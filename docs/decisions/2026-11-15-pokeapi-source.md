# pokeapi data: raw CSVs copied in, frozen at one upstream commit

Date: 2026-11-15. Owner: Jess. Canonical: docs/discussion-outputs/pokeapi-primer.md

- Pokemon facts come from the official PokeAPI repo (github.com/PokeAPI/pokeapi), data/v2/csv, copied into
  source/pokeapi/ as raw files. Nothing in the game or tools reaches pokeapi at run time.
- Frozen at commit db06b37dca1b33c82edad3fe73ca7e909845e548 (2026-11-12). source/pokeapi/README.md records the
  commit and fetch date (the "PIN" note). Re-pinning is done on purpose, as its own issue.
- The fork's copy is not used (mid-October snapshot, CRLF line endings, extra files).
- .gitattributes keeps all text files LF so the files stay byte-identical across machines.
