# /setup-engine — Section 5: Populate Technical Preferences

> Part of `/setup-engine`. `SKILL.md` names when to read this file; the settings it
> resolved and the rules under its later headings still apply here.

## 5. Populate Technical Preferences

**In this file:**

- Engine & Language Section
- Naming Conventions (engine defaults)
- Input & Platform Section
- Remaining Sections
- Engine Specialists Routing
- Collaborative Step

After updating AGENTS.md, create or update `.zcode/docs/technical-preferences.md` with
engine-appropriate defaults. Read the existing template first, then fill in:

### Engine & Language Section
- Fill from the engine choice made in step 4

### Naming Conventions (engine defaults)

**For Godot** — see `references/godot-language-config.md` (**A2**) for GDScript, C#, and Both variants.



### Input & Platform Section

Populate `## Input & Platform` using the answers gathered in Section 2 (or extracted
from the game concept). Derive the values using this mapping:

| Platform target | Gamepad Support | Touch Support |
|-----------------|-----------------|---------------|
| PC only | Partial (recommended) | None |
| Console | Full | None |
| Mobile | None | Full |
| PC + Console | Full | None |
| PC + Mobile | Partial | Full |
| Web | Partial | Partial |

For **Primary Input**, use the dominant input for the game genre:
- Action/RPG/platformer targeting console → Gamepad
- Strategy/point-and-click/RTS → Keyboard/Mouse
- Mobile game → Touch
- Cross-platform → ask the user

> **Genre may not exist yet — check before deriving from it.** At `minimal` the
> design artifact is `design/game-brief.md`, and it is authored *after* this
> skill runs (Section 2 says so explicitly). There is no genre to map. The same
> is true at any tier when `/setup-engine` is run before the concept exists.
>
> When genre is unavailable, **ask** — do not infer one from the platform, and do
> not leave the field silently blank:
> - Prompt: "Primary input for a [2D/3D] [platform] game? Genre isn't established
>   yet — the brief comes next — so this can't be derived."
> - Options: the plausible inputs for that platform, plus
>   `Leave as [TO BE CONFIGURED]` — a legitimate answer here, revisited via
>   `/settings` once the brief exists.
>
> Gamepad Support and Touch Support still come from the platform table above;
> only Primary Input depends on genre.

Present the derived values and ask the user to confirm or adjust before writing.

Example filled section:
```markdown
## Input & Platform
- **Target Platforms**: PC, Console
- **Input Methods**: Keyboard/Mouse, Gamepad
- **Primary Input**: Gamepad
- **Gamepad Support**: Full
- **Touch Support**: None
- **Platform Notes**: All UI must support d-pad navigation. No hover-only interactions.
```

### Remaining Sections
- **Performance Budgets**: Use `AskUserQuestion`:
  - Prompt: "Should I set default performance budgets now, or leave them for later?"
  - Options: `[A] Set defaults now (60fps, 16.6ms frame budget, engine-appropriate draw call limit)` / `[B] Leave as [TO BE CONFIGURED] — I'll set these when I know my target hardware`
  - If [A]: populate with the suggested defaults. If [B]: leave as placeholder.
- **Testing**: Suggest **gdUnit4** (this edition's framework) and ask before adding.
  > **Must match `commands.test` in Section 5.5.1, which writes gdUnit4's own
  > runner (`res://addons/gdUnit4/bin/GdUnitCmdTool.gd`), and
  > `.zcode/docs/coding-standards.md`, which names the same runner.** Naming GUT
  > here would have the skill recommend one framework and configure another in the
  > same run.
- **Forbidden Patterns**: Leave as placeholder — do NOT pre-populate.
- **Allowed Libraries**: Leave as placeholder — do NOT pre-populate dependencies the project does not currently need. Only add a library here when it is actively being integrated, not speculatively.

> **Guardrail**: Never add speculative dependencies to Allowed Libraries. For example, do NOT add GodotSteam unless Steam integration is actively beginning in this session. Post-launch integrations should be added to Allowed Libraries when that work begins, not during engine setup.

### Engine Specialists Routing

Also populate the `## Engine Specialists` section in `technical-preferences.md` with the correct routing for the chosen engine:

**For Godot** — see `references/godot-language-config.md` (**A3**) for the routing table matching the language chosen.

### Collaborative Step
### Collaborative Step
Present the filled-in preferences to the user. For Godot, include the chosen language and note where the full naming conventions and routing tables live:
> "Here are the default technical preferences for [engine] ([language if Godot]). The naming conventions and specialist routing are in this skill's references directory — I'll apply the [GDScript/C#/Both] variant. Want to customize any of these, or may I save them to `.zcode/docs/technical-preferences.md`?"

Wait for approval before writing the file.

---
