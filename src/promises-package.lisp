(defpackage #:event-protocol/promises
  (:use #:cl #:event-protocol)
  (:nicknames #:stack-event-promises)
  (:shadowing-import-from #:event-protocol #:run)
  (:export #:await
           #:await-timeout
           #:await-timeout-seconds
           #:gather
           #:run-promise
           #:defer-promise
           #:sleep-promise
           #:submit-promise
           #:cancel-promise))

(in-package #:event-protocol/promises)
