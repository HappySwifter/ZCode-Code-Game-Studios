# Hook Input/Output Schemas

This documents the JSON payloads each ZCode hook receives on stdin for every
event type, and how a hook's output reaches the user and the model. Every payload
also carries the common fields `session_id`, `transcript_path`, `cwd` and
`hook_event_name`; the examples below show the event-specific ones.

> **Ported to ZCode.** ZCode has seven events: `SessionStart`, `UserPromptSubmit`,
> `PreToolUse`, `PermissionRequest`, `PostToolUse`, `PostToolUseFailure`, `Stop`.
> The stdin payload is Claude-Code-shaped (`tool_name` + `tool_input`), and
> ZCode expands `${CLAUDE_PROJECT_DIR}` in hook commands. Two differences matter:
> there is no PowerShell tool (matchers use `Bash` alone), and plain-text stdout
> on exit 0 is ignored — see [Output](#output-warnings-someone-sees).

## PreToolUse

Fired before a tool is executed. Exit 2 **blocks** the call. Exit 0 lets it
continue through the normal permission flow — it does not approve it, and the
user can still be asked. To warn without blocking, exit 0 and print hook JSON —
see [Output](#output-warnings-someone-sees) below.

### PreToolUse: Bash

```json
{
  "tool_name": "Bash",
  "tool_input": {
    "command": "git commit -m 'feat: add player health system'",
    "description": "Commit changes with message",
    "timeout": 120000
  }
}
```

ZCode has no PowerShell tool; its matcher for shell hooks is `Bash` alone.

### PreToolUse: Write

```json
{
  "tool_name": "Write",
  "tool_input": {
    "file_path": "src/gameplay/health.gd",
    "content": "extends Node\n..."
  }
}
```

### PreToolUse: Edit

```json
{
  "tool_name": "Edit",
  "tool_input": {
    "file_path": "src/gameplay/health.gd",
    "old_string": "var health = 100",
    "new_string": "var health: int = 100"
  }
}
```

### PreToolUse: Read

```json
{
  "tool_name": "Read",
  "tool_input": {
    "file_path": "src/gameplay/health.gd"
  }
}
```

In real payloads a file tool's `file_path` is absolute, with the platform's own
separators — backslashes on Windows. Strip the project root first, then match
from the start of what is left (`assets/data/`). A segment such as
`/assets/data/` matched anywhere also fires on a parent folder of the same name
and on files outside the project, such as the user's own `~/.zcode/skills/`.
`validate-assets.sh` shows the stripping.

## PostToolUse

Fired after a tool completes. **Cannot block** — the tool already ran. Exit 2
shows stderr to Claude, so it can fix what it just wrote. stderr on exit 0 goes to
the debug log only, so an advisory warning must be hook JSON on stdout.

### PostToolUse: Write

```json
{
  "tool_name": "Write",
  "tool_input": {
    "file_path": "assets/data/enemy_stats.json",
    "content": "{\"goblin\": {\"health\": 50}}"
  },
  "tool_response": {
    "filePath": "assets/data/enemy_stats.json",
    "type": "create"
  }
}
```

### PostToolUse: Edit

```json
{
  "tool_name": "Edit",
  "tool_input": {
    "file_path": "assets/data/enemy_stats.json",
    "old_string": "\"health\": 50",
    "new_string": "\"health\": 75"
  },
  "tool_response": { "filePath": "assets/data/enemy_stats.json" }
}
```

## Agent tool calls (subagent lifecycle)

ZCode has no `SubagentStart`/`SubagentStop` events. The same moments are visible
on the tool events, matched with the `Agent` matcher: PreToolUse(Agent) fires
when the subagent is spawned, PostToolUse(Agent) when it returns. The spawned
agent's name is in `tool_input.subagent_type` (empty means the general-purpose
agent):

```json
{
  "tool_name": "Agent",
  "tool_input": {
    "subagent_type": "game-designer",
    "prompt": "..."
  }
}
```

## SessionStart

Fired when a session starts, resumes, is cleared with `/clear`, or is compacted.
Stdin carries `source`: `startup`, `resume`, `clear` or `compact`; the matcher
can filter on it (the compaction log rides `matcher: "compact"`).

**Plain stdout is NOT added to the model's context in ZCode** — unlike Claude
Code, output that does not start with `{` is silently ignored. To restore
context, a SessionStart hook must print `{"additionalContext": "..."}`;
`zcode-wrap-context.sh` does that wrapping for `session-start.sh` and
`detect-gaps.sh`.

## Stop

Fired **every time ZCode finishes a response**, not once when the session ends.
Stdin carries the common fields plus `stop_hook_active` and
`last_assistant_message`. Exit 2 keeps the session working instead of stopping.

## Output: warnings someone sees

A hook that warns but must not block exits 0 — and **on exit 0, stderr reaches
no one**. Print a JSON object on stdout instead:

```json
{
  "systemMessage": "Shown to the user",
  "hookSpecificOutput": {
    "hookEventName": "PostToolUse",
    "additionalContext": "Given to the model next to the tool result"
  }
}
```

- stdout must hold **only** that object.
- `hookEventName` is required inside `hookSpecificOutput`.
- **Leave out `permissionDecision`** unless you mean it: on PreToolUse, `"allow"`
  skips the user's permission prompt.

CCGS hooks use `hook_warn` from `.zcode/hooks/yaml-helper.sh`, which builds this
object and escapes the message without needing `jq`:

```bash
. .zcode/hooks/yaml-helper.sh
hook_warn PostToolUse "Asset names must be lowercase: $FILE_PATH"
exit 0
```

## Exit Code Reference

| Exit Code | Meaning |
|-----------|---------|
| 0 | Pass. Stdout starting with `{` is parsed as hook JSON (`additionalContext`, `systemMessage`, `hookSpecificOutput`); anything else is ignored. stderr goes to the log only. |
| 2 | Block on PreToolUse/PermissionRequest (the model sees stderr as the reason, or stdout when stderr is empty). On PostToolUse/Stop it raises a recoverable error with the same text. |
| Other | Recoverable error; the run is marked failed and the action proceeds. |

**Keep hook output small.** Claude Code capped stdout at 10,000 characters;
ZCode truncates previews around 4,000. Assume nothing past a few thousand
characters is read, and keep what the model must see at the front —
`session-start.sh` caps its checkpoint preview for this reason.

## Notes

- Hooks receive JSON on **stdin** (pipe). Use `INPUT=$(cat)` to capture.
- Parse with `jq` if available, fall back to `grep` for cross-platform compatibility.
- On Windows, `grep -P` (Perl regex) is often unavailable. Use `grep -E` (POSIX extended) instead.
- Path separators may be `\` on Windows. Normalize with `sed 's|\\|/|g'` when comparing paths.
