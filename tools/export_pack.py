#!/usr/bin/env python3
"""Export the pinned pokeapi CSVs (source/pokeapi/csv) into the game's JSON data pack (data/).

Writes data/units.json, data/moves.json, data/abilities.json, data/types.json and data/README.md.
Every entry is keyed by its pokeapi name (vulpix-alola, ember); the pokeapi number is kept as pokeapi_id.

Shaped by the rulings in docs/decisions/ (2026-11-15-*):
  unit-is-pokemon-variant, variant-scope   units are species defaults plus regional forms
  mega-gmax-transform                      Mega, Gigantamax and Primal attach to their base unit
  learnset-game, learn-methods             one learnset game per unit, all four learn methods kept
Plan: docs/discussion-outputs/data-pack-plan.md (issue #2).

Python 3 standard library only. Output is deterministic: sorted keys, LF, UTF-8, scalar-only lists and objects on
one line (so one learnset entry is one line).

Usage (repo root):
  python tools/export_pack.py           write data/
  python tools/export_pack.py --check   rebuild into a temp folder and fail if any file differs from data/
"""

import csv
import filecmp
import json
import re
import sys
import tempfile
from collections import defaultdict
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
CSV_FOLDER = REPO_ROOT / "source" / "pokeapi" / "csv"
PIN_NOTE = REPO_ROOT / "source" / "pokeapi" / "README.md"
PACK_FOLDER = REPO_ROOT / "data"
SPRITE_TRACKER = REPO_ROOT / "source" / "spritecollab" / "tracker.json"
PACKED_SPRITE_FOLDER = REPO_ROOT / "assets" / "pokemon"
PACK_FILES = ["units.json", "moves.json", "abilities.json", "types.json", "README.md"]

ENGLISH = "9"
REGIONS = ["alola", "galar", "hisui", "paldea"]
REGIONAL_NAME = re.compile(r"-(" + "|".join(REGIONS) + r")(-|$)")
TRANSFORMATION_SUFFIX = re.compile(r"-(mega(-[xyz])?|gmax|primal)$")
TRANSFORMATION_KIND = {"mega": "mega", "gmax": "gigantamax", "primal": "primal"}
# SpriteCollab form name for a transformation suffix (tracker.json names every form folder).
TRANSFORMATION_SPRITE_FORM = {"mega": "Mega", "mega-x": "Mega_X", "mega-y": "Mega_Y", "mega-z": "Mega_Z", "gmax": "Gigantamax", "primal": "Primal"}
# Name parts that only say "the usual one" in pokeapi and have no SpriteCollab form name of their own.
PLAIN_FORM_WORDS = {"standard", "combat", "breed"}
# Non-default regional-looking names that are not regional forms (variant-scope ruling).
NOT_REGIONAL_WORDS = ["totem", "cap"]
PREFERRED_LEARNSET_GAME = "scarlet-violet"
SKIPPED_LEARNSET_GAMES = {"legends-arceus", "champions"}
LEARN_METHODS = {"level-up", "machine", "egg", "tutor"}
LEVEL_UP = "level-up"
STAT_KEYS = {
    "hp": "hp",
    "attack": "attack",
    "defense": "defense",
    "special-attack": "special_attack",
    "special-defense": "special_defense",
    "speed": "speed",
}
ATTACK_TYPE_COUNT = 18
# Colosseum and XD Shadow moves sit at 10001 and up (Shadow Ball and Shadow Claw are ordinary moves below it).
FIRST_SHADOW_MOVE_ID = 10000
# Evolution condition columns: column name -> (pack key, table that turns the id into a name, or None).
EVOLUTION_CONDITIONS = {
    "trigger_item_id": ("item", "items"),
    "minimum_level": ("minimum_level", None),
    "gender_id": ("gender", "genders"),
    "location_id": ("location", "locations"),
    "held_item_id": ("held_item", "items"),
    "time_of_day": ("time_of_day", None),
    "known_move_id": ("known_move", "moves"),
    "known_move_type_id": ("known_move_type", "types"),
    "minimum_happiness": ("minimum_happiness", None),
    "minimum_beauty": ("minimum_beauty", None),
    "minimum_affection": ("minimum_affection", None),
    "relative_physical_stats": ("relative_physical_stats", None),
    "party_species_id": ("party_species", "pokemon_species"),
    "party_type_id": ("party_type", "types"),
    "trade_species_id": ("trade_species", "pokemon_species"),
    "region_id": ("region", "regions"),
    "used_move_id": ("used_move", "moves"),
    "minimum_move_count": ("minimum_move_count", None),
    "minimum_steps": ("minimum_steps", None),
    "minimum_damage_taken": ("minimum_damage_taken", None),
    "nature_bitmask": ("nature_bitmask", None),
    "condition_expression": ("condition_expression", None),
    "percentage_chance": ("percentage_chance", None),
}
EVOLUTION_FLAGS = {
    "needs_overworld_rain": "needs_overworld_rain",
    "turn_upside_down": "turn_upside_down",
    "needs_multiplayer": "needs_multiplayer",
    "near_special_rock": "near_special_rock",
}


def read_table(name):
    with open(CSV_FOLDER / f"{name}.csv", encoding="utf-8", newline="") as handle:
        return list(csv.DictReader(handle))


def by_id(rows, key="id"):
    return {row[key]: row for row in rows}


def number_or_none(text):
    if text == "":
        return None
    return int(text)


def clean_text(text):
    """Join in-game text broken over lines (soft hyphens, newlines, form feeds) into one plain line."""
    text = text.replace("­\n", "").replace("­", "")
    return " ".join(text.split())


def english_by(rows, id_key, field):
    return {row[id_key]: clean_text(row[field]) for row in rows if row.get("local_language_id", row.get("language_id")) == ENGLISH}


class Source:
    """The CSV tables the export reads, indexed by id."""

    def __init__(self):
        self.pokemon = read_table("pokemon")
        self.pokemon_by_id = by_id(self.pokemon)
        self.pokemon_by_name = {row["identifier"]: row for row in self.pokemon}
        self.species = by_id(read_table("pokemon_species"))
        self.forms = by_id(read_table("pokemon_forms"))
        self.default_form_of_pokemon = {f["pokemon_id"]: f for f in self.forms.values() if f["is_default"] == "1"}
        self.species_names = english_by(read_table("pokemon_species_names"), "pokemon_species_id", "name")
        self.form_pokemon_names = english_by(read_table("pokemon_form_names"), "pokemon_form_id", "pokemon_name")
        self.stats = by_id(read_table("stats"))
        self.types = by_id(read_table("types"))
        self.type_names = english_by(read_table("type_names"), "type_id", "name")
        self.abilities = by_id(read_table("abilities"))
        self.ability_names = english_by(read_table("ability_names"), "ability_id", "name")
        self.ability_effects = english_by(read_table("ability_prose"), "ability_id", "short_effect")
        self.moves = by_id(read_table("moves"))
        self.move_names = english_by(read_table("move_names"), "move_id", "name")
        self.move_effects = english_by(read_table("move_effect_prose"), "move_effect_id", "short_effect")
        self.move_meta = by_id(read_table("move_meta"), "move_id")
        self.damage_classes = by_id(read_table("move_damage_classes"))
        self.move_targets = by_id(read_table("move_targets"))
        self.meta_categories = by_id(read_table("move_meta_categories"))
        self.meta_ailments = by_id(read_table("move_meta_ailments"))
        self.growth_rates = by_id(read_table("growth_rates"))
        self.version_groups = by_id(read_table("version_groups"))
        self.learn_methods = by_id(read_table("pokemon_move_methods"))
        self.evolution_triggers = by_id(read_table("evolution_triggers"))
        self.name_tables = {
            "items": by_id(read_table("items")),
            "genders": by_id(read_table("genders")),
            "locations": by_id(read_table("locations")),
            "moves": self.moves,
            "types": self.types,
            "pokemon_species": self.species,
            "regions": by_id(read_table("regions")),
        }
        self.stats_of = defaultdict(list)
        for row in read_table("pokemon_stats"):
            self.stats_of[row["pokemon_id"]].append(row)
        self.types_of = defaultdict(list)
        for row in read_table("pokemon_types"):
            self.types_of[row["pokemon_id"]].append(row)
        self.abilities_of = defaultdict(list)
        for row in read_table("pokemon_abilities"):
            self.abilities_of[row["pokemon_id"]].append(row)
        self.stat_changes_of = defaultdict(list)
        for row in read_table("move_meta_stat_changes"):
            self.stat_changes_of[row["move_id"]].append(row)
        self.newest_flavor_of_move = {}
        newest_order = {}
        for row in read_table("move_flavor_text"):
            if row["language_id"] != ENGLISH:
                continue
            order = int(self.version_groups[row["version_group_id"]]["order"])
            if order >= newest_order.get(row["move_id"], -1):
                newest_order[row["move_id"]] = order
                self.newest_flavor_of_move[row["move_id"]] = clean_text(row["flavor_text"])
        self.learnset_rows = defaultdict(list)
        self.level_up_games = defaultdict(set)
        for row in read_table("pokemon_moves"):
            self.learnset_rows[(row["pokemon_id"], row["version_group_id"])].append(row)
            if self.learn_methods[row["pokemon_move_method_id"]]["identifier"] == LEVEL_UP:
                self.level_up_games[row["pokemon_id"]].add(row["version_group_id"])
        self.evolutions_into_species = defaultdict(list)
        for row in read_table("pokemon_evolution"):
            parent = self.species[row["evolved_species_id"]]["evolves_from_species_id"]
            self.evolutions_into_species[parent].append(row)
        self.type_efficacy = read_table("type_efficacy")


class SpriteSets:
    """Which packed sprite set (assets/pokemon/) draws a unit or transformation, matched by SpriteCollab form name."""

    def __init__(self):
        tracker = json.loads(SPRITE_TRACKER.read_text(encoding="utf-8"))
        self.form_folder = {
            dex: {form["name"]: folder for folder, form in species.get("subgroups", {}).items()} for dex, species in tracker.items()
        }
        self.packed = {path.stem for path in PACKED_SPRITE_FOLDER.glob("*.json")}

    def set_for(self, dex_number, form_name):
        """The packed set id for a dex number and SpriteCollab form name ("" is the normal form), or None."""
        dex = f"{dex_number:04d}"
        if form_name == "":
            return dex if dex in self.packed else None
        folder = self.form_folder.get(dex, {}).get(form_name)
        set_id = f"{dex}-{folder}" if folder else None
        return set_id if set_id in self.packed else None

    def for_unit(self, pokemon_row, regional_form, dex_number):
        if not regional_form:
            return self.set_for(dex_number, "")
        name_parts = pokemon_row["identifier"].split("-")
        extra_words = name_parts[name_parts.index(regional_form) + 1 :]
        extra_words = [word.capitalize() for word in extra_words if word not in PLAIN_FORM_WORDS]
        return self.set_for(dex_number, "_".join([regional_form.capitalize(), *extra_words]))

    def for_transformation(self, suffix, dex_number):
        return self.set_for(dex_number, TRANSFORMATION_SPRITE_FORM[suffix])


def regional_form_of(pokemon_row, source):
    """The region a non-default pokemon is a regional form of, or None if it is not one."""
    name = pokemon_row["identifier"]
    if pokemon_row["is_default"] == "1" or TRANSFORMATION_SUFFIX.search(name):
        return None
    if any(word in name.split("-") for word in NOT_REGIONAL_WORDS):
        return None
    default_form = source.default_form_of_pokemon.get(pokemon_row["id"])
    if default_form and default_form["is_battle_only"] == "1":
        return None
    match = REGIONAL_NAME.search(name)
    return match.group(1) if match else None


def english_pokemon_name(pokemon_row, source):
    if pokemon_row["is_default"] == "1":
        return source.species_names[pokemon_row["species_id"]]
    default_form = source.default_form_of_pokemon.get(pokemon_row["id"])
    if default_form and source.form_pokemon_names.get(default_form["id"]):
        return source.form_pokemon_names[default_form["id"]]
    return source.species_names[pokemon_row["species_id"]]


def battle_facts(pokemon_row, source):
    """Types, stats and abilities: what a unit and each of its transformations carry."""
    pokemon_id = pokemon_row["id"]
    base_stats = {}
    ev_yield = {}
    for row in source.stats_of[pokemon_id]:
        key = STAT_KEYS[source.stats[row["stat_id"]]["identifier"]]
        base_stats[key] = int(row["base_stat"])
        ev_yield[key] = int(row["effort"])
    types = [source.types[row["type_id"]]["identifier"] for row in sorted(source.types_of[pokemon_id], key=lambda row: int(row["slot"]))]
    abilities = [
        {"ability": source.abilities[row["ability_id"]]["identifier"], "slot": int(row["slot"]), "hidden": row["is_hidden"] == "1"}
        for row in sorted(source.abilities_of[pokemon_id], key=lambda row: int(row["slot"]))
    ]
    return {
        "pokeapi_id": int(pokemon_id),
        "english_name": english_pokemon_name(pokemon_row, source),
        "types": types,
        "base_stats": base_stats,
        "ev_yield": ev_yield,
        "abilities": abilities,
        "height_decimetres": int(pokemon_row["height"]),
        "weight_hectograms": int(pokemon_row["weight"]),
    }


def learnset(pokemon_row, source):
    """One game's learnset (learnset-game ruling) with every learn method (learn-methods ruling)."""
    games = {
        game_id
        for game_id in source.level_up_games[pokemon_row["id"]]
        if source.version_groups[game_id]["identifier"] not in SKIPPED_LEARNSET_GAMES
    }
    game_names = {game_id: source.version_groups[game_id]["identifier"] for game_id in games}
    preferred = [game_id for game_id, name in game_names.items() if name == PREFERRED_LEARNSET_GAME]
    if preferred:
        chosen = preferred[0]
    else:
        preferred_order = min(
            (int(row["order"]) for row in source.version_groups.values() if row["identifier"] == PREFERRED_LEARNSET_GAME)
        )
        earlier = [game_id for game_id in games if int(source.version_groups[game_id]["order"]) < preferred_order]
        if not earlier:
            raise SystemExit(f"no learnset game for {pokemon_row['identifier']}")
        chosen = max(earlier, key=lambda game_id: int(source.version_groups[game_id]["order"]))
    entries = set()
    for row in source.learnset_rows[(pokemon_row["id"], chosen)]:
        method = source.learn_methods[row["pokemon_move_method_id"]]["identifier"]
        if method not in LEARN_METHODS:
            raise SystemExit(f"unexpected learn method {method} for {pokemon_row['identifier']}")
        level = int(row["level"]) if method == LEVEL_UP else None
        entries.add((method, -1 if level is None else level, source.moves[row["move_id"]]["identifier"]))
    moves = [
        {"method": method, "level": None if level == -1 else level, "move": move} for method, level, move in sorted(entries)
    ]
    for entry in moves:
        if entry["level"] is None:
            del entry["level"]
    return {
        "game": game_names[chosen],
        "games_with_level_up": sorted(game_names.values()),
        "moves": moves,
    }


def evolution_conditions(row, source):
    conditions = {}
    for column, (key, table) in EVOLUTION_CONDITIONS.items():
        value = row[column]
        if value == "":
            continue
        if table:
            conditions[key] = source.name_tables[table][value]["identifier"]
        elif column in ("time_of_day", "condition_expression"):
            conditions[key] = value
        else:
            conditions[key] = int(value)
    for column, key in EVOLUTION_FLAGS.items():
        if row[column] == "1":
            conditions[key] = True
    return conditions


def evolutions(unit_row, unit_names, source, dropped):
    """Evolutions of one unit, resolved to units.

    pokeapi stores evolutions per species. A row naming a required form applies to the unit that form belongs to;
    a row without one applies to the species default only, so a regional unit keeps only its own lines. The target
    is the named evolved form's pokemon, else the evolved species' default. Targets outside the variant scope are
    dropped and listed in the README. The same method listed for several games is kept once.
    """
    found = {}
    for row in source.evolutions_into_species[unit_row["species_id"]]:
        required_form = row["required_pokemon_form_id"]
        if required_form:
            if source.forms[required_form]["pokemon_id"] != unit_row["id"]:
                continue
        elif unit_row["is_default"] != "1":
            continue
        if row["evolved_pokemon_form_id"]:
            target_row = source.pokemon_by_id[source.forms[row["evolved_pokemon_form_id"]]["pokemon_id"]]
        else:
            target_row = next(
                p for p in source.pokemon if p["species_id"] == row["evolved_species_id"] and p["is_default"] == "1"
            )
        target = target_row["identifier"]
        if target not in unit_names:
            dropped.add((unit_row["identifier"], target))
            continue
        entry = {
            "into": target,
            "trigger": source.evolution_triggers[row["evolution_trigger_id"]]["identifier"],
            "conditions": evolution_conditions(row, source),
        }
        found[json.dumps(entry, sort_keys=True)] = entry
    return [found[key] for key in sorted(found)]


def build_units(source, sprite_sets):
    unit_rows = [row for row in source.pokemon if row["is_default"] == "1" or regional_form_of(row, source)]
    unit_names = {row["identifier"] for row in unit_rows}
    default_unit_of_species = {row["species_id"]: row["identifier"] for row in unit_rows if row["is_default"] == "1"}

    transformations = defaultdict(list)
    left_out_transformations = []
    for row in source.pokemon:
        match = TRANSFORMATION_SUFFIX.search(row["identifier"]) if row["is_default"] == "0" else None
        if not match:
            continue
        base_name = row["identifier"][: match.start()]
        if base_name in unit_names:
            base = base_name
        elif base_name in source.pokemon_by_name:
            # The base form exists but is an excluded variant (female Meowstic, Rapid Strike Urshifu): left out.
            left_out_transformations.append((row["identifier"], base_name))
            continue
        else:
            # The base has no plain pokemon of that name (pyroar is pyroar-male): the species default is the base.
            base = default_unit_of_species[row["species_id"]]
        kind = TRANSFORMATION_KIND[match.group(1).split("-")[0]]
        transformation = battle_facts(row, source)
        del transformation["ev_yield"]
        transformation["sprite_set"] = sprite_sets.for_transformation(match.group(1), int(row["species_id"]))
        transformation["kind"] = kind
        transformation["name"] = row["identifier"]
        transformations[base].append(transformation)

    dropped_evolutions = set()
    units = {}
    for row in unit_rows:
        species = source.species[row["species_id"]]
        unit = battle_facts(row, source)
        unit.update(
            {
                "species": species["identifier"],
                "dex_number": int(species["id"]),
                "generation": int(species["generation_id"]),
                "is_species_default": row["is_default"] == "1",
                "regional_form": regional_form_of(row, source),
                "sprite_set": sprite_sets.for_unit(row, regional_form_of(row, source), int(species["id"])),
                "base_experience": number_or_none(row["base_experience"]),
                "gender_rate": int(species["gender_rate"]),
                "capture_rate": int(species["capture_rate"]),
                "growth_rate": source.growth_rates[species["growth_rate_id"]]["identifier"],
                "is_baby": species["is_baby"] == "1",
                "is_legendary": species["is_legendary"] == "1",
                "is_mythical": species["is_mythical"] == "1",
                "evolutions": evolutions(row, unit_names, source, dropped_evolutions),
                "transformations": sorted(transformations[row["identifier"]], key=lambda entry: entry["name"]),
                "learnset": learnset(row, source),
            }
        )
        units[row["identifier"]] = unit
    return units, sorted(left_out_transformations), sorted(dropped_evolutions)


def build_moves(source):
    moves = {}
    flavor_count = 0
    for move_id, row in source.moves.items():
        if int(move_id) >= FIRST_SHADOW_MOVE_ID:
            continue
        effect = source.move_effects.get(row["effect_id"])
        effect_source = "effect"
        if not effect:
            effect = source.newest_flavor_of_move.get(move_id, "")
            effect_source = "in-game description"
            flavor_count += 1
        meta_row = source.move_meta.get(move_id)
        battle_details = None
        if meta_row:
            battle_details = {
                "category": source.meta_categories[meta_row["meta_category_id"]]["identifier"],
                "ailment": source.meta_ailments[meta_row["meta_ailment_id"]]["identifier"],
                "ailment_chance": int(meta_row["ailment_chance"]),
                "minimum_hits": number_or_none(meta_row["min_hits"]),
                "maximum_hits": number_or_none(meta_row["max_hits"]),
                "minimum_turns": number_or_none(meta_row["min_turns"]),
                "maximum_turns": number_or_none(meta_row["max_turns"]),
                "drain_percent": int(meta_row["drain"]),
                "healing_percent": int(meta_row["healing"]),
                "critical_hit_stage": int(meta_row["crit_rate"]),
                "flinch_chance": int(meta_row["flinch_chance"]),
                "stat_chance": int(meta_row["stat_chance"]),
                "stat_changes": [
                    {"stat": STAT_KEYS.get(source.stats[change["stat_id"]]["identifier"], source.stats[change["stat_id"]]["identifier"]), "change": int(change["change"])}
                    for change in sorted(source.stat_changes_of[move_id], key=lambda change: int(change["stat_id"]))
                ],
            }
        moves[row["identifier"]] = {
            "pokeapi_id": int(move_id),
            "english_name": source.move_names[move_id],
            "generation": int(row["generation_id"]),
            "type": source.types[row["type_id"]]["identifier"],
            "damage_class": source.damage_classes[row["damage_class_id"]]["identifier"],
            "power": number_or_none(row["power"]),
            "accuracy": number_or_none(row["accuracy"]),
            "pp": number_or_none(row["pp"]),
            "priority": int(row["priority"]),
            "target": source.move_targets[row["target_id"]]["identifier"],
            "effect_chance": number_or_none(row["effect_chance"]),
            "effect": effect,
            "effect_source": effect_source,
            "battle_details": battle_details,
        }
    return moves, flavor_count


def build_abilities(source):
    return {
        row["identifier"]: {
            "pokeapi_id": int(ability_id),
            "english_name": source.ability_names[ability_id],
            "generation": int(row["generation_id"]),
            "effect": source.ability_effects.get(ability_id, ""),
        }
        for ability_id, row in source.abilities.items()
        if row["is_main_series"] == "1"
    }


def build_types(source):
    attack_types = {type_id: row for type_id, row in source.types.items() if int(type_id) <= ATTACK_TYPE_COUNT}
    chart = defaultdict(dict)
    for row in source.type_efficacy:
        if row["damage_type_id"] in attack_types and row["target_type_id"] in attack_types:
            factor = int(row["damage_factor"]) / 100
            chart[row["damage_type_id"]][attack_types[row["target_type_id"]]["identifier"]] = int(factor) if factor.is_integer() else factor
    return {
        row["identifier"]: {
            "pokeapi_id": int(type_id),
            "english_name": source.type_names[type_id],
            "against": chart[type_id],
        }
        for type_id, row in attack_types.items()
    }


def is_scalar(value):
    return not isinstance(value, (dict, list))


def to_json(value, indent=0):
    """JSON with sorted keys; a list or object holding only scalars goes on one line."""
    pad = "  " * indent
    inner = "  " * (indent + 1)
    if isinstance(value, dict):
        if not value:
            return "{}"
        if all(is_scalar(item) for item in value.values()):
            return json.dumps(value, sort_keys=True, ensure_ascii=False, separators=(", ", ": "))
        parts = [f"{inner}{json.dumps(key, ensure_ascii=False)}: {to_json(value[key], indent + 1)}" for key in sorted(value)]
        return "{\n" + ",\n".join(parts) + "\n" + pad + "}"
    if isinstance(value, list):
        if not value:
            return "[]"
        if all(is_scalar(item) for item in value):
            return json.dumps(value, ensure_ascii=False, separators=(", ", ": "))
        parts = [f"{inner}{to_json(item, indent + 1)}" for item in value]
        return "[\n" + ",\n".join(parts) + "\n" + pad + "]"
    return json.dumps(value, ensure_ascii=False)


def pinned_commit():
    match = re.search(r"\| Commit \| ([0-9a-f]{40}) \|", PIN_NOTE.read_text(encoding="utf-8"))
    return match.group(1) if match else "unknown"


def readme(units, moves, abilities, types, left_out, dropped, flavor_count):
    regional = defaultdict(int)
    games = defaultdict(int)
    transformation_kinds = defaultdict(int)
    for unit in units.values():
        if unit["regional_form"]:
            regional[unit["regional_form"]] += 1
        games[unit["learnset"]["game"]] += 1
        for transformation in unit["transformations"]:
            transformation_kinds[transformation["kind"]] += 1
    entry_count = sum(len(unit["learnset"]["moves"]) for unit in units.values())
    lines = [
        "# data (the game's data pack, generated: do not edit by hand)",
        "",
        "Built by `python tools/export_pack.py` from source/pokeapi/csv at pokeapi commit",
        f"{pinned_commit()}. Plan: docs/discussion-outputs/data-pack-plan.md.",
        "Check that it is current: `python tools/export_pack.py --check` (also run by tools\\run-tests.cmd).",
        "",
        "## Counts",
        "",
        "| File | Entries |",
        "|---|---|",
        f"| units.json | {len(units)} ({sum(1 for u in units.values() if u['is_species_default'])} species defaults, "
        + ", ".join(f"{region} {regional[region]}" for region in REGIONS)
        + ") |",
        f"| moves.json | {len(moves)} (Shadow moves left out) |",
        f"| abilities.json | {len(abilities)} (main series) |",
        f"| types.json | {len(types)} |",
        "",
        "| Learnset game | Units |",
        "|---|---|",
        *[f"| {game} | {games[game]} |" for game in sorted(games, key=lambda game: -games[game])],
        "",
        f"Learnset entries: {entry_count}. Transformations: "
        + ", ".join(f"{kind} {transformation_kinds[kind]}" for kind in sorted(transformation_kinds))
        + ".",
        f"Moves whose effect is pokeapi's newest English in-game description (no effect text upstream): {flavor_count}.",
        "",
        "## Units of measure",
        "",
        "- height_decimetres, weight_hectograms: as pokeapi stores them.",
        "- gender_rate: chance of female in eighths; -1 means genderless.",
        "- types.json `against`: damage multiplier of the attacking type (the entry) on each defending type.",
        "- A learnset entry's level is present only for level-up moves; 0 means learned on evolution.",
        "",
        "## Units and transformations without a sprite set",
        "",
        "Matched by SpriteCollab form name (source/spritecollab/tracker.json); none upstream, or a form not fetched.",
        "The fallback is an open decision (STATE.md).",
        "",
        *[f"- {name}" for name in sorted(
            [name for name, unit in units.items() if unit["sprite_set"] is None]
            + [t["name"] for unit in units.values() for t in unit["transformations"] if t["sprite_set"] is None]
        )],
        "",
        "## Left out on purpose",
        "",
        "Transformations whose base form is an excluded variant (data-pack-plan.md decision 2):",
        "",
        *[f"- {name} (base {base})" for name, base in left_out],
        "",
        "Evolutions whose target is an excluded variant (2026-11-15-variant-scope):",
        "",
        *[f"- {source} into {target}" for source, target in dropped],
        "",
    ]
    return "\n".join(lines)


def write_pack(folder):
    source = Source()
    units, left_out, dropped = build_units(source, SpriteSets())
    moves, flavor_count = build_moves(source)
    abilities = build_abilities(source)
    types = build_types(source)
    folder.mkdir(parents=True, exist_ok=True)
    contents = {
        "units.json": to_json(units) + "\n",
        "moves.json": to_json(moves) + "\n",
        "abilities.json": to_json(abilities) + "\n",
        "types.json": to_json(types) + "\n",
        "README.md": readme(units, moves, abilities, types, left_out, dropped, flavor_count),
    }
    for name, text in contents.items():
        with open(folder / name, "w", encoding="utf-8", newline="\n") as handle:
            handle.write(text)
    return units, moves, abilities, types


def check():
    with tempfile.TemporaryDirectory() as temporary:
        rebuilt = Path(temporary)
        write_pack(rebuilt)
        different = [
            name
            for name in PACK_FILES
            if not (PACK_FOLDER / name).exists() or not filecmp.cmp(rebuilt / name, PACK_FOLDER / name, shallow=False)
        ]
    if different:
        print("data pack is not current, rerun python tools/export_pack.py. Different: " + ", ".join(different))
        return 1
    print("data pack is current (rebuild matches data/ byte for byte)")
    return 0


def main():
    if "--check" in sys.argv[1:]:
        return check()
    units, moves, abilities, types = write_pack(PACK_FOLDER)
    print(f"wrote data/: {len(units)} units, {len(moves)} moves, {len(abilities)} abilities, {len(types)} types")
    return 0


if __name__ == "__main__":
    sys.exit(main())
