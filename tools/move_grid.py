"""Move grid behaviour for the data pack (issue #9): derived defaults, hand-written overrides, the validator, and
the shape footprint table.

Rulings: 2026-11-16-move-shapes-and-range, 2026-11-16-move-schema-adaptation, 2026-11-16-act-cost,
2026-11-16-height-and-sight, 2026-11-16-environment-model. Plan: docs/discussion-outputs/move-schema-opening.md.

A move's grid entry holds:
  shape            single, line, cone or circle
  target           self, other or point (the allowed pairs are ALLOWED_PAIRS)
  radius           circle and cone: tiles whose centre lies within radius + 0.5 of the origin's centre
  spread_degrees   cone only: total angle, a multiple of SPREAD_STEP_DEGREES
  length           line only: tiles in the line
  range_min, range_max   grid steps (no diagonals) from the user to the chosen target; 0 and 0 for self
  close_penalty    damage is halved at range 1 (ranged damaging moves)
  sr_cost          strike rank cost of using the move (placeholder PP bands, a tuning item)
  tile_element     the element the move leaves on tiles it hits, or null
  arcing           ignores units (not walls) for line of sight
  payload          ordered effects; M1 runs damage, fixed_damage and user_faints
                   fixed_damage: damage set by FIXED_DAMAGE_AMOUNTS, not the formula (Night Shade: the user's level)
Only the moves named in authored/move_grid_overrides.json get an entry (Jess, #9: the 45 roster moves).
"""

import json
import math

ALLOWED_PAIRS = {
    "single": {"self", "other", "point"},
    "line": {"self", "point"},
    "cone": {"self"},
    "circle": {"self", "other", "point"},
}
SHAPE_FIELDS = {"single": set(), "line": {"length"}, "cone": {"radius", "spread_degrees"}, "circle": {"radius"}}
COMMON_FIELDS = {"shape", "target", "range_min", "range_max", "close_penalty", "sr_cost", "tile_element", "arcing", "payload"}
ALL_FIELDS = COMMON_FIELDS | {"length", "radius", "spread_degrees"}
EFFECTS = {
    "damage", "fixed_damage", "ailment", "stat", "drain", "recoil", "heal", "multi_hit", "flinch", "user_faints",
    "needs_rule",
}
FIXED_DAMAGE_AMOUNTS = {"user_level"}
EFFECT_SIDES = {"target", "user"}

RADIUS_LIMIT = 50
SPREAD_STEP_DEGREES = 15
FULL_TURN_DEGREES = 360
MELEE_RANGE = 1
RANGED_RANGE_MIN = 1
RANGED_RANGE_MAX = 4
DEFAULT_CONE_RADIUS = 3
DEFAULT_CONE_SPREAD = 60
DEFAULT_CIRCLE_RADIUS = 1
# Placeholder act cost bands (2026-11-16-act-cost, exact formula open): (lowest PP in the band, SR cost).
SR_COST_BANDS = [(35, 2), (25, 3), (15, 4), (10, 5), (0, 6)]
SR_COST_WITHOUT_PP = 4

# Which shape and target pokeapi's target picks by default.
SINGLE_OTHER_TARGETS = {
    "selected-pokemon", "selected-pokemon-me-first", "random-opponent", "specific-move", "ally", "user-or-ally",
    "fainting-pokemon",
}
SINGLE_SELF_TARGETS = {"user", "user-and-allies", "users-field", "entire-field"}
CONE_TARGETS = {"all-opponents"}
CIRCLE_SELF_TARGETS = {"all-other-pokemon", "all-pokemon", "all-allies"}
CIRCLE_POINT_TARGETS = {"opponents-field"}
# Meta categories whose stat change lands on the user rather than the target.
USER_STAT_CATEGORIES = {"damage-raise"}
# Meta categories that need a rule of their own before they do anything (M2b and later).
RULE_NEEDED_CATEGORIES = {"unique", "field-effect", "whole-field-effect", "swagger", "force-switch", "ohko"}


def sr_cost_for(pp):
    if pp is None:
        return SR_COST_WITHOUT_PP
    for lowest_pp, cost in SR_COST_BANDS:
        if pp >= lowest_pp:
            return cost
    return SR_COST_BANDS[-1][1]


def default_shape(move):
    target = move["target"]
    if target in SINGLE_SELF_TARGETS:
        return {"shape": "single", "target": "self"}
    if target in CONE_TARGETS:
        return {"shape": "cone", "target": "self", "radius": DEFAULT_CONE_RADIUS, "spread_degrees": DEFAULT_CONE_SPREAD}
    if target in CIRCLE_SELF_TARGETS:
        return {"shape": "circle", "target": "self", "radius": DEFAULT_CIRCLE_RADIUS}
    if target in CIRCLE_POINT_TARGETS:
        return {"shape": "circle", "target": "point", "radius": DEFAULT_CIRCLE_RADIUS}
    return {"shape": "single", "target": "other"}


def default_payload(move):
    details = move["battle_details"] or {}
    category = details.get("category", "")
    effects = []
    if move["damage_class"] != "status":
        effects.append({"effect": "damage"})
    if details.get("minimum_hits"):
        effects.append({"effect": "multi_hit", "minimum": details["minimum_hits"], "maximum": details["maximum_hits"]})
    if details.get("ailment", "none") != "none":
        chance = details.get("ailment_chance") or 100
        effects.append({"effect": "ailment", "ailment": details["ailment"], "chance": chance, "side": "target"})
    stat_side = "user" if move["target"] == "user" or category in USER_STAT_CATEGORIES else "target"
    for change in details.get("stat_changes", []):
        chance = details.get("stat_chance") or 100
        effects.append({"effect": "stat", "stat": change["stat"], "stages": change["change"], "chance": chance, "side": stat_side})
    drain = details.get("drain_percent", 0)
    if drain > 0:
        effects.append({"effect": "drain", "percent": drain})
    elif drain < 0:
        effects.append({"effect": "recoil", "percent": -drain})
    if details.get("healing_percent", 0) > 0:
        effects.append({"effect": "heal", "percent": details["healing_percent"], "side": "user"})
    if details.get("flinch_chance", 0) > 0:
        effects.append({"effect": "flinch", "chance": details["flinch_chance"]})
    if category in RULE_NEEDED_CATEGORIES:
        effects.append({"effect": "needs_rule", "kind": category})
    return effects


def default_entry(move):
    entry = default_shape(move)
    damaging = move["damage_class"] != "status"
    if entry["target"] == "self":
        entry["range_min"], entry["range_max"] = 0, 0
    elif move["contact"]:
        entry["range_min"], entry["range_max"] = MELEE_RANGE, MELEE_RANGE
    else:
        entry["range_min"], entry["range_max"] = RANGED_RANGE_MIN, RANGED_RANGE_MAX
    entry["close_penalty"] = damaging and not move["contact"] and entry["target"] != "self"
    entry["sr_cost"] = sr_cost_for(move["pp"])
    entry["tile_element"] = move["type"] if damaging else None
    entry["arcing"] = False
    entry["payload"] = default_payload(move)
    return entry


def validation_problems(move_name, entry):
    """Every reason an entry is invalid, as readable lines (empty when valid)."""
    problems = []
    shape, target = entry.get("shape"), entry.get("target")
    if shape not in ALLOWED_PAIRS:
        return [f"{move_name}: unknown shape {shape}"]
    if target not in ALLOWED_PAIRS[shape]:
        problems.append(f"{move_name}: {shape} cannot take target {target}")
    required = COMMON_FIELDS | SHAPE_FIELDS[shape]
    missing = required - entry.keys()
    extra = entry.keys() - required
    if missing:
        problems.append(f"{move_name}: missing {', '.join(sorted(missing))}")
    if extra:
        problems.append(f"{move_name}: {shape} has no field {', '.join(sorted(extra))}")
    for size_field in ("radius", "length"):
        if size_field in entry and not (isinstance(entry[size_field], int) and 1 <= entry[size_field] <= RADIUS_LIMIT):
            problems.append(f"{move_name}: {size_field} must be 1 to {RADIUS_LIMIT}")
    spread = entry.get("spread_degrees")
    if "spread_degrees" in entry and not (
        isinstance(spread, int) and SPREAD_STEP_DEGREES <= spread <= FULL_TURN_DEGREES and spread % SPREAD_STEP_DEGREES == 0
    ):
        problems.append(f"{move_name}: spread_degrees must be a multiple of {SPREAD_STEP_DEGREES} up to {FULL_TURN_DEGREES}")
    range_min, range_max = entry.get("range_min"), entry.get("range_max")
    if isinstance(range_min, int) and isinstance(range_max, int):
        if target == "self" and (range_min, range_max) != (0, 0):
            problems.append(f"{move_name}: a self move has range 0 to 0")
        if target != "self" and not 1 <= range_min <= range_max:
            problems.append(f"{move_name}: range must satisfy 1 <= range_min <= range_max")
    elif not missing:
        problems.append(f"{move_name}: range_min and range_max must be whole numbers")
    for effect in entry.get("payload", []):
        if effect.get("effect") not in EFFECTS:
            problems.append(f"{move_name}: unknown effect {effect.get('effect')}")
        if effect.get("effect") == "fixed_damage" and effect.get("amount") not in FIXED_DAMAGE_AMOUNTS:
            allowed = ", ".join(sorted(FIXED_DAMAGE_AMOUNTS))
            problems.append(f"{move_name}: fixed_damage amount must be one of {allowed}")
        if "side" in effect and effect["side"] not in EFFECT_SIDES:
            problems.append(f"{move_name}: unknown effect side {effect['side']}")
    return problems


def add_grid_entries(moves, overrides_path):
    """Gives each move named in the overrides file its grid entry (defaults, then the override), and every other
    move a null one. Stops the export with every problem listed if an override or entry is invalid."""
    overrides = json.loads(overrides_path.read_text(encoding="utf-8"))
    problems = []
    for move in moves.values():
        move["grid"] = None
    for move_name in sorted(overrides):
        override = overrides[move_name]
        if move_name not in moves:
            problems.append(f"override names unknown move {move_name}")
            continue
        unknown_fields = override.keys() - ALL_FIELDS
        if unknown_fields:
            problems.append(f"{move_name}: override has unknown field {', '.join(sorted(unknown_fields))}")
            continue
        entry = default_entry(moves[move_name])
        entry.update(override)
        # An override that changes the shape drops the default's size fields the new shape does not use.
        if entry["shape"] in SHAPE_FIELDS:
            for field in ALL_FIELDS - COMMON_FIELDS - SHAPE_FIELDS[entry["shape"]] - override.keys():
                entry.pop(field, None)
        problems.extend(validation_problems(move_name, entry))
        moves[move_name]["grid"] = entry
    if problems:
        raise SystemExit("move grid entries are invalid:\n  " + "\n  ".join(problems))
    return len(overrides)


def smallest_radius(x, y):
    """The smallest radius whose circle covers tile (x, y): centre within radius + 0.5, so 4(x^2 + y^2) <= (2r + 1)^2."""
    radius = 1
    while 4 * (x * x + y * y) > (2 * radius + 1) ** 2:
        radius += 1
    return radius


def smallest_spread_steps(x, y):
    """The smallest cone spread, in SPREAD_STEP_DEGREES steps, that covers tile (x, y) for a cone aimed east (+x).
    A tile is in when its angle from the aim is at most half the spread. Integer points only sit exactly on a
    half-spread boundary at 0, 45, 90, 135 and 180 degrees (every other multiple of 7.5 degrees has an irrational
    tangent), so those are decided exactly and the rest by floating point with no tie to break."""
    half_step = SPREAD_STEP_DEGREES / 2
    if y == 0:
        angle = 0 if x > 0 else 180
    elif x == 0:
        angle = 90
    elif abs(x) == abs(y):
        angle = 45 if x > 0 else 135
    else:
        angle = math.degrees(math.atan2(abs(y), x))
        return math.ceil(angle / half_step)
    return max(1, round(angle / half_step))


def shape_table():
    """Every tile within RADIUS_LIMIT of an origin (the origin itself left out), for shapes aimed east, with the
    smallest radius and smallest cone spread that cover it. A footprint of radius r and spread s is every tile with
    smallest radius <= r (and, for a cone, smallest spread <= s). The game turns it to the other three directions
    by exact quarter turns."""
    tiles = []
    for x in range(-RADIUS_LIMIT, RADIUS_LIMIT + 1):
        for y in range(-RADIUS_LIMIT, RADIUS_LIMIT + 1):
            if (x, y) == (0, 0):
                continue
            radius = smallest_radius(x, y)
            if radius > RADIUS_LIMIT:
                continue
            tiles.append([x, y, radius, smallest_spread_steps(x, y) * SPREAD_STEP_DEGREES])
    return {
        "aim": "east (+x); grid y grows south",
        "columns": ["x", "y", "smallest_radius", "smallest_spread_degrees"],
        "radius_limit": RADIUS_LIMIT,
        "spread_step_degrees": SPREAD_STEP_DEGREES,
        "tiles": tiles,
    }
