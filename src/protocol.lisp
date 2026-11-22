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

(defgeneric close-event-loop (backend loop)
  (:documentation "Release LOOP's native resources (descriptor, wake handle, submit
threads) once RUN has returned. Handles still pending on LOOP are canceled
without running their callbacks. Idempotent. After it, LOOP takes no more work.

A caller that made LOOP with MAKE-EVENT-LOOP owns it and must close it:
an unclosed libuv loop keeps its kqueue/epoll descriptor for the life of the
process.")
  (:method ((backend event-backend) loop)
    (declare (ignore loop))
    nil))

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
Returns an EVENT-HANDLE.

CALLBACK is called on the loop thread as (STATUS &optional CODE) each time
FD is ready, and must accept both forms:

  (funcall callback :ok)          FD is ready for DIRECTION.
  (funcall callback :error)       the poll failed; no backend code.
  (funcall callback :error code)  the poll failed; CODE is the backend's
                                  status (event-backend-libuv: the negative
                                  UV_E* code it got, e.g. UV_EBADF on POLLERR).

After :ERROR the FD is in an unknown state: the owner should treat it as a
connection failure, cancel the handle and close the FD. A backend that
catches an error signalled from CALLBACK only warns, so a CALLBACK that
cannot take two arguments loses the error and its owner never completes
(http-backend-async#62).")
  (:method ((backend event-backend) loop fd direction callback &key)
    (declare (ignore loop fd direction callback))
    (%unsupported backend 'register-io)))

(defgeneric update-io (backend handle direction &key callback)
  (:documentation "Change interest on an existing REGISTER-IO handle without
destroying it. DIRECTION is :READ, :WRITE, :READ-WRITE, or :NONE (stop interest,
keep the handle for later UPDATE-IO). Optional CALLBACK replaces the prior one
and is called the same way as REGISTER-IO's: (STATUS &optional CODE).

Backends that watch FDs (libuv poll / libev io) must implement this — cancel +
re-register-io on the same FD races with async close (libuv UV_EEXIST).")
  (:method ((backend event-backend) handle direction &key callback)
    (declare (ignore handle direction callback))
    (%unsupported backend 'update-io)))

(defgeneric wake (backend loop)
  (:documentation "Wake LOOP from another thread so deferred work can run.")
  (:method ((backend event-backend) loop)
    (declare (ignore loop))
    (%unsupported backend 'wake)))

(defgeneric wake-call (backend loop function)
  (:documentation "Enqueue FUNCTION on LOOP and wake it (thread-safe).
asyncio call_soon_threadsafe. FUNCTION runs on the loop thread.")
  (:method ((backend event-backend) loop function)
    (declare (ignore loop function))
    (%unsupported backend 'wake-call)))

(defgeneric submit (backend loop thunk &key callback error-callback executor)
  (:documentation "THUNK off LOOP's thread. CALLBACK/ERROR-CALLBACK on LOOP via WAKE-CALL.

EXECUTOR is a function of one thunk (the hop-off runner), or NIL.
Protocol default: EXECUTOR must be a function — hop-off, then hop-back via WAKE-CALL.
NIL is unsupported here: backends specialize and supply their own default runner
(typically a per-loop pool from cl-stack-executors, or any other thunk runner).
submit does not name a pool type. Do not specialize libuv onto uv_queue_work
for blocking I/O.")
  (:method ((backend event-backend) loop thunk &key callback error-callback executor)
    (check-type thunk function)
    (when callback (check-type callback function))
    (when error-callback (check-type error-callback function))
    (unless executor
      (%unsupported backend 'submit loop))
    (check-type executor function)
    (funcall executor
             (lambda ()
               (handler-case
                   (let ((value (funcall thunk)))
                     (when callback
                       (wake-call backend loop (lambda () (funcall callback value)))))
                 (error (e)
                   (if error-callback
                       (wake-call backend loop (lambda () (funcall error-callback e)))
                       (warn "event-protocol submit: unhandled error: ~A" e))))))
    (values)))

(defmethod make-event-loop :around ((backend event-backend) &key)
  (let ((loop (call-next-method)))
    (check-type loop event-loop)
    loop))
