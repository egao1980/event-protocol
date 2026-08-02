(defpackage #:event-protocol
  (:use #:cl)
  (:export
   ;; backend / loop
   #:event-backend
   #:event-backend-p
   #:event-loop
   #:event-loop-p
   #:event-handle
   #:event-handle-p
   #:event-handle-canceled-p
   #:event-handle-loop
   #:event-loop-backend
   #:*event-backend*
   #:*event-loop*
   #:with-event-backend
   #:with-event-loop-var
   ;; protocol generics
   #:backend-name
   #:make-event-loop
   #:run
   #:stop
   #:defer
   #:call-soon
   #:sleep*
   #:cancel
   #:register-io
   #:wake
   ;; conditions
   #:event-error
   #:event-error-backend
   #:event-error-loop
   #:event-error-handle
   #:event-error-message
   #:event-loop-error
   #:event-canceled
   #:event-io-error
   #:unsupported-operation))

(in-package #:event-protocol)
