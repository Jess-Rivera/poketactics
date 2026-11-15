class_name BattleUnit
extends RefCounted
## A unit as rules see it: where it stands and which way it faces. No nodes and no drawing.

var cell: Vector2i
var facing: Facing.Direction


func _init(start_cell: Vector2i = Vector2i.ZERO, start_facing: Facing.Direction = Facing.Direction.SOUTH) -> void:
	cell = start_cell
	facing = start_facing
