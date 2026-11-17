class_name MoveArea
extends RefCounted
## Where a move reaches and which tiles and units it hits, read from the move's grid entry (data/moves.json, built
## by tools/move_grid.py) and the shape table (data/shapes.json). Rulings: 2026-11-16-move-shapes-and-range.
## Plan: docs/discussion-outputs/move-schema-opening.md (#9). Rules only: no nodes and no drawing.
##
## Shapes: single (one tile), line (a straight run, aimed), cone (aimed from the user), circle (around the user,
## a unit or a tile). An area hits every unit standing in it, friend or foe. The shape table is aimed east; the
## other directions are exact quarter turns, so no trigonometry runs in the game.

const SHAPE_SINGLE := "single"
const SHAPE_LINE := "line"
const SHAPE_CONE := "cone"
const SHAPE_CIRCLE := "circle"
const TARGET_SELF := "self"
const TABLE_X := 0
const TABLE_Y := 1
const TABLE_SMALLEST_RADIUS := 2
const TABLE_SMALLEST_SPREAD := 3


## Grid steps between two cells, no diagonals (height is ignored until #17).
static func distance(from_cell: Vector2i, to_cell: Vector2i) -> int:
	return absi(to_cell.x - from_cell.x) + absi(to_cell.y - from_cell.y)


## Whether the user may choose this target cell. A self move only ever targets the user's own cell.
static func can_reach(grid_entry: Dictionary, user_cell: Vector2i, target_cell: Vector2i) -> bool:
	if grid_entry["target"] == TARGET_SELF:
		return target_cell == user_cell
	var steps := distance(user_cell, target_cell)
	return steps >= int(grid_entry["range_min"]) and steps <= int(grid_entry["range_max"])


## An east-aimed offset turned to face a direction (grid y grows south, so south is a clockwise quarter turn).
static func turned(offset: Vector2i, direction: Facing.Direction) -> Vector2i:
	match direction:
		Facing.Direction.EAST:
			return offset
		Facing.Direction.SOUTH:
			return Vector2i(-offset.y, offset.x)
		Facing.Direction.WEST:
			return Vector2i(-offset.x, -offset.y)
		_:
			return Vector2i(offset.y, -offset.x)


## Every tile the move covers. target_cell is the chosen unit's or tile's cell (ignored by self moves, except a
## line from a point, which starts there); direction aims lines and cones.
static func footprint(
	shapes: Dictionary, grid_entry: Dictionary, user_cell: Vector2i, target_cell: Vector2i, direction: Facing.Direction
) -> Array[Vector2i]:
	var from_self: bool = grid_entry["target"] == TARGET_SELF
	var origin := user_cell if from_self else target_cell
	var cells: Array[Vector2i] = []
	match grid_entry["shape"]:
		SHAPE_SINGLE:
			cells.append(origin)
		SHAPE_LINE:
			var step := Facing.grid_step(direction)
			# A line from the user starts on the next tile; a line from a point starts on that point.
			var first := 1 if from_self else 0
			for index in int(grid_entry["length"]):
				cells.append(origin + step * (first + index))
		SHAPE_CONE:
			for offset in _table_offsets(shapes, int(grid_entry["radius"]), int(grid_entry["spread_degrees"])):
				cells.append(origin + turned(offset, direction))
		SHAPE_CIRCLE:
			# A circle around the user leaves the user out; one around a unit or tile includes its centre.
			if not from_self:
				cells.append(origin)
			for offset in _table_offsets(shapes, int(grid_entry["radius"]), -1):
				cells.append(origin + offset)
	return cells


## Every unit standing on a covered tile inside the grid, friend or foe, in footprint order. Fainted units are
## left out.
static func units_hit(
	battle: Battle,
	shapes: Dictionary,
	grid_entry: Dictionary,
	user: BattleUnit,
	target_cell: Vector2i,
	direction: Facing.Direction
) -> Array[BattleUnit]:
	var hit: Array[BattleUnit] = []
	for cell in footprint(shapes, grid_entry, user.cell, target_cell, direction):
		if not battle.grid.contains(cell):
			continue
		var standing := battle.unit_at(cell)
		if standing != null and not standing.has_fainted() and not hit.has(standing):
			hit.append(standing)
	return hit


## The east-aimed offsets within a radius and, when spread_degrees is not negative, within a cone spread.
static func _table_offsets(shapes: Dictionary, radius: int, spread_degrees: int) -> Array[Vector2i]:
	var offsets: Array[Vector2i] = []
	for row in shapes["tiles"]:
		if int(row[TABLE_SMALLEST_RADIUS]) > radius:
			continue
		if spread_degrees >= 0 and int(row[TABLE_SMALLEST_SPREAD]) > spread_degrees:
			continue
		offsets.append(Vector2i(int(row[TABLE_X]), int(row[TABLE_Y])))
	return offsets
