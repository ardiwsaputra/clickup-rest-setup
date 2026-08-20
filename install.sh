#!/usr/bin/env bash
# Setup ClickUp REST API access for Claude Code.
# Stores your personal token at ~/.clickup_token (chmod 600) and installs the
# clickup skill so Claude knows the API without being re-explained each session.
set -euo pipefail

TOKEN_FILE="$HOME/.clickup_token"
SKILL_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/skills/clickup"
SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ -s "$TOKEN_FILE" ]; then
  printf 'Token already exists at %s. Overwrite? [y/N] ' "$TOKEN_FILE"
  # Non-interactive stdin (CI, `git pull && ./install.sh`) means "keep it".
  read -r reply || reply=n
  [ "$reply" = "y" ] || [ "$reply" = "Y" ] || SKIP_TOKEN=1
fi

if [ -z "${SKIP_TOKEN:-}" ]; then
  echo "Get your token in ClickUp: Settings -> Apps -> API Token -> Generate"
  printf 'Paste token (pk_...): '
  read -rs token; echo
  case "$token" in
    pk_*) ;;
    *) echo "Token must start with 'pk_'. Aborting." >&2; exit 1 ;;
  esac
  # Subshell so the restrictive umask applies to the secret and nothing else.
  # Setting it inline leaks into the later mkdir and strips the dir's +x bit.
  ( umask 177; printf '%s' "$token" > "$TOKEN_FILE" )
  echo "Saved: $TOKEN_FILE (mode 600)"
fi

echo "Verifying token..."
resp="$(curl -fsS -H "Authorization: $(cat "$TOKEN_FILE")" \
  https://api.clickup.com/api/v2/team)" || {
  echo "Failed. Invalid token, or no network connection." >&2
  exit 1
}
# ponytail: grep, not jq -- so nobody has to install jq just for this.
echo "$resp" | grep -o '"name":"[^"]*"' | head -5 | sed 's/"name":"/  workspace: /; s/"$//'

mkdir -p "$SKILL_DIR"
cp "$SRC_DIR/skills/clickup/SKILL.md" "$SKILL_DIR/SKILL.md"
cp "$SRC_DIR/skills/clickup/allowed.sh" "$SKILL_DIR/allowed.sh"
chmod +x "$SKILL_DIR/allowed.sh"
echo "Skill installed: $SKILL_DIR/SKILL.md"
echo
echo "Done. Restart Claude Code, then try: \"list my ClickUp tasks\""
