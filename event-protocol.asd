(defsystem "event-protocol"
  :version "0.2.1"
  :description "Tiny CLOS event-loop protocol for cl-stack (generics + conditions)"
  :author "egao1980"
  :license "MIT"
  :depends-on ()

  :serial t
  :pathname "src"
  :components ((:file "package")
               (:file "conditions")
               (:file "protocol"))
  :in-order-to ((test-op (test-op "event-protocol/tests")))
  :properties
  (:cl-repo (:provides ("event-protocol" "event-protocol/conformance"
                       "event-protocol/promises"))))

(defsystem "event-protocol/tests"
  :depends-on ("event-protocol" "rove")
  :pathname "tests"
  :serial t
  :components ((:file "package")
               (:file "protocol-test"))
  :perform (test-op (o c)
             (unless (symbol-call :rove :run c)
               (error "tests failed for ~A" (component-name c)))))

;;; Shared Rove suite — backends set *TEST-BACKEND-MAKER* and call (rove:run this).
(defsystem "event-protocol/conformance"
  :description "Backend-agnostic event-protocol conformance suite (Rove)"
  :depends-on ("event-protocol" "rove")
  :pathname "tests/conformance"
  :serial t
  :components ((:file "package")
               (:file "suite")
               (:file "asyncio-call")
               (:file "asyncio-io")
               (:file "wake-thread")
               (:file "submit")
               (:file "libuv-loop")))
  ;; Backends set *test-backend-maker* then (rove:run (asdf:find-system "event-protocol/conformance")).

;;; Promise facade — Blackbird stays out of the core system.
(defsystem "event-protocol/promises"
  :description "Blackbird promise facade over event-protocol (callback + cancel)"
  :depends-on ("event-protocol" "blackbird")
  :serial t
  :pathname "src"
  :components ((:file "promises-package")
               (:file "promises"))
  :in-order-to ((test-op (test-op "event-protocol/promises/tests"))))

(defsystem "event-protocol/promises/tests"
  :depends-on ("event-protocol/promises" "rove")
  :pathname "tests/promises"
  :serial t
  :components ((:file "package")
               (:file "promises-test"))
  :perform (test-op (o c)
             (unless (symbol-call :rove :run c)
               (error "tests failed for ~A" (component-name c)))))
