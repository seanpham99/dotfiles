#!/usr/bin/env bash
# PreToolUse hook for the Explore subagent: Bash is allowed only for read-only
# inspection (git history, GitHub state, text search). Allowlist, not denylist:
# every segment of a compound command must match, or the call is blocked (exit 2).
cmd=$(jq -r '.tool_input.command // empty')
deny() { echo "BLOCKED (Explore is read-only): $1. Allowed: git log/show/diff/grep/status/blame/ls-files/rev-parse/rev-list/merge-base, gh pr|issue|label|run|release|repo view/list/diff/checks/status, gh api (GET), rg/grep/ls/cat/head/tail/wc/find/jq/sort/uniq/cut/tr/stat/du/tree." >&2; exit 2; }

# Substitution runs even inside double quotes, so check the raw command for it.
[[ $cmd == *'$('* || $cmd == *'`'* || $cmd == *'<('* ]] && deny "command substitution"
# Quoted text is data: blank it so a pattern like "a|b" or "x>y" is not read as a pipe or redirect.
bare=$(sed -E "s/'[^']*'/''/g; s/\"[^\"]*\"/\"\"/g" <<<"$cmd")
# Interleaved or escaped quotes leave a stray quote that could hide a segment.
[[ $(sed -E "s/''//g; s/\"\"//g" <<<"$bare") == *[\'\"]* ]] && deny "unbalanced or nested quotes"
# Harmless redirections pass; any other redirection writes a file.
s=$(sed -E 's/[0-9]?>&[0-9]//g; s/[0-9]?>[[:space:]]*\/dev\/null//g' <<<"$bare")
[[ $s == *'>'* ]] && deny "output redirection"

while IFS= read -r seg; do
  seg="${seg#"${seg%%[![:space:]]*}"}"; seg="${seg%"${seg##*[![:space:]]}"}"
  [[ -z $seg ]] && continue
  read -r -a w <<<"$seg"
  case "${w[0]}" in
    cd|pwd|echo|true|grep|ls|cat|head|tail|wc|jq|cut|tr|stat|du|file|basename|dirname|realpath|column) ;;
    rg)
      [[ $seg =~ [[:space:]]--pre([[:space:]=]|$) ]] && deny "rg --pre runs a command" ;;
    sort)
      [[ $seg =~ [[:space:]](-o|--output)([[:space:]=]|$) || $seg =~ [[:space:]]-[a-zA-Z]*o ]] && deny "sort -o writes a file" ;;
    uniq)
      args=0; for x in "${w[@]:1}"; do [[ $x == -* ]] || args=$((args+1)); done
      [[ $args -ge 2 ]] && deny "uniq with an output file" ;;
    tree)
      [[ $seg =~ [[:space:]]-o([[:space:]]|$) ]] && deny "tree -o writes a file" ;;
    find)
      [[ $seg =~ (^|[[:space:]])-(delete|exec|execdir|ok|okdir|fprint|fprint0|fprintf|fls)([[:space:]]|$) ]] && deny "find with a write/exec action" ;;
    git)
      i=1; while [[ ${w[$i]} == -C ]]; do i=$((i+2)); done
      [[ ${w[$i]} == -c || ${w[$i]} == --* ]] && deny "git config overrides (-c, --exec-path, ...)"
      [[ $seg =~ [[:space:]]--output([[:space:]=]|$) ]] && deny "git --output writes a file"
      case "${w[$i]}" in
        log|show|diff|status|blame|ls-files|ls-tree|rev-parse|rev-list|merge-base|describe|shortlog|cat-file|for-each-ref|show-ref) ;;
        grep)
          [[ $seg =~ [[:space:]](-O|--open-files-in-pager) ]] && deny "git grep -O runs a pager command" ;;
        branch|tag|remote|worktree|stash)
          [[ $seg =~ [[:space:]](-[dDmMcCf]|--delete|--force|--move|--copy|add|remove|rm|prune|set-url|rename|push|pop|drop|apply|clear|move|lock|unlock|repair)([[:space:]]|$) ]] && deny "git ${w[$i]} mutation"
          [[ ${w[$i]} == stash && ${#w[@]} -gt $((i+1)) && ${w[$((i+1))]} != list && ${w[$((i+1))]} != show ]] && deny "git stash mutation" ;;
        *) deny "git ${w[$i]}" ;;
      esac ;;
    gh)
      case "${w[1]}" in
        pr|issue|label|run|release|repo|workflow|search)
          [[ ${w[1]} == search || ${w[2]} =~ ^(view|list|diff|checks|status)$ ]] || deny "gh ${w[1]} ${w[2]}" ;;
        api)
          [[ $seg =~ [[:space:]](-X|--method|-f|-F|--field|--raw-field|--input)([[:space:]=]|$) ]] && deny "gh api with a method or body" ;;
        *) deny "gh ${w[1]}" ;;
      esac ;;
    *) deny "${w[0]}" ;;
  esac
done < <(sed -E 's/(\&\&|\|\||;|\||&)/\n/g' <<<"$s")
exit 0
