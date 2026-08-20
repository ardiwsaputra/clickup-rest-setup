---
name: clickup
description: Use when the user asks to read, create, update, or comment on ClickUp tasks, lists, spaces, or folders - anything touching their ClickUp workspace. Calls the ClickUp v2 REST API directly with curl.
---

# ClickUp REST API

Talk to ClickUp with `curl` via Bash. No MCP server, no SDK, no install.

## Auth

Token lives at `~/.clickup_token`. Send it raw — **no `Bearer` prefix**:

```bash
curl -fsS -H "Authorization: $(cat ~/.clickup_token)" \
  https://api.clickup.com/api/v2/team
```

Never print the token or paste it into a response. If the file is missing, tell the
user to run `install.sh` from the clickup-rest-setup repo.

## Naming gotcha

ClickUp's API says **`team`** where the UI says **Workspace**. `/v2/team` returns
workspaces, not teams. Hierarchy:

```
Workspace (team_id)
└── Space (space_id)
    ├── Folder (folder_id) → List (list_id) → Task (task_id)
    └── List (folderless)  → Task
```

## Discovery

Run these once, then remember the IDs instead of re-walking the tree every session.

| Goal | Call |
|---|---|
| Workspaces | `GET /v2/team` |
| Spaces | `GET /v2/team/{team_id}/space` |
| Folders in a space | `GET /v2/space/{space_id}/folder` |
| Folderless lists | `GET /v2/space/{space_id}/list` |
| Lists in a folder | `GET /v2/folder/{folder_id}/list` |
| Members of a list | `GET /v2/list/{list_id}/member` |

## Tasks

| Goal | Call |
|---|---|
| Tasks in a list | `GET /v2/list/{list_id}/task` |
| Search across workspace | `GET /v2/team/{team_id}/task` |
| One task | `GET /v2/task/{task_id}` |
| Create | `POST /v2/list/{list_id}/task` |
| Update | `PUT /v2/task/{task_id}` |
| Delete | `DELETE /v2/task/{task_id}` |
| Read comments | `GET /v2/task/{task_id}/comment` |
| Add comment | `POST /v2/task/{task_id}/comment` |

### Create

```bash
curl -fsS -X POST \
  -H "Authorization: $(cat ~/.clickup_token)" \
  -H "Content-Type: application/json" \
  -d '{"name":"Fix login bug","markdown_content":"Steps:\n- repro\n- patch","priority":2}' \
  "https://api.clickup.com/api/v2/list/${LIST_ID}/task"
```

Body fields worth knowing:

- `name` — the only required field.
- `markdown_content` — Markdown body. **Wins over `description` if both are sent.**
- `assignees` — array of **integer** user IDs (get them from `/v2/list/{id}/member`).
- `status` — string, must match a status that exists in that list.
- `priority` — `1` urgent, `2` high, `3` normal, `4` low, `null` none.
- `due_date` / `start_date` — Unix time in **milliseconds**. Pair with
  `due_date_time: true` if the time-of-day matters, otherwise it reads as all-day.
- `parent` — an existing task ID turns this into a subtask.
- `tags` — array of strings, must already exist in the space.

### Reading a list

```bash
curl -fsS -H "Authorization: $(cat ~/.clickup_token)" \
  "https://api.clickup.com/api/v2/list/${LIST_ID}/task?include_closed=true&subtasks=true&page=0"
```

Useful query params: `include_closed`, `subtasks`, `archived`, `statuses[]`,
`assignees[]`, `tags[]`, `order_by` (`id`|`created`|`updated`|`due_date`),
`reverse`, `include_markdown_description`, and date-range filters
(`due_date_gt`, `date_updated_lt`, … — all Unix ms).

### Pagination

**100 tasks per page, `page` starts at 0.** The response carries `last_page`
(boolean). Anything that says "all tasks" must loop until `last_page` is true —
a single call silently truncating at 100 is the most common bug here.

## Two things that look like missing data

- A list's **`task_count` undercounts**. It excludes subtasks and closed tasks, so
  a list reporting 4 can easily return 12 once you pass
  `include_closed=true&subtasks=true`. Never quote `task_count` as "how many tasks
  are in this list" — fetch and count.
- **Task names can carry invisible characters** (e.g. `U+200E` left-to-right mark),
  usually from templates. Exact-string matching on a name will miss them. Match on
  `id`, or use a substring/normalized comparison.

## Rate limits

**100 requests/minute per token** on Free / Unlimited / Business (1,000 on
Business Plus, 10,000 on Enterprise). Per *token*, not per user or workspace.
There is **no daily cap** on the REST API.

Every response carries `X-RateLimit-Remaining` and `X-RateLimit-Reset` (Unix
seconds). Over the limit returns **HTTP 429** — back off until the reset, don't
hammer.

Budget matters when looping. Prefer one filtered list call over N per-task calls;
if you genuinely need per-task detail across hundreds of tasks, say so first and
pace the loop rather than burning the minute silently.

## Scope

If `~/.clickup_allow` exists, it lists the only IDs you may touch. Check before
acting on any space, list, or task:

```bash
~/.claude/skills/clickup/allowed.sh "$LIST_ID" || echo "out of scope"
```

Exit 0 means allowed, 1 means blocked. **If the file does not exist, everything is
allowed** — that is the default, and it is not an error.

When a call is blocked, stop and tell the user which ID was refused and where the
allowlist lives. Do not work around it by targeting a parent space, resolving the
list through a different endpoint, or asking the API for the same data another way.

This is a guardrail against acting on the wrong list, not a security boundary. A
ClickUp personal token cannot be scoped — it reaches the entire account — so the
allowlist only constrains work that goes through this skill.

## Conventions

- `-fsS` on every call: fail on HTTP errors, stay quiet, but still show the error.
- Pipe to `jq` only if it's installed; otherwise ask before installing it.
- Destructive calls (`DELETE`, bulk `PUT`) — confirm with the user first, and
  never run them across a whole list without an explicit go-ahead.
- Store discovered IDs (`team_id`, `space_id`, `list_id`) in memory or the
  project's CLAUDE.md so the next session skips discovery.

## Docs

<https://developer.clickup.com/reference> — check it when a field isn't covered
above rather than guessing the schema.
