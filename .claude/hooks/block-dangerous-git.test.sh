#!/usr/bin/env bash
# Tests for block-dangerous-git.sh. Run: .claude/hooks/block-dangerous-git.test.sh
set -u

hook="$(dirname "$0")/block-dangerous-git.sh"
failures=0

run_hook() {
  jq -n --arg cmd "$1" '{tool_name: "Bash", tool_input: {command: $cmd}}' | "$hook" 2>/dev/null
}

expect_blocked() {
  run_hook "$1"
  local status=$?
  if [[ $status -ne 2 ]]; then
    echo "FAIL (expected blocked, got exit $status): $1"
    failures=$((failures + 1))
  fi
}

expect_allowed() {
  run_hook "$1"
  local status=$?
  if [[ $status -ne 0 ]]; then
    echo "FAIL (expected allowed, got exit $status): $1"
    failures=$((failures + 1))
  fi
}

# Force push in every spelling
expect_blocked 'git push --force'
expect_blocked 'git push -f origin main'
expect_blocked 'git push origin main --force-with-lease'
expect_blocked 'git push --force-with-lease=main:abc123 origin main'
expect_blocked 'git push --force-if-includes origin main'
expect_blocked 'git push -uf origin feature'
expect_blocked 'git push origin +main'

# Other destructive commands
expect_blocked 'git reset --hard'
expect_blocked 'git reset --hard HEAD~1'
expect_blocked 'git clean -fd'
expect_blocked 'git clean -n'
expect_blocked 'git branch -D feature'
expect_blocked 'git branch --delete --force feature'

# Global options and chained commands don't hide the subcommand
expect_blocked 'git -C api reset --hard'
expect_blocked 'git -c core.pager=cat push --force'
expect_blocked 'cd api && git reset --hard'
expect_blocked 'git status; git clean -fdx'
expect_blocked 'git fetch || git push -f'
expect_blocked 'echo "$(git reset --hard)"'
expect_blocked $'git add .\ngit push --force'

# Wrappers in front of git don't hide it either
expect_blocked 'sudo git reset --hard'
expect_blocked 'env GIT_TRACE=1 git clean -f'
expect_blocked 'GIT_TRACE=1 git push --force'
expect_blocked 'bash -c "git clean -fd"'
expect_blocked '/usr/bin/git branch -D feature'

# Plain push and everyday commands
expect_allowed 'git push'
expect_allowed 'git push -u origin feature-fix'
expect_allowed 'git push origin chore/force-update'
expect_allowed 'git reset HEAD file.txt'
expect_allowed 'git reset --soft HEAD~1'
expect_allowed 'git branch -d feature'
expect_allowed 'git status'
expect_allowed 'ls -la'
expect_allowed ''

# Words inside a commit message are not commands
expect_allowed 'git commit -m "block git clean and reset --hard"'
expect_allowed 'git commit -m "fix; git clean docs && git reset --hard"'
expect_allowed "git commit -m 'one | git push --force'"
expect_allowed $'git commit -F - <<\'EOF\'\nchore: tidy\n\ngit clean -fd is now blocked\nEOF'
expect_allowed $'cat <<EOF > notes.md\ngit reset --hard\nEOF\ngit status'

# ...but a command after the heredoc still counts
expect_blocked $'cat <<EOF > notes.md\nhello\nEOF\ngit reset --hard'

# Without jq nothing can be checked, so everything is blocked
echo '{"tool_input":{"command":"ls"}}' | PATH=/nonexistent "$BASH" "$hook" 2>/dev/null
if [[ $? -ne 2 ]]; then
  echo "FAIL (expected blocked without jq)"
  failures=$((failures + 1))
fi

if [[ $failures -gt 0 ]]; then
  echo "$failures test(s) failed"
  exit 1
fi
echo "All tests passed"
