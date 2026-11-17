# Move recipes: build split and scope (#27, #28)

Date: 2026-11-17. Owner: Jess. Canonical: docs/discussion-outputs/ecs-vs-effect-pipeline.md

- Two slices. #27: recipes, the square/circle shape model, one handler per effect; the 45 roster moves behave
  exactly as before. #28: upgrades (filter plus change), splash, Wide Breath demo, hotseat debug toggle.
- Handlers now: damage, fixed damage, faint (splash in #28). Other effects stay as recipe data until their systems
  exist (stat and ailments in M2b, tile elements in #21).
- export writes the recipe format into data/moves.json; the overrides file moves to the new field names; the old
  grid format is dropped. Upgrades: authored/upgrades.json exported to data/upgrades.json.
- Upgrades granted through the test battle setup and a hotseat debug toggle until shops exist.
- AI, preview, forecast and move menu read the built move, never the raw recipe.
- Footprints stay precomputed tables, extended to every radius and angle an upgrade can reach, up to a cap.
  arcing stays in the basics, unchanged until #18.
