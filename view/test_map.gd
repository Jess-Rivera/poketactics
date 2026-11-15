extends Node3D
## Greybox test battle for issue #6: the 20 by 20 map and 8 pack units from rules/test_battle_setup.gd, each drawn
## with its own sprite set. Q and E rotate, WASD or the arrow keys pan, Tab shows the unit panel.

const BACKGROUND_COLOUR := Color(0.11, 0.12, 0.15)
const IDLE_ANIMATION := "Idle"


func _ready() -> void:
	RenderingServer.set_default_clear_color(BACKGROUND_COLOUR)
	var pack := PackData.shared()
	var battle := TestBattleSetup.build(pack)

	var battle_map := BattleMap.new()
	battle_map.name = "BattleMap"
	add_child(battle_map)
	battle_map.build(battle.grid)

	var camera_rig := CameraRig.new()
	camera_rig.name = "CameraRig"
	camera_rig.position = battle_map.map_center()
	camera_rig.map_bounds = Rect2(0, 0, battle.grid.width * BattleMap.CELL_SIZE, battle.grid.depth * BattleMap.CELL_SIZE)
	add_child(camera_rig)

	for unit in battle.units:
		var sprite_set = pack.unit(unit.unit_name)["sprite_set"]
		if sprite_set == null:
			push_warning("%s has no sprite set; not drawn" % unit.unit_name)
			continue
		var unit_sprite := UnitSprite.new()
		unit_sprite.name = unit.unit_name
		add_child(unit_sprite)
		unit_sprite.show_unit(unit, sprite_set, IDLE_ANIMATION, battle_map.top_center(unit.cell))
		camera_rig.view_step_changed.connect(unit_sprite.set_view_step)

	var unit_panel := UnitPanel.new()
	unit_panel.name = "UnitPanel"
	add_child(unit_panel)
	unit_panel.show_battle(battle, pack)

	var hint_layer := CanvasLayer.new()
	var hint := Label.new()
	hint.text = "Q / E: rotate   WASD / arrows: pan   Tab: units"
	hint.add_theme_font_size_override("font_size", UnitPanel.FONT_SIZE)
	hint.position = Vector2(8, 4)
	hint_layer.add_child(hint)
	add_child(hint_layer)
