# Sprite sources: SpriteCollab for Pokemon, RawAsset later for the rest

Date: 2026-11-15. Owner: Jess. Canonical: docs/discussion-outputs/sprites-primer.md

- Pokemon sprites (and portraits, if used) come fresh from PMDCollab/SpriteCollab (CC BY-NC 4.0, per-sprite
  credits), pinned at one commit like pokeapi. Not from the fork, not from RawAsset.
- PMDCollab/RawAsset is the planned source for non-Pokemon art (tiles, items, particles, backgrounds) when a slice
  needs it. It has no license file, so its terms are checked before anything from it ships.
- Fetched sets: every species' normal set, the mainline forms, and the shiny of each, with Anim, Offsets and
  Shadow sheets, into assets/pokemon/ in plain git (Jess, 2026-11-15). Tool: tools/fetch-spritecollab.js.
