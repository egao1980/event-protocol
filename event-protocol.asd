(defsystem "event-protocol"
  :version "0.1.0"
  :description "Tiny CLOS event-loop protocol for cl-stack (generics + conditions)"
  :author "egao1980"
  :license "MIT"
  :depends-on ()
  :serial t
  :pathname "src"
  :components ((:file "package")
               (:file "conditions")
               (:file "protocol"))
  :in-order-to ((test-op (test-op "event-protocol/tests"))))

(defsystem "event-protocol/tests"
  :depends-on ("event-protocol" "rove")
  :pathname "tests"
  :serial t
  :components ((:file "package")
               (:file "protocol-test"))
  :perform (test-op (o c) (symbol-call :rove :run c)))

(defsystem "event-protocol/conformance"
  :description "Rove conformance suite × event backends (libuv required; libev Unix)"
  :depends-on ("event-protocol" "event-backend-libuv" "rove")
  :pathname "tests/conformance"
  :serial t
  :components ((:file "package")
               (:file "suite")
               (:file "asyncio-call")
               (:file "asyncio-io")
               (:file "wake-thread")
               (:file "libuv-loop")
               (:file "libuv-test"))
  :perform (test-op (o c) (symbol-call :rove :run c)))

(defsystem "event-protocol/conformance/libev"
  :description "Run conformance suite against libev (Unix)"
  :depends-on ("event-protocol/conformance" "event-backend-libev")
  :pathname "tests/conformance"
  :serial t
  :components ((:file "package")
               (:file "suite")
               (:file "asyncio-call")
               (:file "asyncio-io")
               (:file "wake-thread")
               (:file "libuv-loop")
               (:file "libev-test"))
  :perform (test-op (o c) (symbol-call :rove :run c)))
