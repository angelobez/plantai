#!/usr/bin/env bash
#
# Prepares a git worktree of this repo for work: root npm ci (it also creates
# .husky/_, without which the pre-commit hook is silently skipped), api/ npm ci
# and flutter pub get. Run it from inside the worktree, and again after a merge
# that changes a package-lock.json or pubspec.lock.
#
# --env copies api/.env from the main checkout; only db:generate and start:dev
# need it (tests use test/support/env.ts). It is gitignored: never commit it.

set -euo pipefail

root="$(git rev-parse --show-toplevel)"
main="$(git worktree list --porcelain | awk '/^worktree /{print $2; exit}')"

(cd "$root" && npm ci --silent)
(cd "$root/api" && npm ci --silent)
(cd "$root/app" && flutter pub get >/dev/null)

if [[ "${1:-}" == "--env" && "$root" != "$main" ]]; then
  cp "$main/api/.env" "$root/api/.env"
fi

echo "[setup-worktree] ready: $root"
