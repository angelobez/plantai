#!/usr/bin/env bash
#
# Builds the release APK and installs it on the phone adb sees (by cable or by
# Android's wireless debugging), keeping the app's session and data.
# - No flag: the app talks to http://localhost:3000, for `npm run dev:phone`.
# - --wifi: the app talks to the notebook's LAN IP, for `npm run dev:wifi`.
#   The IP is baked into the APK, so when the router hands the notebook a new
#   one, run this again (dev:wifi warns when they differ).
# Without a phone in `adb devices` it only builds.

set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
app="$root/app"
apk="$app/build/app/outputs/flutter-apk/app-release.apk"
# Public: Google issues the ID token for this Web client (see the README).
google_client_id=431388587561-jhgntmp6i18htkblrnopm61b0h3815ld.apps.googleusercontent.com

host=localhost
[[ "${1:-}" == "--wifi" ]] && host="$("$root/scripts/lan-ip.sh")"
api="http://$host:3000"

cd "$app"
echo "[build-apk] building for $api"
flutter pub get >/dev/null
flutter build apk --release \
  --dart-define=API_BASE_URL="$api" \
  --dart-define=GOOGLE_SERVER_CLIENT_ID="$google_client_id"
echo "$api" >"$app/build/api-base-url"

if [[ -n "$(adb devices | sed 1d | grep -w device)" ]]; then
  adb install -r "$apk"
else
  echo "[build-apk] no phone in 'adb devices'; built only: $apk"
fi
