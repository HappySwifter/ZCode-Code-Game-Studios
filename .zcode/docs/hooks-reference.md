# Active Hooks

Hooks are registered in `.zcode/config.json` under `hooks.events` (with
`hooks.enabled: true`) and fire automatically. ZCode has exactly seven hook
events — `SessionStart`, `UserPromptSubmit`, `PreToolUse`, `PermissionRequest`,
`PostToolUse`, `PostToolUseFailure`, `Stop` — so the Claude Code events
`Notification`, `PreCompact`, `SubagentStart` and `SubagentStop` are mapped onto
theirs, as the Event column shows:

| Hook | ZCode event | Trigger | Action |
| ---- | ----- | ------- | ------ |
| `validate-commit.sh` | PreToolUse (Bash) | `git commit` commands | Validates design doc sections, JSON data files, hardcoded values, TODO format |
| `validate-push.sh` | PreToolUse (Bash) | `git push`, `git tag`, `git merge` and release commands | Warns on pushes to protected branches (`main`, `master` and `release/*`), and on the steps that ask first: `git tag` (not a listing), `git merge` (not `--abort`), `gh release`, `butler push` and `steamcmd` with `+run_app_build`. Which commands count is `bash .zcode/scripts/write-guard.sh git` |
| `validate-registry.sh` | PreToolUse (Write/Edit) | Writes and edits of `design/registry/entities.yaml` and `docs/architecture/tr-registry.yaml` | Warns, and never blocks, when the change would delete or renumber an entry or set a status outside the values the file's header lists. It runs before the write, while the old file can still be compared; the check itself is `bash .zcode/scripts/registry.sh compare`. The skills that write a registry also run `registry.sh validate` after writing, because hooks do not run in every tool |
| `validate-write.sh` | PreToolUse (Write/Edit) | Writes and edits the rules below name | Warns, and never blocks, when a write would replace a file skills never overwrite (an existing `EPIC.md`, `project.godot`, `tests/helpers/*`, the tech-debt register, an engine reference doc, the files `/test-setup` creates), set a config value outside its list or a key `project.local.yaml` cannot hold, set the review mode, leave a prototype file without its `PROTOTYPE` or `VERTICAL SLICE` header or reach between `prototypes/` and the code root, change a string table during an active freeze, or, from a subagent, write anything but a new file under `production/`, `docs/` or `tests/`. The check is `bash .zcode/scripts/write-guard.sh check`, which the skills that write these files also run themselves |
| `zcode-inject-rules.sh` | PreToolUse (Write/Edit) | Any Write/Edit carrying a `file_path` | Replacement for Claude Code's path-scoped rules: matches the path against each `.zcode/rules/*.md` `paths:` glob and injects the most specific matched rule into the model's context as `additionalContext`. Fail-open |
| `validate-read.sh` | PreToolUse (Read) | A Read with no offset and no limit under `design/`, `docs/architecture/` or `production/session-state/` | Blocks a whole-file read of a doc over 40 KB (`features.read_guard_kb`) and answers with the doc's headings by line, so the retry reads one section; a ranged read always passes. `features.read_guard: off` turns it off. The check is `bash .zcode/scripts/read-guard.sh check` |
| `validate-agent-artifact.sh` | PostToolUse (Agent) *(was SubagentStop)* | An Agent tool call returns | Warns you, and never blocks, when the file the subagent's return contract named ("Write your full output to `<path>`", read from `tool_input.prompt`) is not on disk — a failed phase however its reply reads |
| `validate-assets.sh` | PostToolUse (Write/Edit) | Asset file changes | Checks data-file JSON under `assets/`, `Assets/` or `Content/`, and asset naming in Godot's `assets/` only |
| `session-start.sh` | SessionStart, via `zcode-wrap-context.sh` | Session begins | Loads sprint context, milestone, git activity; detects and previews active session state file for recovery, with one line when its checkpoint names a different branch from the one you are on; one line when a newer release is out, from a cache `update-check.sh` refreshes in the background at most once a day (`updates.check` in `effects-map.md`). The wrapper turns the script's plain output into `{"additionalContext": ...}` — ZCode ignores plain-text stdout |
| `detect-gaps.sh` | SessionStart, via `zcode-wrap-context.sh` | Session begins | Detects fresh projects (suggests /start) and missing documentation when code/prototypes exist, suggests /reverse-document or /project-stage-detect |
| `pre-compact.sh` | SessionStart, matcher `compact` *(was PreCompact)* | Context compression finishes | Appends one line to `production/session-logs/compaction-log.txt` and prints nothing. Claude Code fired it before the compaction; ZCode fires it right after — the log line is identical. `session-start.sh`, which also runs on `SessionStart`, is what restores context |
| `notify.sh` | PermissionRequest *(was Notification)* | ZCode shows a permission prompt | Shows a Windows toast via PowerShell, naming the tool that asked; a no-op on macOS and Linux |
| `session-stop.sh` | Stop | **Every response ends** — not once per session | Updates the session log and writes the subagent spawn tally to `production/session-logs/session-cost.md`; prints nothing. Archives `active.md` only when its content hash changed; without that guard a long session appended the whole file on every turn. ZCode runs hooks inline (no `async`), but the script is cheap; under `zcode -p` it is cancelled if still running when the session ends |
| `log-agent.sh` | PreToolUse (Agent) *(was SubagentStart)* | The Agent tool is invoked | Audit trail start — logs the spawned `tool_input.subagent_type` with timestamp and session id |
| `log-agent-stop.sh` | PostToolUse (Agent) *(was SubagentStop)* | An Agent tool call returns | Audit trail stop — completes the subagent record |
| `validate-skill-change.sh` | PostToolUse (Write/Edit) | Skill file changes | Advises running `/skill-test` after any `.zcode/skills/` file is written or edited |

Warnings from the `validate-*` hooks are shown to you and passed to the model
(only to you from `validate-agent-artifact.sh`)
as hook JSON (`hook_warn` in `yaml-helper.sh` — `systemMessage` plus
`hookSpecificOutput.additionalContext`, which ZCode's output schema accepts
as-is); only a problem that must be fixed now exits 2, and the read guard's
refusal (exit 2's stderr becomes the block reason the model sees). See
`hooks-reference/hook-input-schemas.md` for why stderr is not enough.

### Subagent cost visibility

The two `log-agent*.sh` hooks form one chain. `log-agent.sh` writes a record per
spawn to `production/session-logs/agent-audit.log` in a fixed three-field shape:

```
YYYYMMDD_HHMMSS | <session_id> | Agent invoked: <agent_name>
```

`session-stop.sh` greps the literal string `" | $SESSION_ID | Agent invoked: "`
to tally the current session, then writes a count plus a per-agent breakdown to
`production/session-logs/session-cost.md`.

The field order of that record is fixed. `session-stop.sh` matches it literally,
so a different order silently zeroes the spawn count instead of raising an error.

When the hook input has no session id, `session-stop.sh` writes no total. A
total spanning every session in the log would look plausible and be wrong, which
is worse than none.

The agent name rides in `tool_input.subagent_type` of the Agent tool payload.
Compared with Claude Code's SubagentStart, the ZCode mapping counts only real
`Agent` tool calls — subagent resumes and agent-team message handoffs do not
fire PreToolUse(Agent), so they are not tallied.

## Events considered and deliberately not added

ZCode offers two more hook events than the six the hooks above use. These were
evaluated and not adopted, for the reasons given.

| Event | Why not |
| ---- | ---- |
| `UserPromptSubmit` | Would re-inject session state on **every prompt**. `.zcode/docs/config-resolution.md` already rejects the weaker version of this — injecting config at session start — because it "would cost tokens on every session whether or not any skill needs config, and it would go stale mid-session as `/settings` writes land". Firing per prompt is the same argument, multiplied. |
| `PostToolUseFailure` | Would add another log with no reader. |

Claude Code features with no ZCode equivalent, and what happened to them, are
listed in the repo root `MIGRATION.md`: the permission deny-list (ZCode's own
permission prompts cover dangerous commands), the custom status line, and the
ask-first default mode.

Hook reference documentation: `.zcode/docs/hooks-reference/`
Hook input schema documentation: `.zcode/docs/hooks-reference/hook-input-schemas.md`
