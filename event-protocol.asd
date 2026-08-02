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
