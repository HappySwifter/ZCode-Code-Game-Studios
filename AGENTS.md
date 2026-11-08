# ZCode Game Studios — Game Studio Agent Architecture

Indie game development managed through 49 coordinated ZCode subagents.
Each agent owns a specific domain, enforcing separation of concerns and quality.

> Ported from [Claude Code Game Studios](https://github.com/Donchitos/Claude-Code-Game-Studios)
> (MIT). The studio hierarchy, 74 skills, rules and hooks are unchanged in
> substance; the wiring now targets ZCode — see `MIGRATION.md` for the full
> mapping. Where older documents mention Claude Code behavior, this file and
> `MIGRATION.md` are the authority on how it maps to ZCode.

## Technology Stack

- **Engine**: [CHOOSE: Godot 4 / Unity / Unreal Engine 5]
- **Language**: [CHOOSE: GDScript / C# / C++ / Blueprint]
- **Version Control**: Git with trunk-based development
- **Build System**: [SPECIFY after choosing engine]
- **Asset Pipeline**: [SPECIFY after choosing engine]

> **Note**: Engine-specialist agents exist for Godot, Unity, and Unreal with
> dedicated sub-specialists. Use the set matching your engine.

## Project Structure

```text
/
├── AGENTS.md                    # Master configuration (this file)
├── project.yaml                 # Machine-readable project config — engine, modes, stage (source of truth)
├── .zcode/                      # Agent definitions, skills, hooks, rules, docs
├── <code root>/                 # Game source code — THE PATH IS ENGINE-SPECIFIC, see below
├── assets/                      # Game assets (art, audio, vfx, shaders, data)
├── design/                      # Game design documents (gdd, narrative, levels, balance)
├── docs/                        # Technical documentation (architecture, api, postmortems)
│   └── engine-reference/        # Curated engine API snapshots (version-pinned)
├── tests/                       # Game test suites (unit, integration, performance, playtest)
├── tools/                       # Build and pipeline tools (ci, build, asset-pipeline)
├── prototypes/                  # Throwaway prototypes (outside the code root)
├── production/                  # Production management (sprints, milestones, releases)
│   ├── session-state/           # Ephemeral session state (active.md — gitignored)
│   └── session-logs/            # Session audit trail (gitignored)
└── studio-tests/                # QA for the skills/agents themselves — /skill-test, /skill-improve
```

### The code root is engine-specific

**Two of the three supported engines will not build a project whose code sits in
`src/`.** This is not a style preference — it is a hard constraint of the
engine's own toolchain:

| `engine.name` | Code root | Why it cannot be `src/` |
|---|---|---|
| **Godot** | `src/` | No constraint — Godot loads from `res://` anywhere under the project root. |
| **Unity** | `Assets/` | Unity compiles **only** `Assets/` and `Packages/`. Code outside them is invisible to the compiler. |
| **Unreal** | `Source/<Module>/` | UnrealBuildTool discovers modules under `Source/`; content lives in `Content/`. A module elsewhere is not built. |

**Resolve the code root from `engine.name` before writing any source file.** A
path shown as `src/…` alone is a Godot example: read it as *"the code root"* and
substitute the row above. `src/` is the table's Godot row, not a universal path.

**Tests follow the same rule** — the same compilers decide what they see:

| `engine.name` | Test root | Anywhere else |
|---|---|---|
| **Godot** | `tests/unit/`, `tests/integration/` | — |
| **Unity** | `Assets/Tests/EditMode/`, `Assets/Tests/PlayMode/` | not compiled: "0 tests, Passed" |
| **Unreal** | `Source/<Module>/Private/Tests/` | not built: "No automation tests matched" |

Read `tests/unit/[system]/` (or `integration/`) anywhere as the test root plus `[System]/`.

## Engine Version Reference

<!-- ENGINE-REFERENCE-IMPORT: the pointer below is engine-specific. /setup-engine
     rewrites it to docs/engine-reference/<engine>/VERSION.md for the chosen
     engine, so a Unity or Unreal project stops pointing at the Godot reference
     every session. It defaults to Godot (the template's example engine); skills
     that need the pinned version read docs/engine-reference/<engine>/VERSION.md
     on demand regardless of this pointer. -->
Pinned engine version: read `docs/engine-reference/godot/VERSION.md`.

## Technical Preferences

`project.yaml` at the repo root is the primary config store — engine, specialists,
naming, platform, performance, modes. Skills resolve it via `resolve_config`
(see `.zcode/docs/config-resolution.md`).

`.zcode/docs/technical-preferences.md` is the **legacy fallback**, read on demand
when a key is absent from `project.yaml`. It is not imported here: before
`/setup-engine` runs it is almost entirely `[TO BE CONFIGURED]` placeholders, and
after it runs `project.yaml` holds the real values.

## Coordination Rules

1. **Vertical Delegation**: Leadership agents delegate to department leads, who
   delegate to specialists. Never skip a tier for complex decisions.
2. **Horizontal Consultation**: Agents at the same tier may consult each other
   but must not make binding decisions outside their domain.
3. **Conflict Resolution**: When two agents disagree, escalate to the shared
   parent. If no shared parent, escalate to `creative-director` for design
   conflicts or `technical-director` for technical conflicts.
4. **Change Propagation**: When a design change affects multiple domains, the
   `producer` agent coordinates the propagation.
5. **No Unilateral Cross-Domain Changes**: An agent must never modify files
   outside its designated directories without explicit delegation.
6. **Read Design Docs by Section**: A brief names the sections an agent needs
   by heading. Find a heading in a GDD, ADR or the art bible by searching for
   `^#` headings (`grep -rn "^# "` via Bash) and Read that range with offset and
   limit; read a doc whole only when the task needs all of it, and say why.
   `validate-read.sh` refuses a whole-file read of a doc over 40 KB.
7. **Nothing Goes Upstream**: Never file, open or comment on an issue or pull
   request in an engine, plugin or vendor repository, even when asked. Write a
   draft (`/bug-report` drafts only) and the user submits it.

### Model Tier Assignment

Skills and agents set no model of their own in this port: everything runs on the
session's model. Read `.zcode/docs/model-tiers.md` on demand for how to re-add
per-agent `model:`/`thoughtLevel:` pins if you want a tiered studio.

### Subagents vs Agent Teams

This project uses two distinct multi-agent patterns:

**Subagents (always active).** Spawned via the `Agent` tool within a single
ZCode session. Used by all `team-*` skills and orchestration skills. Subagents
share the session's permission context, run sequentially or in parallel within
the session, and return results to the parent. If two subagents' inputs are
independent, spawn both `Agent` calls simultaneously rather than waiting
(example: `/review-all-gdds` Phases 2 and 3; Phase 1 loads the GDDs and both
depend on it, so it must NOT be parallelised).

**Agent Teams (experimental — opt-in).** Multiple independent ZCode *sessions*
coordinated via a shared task list. Opt-in only — read
`.zcode/docs/agent-teams.md` on demand before proposing one.

### Parallel Task Protocol

When an orchestration skill spawns multiple independent agents:

1. Issue all independent `Agent` calls before waiting for any result
2. Collect all results before proceeding to dependent phases
3. If any agent is BLOCKED, surface it immediately — do not silently skip
4. Always produce a partial report if some agents complete and others block

## Collaboration Protocol

**User-driven collaboration, not autonomous execution.**
Every task follows: **Question -> Options -> Decision -> Draft -> Approval**

- Agents MUST ask "May I write this to [filepath]?" before using Write/Edit tools
  (exempt: `active.md` appends, agent memory, a subagent's new file at the path
  its orchestrating skill named; see `.zcode/rules/agent-memory.md`)
- Agents MUST show drafts or summaries before requesting approval
- Multi-file changes require explicit approval for the full changeset
- No commits without user instruction
- A skipped or dismissed question is not an answer: act on nothing, re-ask in
  plain text and wait
- Started outside this folder? Warn first: workspace hooks load only when ZCode
  opens this project root

See `docs/COLLABORATIVE-DESIGN-PRINCIPLE.md` for full protocol and examples.

> **First session?** If the project has no engine configured and no game concept,
  run `/start` to begin the guided onboarding flow.

## Path-Scoped Rules

Claude Code loaded `.zcode/rules/*.md` automatically whenever a matching file
was edited. ZCode has no native path-scoped rules, so this port ships a
`zcode-inject-rules.sh` hook: on every Write/Edit it matches `tool_input.file_path`
against each rule's `paths:` globs and injects the matched rule into the context.
When that hook is disabled, read the matching rule yourself before editing:

| Path | Rule file |
|------|-----------|
| `src/gameplay/**` (+ Unity/Unreal gameplay code) | `.zcode/rules/gameplay-code.md` |
| `src/core/**` (+ engine code) | `.zcode/rules/engine-code.md` |
| `src/ai/**` | `.zcode/rules/ai-code.md` |
| `src/networking/**` | `.zcode/rules/network-code.md` |
| `src/ui/**` | `.zcode/rules/ui-code.md` |
| `design/gdd/**` | `.zcode/rules/design-docs.md` |
| `design/narrative/**` | `.zcode/rules/narrative.md` |
| `assets/data/**/*.json` | `.zcode/rules/data-files.md` |
| `assets/shaders/**` | `.zcode/rules/shader-code.md` |
| `**/*.tscn`, `**/*.tres` | `.zcode/rules/scene-files.md` |
| `tests/**` | `.zcode/rules/test-standards.md` |
| `prototypes/**` | `.zcode/rules/prototype-code.md` |
| `.zcode/agents/*.md` | `.zcode/rules/agent-memory.md` |
| `.zcode/skills/**` | `.zcode/rules/skill-authoring.md` |

## Coding Standards

- All game code must include doc comments on public APIs
- Architecture decisions are recorded as ADRs in `docs/architecture/`. **How many is
  set by `modes.workflow`** — all ADRs at `full`, *critical* ADRs only at `standard`,
  and none required at `minimal`, where the decision log and `design/game-brief.md`
  carry the rationale instead. See `.zcode/docs/workflow-modes.md`.
- Gameplay values must be data-driven (external config), never hardcoded
- All public methods must be unit-testable (dependency injection over singletons)
- Commits must reference the relevant design document or task ID
- **Commit messages**: Use Conventional Commits format — `feat:`, `fix:`, `chore:`, `docs:`, `test:`, `refactor:`. Reference the story or task ID in the body (e.g., `Story: EPIC-001-S02`).
- **Verification-driven development**: Write tests first when adding gameplay systems.
  For UI changes, verify with screenshots. Compare expected output to actual output
  before marking work complete. Every implementation should have a way to prove it works.
- **A parse check is not a run.** Every story that changes something
  player-observable is launched and observed before it closes, and the
  observation is a retained screenshot in `production/qa/evidence/`. Procedure
  per engine: `.zcode/docs/run-and-observe.md`. Not waived at
  `qa.level: minimal` — tests are, the look is not.

### Design Document Standards

- All design docs use Markdown
- Each mechanic has a dedicated document in `design/gdd/`
- **How many of the 8 sections are required depends on `modes.workflow`** —
  all 8 at `full`, 5 (+ Formulas when the system defines numeric rules — rates,
  curves, thresholds, costs; the system's `Category` is a hint, not the test) at
  `standard`, and no
  GDD at all at `minimal`, where `design/game-brief.md` is the design record.
  See `.zcode/docs/workflow-modes.md`. The 8 sections:
  1. **Overview** -- one-paragraph summary
  2. **Player Fantasy** -- intended feeling and experience
  3. **Detailed Rules** -- unambiguous mechanics
  4. **Formulas** -- all math defined with variables
  5. **Edge Cases** -- unusual situations handled
  6. **Dependencies** -- other systems listed
  7. **Tuning Knobs** -- configurable values identified
  8. **Acceptance Criteria** -- testable success conditions
- Balance values must link to their source formula or rationale

### Testing Standards

All stories must have appropriate test evidence before they can be marked Done:

| Story Type | Required Evidence | Location | Default Gate Level |
|---|---|---|---|
| **Logic** (formulas, AI, state machines) | Automated unit test — must pass | `tests/unit/[system]/` | BLOCKING |
| **Integration** (multi-system) | Integration test OR documented playtest | `tests/integration/[system]/` | BLOCKING |
| **Visual/Feel** (animation, VFX, feel) | Retained screenshot + lead sign-off | `production/qa/evidence/` | BLOCKING |
| **UI** (menus, HUD, screens) | Retained screenshot of each screen touched | `production/qa/evidence/` | BLOCKING |
| **Config/Data** (balance tuning) | Smoke check pass | `production/qa/smoke-[date].md` | ADVISORY |

The **Default Gate Level** applies when `testing.strict` is not set in
`project.yaml`; a project may override it per test type (`.logic`, `.integration`,
`.visual`, `.ui`, `.config` — `true` = BLOCKING, `false` = ADVISORY).

- **Naming**: per engine — `.zcode/rules/test-standards.md`
- **Determinism**: same result every run — no random seeds, no time-dependent assertions
- **Isolation**: each test sets up and tears down its own state; no order dependence
- **No hardcoded data**: fixtures use constant files or factory functions
  (exception: boundary value tests where the exact number IS the point)
- **Independence**: unit tests do not call external APIs, databases, or file I/O

## ZCode Port Notes

- **Tool names.** Some ported texts reference the Claude Code `Glob`/`Grep`
  tools. ZCode has no such tools: do the same through Bash — `Glob '<pattern>'`
  → `ls <pattern>` or `find . -name '<pattern>'`; `Grep pattern=X glob=Y` →
  `grep -rn 'X' --include='Y' .`
- **Skills and agents** load from `.zcode/skills/` and `.zcode/agents/`.
  Skill frontmatter is `name` + `description`; agent frontmatter may also set
  `tools:` (and optionally `model:`/`thoughtLevel:` — see
  `.zcode/docs/model-tiers.md`).
- **Hooks** are registered in `.zcode/config.json` under `hooks.events` with
  `hooks.enabled: true`. Their stdin payload is Claude-Code-shaped
  (`tool_name`, `tool_input`, `session_id`, ...); plain-text stdout on exit 0 is
  ignored — model-visible output must be JSON (`additionalContext`,
  `systemMessage`). `.zcode/docs/hooks-reference.md` maps every hook to its
  ZCode event.

## Context Management

Read `.zcode/docs/context-management.md` on demand — it is a reference, not
session context. Two of its conventions are load-bearing and cited by name
elsewhere in the repo, so they are restated here rather than lost:

- **`production/session-state/active.md` is the session checkpoint.** The file is
  the memory, not the conversation. Read it first after any compaction, crash, or
  `/clear`.
- **Helpers in `.zcode/scripts/` emit observations, never verdicts.** A script
  that scores or judges will eventually contradict a mode or override it cannot
  see. (Cited by `artifact-check.sh` and `adr-dep-graph.sh`.)
