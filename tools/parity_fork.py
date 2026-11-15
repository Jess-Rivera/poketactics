#!/usr/bin/env python3
"""One-off parity check: our data pack against the PokeSurvivor fork's pokedex (two sources, same facts).

Compares base stats and types of every species default unit with the fork's entry of the same dex number. The fork
is read for reference only (CLAUDE.md "Clean-room rule"); nothing from it is written anywhere. Prints a report and
exits 0; differences are for a person to explain, since the fork's pokeapi copy is about a month older than ours.
Run once before issue #2 closes (docs/discussion-outputs/data-pack-plan.md).

Usage (repo root): python tools/parity_fork.py [path to the fork, default C:/dev/pokesurvivor_fork]
"""

import json
import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
DEFAULT_FORK = Path("C:/dev/pokesurvivor_fork")
FORK_POKEDEX = Path("js/data/pokedex.js")
# The fork's stats list is in mainline order.
STAT_ORDER = ["hp", "attack", "defense", "special_attack", "special_defense", "speed"]
FORK_ENTRY = re.compile(r"\{\"dex\":\d+.*?\}")


def main():
    fork = Path(sys.argv[1]) if len(sys.argv) > 1 else DEFAULT_FORK
    text = (fork / FORK_POKEDEX).read_text(encoding="utf-8")
    fork_entries = {}
    for match in FORK_ENTRY.finditer(text):
        entry = json.loads(match.group(0))
        fork_entries[entry["dex"]] = entry
    units = json.loads((REPO_ROOT / "data" / "units.json").read_text(encoding="utf-8"))
    defaults = {unit["dex_number"]: (name, unit) for name, unit in units.items() if unit["is_species_default"]}

    differences = []
    shared = sorted(set(fork_entries) & set(defaults))
    for dex in shared:
        name, unit = defaults[dex]
        fork_entry = fork_entries[dex]
        ours = [unit["base_stats"][key] for key in STAT_ORDER]
        if ours != fork_entry["stats"]:
            differences.append(f"{name} (#{dex}) stats: ours {ours}, fork {fork_entry['stats']}")
        if unit["types"] != fork_entry["types"]:
            differences.append(f"{name} (#{dex}) types: ours {unit['types']}, fork {fork_entry['types']}")

    print(f"Fork entries: {len(fork_entries)}. Our species defaults: {len(defaults)}. Shared dex numbers: {len(shared)}.")
    print(f"Only in the fork: {sorted(set(fork_entries) - set(defaults))}")
    print(f"Differences: {len(differences)}")
    for line in differences:
        print("  " + line)
    return 0


if __name__ == "__main__":
    sys.exit(main())
