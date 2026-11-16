extends Node3D
## Greybox test battle: the 20 by 20 map and pack units from rules/test_battle_setup.gd (issue #6), with select
## and move (issue #7) and turn order (issue #8, docs/discussion-outputs/turn-order-plan.md). Units act one at a
## time, fastest first; the active unit is selected and the camera pans to it. Click a lit tile, choose a facing,
## and it walks there (once per turn). Click another unit to inspect its range. Space ends the turn after a facing
## choice. Until the enemy AI (#11) the player controls both sides.
## Q and E rotate, WASD or the arrow keys pan, wheel or + and - zoom, Tab shows the unit panel. Keys 1, 2 and 3
## restart the battle as a wild, trainer or boss encounter with a new seed (#16): 6 player units against 2 to 4,
## 3 to 6 or 6 enemies.

enum Mode { READY, INSPECTING, CHOOSING_FACING, WALKING, ENDING_TURN }

const BACKGROUND_COLOUR := Color(0.11, 0.12, 0.15)
const IDLE_ANIMATION := "Idle"
## While choosing a facing, the mouse must be this far (world units) from the target's centre to change it.
const FACING_DEAD_ZONE := 0.3
const HINT_TEXT := "Click: move / inspect   Right click, Esc: back   Q / E: rotate   WASD: pan   Wheel, + / -: zoom   Tab: units   1 / 2 / 3: wild / trainer / boss"
const SIDE_LABELS := {Battle.Side.PLAYER: "You", Battle.Side.ENEMY: "Foe"}
const ENCOUNTER_KEYS := {
	KEY_1: TestBattleSetup.EncounterKind.WILD,
	KEY_2: TestBattleSetup.EncounterKind.TRAINER,
	KEY_3: TestBattleSetup.EncounterKind.BOSS,
}

## Kept across a scene reload, so keys 1 to 3 restart with the chosen encounter kind.
static var encounter_kind := TestBattleSetup.EncounterKind.TRAINER

var _battle: Battle
var _pack: PackData
var _turn_order: TurnOrder
var _battle_map: BattleMap
var _camera_rig: CameraRig
var _tile_highlight: TileHighlight
var _turn_bar: TurnBar
var _turn_label: Label
var _sprites_by_unit := {}

var _mode := Mode.READY
## The unit whose turn it is.
var _active_unit: BattleUnit
## Another unit whose range is shown read only, or null.
var _inspected_unit: BattleUnit
var _reachable_paths := {}
var _hovered_cell := CellPicker.NO_CELL
## A unit hovered in the turn bar, or null; its cell gets the cursor outline.
var _bar_hovered_unit: BattleUnit
var _target_cell := CellPicker.NO_CELL
var _chosen_facing := Facing.Direction.SOUTH


func _ready() -> void:
	RenderingServer.set_default_clear_color(BACKGROUND_COLOUR)
	_pack = PackData.shared()
	var random := RandomNumberGenerator.new()
	random.randomize()
	print("%s battle, seed %d" % [TestBattleSetup.ENCOUNTER_NAMES[encounter_kind], random.seed])
	_battle = TestBattleSetup.build(_pack, encounter_kind, random.seed)
	_turn_order = TurnOrder.new(_battle, random)

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
		var sprite_set = _pack.unit(unit.unit_name)["sprite_set"]
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
	unit_panel.show_battle(_battle, _pack)

	_turn_bar = TurnBar.new()
	_turn_bar.name = "TurnBar"
	_turn_bar.set_pack(_pack)
	_turn_bar.unit_hovered.connect(_on_bar_unit_hovered)
	_turn_bar.unit_clicked.connect(_on_bar_unit_clicked)
	add_child(_turn_bar)

	var hint_layer := CanvasLayer.new()
	var hint := Label.new()
	hint.text = HINT_TEXT
	hint.add_theme_font_size_override("font_size", UnitPanel.FONT_SIZE)
	hint.position = Vector2(8, 4)
	hint_layer.add_child(hint)
	_turn_label = Label.new()
	_turn_label.add_theme_font_size_override("font_size", UnitPanel.FONT_SIZE)
	_turn_label.position = Vector2(8, 16)
	hint_layer.add_child(_turn_label)
	add_child(hint_layer)

	_begin_turn()


func _process(_delta: float) -> void:
	if _mode == Mode.WALKING or _camera_rig.camera == null:
		return
	var mouse_position := get_viewport().get_mouse_position()
	var ray_origin := _camera_rig.camera.project_ray_origin(mouse_position)
	var ray_direction := _camera_rig.camera.project_ray_normal(mouse_position)
	if _mode == Mode.CHOOSING_FACING or _mode == Mode.ENDING_TURN:
		_update_facing_from_mouse(ray_origin, ray_direction)
		return
	var cell := CellPicker.cell_under_ray(_battle.grid, ray_origin, ray_direction)
	if cell != _hovered_cell:
		_hovered_cell = cell
		_refresh_marks()


func _unhandled_input(event: InputEvent) -> void:
	if _mode == Mode.WALKING or _active_unit == null:
		return
	var mouse_button := event as InputEventMouseButton
	if mouse_button != null and mouse_button.pressed:
		if mouse_button.button_index == MOUSE_BUTTON_LEFT and not _camera_rig.is_turning():
			_on_left_click()
		elif mouse_button.button_index == MOUSE_BUTTON_RIGHT:
			_step_back()
		return
	var key_event := event as InputEventKey
	if key_event == null or not key_event.pressed or key_event.echo:
		return
	if ENCOUNTER_KEYS.has(key_event.keycode):
		encounter_kind = ENCOUNTER_KEYS[key_event.keycode]
		get_tree().reload_current_scene()
	elif key_event.keycode == KEY_ESCAPE:
		_step_back()
	elif key_event.keycode == KEY_SPACE and (_mode == Mode.READY or _mode == Mode.INSPECTING):
		_start_ending_turn()


## Selects the new active unit, shows its range and pans the camera to it.
func _begin_turn() -> void:
	_active_unit = _turn_order.active_unit()
	_turn_bar.show_forecast(_turn_order.forecast(TurnBar.ENTRY_COUNT))
	if _active_unit == null:
		_turn_label.text = "No unit can act"
		_show_active()
		return
	_turn_label.text = "%s   Round %d   %s (%s)   Space: end turn" % [
		TestBattleSetup.ENCOUNTER_NAMES[encounter_kind],
		_turn_order.round_number,
		_pack.unit(_active_unit.unit_name)["english_name"],
		SIDE_LABELS[_active_unit.side],
	]
	_show_active()
	_camera_rig.pan_to(_battle_map.top_center(_active_unit.cell))


## Back to the active unit: its range if it may still move, nothing inspected.
func _show_active() -> void:
	_inspected_unit = null
	_target_cell = CellPicker.NO_CELL
	_reachable_paths = Movement.reachable_paths(_battle, _active_unit) if _turn_order.can_move(_active_unit) else {}
	_mode = Mode.READY
	_refresh_marks()


func _inspect(unit: BattleUnit) -> void:
	_inspected_unit = unit
	_target_cell = CellPicker.NO_CELL
	_reachable_paths = Movement.reachable_paths(_battle, unit)
	_mode = Mode.INSPECTING
	_refresh_marks()


func _on_left_click() -> void:
	match _mode:
		Mode.CHOOSING_FACING:
			_start_walk()
		Mode.ENDING_TURN:
			_finish_turn()
		Mode.READY, Mode.INSPECTING:
			var clicked_unit := _battle.unit_at(_hovered_cell) if _battle.grid.contains(_hovered_cell) else null
			if clicked_unit != null and clicked_unit != _active_unit:
				_inspect(clicked_unit)
			elif _mode == Mode.READY and clicked_unit == null and _reachable_paths.has(_hovered_cell):
				_target_cell = _hovered_cell
				_chosen_facing = Movement.last_step_facing(_active_unit.cell, _reachable_paths[_target_cell])
				_mode = Mode.CHOOSING_FACING
				_refresh_marks()
			elif _mode == Mode.INSPECTING:
				_show_active()


func _step_back() -> void:
	match _mode:
		Mode.CHOOSING_FACING, Mode.ENDING_TURN, Mode.INSPECTING:
			_show_active()


func _start_ending_turn() -> void:
	_inspected_unit = null
	_reachable_paths = {}
	_target_cell = _active_unit.cell
	_chosen_facing = _active_unit.facing
	_mode = Mode.ENDING_TURN
	_refresh_marks()


func _finish_turn() -> void:
	var unit := _active_unit
	_turn_order.end_turn(_chosen_facing)
	var unit_sprite: UnitSprite = _sprites_by_unit.get(unit)
	if unit_sprite != null:
		unit_sprite.show_unit_facing()
	_begin_turn()


func _on_bar_unit_hovered(unit: BattleUnit) -> void:
	_bar_hovered_unit = unit
	_refresh_marks()


func _on_bar_unit_clicked(unit: BattleUnit) -> void:
	_camera_rig.pan_to(_battle_map.top_center(unit.cell))


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
	var unit := _active_unit
	var start_cell := unit.cell
	if not _turn_order.move_unit(unit, path, _chosen_facing):
		_show_active()
		return
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
	_show_active()


func _refresh_marks() -> void:
	_tile_highlight.reachable_cells.assign(_reachable_paths.keys())
	_tile_highlight.inspecting = _mode == Mode.INSPECTING
	_tile_highlight.path_cells.clear()
	if _mode == Mode.READY or _mode == Mode.CHOOSING_FACING:
		var preview_cell := _target_cell if _mode == Mode.CHOOSING_FACING else _hovered_cell
		if _reachable_paths.has(preview_cell):
			_tile_highlight.path_cells.assign(_reachable_paths[preview_cell])
	_tile_highlight.selected_cell = _active_unit.cell if _active_unit != null else CellPicker.NO_CELL
	_tile_highlight.inspected_cell = _inspected_unit.cell if _inspected_unit != null else CellPicker.NO_CELL
	var facing_mode := _mode == Mode.CHOOSING_FACING or _mode == Mode.ENDING_TURN
	if _bar_hovered_unit != null:
		_tile_highlight.cursor_cell = _bar_hovered_unit.cell
	else:
		_tile_highlight.cursor_cell = _hovered_cell if not facing_mode else CellPicker.NO_CELL
	_tile_highlight.facing_target = _target_cell if facing_mode else CellPicker.NO_CELL
	_tile_highlight.chosen_facing = _chosen_facing
	_tile_highlight.refresh()
