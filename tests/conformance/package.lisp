(defpackage #:event-protocol/conformance
  (:use #:cl #:rove #:event-protocol)
  (:shadowing-import-from #:event-protocol #:run)
  (:export #:run-backend-suite
           #:*test-backend-maker*))
(in-package #:event-protocol/conformance)

(defvar *test-backend-maker* nil
  "Thunk → EVENT-BACKEND for the current conformance run.")
