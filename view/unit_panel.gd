class_name UnitPanel
extends CanvasLayer
## Temporary text panel listing every unit in the battle: side, name, level, HP and moves. Tab shows or hides it.
## For checking unit builds by eye until selection (#7) and HP bars (#10) arrive.

const SIDE_LABELS := {Battle.Side.PLAYER: "You", Battle.Side.ENEMY: "Foe"}
const PANEL_MARGIN := 8
const PANEL_COLOUR := Color(0.0, 0.0, 0.0, 0.7)
const FONT_SIZE := 10

var _background: PanelContainer


func show_battle(battle: Battle, pack: PackData) -> void:
	_background = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_COLOUR
	style.set_content_margin_all(6)
	_background.add_theme_stylebox_override("panel", style)
	_background.position = Vector2(PANEL_MARGIN, PANEL_MARGIN * 3)
	var label := Label.new()
	label.add_theme_font_size_override("font_size", FONT_SIZE)
	var lines: Array[String] = []
	for unit in battle.units:
		var move_names: Array[String] = []
		for move_name in unit.move_names:
			move_names.append(pack.move(move_name)["english_name"])
		lines.append("%s  %s  Lv %d  HP %d/%d  %s" % [
			SIDE_LABELS[unit.side],
			pack.unit(unit.unit_name)["english_name"],
			unit.level,
			unit.hit_points,
			unit.max_hit_points,
			", ".join(move_names),
		])
	label.text = "\n".join(lines)
	_background.add_child(label)
	# Starts hidden: at 640x360 it covers half the map.
	_background.visible = false
	add_child(_background)


func _unhandled_input(event: InputEvent) -> void:
	var key_event := event as InputEventKey
	if key_event != null and key_event.pressed and not key_event.echo and key_event.keycode == KEY_TAB:
		_background.visible = not _background.visible
		get_viewport().set_input_as_handled()
