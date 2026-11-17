class_name SightLine
extends RefCounted
## The straight line from one tile's centre to another's, and whether a wall stands on it (issue #18, rulings
## 2026-11-16-height-and-sight and 2026-11-17-line-of-sight-rules, plan docs/discussion-outputs/line-of-sight-plan.md).
## Rules only: no nodes and no drawing.
##
## Every tile the line passes through counts. Where it passes exactly through a tile corner, the two tiles beside
## that corner form one step, and the step blocks only if both of its tiles block. Whole-number arithmetic only, so
## corner crossings are exact and every machine agrees.


## The tiles the line from from_cell to to_cell passes through, in order from from_cell, leaving out both end
## tiles. Each step holds one tile, or the two tiles beside a corner the line passes exactly through.
static func crossed_steps(from_cell: Vector2i, to_cell: Vector2i) -> Array[Array]:
	var steps: Array[Array] = []
	var across_x := absi(to_cell.x - from_cell.x)
	var across_y := absi(to_cell.y - from_cell.y)
	var step_x := signi(to_cell.x - from_cell.x)
	var step_y := signi(to_cell.y - from_cell.y)
	var taken_x := 0
	var taken_y := 0
	var cell := from_cell
	while taken_x < across_x or taken_y < across_y:
		# Compares where the line next crosses a vertical tile edge with where it next crosses a horizontal one,
		# both scaled by 2 x across_x x across_y so they stay whole numbers.
		var next_vertical_edge := (2 * taken_x + 1) * across_y
		var next_horizontal_edge := (2 * taken_y + 1) * across_x
		if next_vertical_edge == next_horizontal_edge:
			steps.append([cell + Vector2i(step_x, 0), cell + Vector2i(0, step_y)])
			cell += Vector2i(step_x, step_y)
			taken_x += 1
			taken_y += 1
		elif next_vertical_edge < next_horizontal_edge:
			cell.x += step_x
			taken_x += 1
		else:
			cell.y += step_y
			taken_y += 1
		if cell != to_cell:
			steps.append([cell])
	return steps


## Whether a wall stands on the line: a step whose every tile is taller than both end tiles.
static func is_walled(grid: BattleGrid, from_cell: Vector2i, to_cell: Vector2i) -> bool:
	var end_height := maxi(grid.height_level_at(from_cell), grid.height_level_at(to_cell))
	for step in crossed_steps(from_cell, to_cell):
		if _step_is_taller(grid, step, end_height):
			return true
	return false


static func _step_is_taller(grid: BattleGrid, step: Array, end_height: int) -> bool:
	for cell in step:
		if grid.height_level_at(cell) <= end_height:
			return false
	return true
