# event-protocol

MIT. Tiny CLOS **event-loop protocol** for [cl-stack](https://github.com/egao1980/cl-stack).

Generics + conditions + shared conformance suite. **No natives here.**

| Layer | Repo |
|-------|------|
| Protocol | this repo |
| Default backend (Windows-primary) | [`egao1980/event-backend-libuv`](https://github.com/egao1980/event-backend-libuv) |
| Second backend (Unix) | [`egao1980/event-backend-libev`](https://github.com/egao1980/event-backend-libev) |

**Brief:** [cl-stack `docs/capabilities/event-protocol.md`](https://github.com/egao1980/cl-stack/blob/main/docs/capabilities/event-protocol.md)

App DX (promises) lives in a later facade — backends stay callback + cancel tokens.

## Load / test

```bash
sbcl --eval '(asdf:load-asd "event-protocol.asd")' \
     --eval '(asdf:test-system "event-protocol")'
```

Conformance suite: ASDF system `event-protocol/conformance` (set
`event-protocol/conformance:*test-backend-maker*` from a backend test system).
Provenance: [`tests/conformance/PROVENANCE.md`](tests/conformance/PROVENANCE.md).

## CI

Same bootstrap as [`cl-repository`](https://github.com/egao1980/cl-repository): Roswell
`install-for-ci.sh` → pinned `sbcl-bin` → `qlot install` → `qlot exec ros`. Backend CI
lives in the backend repos.

Tracking: [cl-stack#15](https://github.com/egao1980/cl-stack/issues/15) · [#2](https://github.com/egao1980/cl-stack/issues/2).
