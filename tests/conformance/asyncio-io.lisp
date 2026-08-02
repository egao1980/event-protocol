(in-package #:event-protocol/conformance)

;;; Inspired by CPython test_events reader/writer cancel + libuv test-poll.c
;;; PSF / MIT — original Rove tests.

(defun %unix-pipe ()
  #+windows (values nil nil)
  #-windows
  (multiple-value-bind (r w) (sb-unix:unix-pipe)
    (values r w)))

(defun %write-byte (fd byte)
  #-windows
  (let ((buf (make-array 1 :element-type '(unsigned-byte 8) :initial-element byte)))
    (sb-sys:with-pinned-objects (buf)
      (sb-unix:unix-write fd (sb-sys:vector-sap buf) 0 1)))
  #+windows (declare (ignore fd byte)))

(defun %close-fd (fd)
  (when fd
    #-windows (ignore-errors (sb-unix:unix-close fd))))

(deftest register-io-read-ready
  "asyncio add_reader / libuv poll: pipe becomes readable."
  #+windows
  (skip "Unix pipe smoke; Windows IOCP path covered by timers/wake")
  #-windows
  (let ((seen nil) io-handle watchdog)
    (multiple-value-bind (read-fd write-fd) (%unix-pipe)
      (unless read-fd (error "unix-pipe failed"))
      (unwind-protect
           (with-test-loop (backend loop)
             (setf io-handle
                   (register-io
                    backend loop read-fd :read
                    (lambda (status)
                      (push status seen)
                      (when io-handle (cancel backend io-handle))
                      (when watchdog (cancel backend watchdog))
                      (stop backend loop))))
             (%write-byte write-fd 65)
             (setf watchdog
                   (sleep* backend loop 0.5 :callback (lambda () (stop backend loop))))
             (run backend loop :stop-when-idle t))
        (%close-fd read-fd)
        (%close-fd write-fd)))
    (ok (member :ok seen))))

(deftest register-io-cancel-before-ready
  "asyncio test_reader_callback_cancel: cancel before data → no callback."
  #+windows
  (skip "Unix pipe")
  #-windows
  (let ((seen nil) io-handle)
    (multiple-value-bind (read-fd write-fd) (%unix-pipe)
      (unless read-fd (error "unix-pipe failed"))
      (unwind-protect
           (with-test-loop (backend loop)
             (setf io-handle
                   (register-io backend loop read-fd :read
                                (lambda (status) (push status seen))))
             (cancel backend io-handle)
             (sleep* backend loop 0.05 :callback (lambda ()))
             (run backend loop :stop-when-idle t))
        (%close-fd read-fd)
        (%close-fd write-fd)))
    (ok (null seen))
    (ok (event-handle-canceled-p io-handle))))

(deftest register-io-write-ready
  "Writable interest on pipe write end should fire promptly."
  #+windows
  (skip "Unix pipe")
  #-windows
  (let ((seen nil) io-handle watchdog)
    (multiple-value-bind (read-fd write-fd) (%unix-pipe)
      (unless read-fd (error "unix-pipe failed"))
      (unwind-protect
           (with-test-loop (backend loop)
             (setf io-handle
                   (register-io
                    backend loop write-fd :write
                    (lambda (status)
                      (push status seen)
                      (when io-handle (cancel backend io-handle))
                      (when watchdog (cancel backend watchdog))
                      (stop backend loop))))
             (setf watchdog
                   (sleep* backend loop 0.5 :callback (lambda () (stop backend loop))))
             (run backend loop :stop-when-idle t))
        (%close-fd read-fd)
        (%close-fd write-fd)))
    (ok (member :ok seen))))
