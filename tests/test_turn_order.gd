extends GdUnitTestSuite
## Issue #8 relations (docs/discussion-outputs/turn-order-plan.md) that still hold on #13's strike rank clock
## (docs/discussion-outputs/strike-rank-plan.md): ties broken by the battle seed, fainted units skipped, the
## forecast and its landing preview, one action per turn by the active unit only, the end-turn facing, and the turn
## bar layout. The clock's own relations are in test_strike_rank.gd.

const FLAT_ROWS := ["00000000", "00000000", "00000000", "00000000", "00000000", "00000000", "00000000", "00000000"]
const SEEDS_TO_TRY := 64
const TURNS_TO_PLAY := 40


func _flat_battle() -> Battle:
	return Battle.new(BattleGrid.from_rows(PackedStringArray(FLAT_ROWS)))


func _add(battle: Battle, cell: Vector2i, side: int, speed: int) -> BattleUnit:
	var unit := BattleUnit.new(cell)
	unit.stats = {"speed": speed}
	unit.max_hit_points = 10
	unit.hit_points = 10
	battle.add_unit(unit, side)
	return unit


func _seeded(battle_seed: int) -> RandomNumberGenerator:
	var random := RandomNumberGenerator.new()
	random.seed = battle_seed
	return random


## The active unit waits strike_ranks SR (or as long as it may) and ends its turn facing as it is.
func _wait_turn(turn_order: TurnOrder, strike_ranks: int = 1) -> BattleUnit:
	var unit := turn_order.active_unit()
	turn_order.wait(unit, mini(strike_ranks, turn_order.wait_limit()))
	turn_order.end_turn(unit.facing)
	return unit


## Relation 2: units on the same SR with equal Speed are ordered by the seed, the same way every time for one
## seed, and not by side.
func test_speed_ties_follow_the_battle_seed() -> void:
	var first_counts := {}
	for battle_seed in SEEDS_TO_TRY:
		var orders := []
		for repeat in 2:
			var battle := _flat_battle()
			var player_unit := _add(battle, Vector2i(0, 0), Battle.Side.PLAYER, 50)
			var enemy_unit := _add(battle, Vector2i(5, 5), Battle.Side.ENEMY, 50)
			var first := TurnOrder.new(battle, _seeded(battle_seed)).active_unit()
			orders.append(Battle.Side.PLAYER if first == player_unit else Battle.Side.ENEMY)
			assert_bool(first == player_unit or first == enemy_unit).is_true()
		assert_int(orders[0]).is_equal(orders[1])
		first_counts[orders[0]] = first_counts.get(orders[0], 0) + 1
	assert_int(first_counts.size()).is_equal(2)


## Relation 5: a fainted unit never takes a turn and never shows in the forecast.
func test_fainted_units_are_skipped() -> void:
	var battle := _flat_battle()
	_add(battle, Vector2i(0, 0), Battle.Side.PLAYER, 90)
	var fainted := _add(battle, Vector2i(1, 0), Battle.Side.ENEMY, 60)
	_add(battle, Vector2i(2, 0), Battle.Side.ENEMY, 30)
	var turn_order := TurnOrder.new(battle, _seeded(5))
	fainted.hit_points = 0
	for turn in TURNS_TO_PLAY:
		for slot in turn_order.forecast(8):
			assert_object(slot.unit).is_not_same(fainted)
		assert_object(_wait_turn(turn_order, turn % 5 + 1)).is_not_same(fainted)


## Relation 6: the forecast lists each standing unit once, the active unit first, in clock order; and the landing
## preview names the next active unit (the entry after the active one once the preview is placed).
func test_forecast_and_landing_preview_match_the_turns_played() -> void:
	var battle := TestBattleSetup.build(PackData.shared())
	var turn_order := TurnOrder.new(battle, _seeded(11))
	for turn in TURNS_TO_PLAY:
		var forecast := turn_order.forecast(battle.units.size())
		assert_int(forecast.size()).is_equal(battle.units.size())
		assert_object(forecast[0].unit).is_same(turn_order.active_unit())
		var seen := {}
		for index in forecast.size():
			seen[forecast[index].unit] = true
			if index > 0:
				var earlier: TurnOrder.Slot = forecast[index - 1]
				var later: TurnOrder.Slot = forecast[index]
				assert_bool(later.round_number > earlier.round_number or (
					later.round_number == earlier.round_number and later.strike_rank >= earlier.strike_rank
				)).is_true()
		assert_int(seen.size()).is_equal(battle.units.size())
		var wait := turn % turn_order.wait_limit() + 1
		var preview := turn_order.forecast(battle.units.size() + 1, wait, true)
		_wait_turn(turn_order, wait)
		assert_object(turn_order.active_unit()).is_same(preview[1].unit)


## Relation 7: only the active unit takes an action, and only one per turn (a walk, a move used or a Wait).
func test_only_the_active_unit_takes_one_action() -> void:
	var battle := _flat_battle()
	var fast := _add(battle, Vector2i(0, 0), Battle.Side.PLAYER, 90)
	var slow := _add(battle, Vector2i(7, 7), Battle.Side.ENEMY, 30)
	var turn_order := TurnOrder.new(battle, _seeded(2))
	var fast_path: Array[Vector2i] = [Vector2i(1, 0)]
	var fast_second_path: Array[Vector2i] = [Vector2i(2, 0)]
	var slow_path: Array[Vector2i] = [Vector2i(6, 7)]
	# The slow unit is not active: refused, and it stays put.
	assert_bool(turn_order.can_take_action(slow)).is_false()
	assert_bool(turn_order.move_unit(slow, slow_path, Facing.Direction.WEST)).is_false()
	assert_bool(turn_order.wait(slow, 1)).is_false()
	assert_object(battle.unit_at(Vector2i(7, 7))).is_same(slow)
	# The active unit's walk is allowed; a second walk or a Wait after it is refused.
	assert_bool(turn_order.can_take_action(fast)).is_true()
	assert_bool(turn_order.move_unit(fast, fast_path, Facing.Direction.EAST)).is_true()
	assert_object(battle.unit_at(Vector2i(1, 0))).is_same(fast)
	assert_bool(turn_order.can_take_action(fast)).is_false()
	assert_bool(turn_order.move_unit(fast, fast_second_path, Facing.Direction.EAST)).is_false()
	assert_bool(turn_order.wait(fast, 1)).is_false()
	assert_object(battle.unit_at(Vector2i(1, 0))).is_same(fast)
	# Next turn: the slow unit may act.
	turn_order.end_turn(fast.facing)
	assert_object(turn_order.active_unit()).is_same(slow)
	assert_bool(turn_order.move_unit(slow, slow_path, Facing.Direction.WEST)).is_true()
	assert_object(battle.unit_at(Vector2i(6, 7))).is_same(slow)


## Relation 7b: a turn cannot end before its action.
func test_a_turn_does_not_end_without_an_action() -> void:
	var battle := _flat_battle()
	var unit := _add(battle, Vector2i(3, 3), Battle.Side.PLAYER, 50)
	_add(battle, Vector2i(6, 6), Battle.Side.ENEMY, 40)
	var turn_order := TurnOrder.new(battle, _seeded(4))
	assert_object(turn_order.active_unit()).is_same(unit)
	assert_bool(turn_order.end_turn(Facing.Direction.NORTH)).is_false()
	assert_object(turn_order.active_unit()).is_same(unit)


## Relation 8: ending a turn turns the unit to the chosen facing.
func test_ending_a_turn_sets_the_chosen_facing() -> void:
	for direction in Facing.ALL_DIRECTIONS:
		var battle := _flat_battle()
		var unit := _add(battle, Vector2i(3, 3), Battle.Side.PLAYER, 50)
		var turn_order := TurnOrder.new(battle, _seeded(6))
		turn_order.wait(unit, 1)
		turn_order.end_turn(direction)
		assert_int(unit.facing).is_equal(direction)


## Relation 9: the active entry is at the bottom and larger, each higher entry is closer to the right edge,
## entries never overlap and stay on screen, with or without round dividers.
func test_turn_bar_layout() -> void:
	var round_patterns := [[1, 1, 1, 1, 1, 1, 1, 1], [1, 1, 1, 2, 2, 2, 2, 2], [1, 2, 2, 2, 3, 3, 3, 4]]
	var screen := Rect2(Vector2.ZERO, TurnBar.SCREEN_SIZE)
	for slot_rounds in round_patterns:
		var rects := TurnBar.entry_rects(slot_rounds)
		assert_int(rects.size()).is_equal(slot_rounds.size())
		for index in rects.size():
			assert_bool(screen.encloses(rects[index])).is_true()
			if index == 0:
				continue
			assert_float(rects[0].size.x).is_greater(rects[index].size.x)
			assert_float(rects[0].size.y).is_greater(rects[index].size.y)
			assert_float(rects[index].end.y).is_less_equal(rects[index - 1].position.y)
			assert_float(rects[index].end.x).is_greater(rects[index - 1].end.x)
			for other in index:
				assert_bool(rects[index].intersects(rects[other])).is_false()
