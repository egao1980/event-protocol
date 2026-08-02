#!/usr/bin/env bash
# Load ASDF system (runs grovel) and copy processed grovel Lisp into grovel/<os>-<arch>/.
# Usage: ./scripts/stage-grovel.sh event-backend-libuv
# Env: EVENT_PROTOCOL_UV_INCLUDE / EVENT_PROTOCOL_EV_INCLUDE, HOMEBREW_PREFIX
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SYS="${1:?system name (event-backend-libuv|event-backend-libev)}"

uname_s="$(uname -s)"
uname_m="$(uname -m)"
case "$uname_s" in
  Linux) os=linux ;;
  Darwin) os=darwin ;;
  MINGW*|MSYS*|CYGWIN*) os=windows ;;
  *) echo "unsupported OS: $uname_s" >&2; exit 1 ;;
esac
case "$uname_m" in
  x86_64|amd64) arch=amd64 ;;
  aarch64|arm64) arch=arm64 ;;
  *) echo "unsupported arch: $uname_m" >&2; exit 1 ;;
esac

DEST="$ROOT/grovel/${os}-${arch}"
mkdir -p "$DEST"

export HOMEBREW_PREFIX="${HOMEBREW_PREFIX:-}"
if [[ -z "${HOMEBREW_PREFIX}" && -d /opt/homebrew ]]; then
  export HOMEBREW_PREFIX=/opt/homebrew
fi

LOG="$(mktemp)"
sbcl --non-interactive \
  --eval "(asdf:load-asd #p\"${ROOT}/event-protocol.asd\")" \
  --eval "(asdf:load-asd #p\"${ROOT}/${SYS}.asd\")" \
  --eval "(asdf:load-system \"${SYS}\")" \
  --eval "(format t \"LOADED~%\")" \
  >"$LOG" 2>&1 || { tail -80 "$LOG"; exit 1; }

# Find newest grovel.processed-grovel-file under the cache for this system path.
CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/common-lisp"
PROCESSED="$(find "$CACHE" -path "*backends/*/grovel.processed-grovel-file" -newer "$ROOT/${SYS}.asd" 2>/dev/null | head -1 || true)"
if [[ -z "$PROCESSED" ]]; then
  PROCESSED="$(find "$CACHE" -name 'grovel.processed-grovel-file' 2>/dev/null | xargs ls -t 2>/dev/null | head -1 || true)"
fi
if [[ -z "$PROCESSED" || ! -f "$PROCESSED" ]]; then
  echo "could not locate grovel.processed-grovel-file; log:" >&2
  tail -40 "$LOG" >&2
  exit 1
fi

cp -f "$PROCESSED" "$DEST/grovel.cffi.lisp"
echo "staged $DEST/grovel.cffi.lisp from $PROCESSED"
