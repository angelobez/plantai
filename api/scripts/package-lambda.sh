#!/usr/bin/env bash
#
# Builds the Lambda package in build/lambda: the compiled API (dist/), its
# package.json and the production node_modules for Linux x86_64 (glibc), the
# platform of the function. The native modules (argon2, sharp) come as
# prebuilt binaries for that platform, so the package can be built on any
# machine, but it is checked on Linux x86_64 (scripts/check-lambda-package.sh).
#
# Every entry of the package is a handler: dist/lambda.handler (the API) and,
# later, other files under dist/ (the maintenance routine).

set -euo pipefail

api="$(cd "$(dirname "$0")/.." && pwd)"
out="$api/build/lambda"

cd "$api"
npm run build --silent

rm -rf "$out"
mkdir -p "$out"
cp -R dist package.json package-lock.json "$out/"

cd "$out"
# --ignore-scripts: argon2 would try to compile itself for this machine; its
# prebuilt binaries are loaded at runtime by node-gyp-build instead.
npm ci --omit=dev --ignore-scripts --os=linux --cpu=x64 --libc=glibc \
  --no-audit --no-fund --loglevel=error
rm package-lock.json

# argon2 ships prebuilt binaries for every platform; keep only Linux x86_64.
find node_modules/argon2/prebuilds -mindepth 1 -maxdepth 1 -type d \
  ! -name 'linux-x64' -exec rm -rf {} +

# Lambda's limit is 250 MB unzipped. Type declarations and source maps of the
# dependencies are not run, and typescript is only a peer of @nestjs/swagger's
# compile-time plugin.
find node_modules \( -name '*.d.ts' -o -name '*.d.mts' -o -name '*.d.cts' \
  -o -name '*.map' \) -type f -delete
rm -rf node_modules/typescript

echo "[package-lambda] $(du -sh . | cut -f1) in $out"
