(in-package #:event-protocol/promises)

;;; Thin Blackbird wrappers over callback + cancel. Protocol core stays
;;; callback-only; this secondary system is the App DX layer.

(defvar *promise-handles* (make-hash-table :test 'eq)
  "Pending promise → (backend . event-handle) for CANCEL-PROMISE.")

(defun %remember-handle (promise backend handle)
  (when handle
    (setf (gethash promise *promise-handles*) (cons backend handle)))
  promise)

(defun %forget-handle (promise)
  (prog1 (gethash promise *promise-handles*)
    (remhash promise *promise-handles*)))

(defun %require-backend (backend)
  (or backend
      (error 'event-error :message "*event-backend* is not bound")))

(defun %event-context ()
  (let ((eb *event-backend*)
        (el *event-loop*))
    (unless (and eb el)
      (error 'event-error
             :backend eb :loop el
             :message "bind *event-backend* and *event-loop*"))
    (values eb el)))

(defun await (start-fn &key timeout)
  "Drive the bound loop until START-FN's resolve/reject fires.
   START-FN is (lambda (resolve reject) ...)."
  (check-type start-fn function)
  (multiple-value-bind (eb el) (%event-context)
    (let ((result nil)
          (err nil)
          (done nil))
      (funcall start-fn
               (lambda (value)
                 (setf result value done t)
                 (stop eb el))
               (lambda (c)
                 (setf err c done t)
                 (stop eb el)))
      (when timeout
        (sleep* eb el timeout
                :callback (lambda ()
                            (unless done
                              (setf err (make-condition
                                         'event-error
                                         :backend eb :loop el
                                         :message "await timed out")
                                    done t)
                              (stop eb el)))))
      (run eb el :stop-when-idle nil)
      (when err (error err))
      result)))

(defun defer-promise (loop fn &key (backend *event-backend*))
  "DEFER FN; resolve its value, reject on error. Stores the handle for cancel."
  (check-type fn function)
  (let ((backend (%require-backend backend))
        promise
        handle)
    (setf promise
          (blackbird:with-promise (resolve reject)
            (setf handle
                  (defer backend loop
                         (lambda ()
                           (%forget-handle promise)
                           (handler-case (resolve (funcall fn))
                             (error (e) (reject e))))))))
    (%remember-handle promise backend handle)
    promise))

(defun sleep-promise (loop seconds &key (backend *event-backend*))
  "SLEEP* as a Blackbird promise. Stores the handle for cancel."
  (let ((backend (%require-backend backend))
        promise
        handle)
    (setf promise
          (blackbird:with-promise (resolve reject)
            (setf handle
                  (sleep* backend loop seconds
                          :callback (lambda ()
                                      (%forget-handle promise)
                                      (resolve))))))
    (%remember-handle promise backend handle)
    promise))

(defun submit-promise (loop thunk &key (backend *event-backend*) executor)
  "SUBMIT THUNK; resolve the value, reject on error.
   :EXECUTOR is the hop-off runner (function of one thunk), same as SUBMIT."
  (check-type thunk function)
  (let ((backend (%require-backend backend)))
    (blackbird:with-promise (resolve reject)
      (submit backend loop thunk
              :callback (lambda (value) (resolve value))
              :error-callback (lambda (e) (reject e))
              :executor executor))))

(defun cancel-promise (promise)
  "Cancel the stored event-handle if still pending; reject if still outstanding."
  (check-type promise blackbird:promise)
  (let ((entry (%forget-handle promise)))
    (when entry
      (let ((backend (car entry))
            (handle (cdr entry)))
        (when (and backend handle
                   (not (event-handle-canceled-p handle)))
          (cancel backend handle)))))
  (unless (blackbird:promise-finished-p promise)
    (blackbird:signal-error
     promise
     (make-condition 'event-canceled :message "promise canceled")))
  promise)
