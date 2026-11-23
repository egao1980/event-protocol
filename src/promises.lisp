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

(define-condition await-timeout (event-error)
  ((seconds :initarg :seconds :reader await-timeout-seconds :initform nil))
  (:documentation "AWAIT / RUN-PROMISE gave up after :TIMEOUT seconds. The
promise itself is left as it is (cancel it with CANCEL-PROMISE)."))

(defun %starter (promise)
  "(lambda (resolve reject)) that settles with PROMISE: a Blackbird promise,
   or already such a starter function."
  (etypecase promise
    (function promise)
    (blackbird:promise
     (lambda (resolve reject)
       (blackbird:attach-errback promise (lambda (c) (funcall reject c)))
       (blackbird:attach promise (lambda (&rest values) (apply resolve values)))))))

(defun await (promise &key timeout)
  "Drive the bound loop (*EVENT-BACKEND* / *EVENT-LOOP*) until PROMISE settles;
   return its value(s), or re-signal the condition it was rejected with.

   PROMISE is a Blackbird promise, or a starter (lambda (resolve reject) ...)
   that FUNCALLs one of them. The loop runs with :STOP-WHEN-IDLE NIL and is
   stopped as soon as PROMISE settles, so work still pending on the loop
   (idle pooled connections, timers) does not hold AWAIT. A promise that is
   already settled returns without running the loop.
   TIMEOUT (seconds) signals AWAIT-TIMEOUT when PROMISE has not settled by then.
   Call it from outside the loop, not from one of its callbacks."
  (check-type promise (or function blackbird:promise))
  (multiple-value-bind (eb el) (%event-context)
    (let ((values nil)
          (err nil)
          (done nil)
          (running nil)
          (timer nil))
      (flet ((settle ()
               (setf done t)
               (when timer
                 (ignore-errors (cancel eb timer)))
               ;; A stop before RUN would end the loop's next run instead.
               (when running
                 (stop eb el))))
        (funcall (%starter promise)
                 (lambda (&rest vs)
                   (unless done
                     (setf values vs)
                     (settle)))
                 (lambda (c)
                   (unless done
                     (setf err c)
                     (settle))))
        (when (and timeout (not done))
          (setf timer
                (sleep* eb el timeout
                        :callback (lambda ()
                                    (unless done
                                      (setf timer nil
                                            err (make-condition
                                                 'await-timeout
                                                 :seconds timeout
                                                 :backend eb :loop el
                                                 :message (format nil "await timed out after ~A s" timeout)))
                                      (settle))))))
        (unless done
          (setf running t)
          (unwind-protect (run eb el :stop-when-idle nil)
            (setf running nil)))
        (when err (error err))
        (values-list values)))))

(defun gather (&rest promises)
  "Promise of the values of PROMISES, in argument order (asyncio.gather).
   It rejects with the first rejection; the other promises keep running. A
   non-promise argument stands for its own value. (await (gather a b c))."
  (blackbird:all promises))

(defun run-promise (thunk &key (backend *event-backend*) timeout)
  "Run a promise to completion from synchronous code (asyncio.run).

   Makes a fresh loop on BACKEND (default *EVENT-BACKEND*), binds
   *EVENT-BACKEND* / *EVENT-LOOP* around THUNK, AWAITs the promise THUNK
   returns (a non-promise value is returned as it is) and closes the loop,
   pending handles included, even on a non-local exit. Returns the promise's
   value(s); TIMEOUT is AWAIT's."
  (check-type thunk function)
  (unless backend
    (error 'event-error
           :message "run-promise: pass :backend or bind *event-backend*"))
  (let ((loop (make-event-loop backend)))
    (unwind-protect
        (with-event-backend (backend)
          (with-event-loop-var (loop)
            (let ((result (multiple-value-list (funcall thunk))))
              (if (typep (first result) 'blackbird:promise)
                  (await (first result) :timeout timeout)
                  (values-list result)))))
      (close-event-loop backend loop))))

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
