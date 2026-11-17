class_name Battle
extends RefCounted
## A battle as rules see it: the grid and every unit on it, by side. No nodes and no drawing, so turns, moves and
## AI (later slices) can run headless on it.

enum Side { PLAYER, ENEMY }

var grid: BattleGrid
var units: Array[BattleUnit] = []


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


## Walks a unit along a path (from Movement.reachable_paths) and turns it to the chosen facing.
func move_unit(unit: BattleUnit, path: Array[Vector2i], end_facing: Facing.Direction) -> void:
	assert(not path.is_empty(), "a move needs at least one step")
	unit.cell = path.back()
	unit.facing = end_facing
