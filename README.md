# event-protocol

MIT. Tiny CLOS **event-loop protocol** for [cl-stack](https://github.com/egao1980/cl-stack).

| Layer | System | Notes |
|-------|--------|-------|
| Protocol | `event-protocol` | Generics + conditions |
| Default backend | `event-backend-libuv` | **Windows / linux / darwin** |
| Second backend | `event-backend-libev` | **Unix only** (Woo-adjacent) |

**Brief:** [cl-stack `docs/capabilities/event-protocol.md`](https://github.com/egao1980/cl-stack/blob/main/docs/capabilities/event-protocol.md)

App DX (promises) lives in a later facade — backends stay callback + cancel tokens.

## Grovel / overlays

- ASDF declares `(cffi-grovel:grovel-file "grovel")` for local-dev (needs `uv.h` / `ev.h` + CC).
- Overlay CI grovels per os/arch and ships `cffi-grovel-output` → `grovel-cache/` via [cl-repository](https://github.com/egao1980/cl-repository). Consumers load **without** a C toolchain.
- Natives: `libuv` / `libev` under `lib/<os>-<arch>/` (`native-library` role).

```bash
./scripts/build-libuv.sh          # or build-libuv.ps1 on Windows
export EVENT_PROTOCOL_UV_INCLUDE=...
./scripts/stage-grovel.sh event-backend-libuv
```

## Load / test

```bash
# protocol only
sbcl --eval '(asdf:load-asd "event-protocol.asd")' \
     --eval '(asdf:test-system "event-protocol")'

# conformance × libuv (needs libuv + headers for first grovel)
export HOMEBREW_PREFIX=/opt/homebrew   # macOS
sbcl --eval '(asdf:load-asd "event-protocol.asd")' \
     --eval '(asdf:load-asd "event-backend-libuv.asd")' \
     --eval '(asdf:test-system "event-protocol/conformance")'

# libev (Unix)
sbcl --eval '(asdf:load-asd "event-backend-libev.asd")' \
     --eval '(asdf:test-system "event-protocol/conformance/libev")'
```

## Conformance provenance

Case ideas from **CPython asyncio** (PSF) and **libuv / Node** (MIT) — see
[`tests/conformance/PROVENANCE.md`](tests/conformance/PROVENANCE.md). Original
Rove tests; no upstream sources vendored.

Tracking: [cl-stack#16](https://github.com/egao1980/cl-stack/issues/16) · [#17](https://github.com/egao1980/cl-stack/issues/17) · [#18](https://github.com/egao1980/cl-stack/issues/18) (parent [#2](https://github.com/egao1980/cl-stack/issues/2)).
