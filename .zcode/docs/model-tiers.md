# Model Tier Assignment

> **Ported to ZCode:** Claude Code let each skill and agent pin a model tier
> (`haiku`, `sonnet`, `opus`, `inherit`). ZCode skills load only `name` and
> `description` from SKILL.md frontmatter, and the port deliberately sets no
> `model:` on agents either — every skill and every agent runs on your
> session's model, which is also what the thirty `model: inherit` agents did
> before.

## If you want a tiered studio again

ZCode agent frontmatter accepts a `model:` (a full `provider/model` id as
listed by its model picker) and a `thoughtLevel:` (`low` ... `max`). To rebuild
the old three-tier shape, edit `.zcode/agents/*.md`:

| Old Claude Code pin | ZCode equivalent |
|---|---|
| `model: opus` (directors) | `model: <your strongest model>` and/or `thoughtLevel: max` |
| `model: sonnet` (leads, 16 specialists) | `model: <your everyday model>` (or omit — session default) |
| `model: inherit` (30 agents) | omit `model:` — the session model |

A hard-coded `model:` id ties the repo to one account's provider names, so the
template ships without pins; add them per-project if you want them.
