# Base resolution 640x360, integer scaling

Date: 2026-11-15. Owner: Jess. Canonical: docs/discussion-outputs/godot-primer.md

- The game draws at 640x360 and scales up by whole numbers only (2x 720p, 3x 1080p, 4x 1440p, 6x 4K), with
  nearest-neighbor filtering, so pixels stay square and crisp.
- Grid projection: isometric with 4-way rotation (2026-11-15-isometric-rotating-view); 640x360 suits it.
