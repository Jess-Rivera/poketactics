class_name Movement
extends RefCounted
## Where a unit can walk this turn and what the walk costs in strike rank (issue #13, ruling
## 2026-11-17-elevation-cost, plan docs/discussion-outputs/strike-rank-plan.md). Each step is orthogonal and climbs
## at most 1 height level or drops at most 2. Allies can be walked through, enemies block, and no unit ends on
## another. A walk costs at most MAX_WALK_COST. Rules only, no nodes.
##
## Cost: the walk splits into segments, each rounded up on its own. A segment starts with the walk, and again at
## any step that changes height after a flat step or after a change the other way, so a run of stairs is one
## segment. A segment costs round up(tiles / 2) + 1 per level climbed + round up(levels dropped / 2); every tile
## stepped onto counts, the one reached by a height change included.

const MAX_WALK_COST := 12
const MAX_CLIMB_LEVELS := 1
const MAX_DROP_LEVELS := 2

## The kind of the last step taken; NONE before the first.
enum StepKind { NONE, FLAT, UP, DOWN }


## Whether one step from a cell to an orthogonal neighbour is allowed by height alone.
static func can_step(grid: BattleGrid, from_cell: Vector2i, to_cell: Vector2i) -> bool:
	if not grid.contains(to_cell):
		return false
	var rise := grid.height_level_at(to_cell) - grid.height_level_at(from_cell)
	return rise <= MAX_CLIMB_LEVELS and -rise <= MAX_DROP_LEVELS


## The SR a walk along a path costs (the cells stepped on in order, the start left out).
static func walk_cost(grid: BattleGrid, start_cell: Vector2i, path: Array[Vector2i]) -> int:
	var segment := 0
	var cost := 0
	var previous_cell := start_cell
	for cell in path:
		var step := _after_step(segment, grid.height_level_at(cell) - grid.height_level_at(previous_cell))
		segment = step.x
		cost += step.y
		previous_cell = cell
	return cost


## Every cell the unit can end a walk on, mapped to the cheapest path there (the cells stepped on in order, the
## start left out, the destination last). Cheapest first, and of equal costs the one found first in
## Facing.ALL_DIRECTIONS order, so the same board always gives the same paths.
static func reachable_paths(battle: Battle, unit: BattleUnit) -> Dictionary:
	var start := Vector3i(unit.cell.x, unit.cell.y, 0)
	var cost_of := {start: 0}
	var came_from := {start: start}
	var states_by_cost: Array[Array] = []
	for cost in MAX_WALK_COST + 1:
		states_by_cost.append([])
	states_by_cost[0].append(start)
	var paths := {}
	for cost in MAX_WALK_COST + 1:
		var index := 0
		# The list can grow while it is read: a step that adds no cost lands in the same list.
		while index < states_by_cost[cost].size():
			var state: Vector3i = states_by_cost[cost][index]
			index += 1
			if cost_of[state] != cost:
				continue
			var cell := Vector2i(state.x, state.y)
			if not paths.has(cell) and cell != unit.cell and battle.unit_at(cell) == null:
				paths[cell] = _path_back(came_from, start, state)
			_expand(battle, unit, state, cost, cost_of, came_from, states_by_cost)
	return paths


## The facing a walk would end with on its own: the direction of the path's last step.
static func last_step_facing(start_cell: Vector2i, path: Array[Vector2i]) -> Facing.Direction:
	var before_last := start_cell if path.size() < 2 else path[path.size() - 2]
	return Facing.direction_of_step(path.back() - before_last)


## Queues every legal step from a search state that keeps the walk within MAX_WALK_COST and is cheaper than any
## way found so far to the same state.
static func _expand(
	battle: Battle,
	unit: BattleUnit,
	state: Vector3i,
	cost: int,
	cost_of: Dictionary,
	came_from: Dictionary,
	states_by_cost: Array[Array]
) -> void:
	var cell := Vector2i(state.x, state.y)
	for direction in Facing.ALL_DIRECTIONS:
		var next_cell: Vector2i = cell + Facing.grid_step(direction)
		if not can_step(battle.grid, cell, next_cell):
			continue
		var standing := battle.unit_at(next_cell)
		if standing != null and standing.side != unit.side:
			continue
		var rise := battle.grid.height_level_at(next_cell) - battle.grid.height_level_at(cell)
		var step := _after_step(state.z, rise)
		var next_cost := cost + step.y
		var next_state := Vector3i(next_cell.x, next_cell.y, step.x)
		if next_cost > MAX_WALK_COST or (cost_of.has(next_state) and cost_of[next_state] <= next_cost):
			continue
		cost_of[next_state] = next_cost
		came_from[next_state] = state
		states_by_cost[next_cost].append(next_state)


## One step's effect on the open segment. A segment is packed in one number: the last step's StepKind times 4,
## plus 2 if the segment has an odd number of tiles, plus 1 if it has an odd number of levels dropped. Returns the
## segment after the step (x) and the SR the step adds (y), so that the sum over a walk is its cost.
static func _after_step(segment: int, rise: int) -> Vector2i:
	var previous_kind: int = segment / 4
	var odd_tiles := (segment / 2) % 2 == 1
	var odd_drops := segment % 2 == 1
	var kind := StepKind.FLAT
	if rise > 0:
		kind = StepKind.UP
	elif rise < 0:
		kind = StepKind.DOWN
	if kind != StepKind.FLAT and kind != previous_kind:
		odd_tiles = false
		odd_drops = false
	var added_cost := 0 if odd_tiles else 1
	odd_tiles = not odd_tiles
	if kind == StepKind.UP:
		added_cost += rise
	elif kind == StepKind.DOWN:
		# round up((D + levels) / 2) - round up(D / 2) for the drops D already in the segment.
		var levels := -rise
		added_cost += levels / 2 if odd_drops else (levels + 1) / 2
		odd_drops = odd_drops != (levels % 2 == 1)
	return Vector2i(kind * 4 + (2 if odd_tiles else 0) + (1 if odd_drops else 0), added_cost)


static func _path_back(came_from: Dictionary, start: Vector3i, end: Vector3i) -> Array[Vector2i]:
	var path: Array[Vector2i] = []
	var state := end
	while state != start:
		path.push_front(Vector2i(state.x, state.y))
		state = came_from[state]
	return path
