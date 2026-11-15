class_name BattleMap
extends MeshInstance3D
## Draws a BattleGrid as greybox blocks: one column per cell, lighter tops, darker sides, one colour per height.
## Only faces that can be seen are built (a side is drawn where the neighbour is lower or the map ends).

## One cell is one world unit wide, which is 24 sprite pixels (SpriteCollab sprites are drawn for 24 pixel tiles).
const CELL_SIZE := 1.0
## One height level is half a cell, so a step reads as a ledge and not a wall.
const HEIGHT_PER_LEVEL := 0.5
## Height-0 cells still stand on a slab, so the map's outer edge shows a side.
const BASE_THICKNESS := 0.5

const TOP_COLOURS_BY_LEVEL: Array[Color] = [
	Color(0.55, 0.62, 0.50),
	Color(0.62, 0.66, 0.52),
	Color(0.70, 0.70, 0.56),
	Color(0.78, 0.75, 0.62),
]
const CHECKER_LIGHTEN := 0.04
const SIDE_FACING_X_SHADE := 0.72
const SIDE_FACING_Z_SHADE := 0.56

var _grid: BattleGrid


func build(grid: BattleGrid) -> void:
	_grid = grid
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for grid_y in grid.depth:
		for grid_x in grid.width:
			_add_column(surface, Vector2i(grid_x, grid_y))
	mesh = surface.commit()
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material_override = material


## World position of the middle of a cell's top face, where a unit's feet go.
func top_center(cell: Vector2i) -> Vector3:
	return Vector3((cell.x + 0.5) * CELL_SIZE, _top_y(cell), (cell.y + 0.5) * CELL_SIZE)


## World position of the middle of the whole map at ground level.
func map_center() -> Vector3:
	return Vector3(_grid.width * CELL_SIZE / 2.0, BASE_THICKNESS, _grid.depth * CELL_SIZE / 2.0)


func _top_y(cell: Vector2i) -> float:
	return BASE_THICKNESS + _grid.height_level_at(cell) * HEIGHT_PER_LEVEL


func _add_column(surface: SurfaceTool, cell: Vector2i) -> void:
	var level := _grid.height_level_at(cell)
	var top_colour: Color = TOP_COLOURS_BY_LEVEL[clampi(level, 0, TOP_COLOURS_BY_LEVEL.size() - 1)]
	if (cell.x + cell.y) % 2 == 0:
		top_colour = top_colour.lightened(CHECKER_LIGHTEN)
	var top_y := _top_y(cell)
	var west := cell.x * CELL_SIZE
	var east := west + CELL_SIZE
	var north := cell.y * CELL_SIZE
	var south := north + CELL_SIZE
	_add_quad(surface, top_colour,
		Vector3(west, top_y, north), Vector3(east, top_y, north),
		Vector3(east, top_y, south), Vector3(west, top_y, south))
	for direction in Facing.ALL_DIRECTIONS:
		var neighbour := cell + Facing.grid_step(direction)
		var neighbour_top_y := _top_y(neighbour) if _grid.contains(neighbour) else 0.0
		if neighbour_top_y >= top_y:
			continue
		var shade := SIDE_FACING_X_SHADE if direction in [Facing.Direction.EAST, Facing.Direction.WEST] else SIDE_FACING_Z_SHADE
		var side_colour := top_colour.darkened(1.0 - shade)
		match direction:
			Facing.Direction.NORTH:
				_add_wall(surface, side_colour, Vector2(west, north), Vector2(east, north), neighbour_top_y, top_y)
			Facing.Direction.SOUTH:
				_add_wall(surface, side_colour, Vector2(west, south), Vector2(east, south), neighbour_top_y, top_y)
			Facing.Direction.WEST:
				_add_wall(surface, side_colour, Vector2(west, north), Vector2(west, south), neighbour_top_y, top_y)
			Facing.Direction.EAST:
				_add_wall(surface, side_colour, Vector2(east, north), Vector2(east, south), neighbour_top_y, top_y)


func _add_wall(surface: SurfaceTool, colour: Color, start: Vector2, end: Vector2, bottom_y: float, top_y: float) -> void:
	_add_quad(surface, colour,
		Vector3(start.x, top_y, start.y), Vector3(end.x, top_y, end.y),
		Vector3(end.x, bottom_y, end.y), Vector3(start.x, bottom_y, start.y))


func _add_quad(surface: SurfaceTool, colour: Color, corner_a: Vector3, corner_b: Vector3, corner_c: Vector3, corner_d: Vector3) -> void:
	for corner in [corner_a, corner_b, corner_c, corner_a, corner_c, corner_d]:
		surface.set_color(colour)
		surface.add_vertex(corner)
