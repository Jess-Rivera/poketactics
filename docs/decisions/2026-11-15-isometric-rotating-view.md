# Isometric view with 4-way rotation

Date: 2026-11-15. Owner: Jess. Canonical: docs/discussion-outputs/godot-primer.md (Isometric with rotation)

- Battles use an isometric view the player can rotate in 90 degree steps (four views), as in FFT and Triangle
  Strategy.
- Sprites stay 2D SpriteCollab sheets (8 facing rows); the row drawn is the unit's facing turned by the camera's
  rotation.
- The map is 3D blocks (GridMap) under an orthographic camera at the iso angle, with 2D sprites (Jess, 2026-11-15).
- Still open: block and prop art (where it comes from, texel size, style).
