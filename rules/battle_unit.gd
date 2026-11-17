class_name BattleUnit
extends RefCounted
## A unit as rules see it: where it stands, which way it faces, and (when built from the data pack) its level,
## battle stats, hit points, types, abilities and the moves it knows. No nodes and no drawing.

var cell: Vector2i
var facing: Facing.Direction
## Which side the unit fights for (a Battle.Side value); set when it joins a battle.
var side: int = 0
## The pack unit it was built from (pokeapi name, for example vulpix-alola); empty for a bare unit.
var unit_name: String
var level: int
var stats: Dictionary
var max_hit_points: int
var hit_points: int
var types: Array[String] = []
var abilities: Array[String] = []
var move_names: Array[String] = []
## Size band from the pack (0 smallest to 4) and the SR added after each turn (2026-11-17-size-bands); a bare unit
## sits in the middle band.
var size_band := BattleStats.MIDDLE_SIZE_BAND
var base_strike_rank := BattleStats.MIDDLE_SIZE_BAND


func _init(start_cell: Vector2i = Vector2i.ZERO, start_facing: Facing.Direction = Facing.Direction.SOUTH) -> void:
	cell = start_cell
	facing = start_facing


## A fainted unit has no hit points left; it no longer takes turns.
func has_fainted() -> bool:
	return hit_points <= 0


## Loses hit points, never below 0.
func take_damage(amount: int) -> void:
	hit_points = maxi(hit_points - amount, 0)


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
	unit.size_band = int(pack_unit["size_band"])
	unit.base_strike_rank = BattleStats.base_strike_rank(unit.size_band, unit.stats["speed"], unit_level)
	unit.hit_points = unit.max_hit_points
	for type_name in pack_unit["types"]:
		unit.types.append(type_name)
	for ability_entry in pack_unit["abilities"]:
		unit.abilities.append(ability_entry["ability"])
	unit.move_names = BattleStats.moves_known_at(pack_unit["learnset"]["moves"], unit_level)
	return unit
