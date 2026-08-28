(in-package #:event-protocol/conformance)

;;; asyncio run_in_executor — hop-off + hop-back via wake-call.

(deftest submit-callback-on-loop
  "THUNK off the loop thread; CALLBACK runs on LOOP (stop from hop-back)."
  (let ((seen nil)
        (on-loop nil))
    (with-test-loop (backend loop)
      (sleep* backend loop 0.4 :callback (lambda ()))
      (submit backend loop
              (lambda ()
                (sleep 0.05)
                42)
              :callback (lambda (v)
                          (push v seen)
                          (setf on-loop (eq *event-loop* loop))
                          (stop backend loop)))
      (run backend loop :stop-when-idle t))
    (ok (equal seen '(42)))
    (ok on-loop)))

(deftest submit-error-callback-on-loop
  (let ((seen nil)
        (err (make-condition 'simple-error :format-control "submit-boom")))
    (with-test-loop (backend loop)
      (sleep* backend loop 0.4 :callback (lambda ()))
      (submit backend loop
              (lambda () (error err))
              :callback (lambda (v) (push (list :ok v) seen))
              :error-callback (lambda (e)
                                (push (list :err e) seen)
                                (stop backend loop)))
      (run backend loop :stop-when-idle t))
    (ok (equal seen (list (list :err err))))))

(deftest submit-inline-executor
  (let ((seen nil))
    (with-test-loop (backend loop)
      ;; Keep the loop alive: unref'd wake handles do not by themselves.
      (sleep* backend loop 0.4 :callback (lambda ()))
      (submit backend loop (lambda () :inline)
              :callback (lambda (v)
                          (push v seen)
                          (stop backend loop))
              :executor (lambda (fn) (funcall fn)))
      (run backend loop :stop-when-idle t))
    (ok (equal seen '(:inline)))))
