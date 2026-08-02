(in-package #:event-protocol/conformance)

#+windows
(deftest libev-unsupported-on-windows
  (ok (signals (event-backend-libev:make-libev-backend)
               'unsupported-operation)))

#-windows
(setf *test-backend-maker*
      (lambda () (event-backend-libev:make-libev-backend)))
