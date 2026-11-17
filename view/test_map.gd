extends Node3D
## Greybox test battle: the 20 by 20 map and pack units from rules/test_battle_setup.gd (issue #6), with select
## and move (issue #7) and turn order (issue #8, docs/discussion-outputs/turn-order-plan.md). Units act one at a
## time, fastest first; the active unit is selected and the camera pans to it. Click a lit tile, choose a facing,
## and it walks there (once per turn). Keys 1 to 4 aim one of its moves (once per turn, issue #10,
## docs/discussion-outputs/use-a-move-opening.md): the target cells and the area are lit, click or Enter uses it.
## Click another unit to inspect its range. Space ends the turn after a facing choice. The player controls only the
## player side; enemy units choose with TurnAi (#11, docs/discussion-outputs/enemy-turn-opening.md) and play their
## turn out with short pauses: camera, walk, area preview, strike, facing. When a side is routed the board freezes
## and the end screen offers the same battle again or a new one (#12, docs/discussion-outputs/win-lose-opening.md).
## Q and E rotate, WASD or the arrow keys pan, wheel or + and - zoom, Tab shows the unit panel. F1, F2 and F3
## restart the battle as a wild, trainer or boss encounter with a new seed (#16): 6 player units against 2 to 4,
## 3 to 6 or 6 enemies.

enum Mode { READY, INSPECTING, CHOOSING_FACING, WALKING, ENDING_TURN, AIMING, RESOLVING, AI_TURN, OVER }

const BACKGROUND_COLOUR := Color(0.11, 0.12, 0.15)
const IDLE_ANIMATION := "Idle"
## While choosing a facing, the mouse must be this far (world units) from the target's centre to change it.
const FACING_DEAD_ZONE := 0.3
const HINT_TEXT := "Click: move / inspect   1-4: moves   Right click, Esc: back   Q / E: rotate   WASD: pan   Wheel: zoom   Tab: units   F1-F3: wild / trainer / boss"
const SIDE_LABELS := {Battle.Side.PLAYER: "You", Battle.Side.ENEMY: "Foe"}
const ENCOUNTER_KEYS := {
	KEY_F1: TestBattleSetup.EncounterKind.WILD,
	KEY_F2: TestBattleSetup.EncounterKind.TRAINER,
	KEY_F3: TestBattleSetup.EncounterKind.BOSS,
}
const MOVE_KEYS := [KEY_1, KEY_2, KEY_3, KEY_4]
const CONFIRM_KEYS := [KEY_ENTER, KEY_KP_ENTER]
const ATTACK_ANIMATION := "Attack"
const HURT_ANIMATION := "Hurt"
const NO_MOVE := -1
const DAMAGE_TEXT_COLOUR := Color(1.0, 1.0, 1.0)
const QUIET_TEXT_COLOUR := Color(0.7, 0.7, 0.7)
## The side TurnAi plays (2026-11-17-enemy-ai-m1); a hotseat toggle comes with #15.
const AI_SIDE := Battle.Side.ENEMY
## Seconds an AI unit waits after the camera reaches it, and while its move's area is shown before the strike.
const AI_THINK_SECONDS := 0.4
const AI_PREVIEW_SECONDS := 0.5

## Kept across a scene reload, so keys 1 to 3 restart with the chosen encounter kind.
static var encounter_kind := TestBattleSetup.EncounterKind.TRAINER
## The seed the last battle started with, and whether the next load reuses it (the end screen's Same battle, #12).
static var last_seed := 0
static var replay_seed_requested := false

var _battle: Battle
var _pack: PackData
var _turn_order: TurnOrder
var _battle_map: BattleMap
var _camera_rig: CameraRig
var _tile_highlight: TileHighlight
var _turn_bar: TurnBar
var _turn_label: Label
var _move_menu: MoveMenu
var _unit_panel: UnitPanel
var _end_screen: EndScreen
## The battle's seeded random source, shared by turn order and move rolls.
var _random: RandomNumberGenerator
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
## The active unit's move being aimed (an index into its move_names), or NO_MOVE.
var _aimed_move_index := NO_MOVE
## Where a cone or line is aimed, from the mouse.
var _aim_direction := Facing.Direction.SOUTH
## The AI unit's choice for the turn being played out.
var _ai_choice: TurnAi.Choice
## The tiles an AI move will cover, lit before it strikes.
var _ai_preview_cells: Array[Vector2i] = []
## Times the AI pauses; a child of this scene, so a restart mid-turn drops its pending step.
var _pause_timer: Timer


func _ready() -> void:
	RenderingServer.set_default_clear_color(BACKGROUND_COLOUR)
	_pack = PackData.shared()
	_random = RandomNumberGenerator.new()
	if replay_seed_requested:
		_random.seed = last_seed
		replay_seed_requested = false
	else:
		_random.randomize()
	last_seed = _random.seed
	print("%s battle, seed %d" % [TestBattleSetup.ENCOUNTER_NAMES[encounter_kind], _random.seed])
	_battle = TestBattleSetup.build(_pack, encounter_kind, _random.seed)
	_turn_order = TurnOrder.new(_battle, _random)

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

	_unit_panel = UnitPanel.new()
	_unit_panel.name = "UnitPanel"
	add_child(_unit_panel)
	_unit_panel.show_battle(_battle, _pack)
	_move_menu = MoveMenu.new()
	_move_menu.name = "MoveMenu"
	_move_menu.move_clicked.connect(_pick_move)
	add_child(_move_menu)

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

	_pause_timer = Timer.new()
	_pause_timer.one_shot = true
	add_child(_pause_timer)

	_end_screen = EndScreen.new()
	_end_screen.name = "EndScreen"
	_end_screen.same_battle_pressed.connect(_restart_same_battle)
	_end_screen.new_battle_pressed.connect(_restart_new_battle)
	add_child(_end_screen)

	_begin_turn()


func _process(_delta: float) -> void:
	if _is_busy() or _camera_rig.camera == null:
		return
	var mouse_position := get_viewport().get_mouse_position()
	var ray_origin := _camera_rig.camera.project_ray_origin(mouse_position)
	var ray_direction := _camera_rig.camera.project_ray_normal(mouse_position)
	if _mode == Mode.CHOOSING_FACING or _mode == Mode.ENDING_TURN:
		var facing = _direction_under_mouse(_target_cell, ray_origin, ray_direction)
		if facing != null and facing != _chosen_facing:
			_chosen_facing = facing
			_refresh_marks()
		return
	if _mode == Mode.AIMING and MoveUse.is_aimed(_aimed_grid_entry()):
		var aim = _direction_under_mouse(_active_unit.cell, ray_origin, ray_direction)
		if aim != null and aim != _aim_direction:
			_aim_direction = aim
			_refresh_marks()
		return
	var cell := CellPicker.cell_under_ray(_battle.grid, ray_origin, ray_direction)
	if cell != _hovered_cell:
		_hovered_cell = cell
		_refresh_marks()


func _unhandled_input(event: InputEvent) -> void:
	var key_event := event as InputEventKey
	if key_event != null and key_event.pressed and ENCOUNTER_KEYS.has(key_event.keycode):
		encounter_kind = ENCOUNTER_KEYS[key_event.keycode]
		get_tree().reload_current_scene()
		return
	if _is_busy() or _active_unit == null:
		return
	var mouse_button := event as InputEventMouseButton
	if mouse_button != null and mouse_button.pressed:
		if mouse_button.button_index == MOUSE_BUTTON_LEFT and not _camera_rig.is_turning():
			_on_left_click()
		elif mouse_button.button_index == MOUSE_BUTTON_RIGHT:
			_step_back()
		return
	if key_event == null or not key_event.pressed or key_event.echo:
		return
	if key_event.keycode in MOVE_KEYS and _mode in [Mode.READY, Mode.INSPECTING, Mode.AIMING]:
		_pick_move(MOVE_KEYS.find(key_event.keycode))
	elif key_event.keycode in CONFIRM_KEYS and _mode == Mode.AIMING:
		_use_aimed_move()
	elif key_event.keycode == KEY_ESCAPE:
		_step_back()
	elif key_event.keycode == KEY_SPACE and (_mode == Mode.READY or _mode == Mode.INSPECTING):
		_start_ending_turn()


## Selects the new active unit and pans the camera to it: a player unit shows its range, an AI unit starts playing
## out its choice.
func _begin_turn() -> void:
	_active_unit = _turn_order.active_unit()
	_turn_bar.show_forecast(_turn_order.forecast(TurnBar.ENTRY_COUNT))
	if _active_unit == null:
		_turn_label.text = "No unit can act"
		_move_menu.show_moves(null, _pack, NO_MOVE, false)
		_tile_highlight.clear()
		return
	var is_ai_turn := _active_unit.side == AI_SIDE
	_turn_label.text = "%s   Round %d   %s (%s)   %s" % [
		TestBattleSetup.ENCOUNTER_NAMES[encounter_kind],
		_turn_order.round_number,
		_pack.unit(_active_unit.unit_name)["english_name"],
		SIDE_LABELS[_active_unit.side],
		"Thinking" if is_ai_turn else "Space: end turn",
	]
	_camera_rig.pan_to(_battle_map.top_center(_active_unit.cell))
	if is_ai_turn:
		_start_ai_turn()
	else:
		_show_active()


## Back to the active unit: its range if it may still move, nothing inspected.
func _show_active() -> void:
	_inspected_unit = null
	_target_cell = CellPicker.NO_CELL
	_aimed_move_index = NO_MOVE
	_reachable_paths = Movement.reachable_paths(_battle, _active_unit) if _turn_order.can_move(_active_unit) else {}
	_mode = Mode.READY
	_move_menu.show_moves(_active_unit, _pack, NO_MOVE, _turn_order.can_act(_active_unit))
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
		Mode.AIMING:
			_use_aimed_move()
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
		Mode.CHOOSING_FACING, Mode.ENDING_TURN, Mode.INSPECTING, Mode.AIMING:
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


## The direction from a cell's centre to the mouse on that cell's top face (the bigger axis of the offset wins),
## or null while the mouse is within FACING_DEAD_ZONE of the centre.
func _direction_under_mouse(anchor_cell: Vector2i, ray_origin: Vector3, ray_direction: Vector3) -> Variant:
	var plane_y := CellPicker.top_y_of(_battle.grid, anchor_cell)
	if absf(ray_direction.y) < 0.000001:
		return null
	var along := (plane_y - ray_origin.y) / ray_direction.y
	var point := ray_origin + ray_direction * along
	var offset := Vector2(point.x - (anchor_cell.x + 0.5), point.z - (anchor_cell.y + 0.5))
	if offset.length() < FACING_DEAD_ZONE:
		return null
	if absf(offset.x) >= absf(offset.y):
		return Facing.Direction.EAST if offset.x > 0.0 else Facing.Direction.WEST
	return Facing.Direction.SOUTH if offset.y > 0.0 else Facing.Direction.NORTH


func _is_busy() -> bool:
	return _mode in [Mode.WALKING, Mode.RESOLVING, Mode.AI_TURN, Mode.OVER]


## The battle is over (#12): the board freezes (the camera still works) and the end screen shows the result.
func _show_end() -> void:
	_mode = Mode.OVER
	_reachable_paths = {}
	_inspected_unit = null
	_tile_highlight.clear()
	_tile_highlight.cursor_cell = CellPicker.NO_CELL
	_tile_highlight.refresh()
	_move_menu.show_moves(null, _pack, NO_MOVE, false)
	_turn_label.text = "%s   Round %d   %s" % [
		TestBattleSetup.ENCOUNTER_NAMES[encounter_kind],
		_turn_order.round_number,
		EndScreen.result_title(_battle),
	]
	_end_screen.show_result(_battle, _turn_order.round_number)


## Restarts with the seed this battle used, so the same units start in the same places and the same turn order.
func _restart_same_battle() -> void:
	replay_seed_requested = true
	get_tree().reload_current_scene()


func _restart_new_battle() -> void:
	get_tree().reload_current_scene()


## Starts aiming one of the active unit's moves, if it may still act.
func _pick_move(move_index: int) -> void:
	if not _turn_order.can_act(_active_unit) or move_index >= _active_unit.move_names.size():
		return
	_aimed_move_index = move_index
	_inspected_unit = null
	_reachable_paths = {}
	_aim_direction = _active_unit.facing
	_mode = Mode.AIMING
	_move_menu.show_moves(_active_unit, _pack, move_index, true)
	_refresh_marks()


func _aimed_grid_entry() -> Dictionary:
	return _pack.move(_active_unit.move_names[_aimed_move_index])["grid"]


## The use the mouse is aiming now: at the user for self moves, else at the hovered cell. Cones and lines take the
## aim direction; other moves face their target.
func _aimed_move_use() -> MoveUse:
	var grid_entry := _aimed_grid_entry()
	var target_cell := _active_unit.cell if grid_entry["target"] == MoveArea.TARGET_SELF else _hovered_cell
	var direction := _active_unit.facing
	if MoveUse.is_aimed(grid_entry):
		direction = _aim_direction
	elif target_cell != _active_unit.cell:
		direction = Facing.direction_of_step(target_cell - _active_unit.cell)
	return MoveUse.new(_battle, _pack, _active_unit, _active_unit.move_names[_aimed_move_index], target_cell, direction)


func _use_aimed_move() -> void:
	_play_move_use(_aimed_move_use())


## Uses the move through the turn order and plays the attack; returns false (and changes nothing) if not allowed.
func _play_move_use(move_use: MoveUse) -> bool:
	if not _turn_order.use_move(move_use, _random):
		return false
	_mode = Mode.RESOLVING
	_tile_highlight.clear()
	_tile_highlight.cursor_cell = CellPicker.NO_CELL
	_tile_highlight.refresh()
	_move_menu.show_moves(_active_unit, _pack, NO_MOVE, false)
	var user_sprite: UnitSprite = _sprites_by_unit.get(move_use.user)
	if user_sprite == null:
		_show_outcomes(move_use)
		_after_move(move_use)
		return true
	user_sprite.show_unit_facing()
	user_sprite.hit_landed.connect(_show_outcomes.bind(move_use), CONNECT_ONE_SHOT)
	user_sprite.play_once_finished.connect(_after_move.bind(move_use), CONNECT_ONE_SHOT)
	user_sprite.play_once(ATTACK_ANIMATION)
	return true


## At the attack's hit frame: each unit hit flinches and shows its damage, or "Miss"; fainted units fade out.
func _show_outcomes(move_use: MoveUse) -> void:
	var user_sprite: UnitSprite = _sprites_by_unit.get(move_use.user)
	if user_sprite != null and _pack.move(move_use.move_name)["damage_class"] == "status":
		user_sprite.float_text("No effect yet", QUIET_TEXT_COLOUR)
	for outcome in move_use.outcomes:
		var unit_sprite: UnitSprite = _sprites_by_unit.get(outcome.unit)
		if unit_sprite == null:
			continue
		if not outcome.is_hit:
			unit_sprite.float_text("Miss", QUIET_TEXT_COLOUR)
			continue
		unit_sprite.play_once(HURT_ANIMATION)
		unit_sprite.show_hit_points()
		unit_sprite.float_text(_outcome_text(outcome), DAMAGE_TEXT_COLOUR)
		if outcome.unit.has_fainted():
			unit_sprite.fade_out()


## The damage, with a crit and effectiveness note under it.
func _outcome_text(outcome: MoveUse.Outcome) -> String:
	var lines: Array[String] = [str(outcome.damage)]
	if outcome.is_critical_hit:
		lines.append("Critical")
	if outcome.type_multiplier == 0.0:
		lines.append("No effect")
	elif outcome.type_multiplier > 1.0:
		lines.append("Super effective")
	elif outcome.type_multiplier < 1.0:
		lines.append("Not very effective")
	return "\n".join(lines)


## After the attack: the panels catch up and a user that fainted (Self-Destruct) fades. If that ended the battle
## the end screen shows; otherwise a fainted user's turn passes on, an AI unit ends its turn, and a player unit goes
## back to its menu.
func _after_move(move_use: MoveUse) -> void:
	_unit_panel.refresh()
	_hovered_cell = CellPicker.NO_CELL
	if move_use.user.has_fainted():
		var user_sprite: UnitSprite = _sprites_by_unit.get(move_use.user)
		if user_sprite != null:
			user_sprite.fade_out()
	if _battle.is_over():
		_show_end()
		return
	if move_use.user.has_fainted():
		_begin_turn()
		return
	if move_use.user.side == AI_SIDE:
		_finish_ai_turn()
		return
	_turn_bar.show_forecast(_turn_order.forecast(TurnBar.ENTRY_COUNT))
	_show_active()


func _start_walk() -> void:
	if not _play_walk(_reachable_paths[_target_cell], _chosen_facing, _after_walk):
		_show_active()


## Walks the active unit through the turn order and plays the walk, then calls on_finished; returns false (and
## changes nothing) if it may not move.
func _play_walk(path: Array[Vector2i], end_facing: Facing.Direction, on_finished: Callable) -> bool:
	var unit := _active_unit
	var start_cell := unit.cell
	if not _turn_order.move_unit(unit, path, end_facing):
		return false
	_mode = Mode.WALKING
	_tile_highlight.clear()
	_tile_highlight.cursor_cell = CellPicker.NO_CELL
	_tile_highlight.refresh()
	var unit_sprite: UnitSprite = _sprites_by_unit.get(unit)
	if unit_sprite == null:
		on_finished.call()
		return true
	var step_feet_positions: Array[Vector3] = []
	var step_facings: Array[Facing.Direction] = []
	var previous_cell := start_cell
	for cell in path:
		step_feet_positions.append(_battle_map.top_center(cell))
		step_facings.append(Facing.direction_of_step(cell - previous_cell))
		previous_cell = cell
	unit_sprite.walk_finished.connect(on_finished, CONNECT_ONE_SHOT)
	unit_sprite.walk(step_feet_positions, step_facings)
	return true


func _after_walk() -> void:
	_hovered_cell = CellPicker.NO_CELL
	_show_active()


## An AI unit's turn: choose, wait a moment, then walk, preview and strike as the choice says, then face and end.
func _start_ai_turn() -> void:
	_mode = Mode.AI_TURN
	_inspected_unit = null
	_reachable_paths = {}
	_ai_preview_cells.clear()
	_ai_choice = TurnAi.choose(_battle, _pack, _active_unit)
	_move_menu.show_moves(_active_unit, _pack, NO_MOVE, false)
	_refresh_marks()
	_after_pause(AI_THINK_SECONDS, _play_ai_walk)


func _play_ai_walk() -> void:
	if not _ai_choice.has_walk():
		_play_ai_move()
		return
	var walk_facing := Movement.last_step_facing(_active_unit.cell, _ai_choice.path)
	if not _play_walk(_ai_choice.path, walk_facing, _play_ai_move):
		_play_ai_move()


## Lights the chosen move's area, then strikes after the preview pause; ends the turn if there is no move.
func _play_ai_move() -> void:
	_mode = Mode.AI_TURN
	if not _ai_choice.has_move():
		_finish_ai_turn()
		return
	var move_use := MoveUse.new(
		_battle, _pack, _active_unit, _ai_choice.move_name, _ai_choice.target_cell, _ai_choice.direction
	)
	_ai_preview_cells = move_use.footprint()
	_refresh_marks()
	_after_pause(AI_PREVIEW_SECONDS, _strike_ai_move.bind(move_use))


func _strike_ai_move(move_use: MoveUse) -> void:
	_ai_preview_cells.clear()
	if not _play_move_use(move_use):
		_finish_ai_turn()


func _finish_ai_turn() -> void:
	_chosen_facing = _ai_choice.end_facing
	_finish_turn()


func _after_pause(seconds: float, next_step: Callable) -> void:
	_pause_timer.timeout.connect(next_step, CONNECT_ONE_SHOT)
	_pause_timer.start(seconds)


func _refresh_marks() -> void:
	_tile_highlight.reachable_cells.assign(_reachable_paths.keys())
	_tile_highlight.move_range_cells.clear()
	_tile_highlight.move_area_cells.clear()
	if _mode == Mode.AIMING:
		_tile_highlight.move_range_cells = MoveArea.target_cells(_battle.grid, _aimed_grid_entry(), _active_unit.cell)
		var move_use := _aimed_move_use()
		if move_use.is_allowed():
			_tile_highlight.move_area_cells = move_use.footprint()
	elif _mode == Mode.AI_TURN:
		_tile_highlight.move_area_cells.assign(_ai_preview_cells)
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
