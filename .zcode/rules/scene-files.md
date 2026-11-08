---
paths:
  - "**/*.tscn"
  - "**/*.tres"

---

# Scene and Asset File Rules

The engine's editor writes these files. A hand edit that breaks one can stop a
scene loading, or drop references without an error. Change them in the editor
when you can.

## Godot (`.tscn`, `.tres`, `.uid`)

When you edit the text by hand:

- Never change the `format=` value in the `[gd_scene]` or `[gd_resource]` header.
- Never reuse an `id`: every `[ext_resource]` and `[sub_resource]` id is unique in its file.
- Never copy a node block with its `unique_id=` (Godot 4.6+). Drop it from the copy.
- Never invent a `uid://` value. Leave `uid=` off a new reference and let the
  editor or `godot --headless --path . --import` assign it.
- Never hand-edit TileMapLayer or GridMap cell data. It is encoded, so change it in the editor.
- Never edit or delete a `.uid` file, and commit it with its script or shader.
  Godot 4.4+ writes one beside each; when you move or rename the script or
  shader outside the editor, move its `.uid` with it.
- After a hand edit, run `godot --headless --path . --import` and open or run
  the scene once to confirm it loads without errors.

