#!/usr/bin/env bash
# git-guardrails: PreToolUse hook that stops Claude Code from running git
# commands that throw work away. Plain `git push` stays allowed.
#
# Blocked: force push (--force, -f, --force-with-lease, --force-if-includes,
# +refspec), reset --hard, clean (any flags) and branch -D.
#
# This is a guardrail, not a sandbox: it splits the command into simple
# commands (on ; & | ( ) ` and newlines outside quotes, skipping heredoc
# bodies), unwraps sudo/env/bash -c, and checks each git invocation.

if ! command -v jq >/dev/null; then
  echo "BLOCKED by git-guardrails: jq is not installed, so commands can't be checked. Install jq." >&2
  exit 2
fi

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

# Prints one simple command per line. Quote marks are dropped but quoted text
# stays inside its command, so `git commit -m "a; git clean"` is one commit.
split_commands() {
  local line c next i quote="" heredoc=""
  while IFS= read -r line || [[ -n $line ]]; do
    if [[ -n $heredoc ]]; then
      [[ ${line#"${line%%[![:space:]]*}"} == "$heredoc" ]] && heredoc=""
      continue
    fi
    if [[ -z $quote && $line =~ (^|[^<])\<\<-?[[:space:]]*[\'\"]?([A-Za-z_][A-Za-z0-9_]*) ]]; then
      heredoc=${BASH_REMATCH[2]}
    fi
    for ((i = 0; i < ${#line}; i++)); do
      c=${line:i:1}
      next=${line:i+1:1}
      if [[ $quote == "'" ]]; then
        [[ $c == "'" ]] && quote="" || printf '%s' "$c"
        continue
      fi
      case $c in
        \\) printf '%s' "$next" && i=$((i + 1)) ;;
        \") [[ $quote == '"' ]] && quote="" || quote='"' ;;
        \') [[ -n $quote ]] && printf '%s' "$c" || quote="'" ;;
        '$') [[ $next == "(" ]] && printf '\n' && i=$((i + 1)) || printf '%s' "$c" ;;
        '`' | '(' | ')') printf '\n' ;;
        ';' | '&' | '|') [[ -n $quote ]] && printf '%s' "$c" || printf '\n' ;;
        *) printf '%s' "$c" ;;
      esac
    done
    [[ -n $quote ]] && printf ' ' || printf '\n'
  done <<<"$1"
}

while IFS= read -r segment; do
  read -ra tokens <<<"$segment"
  [[ ${tokens[0]:-} == "{" ]] && tokens=("${tokens[@]:1}")

  # Skip wrappers that still run git: sudo, env, VAR=value, bash -c "..."
  while [[ ${#tokens[@]} -gt 0 ]]; do
    case ${tokens[0]} in
      sudo | env | command | exec | nohup | time) tokens=("${tokens[@]:1}") ;;
      bash | sh | zsh)
        [[ ${tokens[1]:-} == -c ]] || break
        tokens=("${tokens[@]:2}")
        ;;
      -*) break ;;
      *=*) tokens=("${tokens[@]:1}") ;;
      *) break ;;
    esac
  done

  [[ ${tokens[0]:-} == git || ${tokens[0]:-} == */git ]] && check_git "${tokens[@]:1}"
done < <(split_commands "$command")

exit 0
