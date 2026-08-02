(defpackage #:event-protocol/conformance
  (:use #:cl #:rove #:event-protocol)
  (:shadowing-import-from #:event-protocol #:run)
  (:export #:*test-backend-maker*
           #:with-test-loop
           #:backend-close-loop
           #:backend-wake-call))
(in-package #:event-protocol/conformance)

(defvar *test-backend-maker* nil
  "Thunk → EVENT-BACKEND for the current conformance run.")

(defun backend-close-loop (backend loop)
  (declare (ignore backend))
  (let* ((pkg (symbol-package (class-name (class-of loop))))
         (fn (find-symbol "CLOSE-LOOP" pkg)))
    (when (and fn (fboundp fn))
      (funcall fn loop))))

(defun backend-wake-call (backend loop function)
  (let* ((pkg (symbol-package (class-name (class-of backend))))
         (fn (find-symbol "WAKE-CALL" pkg)))
    (assert fn () "WAKE-CALL missing in ~A" pkg)
    (funcall fn loop function)))

(defmacro with-test-loop ((backend loop) &body body)
  "Bind BACKEND/LOOP, run BODY under WITH-EVENT-BACKEND, always CLOSE-LOOP."
  (let ((b (gensym "BACKEND"))
        (l (gensym "LOOP")))
    `(let* ((,b (funcall *test-backend-maker*))
            (,l (make-event-loop ,b))
            (,backend ,b)
            (,loop ,l))
       (unwind-protect
            (with-event-backend (,b)
              ,@body)
         (backend-close-loop ,b ,l)))))

(defun %now ()
  (/ (get-internal-real-time) internal-time-units-per-second))
