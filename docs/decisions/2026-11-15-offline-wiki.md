# Offline wiki: static HTML, built from the data pack, committed

Date: 2026-11-15. Owner: Jess. Canonical: docs/discussion-outputs/pokeapi-primer.md

- A tools/ script builds a static HTML wiki (one page per unit, move, ability and type, cross-linked, with search)
  from the data/ JSON pack, so it shows exactly what the game loads. It opens from disk in any browser.
- The generated pages are committed, so the work machine can read them without running the build.
- The game never reads the CSVs or the wiki; it loads the pack.
