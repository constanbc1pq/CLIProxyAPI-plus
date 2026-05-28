#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

CONFIG="${CONFIG:-./config.yaml}"
BIN="./bin/cli-proxy-api"

if [[ ! -f "$CONFIG" ]]; then
  echo "config file not found: $CONFIG" >&2
  exit 1
fi

# Rebuild if binary missing or any Go source is newer than it.
needs_build=0
if [[ ! -x "$BIN" ]]; then
  needs_build=1
elif [[ -n "$(find cmd internal sdk -name '*.go' -newer "$BIN" -print -quit 2>/dev/null)" ]]; then
  needs_build=1
fi

if [[ "$needs_build" == "1" ]]; then
  echo ">> building $BIN ..."
  mkdir -p ./bin
  go build -o "$BIN" ./cmd/server
fi

# Stop any previous instance on the same port (best-effort).
PORT="$(awk '/^port:/ {print $2; exit}' "$CONFIG")"
PORT="${PORT:-8317}"
if command -v ss >/dev/null 2>&1; then
  pids="$(ss -tlnpH "sport = :$PORT" 2>/dev/null | grep -oP 'pid=\K[0-9]+' | sort -u || true)"
  if [[ -n "$pids" ]]; then
    echo ">> killing previous process on :$PORT (pid=$pids)"
    kill $pids 2>/dev/null || true
    sleep 1
  fi
fi

echo ">> starting $BIN -config $CONFIG (port $PORT)"
exec "$BIN" -config "$CONFIG" "$@"
