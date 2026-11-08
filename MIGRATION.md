# MIGRATION — Claude Code Game Studios → ZCode

This fork is [Claude Code Game Studios](https://github.com/Donchitos/Claude-Code-Game-Studios)
v1.2.0 rewired to run as a **ZCode working copy** (workspace resources in
`.zcode/`), not a plugin. The studio itself — 49 agents, 74 skills, 62
templates, the `project.yaml` config, the quality gates — is unchanged in
substance; only the wiring moved. This document maps every piece, so you can
also use it to port *your own* customized CCGS checkout.

## File moves

| Claude Code | ZCode | Notes |
|---|---|---|
| `CLAUDE.md` (root) | `AGENTS.md` | Workspace instruction file. The `@path` imports Claude Code expanded are **inlined** (ZCode does not expand imports); the engine `VERSION.md` import became a read-on-demand pointer |
| `design/`, `docs/`, `src/`, `studio-tests/CLAUDE.md` | same dirs, `AGENTS.md` | ZCode loads `AGENTS.md` found from the working directory upward, so a nested file applies when working inside that folder |
| `.claude/agents/` | `.zcode/agents/` | 49 files, frontmatter normalized (below) |
| `.claude/skills/` | `.zcode/skills/` | 74 skills, frontmatter normalized (below) |
| `.claude/hooks/`, `.claude/scripts/`, `.claude/rules/`, `.claude/docs/` | `.zcode/…` | Scripts unchanged except the adaptations listed here |
| `.claude/settings.json` | `.zcode/config.json` | Only hooks moved over (see below); permissions and status line dropped |
| `.claude/statusline.sh` | — | ZCode has no custom status line |
| `CLAUDE-local-template.md` | `AGENTS-local-template.md` | `.zcode/docs/` |

All textual references were rewritten (`.claude/` → `.zcode/`, `CLAUDE.md` →
`AGENTS.md`). `CHANGELOG.md` and `UPGRADING.md` are left as historical records
of the upstream releases; their paths refer to the upstream layout.

## Frontmatter

**Skills** (`.zcode/skills/*/SKILL.md`): ZCode loads `name` and `description`
only. The Claude Code keys (`model`, `allowed-tools`, `user-invocable`,
`disable-model-invocation`, `argument-hint`) were removed; skills that had an
`argument-hint` carry it as a trailing "Arguments: …" sentence in the
description. `/skill-test`'s structural checks were updated to match (Check 1
and Check 7).

**Agents** (`.zcode/agents/*.md`): `model:` (`opus`/`sonnet`/`inherit`) and
`maxTurns:` were dropped — every agent runs on the session's model. `tools:`
was converted to ZCode's bracket list with its tool names: `Glob` and `Grep`
do not exist in ZCode (searching is done through Bash), `Task` was renamed
`Agent`. To re-create a tiered studio, see `.zcode/docs/model-tiers.md`.

## Hooks

ZCode has seven hook events — `SessionStart`, `UserPromptSubmit`, `PreToolUse`,
`PermissionRequest`, `PostToolUse`, `PostToolUseFailure`, `Stop` — registered
in `.zcode/config.json` under `hooks.events` with `"hooks": {"enabled": true}`.
The stdin payload is Claude-Code-shaped (`hook_event_name`, `session_id`,
`tool_name`, `tool_input`, `tool_response`, …), `${CLAUDE_PROJECT_DIR}` is
expanded in commands, exit 2 blocks with stderr as the reason. Verified against
the ZCode hook runner: **plain-text stdout on exit 0 is silently ignored** —
model-visible output must be JSON (`additionalContext`, `systemMessage`,
`hookSpecificOutput`).

| CCGS hook | Claude Code event | ZCode event | Adaptation |
|---|---|---|---|
| `validate-commit.sh` | PreToolUse (Bash, PowerShell) | PreToolUse (`Bash`) | none — payload shape identical |
| `validate-push.sh` | PreToolUse (Bash, PowerShell) | PreToolUse (`Bash`) | none; its warning JSON is valid ZCode output as-is |
| `validate-read.sh` | PreToolUse (Read) | PreToolUse (`Read`) | none |
| `validate-registry.sh` / `validate-write.sh` | PreToolUse (Write/Edit) | PreToolUse (`Write\|Edit`) | none (`hook_warn`'s JSON fits ZCode's schema) |
| `validate-assets.sh` / `validate-skill-change.sh` | PostToolUse (Write/Edit) | PostToolUse (`Write\|Edit`) | none |
| `session-start.sh` | SessionStart | SessionStart | wrapped in new `zcode-wrap-context.sh` — plain stdout would be ignored |
| `detect-gaps.sh` | SessionStart | SessionStart | same wrapper |
| `pre-compact.sh` | PreCompact | SessionStart, matcher `compact` | fires after the compaction instead of before; the log line is identical |
| `notify.sh` | Notification | PermissionRequest | message now built from `tool_name` (no `.message` field); Windows-only toast as before |
| `session-stop.sh` | Stop (async) | Stop | ZCode runs hooks inline; script unchanged |
| `log-agent.sh` | SubagentStart | PreToolUse (`Agent`) | agent name read from `tool_input.subagent_type` |
| `log-agent-stop.sh` | SubagentStop | PostToolUse (`Agent`) | same field |
| `validate-agent-artifact.sh` | SubagentStop | PostToolUse (`Agent`) | the return contract is read from `tool_input.prompt` (no `agent_transcript_path`) |

New hooks added by the port:

- `zcode-wrap-context.sh` — runs a SessionStart script and re-emits its output
  as `{"additionalContext": ...}`.
- `zcode-inject-rules.sh` — PreToolUse (Write/Edit): matches the written path
  against `.zcode/rules/*.md` `paths:` globs and injects the most specific
  matched rule as context — the replacement for Claude Code's native
  path-scoped rules. Fail-open.

### What the mapping loses

- **Subagent resumes and agent-team handoffs are not tallied** — without
  `SubagentStart`/`SubagentStop`, the audit trail (`production/session-logs/`)
  counts real `Agent` tool calls only.
- **No idle notification** — Claude Code's `Notification` also fired after a
  minute of idleness; `PermissionRequest` covers permission prompts only.
- **No async Stop** — `session-stop.sh` runs inline at every response end; it
  stays fast, but a slow Stop hook would now add latency.
- **Permission deny-list dropped** — the ~130 `deny` rules from
  `settings.json` have no ZCode config-file equivalent; ZCode's own permission
  prompts and sandboxing cover dangerous commands. `validate-push.sh` still
  warns on the dangerous git steps.
- **Custom status line dropped** — `statusline.sh` had no ZCode counterpart.

## Instructions (AGENTS.md)

- `@path` imports are not expanded by ZCode — the three imported docs
  (`directory-structure`, `coordination-rules`, `coding-standards`) are
  inlined in the root `AGENTS.md`; the engine version import became a pointer
  (`/setup-engine` reference 4 updated to rewrite the pointer).
- A "ZCode Port Notes" section was added: the `Glob`/`Grep` → Bash mapping for
  texts that still name those tools, where hooks live, and the frontmatter keys.
- `.zcode/docs/model-tiers.md` rewritten: no model pins; how to re-add them.

## Syncing with upstream

Upstream evolves in `.claude/` with Claude Code frontmatter and hook events.
To pull a change: take the upstream file, apply the file moves above, then the
frontmatter rules, and check the hook against the event table. The scripts
changed by this port are marked by header comments mentioning ZCode events —
everything else is upstream text with paths rewritten.

## Porting checklist (for your own fork)

1. `git mv .claude .zcode`, rename `CLAUDE.md` files to `AGENTS.md`.
2. Rewrite `.claude` → `.zcode` and `CLAUDE.md` → `AGENTS.md` in text files.
3. Strip skill frontmatter to `name` + `description`; drop agent `model:` /
   `maxTurns:`; map tools (`Glob`/`Grep` out, `Task` → `Agent`).
4. Replace `settings.json` with `config.json` hooks (mind `hooks.enabled: true`).
5. Wrap SessionStart output in `additionalContext` JSON.
6. Re-point the subagent hooks at PreToolUse/PostToolUse (`Agent`) and parse
   `tool_input.subagent_type`.
7. Add a rules-injection hook for path-scoped rules, or list the rules table in
   `AGENTS.md`.
8. Inline any `@path` imports in `AGENTS.md`.
9. Run `/skill-test static all` and the hooks by hand with a sample payload
   (`{"tool_name":"Bash","tool_input":{"command":"git commit -m test"}}`).
