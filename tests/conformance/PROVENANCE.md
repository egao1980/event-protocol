# Conformance test provenance

Case *ideas* and behavioral expectations are informed by upstream suites.
This tree contains **original Common Lisp / Rove tests** — upstream sources
are **not** vendored.

## CPython asyncio — **permitted (PSF License v2)**

- Upstream: https://github.com/python/cpython
- Tests: `Lib/test/test_asyncio/` especially `test_events.py`
  (`test_call_soon`, `test_call_later`, `test_call_soon_threadsafe`,
  reader/writer cancel cases)
- License: **PSF License Agreement** (permissive; retain copyright notice when
  redistributing PSF material — we do not copy source files)

Mapped protocol ops:

| asyncio | event-protocol |
|---------|----------------|
| `call_soon` | `defer` / `call-soon` |
| `call_later` | `sleep*` |
| `call_soon_threadsafe` | `wake-call` |
| `run_in_executor` | `submit` |
| `add_reader` / cancel | `register-io` + `cancel` |
| `loop.stop` | `stop` |

## Node.js / libuv — **permitted (MIT)**

- libuv tests: https://github.com/libuv/libuv/tree/v1.x/test  
  (`test-timer.c`, `test-idle.c`, `test-async.c`, `test-poll.c`,
  `test-loop-stop.c`, `test-run-once.c`, …)
- Node.js: https://github.com/nodejs/node (MIT) — timer / next-tick *ideas*
  only; we do not port V8-specific async_hooks suites
- License: **MIT** (Joyent / Node / libuv contributors)

## Scope

Protocol-level only (callbacks + cancel tokens). Out of scope here:

- asyncio Tasks / Futures / await (facade / promises later)
- Node async_hooks / promises A+
- Full libuv handle zoo (TCP/UDP/FS/process)

If a concrete input/output vector is taken with only trivial adaptation, note
it next to that `deftest` and retain:

> Copyright © 2001–present Python Software Foundation; All Rights Reserved.  
> Copyright Joyent, Inc. and other Node contributors; MIT License.  
> Copyright libuv project contributors; MIT License.
