class_name TileHighlight
extends MeshInstance3D
## Flat marks drawn just above cell tops: the cells a selected unit can reach, the previewed path, the cursor
## outline, the selected unit's cell, and (while choosing a facing) four arrows on the target cell. Set the fields,
## then call refresh(). Unshaded and flat, so the marks stay pixel crisp.

const LIFT_ABOVE_TOP := 0.02
const REACHABLE_COLOUR := Color(0.35, 0.6, 1.0, 0.35)
## Another unit's range while inspecting it: read only, so a different colour.
const INSPECT_COLOUR := Color(1.0, 0.6, 0.25, 0.35)
const INSPECTED_COLOUR := Color(1.0, 0.6, 0.25, 0.95)
const PATH_COLOUR := Color(0.45, 0.8, 1.0, 0.7)
const CURSOR_COLOUR := Color(1.0, 1.0, 1.0, 0.95)
const SELECTED_COLOUR := Color(1.0, 0.85, 0.3, 0.95)
const ARROW_COLOUR := Color(1.0, 1.0, 1.0, 0.45)
const CHOSEN_ARROW_COLOUR := Color(1.0, 0.85, 0.3, 1.0)
## Outline thickness: two sprite pixels.
const OUTLINE_WIDTH := 2.0 / 24.0
const FILL_INSET := 1.0 / 24.0

var grid: BattleGrid
var reachable_cells: Array[Vector2i] = []
var path_cells: Array[Vector2i] = []
var cursor_cell := CellPicker.NO_CELL
var selected_cell := CellPicker.NO_CELL
## True while reachable_cells is an inspected unit's range rather than the active unit's.
var inspecting := false
var inspected_cell := CellPicker.NO_CELL
var facing_target := CellPicker.NO_CELL
var chosen_facing := Facing.Direction.SOUTH


func _ready() -> void:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material_override = material


func clear() -> void:
	reachable_cells.clear()
	path_cells.clear()
	selected_cell = CellPicker.NO_CELL
	inspecting = false
	inspected_cell = CellPicker.NO_CELL
	facing_target = CellPicker.NO_CELL
	refresh()


func refresh() -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var drawn_anything := false
	for cell in reachable_cells:
		var colour := PATH_COLOUR if cell in path_cells else REACHABLE_COLOUR
		if inspecting:
			colour = INSPECT_COLOUR
		_add_fill(surface, cell, colour)
		drawn_anything = true
	if grid != null and grid.contains(selected_cell):
		_add_outline(surface, selected_cell, SELECTED_COLOUR)
		drawn_anything = true
	if grid != null and grid.contains(inspected_cell):
		_add_outline(surface, inspected_cell, INSPECTED_COLOUR)
		drawn_anything = true
	if grid != null and grid.contains(cursor_cell):
		_add_outline(surface, cursor_cell, CURSOR_COLOUR)
		drawn_anything = true
	if grid != null and grid.contains(facing_target):
		for direction in Facing.ALL_DIRECTIONS:
			_add_arrow(surface, facing_target, direction, CHOSEN_ARROW_COLOUR if direction == chosen_facing else ARROW_COLOUR)
		drawn_anything = true
	mesh = surface.commit() if drawn_anything else null


func _mark_y(cell: Vector2i) -> float:
	return CellPicker.top_y_of(grid, cell) + LIFT_ABOVE_TOP


func _add_fill(surface: SurfaceTool, cell: Vector2i, colour: Color) -> void:
	var west := cell.x + FILL_INSET
	var north := cell.y + FILL_INSET
	var size := BattleMap.CELL_SIZE - FILL_INSET * 2.0
	_add_flat_rect(surface, colour, west, north, size, size, _mark_y(cell))


func _add_outline(surface: SurfaceTool, cell: Vector2i, colour: Color) -> void:
	var y := _mark_y(cell) + LIFT_ABOVE_TOP
	var west := float(cell.x)
	var north := float(cell.y)
	var size := BattleMap.CELL_SIZE
	_add_flat_rect(surface, colour, west, north, size, OUTLINE_WIDTH, y)
	_add_flat_rect(surface, colour, west, north + size - OUTLINE_WIDTH, size, OUTLINE_WIDTH, y)
	_add_flat_rect(surface, colour, west, north, OUTLINE_WIDTH, size, y)
	_add_flat_rect(surface, colour, west + size - OUTLINE_WIDTH, north, OUTLINE_WIDTH, size, y)


## A triangle near the cell edge on the side of direction, pointing outward.
func _add_arrow(surface: SurfaceTool, cell: Vector2i, direction: Facing.Direction, colour: Color) -> void:
	var y := _mark_y(cell) + LIFT_ABOVE_TOP * 2.0
	var centre := Vector2(cell.x + 0.5, cell.y + 0.5)
	var outward := Vector2(Facing.grid_step(direction))
	var across := Vector2(-outward.y, outward.x)
	var tip := centre + outward * 0.46
	var base_middle := centre + outward * 0.22
	var corners := [tip, base_middle + across * 0.18, base_middle - across * 0.18]
	for corner in corners:
		surface.set_color(colour)
		surface.add_vertex(Vector3(corner.x, y, corner.y))


func _add_flat_rect(surface: SurfaceTool, colour: Color, west: float, north: float, size_x: float, size_z: float, y: float) -> void:
	var corner_a := Vector3(west, y, north)
	var corner_b := Vector3(west + size_x, y, north)
	var corner_c := Vector3(west + size_x, y, north + size_z)
	var corner_d := Vector3(west, y, north + size_z)
	for corner in [corner_a, corner_b, corner_c, corner_a, corner_c, corner_d]:
		surface.set_color(colour)
		surface.add_vertex(corner)
