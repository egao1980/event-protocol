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
`defer-promise`, `sleep-promise`, `submit-promise`, `cancel-promise`, `await`.
Blackbird lives only in that system. **Backends stay callback + cancel tokens.**

## Load / test

```bash
sbcl --eval '(asdf:load-asd "event-protocol.asd")' \
     --eval '(asdf:test-system "event-protocol")' \
     --eval '(asdf:test-system "event-protocol/promises")'
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

