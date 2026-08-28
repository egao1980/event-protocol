(in-package #:event-protocol/tests)

;;; Null backend — proves protocol load + default method surface (#15).

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

(defmethod sleep* ((backend null-backend) (loop null-loop) seconds &key)
  (declare (ignore seconds))
  (defer backend loop (lambda ())))

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

(deftest null-backend-defer-and-run
  (let* ((backend (make-instance 'null-backend))
         (loop (make-event-loop backend))
         (seen nil))
    (with-event-backend (backend)
      (defer backend loop (lambda () (push :a seen)))
      (defer backend loop (lambda () (push :b seen)))
      (run backend loop :stop-when-idle t))
    ;; PUSH reverses chronological order: A then B → (:B :A)
    (ok (equal seen '(:b :a)))))

(deftest cancel-skips-callback
  (let* ((backend (make-instance 'null-backend))
         (loop (make-event-loop backend))
         (seen nil)
         (h nil))
    (with-event-backend (backend)
      (setf h (defer backend loop (lambda () (push :x seen))))
      (cancel backend h)
      (run backend loop :stop-when-idle t))
    (ok (null seen))
    (ok (event-handle-canceled-p h))))

(deftest unsupported-register-io
  (let ((backend (make-instance 'null-backend))
        (loop (make-event-loop (make-instance 'null-backend))))
    (ok (signals (register-io backend loop 0 :read (lambda ()))
                 'unsupported-operation))))

(deftest backend-name-and-dynamics
  (let ((b (make-instance 'null-backend)))
    (ok (string= (backend-name b) "null"))
    (with-event-backend (b)
      (ok (eq *event-backend* b)))))

(deftest submit-without-executor-unsupported
  (let* ((backend (make-instance 'null-backend))
         (loop (make-event-loop backend)))
    (ok (signals (submit backend loop (lambda () 1))
                 'unsupported-operation))))

(deftest submit-inline-executor
  " :executor (lambda (fn) (funcall fn)) — tests / deterministic hop-back."
  (let* ((backend (make-instance 'null-backend))
         (loop (make-event-loop backend))
         (seen nil))
    (with-event-backend (backend)
      (submit backend loop (lambda () 7)
              :callback (lambda (v) (push v seen))
              :executor (lambda (fn) (funcall fn)))
      (run backend loop :stop-when-idle t))
    (ok (equal seen '(7)))))

(deftest submit-error-callback
  (let* ((backend (make-instance 'null-backend))
         (loop (make-event-loop backend))
         (seen nil)
         (err (make-condition 'simple-error :format-control "boom")))
    (with-event-backend (backend)
      (submit backend loop (lambda () (error err))
              :callback (lambda (v) (push (list :ok v) seen))
              :error-callback (lambda (e)
                                (push (list :err e) seen)
                                (stop backend loop))
              :executor (lambda (fn) (funcall fn)))
      (run backend loop :stop-when-idle nil))
    (ok (equal seen (list (list :err err))))))

(deftest submit-escape-hatch-function
  (let* ((backend (make-instance 'null-backend))
         (loop (make-event-loop backend))
         (seen nil)
         (ran nil))
    (with-event-backend (backend)
      (submit backend loop (lambda () :ok)
              :callback (lambda (v) (push v seen))
              :executor (lambda (fn)
                          (setf ran t)
                          (funcall fn)))
      (run backend loop :stop-when-idle t))
    (ok ran)
    (ok (equal seen '(:ok)))))
