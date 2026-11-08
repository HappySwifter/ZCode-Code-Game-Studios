---
paths:
  - "assets/data/**/*.json"

---

# Data File Rules

- All JSON files must be valid JSON — broken JSON blocks the entire build pipeline
- File naming: lowercase with underscores only, following `[system]_[name].json` pattern
- Every data file must have a documented schema (either JSON Schema or documented in the corresponding design doc)
- Numeric values must include comments or companion docs explaining what the numbers mean
- Use consistent key naming: **`snake_case` for keys within JSON files**, matching
  the `[system]_[name].json` file convention one line above and the engine idiom
  every other standard in this repo uses.

- No orphaned data entries — every entry must be referenced by code or another data file
- Version data files when making breaking schema changes
- Include sensible defaults for all optional fields

## Examples

**Correct** naming and structure (`combat_enemies.json`):

```json
{
  "goblin": {
    "base_health": 50,
    "base_damage": 8,
    "move_speed": 3.5,
    "loot_table": "loot_goblin_common"
  },
  "goblin_chief": {
    "base_health": 150,
    "base_damage": 20,
    "move_speed": 2.8,
    "loot_table": "loot_goblin_rare"
  }
}
```

**Incorrect** (`EnemyData.json`):

```json
{
  "Goblin": { "hp": 50 }
}
```

Violations: uppercase filename, uppercase key, no `[system]_[name]` pattern, missing required fields.
