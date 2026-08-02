(defpackage #:event-protocol/tests
  (:use #:cl #:rove #:event-protocol)
  ;; ROVE:RUN vs EVENT-PROTOCOL:RUN
  (:shadowing-import-from #:event-protocol #:run))
(in-package #:event-protocol/tests)
