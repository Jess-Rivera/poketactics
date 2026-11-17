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
##
## Line of sight (#18, 2026-11-17-line-of-sight-rules, SightLine): a wall between the user and where the move lands
## makes a cell unaimable; a projectile (MoveRecipe.is_projectile) lands on the first unit on its line; walls
## shelter the tiles behind them inside an area, units never do.

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


## Whether the mover, standing on from_cell, may aim the move at target_cell: in reach and in sight.
static func can_target(
	battle: Battle, recipe: Dictionary, mover: BattleUnit, from_cell: Vector2i, target_cell: Vector2i
) -> bool:
	if not can_reach(battle.grid, recipe, from_cell, target_cell):
		return false
	return is_in_sight(battle, recipe, mover, from_cell, target_cell)


## Every cell the mover, standing on from_cell, may aim the move at (just its own cell at range 0).
static func target_cells(
	battle: Battle, recipe: Dictionary, mover: BattleUnit, from_cell: Vector2i
) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for cell in _cells_in_reach(battle.grid, recipe, from_cell):
		if is_in_sight(battle, recipe, mover, from_cell, cell):
			cells.append(cell)
	return cells


## Every cell in the move's reach that a wall hides from the mover standing on from_cell.
static func walled_cells(
	battle: Battle, recipe: Dictionary, mover: BattleUnit, from_cell: Vector2i
) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for cell in _cells_in_reach(battle.grid, recipe, from_cell):
		if not is_in_sight(battle, recipe, mover, from_cell, cell):
			cells.append(cell)
	return cells


## Whether no wall stands between from_cell and where the move would land when aimed at aimed_cell. Moves on the
## user's own tile always are.
static func is_in_sight(
	battle: Battle, recipe: Dictionary, mover: BattleUnit, from_cell: Vector2i, aimed_cell: Vector2i
) -> bool:
	if MoveRecipe.is_on_user_tile(recipe):
		return true
	var landing := landing_cell(battle, recipe, mover, from_cell, aimed_cell)
	return not SightLine.is_walled(battle.grid, from_cell, landing)


## Where the move lands when the mover, standing on from_cell, aims it at aimed_cell: for a projectile, the first
## standing unit on the line (at a corner, only when both tiles hold one, and then the first in reading order: lower
## grid y, then lower x); otherwise, or with nobody in the way, the aimed cell. The mover's own cell counts as empty,
## so the AI can ask from a cell it has not walked to yet. Walls do not stop the search; is_in_sight judges them.
static func landing_cell(
	battle: Battle, recipe: Dictionary, mover: BattleUnit, from_cell: Vector2i, aimed_cell: Vector2i
) -> Vector2i:
	if not MoveRecipe.is_projectile(recipe):
		return aimed_cell
	for step in SightLine.crossed_steps(from_cell, aimed_cell):
		var occupied := _occupied_cells(battle, mover, step)
		if not occupied.is_empty() and occupied.size() == step.size():
			return _first_in_reading_order(occupied)
	return aimed_cell


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


## Every tile the move covers, in a fixed order, leaving out tiles inside the grid that a wall shelters from the
## shape's origin (the user for shapes on or running from the user, else the centre). target_cell is where the move
## lands (landing_cell; the user's own tile at range 0); direction aims forward shapes and cones, and turns squares.
static func footprint(
	grid: BattleGrid,
	shapes: Dictionary,
	recipe: Dictionary,
	user_cell: Vector2i,
	target_cell: Vector2i,
	direction: Facing.Direction
) -> Array[Vector2i]:
	var shape: Dictionary = recipe["shape"]
	var anchor := user_cell if MoveRecipe.is_on_user_tile(recipe) else target_cell
	var leaves_out_anchor := MoveRecipe.is_on_user_tile(recipe) and not _is_single_tile(shape)
	var cells: Array[Vector2i]
	if shape["kind"] == MoveRecipe.SHAPE_SQUARE:
		cells = _square_cells(shape, anchor, leaves_out_anchor, direction)
	else:
		cells = _circle_cells(shapes, shape, anchor, leaves_out_anchor, direction)
	var origin := user_cell if shape["anchor"] == MoveRecipe.ANCHOR_FORWARD else anchor
	return _unsheltered(grid, origin, cells)


## Every unit standing on a covered tile inside the grid, friend or foe, in footprint order. Fainted units are
## left out. target_cell is where the move lands (landing_cell).
static func units_hit(
	battle: Battle,
	shapes: Dictionary,
	recipe: Dictionary,
	user: BattleUnit,
	target_cell: Vector2i,
	direction: Facing.Direction
) -> Array[BattleUnit]:
	var hit: Array[BattleUnit] = []
	for cell in footprint(battle.grid, shapes, recipe, user.cell, target_cell, direction):
		if not battle.grid.contains(cell):
			continue
		var standing := battle.unit_at(cell)
		if standing != null and not standing.has_fainted() and not hit.has(standing):
			hit.append(standing)
	return hit


## Every cell inside the grid within the move's reach of from_cell, sight not judged. The search box allows for
## the largest range a height difference can add.
static func _cells_in_reach(grid: BattleGrid, recipe: Dictionary, from_cell: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var reach := int(recipe["shape"]["range_max"])
	if reach >= BattleStats.RANGED_MIN_REACH:
		reach += BattleStats.range_change_from_height(BattleGrid.HIGHEST_LEVEL)
	for step_y in range(-reach, reach + 1):
		for step_x in range(-reach, reach + 1):
			var cell := from_cell + Vector2i(step_x, step_y)
			if can_reach(grid, recipe, from_cell, cell):
				cells.append(cell)
	return cells


## The cells of one sight line step that hold a standing unit other than the mover.
static func _occupied_cells(battle: Battle, mover: BattleUnit, step: Array) -> Array[Vector2i]:
	var occupied: Array[Vector2i] = []
	for cell in step:
		var standing := battle.unit_at(cell)
		if standing != null and standing != mover:
			occupied.append(cell)
	return occupied


static func _first_in_reading_order(cells: Array[Vector2i]) -> Vector2i:
	var first := cells[0]
	for cell in cells:
		if cell.y < first.y or (cell.y == first.y and cell.x < first.x):
			first = cell
	return first


## The cells no wall shelters from origin. Cells outside the grid are kept for the caller to skip.
static func _unsheltered(grid: BattleGrid, origin: Vector2i, cells: Array[Vector2i]) -> Array[Vector2i]:
	if not grid.contains(origin):
		return cells
	var open_cells: Array[Vector2i] = []
	for cell in cells:
		if not grid.contains(cell) or not SightLine.is_walled(grid, origin, cell):
			open_cells.append(cell)
	return open_cells


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
