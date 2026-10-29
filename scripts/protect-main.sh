#!/usr/bin/env bash
# Applies the branch protection for `main` (spec #22, "CI e proteção da main"):
# PR required with zero approvals, the `ci` check required and up to date with
# `main`, rules enforced for admins too, no force pushes and no deletions.
# Needs `gh` authenticated with admin rights on the repository.
# Usage: scripts/protect-main.sh [owner/repo]
set -euo pipefail

repo="${1:-$(gh repo view --json nameWithOwner --jq .nameWithOwner)}"

gh api --method PUT "repos/$repo/branches/main/protection" --input - <<'JSON'
{
  "required_status_checks": {
    "strict": true,
    "checks": [{ "context": "ci" }]
  },
  "enforce_admins": true,
  "required_pull_request_reviews": {
    "required_approving_review_count": 0,
    "dismiss_stale_reviews": false,
    "require_code_owner_reviews": false
  },
  "restrictions": null,
  "allow_force_pushes": false,
  "allow_deletions": false
}
JSON

echo "Branch protection applied to $repo:main"
