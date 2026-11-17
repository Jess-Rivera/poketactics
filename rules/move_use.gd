class_name MoveUse
extends RefCounted
## One use of a move (issue #10, docs/discussion-outputs/use-a-move-opening.md, ruling 2026-11-16-use-a-move-m1):
## whether the user may aim it at a cell, which tiles it covers, and what it does to each unit there. Rules only:
## no nodes and no drawing. MoveArea owns the geometry and BattleStats every formula; this file applies them.
##
## M1 runs damage only: every unit in the footprint gets its own accuracy roll, then a crit roll and formula
## damage, or fixed damage for moves like Night Shade; a ranged move used at range 1 does half. Status moves
## change nothing yet. A use with nobody in the footprint is allowed: a wasted action.

const EFFECT_DAMAGE := "damage"
const EFFECT_FIXED_DAMAGE := "fixed_damage"
const EFFECT_USER_FAINTS := "user_faints"
const AIMED_SHAPES := [MoveArea.SHAPE_CONE, MoveArea.SHAPE_LINE]


## What the move did to one unit in its footprint.
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
## Filled by resolve(), in footprint order.
var outcomes: Array[Outcome] = []

var _battle: Battle
var _pack: PackData
var _move: Dictionary
var _grid_entry: Dictionary


## direction aims cones and lines; for other moves pass the direction toward the target (Facing.direction_of_step).
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
	var grid_entry = _move.get("grid")
	_grid_entry = grid_entry if grid_entry != null else {}


## Whether the move is aimed in a direction from the user (a cone or line from self) rather than at a cell.
static func is_aimed(grid_entry: Dictionary) -> bool:
	return grid_entry["target"] == MoveArea.TARGET_SELF and grid_entry["shape"] in AIMED_SHAPES


## The user knows the move, it has grid behaviour, and the target cell is in range. Nobody needs to stand there.
func is_allowed() -> bool:
	if _grid_entry.is_empty() or not user.move_names.has(move_name):
		return false
	return MoveArea.can_reach(_grid_entry, user.cell, target_cell) and _battle.grid.contains(target_cell)


## Every tile the move covers, for the preview.
func footprint() -> Array[Vector2i]:
	return MoveArea.footprint(_pack.shapes, _grid_entry, user.cell, target_cell, direction)


## Carries the move out: turns the user, strikes every unit in the footprint, then applies user_faints. Call once,
## only when is_allowed().
func resolve(random: RandomNumberGenerator) -> void:
	assert(is_allowed(), "%s cannot be used on %s" % [move_name, target_cell])
	if _grid_entry["target"] != MoveArea.TARGET_SELF or is_aimed(_grid_entry):
		user.facing = direction
	if deals_damage(_grid_entry):
		for unit in MoveArea.units_hit(_battle, _pack.shapes, _grid_entry, user, target_cell, direction):
			outcomes.append(_strike(unit, random))
	if has_effect(_grid_entry, EFFECT_USER_FAINTS):
		user.take_damage(user.hit_points)


## Whether a move's grid entry carries an effect (EFFECT_DAMAGE, EFFECT_USER_FAINTS and so on).
static func has_effect(grid_entry: Dictionary, effect_name: String) -> bool:
	for effect in grid_entry.get("payload", []):
		if effect["effect"] == effect_name:
			return true
	return false


## Whether the move damages the units it hits (by the stat formula or a fixed amount).
static func deals_damage(grid_entry: Dictionary) -> bool:
	return has_effect(grid_entry, EFFECT_DAMAGE) or has_effect(grid_entry, EFFECT_FIXED_DAMAGE)


## The damage one hit does to a unit when the user stands on user_cell and aims at target_cell: fixed level
## damage or the stat formula, then the 0.5x of a ranged move at range 1. The AI scores with the non-crit value.
static func hit_damage(
	pack: PackData,
	attacker: BattleUnit,
	defender: BattleUnit,
	move_name: String,
	user_cell: Vector2i,
	target_cell: Vector2i,
	is_critical_hit: bool
) -> int:
	var move := pack.move(move_name)
	var grid_entry: Dictionary = move["grid"]
	var amount := 0
	if has_effect(grid_entry, EFFECT_FIXED_DAMAGE):
		var multiplier := BattleStats.type_multiplier(pack, move["type"], defender.types)
		amount = BattleStats.level_damage(attacker.level, multiplier)
	else:
		amount = BattleStats.move_damage(pack, attacker, defender, move_name, is_critical_hit)
	if grid_entry["close_penalty"] and MoveArea.distance(user_cell, target_cell) == 1:
		amount = BattleStats.close_range_damage(amount)
	return amount


## Accuracy roll, then crit roll, then damage to one unit.
func _strike(unit: BattleUnit, random: RandomNumberGenerator) -> Outcome:
	var outcome := Outcome.new()
	outcome.unit = unit
	outcome.type_multiplier = BattleStats.type_multiplier(_pack, _move["type"], unit.types)
	outcome.is_hit = BattleStats.rolls_hit(_move, random)
	if not outcome.is_hit:
		return outcome
	if not has_effect(_grid_entry, EFFECT_FIXED_DAMAGE):
		outcome.is_critical_hit = BattleStats.rolls_critical_hit(_critical_hit_stage(), random)
	outcome.damage = hit_damage(_pack, user, unit, move_name, user.cell, target_cell, outcome.is_critical_hit)
	unit.take_damage(outcome.damage)
	return outcome


func _critical_hit_stage() -> int:
	var details = _move.get("battle_details")
	return int(details["critical_hit_stage"]) if details != null else 0
