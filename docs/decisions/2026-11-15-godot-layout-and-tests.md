# Godot folder layout by role; gdUnit4 for tests

Date: 2026-11-15. Owner: Jess. Canonical: docs/discussion-outputs/godot-primer.md

- The repo root is the Godot project. Folders by role: rules/ (simulation, no nodes or drawing, runs headless),
  view/ (scenes and anything that draws), tests/, data/, assets/. source/, tools/ and docs/ carry .gdignore.
- A file in rules/ that refers to view/ is a bug.
- Tests use gdUnit4 (MIT add-on in addons/gdUnit4, v6.2.3 supports Godot 4.6), run headless from the command line.
