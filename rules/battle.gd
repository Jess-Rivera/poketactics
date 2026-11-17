class_name Battle
extends RefCounted
## A battle as rules see it: the grid and every unit on it, by side. No nodes and no drawing, so turns, moves and
## AI (later slices) can run headless on it.

enum Side { PLAYER, ENEMY }

## winning_side before the battle is over.
const NO_WINNER := -1

var grid: BattleGrid
var units: Array[BattleUnit] = []
## The side that won (a Side value), or NO_WINNER while the battle goes on. Set once by settle_rout, never changed.
var winning_side := NO_WINNER


func _init(battle_grid: BattleGrid = null) -> void:
	grid = battle_grid


func add_unit(unit: BattleUnit, unit_side: int) -> void:
	unit.side = unit_side
	units.append(unit)


func units_on_side(unit_side: int) -> Array[BattleUnit]:
	var on_side: Array[BattleUnit] = []
	for unit in units:
		if unit.side == unit_side:
			on_side.append(unit)
	return on_side


## The unit standing on a cell, or null. A fainted unit has left the map, so its cell is free.
func unit_at(cell: Vector2i) -> BattleUnit:
	for unit in units:
		if unit.cell == cell and not unit.has_fainted():
			return unit
	return null


func is_over() -> bool:
	return winning_side != NO_WINNER


## Ends the battle on a rout (issue #12, ruling 2026-11-17-battle-end-m1) once a side has no standing unit: the
## other side wins, or the acting side if both are gone (a last Self-Destruct). Call after every move resolves.
func settle_rout(acting_side: int) -> void:
	if is_over():
		return
	var sides_standing: Array[int] = []
	for unit_side in Side.values():
		if standing_count(unit_side) > 0:
			sides_standing.append(unit_side)
	if sides_standing.size() == 1:
		winning_side = sides_standing[0]
	elif sides_standing.is_empty():
		winning_side = acting_side


## How many of a side's units have not fainted.
func standing_count(unit_side: int) -> int:
	var standing := 0
	for unit in units_on_side(unit_side):
		if not unit.has_fainted():
			standing += 1
	return standing


## Walks a unit along a path (from Movement.reachable_paths) and turns it to the chosen facing.
func move_unit(unit: BattleUnit, path: Array[Vector2i], end_facing: Facing.Direction) -> void:
	assert(not path.is_empty(), "a move needs at least one step")
	unit.cell = path.back()
	unit.facing = end_facing
