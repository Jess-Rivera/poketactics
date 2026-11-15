class_name BattleUnit
extends RefCounted
## A unit as rules see it: where it stands, which way it faces, and (when built from the data pack) its level,
## battle stats, hit points, types, abilities and the moves it knows. No nodes and no drawing.

var cell: Vector2i
var facing: Facing.Direction
## The pack unit it was built from (pokeapi name, for example vulpix-alola); empty for a bare unit.
var unit_name: String
var level: int
var stats: Dictionary
var max_hit_points: int
var hit_points: int
var types: Array[String] = []
var abilities: Array[String] = []
var move_names: Array[String] = []


func _init(start_cell: Vector2i = Vector2i.ZERO, start_facing: Facing.Direction = Facing.Direction.SOUTH) -> void:
	cell = start_cell
	facing = start_facing


## A battle-ready unit from a pack unit at a level: stats by the mainline formula, full HP, and the 4 most
## recently learned level-up moves (docs/decisions/2026-11-15-unit-stats-and-moves.md).
static func from_pack(
	pack: PackData,
	pack_unit_name: String,
	unit_level: int,
	start_cell: Vector2i = Vector2i.ZERO,
	start_facing: Facing.Direction = Facing.Direction.SOUTH
) -> BattleUnit:
	var pack_unit := pack.unit(pack_unit_name)
	var unit := BattleUnit.new(start_cell, start_facing)
	if pack_unit.is_empty():
		return unit
	unit.unit_name = pack_unit_name
	unit.level = unit_level
	unit.stats = BattleStats.battle_stats(pack_unit["base_stats"], unit_level)
	unit.max_hit_points = unit.stats["hp"]
	unit.hit_points = unit.max_hit_points
	for type_name in pack_unit["types"]:
		unit.types.append(type_name)
	for ability_entry in pack_unit["abilities"]:
		unit.abilities.append(ability_entry["ability"])
	unit.move_names = BattleStats.moves_known_at(pack_unit["learnset"]["moves"], unit_level)
	return unit
