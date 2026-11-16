# Learn methods: all four in the pack, use decided at design

Date: 2026-11-15. Owner: Jess. Canonical: docs/discussion-outputs/pokeapi-primer.md

- The data pack keeps every move a unit learns in its learnset game, tagged with its method: level-up (with level),
  machine, egg, tutor.
- Which methods the game uses (and how, for example TMs as rewards) is a design ruling, made when progression is
  designed. Until then nothing in game code assumes a method other than level-up.

Updated by 2026-11-16-moves-and-shops (level-up automatic; shops sell machine, tutor and egg moves).
