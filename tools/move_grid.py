"""Move recipes for the data pack (issues #9, #27): derived defaults, hand-written overrides, the validator, and
the shape footprint table.

Rulings: 2026-11-17-move-recipe-structure, 2026-11-17-move-recipes-build, 2026-11-16-act-cost,
2026-11-16-height-and-sight, 2026-11-16-environment-model, 2026-11-17-line-of-sight-rules.
Plan: docs/discussion-outputs/move-recipes-plan.md.

A move's recipe holds:
  type, damage_class, accuracy   the move's pokeapi facts, as the game reads them (upgrades may change them, #28)
  sr_cost          strike rank cost of using the move (placeholder PP bands, a tuning item)
  tags             the move's pokeapi flags (contact, ballistics, sound, ...) in pokeapi id order, plus arcing (from
                   ballistics, or an override): arcing ignores units, not walls, for line of sight
  shape            kind square (length along the aim, width across it; width always odd, length odd when
                   centred) or circle (radius: tiles whose centre lies within radius + 0.5; angle: a multiple of
                   SPREAD_STEP_DEGREES, under 360 for a cone), range_min and range_max in grid steps (0 and 0 for a
                   move on the user's own tile), anchor centered (on the aimed tile) or forward (runs away from the
                   user; a circle under 360 is always forward)
  components       ordered effects, each with effect, timing (on_hit: only units that passed the accuracy roll;
                   on_use: not gated by accuracy), touches (units or tiles), who (units only: all, foes, allies or
                   self; all leaves out the user) and an optional chance. #27 runs damage, fixed_damage and faint.
  modifiers        resolve-time number changes the move brings: close_range (ranged damage halved at range 1)
Only the moves named in authored/move_recipe_overrides.json get a recipe (Jess, #9: the 45 roster moves). An
override replaces whole top-level fields (a whole shape, a whole component list).
"""

import json
import math

SHAPE_KINDS = {"square", "circle"}
ANCHORS = {"centered", "forward"}
TIMINGS = {"on_use", "on_hit"}
TOUCHES = {"units", "tiles"}
WHO = {"all", "foes", "allies", "self"}
MODIFIERS = {"close_range"}
EFFECTS = {
    "damage", "fixed_damage", "status", "stat", "drain", "recoil", "heal", "multi_hit", "flinch", "faint", "element",
    "needs_rule",
}
FIXED_DAMAGE_AMOUNTS = {"user_level"}
RECIPE_FIELDS = {"type", "damage_class", "accuracy", "sr_cost", "tags", "shape", "components", "modifiers"}
# pokeapi's 21 move flag identifiers (source/pokeapi/csv/move_flags.csv), then the one tag of our own.
POKEAPI_FLAGS = [
    "contact", "charge", "recharge", "protect", "reflectable", "snatch", "mirror", "punch", "sound", "gravity",
    "defrost", "distance", "heal", "authentic", "powder", "bite", "pulse", "ballistics", "mental", "non-sky-battle",
    "dance",
]
ARCING_TAG = "arcing"
ARCING_FLAG = "ballistics"
KNOWN_TAGS = set(POKEAPI_FLAGS) | {ARCING_TAG}
SHAPE_FIELDS = {"square": {"length", "width"}, "circle": {"radius", "angle"}}
SHAPE_COMMON_FIELDS = {"kind", "range_min", "range_max", "anchor"}

RADIUS_LIMIT = 50
SPREAD_STEP_DEGREES = 15
FULL_TURN_DEGREES = 360
MELEE_RANGE = 1
RANGED_RANGE_MIN = 1
RANGED_RANGE_MAX = 4
DEFAULT_CONE_RADIUS = 3
DEFAULT_CONE_SPREAD = 60
DEFAULT_CIRCLE_RADIUS = 1
HIGHEST_POWER = 1000
# Placeholder act cost bands (2026-11-16-act-cost, exact formula open): (lowest PP in the band, SR cost).
SR_COST_BANDS = [(35, 2), (25, 3), (15, 4), (10, 5), (0, 6)]
SR_COST_WITHOUT_PP = 4

# Which shape pokeapi's target picks by default.
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
    """The shape pokeapi's target picks, with its range: the user's own tile (0), melee or ranged."""
    target = move["target"]
    on_user_tile = True
    if target in CONE_TARGETS:
        shape = {"kind": "circle", "radius": DEFAULT_CONE_RADIUS, "angle": DEFAULT_CONE_SPREAD, "anchor": "forward"}
    elif target in CIRCLE_SELF_TARGETS | CIRCLE_POINT_TARGETS:
        shape = {"kind": "circle", "radius": DEFAULT_CIRCLE_RADIUS, "angle": FULL_TURN_DEGREES, "anchor": "centered"}
        on_user_tile = target in CIRCLE_SELF_TARGETS
    else:
        shape = {"kind": "square", "length": 1, "width": 1, "anchor": "centered"}
        on_user_tile = target in SINGLE_SELF_TARGETS
    if on_user_tile:
        shape["range_min"], shape["range_max"] = 0, 0
    elif move["contact"]:
        shape["range_min"], shape["range_max"] = MELEE_RANGE, MELEE_RANGE
    else:
        shape["range_min"], shape["range_max"] = RANGED_RANGE_MIN, RANGED_RANGE_MAX
    return shape


def on_hit_units(component, chance=None):
    """A component that lands on the units that passed the accuracy roll."""
    component.update({"timing": "on_hit", "touches": "units", "who": "all"})
    if chance is not None:
        component["chance"] = chance
    return component


def on_user(component, chance=None):
    """A component that lands on the user, whatever the accuracy roll."""
    component.update({"timing": "on_use", "touches": "units", "who": "self"})
    if chance is not None:
        component["chance"] = chance
    return component


def default_components(move):
    details = move["battle_details"] or {}
    category = details.get("category", "")
    damaging = move["damage_class"] != "status"
    components = []
    if damaging:
        components.append(on_hit_units({"effect": "damage", "power": move["power"]}))
    if details.get("minimum_hits"):
        hits = {"effect": "multi_hit", "minimum": details["minimum_hits"], "maximum": details["maximum_hits"]}
        components.append(on_hit_units(hits))
    if details.get("ailment", "none") != "none":
        chance = details.get("ailment_chance") or 100
        components.append(on_hit_units({"effect": "status", "status": details["ailment"]}, chance))
    stat_on_user = move["target"] == "user" or category in USER_STAT_CATEGORIES
    for change in details.get("stat_changes", []):
        chance = details.get("stat_chance") or 100
        stat = {"effect": "stat", "stat": change["stat"], "stages": change["change"]}
        components.append(on_user(stat, chance) if stat_on_user else on_hit_units(stat, chance))
    drain = details.get("drain_percent", 0)
    if drain > 0:
        components.append(on_user({"effect": "drain", "percent": drain}))
    elif drain < 0:
        components.append(on_user({"effect": "recoil", "percent": -drain}))
    if details.get("healing_percent", 0) > 0:
        components.append(on_user({"effect": "heal", "percent": details["healing_percent"]}))
    if details.get("flinch_chance", 0) > 0:
        components.append(on_hit_units({"effect": "flinch"}, details["flinch_chance"]))
    if category in RULE_NEEDED_CATEGORIES:
        components.append(on_hit_units({"effect": "needs_rule", "kind": category}))
    if damaging:
        components.append({"effect": "element", "element": move["type"], "timing": "on_use", "touches": "tiles"})
    return components


def default_tags(flags):
    """The move's pokeapi flags, plus arcing when it has the ballistics flag."""
    return list(flags) + ([ARCING_TAG] if ARCING_FLAG in flags else [])


def default_recipe(move, flags):
    shape = default_shape(move)
    is_ranged_damage = move["damage_class"] != "status" and not move["contact"] and shape["range_max"] > 0
    return {
        "type": move["type"],
        "damage_class": move["damage_class"],
        "accuracy": move["accuracy"],
        "sr_cost": sr_cost_for(move["pp"]),
        "tags": default_tags(flags),
        "shape": shape,
        "components": default_components(move),
        "modifiers": [{"modifier": "close_range"}] if is_ranged_damage else [],
    }


def is_whole_number(value, lowest, highest):
    return isinstance(value, int) and not isinstance(value, bool) and lowest <= value <= highest


def size_problems(move_name, shape):
    problems = []
    for size_field in ("length", "width", "radius"):
        if size_field in shape and not is_whole_number(shape[size_field], 1, RADIUS_LIMIT):
            problems.append(f"{move_name}: {size_field} must be 1 to {RADIUS_LIMIT}")
    if shape["kind"] == "square":
        odd_fields = ["width"] + (["length"] if shape.get("anchor") == "centered" else [])
        for size_field in odd_fields:
            if is_whole_number(shape.get(size_field), 1, RADIUS_LIMIT) and shape[size_field] % 2 == 0:
                problems.append(f"{move_name}: {size_field} must be odd")
    if shape["kind"] == "circle":
        angle = shape.get("angle")
        if not (is_whole_number(angle, SPREAD_STEP_DEGREES, FULL_TURN_DEGREES) and angle % SPREAD_STEP_DEGREES == 0):
            problems.append(f"{move_name}: angle must be a multiple of {SPREAD_STEP_DEGREES} up to {FULL_TURN_DEGREES}")
        elif angle < FULL_TURN_DEGREES and shape.get("anchor") != "forward":
            problems.append(f"{move_name}: a circle under {FULL_TURN_DEGREES} degrees is forward")
    return problems


def shape_problems(move_name, shape):
    kind = shape.get("kind")
    if kind not in SHAPE_KINDS:
        return [f"{move_name}: unknown shape kind {kind}"]
    problems = []
    required = SHAPE_COMMON_FIELDS | SHAPE_FIELDS[kind]
    missing, extra = required - shape.keys(), shape.keys() - required
    if missing:
        problems.append(f"{move_name}: shape missing {', '.join(sorted(missing))}")
    if extra:
        problems.append(f"{move_name}: {kind} has no field {', '.join(sorted(extra))}")
    if shape.get("anchor") not in ANCHORS:
        problems.append(f"{move_name}: unknown anchor {shape.get('anchor')}")
    problems.extend(size_problems(move_name, shape))
    range_min, range_max = shape.get("range_min"), shape.get("range_max")
    if not (is_whole_number(range_min, 0, RADIUS_LIMIT) and is_whole_number(range_max, 0, RADIUS_LIMIT)):
        problems.append(f"{move_name}: range_min and range_max must be whole numbers")
    elif range_min > range_max or (range_min == 0 and range_max != 0):
        problems.append(f"{move_name}: range must be 0 to 0, or satisfy 1 <= range_min <= range_max")
    return problems


def component_problems(move_name, component):
    problems = []
    effect = component.get("effect")
    if effect not in EFFECTS:
        problems.append(f"{move_name}: unknown effect {effect}")
    if component.get("timing") not in TIMINGS:
        problems.append(f"{move_name}: {effect} has unknown timing {component.get('timing')}")
    touches = component.get("touches")
    if touches not in TOUCHES:
        problems.append(f"{move_name}: {effect} touches unknown {touches}")
    if touches == "units" and component.get("who") not in WHO:
        problems.append(f"{move_name}: {effect} has unknown who {component.get('who')}")
    if "chance" in component and not is_whole_number(component["chance"], 1, 100):
        problems.append(f"{move_name}: {effect} chance must be 1 to 100")
    if effect == "fixed_damage" and component.get("amount") not in FIXED_DAMAGE_AMOUNTS:
        allowed = ", ".join(sorted(FIXED_DAMAGE_AMOUNTS))
        problems.append(f"{move_name}: fixed_damage amount must be one of {allowed}")
    power = component.get("power")
    if effect == "damage" and power is not None and not is_whole_number(power, 1, HIGHEST_POWER):
        problems.append(f"{move_name}: damage power must be 1 to {HIGHEST_POWER} or null")
    return problems


def validation_problems(move_name, recipe):
    """Every reason a recipe is invalid, as readable lines (empty when valid)."""
    missing, extra = RECIPE_FIELDS - recipe.keys(), recipe.keys() - RECIPE_FIELDS
    if missing or extra:
        return [f"{move_name}: recipe fields differ: missing {sorted(missing)}, extra {sorted(extra)}"]
    problems = shape_problems(move_name, recipe["shape"])
    tags = recipe["tags"]
    if not isinstance(tags, list) or len(set(tags)) != len(tags) or not set(tags) <= KNOWN_TAGS:
        problems.append(f"{move_name}: tags must be a list of known tags with no repeats")
    for component in recipe["components"]:
        problems.extend(component_problems(move_name, component))
    for modifier in recipe["modifiers"]:
        if modifier.get("modifier") not in MODIFIERS:
            problems.append(f"{move_name}: unknown modifier {modifier.get('modifier')}")
    return problems


def add_recipes(moves, overrides_path, flags_by_move_name):
    """Gives each move named in the overrides file its recipe (defaults, then the override's whole fields), and
    every other move a null one. flags_by_move_name holds each move's pokeapi flag identifiers. Stops the export
    with every problem listed if an override or recipe is invalid."""
    overrides = json.loads(overrides_path.read_text(encoding="utf-8"))
    problems = []
    for move in moves.values():
        move["recipe"] = None
    for move_name in sorted(overrides):
        override = overrides[move_name]
        if move_name not in moves:
            problems.append(f"override names unknown move {move_name}")
            continue
        unknown_fields = override.keys() - RECIPE_FIELDS
        if unknown_fields:
            problems.append(f"{move_name}: override has unknown field {', '.join(sorted(unknown_fields))}")
            continue
        recipe = default_recipe(moves[move_name], flags_by_move_name.get(move_name, []))
        recipe.update(override)
        problems.extend(validation_problems(move_name, recipe))
        moves[move_name]["recipe"] = recipe
    if problems:
        raise SystemExit("move recipes are invalid:\n  " + "\n  ".join(problems))
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
