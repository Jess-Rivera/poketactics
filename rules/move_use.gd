class_name MoveUse
extends RefCounted
## One use of a move (issues #10, #27; rulings 2026-11-16-use-a-move-m1, 2026-11-17-move-recipe-structure; plan
## docs/discussion-outputs/move-recipes-plan.md): whether the user may aim it at a cell, which tiles it covers, and
## what it does there. Rules only: no nodes and no drawing. MoveRecipe reads the recipe, MoveArea owns the geometry,
## MoveEffects does each effect and BattleStats holds every formula; this file runs the one generic loop.
##
## The loop: on-hit components first, unit by unit in footprint order (one accuracy roll per unit that any of them
## lands on, then each one's chance and handler), then on-use components in recipe order. Components with no
## handler yet are skipped before any roll. A use with nobody in the footprint is allowed: a wasted action.


## What the move did to one unit it rolled accuracy against.
class Outcome:
	var unit: BattleUnit
	var is_hit := false
	var is_critical_hit := false
	var damage := 0
	## The move type's multiplier on the unit's types (0 immune, below 1 resisted, above 1 super effective).
	var type_multiplier := 1.0


var user: BattleUnit
var move_name: String
var target_cell: Vector2i
var direction: Facing.Direction
## The built recipe (MoveRecipe.built); empty when the move has none.
var recipe: Dictionary
## Filled by resolve(), in footprint order.
var outcomes: Array[Outcome] = []

var _battle: Battle
var _pack: PackData
var _move: Dictionary


## direction aims forward shapes and cones; for other moves pass the direction toward the target
## (Facing.direction_of_step).
func _init(
	battle: Battle,
	pack: PackData,
	move_user: BattleUnit,
	used_move_name: String,
	chosen_target_cell: Vector2i,
	aim_direction: Facing.Direction
) -> void:
	_battle = battle
	_pack = pack
	user = move_user
	move_name = used_move_name
	target_cell = chosen_target_cell
	direction = aim_direction
	_move = pack.move(used_move_name)
	recipe = MoveRecipe.built(pack, move_user, used_move_name)


## The user knows the move, it has a recipe, and the target cell is in range. Nobody needs to stand there.
func is_allowed() -> bool:
	if recipe.is_empty() or not user.move_names.has(move_name):
		return false
	return MoveArea.can_reach(recipe, user.cell, target_cell) and _battle.grid.contains(target_cell)


## The SR using the move costs (2026-11-16-act-cost; placeholder bands until tuned). Call only when is_allowed().
func strike_rank_cost() -> int:
	return int(recipe["sr_cost"])


## Every tile the move covers, for the preview.
func footprint() -> Array[Vector2i]:
	return MoveArea.footprint(_pack.shapes, recipe, user.cell, target_cell, direction)


## Carries the move out: turns the user, then runs the loop. Call once, only when is_allowed().
func resolve(random: RandomNumberGenerator) -> void:
	assert(is_allowed(), "%s cannot be used on %s" % [move_name, target_cell])
	if not MoveRecipe.is_on_user_tile(recipe) or MoveRecipe.needs_aim(recipe):
		user.facing = direction
	var units_hit := MoveArea.units_hit(_battle, _pack.shapes, recipe, user, target_cell, direction)
	var on_hit_components := _handled_unit_components(true)
	if not on_hit_components.is_empty():
		for unit in units_hit:
			if _any_lands_on(on_hit_components, unit):
				outcomes.append(_strike(unit, on_hit_components, random))
	for component in _handled_unit_components(false):
		for unit in _on_use_units(component, units_hit):
			if _rolls_component_chance(component, random):
				MoveEffects.run(self, component, unit, null, random)


## The crit stage of the move (its critical_hit_stage, later plus other boosts).
func critical_hit_stage() -> int:
	var details = _move.get("battle_details")
	return int(details["critical_hit_stage"]) if details != null else 0


## The damage one of this use's damage components does to a unit.
func damage_to(unit: BattleUnit, component: Dictionary, is_critical_hit: bool) -> int:
	return component_damage(_pack, user, unit, recipe, component, user.cell, target_cell, is_critical_hit)


## The damage one hit of a move's first damage component does to a unit when the user stands on user_cell and
## aims at target_cell. The AI scores with the non-crit value.
static func hit_damage(
	pack: PackData,
	attacker: BattleUnit,
	defender: BattleUnit,
	used_move_name: String,
	user_cell: Vector2i,
	aimed_cell: Vector2i,
	is_critical_hit: bool
) -> int:
	var built := MoveRecipe.built(pack, attacker, used_move_name)
	var component := MoveRecipe.damage_component(built)
	if component.is_empty():
		return 0
	return component_damage(pack, attacker, defender, built, component, user_cell, aimed_cell, is_critical_hit)


## A damage component's amount: fixed level damage or the stat formula at the component's power, then the
## close-range modifier when the move brings it and is used at range 1.
static func component_damage(
	pack: PackData,
	attacker: BattleUnit,
	defender: BattleUnit,
	built: Dictionary,
	component: Dictionary,
	user_cell: Vector2i,
	aimed_cell: Vector2i,
	is_critical_hit: bool
) -> int:
	var amount := 0
	if component["effect"] == MoveRecipe.EFFECT_FIXED_DAMAGE:
		var multiplier := BattleStats.type_multiplier(pack, built["type"], defender.types)
		amount = BattleStats.level_damage(attacker.level, multiplier)
	else:
		amount = BattleStats.power_damage(pack, attacker, defender, built, component["power"], is_critical_hit)
	var is_close := MoveArea.distance(user_cell, aimed_cell) == 1
	if is_close and MoveRecipe.has_modifier(built, MoveRecipe.MODIFIER_CLOSE_RANGE):
		amount = BattleStats.close_range_damage(amount)
	return amount


## The handled components that touch units, either the on-hit ones or the on-use ones, in recipe order.
func _handled_unit_components(on_hit: bool) -> Array[Dictionary]:
	var picked: Array[Dictionary] = []
	for component in recipe["components"]:
		if component["touches"] != MoveRecipe.TOUCHES_UNITS or not MoveEffects.has_handler(component["effect"]):
			continue
		if (component["timing"] == MoveRecipe.TIMING_ON_HIT) == on_hit:
			picked.append(component)
	return picked


func _any_lands_on(components: Array[Dictionary], unit: BattleUnit) -> bool:
	for component in components:
		if MoveRecipe.lands_on(component, user, unit):
			return true
	return false


## The units an on-use component lands on: the user for self, otherwise those in the footprint its who allows.
func _on_use_units(component: Dictionary, units_hit: Array[BattleUnit]) -> Array[BattleUnit]:
	var landed: Array[BattleUnit] = []
	if component["who"] == MoveRecipe.WHO_SELF:
		landed.append(user)
		return landed
	for unit in units_hit:
		if MoveRecipe.lands_on(component, user, unit):
			landed.append(unit)
	return landed


func _rolls_component_chance(component: Dictionary, random: RandomNumberGenerator) -> bool:
	if not component.has("chance"):
		return true
	return BattleStats.rolls_chance(int(component["chance"]), random)


## Accuracy roll, then each on-hit component that lands on the unit: its chance, then its handler.
func _strike(unit: BattleUnit, components: Array[Dictionary], random: RandomNumberGenerator) -> Outcome:
	var outcome := Outcome.new()
	outcome.unit = unit
	outcome.type_multiplier = BattleStats.type_multiplier(_pack, recipe["type"], unit.types)
	outcome.is_hit = BattleStats.rolls_hit(recipe, random)
	if not outcome.is_hit:
		return outcome
	for component in components:
		if MoveRecipe.lands_on(component, user, unit) and _rolls_component_chance(component, random):
			MoveEffects.run(self, component, unit, outcome, random)
	return outcome
