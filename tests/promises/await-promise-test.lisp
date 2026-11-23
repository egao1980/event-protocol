;;;; Evidence for event-protocol#26: await a Blackbird promise, gather
;;;; several, and run one to completion from sync code (asyncio.run /
;;;; asyncio.gather shape). Each test is the spec a fix must satisfy.
;;;; NULL-BACKEND comes from promises-test.lisp.

(in-package #:event-protocol/promises/tests)

(define-condition %await-boom (error) ()
  (:report "boom"))

(defun %promises-fn (name)
  "Exported function NAME of event-protocol/promises, or NIL."
  (multiple-value-bind (sym status) (find-symbol name :event-protocol/promises)
    (and (eq status :external) (fboundp sym) (symbol-function sym))))

(defmacro %with-null-loop ((backend loop) &body body)
  `(let* ((,backend (make-instance 'null-backend))
          (,loop (make-event-loop ,backend)))
     (declare (ignorable ,backend ,loop))
     (with-event-backend (,backend)
       (with-event-loop-var (,loop)
         ,@body))))

(defun %settled-later (loop value)
  "Promise of VALUE that settles a few ticks after the ones made before it."
  (blackbird:attach (sleep-promise loop 0)
                    (lambda (&rest ignore)
                      (declare (ignore ignore))
                      (defer-promise loop (lambda () value)))))

(deftest await-accepts-promise
  (testing "(await promise) drives the bound loop and returns the value"
    (%with-null-loop (backend loop)
      (let ((got (handler-case (await (defer-promise loop (lambda () 42)))
                   (error (e) e))))
        (ok (eql 42 got) (format nil "await returned ~A" got))))))

(deftest await-promise-signals-rejection
  (testing "a rejected promise re-signals its condition from await"
    (%with-null-loop (backend loop)
      (ok (signals (await (defer-promise loop (lambda () (error '%await-boom))))
                   '%await-boom)))))

(deftest await-promise-timeout
  (testing "(await promise :timeout s) on a promise that never settles"
    (%with-null-loop (backend loop)
                     (ok (signals (await (blackbird:with-promise (resolve reject) nil)
                                         :timeout 0)
                           'event-error)))))

(deftest await-promise-returns-while-loop-busy
  (testing "await returns once the promise settles though the loop never idles"
    ;; Idle pooled connections keep a real loop busy; here a self-rescheduling
    ;; DEFER chain does (bounded so a broken await cannot spin forever).
    (%with-null-loop (backend loop)
      (let ((ticks 0))
        (labels ((keepalive ()
                   (when (< (incf ticks) 100000)
                     (defer backend loop #'keepalive))))
          (defer backend loop #'keepalive))
        (let ((got (handler-case (await (%settled-later loop :done))
                     (error (e) e))))
          (ok (eq :done got) (format nil "await returned ~A" got))
          (ok (< ticks 100000) "returned before the keepalive chain ran out"))))))

(deftest gather-awaits-all-in-order
  (testing "event-protocol/promises:gather → promise of the values in argument order"
    (let ((gather (%promises-fn "GATHER")))
      (ok gather "GATHER is exported")
      (when gather
        (%with-null-loop (backend loop)
          (let ((got (handler-case
                         (await (funcall gather
                                         (%settled-later loop 1)
                                         (defer-promise loop (lambda () 2))
                                         (defer-promise loop (lambda () 3))))
                       (error (e) e))))
            (ok (equal '(1 2 3) got) (format nil "gather → ~S" got))))))))

(defclass %closing-backend (null-backend)
  ((closed :initform '() :accessor closed-loops)))

(defmethod close-event-loop ((backend %closing-backend) loop)
  (push loop (closed-loops backend))
  nil)

(deftest run-promise-makes-binds-and-closes-loop
  (testing "run-promise: fresh loop on BACKEND, bound around THUNK, awaited, closed"
    (let ((run-promise (%promises-fn "RUN-PROMISE")))
      (ok run-promise "RUN-PROMISE is exported")
      (when run-promise
        (let* ((backend (make-instance '%closing-backend))
               (seen-loop nil)
               (seen-backend nil)
               (got (handler-case
                        (funcall run-promise
                                 (lambda ()
                                   (setf seen-loop *event-loop*
                                         seen-backend *event-backend*)
                                   (%settled-later *event-loop* 7))
                                 :backend backend)
                      (error (e) e))))
          (ok (eql 7 got) (format nil "run-promise → ~A" got))
          (ok (typep seen-loop 'event-loop) "THUNK sees a bound *event-loop*")
          (ok (eq backend seen-backend) "THUNK sees *event-backend* = BACKEND")
          (ok (member seen-loop (closed-loops backend)) "the loop is closed after")
          (ok (null *event-loop*) "no *event-loop* binding leaks out"))))))

(deftest run-promise-defaults-to-bound-backend
  (testing "run-promise without :backend uses *event-backend*"
    (let ((run-promise (%promises-fn "RUN-PROMISE")))
      (ok run-promise "RUN-PROMISE is exported")
      (when run-promise
        (let ((backend (make-instance 'null-backend)))
          (with-event-backend (backend)
            (let ((got (handler-case
                           (funcall run-promise
                                    (lambda ()
                                      (defer-promise *event-loop* (lambda () :ok))))
                         (error (e) e))))
              (ok (eq :ok got) (format nil "run-promise → ~A" got)))))))))
