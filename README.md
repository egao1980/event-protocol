# event-protocol

MIT. Tiny CLOS **event-loop protocol** for [cl-stack](https://github.com/egao1980/cl-stack).

Generics + conditions + shared conformance suite. **No natives here.**

| Layer | Repo |
|-------|------|
| Protocol | this repo |
| Default backend (Windows-primary) | [`egao1980/event-backend-libuv`](https://github.com/egao1980/event-backend-libuv) |
| Second backend (Unix) | [`egao1980/event-backend-libev`](https://github.com/egao1980/event-backend-libev) |
| Optional BT pools (backends, not this protocol) | [`egao1980/cl-stack-executors`](https://github.com/egao1980/cl-stack-executors) |

**Brief:** [cl-stack `docs/capabilities/event-protocol.md`](https://github.com/egao1980/cl-stack/blob/main/docs/capabilities/event-protocol.md)

App DX (promises) is the secondary ASDF system `event-protocol/promises`
(package `event-protocol/promises`, nickname `stack-event-promises`):
`defer-promise`, `sleep-promise`, `submit-promise`, `cancel-promise`, `await`,
`gather`, `run-promise`. Blackbird lives only in that system. **Backends stay
callback + cancel tokens.**

## Promises from synchronous code (asyncio shape)

| Python | event-protocol/promises |
|--------|-------------------------|
| `asyncio.run(main())` | `(run-promise (lambda () …promise…) :backend b)` (fresh loop, bound, awaited, closed) |
| `await aw` / `loop.run_until_complete(aw)` | `(await promise :timeout s)` on the bound loop |
| `asyncio.gather(a, b, c)` | `(gather a b c)` (promise of the values, in argument order) |
| `asyncio.wait_for(aw, s)` timeout | `await-timeout` (an `event-error`, `await-timeout-seconds`) |

```lisp
(asdf:load-system "event-protocol/promises")
(asdf:load-system "event-backend-libuv")
(asdf:load-system "cl-stack-http")

(stack-event-promises:run-promise
 (lambda ()
   (stack-event-promises:gather
    (stack-http:get-async "https://httpbin.org/get")
    (stack-http:get-async "https://httpbin.org/uuid")))
 :backend (event-backend-libuv:make-libuv-backend)
 :timeout 30)
;; => (#<HTTP-RESPONSE> #<HTTP-RESPONSE>)
```

`await` takes a Blackbird promise or a `(lambda (resolve reject) …)` starter.
It runs the loop with `:stop-when-idle nil` and stops it as soon as the
promise settles, so idle pooled connections or timers left on the loop do
not hold it. A plain `(run backend loop)` waits for those. Its timeout timer
is canceled when the promise settles first. `run-promise` closes its loop on
every exit, which cancels any handles still pending on it. A THUNK that
returns a plain value gets that value back.

## Load / test

```bash
cl-repo test        # event-protocol/tests + event-protocol/promises/tests
```

Conformance suite: ASDF system `event-protocol/conformance` (set
`event-protocol/conformance:*test-backend-maker*` from a backend test system).
Provenance: [`tests/conformance/PROVENANCE.md`](tests/conformance/PROVENANCE.md).

## Adding backend C later

1. New repo `event-backend-<name>` depending on `event-protocol` (+ natives/overlays as needed).
2. Implement the generics on an `event-backend` subclass (`run` / `defer` / `sleep*` / `cancel` / `register-io` / `wake` / `wake-call`). `submit` default method is hop-back only (`:executor` a function of one thunk). The default hop-off runner is a backend choice — typically a per-loop [`cl-stack-executors`](https://github.com/egao1980/cl-stack-executors) thread pool. Do not put a pool in this repo; do not specialize libuv onto `uv_queue_work` for blocking I/O.
3. Test system sets `event-protocol/conformance:*test-backend-maker*` to a zero-arg thunk that returns a fresh backend, then `(asdf:test-system …)` / `rove:run` of `event-protocol/conformance`.
4. CI: pull `event-protocol` from `ghcr.io/egao1980/cl-systems` via cl-repo (OCI includes `event-protocol/conformance`). Install natives / overlays, run conformance. Optional OCI publish via cl-repository reusable workflow (`native-<os>-<arch>` artifacts; nested `lib/` + `grovel/` when shipping `cffi-grovel-output`).
5. Document the system in the cl-stack event brief; do **not** add a plugin registry.

## CI

CI: canned [`cl-repository`](https://github.com/egao1980/cl-repository) (`test-system.yml` / `setup-client` + `ci`). Deps from `ghcr.io/egao1980/cl-systems`. Backend CI lives in the backend repos.

Tracking: [cl-stack#15](https://github.com/egao1980/cl-stack/issues/15) · [#2](https://github.com/egao1980/cl-stack/issues/2) · [#18](https://github.com/egao1980/cl-stack/issues/18).

## Publish

Owning-repo canned [`publish-source.yml`](https://github.com/egao1980/cl-repository/blob/main/.github/workflows/publish-source.yml):

```bash
gh workflow run publish-checkout.yml -R egao1980/event-protocol
```

