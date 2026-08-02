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
                     (t (return))))))
  loop)

(defmethod stop ((backend null-backend) (loop null-loop))
  (setf (null-loop-running-p loop) nil)
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

(deftest unsupported-wake
  (let ((backend (make-instance 'null-backend))
        (loop (make-event-loop (make-instance 'null-backend))))
    (ok (signals (wake backend loop) 'unsupported-operation))))

(deftest backend-name-and-dynamics
  (let ((b (make-instance 'null-backend)))
    (ok (string= (backend-name b) "null"))
    (with-event-backend (b)
      (ok (eq *event-backend* b)))))
