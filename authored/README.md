# authored (hand-written game data)

Game data written by hand, read by tools/export_pack.py when it builds data/. Unlike source/ (pinned upstream
data, never edited) these files are ours to change; rerun `python tools/export_pack.py` after an edit.

- move_grid_overrides.json: the moves that get a grid entry (issue #9), each with fields that replace the
  derived default. An empty object keeps the default. Fields and defaults: tools/move_grid.py. Rulings:
  docs/decisions/2026-11-16-move-shapes-and-range.md.
