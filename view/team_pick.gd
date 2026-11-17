class_name TeamPick
extends Control
## Blind hotseat picks (#15, docs/discussion-outputs/hotseat-opening.md, ruling 2026-11-17-hotseat-m1b): player 1
## picks TEAM_SIZE units from the pool while player 2 looks away, a cover screen passes the machine over, then player
## 2 picks. One button per pool unit (portrait, name, types); click to add or remove. Units that may not join (team
## full, species taken) are greyed out. TestBattleSetup decides who may join; this screen only draws and clicks.

const TEST_MAP_SCENE := "res://view/test_map.tscn"
const PORTRAIT_SIZE := Vector2(32, 32)
const POOL_COLUMNS := 3
const ROW_GAP := 4
const PANEL_PADDING := 8

var _pack: PackData
## The side whose player is picking: the player side (player 1) first, then the enemy side (player 2).
var _picking_side := Battle.Side.PLAYER
var _team: Array[String] = []
var _first_team: Array[String] = []
var _buttons_by_unit := {}
var _picker: MarginContainer
var _cover: CenterContainer
var _heading: Label
var _done_button: Button


func _ready() -> void:
	RenderingServer.set_default_clear_color(TestMap.BACKGROUND_COLOUR)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_pack = PackData.shared()
	_picker = _build_picker()
	_cover = _build_cover()
	_cover.visible = false
	_refresh()


func _build_picker() -> MarginContainer:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side_name in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side_name, PANEL_PADDING)
	add_child(margin)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", ROW_GAP)
	margin.add_child(rows)
	_heading = Label.new()
	_heading.add_theme_font_size_override("font_size", UnitPanel.FONT_SIZE)
	rows.add_child(_heading)
	var pool_grid := GridContainer.new()
	pool_grid.columns = POOL_COLUMNS
	pool_grid.add_theme_constant_override("h_separation", ROW_GAP)
	pool_grid.add_theme_constant_override("v_separation", ROW_GAP)
	rows.add_child(pool_grid)
	for unit_name in TestBattleSetup.HOTSEAT_POOL:
		var button := _unit_button(unit_name)
		pool_grid.add_child(button)
		_buttons_by_unit[unit_name] = button
	_done_button = Button.new()
	_done_button.text = "Done"
	_done_button.add_theme_font_size_override("font_size", UnitPanel.FONT_SIZE)
	_done_button.pressed.connect(_finish_team)
	rows.add_child(_done_button)
	return margin


func _build_cover() -> CenterContainer:
	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(centre)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", ROW_GAP)
	centre.add_child(rows)
	var message := Label.new()
	message.text = "Pass to %s.\n%s, look away." % [_player_name(Battle.Side.ENEMY), _player_name(Battle.Side.PLAYER)]
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.add_theme_font_size_override("font_size", EndScreen.TITLE_FONT_SIZE)
	rows.add_child(message)
	var ready_button := Button.new()
	ready_button.text = "Ready"
	ready_button.add_theme_font_size_override("font_size", UnitPanel.FONT_SIZE)
	ready_button.pressed.connect(_start_second_pick)
	rows.add_child(ready_button)
	return centre


func _unit_button(unit_name: String) -> Button:
	var pack_unit := _pack.unit(unit_name)
	var button := Button.new()
	var type_names: Array[String] = []
	for type_name in pack_unit["types"]:
		type_names.append(String(type_name).capitalize())
	button.text = "%s\n%s" % [pack_unit["english_name"], " / ".join(type_names)]
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_font_size_override("font_size", UnitPanel.FONT_SIZE)
	var full_portrait := PortraitLoader.portrait(PortraitLoader.set_id_for(pack_unit, int(pack_unit["dex_number"])))
	button.icon = PortraitLoader.cropped(full_portrait, PORTRAIT_SIZE)
	button.pressed.connect(_toggle_unit.bind(unit_name))
	return button


func _toggle_unit(unit_name: String) -> void:
	if _team.has(unit_name):
		_team.erase(unit_name)
	elif TestBattleSetup.can_join_team(_pack, _team, unit_name):
		_team.append(unit_name)
	_refresh()


## Marks picked units, greys out units that may not join, and enables Done once the team is valid.
func _refresh() -> void:
	_heading.text = "%s: pick %d (%d of %d)" % [
		_player_name(_picking_side), TestBattleSetup.TEAM_SIZE, _team.size(), TestBattleSetup.TEAM_SIZE
	]
	for unit_name in _buttons_by_unit:
		var button: Button = _buttons_by_unit[unit_name]
		var is_picked := _team.has(unit_name)
		button.modulate = MoveMenu.PICKED_COLOUR if is_picked else Color.WHITE
		button.disabled = not is_picked and not TestBattleSetup.can_join_team(_pack, _team, unit_name)
	_done_button.disabled = not TestBattleSetup.is_valid_team(_pack, _team)


## Player 1 done: hide their picks behind the cover screen. Player 2 done: start the hotseat battle.
func _finish_team() -> void:
	if _picking_side == Battle.Side.PLAYER:
		_first_team = _team.duplicate()
		_team.clear()
		_picking_side = Battle.Side.ENEMY
		_picker.visible = false
		_cover.visible = true
		return
	TestMap.player_one_team = _first_team
	TestMap.player_two_team = _team
	TestMap.play_mode = TestBattleSetup.PlayMode.HOTSEAT
	TestMap.replay_seed_requested = false
	get_tree().change_scene_to_file(TEST_MAP_SCENE)


func _start_second_pick() -> void:
	_cover.visible = false
	_picker.visible = true
	_refresh()


func _player_name(side: int) -> String:
	return TestMap.SIDE_LABELS_BY_MODE[TestBattleSetup.PlayMode.HOTSEAT][side]
