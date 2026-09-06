(defpackage #:event-protocol/promises/tests
  (:use #:cl #:rove #:event-protocol #:event-protocol/promises)
  ;; ROVE:RUN vs EVENT-PROTOCOL:RUN
  (:shadowing-import-from #:event-protocol #:run))

(in-package #:event-protocol/promises/tests)
