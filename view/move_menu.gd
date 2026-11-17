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
		var move_name := unit.move_names[move_index]
		var row_text := _row_text(move_index, pack.move(move_name), MoveRecipe.built(pack, unit, move_name))
		var row := _row(row_text, move_index == picked_index, can_act)
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


## One menu row from the built recipe (what the move does for this unit) and the pack entry (its name).
func _row_text(move_index: int, move: Dictionary, recipe: Dictionary) -> String:
	var shape: Dictionary = recipe["shape"]
	var reach := "self"
	if not MoveRecipe.is_on_user_tile(recipe):
		reach = "%d-%d" % [shape["range_min"], shape["range_max"]]
	var power_value = MoveRecipe.damage_component(recipe).get("power")
	var power: String = str(power_value) if power_value != null else "-"
	return "%d  %s  %s  %s  %s  %d SR" % [
		move_index + 1, move["english_name"], String(recipe["type"]).capitalize(), power, reach, recipe["sr_cost"]
	]
