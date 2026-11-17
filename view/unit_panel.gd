class_name UnitPanel
extends CanvasLayer
## Temporary text panel listing every unit in the battle: side, name, level, HP and moves. Tab shows or hides it.
## For checking unit builds by eye; call refresh() after hit points change (#10) and after each turn (#13: size
## band, base SR and the round and SR of the unit's next turn).

const PANEL_MARGIN := 8
const PANEL_COLOUR := Color(0.0, 0.0, 0.0, 0.7)
const FONT_SIZE := 10

var _background: PanelContainer
var _label: Label
var _battle: Battle
var _pack: PackData
## A name per side (a Battle.Side value to text), from the map: "You" and "Foe", or "Player 1" and "Player 2".
var _side_labels: Dictionary
var _turn_order: TurnOrder


func show_battle(battle: Battle, pack: PackData, side_labels: Dictionary, turn_order: TurnOrder) -> void:
	_battle = battle
	_pack = pack
	_turn_order = turn_order
	_side_labels = side_labels
	_background = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_COLOUR
	style.set_content_margin_all(6)
	_background.add_theme_stylebox_override("panel", style)
	_background.position = Vector2(PANEL_MARGIN, PANEL_MARGIN * 3)
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", FONT_SIZE)
	_background.add_child(_label)
	# Starts hidden: at 640x360 it covers half the map.
	_background.visible = false
	add_child(_background)
	refresh()


## Rewrites every unit's line, for example after a move changed hit points.
func refresh() -> void:
	var lines: Array[String] = []
	for unit in _battle.units:
		var move_names: Array[String] = []
		for move_name in unit.move_names:
			move_names.append(_pack.move(move_name)["english_name"])
		var next_turn := _turn_order.next_turn_of(unit)
		lines.append("%s  %s  Lv %d  HP %d/%d  Size %d  Base SR %d  Next R%d SR %d  %s" % [
			_side_labels[unit.side],
			_pack.unit(unit.unit_name)["english_name"],
			unit.level,
			unit.hit_points,
			unit.max_hit_points,
			unit.size_band,
			unit.base_strike_rank,
			TurnOrder.round_of(next_turn),
			TurnOrder.strike_rank_in_round(next_turn),
			", ".join(move_names),
		])
	_label.text = "\n".join(lines)


func _unhandled_input(event: InputEvent) -> void:
	var key_event := event as InputEventKey
	if key_event != null and key_event.pressed and not key_event.echo and key_event.keycode == KEY_TAB:
		_background.visible = not _background.visible
		get_viewport().set_input_as_handled()
