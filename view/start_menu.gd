class_name StartMenu
extends Control
## The first screen (#15, docs/discussion-outputs/hotseat-opening.md, ruling 2026-11-17-hotseat-m1b): battle the
## AI on the test map, or pick teams for a hotseat battle.

const TITLE_TEXT := "PokeTactics"
const TEST_MAP_SCENE := "res://view/test_map.tscn"
const TEAM_PICK_SCENE := "res://view/team_pick.tscn"
const ROW_GAP := 8


func _ready() -> void:
	RenderingServer.set_default_clear_color(TestMap.BACKGROUND_COLOUR)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(centre)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", ROW_GAP)
	centre.add_child(rows)
	var title := Label.new()
	title.text = TITLE_TEXT
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", EndScreen.TITLE_FONT_SIZE)
	rows.add_child(title)
	rows.add_child(_button("Battle the AI", _battle_the_ai))
	rows.add_child(_button("Hotseat versus", _hotseat_versus))


func _battle_the_ai() -> void:
	TestMap.play_mode = TestBattleSetup.PlayMode.AI_BATTLE
	TestMap.replay_seed_requested = false
	get_tree().change_scene_to_file(TEST_MAP_SCENE)


func _hotseat_versus() -> void:
	get_tree().change_scene_to_file(TEAM_PICK_SCENE)


func _button(text: String, on_pressed: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.add_theme_font_size_override("font_size", UnitPanel.FONT_SIZE)
	button.pressed.connect(on_pressed)
	return button
