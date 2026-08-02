(in-package #:event-protocol)

;;; Protocol-only types. Backends subclass these and specialize the generics.
;;; See cl-stack docs/capabilities/event-protocol.md

(defclass event-backend ()
  ((name :initarg :name :reader backend-name :initform "unknown")))

(defun event-backend-p (x) (typep x 'event-backend))

(defclass event-loop ()
  ((backend :initarg :backend :reader event-loop-backend :type event-backend)))

(defun event-loop-p (x) (typep x 'event-loop))

(defclass event-handle ()
  ((loop :initarg :loop :reader event-handle-loop)
   (canceled :initform nil :accessor event-handle-canceled-p)))

(defun event-handle-p (x) (typep x 'event-handle))

(defvar *event-backend* nil
  "Current EVENT-BACKEND. Required while running loop ops.")

(defvar *event-loop* nil
  "Current EVENT-LOOP, bound inside RUN / WITH-EVENT-LOOP-VAR.")

(defmacro with-event-backend ((backend) &body body)
  `(let ((*event-backend* ,backend))
     ,@body))

(defmacro with-event-loop-var ((loop) &body body)
  `(let ((*event-loop* ,loop))
     ,@body))

(defgeneric make-event-loop (backend &key)
  (:documentation "Create a new EVENT-LOOP for BACKEND."))

(defgeneric run (backend loop &key stop-when-idle)
  (:documentation "Enter the event loop until stopped or idle (when STOP-WHEN-IDLE)."))

(defgeneric stop (backend loop)
  (:documentation "Request loop exit after the current callback."))

(defgeneric defer (backend loop function &key)
  (:documentation "Schedule FUNCTION on LOOP (next tick). Returns an EVENT-HANDLE."))

(defgeneric call-soon (backend loop function &key)
  (:documentation "Alias of DEFER for asyncio-shaped call sites.")
  (:method ((backend event-backend) loop function &key)
    (defer backend loop function)))

(defgeneric sleep* (backend loop seconds &key)
  (:documentation "Schedule a timer; returns an EVENT-HANDLE.
Facade layers may wrap this as a promise."))

(defgeneric cancel (backend handle)
  (:documentation "Cancel HANDLE if still pending.")
  (:method ((backend event-backend) (handle event-handle))
    (setf (event-handle-canceled-p handle) t)
    handle))

(defgeneric register-io (backend loop fd direction callback &key)
  (:documentation "Register interest in FD. DIRECTION is :READ, :WRITE, or :READ-WRITE.
Returns an EVENT-HANDLE.")
  (:method ((backend event-backend) loop fd direction callback &key)
    (declare (ignore loop fd direction callback))
    (%unsupported backend 'register-io)))

(defgeneric wake (backend loop)
  (:documentation "Wake LOOP from another thread so deferred work can run.")
  (:method ((backend event-backend) loop)
    (declare (ignore loop))
    (%unsupported backend 'wake)))

(defmethod make-event-loop :around ((backend event-backend) &key)
  (let ((loop (call-next-method)))
    (check-type loop event-loop)
    loop))
