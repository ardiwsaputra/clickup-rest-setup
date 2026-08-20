# clickup-rest-setup

Use ClickUp from Claude Code through the REST API directly. No MCP server, no
SDK, no dependencies — just `curl` plus one skill that teaches Claude the API.

## Install

```bash
git clone https://github.com/ardiwsaputra/clickup-rest-setup.git
cd clickup-rest-setup
./install.sh
```

The script will:

1. Ask for your personal API token (ClickUp → **Settings → Apps → API Token → Generate**)
2. Save it to `~/.clickup_token` with `600` permissions
3. Verify it against `/v2/team` and print your workspace names
4. Install the skill to `~/.claude/skills/clickup/`

Restart Claude Code, then try: *"list my ClickUp tasks"*.

## Installing with Claude Code

Point Claude at this repo and it can do everything except the one step it must not
do — typing your token.

> Install github.com/ardiwsaputra/clickup-rest-setup for me.

What Claude should do, and what it can't:

1. `git clone https://github.com/ardiwsaputra/clickup-rest-setup.git && cd clickup-rest-setup`
2. **Stop and hand this step to the human.** `install.sh` prompts for the token with
   a hidden `read`, so running it from a tool call just hangs waiting for input that
   never arrives. Tell the user to run `./install.sh` in their own terminal, and
   never ask them to paste the token into the chat — it would end up in the
   transcript.
3. Once they confirm it's done, verify and discover their IDs:
   ```bash
   curl -fsS -H "Authorization: $(cat ~/.clickup_token)" \
     https://api.clickup.com/api/v2/team
   ```
   Then walk `/team/{team_id}/space` and `/space/{space_id}/list`.
4. Write the IDs into the project's `CLAUDE.md` so later sessions skip discovery —
   that walk costs ~5 API calls every time.
5. Restart is required for the skill to load.

The skill lands in `~/.claude/skills/clickup/` and activates on its own whenever
ClickUp comes up. There's nothing to wire into `settings.json`.

## Why REST instead of MCP?

ClickUp's hosted MCP (`mcp.clickup.com`) has a **daily cap**: 300 calls per rolling
24 hours on Unlimited and above, and less than that on Free — unless your workspace
buys the Everything AI add-on.

The REST API has **no daily cap at all**. Just 100 requests/minute per token on
Free/Unlimited/Business, and it resets every minute. For working alongside Claude
Code, that is far more headroom, for free.

| | REST API (this repo) | ClickUp hosted MCP |
|---|---|---|
| Limit | 100/min per token | 300/day (rolling 24h) |
| Daily cap | none | yes |
| Cost | free | needs Everything AI to lift the cap |
| Install | curl (already there) | server + config |

Limits are counted **per token**, not per user or per workspace. So everyone who
runs `install.sh` with their own token gets their own independent quota.

## What's in here

```
install.sh                 # token setup + skill install
clickup_allow.example      # optional allowlist template
skills/clickup/SKILL.md    # endpoints, fields, pagination, rate limits
skills/clickup/allowed.sh  # allowlist gate (run --self-test to verify)
```

`SKILL.md` is the heart of this repo. It's what stops Claude from guessing, and it
covers the things that quietly break integrations:

- The API says `team` where the UI says **Workspace**
- `markdown_content` **overrides** `description` when both are sent
- Dates are Unix time in **milliseconds**, not seconds
- Task lists silently stop at **100 items** unless you loop until `last_page: true`
- The auth header takes the raw token, with **no** `Bearer` prefix

## Limiting scope (optional)

By default every space and list in the workspace is reachable. To narrow that,
copy the example and list only the IDs you want in play:

```bash
cp clickup_allow.example ~/.clickup_allow
$EDITOR ~/.clickup_allow
```

The skill checks each ID against that file before acting, and stops if it isn't
listed. Delete the file to go back to full access.

Worth being clear about what this is: a **guardrail against touching the wrong
list**, not a security boundary. ClickUp personal tokens can't be scoped — one
token reaches the whole account — so the allowlist constrains work that goes
through the skill, not what the token *could* do. If you need real enforcement,
deny direct `curl` to `api.clickup.com` in your Claude Code permission settings
and let the skill be the only path.

## Security

- The token is stored `chmod 600`, readable only by your user.
- `umask` is set *before* the secret touches disk, so there's no brief window where
  the file is world-readable.
- The token never enters the repo, git history, or Claude's output.
- No outbound traffic to anything except `api.clickup.com`.
- To revoke: delete `~/.clickup_token`, then revoke the token in ClickUp under
  Settings → Apps.

## Manual setup (no script)

```bash
printf 'pk_XXXX' > ~/.clickup_token && chmod 600 ~/.clickup_token
curl -fsS -H "Authorization: $(cat ~/.clickup_token)" https://api.clickup.com/api/v2/team
```

Then copy `skills/clickup/SKILL.md` to `~/.claude/skills/clickup/SKILL.md`.

## License

MIT
