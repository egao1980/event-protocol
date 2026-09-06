(in-package #:event-protocol/promises/tests)

;;; Copied from tests/protocol-test.lisp so this system does not couple
;;; to the core test package. SLEEP* accepts :CALLBACK like real backends.

(defclass null-backend (event-backend)
  ()
  (:default-initargs :name "null"))

(defclass null-loop (event-loop)
  ((running :initform nil :accessor null-loop-running-p)
   (queue :initform '() :accessor null-loop-queue)))

(defmethod make-event-loop ((backend null-backend) &key)
  (make-instance 'null-loop :backend backend))

(defmethod defer ((backend null-backend) (loop null-loop) function &key)
  (let ((h (make-instance 'event-handle :loop loop)))
    (setf (null-loop-queue loop)
          (nconc (null-loop-queue loop) (list (cons h function))))
    h))

(defmethod sleep* ((backend null-backend) (loop null-loop) seconds &key callback)
  (declare (ignore seconds))
  (defer backend loop (or callback (lambda ()))))

(defmethod run ((backend null-backend) (loop null-loop) &key (stop-when-idle t))
  (setf (null-loop-running-p loop) t)
  (with-event-loop-var (loop)
    (loop while (null-loop-running-p loop)
          do (let ((item (pop (null-loop-queue loop))))
               (cond (item
                      (destructuring-bind (handle . fn) item
                        (unless (event-handle-canceled-p handle)
                          (funcall fn))))
                     (stop-when-idle
                      (setf (null-loop-running-p loop) nil))
                     (t
                      (sleep 0.001))))))
  loop)

(defmethod stop ((backend null-backend) (loop null-loop))
  (setf (null-loop-running-p loop) nil)
  loop)

(defmethod wake ((backend null-backend) (loop null-loop))
  loop)

(defmethod wake-call ((backend null-backend) (loop null-loop) function)
  (defer backend loop function)
  loop)

(deftest defer-promise-resolves-on-run
  (let* ((backend (make-instance 'null-backend))
         (loop (make-event-loop backend))
         (seen nil))
    (with-event-backend (backend)
      (let ((p (defer-promise loop (lambda () :ok))))
        (blackbird:attach p (lambda (v) (setf seen v)))
        (run backend loop :stop-when-idle t))
      (ok (eq seen :ok)))))

(deftest sleep-promise-resolves
  (let* ((backend (make-instance 'null-backend))
         (loop (make-event-loop backend))
         (seen nil))
    (with-event-backend (backend)
      (let ((p (sleep-promise loop 0)))
        (blackbird:attach p (lambda (&rest vals)
                              (declare (ignore vals))
                              (setf seen t)))
        (run backend loop :stop-when-idle t))
      (ok seen))))

(deftest cancel-promise-skips-callback
  (let* ((backend (make-instance 'null-backend))
         (loop (make-event-loop backend))
         (seen nil)
         (err nil))
    (with-event-backend (backend)
      (let ((p (defer-promise loop (lambda () (setf seen t) :ran))))
        (blackbird:attach-errback p (lambda (e) (setf err e)))
        (cancel-promise p)
        (run backend loop :stop-when-idle t))
      (ok (null seen))
      (ok (typep err 'event-canceled)))))

(deftest await-drives-until-callback
  (let* ((backend (make-instance 'null-backend))
         (loop (make-event-loop backend)))
    (with-event-backend (backend)
      (with-event-loop-var (loop)
        (ok (eq :ok
                (await (lambda (resolve reject)
                         (declare (ignore reject))
                         (defer backend loop
                                (lambda () (funcall resolve :ok)))))))))))

(deftest await-timeout
  (let* ((backend (make-instance 'null-backend))
         (loop (make-event-loop backend)))
    (with-event-backend (backend)
      (with-event-loop-var (loop)
        (ok (signals (await (lambda (resolve reject)
                              (declare (ignore resolve reject)))
                            :timeout 0)
                     'event-error))))))

(deftest submit-promise-inline-executor
  " :executor (lambda (thunk) (funcall thunk)) — hop-off then hop-back."
  (let* ((backend (make-instance 'null-backend))
         (loop (make-event-loop backend))
         (seen nil))
    (with-event-backend (backend)
      (let ((p (submit-promise loop (lambda () 7)
                               :executor (lambda (thunk) (funcall thunk)))))
        (blackbird:attach p (lambda (v) (setf seen v)))
        (run backend loop :stop-when-idle t))
      (ok (eql seen 7)))))
