# authored (hand-written game data)

Game data written by hand, read by tools/export_pack.py when it builds data/. Unlike source/ (pinned upstream
data, never edited) these files are ours to change; rerun `python tools/export_pack.py` after an edit.

- move_recipe_overrides.json: the moves that get a recipe (issues #9, #27), each with top-level recipe fields that
  replace the derived default whole (a whole shape, a whole component list). An empty object keeps the default.
  Fields and defaults: tools/move_grid.py. Rulings: docs/decisions/2026-11-17-move-recipe-structure.md.
