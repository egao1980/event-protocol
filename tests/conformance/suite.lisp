(in-package #:event-protocol/conformance)

;;; Shared Rove suite — specialize via *TEST-BACKEND-MAKER*.

(defun %close (backend loop)
  (declare (ignore backend))
  (let* ((pkg (symbol-package (class-name (class-of loop))))
         (fn (find-symbol "CLOSE-LOOP" pkg)))
    (when (and fn (fboundp fn))
      (funcall fn loop))))

(defun %wake-call (backend loop function)
  (let* ((pkg (symbol-package (class-name (class-of backend))))
         (fn (find-symbol "WAKE-CALL" pkg)))
    (assert fn () "WAKE-CALL missing in ~A" pkg)
    (funcall fn loop function)))

(deftest defer-and-run
  (let* ((backend (funcall *test-backend-maker*))
         (loop (make-event-loop backend))
         (seen nil))
    (with-event-backend (backend)
      (defer backend loop (lambda () (push :a seen)))
      (defer backend loop (lambda () (push :b seen)))
      (run backend loop :stop-when-idle t)
      (%close backend loop))
    ;; Idle fire order is backend-defined; require both ran exactly once.
    (ok (null (set-exclusive-or seen '(:a :b))))
    (ok (= 2 (length seen)))))

(deftest cancel-skips-callback
  (let* ((backend (funcall *test-backend-maker*))
         (loop (make-event-loop backend))
         (seen nil)
         (h nil))
    (with-event-backend (backend)
      (setf h (defer backend loop (lambda () (push :x seen))))
      (cancel backend h)
      (sleep* backend loop 0.05 :callback (lambda ()))
      (run backend loop :stop-when-idle t)
      (%close backend loop))
    (ok (null seen))
    (ok (event-handle-canceled-p h))))

(deftest sleep-fires-callback
  (let* ((backend (funcall *test-backend-maker*))
         (loop (make-event-loop backend))
         (seen nil))
    (with-event-backend (backend)
      (sleep* backend loop 0.05 :callback (lambda () (push :tick seen)))
      (run backend loop :stop-when-idle t)
      (%close backend loop))
    (ok (equal seen '(:tick)))))

(deftest wake-runs-enqueued
  (let* ((backend (funcall *test-backend-maker*))
         (loop (make-event-loop backend))
         (seen nil))
    (with-event-backend (backend)
      (sleep* backend loop 0.1 :callback (lambda ()))
      (%wake-call backend loop (lambda () (push :woken seen)))
      (run backend loop :stop-when-idle t)
      (%close backend loop))
    (ok (equal seen '(:woken)))))

(deftest register-io-read-ready
  "Smoke: poll a pipe that becomes readable (Unix)."
  #+windows
  (skip "Unix pipe smoke; Windows covered by sleep/defer/wake")
  #-windows
  (let* ((backend (funcall *test-backend-maker*))
         (loop (make-event-loop backend))
         (seen nil)
         (io-handle nil))
    (multiple-value-bind (read-fd write-fd)
        (sb-unix:unix-pipe)
      (unless read-fd
        (error "unix-pipe failed"))
      (unwind-protect
           (let ((buf (make-array 1 :element-type '(unsigned-byte 8) :initial-element 65))
                 (watchdog nil))
             (with-event-backend (backend)
               (setf io-handle
                     (register-io
                      backend loop read-fd :read
                      (lambda (status)
                        (push status seen)
                        (when io-handle
                          (cancel backend io-handle))
                        (when watchdog
                          (cancel backend watchdog))
                        (stop backend loop))))
               (sb-sys:with-pinned-objects (buf)
                 (sb-unix:unix-write write-fd (sb-sys:vector-sap buf) 0 1))
               (setf watchdog
                     (sleep* backend loop 0.5 :callback (lambda () (stop backend loop))))
               (run backend loop :stop-when-idle t)
               (%close backend loop)))

        (ignore-errors (sb-unix:unix-close read-fd))
        (ignore-errors (sb-unix:unix-close write-fd))))
    (ok (member :ok seen))))
