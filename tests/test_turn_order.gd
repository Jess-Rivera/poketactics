extends GdUnitTestSuite
## Issue #8 relations (docs/discussion-outputs/turn-order-plan.md): rounds, fastest first, ties broken by the
## battle seed, Speed changes from the next round, fainted units skipped, the forecast, moving once per turn,
## the end-turn facing, and the turn bar layout.

const FLAT_ROWS := ["00000000", "00000000", "00000000", "00000000", "00000000", "00000000", "00000000", "00000000"]
const SEEDS_TO_TRY := 64


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


## Plays whole rounds and returns the units in the order they acted, one array per round.
func _play_rounds(turn_order: TurnOrder, round_count: int) -> Array:
	var rounds := []
	for round_index in round_count:
		var acted: Array[BattleUnit] = []
		var this_round := turn_order.round_number
		while turn_order.round_number == this_round and turn_order.active_unit() != null:
			var unit := turn_order.active_unit()
			acted.append(unit)
			turn_order.end_turn(unit.facing)
		rounds.append(acted)
	return rounds


## Relation 1, over the real test battle: each standing unit once per round, Speed never rising.
func test_each_unit_acts_once_per_round_fastest_first() -> void:
	var battle := TestBattleSetup.build(PackData.shared())
	var turn_order := TurnOrder.new(battle, _seeded(1))
	for acted in _play_rounds(turn_order, 3):
		assert_array(acted).contains_exactly_in_any_order(battle.units)
		for index in range(1, acted.size()):
			assert_int(TurnOrder.speed_of(acted[index])).is_less_equal(TurnOrder.speed_of(acted[index - 1]))


## Relation 2: equal Speed is decided by the seed, the same way every time for one seed, and not by side.
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


## Relation 3: with no Speed changes, every round repeats the first round's order (ties included).
func test_rounds_repeat_their_order() -> void:
	var battle := _flat_battle()
	for index in 6:
		_add(battle, Vector2i(index, 0), index % 2, 40 + (index / 2) * 10)
	var rounds := _play_rounds(TurnOrder.new(battle, _seeded(7)), 4)
	for acted in rounds:
		assert_array(acted).is_equal(rounds[0])


## Relation 4: a Speed change during a round only applies from the next round.
func test_speed_change_applies_from_the_next_round() -> void:
	var battle := _flat_battle()
	var fast := _add(battle, Vector2i(0, 0), Battle.Side.PLAYER, 90)
	var slow := _add(battle, Vector2i(5, 5), Battle.Side.ENEMY, 30)
	var turn_order := TurnOrder.new(battle, _seeded(3))
	assert_object(turn_order.active_unit()).is_same(fast)
	slow.stats["speed"] = 200
	turn_order.end_turn(fast.facing)
	assert_object(turn_order.active_unit()).is_same(slow)
	turn_order.end_turn(slow.facing)
	assert_int(turn_order.round_number).is_equal(2)
	assert_object(turn_order.active_unit()).is_same(slow)


## Relation 5: a fainted unit never acts and never shows in the forecast, even if it faints mid-round.
func test_fainted_units_are_skipped() -> void:
	var battle := _flat_battle()
	var first := _add(battle, Vector2i(0, 0), Battle.Side.PLAYER, 90)
	var second := _add(battle, Vector2i(1, 0), Battle.Side.ENEMY, 60)
	var third := _add(battle, Vector2i(2, 0), Battle.Side.ENEMY, 30)
	var turn_order := TurnOrder.new(battle, _seeded(5))
	second.hit_points = 0
	for slot in turn_order.forecast(8):
		assert_object(slot.unit).is_not_same(second)
	var acted := _play_rounds(turn_order, 2)
	for round_acted in acted:
		assert_array(round_acted).not_contains([second])
	assert_array(acted[1]).contains_exactly([first, third])


## Relation 6: the forecast starts with the active unit, has the asked length, never goes back a round, and
## matches the turns as they are then played.
func test_forecast_matches_the_turns_played() -> void:
	var battle := TestBattleSetup.build(PackData.shared())
	var turn_order := TurnOrder.new(battle, _seeded(11))
	turn_order.end_turn(turn_order.active_unit().facing)
	turn_order.end_turn(turn_order.active_unit().facing)
	var forecast := turn_order.forecast(20)
	assert_int(forecast.size()).is_equal(20)
	assert_object(forecast[0].unit).is_same(turn_order.active_unit())
	for index in forecast.size():
		if index > 0:
			assert_int(forecast[index].round_number).is_greater_equal(forecast[index - 1].round_number)
		assert_object(turn_order.active_unit()).is_same(forecast[index].unit)
		assert_int(turn_order.round_number).is_equal(forecast[index].round_number)
		turn_order.end_turn(turn_order.active_unit().facing)


## Relation 7: only the active unit moves, once per turn; the next turn may move again.
func test_only_the_active_unit_moves_and_only_once() -> void:
	var battle := _flat_battle()
	var fast := _add(battle, Vector2i(0, 0), Battle.Side.PLAYER, 90)
	var slow := _add(battle, Vector2i(7, 7), Battle.Side.ENEMY, 30)
	var turn_order := TurnOrder.new(battle, _seeded(2))
	var fast_path: Array[Vector2i] = [Vector2i(1, 0)]
	var fast_second_path: Array[Vector2i] = [Vector2i(2, 0)]
	var slow_path: Array[Vector2i] = [Vector2i(6, 7)]
	# The slow unit is not active: refused, and it stays put.
	assert_bool(turn_order.can_move(slow)).is_false()
	assert_bool(turn_order.move_unit(slow, slow_path, Facing.Direction.WEST)).is_false()
	assert_object(battle.unit_at(Vector2i(7, 7))).is_same(slow)
	# The active unit's first move is allowed, a second one is refused.
	assert_bool(turn_order.can_move(fast)).is_true()
	assert_bool(turn_order.move_unit(fast, fast_path, Facing.Direction.EAST)).is_true()
	assert_object(battle.unit_at(Vector2i(1, 0))).is_same(fast)
	assert_bool(turn_order.can_move(fast)).is_false()
	assert_bool(turn_order.move_unit(fast, fast_second_path, Facing.Direction.EAST)).is_false()
	assert_object(battle.unit_at(Vector2i(1, 0))).is_same(fast)
	# Next turn: the slow unit may move.
	turn_order.end_turn(fast.facing)
	assert_bool(turn_order.can_move(slow)).is_true()
	assert_bool(turn_order.move_unit(slow, slow_path, Facing.Direction.WEST)).is_true()
	assert_object(battle.unit_at(Vector2i(6, 7))).is_same(slow)
	# A new round gives the fast unit a fresh move.
	turn_order.end_turn(slow.facing)
	assert_bool(turn_order.can_move(fast)).is_true()


## Relation 8: ending a turn turns the unit to the chosen facing.
func test_ending_a_turn_sets_the_chosen_facing() -> void:
	for direction in Facing.ALL_DIRECTIONS:
		var battle := _flat_battle()
		var unit := _add(battle, Vector2i(3, 3), Battle.Side.PLAYER, 50)
		var turn_order := TurnOrder.new(battle, _seeded(6))
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
