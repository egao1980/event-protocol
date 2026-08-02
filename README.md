# event-protocol

MIT. Tiny CLOS **event-loop protocol** for [cl-stack](https://github.com/egao1980/cl-stack).

Generics + conditions only — no natives here. Backends (`libuv`, `libev`) and overlays ship separately.

**Brief (locked):** [cl-stack `docs/capabilities/event-protocol.md`](https://github.com/egao1980/cl-stack/blob/main/docs/capabilities/event-protocol.md)

| Decision | Choice |
|----------|--------|
| App DX | Promises (facade; not this system) |
| Default backend | libuv |
| Second backend | libev |

## Load / test

```bash
sbcl --eval '(asdf:load-asd "event-protocol.asd")' \
     --eval '(asdf:test-system "event-protocol")'
```

Tracking: [egao1980/cl-stack#15](https://github.com/egao1980/cl-stack/issues/15) (parent [#2](https://github.com/egao1980/cl-stack/issues/2)).
