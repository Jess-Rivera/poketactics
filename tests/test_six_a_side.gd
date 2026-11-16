extends GdUnitTestSuite
## Issue #16 relations (docs/discussion-outputs/six-a-side-opening.md): 6 player units against an enemy count set
## by encounter kind and seed, on distinct start cells, and every unit's portrait found through the packed index.
## Relation 6 (packing twice gives identical files) is checked by tools/pack_portraits.py --check in
## tools/run-tests.cmd.

const SEEDS_TRIED := 200
const KINDS: Array[TestBattleSetup.EncounterKind] = [
	TestBattleSetup.EncounterKind.WILD,
	TestBattleSetup.EncounterKind.TRAINER,
	TestBattleSetup.EncounterKind.BOSS,
]

var pack: PackData


func before() -> void:
	pack = PackData.shared()


## Relation 1: the player always has 6 units; the enemy count is inside the encounter kind's range.
func test_six_players_and_enemy_count_in_range() -> void:
	for kind in KINDS:
		var count_range: Vector2i = TestBattleSetup.ENEMY_COUNT_RANGES[kind]
		for battle_seed in [0, 1, 7, 42, 9001]:
			var battle := TestBattleSetup.build(pack, kind, battle_seed)
			assert_int(battle.units_on_side(Battle.Side.PLAYER).size()).is_equal(6)
			var enemy_count := battle.units_on_side(Battle.Side.ENEMY).size()
			assert_int(enemy_count).is_between(count_range.x, count_range.y)


## Relation 2: the same seed gives the same roster; every count in a range comes up for some seed; a roster
## never repeats a unit and only uses the enemy pool.
func test_seeded_rosters_are_repeatable_and_cover_the_range() -> void:
	for kind in KINDS:
		var count_range: Vector2i = TestBattleSetup.ENEMY_COUNT_RANGES[kind]
		var counts_seen := {}
		for battle_seed in SEEDS_TRIED:
			var roster := TestBattleSetup.enemy_roster(kind, battle_seed)
			assert_array(TestBattleSetup.enemy_roster(kind, battle_seed)).is_equal(roster)
			counts_seen[roster.size()] = true
			var distinct := {}
			for unit_name in roster:
				assert_bool(TestBattleSetup.ENEMY_POOL.has(unit_name)).is_true()
				distinct[unit_name] = true
			assert_int(distinct.size()).is_equal(roster.size())
		for count in range(count_range.x, count_range.y + 1):
			assert_bool(counts_seen.has(count)).override_failure_message(
				"%s never fields %d enemies" % [TestBattleSetup.ENCOUNTER_NAMES[kind], count]
			).is_true()


## Relation 3: no two units share a start cell, and every start cell is inside the map.
func test_start_cells_are_distinct_and_inside_the_map() -> void:
	for kind in KINDS:
		for battle_seed in [3, 5, 8]:
			var battle := TestBattleSetup.build(pack, kind, battle_seed)
			var used_cells := {}
			for unit in battle.units:
				assert_bool(battle.grid.contains(unit.cell)).is_true()
				assert_bool(used_cells.has(unit.cell)).override_failure_message(
					"%s shares %s" % [unit.unit_name, unit.cell]
				).is_false()
				used_cells[unit.cell] = true


## Relation 4: every unit and transformation in the pack resolves to a portrait set in the index (its own cell,
## or a fallback the index names).
func test_every_unit_and_transformation_has_a_portrait_entry() -> void:
	var sets: Dictionary = PortraitLoader.index()["sets"]
	var failures: Array[String] = []
	for unit_name in pack.units:
		var unit: Dictionary = pack.units[unit_name]
		var dex := int(unit["dex_number"])
		var entries := [[unit_name, unit]]
		for transformation in unit["transformations"]:
			entries.append([transformation["name"], transformation])
		for named_entry in entries:
			var set_id := PortraitLoader.set_id_for(named_entry[1], dex)
			if not sets.has(set_id):
				failures.append("%s: %s is not in the portrait index" % [named_entry[0], set_id])
			elif PortraitLoader.resolve(set_id)["cell"] < 0:
				failures.append("%s: %s resolves to no cell" % [named_entry[0], set_id])
	assert_array(failures).is_empty()


## Relation 5: every sheet is the same size and every indexed cell lies inside it; a shiny set with its own
## portrait resolves to the shiny sheets, never the normal ones.
func test_cells_fit_every_sheet_and_shinies_stay_shiny() -> void:
	var index := PortraitLoader.index()
	var cell_size := int(index["cell_size"])
	var sheet_size := Vector2i(int(index["columns"]), int(index["rows"])) * cell_size
	for colour in index["sheets"]:
		for emotion in index["sheets"][colour]:
			var sheet: Texture2D = load("%s/%s" % [PortraitLoader.PACKED_FOLDER, index["sheets"][colour][emotion]])
			assert_object(sheet).is_not_null()
			assert_bool(Vector2i(sheet.get_size()) == sheet_size).is_true()
	var whole_sheet := Rect2i(Vector2i.ZERO, sheet_size)
	var failures: Array[String] = []
	for set_id in index["sets"]:
		var entry: Dictionary = index["sets"][set_id]
		if not entry.has("cell"):
			continue
		if not whole_sheet.encloses(PortraitLoader.cell_rect(int(entry["cell"]))):
			failures.append("%s: cell %d is outside the sheets" % [set_id, entry["cell"]])
		var is_shiny_set: bool = set_id.ends_with("-" + PortraitLoader.SHINY_FOLDER) and set_id.count("-") == 2
		if is_shiny_set and PortraitLoader.resolve(set_id)["colour"] != PortraitLoader.SHINY_COLOUR:
			failures.append("%s has its own portrait but resolves to a normal sheet" % set_id)
	assert_array(failures).is_empty()


## Relation 7: with the full 12 units of a boss battle, every turn bar entry sits inside the screen.
func test_turn_bar_fits_with_twelve_units() -> void:
	var battle := TestBattleSetup.build(pack, TestBattleSetup.EncounterKind.BOSS, 11)
	assert_int(battle.units.size()).is_equal(12)
	var random := RandomNumberGenerator.new()
	random.seed = 11
	var turn_order := TurnOrder.new(battle, random)
	var slot_rounds := []
	for slot in turn_order.forecast(TurnBar.ENTRY_COUNT):
		slot_rounds.append(slot.round_number)
	var screen := Rect2(Vector2.ZERO, TurnBar.SCREEN_SIZE)
	for rect in TurnBar.entry_rects(slot_rounds):
		assert_bool(screen.encloses(rect)).is_true()
