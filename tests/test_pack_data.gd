extends GdUnitTestSuite
## Issue #5 relations 1, 9 and 10 (docs/discussion-outputs/pack-loader-plan.md): the pack loads by name, and a
## unit built from it carries its pack facts and the moves the mainline wild rule gives it.

const LEVELS_CHECKED := [1, 5, 10, 25, 30, 50, 75, 100]

var pack: PackData


func before() -> void:
	pack = PackData.shared()


## Relation 1: every unit, move, ability and type loads, and a name not in the pack fails loudly.
func test_every_pack_entry_loads_by_name() -> void:
	var failures: Array[String] = []
	for table_and_lookup in [[pack.units, pack.unit], [pack.moves, pack.move], [pack.abilities, pack.ability], [pack.types, pack.type_entry]]:
		var table: Dictionary = table_and_lookup[0]
		var look_up: Callable = table_and_lookup[1]
		if table.is_empty():
			failures.append("a pack table is empty")
		for entry_name in table:
			if look_up.call(entry_name).is_empty():
				failures.append("%s did not load" % entry_name)
	assert_array(failures).is_empty()


func test_a_name_not_in_the_pack_fails_loudly() -> void:
	await assert_error(func(): pack.unit("not-a-unit")).is_push_error("data pack has no unit named 'not-a-unit'")
	await assert_error(func(): pack.move("not-a-move")).is_push_error("data pack has no move named 'not-a-move'")


func test_the_pack_is_loaded_once() -> void:
	assert_object(PackData.shared()).is_same(pack)


## Relation 9: at most 4 moves, each a level-up move at or below the level, and none learned later is left out.
func test_built_units_know_their_latest_level_up_moves() -> void:
	var failures: Array[String] = []
	for unit_name in pack.units:
		var learnset_moves: Array = pack.units[unit_name]["learnset"]["moves"]
		for level in LEVELS_CHECKED:
			var known := BattleStats.moves_known_at(learnset_moves, level)
			var latest_level_of := _latest_level_up_levels(learnset_moves, level)
			var where := "%s at level %d" % [unit_name, level]
			if known.size() > BattleStats.MOVES_KNOWN:
				failures.append("%s knows %d moves" % [where, known.size()])
			if known.size() != mini(BattleStats.MOVES_KNOWN, latest_level_of.size()):
				failures.append("%s knows %d of %d learnable moves" % [where, known.size(), latest_level_of.size()])
			var lowest_known_level := 1000
			for move_name in known:
				if not latest_level_of.has(move_name):
					failures.append("%s knows %s, not a level-up move at or below its level" % [where, move_name])
					continue
				lowest_known_level = mini(lowest_known_level, latest_level_of[move_name])
			for move_name in latest_level_of:
				if not move_name in known and latest_level_of[move_name] > lowest_known_level:
					failures.append("%s misses %s, learned later than a move it knows" % [where, move_name])
	assert_array(failures).is_empty()


## Relation 10: a built unit starts at full HP with its pack unit's types and abilities.
func test_built_units_start_full_with_their_pack_types_and_abilities() -> void:
	var failures: Array[String] = []
	for unit_name in pack.units:
		var pack_unit: Dictionary = pack.units[unit_name]
		var unit := BattleUnit.from_pack(pack, unit_name, 50)
		var pack_abilities := []
		for ability_entry in pack_unit["abilities"]:
			pack_abilities.append(ability_entry["ability"])
		if unit.hit_points != unit.max_hit_points or unit.max_hit_points <= 0:
			failures.append("%s starts at %d of %d HP" % [unit_name, unit.hit_points, unit.max_hit_points])
		if Array(unit.types) != pack_unit["types"]:
			failures.append("%s has types %s, pack says %s" % [unit_name, unit.types, pack_unit["types"]])
		if Array(unit.abilities) != pack_abilities:
			failures.append("%s has abilities %s, pack says %s" % [unit_name, unit.abilities, pack_abilities])
		if unit.unit_name != unit_name or unit.level != 50:
			failures.append("%s was built as %s at level %d" % [unit_name, unit.unit_name, unit.level])
	assert_array(failures).is_empty()


func _latest_level_up_levels(learnset_moves: Array, level: int) -> Dictionary:
	var latest_level_of := {}
	for entry in learnset_moves:
		if entry["method"] == "level-up" and int(entry["level"]) <= level:
			latest_level_of[entry["move"]] = maxi(int(entry["level"]), int(latest_level_of.get(entry["move"], 0)))
	return latest_level_of
