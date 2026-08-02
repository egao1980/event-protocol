(in-package #:event-protocol/conformance)

;;; Inspired by CPython Lib/test/test_asyncio/test_events.py
;;; (test_call_soon, test_call_later, cancel / nesting). PSF License v2.
;;; Original Rove tests — not a copy of test_events.py.

(deftest defer-nested
  "call_soon from inside call_soon — nested work drains before idle exit."
  (let ((seen nil))
    (with-test-loop (backend loop)
      (defer backend loop
        (lambda ()
          (push :outer seen)
          (defer backend loop (lambda () (push :inner seen)))))
      (run backend loop :stop-when-idle t))
    (ok (member :outer seen))
    (ok (member :inner seen))))

(deftest defer-stops-loop
  "asyncio: callback may stop the loop."
  (let ((seen nil))
    (with-test-loop (backend loop)
      (defer backend loop
        (lambda ()
          (push :stop seen)
          (stop backend loop)))
      ;; Extra work that must not be required to finish if stop is prompt.
      (sleep* backend loop 1.0 :callback (lambda () (push :late seen)))
      (run backend loop :stop-when-idle t))
    (ok (member :stop seen))))

(deftest sleep-zero-like-soon
  "libuv zero_timeout / asyncio call_later(0)."
  (let ((seen nil))
    (with-test-loop (backend loop)
      (sleep* backend loop 0 :callback (lambda () (push :z seen)))
      (run backend loop :stop-when-idle t))
    (ok (equal seen '(:z)))))

(deftest sleep-delay-respected
  "asyncio test_run_until_complete sleep lower bound (coarse clock OK)."
  (let* ((delay 0.1d0)
         (t0 0d0)
         (dt 0d0))
    (with-test-loop (backend loop)
      (setf t0 (%now))
      (sleep* backend loop delay
              :callback (lambda () (setf dt (- (%now) t0))))
      (run backend loop :stop-when-idle t))
    ;; Allow 20ms slack for scheduling / Windows timer granularity ideas.
    (ok (>= dt (- delay 0.02d0)))))

(deftest sleep-order-by-deadline
  "libuv timer order: shorter timeout fires before longer."
  (let ((seen nil))
    (with-test-loop (backend loop)
      (sleep* backend loop 0.12 :callback (lambda () (push :late seen)))
      (sleep* backend loop 0.04 :callback (lambda () (push :early seen)))
      (run backend loop :stop-when-idle t))
    ;; PUSH reverses: early then late → (:LATE :EARLY)
    (ok (equal seen '(:late :early)))))

(deftest cancel-timer-others-fire
  "Cancel one timer; siblings still run (libuv never_cb pattern)."
  (let ((seen nil) h)
    (with-test-loop (backend loop)
      (setf h (sleep* backend loop 0.2 :callback (lambda () (push :nope seen))))
      (sleep* backend loop 0.05 :callback (lambda () (push :ok seen)))
      (cancel backend h)
      (run backend loop :stop-when-idle t))
    (ok (equal seen '(:ok)))
    (ok (event-handle-canceled-p h))))

(deftest cancel-already-fired-safe
  "Cancel after fire must not signal; handle marked canceled."
  (let ((h nil))
    (with-test-loop (backend loop)
      (setf h (sleep* backend loop 0.02 :callback (lambda ())))
      (run backend loop :stop-when-idle t)
      (cancel backend h))
    (ok (event-handle-canceled-p h))))

(deftest many-once-timers
  "libuv test-timer: many once timers all fire."
  (let ((n 0)
        (count 8))
    (with-test-loop (backend loop)
      (dotimes (i count)
        (sleep* backend loop (* 0.01 (1+ i))
                :callback (lambda () (incf n))))
      (run backend loop :stop-when-idle t))
    (ok (= n count))))
