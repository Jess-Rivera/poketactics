class_name CellPicker
extends RefCounted
## Which map cell is under a camera ray. The map is one mesh without collision, so instead of physics picking each
## cell is treated as a solid column (from the ground to its top face, as BattleMap draws it) and the column the
## ray enters first wins. Clicking a column's side picks that column, as it is the one drawn there.

const NO_CELL := Vector2i(-1, -1)


static func cell_under_ray(grid: BattleGrid, ray_origin: Vector3, ray_direction: Vector3) -> Vector2i:
	var nearest_cell := NO_CELL
	var nearest_distance := INF
	for grid_y in grid.depth:
		for grid_x in grid.width:
			var cell := Vector2i(grid_x, grid_y)
			var distance := _ray_box_distance(ray_origin, ray_direction, column_box(grid, cell))
			if distance < nearest_distance:
				nearest_distance = distance
				nearest_cell = cell
	return nearest_cell


## The world-space box a cell's column fills.
static func column_box(grid: BattleGrid, cell: Vector2i) -> AABB:
	var top_y := top_y_of(grid, cell)
	return AABB(Vector3(cell.x * BattleMap.CELL_SIZE, 0.0, cell.y * BattleMap.CELL_SIZE),
		Vector3(BattleMap.CELL_SIZE, top_y, BattleMap.CELL_SIZE))


static func top_y_of(grid: BattleGrid, cell: Vector2i) -> float:
	return BattleMap.BASE_THICKNESS + grid.height_level_at(cell) * BattleMap.HEIGHT_PER_LEVEL


## Where along the ray (in ray lengths) it first enters the box, or INF if it misses (slab method).
static func _ray_box_distance(ray_origin: Vector3, ray_direction: Vector3, box: AABB) -> float:
	var enter := -INF
	var leave := INF
	for axis in 3:
		var low := box.position[axis]
		var high := box.end[axis]
		if absf(ray_direction[axis]) < 0.000001:
			if ray_origin[axis] < low or ray_origin[axis] > high:
				return INF
			continue
		var first := (low - ray_origin[axis]) / ray_direction[axis]
		var second := (high - ray_origin[axis]) / ray_direction[axis]
		enter = maxf(enter, minf(first, second))
		leave = minf(leave, maxf(first, second))
	if enter > leave or leave < 0.0:
		return INF
	return maxf(enter, 0.0)
