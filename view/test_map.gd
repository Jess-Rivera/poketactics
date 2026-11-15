extends Node3D
## Greybox test map for issue #1: an 8 by 8 grid with height steps, Charmander idling on it, Q and E rotate the view.

const HEIGHT_ROWS := [
	"00001233",
	"00001233",
	"00000122",
	"00000011",
	"00000000",
	"11000000",
	"21100000",
	"32100000",
]
const UNIT_CELL := Vector2i(3, 3)
const UNIT_SPRITE_SET := "0004"
const BACKGROUND_COLOUR := Color(0.11, 0.12, 0.15)


func _ready() -> void:
	RenderingServer.set_default_clear_color(BACKGROUND_COLOUR)
	var grid := BattleGrid.from_rows(PackedStringArray(HEIGHT_ROWS))

	var battle_map := BattleMap.new()
	battle_map.name = "BattleMap"
	add_child(battle_map)
	battle_map.build(grid)

	var camera_rig := CameraRig.new()
	camera_rig.name = "CameraRig"
	camera_rig.position = battle_map.map_center()
	add_child(camera_rig)

	var unit := BattleUnit.new(UNIT_CELL, Facing.Direction.SOUTH)
	var unit_sprite := UnitSprite.new()
	unit_sprite.name = "Charmander"
	add_child(unit_sprite)
	unit_sprite.show_unit(unit, UNIT_SPRITE_SET, "Idle", battle_map.top_center(UNIT_CELL))
	camera_rig.view_step_changed.connect(unit_sprite.set_view_step)

	var hint_layer := CanvasLayer.new()
	var hint := Label.new()
	hint.text = "Q / E: rotate view"
	hint.position = Vector2(8, 4)
	hint_layer.add_child(hint)
	add_child(hint_layer)
