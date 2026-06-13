---
name: jira-integration
description: "Auto-invoked when work touches Jira — creating/reading/updating issues, syncing a sprint plan to Jira, starting work from a JIRA-KEY, moving issues across statuses, or commenting a PR link back. Also triggers during /sprint-plan, /feature, /ship, and /auto-build when a Jira project is configured. Drives bidirectional sync (Cortex ⇆ Jira) through the Atlassian MCP server. NO dedicated slash command — this skill handles all Jira interaction."
---

# Jira Integration (via Atlassian MCP Server)

Cortex talks to Jira through the **official Atlassian Remote MCP server**, declared
in the plugin's `.mcp.json` (`type: "http"`, `https://mcp.atlassian.com/v1/mcp`).
There is **no `/jira` command** — this skill is the entire integration surface.
When any workflow needs Jira, this skill tells you how to do it.

The MCP tools are namespaced to this plugin:
**`mcp__plugin_cortex_atlassian__<toolName>`**

---

## Step 0 — Availability & Auth (ALWAYS check first)

Before any Jira action, confirm the integration is live. Fail SOFT — never block a
build because Jira isn't set up.

1. **Is the server connected?** The Atlassian MCP tools appear after the plugin
   loads. If `mcp__plugin_cortex_atlassian__*` tools are not available, tell the
   user: *"Jira isn't connected yet — run `/mcp` and authenticate the `atlassian`
   server, then retry."* Continue the underlying task WITHOUT Jira sync.
2. **Authenticated?** The first tool call triggers OAuth in the browser (handled by
   Claude Code — no token to store). If a call returns an auth error, surface the
   `/mcp` re-auth hint and proceed without Jira.
3. **Which site?** Call `mcp__plugin_cortex_atlassian__getAccessibleAtlassianResources`
   to get the **cloudId** (and site URL). Most Jira tools require `cloudId`. Cache it
   in the project config (Step 1) so you don't re-fetch every call.

> **Golden rule:** Jira sync is an ENHANCEMENT. If it's unavailable, log one clear
> line and keep doing the real work (planning, building, shipping). Never error out.

---

## Step 1 — Project Config: `.cortex/jira.json`

Jira binding is per-project. On first use, create/read `.cortex/jira.json`:

```json
{
  "cloudId": "<from getAccessibleAtlassianResources>",
  "siteUrl": "https://your-org.atlassian.net",
  "projectKey": "PROJ",
  "epicLinkField": "customfield_10014",
  "statusMap": {
    "todo": "To Do",
    "in_progress": "In Progress",
    "in_review": "In Review",
    "done": "Done"
  }
}
```

- If it doesn't exist and the user wants Jira sync, ask ONCE for the **project key**
  (e.g. `PROJ`), resolve `cloudId` via the API, confirm the status names actually
  exist on that project's workflow (via `getTransitionsForJiraIssue` on a sample
  issue or `getJiraProjectIssueTypesMetadata`), and write the file.
- `.cortex/jira.json` holds NO secrets (auth is OAuth) — safe to commit. Add it to
  the repo so the whole team shares the same binding.
- **Never invent a status name.** Workflows differ per project; always reconcile
  against the real transitions returned by `getTransitionsForJiraIssue`.

---

## The Atlassian Rovo MCP Tools (canonical names)

| Group | Tool (`mcp__plugin_cortex_atlassian__…`) | Use |
|-------|------------------------------------------|-----|
| auth/platform | `getAccessibleAtlassianResources` | Get cloudId + accessible sites |
| auth/platform | `atlassianUserInfo` | Current user (for assignee = me) |
| read | `getJiraIssue` | Fetch one issue by key/ID |
| read | `getVisibleJiraProjects` | List projects the user can see |
| read | `getJiraProjectIssueTypesMetadata` | Valid issue types + required fields |
| read | `getJiraIssueTypeMetaWithFields` | Field metadata for an issue type |
| read | `getTransitionsForJiraIssue` | **Valid** status transitions for an issue |
| read | `getIssueLinkTypes` | Link types (blocks, relates to…) |
| read | `lookupJiraAccountId` | Resolve a name/email → accountId |
| search | `searchJiraIssuesUsingJql` | JQL query (the workhorse for "find") |
| write | `createJiraIssue` | Create an issue |
| write | `editJiraIssue` | Update fields/description |
| write | `transitionJiraIssue` | Move issue to a new status |
| write | `addCommentToJiraIssue` | Comment (e.g. PR link, build status) |
| write | `addWorklogToJiraIssue` | Log time |

**Always** call `getTransitionsForJiraIssue` before `transitionJiraIssue` — pass the
transition ID it returns, not a guessed status name. **Always** call
`getJiraProjectIssueTypesMetadata` before `createJiraIssue` to use a real issue type
and satisfy required fields.

---

## Bidirectional Workflows

### A. `/sprint-plan` → create Jira issues  (Cortex → Jira)
After `SPRINT_PLAN.md` is generated, if Jira is configured (or the user asks "push
to Jira"):
1. Read `getJiraProjectIssueTypesMetadata` for the project → pick `Epic`/`Story`/
   `Task`/`Sub-task` types and required fields.
2. For each sprint epic → `createJiraIssue` (Epic). For each task → `createJiraIssue`
   (Story/Task) with summary, description (acceptance criteria from the plan), story
   points (estimate), and Epic link.
3. **Idempotency:** before creating, `searchJiraIssuesUsingJql` for an existing issue
   with the same summary in the project; skip/update instead of duplicating.
4. Write the returned issue keys back into `SPRINT_PLAN.md` next to each task
   (`- [ ] PROJ-123 — Implement auth`) and into `AUTO_BUILD_STATE.json` so later
   phases can transition them.

### B. `/feature PROJ-123` → start work from a Jira issue  (Jira → Cortex)
When `$ARGUMENTS` looks like a Jira key (`^[A-Z][A-Z0-9]+-\d+$`):
1. `getJiraIssue` → read summary, description, acceptance criteria, comments, links.
2. Use that as the feature spec (in place of, or merged with, a local description).
3. `getTransitionsForJiraIssue` → `transitionJiraIssue` to **In Progress**
   (statusMap.in_progress), and optionally assign to the current user
   (`atlassianUserInfo` → assignee).
4. Proceed with the normal /feature flow. On completion, transition + comment (see D).

### C. `/auto-build` → sync phase / sprint progress  (Cortex → Jira)
During the build loop, when a sprint task's phase completes and the task has a Jira
key in `AUTO_BUILD_STATE.json`:
- `transitionJiraIssue` → In Progress when its phase starts, → In Review/Done when
  verified. `addCommentToJiraIssue` with a short progress note (phase, commit SHA).
- Keep it lightweight: one transition + at most one comment per task state change —
  don't spam the issue on every iteration.

### D. `/ship` → close the loop with the PR  (Cortex → Jira)
After the PR is created:
1. Determine the issue key (from the branch name `feature/PROJ-123-...`, the commit
   message, or `AUTO_BUILD_STATE.json`).
2. `addCommentToJiraIssue` with the PR URL + a one-line summary.
3. `transitionJiraIssue` → **In Review** (or **Done** if the project workflow merges
   on ship and the user opted in). Use the real transition ID from
   `getTransitionsForJiraIssue`.

### E. Ad-hoc ("create a bug for X", "what's assigned to me", "move PROJ-5 to done")
Just map to the right tool: `createJiraIssue`, `searchJiraIssuesUsingJql`
(`assignee = currentUser() AND statusCategory != Done`), `transitionJiraIssue`. No
command needed — this skill covers it.

---

## Rules & Etiquette

- ✅ Resolve cloudId once, cache in `.cortex/jira.json`.
- ✅ Read transitions/metadata before writing — never guess transition IDs, status
  names, issue types, or required fields.
- ✅ Be idempotent on creation (JQL-check first) so re-running `/sprint-plan` doesn't
  duplicate issues.
- ✅ Mirror issue keys into `SPRINT_PLAN.md` + `AUTO_BUILD_STATE.json` so the link
  survives across sessions.
- ✅ Confirm with the user before BULK writes (creating a whole sprint's issues,
  closing issues) — show a dry-run summary first.
- ✅ Keep comments concise and useful (PR links, build/verify status, blockers).
- ❌ NEVER store Atlassian credentials anywhere — auth is OAuth via the MCP server.
- ❌ NEVER hard-code cloudId / issue keys into commands or the plugin.
- ❌ NEVER block a build, plan, or ship because Jira is unavailable — degrade
  gracefully and tell the user how to connect (`/mcp`).
- ❌ NEVER transition an issue to a status that isn't in `getTransitionsForJiraIssue`.

---

## Setup (tell the user once, when Jira tools aren't connected)

1. The `atlassian` MCP server ships with Cortex (`.mcp.json`). Run `/mcp` to see it.
2. On first Jira action, a browser OAuth prompt connects your Atlassian Cloud site.
3. Cortex writes `.cortex/jira.json` (project key + cloudId + status map) — commit it.
4. Requires **Jira Cloud**. For Jira Server/Data Center, swap `.mcp.json` for a
   self-hosted Atlassian MCP (e.g. `sooperset/mcp-atlassian` via stdio with a PAT).
