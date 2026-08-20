#!/usr/bin/env bash
# Allowlist gate for ClickUp IDs. Exit 0 = allowed, 1 = blocked.
#
# No ~/.clickup_allow file means everything is allowed (default open).
# Create the file to restrict work to the IDs listed in it.
#
# ponytail: a guardrail against mistakes, not a security boundary -- the token
# itself is unscoped, so anything holding it can reach the whole account.
set -euo pipefail

ALLOW="${CLICKUP_ALLOW_FILE:-$HOME/.clickup_allow}"

self_test() {
  tmp="$(mktemp)"
  printf '# comment\n\n222222222222  # example list\n111111111111\n' > "$tmp"
  export CLICKUP_ALLOW_FILE="$tmp"
  "$0" 222222222222            || { echo "FAIL: listed id with comment"; exit 1; }
  "$0" 111111111111            || { echo "FAIL: listed id bare"; exit 1; }
  ! "$0" 999999999 2>/dev/null || { echo "FAIL: unlisted id allowed"; exit 1; }
  ! "$0" 11111111  2>/dev/null || { echo "FAIL: prefix matched"; exit 1; }
  ! "$0" 'comment' 2>/dev/null || { echo "FAIL: non-alnum accepted"; exit 1; }
  rm -f "$tmp"
  CLICKUP_ALLOW_FILE=/nonexistent "$0" 123 || { echo "FAIL: no file should allow"; exit 1; }
  echo "self-test: ok"
}

[ "${1:-}" = "--self-test" ] && { self_test; exit 0; }

id="${1:?usage: allowed.sh <space_id|list_id|task_id>}"
case "$id" in
  *[!a-zA-Z0-9]*) echo "refusing to match non-alphanumeric id: $id" >&2; exit 1 ;;
esac

[ -f "$ALLOW" ] || exit 0   # default open

if grep -qE "^[[:space:]]*${id}([[:space:]]|#|\$)" "$ALLOW"; then
  exit 0
fi

echo "blocked: $id is not listed in $ALLOW" >&2
exit 1
