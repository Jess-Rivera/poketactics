class_name MoveRecipe
extends RefCounted
## Reads a move's recipe (data/moves.json, built by tools/move_grid.py, which documents every field): basics,
## shape, components and modifiers. Issue #27, rulings 2026-11-17-move-recipe-structure and
## 2026-11-17-move-recipes-build, plan docs/discussion-outputs/move-recipes-plan.md. Rules only: no nodes.
##
## Everything that uses a move (MoveUse, MoveArea, the AI, the view) reads the built recipe from built(), never the
## pack entry directly, so upgrades (#28) change every reader at once.

const SHAPE_SQUARE := "square"
const SHAPE_CIRCLE := "circle"
const ANCHOR_FORWARD := "forward"
const FULL_TURN_DEGREES := 360
const EFFECT_DAMAGE := "damage"
const EFFECT_FIXED_DAMAGE := "fixed_damage"
const EFFECT_FAINT := "faint"
const TIMING_ON_HIT := "on_hit"
const TOUCHES_UNITS := "units"
const WHO_FOES := "foes"
const WHO_ALLIES := "allies"
const WHO_SELF := "self"
const MODIFIER_CLOSE_RANGE := "close_range"


## The move as this unit uses it: today the pack's recipe itself, since upgrades come in #28. Empty for a move
## with no recipe. Read only: callers never change it.
static func built(pack: PackData, unit: BattleUnit, move_name: String) -> Dictionary:
	assert(unit != null)
	var recipe = pack.move(move_name).get("recipe")
	return recipe if recipe != null else {}


## Whether the player picks a direction for the move: a shape that runs forward, or a cone.
static func needs_aim(recipe: Dictionary) -> bool:
	var shape: Dictionary = recipe["shape"]
	if shape["anchor"] == ANCHOR_FORWARD:
		return true
	return shape["kind"] == SHAPE_CIRCLE and int(shape["angle"]) < FULL_TURN_DEGREES


## Whether the move is used on the user's own tile (range 0 to 0).
static func is_on_user_tile(recipe: Dictionary) -> bool:
	return int(recipe["shape"]["range_max"]) == 0


static func has_effect(recipe: Dictionary, effect_name: String) -> bool:
	for component in recipe.get("components", []):
		if component["effect"] == effect_name:
			return true
	return false


## Whether the move damages the units it hits (by the stat formula or a fixed amount).
static func deals_damage(recipe: Dictionary) -> bool:
	return not damage_component(recipe).is_empty()


## The first component that deals damage (formula or fixed), or an empty one.
static func damage_component(recipe: Dictionary) -> Dictionary:
	for component in recipe.get("components", []):
		if component["effect"] in [EFFECT_DAMAGE, EFFECT_FIXED_DAMAGE]:
			return component
	return {}


static func has_modifier(recipe: Dictionary, modifier_name: String) -> bool:
	for modifier in recipe.get("modifiers", []):
		if modifier["modifier"] == modifier_name:
			return true
	return false


## Whether a component that touches units lands on this unit, by its who: all leaves out the user, self is only
## the user.
static func lands_on(component: Dictionary, user: BattleUnit, unit: BattleUnit) -> bool:
	match component["who"]:
		WHO_SELF:
			return unit == user
		WHO_FOES:
			return unit.side != user.side
		WHO_ALLIES:
			return unit != user and unit.side == user.side
		_:
			return unit != user
