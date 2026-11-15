extends Node3D
## Greybox test battle: the 20 by 20 map and 8 pack units from rules/test_battle_setup.gd (issue #6), with select
## and move (issue #7, docs/discussion-outputs/select-and-move-plan.md): click a unit, click a lit tile, choose a
## facing, and it walks there. Any unit can be moved, as often as you like, until turn order arrives in #8.
## Q and E rotate, WASD or the arrow keys pan, wheel or + and - zoom, Tab shows the unit panel.

enum Mode { IDLE, SELECTED, CHOOSING_FACING, WALKING }

const BACKGROUND_COLOUR := Color(0.11, 0.12, 0.15)
const IDLE_ANIMATION := "Idle"
## While choosing a facing, the mouse must be this far (world units) from the target's centre to change it.
const FACING_DEAD_ZONE := 0.3
const HINT_TEXT := "Click: select / move   Right click, Esc: back   Q / E: rotate   WASD: pan   Wheel, + / -: zoom   Tab: units"

var _battle: Battle
var _battle_map: BattleMap
var _camera_rig: CameraRig
var _tile_highlight: TileHighlight
var _sprites_by_unit := {}

var _mode := Mode.IDLE
var _selected_unit: BattleUnit
var _reachable_paths := {}
var _hovered_cell := CellPicker.NO_CELL
var _target_cell := CellPicker.NO_CELL
var _chosen_facing := Facing.Direction.SOUTH


func _ready() -> void:
	RenderingServer.set_default_clear_color(BACKGROUND_COLOUR)
	var pack := PackData.shared()
	_battle = TestBattleSetup.build(pack)

	_battle_map = BattleMap.new()
	_battle_map.name = "BattleMap"
	add_child(_battle_map)
	_battle_map.build(_battle.grid)

	_tile_highlight = TileHighlight.new()
	_tile_highlight.name = "TileHighlight"
	_tile_highlight.grid = _battle.grid
	add_child(_tile_highlight)

	_camera_rig = CameraRig.new()
	_camera_rig.name = "CameraRig"
	_camera_rig.position = _battle_map.map_center()
	_camera_rig.map_bounds = Rect2(0, 0, _battle.grid.width * BattleMap.CELL_SIZE, _battle.grid.depth * BattleMap.CELL_SIZE)
	add_child(_camera_rig)

	for unit in _battle.units:
		var sprite_set = pack.unit(unit.unit_name)["sprite_set"]
		if sprite_set == null:
			push_warning("%s has no sprite set; not drawn" % unit.unit_name)
			continue
		var unit_sprite := UnitSprite.new()
		unit_sprite.name = unit.unit_name
		add_child(unit_sprite)
		unit_sprite.show_unit(unit, sprite_set, IDLE_ANIMATION, _battle_map.top_center(unit.cell))
		_camera_rig.view_step_changed.connect(unit_sprite.set_view_step)
		_sprites_by_unit[unit] = unit_sprite

	var unit_panel := UnitPanel.new()
	unit_panel.name = "UnitPanel"
	add_child(unit_panel)
	unit_panel.show_battle(_battle, pack)

	var hint_layer := CanvasLayer.new()
	var hint := Label.new()
	hint.text = HINT_TEXT
	hint.add_theme_font_size_override("font_size", UnitPanel.FONT_SIZE)
	hint.position = Vector2(8, 4)
	hint_layer.add_child(hint)
	add_child(hint_layer)


func _process(_delta: float) -> void:
	if _mode == Mode.WALKING or _camera_rig.camera == null:
		return
	var mouse_position := get_viewport().get_mouse_position()
	var ray_origin := _camera_rig.camera.project_ray_origin(mouse_position)
	var ray_direction := _camera_rig.camera.project_ray_normal(mouse_position)
	if _mode == Mode.CHOOSING_FACING:
		_update_facing_from_mouse(ray_origin, ray_direction)
		return
	var cell := CellPicker.cell_under_ray(_battle.grid, ray_origin, ray_direction)
	if cell != _hovered_cell:
		_hovered_cell = cell
		_refresh_marks()


func _unhandled_input(event: InputEvent) -> void:
	if _mode == Mode.WALKING:
		return
	var mouse_button := event as InputEventMouseButton
	if mouse_button != null and mouse_button.pressed:
		if mouse_button.button_index == MOUSE_BUTTON_LEFT and not _camera_rig.is_turning():
			_on_left_click()
		elif mouse_button.button_index == MOUSE_BUTTON_RIGHT:
			_step_back()
		return
	var key_event := event as InputEventKey
	if key_event != null and key_event.pressed and not key_event.echo and key_event.keycode == KEY_ESCAPE:
		_step_back()


func _on_left_click() -> void:
	match _mode:
		Mode.CHOOSING_FACING:
			_start_walk()
		_:
			var clicked_unit := _battle.unit_at(_hovered_cell) if _battle.grid.contains(_hovered_cell) else null
			if clicked_unit != null:
				_select(clicked_unit)
			elif _mode == Mode.SELECTED and _reachable_paths.has(_hovered_cell):
				_target_cell = _hovered_cell
				_chosen_facing = Movement.last_step_facing(_selected_unit.cell, _reachable_paths[_target_cell])
				_mode = Mode.CHOOSING_FACING
				_refresh_marks()
			else:
				_deselect()


func _step_back() -> void:
	if _mode == Mode.CHOOSING_FACING:
		_target_cell = CellPicker.NO_CELL
		_mode = Mode.SELECTED
		_refresh_marks()
	elif _mode == Mode.SELECTED:
		_deselect()


func _select(unit: BattleUnit) -> void:
	_selected_unit = unit
	_reachable_paths = Movement.reachable_paths(_battle, unit)
	_target_cell = CellPicker.NO_CELL
	_mode = Mode.SELECTED
	_refresh_marks()


func _deselect() -> void:
	_selected_unit = null
	_reachable_paths = {}
	_target_cell = CellPicker.NO_CELL
	_mode = Mode.IDLE
	_refresh_marks()


## Points the facing toward the mouse: the target's top face is the plane, the bigger axis of the offset wins.
func _update_facing_from_mouse(ray_origin: Vector3, ray_direction: Vector3) -> void:
	var plane_y := CellPicker.top_y_of(_battle.grid, _target_cell)
	if absf(ray_direction.y) < 0.000001:
		return
	var along := (plane_y - ray_origin.y) / ray_direction.y
	var point := ray_origin + ray_direction * along
	var offset := Vector2(point.x - (_target_cell.x + 0.5), point.z - (_target_cell.y + 0.5))
	if offset.length() < FACING_DEAD_ZONE:
		return
	var direction: Facing.Direction
	if absf(offset.x) >= absf(offset.y):
		direction = Facing.Direction.EAST if offset.x > 0.0 else Facing.Direction.WEST
	else:
		direction = Facing.Direction.SOUTH if offset.y > 0.0 else Facing.Direction.NORTH
	if direction != _chosen_facing:
		_chosen_facing = direction
		_refresh_marks()


func _start_walk() -> void:
	var path: Array[Vector2i] = _reachable_paths[_target_cell]
	var unit := _selected_unit
	var start_cell := unit.cell
	_battle.move_unit(unit, path, _chosen_facing)
	_mode = Mode.WALKING
	_tile_highlight.clear()
	_tile_highlight.cursor_cell = CellPicker.NO_CELL
	_tile_highlight.refresh()
	var unit_sprite: UnitSprite = _sprites_by_unit.get(unit)
	if unit_sprite == null:
		_after_walk()
		return
	var step_feet_positions: Array[Vector3] = []
	var step_facings: Array[Facing.Direction] = []
	var previous_cell := start_cell
	for cell in path:
		step_feet_positions.append(_battle_map.top_center(cell))
		step_facings.append(Facing.direction_of_step(cell - previous_cell))
		previous_cell = cell
	unit_sprite.walk_finished.connect(_after_walk, CONNECT_ONE_SHOT)
	unit_sprite.walk(step_feet_positions, step_facings)


func _after_walk() -> void:
	_hovered_cell = CellPicker.NO_CELL
	_deselect()


func _refresh_marks() -> void:
	_tile_highlight.reachable_cells.assign(_reachable_paths.keys())
	_tile_highlight.path_cells.clear()
	var preview_cell := _target_cell if _mode == Mode.CHOOSING_FACING else _hovered_cell
	if _reachable_paths.has(preview_cell):
		_tile_highlight.path_cells.assign(_reachable_paths[preview_cell])
	_tile_highlight.selected_cell = _selected_unit.cell if _selected_unit != null else CellPicker.NO_CELL
	_tile_highlight.cursor_cell = _hovered_cell if _mode != Mode.CHOOSING_FACING else CellPicker.NO_CELL
	_tile_highlight.facing_target = _target_cell if _mode == Mode.CHOOSING_FACING else CellPicker.NO_CELL
	_tile_highlight.chosen_facing = _chosen_facing
	_tile_highlight.refresh()
