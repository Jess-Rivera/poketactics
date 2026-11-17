class_name MoveArea
extends RefCounted
## Where a move reaches and which tiles and units it hits, read from the shape in the move's recipe (MoveRecipe,
## data/moves.json) and the shape table (data/shapes.json). Rulings: 2026-11-17-move-recipe-structure,
## 2026-11-16-move-shapes-and-range. Plan: docs/discussion-outputs/move-recipes-plan.md (#27). Rules only.
##
## Shapes: a square (length along the aim, width across it) or a circle (a radius, and an angle under 360 for a
## cone), centred on the aimed tile or running forward from it. A move with range 0 is aimed at the user's own
## tile and leaves that tile out, unless it is a single tile. An area hits every unit standing in it, friend or
## foe. The shape table is aimed east; the other directions are exact quarter turns, so no trigonometry runs.

const TABLE_X := 0
const TABLE_Y := 1
const TABLE_SMALLEST_RADIUS := 2
const TABLE_SMALLEST_SPREAD := 3
const ANY_SPREAD := -1


## Grid steps between two cells, no diagonals. Height changes reach through max_reach(), not here.
static func distance(from_cell: Vector2i, to_cell: Vector2i) -> int:
	return absi(to_cell.x - from_cell.x) + absi(to_cell.y - from_cell.y)


## The farthest the move reaches from the user's cell to a target cell inside the grid: a ranged move (max range
## RANGED_MIN_REACH or more) gains or loses range by height (2026-11-17-facing-height-rules), never below its min
## range; melee and range-0 moves keep their range.
static func max_reach(grid: BattleGrid, recipe: Dictionary, user_cell: Vector2i, target_cell: Vector2i) -> int:
	var shape: Dictionary = recipe["shape"]
	var range_max := int(shape["range_max"])
	if range_max < BattleStats.RANGED_MIN_REACH:
		return range_max
	var levels_above := grid.height_level_at(user_cell) - grid.height_level_at(target_cell)
	return maxi(range_max + BattleStats.range_change_from_height(levels_above), int(shape["range_min"]))


## Whether the user may choose this target cell: inside the grid and within the move's reach (only its own cell
## at range 0).
static func can_reach(grid: BattleGrid, recipe: Dictionary, user_cell: Vector2i, target_cell: Vector2i) -> bool:
	if not grid.contains(target_cell):
		return false
	var steps := distance(user_cell, target_cell)
	return steps >= int(recipe["shape"]["range_min"]) and steps <= max_reach(grid, recipe, user_cell, target_cell)


## Every cell inside the grid the user may choose as the target (just its own cell at range 0). The search box
## allows for the largest range a height difference can add.
static func target_cells(grid: BattleGrid, recipe: Dictionary, user_cell: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var reach := int(recipe["shape"]["range_max"])
	if reach >= BattleStats.RANGED_MIN_REACH:
		reach += BattleStats.range_change_from_height(BattleGrid.HIGHEST_LEVEL)
	for step_y in range(-reach, reach + 1):
		for step_x in range(-reach, reach + 1):
			var cell := user_cell + Vector2i(step_x, step_y)
			if can_reach(grid, recipe, user_cell, cell):
				cells.append(cell)
	return cells


## The cell one hit is measured from for facing and height (2026-11-17-facing-height-rules): the blast centre for
## an area bigger than one tile centred on a cell away from the user, else the user's cell. A defender on the blast
## centre is measured from the user.
static func hit_origin(
	recipe: Dictionary, user_cell: Vector2i, aimed_cell: Vector2i, defender_cell: Vector2i
) -> Vector2i:
	var shape: Dictionary = recipe["shape"]
	if MoveRecipe.is_on_user_tile(recipe) or shape["anchor"] == MoveRecipe.ANCHOR_FORWARD or _is_single_tile(shape):
		return user_cell
	return user_cell if defender_cell == aimed_cell else aimed_cell


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


## Every tile the move covers, in a fixed order. target_cell is the aimed tile (the user's own at range 0);
## direction aims forward shapes and cones, and turns squares.
static func footprint(
	shapes: Dictionary, recipe: Dictionary, user_cell: Vector2i, target_cell: Vector2i, direction: Facing.Direction
) -> Array[Vector2i]:
	var shape: Dictionary = recipe["shape"]
	var anchor := user_cell if MoveRecipe.is_on_user_tile(recipe) else target_cell
	var leaves_out_anchor := MoveRecipe.is_on_user_tile(recipe) and not _is_single_tile(shape)
	if shape["kind"] == MoveRecipe.SHAPE_SQUARE:
		return _square_cells(shape, anchor, leaves_out_anchor, direction)
	return _circle_cells(shapes, shape, anchor, leaves_out_anchor, direction)


## Every unit standing on a covered tile inside the grid, friend or foe, in footprint order. Fainted units are
## left out.
static func units_hit(
	battle: Battle,
	shapes: Dictionary,
	recipe: Dictionary,
	user: BattleUnit,
	target_cell: Vector2i,
	direction: Facing.Direction
) -> Array[BattleUnit]:
	var hit: Array[BattleUnit] = []
	for cell in footprint(shapes, recipe, user.cell, target_cell, direction):
		if not battle.grid.contains(cell):
			continue
		var standing := battle.unit_at(cell)
		if standing != null and not standing.has_fainted() and not hit.has(standing):
			hit.append(standing)
	return hit


static func _is_single_tile(shape: Dictionary) -> bool:
	return shape["kind"] == MoveRecipe.SHAPE_SQUARE and int(shape["length"]) == 1 and int(shape["width"]) == 1


## A square's tiles, row by row along the aim. Centred squares sit on the anchor; forward ones start on it, or on
## the next tile when the anchor (the user's own tile) is left out.
static func _square_cells(
	shape: Dictionary, anchor: Vector2i, leaves_out_anchor: bool, direction: Facing.Direction
) -> Array[Vector2i]:
	var length := int(shape["length"])
	var half_width := (int(shape["width"]) - 1) / 2
	var first_along := -(length - 1) / 2
	if shape["anchor"] == MoveRecipe.ANCHOR_FORWARD:
		first_along = 1 if leaves_out_anchor else 0
	var cells: Array[Vector2i] = []
	for along in range(first_along, first_along + length):
		for across in range(-half_width, half_width + 1):
			var offset := Vector2i(along, across)
			if leaves_out_anchor and offset == Vector2i.ZERO:
				continue
			cells.append(anchor + turned(offset, direction))
	return cells


## A circle's tiles: the anchor first (unless left out), then the shape table's order. A cone (angle under 360)
## is turned to the aim; a full circle needs no turn.
static func _circle_cells(
	shapes: Dictionary, shape: Dictionary, anchor: Vector2i, leaves_out_anchor: bool, direction: Facing.Direction
) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	if not leaves_out_anchor:
		cells.append(anchor)
	var angle := int(shape["angle"])
	if angle >= MoveRecipe.FULL_TURN_DEGREES:
		for offset in _table_offsets(shapes, int(shape["radius"]), ANY_SPREAD):
			cells.append(anchor + offset)
		return cells
	for offset in _table_offsets(shapes, int(shape["radius"]), angle):
		cells.append(anchor + turned(offset, direction))
	return cells


## The east-aimed offsets within a radius and, unless spread_degrees is ANY_SPREAD, within a cone spread.
static func _table_offsets(shapes: Dictionary, radius: int, spread_degrees: int) -> Array[Vector2i]:
	var offsets: Array[Vector2i] = []
	for row in shapes["tiles"]:
		if int(row[TABLE_SMALLEST_RADIUS]) > radius:
			continue
		if spread_degrees != ANY_SPREAD and int(row[TABLE_SMALLEST_SPREAD]) > spread_degrees:
			continue
		offsets.append(Vector2i(int(row[TABLE_X]), int(row[TABLE_Y])))
	return offsets
