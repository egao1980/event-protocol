(in-package #:event-protocol)

(define-condition event-error (error)
  ((backend :initarg :backend :reader event-error-backend :initform nil)
   (loop :initarg :loop :reader event-error-loop :initform nil)
   (handle :initarg :handle :reader event-error-handle :initform nil)
   (message :initarg :message :reader event-error-message :initform nil))
  (:report (lambda (c s)
             (format s "~@[~A~%~]backend=~S loop=~S handle=~S"
                     (event-error-message c)
                     (event-error-backend c)
                     (event-error-loop c)
                     (event-error-handle c)))))

(define-condition event-loop-error (event-error) ())
(define-condition event-canceled (event-error) ())
(define-condition event-io-error (event-error) ())
(define-condition unsupported-operation (event-error) ())

(defun %unsupported (backend op &optional loop)
  (error 'unsupported-operation
         :backend backend :loop loop
         :message (format nil "~A does not support ~A" backend op)))
