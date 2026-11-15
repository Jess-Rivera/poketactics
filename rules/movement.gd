class_name Movement
extends RefCounted
## Where a unit can walk this turn (docs/decisions/2026-11-15-movement-range.md): up to 4 orthogonal steps, each
## climbing at most 1 height level or dropping at most 2. Allies can be walked through, enemies block, and no
## unit ends on another (docs/discussion-outputs/select-and-move-plan.md). Rules only, no nodes.

const STEPS_PER_TURN := 4
const MAX_CLIMB_LEVELS := 1
const MAX_DROP_LEVELS := 2


## Whether one step from a cell to an orthogonal neighbour is allowed by height alone.
static func can_step(grid: BattleGrid, from_cell: Vector2i, to_cell: Vector2i) -> bool:
	if not grid.contains(to_cell):
		return false
	var rise := grid.height_level_at(to_cell) - grid.height_level_at(from_cell)
	return rise <= MAX_CLIMB_LEVELS and -rise <= MAX_DROP_LEVELS


## Every cell the unit can end its walk on, mapped to the shortest path there (the cells stepped on in order, the
## start left out, the destination last). Breadth-first in Facing.ALL_DIRECTIONS order, so equal paths always
## resolve the same way.
static func reachable_paths(battle: Battle, unit: BattleUnit) -> Dictionary:
	var came_from := {unit.cell: unit.cell}
	var steps_to := {unit.cell: 0}
	var frontier: Array[Vector2i] = [unit.cell]
	var paths := {}
	while not frontier.is_empty():
		var cell: Vector2i = frontier.pop_front()
		if steps_to[cell] == STEPS_PER_TURN:
			continue
		for direction in Facing.ALL_DIRECTIONS:
			var next_cell: Vector2i = cell + Facing.grid_step(direction)
			if came_from.has(next_cell) or not can_step(battle.grid, cell, next_cell):
				continue
			var standing := battle.unit_at(next_cell)
			if standing != null and standing.side != unit.side:
				continue
			came_from[next_cell] = cell
			steps_to[next_cell] = steps_to[cell] + 1
			frontier.append(next_cell)
			if standing == null:
				paths[next_cell] = _path_back(came_from, unit.cell, next_cell)
	return paths


## The facing a walk would end with on its own: the direction of the path's last step.
static func last_step_facing(start_cell: Vector2i, path: Array[Vector2i]) -> Facing.Direction:
	var before_last := start_cell if path.size() < 2 else path[path.size() - 2]
	return Facing.direction_of_step(path.back() - before_last)


static func _path_back(came_from: Dictionary, start_cell: Vector2i, end_cell: Vector2i) -> Array[Vector2i]:
	var path: Array[Vector2i] = []
	var cell := end_cell
	while cell != start_cell:
		path.push_front(cell)
		cell = came_from[cell]
	return path
