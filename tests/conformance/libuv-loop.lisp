(in-package #:event-protocol/conformance)

;;; Inspired by libuv test-loop-stop.c / test-timer.c / test-idle.c (MIT).
;;; Original Rove tests.

(deftest stop-from-timer
  "libuv test-loop-stop: stop aborts further waiting."
  (let ((seen nil))
    (with-test-loop (backend loop)
      (sleep* backend loop 0.05
              :callback (lambda ()
                          (push :stop seen)
                          (stop backend loop)))
      (sleep* backend loop 1.0 :callback (lambda () (push :late seen)))
      (run backend loop :stop-when-idle t))
    (ok (member :stop seen))))

(deftest defer-then-sleep
  "Idle work then timer (libuv idle + timer coexistence)."
  (let ((seen nil))
    (with-test-loop (backend loop)
      (defer backend loop (lambda () (push :idle seen)))
      (sleep* backend loop 0.05 :callback (lambda () (push :timer seen)))
      (run backend loop :stop-when-idle t))
    (ok (member :idle seen))
    (ok (member :timer seen))))

(deftest reenter-defer-after-timer
  "Schedule more defer work from a timer callback."
  (let ((seen nil))
    (with-test-loop (backend loop)
      (sleep* backend loop 0.03
              :callback (lambda ()
                          (push :timer seen)
                          (defer backend loop (lambda () (push :after seen)))))
      (run backend loop :stop-when-idle t))
    (ok (equal (reverse seen) '(:timer :after)))))

(deftest cancel-defer-keeps-timer
  (let ((seen nil) h)
    (with-test-loop (backend loop)
      (setf h (defer backend loop (lambda () (push :nope seen))))
      (cancel backend h)
      (sleep* backend loop 0.04 :callback (lambda () (push :ok seen)))
      (run backend loop :stop-when-idle t))
    (ok (equal seen '(:ok)))))
