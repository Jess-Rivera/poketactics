#!/usr/bin/env python3
"""Build the offline wiki (wiki/) from the data pack (data/*.json): static HTML that opens from disk.

One page per unit, move, ability and type, cross-linked, plus an index with search, tabs and a sortable unit table.
Mega, Gigantamax and Primal forms show on their base unit's page, as in the pack. No network resources.
Ruling: docs/decisions/2026-11-15-offline-wiki.md. Issue #4.

Python 3 standard library only. Usage (repo root): python tools/build_wiki.py
"""

import html
import json
import shutil
from collections import defaultdict
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
PACK_FOLDER = REPO_ROOT / "data"
WIKI_FOLDER = REPO_ROOT / "wiki"
STAT_ORDER = [
    ("hp", "HP"),
    ("attack", "Atk"),
    ("defense", "Def"),
    ("special_attack", "SpA"),
    ("special_defense", "SpD"),
    ("speed", "Spe"),
]
METHOD_ORDER = ["level-up", "machine", "tutor", "egg"]
METHOD_TITLES = {"level-up": "Level-up", "machine": "TM (machine)", "tutor": "Tutor", "egg": "Egg move"}
KIND_TITLES = {"mega": "Mega", "gigantamax": "Gigantamax", "primal": "Primal"}
FLAG_WORDS = {
    "needs_overworld_rain": "while it rains",
    "turn_upside_down": "with the console held upside down",
    "needs_multiplayer": "in a multiplayer session",
    "near_special_rock": "near a special rock",
}
PHYSICAL_STAT_WORDS = {1: "with Attack higher than Defense", -1: "with Attack lower than Defense", 0: "with Attack equal to Defense"}


def escape(text):
    return html.escape(str(text), quote=True)


def words(identifier):
    """ice-stone -> Ice Stone, for item, location and trigger names that have no English name in the pack."""
    return " ".join(part.capitalize() for part in str(identifier).replace("_", "-").split("-"))


def with_article(noun):
    return ("an " if noun[:1].lower() in "aeiou" else "a ") + noun


def read_pack(name):
    return json.loads((PACK_FOLDER / name).read_text(encoding="utf-8"))


class Wiki:
    def __init__(self):
        self.units = read_pack("units.json")
        self.moves = read_pack("moves.json")
        self.abilities = read_pack("abilities.json")
        self.types = read_pack("types.json")
        self.learners_of_move = defaultdict(list)
        self.holders_of_ability = defaultdict(list)
        self.units_of_type = defaultdict(list)
        self.evolves_from = defaultdict(list)
        for unit_name, unit in self.units.items():
            for entry in unit["learnset"]["moves"]:
                self.learners_of_move[entry["move"]].append((unit_name, entry))
            for ability_entry in unit["abilities"]:
                self.holders_of_ability[ability_entry["ability"]].append((unit_name, ability_entry["hidden"], None))
            for transformation in unit["transformations"]:
                for ability_entry in transformation["abilities"]:
                    self.holders_of_ability[ability_entry["ability"]].append(
                        (unit_name, ability_entry["hidden"], transformation["english_name"])
                    )
            for type_name in unit["types"]:
                self.units_of_type[type_name].append(unit_name)
            for evolution in unit["evolutions"]:
                if unit_name not in self.evolves_from[evolution["into"]]:
                    self.evolves_from[evolution["into"]].append(unit_name)

    # Links -------------------------------------------------------------------------------------------------------

    def unit_link(self, unit_name, prefix="../"):
        return f'<a href="{prefix}units/{escape(unit_name)}.html">{escape(self.units[unit_name]["english_name"])}</a>'

    def move_link(self, move_name, prefix="../"):
        if move_name not in self.moves:
            return escape(words(move_name))
        return f'<a href="{prefix}moves/{escape(move_name)}.html">{escape(self.moves[move_name]["english_name"])}</a>'

    def ability_link(self, ability_name, prefix="../"):
        return f'<a href="{prefix}abilities/{escape(ability_name)}.html">{escape(self.abilities[ability_name]["english_name"])}</a>'

    def type_badge(self, type_name, prefix="../"):
        return (
            f'<a class="type type-{escape(type_name)}" href="{prefix}types/{escape(type_name)}.html">'
            f'{escape(self.types[type_name]["english_name"])}</a>'
        )

    def type_badges(self, type_names):
        return " ".join(self.type_badge(type_name) for type_name in type_names)

    # Shared pieces -----------------------------------------------------------------------------------------------

    def page(self, title, body, prefix="../"):
        return (
            "<!doctype html>\n<html lang=\"en\">\n<head>\n<meta charset=\"utf-8\">\n"
            '<meta name="viewport" content="width=device-width, initial-scale=1">\n'
            f"<title>{escape(title)} | PokeTactics wiki</title>\n"
            f'<link rel="stylesheet" href="{prefix}style.css">\n</head>\n<body>\n'
            f'<header><a class="home" href="{prefix}index.html">PokeTactics wiki</a></header>\n'
            f"<main>\n{body}\n</main>\n</body>\n</html>\n"
        )

    def stats_table(self, stats):
        rows = "".join(
            f'<tr><th>{label}</th><td class="number">{stats[key]}</td>'
            f'<td class="bar-cell"><span class="bar" style="width:{min(100, round(stats[key] / 2.55))}%"></span></td></tr>'
            for key, label in STAT_ORDER
        )
        total = sum(stats[key] for key, _ in STAT_ORDER)
        return f'<table class="stats">{rows}<tr class="total"><th>Total</th><td class="number">{total}</td><td></td></tr></table>'

    def abilities_list(self, ability_entries):
        items = []
        for entry in ability_entries:
            hidden = ' <span class="tag">hidden</span>' if entry["hidden"] else ""
            effect = escape(self.abilities[entry["ability"]]["effect"])
            items.append(f"<li>{self.ability_link(entry['ability'])}{hidden}<div class=\"note\">{effect}</div></li>")
        return "<ul class=\"plain\">" + "".join(items) + "</ul>"

    def defensive_multipliers(self, unit_types):
        groups = defaultdict(list)
        for attacking_name, attacking in self.types.items():
            multiplier = 1
            for defending_name in unit_types:
                multiplier *= attacking["against"][defending_name]
            groups[multiplier].append(attacking_name)
        rows = []
        for multiplier in sorted(groups, reverse=True):
            if multiplier == 1:
                continue
            label = {0: "Immune (0x)", 0.25: "0.25x", 0.5: "0.5x", 2: "2x", 4: "4x"}.get(multiplier, f"{multiplier}x")
            rows.append(f"<tr><th>{label}</th><td>{self.type_badges(sorted(groups[multiplier]))}</td></tr>")
        return '<table class="multipliers">' + "".join(rows) + "</table>" if rows else "<p>No weaknesses or resistances.</p>"

    def condition_text(self, evolution):
        """An evolution's trigger and conditions in plain words."""
        trigger = evolution["trigger"]
        conditions = evolution["conditions"]
        parts = []
        if trigger == "use-item" and "item" in conditions:
            parts.append(f"Use {with_article(escape(words(conditions['item'])))}")
        elif trigger == "level-up":
            parts.append(f"Level up to {conditions['minimum_level']}" if "minimum_level" in conditions else "Level up")
        elif trigger == "trade":
            parts.append("Trade")
        else:
            parts.append(escape(words(trigger)))
        for key, value in conditions.items():
            if key == "item" and trigger == "use-item":
                continue
            if key == "minimum_level" and trigger == "level-up":
                continue
            parts.append(self.condition_phrase(key, value, conditions))
        return ", ".join(part for part in parts if part)

    def condition_phrase(self, key, value, conditions):
        if key == "minimum_level":
            return f"at level {value} or higher"
        if key == "item":
            return f"with {with_article(escape(words(value)))}"
        if key == "held_item":
            return f"holding {with_article(escape(words(value)))}"
        if key == "time_of_day":
            return f"during the {escape(value)}"
        if key == "minimum_happiness":
            return f"with happiness {value} or more"
        if key == "minimum_beauty":
            return f"with beauty {value} or more"
        if key == "minimum_affection":
            return f"with affection {value} or more"
        if key == "known_move":
            return f"knowing {self.move_link(value)}"
        if key == "known_move_type":
            return f"knowing a {self.type_badge(value)} move"
        if key == "location":
            return f"at {escape(words(value))}"
        if key == "gender":
            return f"if {escape(value)}"
        if key == "region":
            return f"in {escape(words(value))}"
        if key == "party_species":
            return f"with {escape(words(value))} in the party"
        if key == "party_type":
            return f"with a {self.type_badge(value)} Pokemon in the party"
        if key == "trade_species":
            return f"for {with_article(escape(words(value)))}"
        if key == "relative_physical_stats":
            return PHYSICAL_STAT_WORDS.get(value, "")
        if key == "used_move":
            count = conditions.get("minimum_move_count")
            return f"after using {self.move_link(value)}" + (f" {count} times" if count else "")
        if key == "minimum_move_count":
            return ""
        if key == "minimum_steps":
            return f"after {value} steps"
        if key == "minimum_damage_taken":
            return f"after taking {value} damage"
        if key == "nature_bitmask":
            return "with certain natures"
        if key == "percentage_chance":
            return f"{value}% chance"
        if key == "condition_expression":
            return f'<span class="note">(condition: {escape(value)})</span>'
        if key in FLAG_WORDS:
            return FLAG_WORDS[key]
        if value is True:
            return escape(words(key)).lower()
        return f"{escape(words(key))} {escape(value)}"

    # Pages -------------------------------------------------------------------------------------------------------

    def unit_page(self, unit_name):
        unit = self.units[unit_name]
        learnset = unit["learnset"]
        sections = [
            f"<h1>{escape(unit['english_name'])} <span class=\"dex\">#{unit['dex_number']:04d}</span></h1>",
            f"<p>{self.type_badges(unit['types'])}</p>",
            f'<p class="note">{escape(unit_name)}, generation {unit["generation"]}'
            + (f", {escape(words(unit['regional_form']))} form" if unit["regional_form"] else "")
            + ("" if not (unit["is_legendary"] or unit["is_mythical"]) else (", legendary" if unit["is_legendary"] else ", mythical"))
            + "</p>",
            '<div class="columns"><section><h2>Base stats</h2>' + self.stats_table(unit["base_stats"]) + "</section>",
            "<section><h2>Abilities</h2>" + self.abilities_list(unit["abilities"]) + "</section></div>",
            "<h2>Type matchups (defending)</h2>" + self.defensive_multipliers(unit["types"]),
        ]
        evolution_lines = []
        for source in self.evolves_from.get(unit_name, []):
            evolution_lines.append(f"<li>Evolves from {self.unit_link(source)}</li>")
        for evolution in sorted(unit["evolutions"], key=lambda entry: self.units[entry["into"]]["english_name"]):
            evolution_lines.append(f"<li>Evolves into {self.unit_link(evolution['into'])}: {self.condition_text(evolution)}</li>")
        if evolution_lines:
            sections.append("<h2>Evolution</h2><ul>" + "".join(evolution_lines) + "</ul>")
        for transformation in unit["transformations"]:
            sections.append(
                f"<h2>{KIND_TITLES[transformation['kind']]}: {escape(transformation['english_name'])}</h2>"
                f"<p>{self.type_badges(transformation['types'])}</p>"
                '<div class="columns"><section>' + self.stats_table(transformation["base_stats"]) + "</section>"
                "<section>" + self.abilities_list(transformation["abilities"]) + "</section></div>"
            )
        sections.append(f"<h2>Learnset</h2><p class=\"note\">From {escape(words(learnset['game']))}.</p>")
        by_method = defaultdict(list)
        for entry in learnset["moves"]:
            by_method[entry["method"]].append(entry)
        for method in METHOD_ORDER:
            entries = by_method.get(method)
            if not entries:
                continue
            if method == "level-up":
                entries = sorted(entries, key=lambda entry: (entry["level"], self.moves[entry["move"]]["english_name"]))
            else:
                entries = sorted(entries, key=lambda entry: self.moves[entry["move"]]["english_name"])
            rows = "".join(self.learnset_row(entry, method) for entry in entries)
            level_header = "<th>Level</th>" if method == "level-up" else ""
            sections.append(
                f"<h3>{METHOD_TITLES[method]} ({len(entries)})</h3>"
                f'<table class="list">{"<tr>" + level_header + "<th>Move</th><th>Type</th><th>Class</th><th>Power</th><th>Acc</th><th>PP</th></tr>"}{rows}</table>'
            )
        return self.page(unit["english_name"], "\n".join(sections))

    def learnset_row(self, entry, method):
        move = self.moves[entry["move"]]
        level = ""
        if method == "level-up":
            level = f'<td class="number">{"Evolve" if entry["level"] == 0 else entry["level"]}</td>'
        return (
            f"<tr>{level}<td>{self.move_link(entry['move'])}</td><td>{self.type_badge(move['type'])}</td>"
            f"<td>{escape(move['damage_class'])}</td><td class=\"number\">{dash(move['power'])}</td>"
            f"<td class=\"number\">{dash(move['accuracy'])}</td><td class=\"number\">{dash(move['pp'])}</td></tr>"
        )

    def move_page(self, move_name):
        move = self.moves[move_name]
        facts = [
            ("Type", self.type_badge(move["type"])),
            ("Class", escape(move["damage_class"])),
            ("Power", dash(move["power"])),
            ("Accuracy", dash(move["accuracy"])),
            ("PP", dash(move["pp"])),
            ("Priority", move["priority"]),
            ("Target", escape(words(move["target"]))),
            ("Contact", "yes" if move["contact"] else "no"),
            ("Effect chance", f"{move['effect_chance']}%" if move["effect_chance"] is not None else "-"),
            ("Generation", move["generation"]),
        ]
        source_note = ' <span class="tag">in-game description</span>' if move["effect_source"] != "effect" else ""
        sections = [
            f"<h1>{escape(move['english_name'])}</h1>",
            f"<p>{escape(move['effect'])}{source_note}</p>",
            '<table class="facts">' + "".join(f"<tr><th>{label}</th><td>{value}</td></tr>" for label, value in facts) + "</table>",
        ]
        details = move["battle_details"]
        if details:
            detail_rows = [("Category", escape(words(details["category"])))]
            if details["ailment"] != "none":
                detail_rows.append(("Ailment", f"{escape(words(details['ailment']))} ({details['ailment_chance']}%)" if details["ailment_chance"] else escape(words(details["ailment"]))))
            if details["minimum_hits"] is not None:
                detail_rows.append(("Hits", f"{details['minimum_hits']} to {details['maximum_hits']}"))
            if details["minimum_turns"] is not None:
                detail_rows.append(("Turns", f"{details['minimum_turns']} to {details['maximum_turns']}"))
            if details["drain_percent"]:
                detail_rows.append(("Drain or recoil", f"{details['drain_percent']}%"))
            if details["healing_percent"]:
                detail_rows.append(("Healing", f"{details['healing_percent']}%"))
            if details["critical_hit_stage"]:
                detail_rows.append(("Critical hit stage", f"+{details['critical_hit_stage']}"))
            if details["flinch_chance"]:
                detail_rows.append(("Flinch chance", f"{details['flinch_chance']}%"))
            if details["stat_changes"]:
                changes = ", ".join(f"{escape(words(change['stat']))} {change['change']:+d}" for change in details["stat_changes"])
                chance = f" ({details['stat_chance']}%)" if details["stat_chance"] else ""
                detail_rows.append(("Stat changes", changes + chance))
            sections.append("<h2>Battle details</h2><table class=\"facts\">" + "".join(f"<tr><th>{label}</th><td>{value}</td></tr>" for label, value in detail_rows) + "</table>")
        recipe = move["recipe"]
        if recipe:
            shape = recipe["shape"]
            if shape["kind"] == "square":
                size = f"square {shape['length']} by {shape['width']}"
            elif shape["angle"] < 360:
                size = f"cone, radius {shape['radius']}, {shape['angle']} degrees"
            else:
                size = f"circle, radius {shape['radius']}"
            on_user_tile = shape["range_max"] == 0
            reach = "the user's tile" if on_user_tile else f"{shape['range_min']} to {shape['range_max']} tiles"
            close_range = any(modifier["modifier"] == "close_range" for modifier in recipe["modifiers"])
            components = ", ".join(
                escape(words(component["effect"])) + (f" ({component['chance']}%)" if "chance" in component else "")
                for component in recipe["components"]
            ) or "-"
            recipe_rows = [
                ("Shape", escape(size) + f", {escape(shape['anchor'])}"),
                ("Reach", escape(reach) + (" (half damage at 1)" if close_range else "")),
                ("Strike rank cost", f"{recipe['sr_cost']} SR"),
                ("Tags", escape(", ".join(words(tag) for tag in recipe["tags"])) or "-"),
                ("Components", components),
            ]
            sections.append("<h2>On the grid</h2><table class=\"facts\">" + "".join(f"<tr><th>{label}</th><td>{value}</td></tr>" for label, value in recipe_rows) + "</table>")
        learners = self.learners_of_move.get(move_name, [])
        sections.append(f"<h2>Learned by ({len({name for name, _ in learners})} units)</h2>")
        by_method = defaultdict(list)
        for unit_name, entry in learners:
            by_method[entry["method"]].append((unit_name, entry))
        for method in METHOD_ORDER:
            entries = by_method.get(method)
            if not entries:
                continue
            entries = sorted(entries, key=lambda item: (self.units[item[0]]["dex_number"], item[0], item[1].get("level", 0)))
            items = []
            for unit_name, entry in entries:
                level = ""
                if method == "level-up":
                    level = " (evolve)" if entry["level"] == 0 else f" (level {entry['level']})"
                items.append(f"<li>{self.unit_link(unit_name)}{level}</li>")
            sections.append(f"<h3>{METHOD_TITLES[method]} ({len(entries)})</h3><ul class=\"grid\">{''.join(items)}</ul>")
        if not learners:
            sections.append("<p>No unit learns this move in its learnset game.</p>")
        return self.page(move["english_name"], "\n".join(sections))

    def ability_page(self, ability_name):
        ability = self.abilities[ability_name]
        holders = sorted(self.holders_of_ability.get(ability_name, []), key=lambda item: (self.units[item[0]]["dex_number"], item[0], item[2] or ""))
        items = []
        for unit_name, hidden, transformation_name in holders:
            label = self.unit_link(unit_name)
            if transformation_name:
                label += f" <span class=\"note\">as {escape(transformation_name)}</span>"
            if hidden:
                label += ' <span class="tag">hidden</span>'
            items.append(f"<li>{label}</li>")
        body = (
            f"<h1>{escape(ability['english_name'])}</h1><p>{escape(ability['effect'])}</p>"
            f"<p class=\"note\">Generation {ability['generation']}</p>"
            f"<h2>Units ({len(holders)})</h2>"
            + (f"<ul class=\"grid\">{''.join(items)}</ul>" if items else "<p>No unit has this ability.</p>")
        )
        return self.page(ability["english_name"], body)

    def type_page(self, type_name):
        type_entry = self.types[type_name]
        attack_rows = defaultdict(list)
        for defending_name, multiplier in type_entry["against"].items():
            attack_rows[multiplier].append(defending_name)
        defend_rows = defaultdict(list)
        for attacking_name, attacking in self.types.items():
            defend_rows[attacking["against"][type_name]].append(attacking_name)

        def chart(groups):
            return '<table class="multipliers">' + "".join(
                f"<tr><th>{multiplier}x</th><td>{self.type_badges(sorted(groups[multiplier]))}</td></tr>"
                for multiplier in sorted(groups, reverse=True)
            ) + "</table>"

        units = sorted(self.units_of_type.get(type_name, []), key=lambda name: (self.units[name]["dex_number"], name))
        moves = sorted((name for name, move in self.moves.items() if move["type"] == type_name), key=lambda name: self.moves[name]["english_name"])
        body = (
            f"<h1>{self.type_badge(type_name)}</h1>"
            f"<div class=\"columns\"><section><h2>Attacking</h2>{chart(attack_rows)}</section>"
            f"<section><h2>Defending</h2>{chart(defend_rows)}</section></div>"
            f"<h2>Units ({len(units)})</h2><ul class=\"grid\">{''.join(f'<li>{self.unit_link(name)}</li>' for name in units)}</ul>"
            f"<h2>Moves ({len(moves)})</h2><ul class=\"grid\">{''.join(f'<li>{self.move_link(name)}</li>' for name in moves)}</ul>"
        )
        return self.page(type_entry["english_name"], body)

    def index_page(self):
        unit_rows = []
        for unit_name in sorted(self.units, key=lambda name: (self.units[name]["dex_number"], name)):
            unit = self.units[unit_name]
            stats = unit["base_stats"]
            total = sum(stats[key] for key, _ in STAT_ORDER)
            cells = "".join(f'<td class="number">{stats[key]}</td>' for key, _ in STAT_ORDER)
            unit_rows.append(
                f'<tr><td class="number">{unit["dex_number"]}</td><td>{self.unit_link(unit_name, "")}</td>'
                f"<td>{' '.join(self.type_badge(name, '') for name in unit['types'])}</td>{cells}<td class=\"number\">{total}</td></tr>"
            )
        unit_header = "".join(f'<th data-sort="number">{label}</th>' for _, label in STAT_ORDER)
        move_rows = []
        for move_name in sorted(self.moves, key=lambda name: self.moves[name]["english_name"]):
            move = self.moves[move_name]
            move_rows.append(
                f"<tr><td>{self.move_link(move_name, '')}</td><td>{self.type_badge(move['type'], '')}</td>"
                f"<td>{escape(move['damage_class'])}</td><td class=\"number\">{dash(move['power'])}</td>"
                f"<td class=\"number\">{dash(move['accuracy'])}</td><td class=\"number\">{dash(move['pp'])}</td></tr>"
            )
        ability_rows = [
            f"<tr><td>{self.ability_link(name, '')}</td><td>{escape(self.abilities[name]['effect'])}</td></tr>"
            for name in sorted(self.abilities, key=lambda name: self.abilities[name]["english_name"])
        ]
        type_items = " ".join(self.type_badge(name, "") for name in sorted(self.types, key=lambda name: self.types[name]["pokeapi_id"]))
        body = f"""<h1>PokeTactics wiki</h1>
<p class="note">Built from the data pack (data/) by tools/build_wiki.py: {len(self.units)} units, {len(self.moves)} moves, {len(self.abilities)} abilities, {len(self.types)} types.</p>
<input id="search" type="search" placeholder="Search units, moves, abilities, types" autocomplete="off" autofocus>
<ul id="results" class="plain"></ul>
<nav class="tabs"><button data-tab="units" class="active">Units</button><button data-tab="moves">Moves</button><button data-tab="abilities">Abilities</button><button data-tab="types">Types</button></nav>
<section id="tab-units" class="tab"><p class="note">Click a column header to sort.</p>
<table class="list sortable"><thead><tr><th data-sort="number">#</th><th data-sort="text">Name</th><th>Types</th>{unit_header}<th data-sort="number">Total</th></tr></thead><tbody>{''.join(unit_rows)}</tbody></table></section>
<section id="tab-moves" class="tab" hidden><table class="list sortable"><thead><tr><th data-sort="text">Move</th><th data-sort="text">Type</th><th data-sort="text">Class</th><th data-sort="number">Power</th><th data-sort="number">Acc</th><th data-sort="number">PP</th></tr></thead><tbody>{''.join(move_rows)}</tbody></table></section>
<section id="tab-abilities" class="tab" hidden><table class="list"><thead><tr><th>Ability</th><th>Effect</th></tr></thead><tbody>{''.join(ability_rows)}</tbody></table></section>
<section id="tab-types" class="tab" hidden><p>{type_items}</p></section>
<script src="search-index.js"></script>
<script src="app.js"></script>"""
        return self.page("Home", body, prefix="")

    def search_index(self):
        entries = []
        for kind, table, folder in (("unit", self.units, "units"), ("move", self.moves, "moves"), ("ability", self.abilities, "abilities"), ("type", self.types, "types")):
            for name in sorted(table):
                entries.append([table[name]["english_name"], kind, f"{folder}/{name}.html"])
        return "window.WIKI_SEARCH = " + json.dumps(entries, ensure_ascii=False, separators=(",", ":")) + ";\n"


def dash(value):
    return "-" if value is None else escape(value)


STYLE = """:root { --bg: #fafafa; --fg: #1d1d1f; --muted: #6b6b70; --line: #dcdce0; --panel: #ffffff; --link: #1a5fb4; --bar: #3a86ff; }
@media (prefers-color-scheme: dark) { :root { --bg: #17171a; --fg: #e8e8ea; --muted: #9a9aa0; --line: #33333a; --panel: #1f1f23; --link: #78aeff; --bar: #5b9bff; } }
* { box-sizing: border-box; }
body { margin: 0; background: var(--bg); color: var(--fg); font: 15px/1.45 system-ui, -apple-system, "Segoe UI", sans-serif; }
header { padding: 10px 16px; border-bottom: 1px solid var(--line); background: var(--panel); }
header .home { font-weight: 600; text-decoration: none; }
main { max-width: 1100px; margin: 0 auto; padding: 16px; }
a { color: var(--link); }
h1 { margin: 8px 0; } h2 { margin-top: 28px; border-bottom: 1px solid var(--line); padding-bottom: 4px; } h3 { margin-top: 18px; }
.dex, .note { color: var(--muted); font-weight: normal; } .note { font-size: 13px; }
.tag { font-size: 11px; padding: 1px 6px; border-radius: 8px; border: 1px solid var(--line); color: var(--muted); }
.columns { display: flex; flex-wrap: wrap; gap: 24px; } .columns > section { flex: 1 1 320px; }
table { border-collapse: collapse; } th, td { padding: 4px 8px; text-align: left; vertical-align: top; }
table.list { width: 100%; } table.list tr:nth-child(even) { background: var(--panel); } table.list th { border-bottom: 1px solid var(--line); }
.number { text-align: right; font-variant-numeric: tabular-nums; }
table.stats { width: 100%; } .bar-cell { width: 60%; } .bar { display: inline-block; height: 10px; border-radius: 5px; background: var(--bar); }
table.stats .total th, table.stats .total td { border-top: 1px solid var(--line); font-weight: 600; }
table.facts th { color: var(--muted); font-weight: normal; padding-right: 16px; }
ul.plain { list-style: none; padding: 0; } ul.plain li { margin-bottom: 8px; }
ul.grid { list-style: none; padding: 0; display: grid; grid-template-columns: repeat(auto-fill, minmax(190px, 1fr)); gap: 2px 12px; }
.type { display: inline-block; min-width: 64px; text-align: center; padding: 1px 8px; border-radius: 4px; color: #fff; font-size: 12px; font-weight: 600; text-decoration: none; text-shadow: 0 1px 1px rgba(0,0,0,.35); }
.type-normal { background: #9fa19f; } .type-fighting { background: #ff8000; } .type-flying { background: #81b9ef; } .type-poison { background: #9141cb; }
.type-ground { background: #915121; } .type-rock { background: #afa981; } .type-bug { background: #91a119; } .type-ghost { background: #704170; }
.type-steel { background: #60a1b8; } .type-fire { background: #e62829; } .type-water { background: #2980ef; } .type-grass { background: #3fa129; }
.type-electric { background: #d8b100; } .type-psychic { background: #ef4179; } .type-ice { background: #3dcef3; } .type-dragon { background: #5060e1; }
.type-dark { background: #624d4e; } .type-fairy { background: #ef70ef; }
#search { width: 100%; padding: 10px 12px; font-size: 16px; border: 1px solid var(--line); border-radius: 8px; background: var(--panel); color: var(--fg); }
#results li { margin: 4px 0; } #results .kind { color: var(--muted); font-size: 12px; margin-left: 6px; }
.tabs { margin: 16px 0 8px; display: flex; gap: 4px; flex-wrap: wrap; }
.tabs button { padding: 6px 14px; border: 1px solid var(--line); background: var(--panel); color: var(--fg); border-radius: 6px; cursor: pointer; font: inherit; }
.tabs button.active { border-color: var(--link); color: var(--link); }
.sortable th[data-sort] { cursor: pointer; user-select: none; } .sortable th[data-sort]:hover { color: var(--link); }
.sortable th.asc::after { content: " \\25B2"; } .sortable th.desc::after { content: " \\25BC"; }
.list-wrap { overflow-x: auto; }
@media (max-width: 640px) { table.list { font-size: 13px; } th, td { padding: 3px 4px; } }
"""

APP = """// Index page: search over every English name, tabs, and sortable tables. Runs from disk (no network).
(function () {
  var input = document.getElementById("search");
  var results = document.getElementById("results");
  var index = window.WIKI_SEARCH || [];
  var MAX_RESULTS = 40;
  input.addEventListener("input", function () {
    var query = input.value.trim().toLowerCase();
    results.innerHTML = "";
    if (!query) return;
    var starts = [], contains = [];
    for (var i = 0; i < index.length; i++) {
      var name = index[i][0].toLowerCase();
      if (name.indexOf(query) === 0) starts.push(index[i]);
      else if (name.indexOf(query) > 0) contains.push(index[i]);
    }
    starts.concat(contains).slice(0, MAX_RESULTS).forEach(function (entry) {
      var item = document.createElement("li");
      var link = document.createElement("a");
      link.href = entry[2];
      link.textContent = entry[0];
      var kind = document.createElement("span");
      kind.className = "kind";
      kind.textContent = entry[1];
      item.appendChild(link);
      item.appendChild(kind);
      results.appendChild(item);
    });
  });
  input.addEventListener("keydown", function (event) {
    if (event.key === "Enter") {
      var first = results.querySelector("a");
      if (first) window.location.href = first.href;
    }
  });

  var buttons = document.querySelectorAll(".tabs button");
  buttons.forEach(function (button) {
    button.addEventListener("click", function () {
      buttons.forEach(function (other) { other.classList.toggle("active", other === button); });
      document.querySelectorAll(".tab").forEach(function (tab) { tab.hidden = tab.id !== "tab-" + button.dataset.tab; });
    });
  });

  document.querySelectorAll("table.sortable").forEach(function (table) {
    var headers = table.querySelectorAll("th");
    headers.forEach(function (header, column) {
      if (!header.dataset.sort) return;
      header.addEventListener("click", function () {
        var numeric = header.dataset.sort === "number";
        var descending = header.classList.contains("asc") ? true : header.classList.contains("desc") ? false : numeric;
        headers.forEach(function (other) { other.classList.remove("asc", "desc"); });
        header.classList.add(descending ? "desc" : "asc");
        var body = table.tBodies[0];
        var rows = Array.prototype.slice.call(body.rows);
        rows.sort(function (rowA, rowB) {
          var a = rowA.cells[column].textContent.trim(), b = rowB.cells[column].textContent.trim();
          var order = numeric ? (parseFloat(a) || 0) - (parseFloat(b) || 0) : a.localeCompare(b);
          return descending ? -order : order;
        });
        rows.forEach(function (row) { body.appendChild(row); });
      });
    });
  });
})();
"""


def write(path, text):
    path.parent.mkdir(parents=True, exist_ok=True)
    with open(path, "w", encoding="utf-8", newline="\n") as handle:
        handle.write(text)


def main():
    wiki = Wiki()
    if WIKI_FOLDER.exists():
        shutil.rmtree(WIKI_FOLDER)
    write(WIKI_FOLDER / ".gdignore", "")
    write(WIKI_FOLDER / "style.css", STYLE)
    write(WIKI_FOLDER / "app.js", APP)
    write(WIKI_FOLDER / "search-index.js", wiki.search_index())
    write(WIKI_FOLDER / "index.html", wiki.index_page())
    for unit_name in wiki.units:
        write(WIKI_FOLDER / "units" / f"{unit_name}.html", wiki.unit_page(unit_name))
    for move_name in wiki.moves:
        write(WIKI_FOLDER / "moves" / f"{move_name}.html", wiki.move_page(move_name))
    for ability_name in wiki.abilities:
        write(WIKI_FOLDER / "abilities" / f"{ability_name}.html", wiki.ability_page(ability_name))
    for type_name in wiki.types:
        write(WIKI_FOLDER / "types" / f"{type_name}.html", wiki.type_page(type_name))
    page_count = len(wiki.units) + len(wiki.moves) + len(wiki.abilities) + len(wiki.types) + 1
    print(f"wrote wiki/: {page_count} pages. Open wiki/index.html in a browser.")


if __name__ == "__main__":
    main()
