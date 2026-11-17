extends GdUnitTestSuite
## Issue #13 end-goal test (docs/discussion-outputs/strike-rank-plan.md; rulings 2026-11-16-strike-rank-clock,
## 2026-11-17-size-bands, 2026-11-17-wait-action, 2026-11-17-elevation-cost). Relations only, plus Jess's own worked
## walk rows from the elevation ruling.

const FLAT_ROWS := ["00000000", "00000000", "00000000", "00000000", "00000000", "00000000", "00000000", "00000000"]
## The band shares the ruling asks for, smallest first, in percent; each may be off by this much from rounding.
const BAND_SHARES_PERCENT := [10, 20, 40, 20, 10]
const SHARE_TOLERANCE_PERCENT := 1.0
## Every this-many default species are compared pairwise for the size order relation (a sample keeps it quick).
const SIZE_SAMPLE_STEP := 5
const LEVELS_TO_TRY := [5, 30, 100]
const HIGHEST_SPEED_TO_TRY := 400
const AI_TURNS := 150
const BATTLE_SEED := 21

var pack: PackData


func before() -> void:
	pack = PackData.shared()


func _flat_battle(rows: Array = FLAT_ROWS) -> Battle:
	return Battle.new(BattleGrid.from_rows(PackedStringArray(rows)))


func _add(battle: Battle, cell: Vector2i, side: int, speed: int, base_strike_rank: int) -> BattleUnit:
	var unit := BattleUnit.new(cell)
	unit.stats = {"speed": speed}
	unit.max_hit_points = 10
	unit.hit_points = 10
	unit.base_strike_rank = base_strike_rank
	battle.add_unit(unit, side)
	return unit


func _seeded(battle_seed: int) -> RandomNumberGenerator:
	var random := RandomNumberGenerator.new()
	random.seed = battle_seed
	return random


func _path(cells: Array) -> Array[Vector2i]:
	var path: Array[Vector2i] = []
	path.assign(cells)
	return path


## A straight walk east along row 0 from column 0 to column last_column.
func _east_path(last_column: int) -> Array[Vector2i]:
	var path: Array[Vector2i] = []
	for column in range(1, last_column + 1):
		path.append(Vector2i(column, 0))
	return path


## Relation 1: a cheaper action brings the next turn sooner (a shorter walk, a shorter Wait).
func test_a_cheaper_action_brings_the_next_turn_sooner() -> void:
	var next_turns := []
	for walk_length in [2, 6]:
		var battle := _flat_battle()
		var unit := _add(battle, Vector2i(0, 0), Battle.Side.PLAYER, 50, 2)
		var turn_order := TurnOrder.new(battle, _seeded(1))
		turn_order.move_unit(unit, _east_path(walk_length), Facing.Direction.EAST)
		turn_order.end_turn(Facing.Direction.EAST)
		next_turns.append(turn_order.next_turn_of(unit))
	assert_int(next_turns[0]).is_less(next_turns[1])
	var waited_turns := []
	for wait in [1, 3]:
		var battle := _flat_battle()
		var unit := _add(battle, Vector2i(0, 0), Battle.Side.PLAYER, 50, 2)
		var turn_order := TurnOrder.new(battle, _seeded(1))
		turn_order.wait(unit, wait)
		turn_order.end_turn(Facing.Direction.EAST)
		waited_turns.append(turn_order.next_turn_of(unit))
	assert_int(waited_turns[0]).is_less(waited_turns[1])


## Relation 2: a species at least as tall and at least as heavy as another never has a smaller size band.
func test_a_bigger_species_never_has_a_smaller_band() -> void:
	var sample := []
	var index := 0
	for unit_name in pack.units:
		var entry: Dictionary = pack.units[unit_name]
		if entry["is_species_default"] and index % SIZE_SAMPLE_STEP == 0:
			sample.append(entry)
		if entry["is_species_default"]:
			index += 1
	var failures: Array[String] = []
	for bigger in sample:
		for smaller in sample:
			var is_bigger: bool = bigger["height_decimetres"] >= smaller["height_decimetres"] \
				and bigger["weight_hectograms"] >= smaller["weight_hectograms"]
			if is_bigger and int(bigger["size_band"]) < int(smaller["size_band"]):
				failures.append("%s band %d < %s band %d" % [
					bigger["species"], bigger["size_band"], smaller["species"], smaller["size_band"]
				])
	assert_array(failures).is_empty()


## Relation 3: the default species split into the ruled band shares, within rounding.
func test_band_shares_match_the_ruling() -> void:
	var counts := [0, 0, 0, 0, 0]
	var total := 0
	for unit_name in pack.units:
		var entry: Dictionary = pack.units[unit_name]
		if not entry["is_species_default"]:
			continue
		counts[int(entry["size_band"])] += 1
		total += 1
	for band in counts.size():
		var share: float = 100.0 * counts[band] / total
		assert_float(share).is_between(
			BAND_SHARES_PERCENT[band] - SHARE_TOLERANCE_PERCENT, BAND_SHARES_PERCENT[band] + SHARE_TOLERANCE_PERCENT
		)


## Relation 4: higher Speed never gives a higher base SR; the nudge is at most 1 band and stays in 0 to 4.
func test_higher_speed_never_gives_a_later_turn() -> void:
	for level in LEVELS_TO_TRY:
		for band in range(BattleStats.SMALLEST_SIZE_BAND, BattleStats.LARGEST_SIZE_BAND + 1):
			var previous := BattleStats.base_strike_rank(band, 1, level)
			for speed in range(1, HIGHEST_SPEED_TO_TRY + 1):
				var base := BattleStats.base_strike_rank(band, speed, level)
				assert_int(base).is_less_equal(previous)
				assert_int(absi(base - band)).is_less_equal(1)
				assert_int(base).is_between(BattleStats.SMALLEST_SIZE_BAND, BattleStats.LARGEST_SIZE_BAND)
				previous = base


## Relation 5: a Wait of w lands exactly w later, and on that SR goes before a faster unit that did not wait.
func test_a_wait_lands_exactly_and_goes_first() -> void:
	var battle := _flat_battle()
	var waiter := _add(battle, Vector2i(0, 0), Battle.Side.PLAYER, 10, 2)
	var walker := _add(battle, Vector2i(0, 4), Battle.Side.ENEMY, 90, 2)
	var turn_order := TurnOrder.new(battle, _seeded(3))
	# Both start on the same SR; the faster walker goes first and walks 2 tiles (1 SR), landing 1 + base later.
	assert_object(turn_order.active_unit()).is_same(walker)
	var walk_landing := turn_order.next_turn_of(walker) + 1 + walker.base_strike_rank
	turn_order.move_unit(walker, _path([Vector2i(1, 4), Vector2i(2, 4)]), Facing.Direction.EAST)
	turn_order.end_turn(Facing.Direction.EAST)
	assert_object(turn_order.active_unit()).is_same(waiter)
	var wait := walk_landing - turn_order.next_turn_of(waiter)
	var wait_landing := turn_order.next_turn_of(waiter) + wait
	turn_order.wait(waiter, wait)
	turn_order.end_turn(Facing.Direction.SOUTH)
	assert_int(turn_order.next_turn_of(waiter)).is_equal(wait_landing)
	assert_int(turn_order.next_turn_of(walker)).is_equal(wait_landing)
	assert_object(turn_order.active_unit()).is_same(waiter)


## Relations 6 and 10, and the slice's "AI plays full battles": on the real test battle driven by TurnAi, every
## turn takes one action, lands strictly later than now, the clock never goes back, the round is always the
## clock's round, and the same seed plays the same turns.
func test_ai_turns_always_land_later_and_replay() -> void:
	var first := _ai_turn_record(BATTLE_SEED)
	var second := _ai_turn_record(BATTLE_SEED)
	assert_array(second).is_equal(first)


## [unit index, clock] of each turn of an AI-against-AI test battle, checking relation 6 along the way.
func _ai_turn_record(battle_seed: int) -> Array:
	var battle := TestBattleSetup.build(pack, TestBattleSetup.EncounterKind.BOSS, battle_seed)
	var random := _seeded(battle_seed)
	var turn_order := TurnOrder.new(battle, random)
	var record := []
	var previous_clock := 0
	for turn in AI_TURNS:
		var unit := turn_order.active_unit()
		if unit == null:
			break
		var now := turn_order.next_turn_of(unit)
		assert_int(now).is_greater_equal(previous_clock)
		assert_int(turn_order.round_number).is_equal(TurnOrder.round_of(now))
		previous_clock = now
		record.append([battle.units.find(unit), now])
		var choice := TurnAi.choose(battle, pack, unit)
		if choice.has_walk():
			var walk_facing := Movement.last_step_facing(unit.cell, choice.path)
			assert_bool(turn_order.move_unit(unit, choice.path, walk_facing)).is_true()
		elif choice.has_move():
			var use := MoveUse.new(battle, pack, unit, choice.move_name, choice.target_cell, choice.direction)
			assert_bool(turn_order.use_move(use, random)).is_true()
		else:
			assert_bool(turn_order.wait(unit, TurnAi.FALLBACK_WAIT)).is_true()
		if battle.is_over() or unit.has_fainted():
			continue
		assert_bool(turn_order.end_turn(choice.end_facing)).is_true()
		assert_int(turn_order.next_turn_of(unit)).is_greater(now)
	return record


## Relation 7: climbing never costs less than dropping the same levels, and costs more from 2 levels.
func test_a_climb_costs_at_least_the_same_drop() -> void:
	for levels in range(1, 4):
		var up_rows := ""
		var down_rows := ""
		for step in levels + 1:
			up_rows += str(step)
			down_rows += str(levels - step)
		var up_cost := Movement.walk_cost(BattleGrid.from_rows(PackedStringArray([up_rows])), Vector2i.ZERO,
			_east_path(levels))
		var down_cost := Movement.walk_cost(BattleGrid.from_rows(PackedStringArray([down_rows])), Vector2i.ZERO,
			_east_path(levels))
		assert_int(up_cost).is_greater_equal(down_cost)
		if levels >= 2:
			assert_int(up_cost).is_greater(down_cost)


## Relation 8: a run of stairs costs no more than the same steps walked as separate one-step walks.
func test_a_stair_run_costs_no_more_than_its_steps_apart() -> void:
	for rows in [["43210"], ["01234"], ["44322"]]:
		var grid := BattleGrid.from_rows(PackedStringArray(rows))
		var whole := Movement.walk_cost(grid, Vector2i.ZERO, _east_path(4))
		var apart := 0
		for column in range(1, 5):
			apart += Movement.walk_cost(grid, Vector2i(column - 1, 0), _path([Vector2i(column, 0)]))
		assert_int(whole).is_less_equal(apart)


## Relation 9: upkeep runs exactly once per round boundary, also across a round in which no unit has a turn.
func test_upkeep_runs_once_per_round_boundary() -> void:
	var long_row := "0".repeat(Movement.MAX_WALK_COST * 2 + 1)
	var battle := _flat_battle([long_row])
	var unit := _add(battle, Vector2i(0, 0), Battle.Side.PLAYER, 50, BattleStats.LARGEST_SIZE_BAND)
	var turn_order := TurnOrder.new(battle, _seeded(9))
	assert_int(turn_order.round_number).is_equal(1)
	# Wait to the round's last SR, then make the longest walk: the next turn skips a whole round.
	turn_order.wait(unit, turn_order.wait_limit())
	turn_order.end_turn(Facing.Direction.EAST)
	assert_int(turn_order.current_strike_rank()).is_equal(TurnOrder.ROUND_LENGTH)
	turn_order.move_unit(unit, _east_path(Movement.MAX_WALK_COST * 2), Facing.Direction.EAST)
	turn_order.end_turn(Facing.Direction.EAST)
	var landing_round := TurnOrder.round_of(turn_order.next_turn_of(unit))
	assert_int(landing_round).is_greater(2)
	assert_int(turn_order.round_number).is_equal(landing_round)


## Relation 11: Jess's worked rows from 2026-11-17-elevation-cost (flat, up, down, flat: SR). walk_cost does not
## check step legality, so row 4 (4 levels up in one step) can be measured although no walk could take it.
func test_jess_worked_walk_rows() -> void:
	var rows := [
		["1110", 3],
		["11110", 4],
		["0001", 3],
		["0000044", 7],
		["4444420", 5],
	]
	for row in rows:
		var heights: String = row[0]
		var grid := BattleGrid.from_rows(PackedStringArray([heights]))
		var cost := Movement.walk_cost(grid, Vector2i.ZERO, _east_path(heights.length() - 1))
		assert_int(cost).override_failure_message("%s costs %d" % [heights, cost]).is_equal(row[1])
