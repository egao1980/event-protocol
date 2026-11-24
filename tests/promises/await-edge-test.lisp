;;;; Edge cases for event-protocol#26: AWAIT on settled / multi-value
;;;; promises, its timeout condition and timer, GATHER rejection and plain
;;;; values, RUN-PROMISE cleanup on every exit. Null backend, no natives.

(in-package #:event-protocol/promises/tests)

(defclass %recording-backend (null-backend)
  ((runs :initform 0 :accessor backend-runs)
   (timers :initform '() :accessor backend-timers)
   (closed :initform '() :accessor backend-closed)))

(defmethod run :before ((backend %recording-backend) loop &key stop-when-idle)
  (declare (ignore loop stop-when-idle))
  (incf (backend-runs backend)))

(defmethod sleep* :around ((backend %recording-backend) loop seconds &key callback)
  (declare (ignore loop seconds callback))
  (let ((handle (call-next-method)))
    (push handle (backend-timers backend))
    handle))

(defmethod close-event-loop ((backend %recording-backend) loop)
  (push loop (backend-closed backend))
  nil)

(defmacro %with-recording-loop ((backend loop) &body body)
  `(let* ((,backend (make-instance '%recording-backend))
          (,loop (make-event-loop ,backend)))
     (declare (ignorable ,loop))
     (with-event-backend (,backend)
       (with-event-loop-var (,loop)
         ,@body))))

(deftest await-settled-promise-does-not-run-the-loop
  (%with-recording-loop (backend loop)
    (ok (eql 5 (await (blackbird:with-promise (resolve reject) (resolve 5)))))
    (ok (zerop (backend-runs backend))
        "a settled promise returns without RUN (a STOP before RUN would end the next run)")))

(deftest await-returns-all-values
  (%with-recording-loop (backend loop)
    (ok (equal '(1 2)
               (multiple-value-list
                (await (blackbird:attach (sleep-promise loop 0)
                                         (lambda (&rest ignore)
                                           (declare (ignore ignore))
                                           (values 1 2)))))))))

(deftest await-timeout-is-typed
  (%with-recording-loop (backend loop)
    (let ((c (handler-case (await (blackbird:with-promise (resolve reject) nil)
                                  :timeout 0.5)
               (event-error (e) e))))
      (ok (typep c 'await-timeout) (format nil "got ~S" (type-of c)))
      (ok (and (typep c 'await-timeout) (eql 0.5 (await-timeout-seconds c)))))))

(deftest await-cancels-its-timer-when-settled
  (%with-recording-loop (backend loop)
    (ok (eq :ok (await (defer-promise loop (lambda () :ok)) :timeout 30)))
    (let ((timer (first (backend-timers backend))))
      (ok (and timer (event-handle-canceled-p timer))
          "the :timeout timer does not stay pending on the loop"))))

(deftest await-rejects-a-non-promise
  (%with-recording-loop (backend loop)
    (ok (signals (await 42) 'type-error))))

(deftest gather-rejects-with-the-first-error
  (%with-recording-loop (backend loop)
    (ok (signals (await (gather (defer-promise loop (lambda () 1))
                                (defer-promise loop (lambda () (error '%await-boom)))
                                (%settled-later loop 3)))
                 '%await-boom))))

(deftest gather-accepts-plain-values-and-nothing
  (%with-recording-loop (backend loop)
    (ok (equal '(1 2) (await (gather 1 (defer-promise loop (lambda () 2))))))
    (ok (null (await (gather))) "(gather) → NIL")))

(deftest run-promise-closes-the-loop-on-every-exit
  (let ((backend (make-instance '%recording-backend)))
    (testing "a rejected promise"
      (ok (signals (run-promise (lambda ()
                                  (defer-promise *event-loop* (lambda () (error '%await-boom))))
                                :backend backend)
                   '%await-boom))
      (ok (= 1 (length (backend-closed backend)))))
    (testing "THUNK signals before returning a promise"
      (ok (signals (run-promise (lambda () (error '%await-boom)) :backend backend)
                   '%await-boom))
      (ok (= 2 (length (backend-closed backend)))))
    (testing "the timeout"
      (ok (signals (run-promise (lambda () (blackbird:with-promise (resolve reject) nil))
                                :backend backend :timeout 0)
                   'await-timeout))
      (ok (= 3 (length (backend-closed backend)))))
    (testing "THUNK returns a plain value"
      (ok (equal '(:a :b) (multiple-value-list
                           (run-promise (lambda () (values :a :b)) :backend backend))))
      (ok (= 4 (length (backend-closed backend)))))))

(deftest run-promise-needs-a-backend
  (let ((*event-backend* nil))
    (ok (signals (run-promise (lambda () 1)) 'event-error))))
