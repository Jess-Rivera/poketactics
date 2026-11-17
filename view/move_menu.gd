class_name MoveMenu
extends CanvasLayer
## The active unit's moves, bottom left (issue #10, docs/discussion-outputs/use-a-move-opening.md): one row per
## move with its key, name, type, power and range. Keys 1 to 4 or a click pick a move; the picked row is marked.
## Greyed out once the unit has acted this turn. Clicks are announced by signal; the keys are read by the map.
## Since #13 each row shows the move's SR cost, and a last row offers Wait (Space).

signal move_clicked(move_index: int)
signal wait_clicked

const SCREEN_HEIGHT := 360.0
const LEFT_MARGIN := 8.0
const BOTTOM_MARGIN := 10.0
const ROW_GAP := 1
const PANEL_COLOUR := Color(0.0, 0.0, 0.0, 0.7)
const PICKED_COLOUR := Color(1.0, 0.85, 0.3)
const ROW_COLOUR := Color(1.0, 1.0, 1.0)
const SPENT_COLOUR := Color(1.0, 1.0, 1.0, 0.4)

var _background: PanelContainer
var _rows: VBoxContainer


func _ready() -> void:
	_background = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_COLOUR
	style.set_content_margin_all(4)
	_background.add_theme_stylebox_override("panel", style)
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", ROW_GAP)
	_background.add_child(_rows)
	add_child(_background)


## Lists a unit's moves. picked_index marks the move being aimed (-1 for none); can_act false greys every row.
func show_moves(unit: BattleUnit, pack: PackData, picked_index: int, can_act: bool) -> void:
	for row in _rows.get_children():
		_rows.remove_child(row)
		row.queue_free()
	_background.visible = unit != null
	if unit == null:
		return
	for move_index in unit.move_names.size():
		var row := _row(_row_text(move_index, pack.move(unit.move_names[move_index])), move_index == picked_index, can_act)
		row.pressed.connect(func() -> void: move_clicked.emit(move_index))
		_rows.add_child(row)
	var wait_row := _row("Space  Wait", false, can_act)
	wait_row.pressed.connect(func() -> void: wait_clicked.emit())
	_rows.add_child(wait_row)
	# Shrink to the new rows, then sit on the bottom margin.
	_background.reset_size()
	var panel_height := _background.get_combined_minimum_size().y
	_background.position = Vector2(LEFT_MARGIN, SCREEN_HEIGHT - BOTTOM_MARGIN - panel_height)


func _row(text: String, is_picked: bool, can_act: bool) -> Button:
	var row := Button.new()
	row.text = text
	row.flat = true
	row.focus_mode = Control.FOCUS_NONE
	row.alignment = HORIZONTAL_ALIGNMENT_LEFT
	row.disabled = not can_act
	row.add_theme_font_size_override("font_size", UnitPanel.FONT_SIZE)
	row.add_theme_color_override("font_color", PICKED_COLOUR if is_picked else ROW_COLOUR)
	row.add_theme_color_override("font_disabled_color", SPENT_COLOUR)
	return row


func _row_text(move_index: int, move: Dictionary) -> String:
	var grid_entry: Dictionary = move["grid"]
	var reach := "self"
	if grid_entry["target"] != MoveArea.TARGET_SELF:
		reach = "%d-%d" % [grid_entry["range_min"], grid_entry["range_max"]]
	var power: String = str(move["power"]) if move["power"] != null else "-"
	return "%d  %s  %s  %s  %s  %d SR" % [
		move_index + 1, move["english_name"], String(move["type"]).capitalize(), power, reach, grid_entry["sr_cost"]
	]
