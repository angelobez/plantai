#!/usr/bin/env bash
#
# Runs the API for the app on the phone, by USB cable or, with --wifi, over the
# home network.
# - USB: re-applies `adb reverse` of the API (3000) and of the S3 emulator (9000,
#   where the presigned photo URLs point) every time the phone (re)connects.
# - --wifi: no adb; the presigned photo URLs point at the notebook's LAN IP
#   (S3_ENDPOINT overrides api/.env), and it warns when the installed APK was
#   built for another IP (`npm run apk:wifi` rebuilds it).
# - Applies the pending migrations (`npm run db:migrate` in api/), so a merge
#   that adds a table does not leave the phone with 500s.
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

wifi=false
[[ "${1:-}" == "--wifi" ]] && wifi=true

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

# drizzle-kit exits 1 with no reason when the database is unreachable.
echo "[dev-phone] applying pending migrations"
if ! (cd "$root/api" && npm run --silent db:migrate); then
  echo "[dev-phone] db:migrate failed; is the database up? run: npm --prefix api run db:up" >&2
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

if $wifi; then
  ip="$("$root/scripts/lan-ip.sh")"
  export S3_ENDPOINT="http://$ip:9000"
  built="$(cat "$root/app/build/api-base-url" 2>/dev/null || true)"
  if [[ "$built" != "http://$ip:3000" ]]; then
    echo "[dev-phone] the last APK was built for '${built:-unknown}', not http://$ip:3000; run: npm run apk:wifi" >&2
  fi
  echo "[dev-phone] Wi-Fi: on the phone's browser, http://$ip:3000/v1/health should answer"
else
  forward_port &
  trap 'kill $! 2>/dev/null' EXIT
fi

cd "$root/api"
echo "[dev-phone] API log: $log"
npm run start:dev 2>&1 | tee "$log"
