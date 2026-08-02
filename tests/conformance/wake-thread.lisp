(in-package #:event-protocol/conformance)

;;; Inspired by asyncio test_call_soon_threadsafe + libuv test-async.c (MIT/PSF).
;;; SBCL threads only for the cross-thread case.

(deftest wake-multiple-callbacks
  "Several wake-call enqueues all run (coalesced async OK)."
  (let ((seen nil))
    (with-test-loop (backend loop)
      (sleep* backend loop 0.15 :callback (lambda ()))
      (backend-wake-call backend loop (lambda () (push :a seen)))
      (backend-wake-call backend loop (lambda () (push :b seen)))
      (backend-wake-call backend loop (lambda () (push :c seen)))
      (run backend loop :stop-when-idle t))
    (ok (null (set-exclusive-or seen '(:a :b :c))))
    (ok (= 3 (length seen)))))

#+sbcl
(deftest wake-from-other-thread
  "asyncio call_soon_threadsafe from another thread."
  (let ((seen nil)
        (ready (sb-thread:make-semaphore :count 0)))
    (with-test-loop (backend loop)
      ;; Keep loop alive until foreign thread schedules work.
      (sleep* backend loop 0.05
              :callback (lambda ()
                          (sb-thread:signal-semaphore ready)
                          ;; Stay alive a bit longer for the wake.
                          (sleep* backend loop 0.25 :callback (lambda ()))))
      (sb-thread:make-thread
       (lambda ()
         (sb-thread:wait-on-semaphore ready)
         (backend-wake-call backend loop
                            (lambda ()
                              (push :from-thread seen)
                              (stop backend loop))))
       :name "event-wake")
      (run backend loop :stop-when-idle t))
    (ok (equal seen '(:from-thread)))))

#-sbcl
(deftest wake-from-other-thread
  (skip "SBCL threads only"))
