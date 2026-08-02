(in-package #:event-protocol/conformance)

;;; Core smoke — kept small; see asyncio-*.lisp / libuv-*.lisp for depth.

(deftest backend-name-nonempty
  (with-test-loop (backend loop)
    (declare (ignore loop))
    (ok (stringp (backend-name backend)))
    (ok (plusp (length (backend-name backend))))))

(deftest empty-run-returns
  "libuv test-run / idle loop: no work → run returns."
  (with-test-loop (backend loop)
    (run backend loop :stop-when-idle t)
    (ok t)))

(deftest defer-and-run
  "asyncio test_call_soon / libuv idle: both deferred fns run."
  (let ((seen nil))
    (with-test-loop (backend loop)
      (defer backend loop (lambda () (push :a seen)))
      (defer backend loop (lambda () (push :b seen)))
      (run backend loop :stop-when-idle t))
    (ok (null (set-exclusive-or seen '(:a :b))))
    (ok (= 2 (length seen)))))

(deftest call-soon-alias
  (let ((seen nil))
    (with-test-loop (backend loop)
      (call-soon backend loop (lambda () (push :soon seen)))
      (run backend loop :stop-when-idle t))
    (ok (equal seen '(:soon)))))

(deftest cancel-skips-callback
  (let ((seen nil) h)
    (with-test-loop (backend loop)
      (setf h (defer backend loop (lambda () (push :x seen))))
      (cancel backend h)
      (sleep* backend loop 0.05 :callback (lambda ()))
      (run backend loop :stop-when-idle t))
    (ok (null seen))
    (ok (event-handle-canceled-p h))))

(deftest sleep-fires-callback
  "asyncio test_call_later."
  (let ((seen nil))
    (with-test-loop (backend loop)
      (sleep* backend loop 0.05 :callback (lambda () (push :tick seen)))
      (run backend loop :stop-when-idle t))
    (ok (equal seen '(:tick)))))

(deftest wake-runs-enqueued
  "libuv test-async / asyncio call_soon_threadsafe (same-thread)."
  (let ((seen nil))
    (with-test-loop (backend loop)
      (sleep* backend loop 0.1 :callback (lambda ()))
      (backend-wake-call backend loop (lambda () (push :woken seen)))
      (run backend loop :stop-when-idle t))
    (ok (equal seen '(:woken)))))
