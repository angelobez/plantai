#!/usr/bin/env bash
# git-guardrails: PreToolUse hook that stops Claude Code from running git
# commands that throw work away. Plain `git push` stays allowed.
#
# Blocked: force push (--force, -f, --force-with-lease, --force-if-includes,
# +refspec), reset --hard, clean (any flags) and branch -D.
#
# This is a guardrail, not a sandbox: it reads each git invocation in the
# command (split on ; && || | $( and newlines) and ignores the rest.

command=$(jq -r '.tool_input.command // empty')

block() {
  echo "BLOCKED by git-guardrails: $1. Ask the user to run it if it is really needed." >&2
  exit 2
}

check_git() {
  local -a args=("$@")
  local i=0

  # Skip global options to reach the subcommand (git -C dir -c k=v push ...)
  while [[ $i -lt ${#args[@]} && ${args[i]} == -* ]]; do
    case ${args[i]} in
      -C | -c | --git-dir | --work-tree | --namespace) i=$((i + 2)) ;;
      *) i=$((i + 1)) ;;
    esac
  done

  local subcommand=${args[i]:-}
  local -a rest=("${args[@]:i+1}")
  local arg delete=false force=false

  case $subcommand in
    push)
      for arg in "${rest[@]}"; do
        case $arg in
          --force | --force=* | --force-with-lease | --force-with-lease=* | --force-if-includes)
            block "force push ($arg)" ;;
          --*) ;;
          -*f*) block "force push ($arg)" ;;
          +*) block "force push via refspec ($arg)" ;;
        esac
      done
      ;;
    reset)
      for arg in "${rest[@]}"; do
        [[ $arg == --hard ]] && block "git reset --hard"
      done
      ;;
    clean)
      block "git clean"
      ;;
    branch)
      for arg in "${rest[@]}"; do
        case $arg in
          --delete) delete=true ;;
          --force) force=true ;;
          --*) ;;
          -*D*) block "git branch $arg" ;;
          -*d*f* | -*f*d*) delete=true force=true ;;
          -*d*) delete=true ;;
          -*f*) force=true ;;
        esac
      done
      [[ $delete == true && $force == true ]] && block "git branch force delete"
      ;;
  esac
}

segments=$(printf '%s\n' "$command" | sed -E 's/&&|\|\||;|\||\$\(|`/\n/g')

while IFS= read -r segment; do
  # Quotes and closing parens around a git call aren't part of its arguments
  segment=${segment//[\"\')]/ }
  read -ra tokens <<<"$segment"
  [[ ${tokens[0]:-} == "(" || ${tokens[0]:-} == "{" ]] && tokens=("${tokens[@]:1}")
  tokens[0]=${tokens[0]#(}
  [[ ${tokens[0]:-} == git ]] && check_git "${tokens[@]:1}"
done <<<"$segments"

exit 0
