#!/usr/bin/env bash
#
# Lists the keys of api/.env.example that are missing from api/.env, so a new
# variable added by a ticket shows up here instead of as a Zod error later.
# Commented keys in the example (optional ones) are not required.

set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
example="$root/api/.env.example"
env="$root/api/.env"

if [[ ! -f "$env" ]]; then
  echo "[check-env] api/.env not found; copy it from api/.env.example" >&2
  exit 1
fi

keys() { grep -oE '^[A-Z][A-Z0-9_]*=' "$1" | tr -d '=' | sort -u; }

missing="$(comm -23 <(keys "$example") <(keys "$env"))"
if [[ -n "$missing" ]]; then
  echo "[check-env] api/.env is missing keys from api/.env.example:" >&2
  sed 's/^/  - /' <<<"$missing" >&2
  exit 1
fi
