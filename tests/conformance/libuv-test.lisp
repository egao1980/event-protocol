(in-package #:event-protocol/conformance)

(setf *test-backend-maker*
      (lambda () (event-backend-libuv:make-libuv-backend)))
