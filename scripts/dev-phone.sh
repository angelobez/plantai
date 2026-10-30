#!/usr/bin/env bash
#
# Runs the API for the app on a USB-connected phone.
# - Re-applies `adb reverse` of the API (3000) and of the S3 emulator (9000,
#   where the presigned photo URLs point) every time the phone (re)connects.
# - Runs `npm run start:dev` in api/, teeing its output to api/logs/dev.log,
#   where the e-mail codes show up when RESEND_API_KEY is unset.
#
# Run it in your own terminal, outside Claude Code, so it outlives the session.

set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
log="$root/api/logs/dev.log"
mkdir -p "$(dirname "$log")"

# The API, and the S3 emulator from api/compose.yaml.
ports=(3000 9000)

"$root/scripts/check-env.sh"

# A leftover API on 3000 (an old dev:phone, say) would answer the phone with old
# code while the new one dies on EADDRINUSE behind `nest --watch`.
if [[ -n "$(ss -ltnH 'sport = :3000')" ]]; then
  echo "[dev-phone] port 3000 is already taken; stop it and run again:" >&2
  pids="$(lsof -t -iTCP:3000 -sTCP:LISTEN 2>/dev/null | paste -sd, || true)"
  [[ -n "$pids" ]] && ps -o pid=,lstart=,args= -p "$pids" | sed 's/^/  /' >&2
  exit 1
fi
if ! (exec 3<>/dev/tcp/127.0.0.1/9000) 2>/dev/null; then
  echo "[dev-phone] the S3 emulator is not up on 9000; run: npm --prefix api run db:up" >&2
  exit 1
fi

forward_port() {
  while true; do
    adb wait-for-device
    for port in "${ports[@]}"; do
      adb reverse "tcp:$port" "tcp:$port" >/dev/null && echo "[dev-phone] adb reverse tcp:$port on $(adb get-serialno)"
    done
    adb wait-for-disconnect
    echo "[dev-phone] phone disconnected, waiting for it"
  done
}

forward_port &
trap 'kill $! 2>/dev/null' EXIT

cd "$root/api"
echo "[dev-phone] API log: $log"
npm run start:dev 2>&1 | tee "$log"
