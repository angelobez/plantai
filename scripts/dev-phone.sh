#!/usr/bin/env bash
#
# Runs the API for the app on a USB-connected phone.
# - Re-applies `adb reverse tcp:3000 tcp:3000` every time the phone (re)connects.
# - Runs `npm run start:dev` in api/, teeing its output to api/logs/dev.log,
#   where the e-mail codes show up when RESEND_API_KEY is unset.
#
# Run it in your own terminal, outside Claude Code, so it outlives the session.

set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
log="$root/api/logs/dev.log"
mkdir -p "$(dirname "$log")"

forward_port() {
  while true; do
    adb wait-for-device
    adb reverse tcp:3000 tcp:3000 >/dev/null && echo "[dev-phone] adb reverse tcp:3000 on $(adb get-serialno)"
    adb wait-for-disconnect
    echo "[dev-phone] phone disconnected, waiting for it"
  done
}

forward_port &
trap 'kill $! 2>/dev/null' EXIT

cd "$root/api"
echo "[dev-phone] API log: $log"
npm run start:dev 2>&1 | tee "$log"
