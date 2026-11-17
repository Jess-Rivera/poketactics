class_name EndScreen
extends CanvasLayer
## The battle's end (issue #12, docs/discussion-outputs/win-lose-opening.md, ruling 2026-11-17-battle-end-m1): a
## centred panel with the result title from the map (Victory or Defeat, or Player N wins in hotseat, #15), the rounds
## played, the units standing per side, and three buttons. Hidden until show_result; the buttons are announced by
## signal and the map acts on them.

signal same_battle_pressed
signal new_battle_pressed
signal menu_pressed

## Above the map's other panels.
const SCREEN_LAYER := 2
const PANEL_COLOUR := Color(0.0, 0.0, 0.0, 0.8)
const PANEL_PADDING := 10
const ROW_GAP := 4
const TITLE_FONT_SIZE := 20
const WIN_COLOUR := Color(1.0, 0.85, 0.3)
const LOSS_COLOUR := Color(0.85, 0.35, 0.35)

var _title: Label
var _summary: Label


func _ready() -> void:
	layer = SCREEN_LAYER
	visible = false
	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(centre)
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_COLOUR
	style.set_content_margin_all(PANEL_PADDING)
	panel.add_theme_stylebox_override("panel", style)
	centre.add_child(panel)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", ROW_GAP)
	panel.add_child(rows)
	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", TITLE_FONT_SIZE)
	rows.add_child(_title)
	_summary = Label.new()
	_summary.add_theme_font_size_override("font_size", UnitPanel.FONT_SIZE)
	rows.add_child(_summary)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", ROW_GAP)
	rows.add_child(buttons)
	buttons.add_child(_button("Same battle", same_battle_pressed.emit))
	buttons.add_child(_button("New battle", new_battle_pressed.emit))
	buttons.add_child(_button("Menu", menu_pressed.emit))


## Shows the result of a battle that is over, after round_number rounds. is_win colours the title as a win (always
## in hotseat, where someone won); side_labels names each side in the summary.
func show_result(title: String, is_win: bool, battle: Battle, round_number: int, side_labels: Dictionary) -> void:
	_title.text = title
	_title.add_theme_color_override("font_color", WIN_COLOUR if is_win else LOSS_COLOUR)
	var lines: Array[String] = ["Rounds played: %d" % round_number]
	for unit_side in Battle.Side.values():
		lines.append("%s: %d of %d standing" % [
			side_labels[unit_side], battle.standing_count(unit_side), battle.units_on_side(unit_side).size()
		])
	_summary.text = "\n".join(lines)
	visible = true


func _button(text: String, on_pressed: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.add_theme_font_size_override("font_size", UnitPanel.FONT_SIZE)
	button.pressed.connect(on_pressed)
	return button
