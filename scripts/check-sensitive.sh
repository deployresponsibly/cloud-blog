#!/usr/bin/env bash
# Scan for secrets and identifying values before they are committed.
#
#   scripts/check-sensitive.sh          check what is staged
#   scripts/check-sensitive.sh --all    check every tracked file
#
# Generic patterns live here. Values specific to the owner (old handles,
# account IDs, profile names, domains) live in .local/sensitive-patterns.txt,
# which is git-ignored: one extended regex per line, # for comments.
# Matches are reported as file:line only, never the matching text.
set -uo pipefail
cd "$(git rev-parse --show-toplevel)"

mode=staged
[[ "${1:-}" == "--all" ]] && mode=all

if [[ $mode == all ]]; then
  mapfile -t files < <(git ls-files)
else
  mapfile -t files < <(git diff --cached --name-only --diff-filter=ACMR)
fi

fail=0
report() { echo "FAIL: $1"; fail=1; }

read_file() {
  if [[ $mode == all ]]; then cat -- "$1"; else git show ":$1"; fi
}

# 1. Files that must never be tracked.
forbidden='(\.tfvars$|\.tfstate|(^|/)\.terraform/|(^|/)backend\.hcl$|(^|/)\.env|\.pem$|\.key$|\.bundle$|\.patch$|^\.local/)'
for f in "${files[@]}"; do
  [[ $f =~ $forbidden ]] && report "forbidden file tracked: $f"
done

# 2. Commit identity must be the GitHub noreply address.
email=$(git config user.email || true)
[[ $email == *@users.noreply.github.com ]] || report "git user.email is not a GitHub noreply address"

# 3. Generic secret and identifier patterns.
declare -A generic=(
  [aws-access-key]='(AKIA|ASIA)[0-9A-Z]{16}'
  [aws-secret-name]='aws_secret_access_key|aws_session_token'
  [private-key]='-----BEGIN [A-Z ]*PRIVATE KEY-----'
  [github-token]='gh[pousr]_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}'
  [arn-with-account]='arn:aws[a-z-]*:[a-z0-9-]*:[a-z0-9-]*:[0-9]{12}:'
  [account-id]='(^|[^0-9A-Za-z])[0-9]{12}([^0-9A-Za-z]|$)'
  [credential-assignment]='(secret|token|password|api[_-]?key)["'"'"' ]*[:=]["'"'"' ]*[A-Za-z0-9/+_-]{16,}'
)
skip_generic='(^|/)(package-lock\.json|\.terraform\.lock\.hcl|check-sensitive\.sh)$'

# 4. Owner-specific patterns.
local_patterns=()
if [[ -f .local/sensitive-patterns.txt ]]; then
  mapfile -t local_patterns < <(grep -vE '^\s*(#|$)' .local/sensitive-patterns.txt)
else
  echo "WARN: .local/sensitive-patterns.txt not found; owner-specific values were not checked"
fi

for f in "${files[@]}"; do
  [[ -f $f ]] || continue
  content=$(read_file "$f" 2>/dev/null) || continue
  # Skip binary files.
  grep -qI . <<<"$content" || continue

  if ! [[ $f =~ $skip_generic ]]; then
    for name in "${!generic[@]}"; do
      while IFS=: read -r line _; do
        [[ -n $line ]] && report "$name at $f:$line"
      done < <(grep -nE -- "${generic[$name]}" <<<"$content" | cut -d: -f1 | sed 's/$/:/')
    done
    # Email addresses, other than noreply and obvious placeholders.
    while IFS=: read -r line _; do
      [[ -n $line ]] && report "email address at $f:$line"
    done < <(grep -nE '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}' <<<"$content" \
      | grep -vE 'users\.noreply\.github\.com|@example\.(com|org)' | cut -d: -f1 | sed 's/$/:/')
  fi

  for i in "${!local_patterns[@]}"; do
    while IFS=: read -r line _; do
      [[ -n $line ]] && report "local pattern #$((i + 1)) at $f:$line"
    done < <(grep -niE -- "${local_patterns[$i]}" <<<"$content" | cut -d: -f1 | sed 's/$/:/')
  done
done

if ((fail)); then
  echo "Sensitive-value check failed. Fix the above before committing."
  exit 1
fi
echo "Sensitive-value check passed (${#files[@]} files, mode: $mode)."
