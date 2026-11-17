extends GdUnitTestSuite
## Issue #12 relations (docs/discussion-outputs/win-lose-opening.md, ruling 2026-11-17-battle-end-m1): a battle
## ends on a rout the moment one side has no standing unit, a double wipe goes to the side that used the move,
## nothing acts after the end, an AI battle replays from its seed, and the AI takes a win it can see.

const BOARD_ROWS := [
	"0000000000",
	"0000000000",
	"0000000000",
	"0000000000",
	"0000000000",
	"0000000000",
	"0000000000",
	"0000000000",
	"0000000000",
	"0000000000",
]
const LEVEL := 30
## Makes a unit act first in the turn order (a set-up value, not an outcome).
const FASTEST_SPEED := 999
const ATTACKER_CELL := Vector2i(4, 4)
const ADJACENT_CELL := Vector2i(5, 4)
const FAR_CELL := Vector2i(9, 9)
const REPLAY_SEED := 7
## Stall guard for the AI battles: a safety limit, not an expected battle length.
const MAX_ROUNDS := 200

var pack: PackData


func before() -> void:
	pack = PackData.shared()


## Relation 1: while both sides have a standing unit the battle goes on, after a hit as well as before.
func test_ongoing_while_both_sides_stand() -> void:
	var battle := _battle()
	var attacker := _unit(battle, "machop", ATTACKER_CELL, Battle.Side.PLAYER, ["strength"])
	attacker.stats["speed"] = FASTEST_SPEED
	attacker.base_strike_rank = BattleStats.SMALLEST_SIZE_BAND
	_unit(battle, "eevee", ADJACENT_CELL, Battle.Side.ENEMY)
	_unit(battle, "eevee", FAR_CELL, Battle.Side.ENEMY)
	var turn_order := TurnOrder.new(battle, _random())
	assert_bool(battle.is_over()).is_false()
	assert_bool(turn_order.use_move(_strength(battle, attacker, ADJACENT_CELL), _random())).is_true()
	assert_bool(battle.is_over()).is_false()
	assert_int(battle.winning_side).is_equal(Battle.NO_WINNER)


## Relation 2: knocking out a side's last unit makes the other side the winner, for either side.
func test_routing_a_side_gives_the_other_side_the_win() -> void:
	for attacking_side in [Battle.Side.PLAYER, Battle.Side.ENEMY]:
		var defending_side := Battle.Side.ENEMY if attacking_side == Battle.Side.PLAYER else Battle.Side.PLAYER
		var battle := _battle()
		var attacker := _unit(battle, "machop", ATTACKER_CELL, attacking_side, ["strength"])
		attacker.stats["speed"] = FASTEST_SPEED
		attacker.base_strike_rank = BattleStats.SMALLEST_SIZE_BAND
		var last_defender := _unit(battle, "eevee", ADJACENT_CELL, defending_side)
		last_defender.hit_points = 1
		var turn_order := TurnOrder.new(battle, _random())
		turn_order.use_move(_strength(battle, attacker, ADJACENT_CELL), _random())
		assert_bool(last_defender.has_fainted()).is_true()
		assert_bool(battle.is_over()).is_true()
		assert_int(battle.winning_side).is_equal(attacking_side)


## Relation 3: the result is fixed mid-turn, and after it no unit may move, act or end a turn.
func test_nothing_acts_after_the_end() -> void:
	var battle := _battle()
	var attacker := _unit(battle, "machop", ATTACKER_CELL, Battle.Side.PLAYER, ["strength"])
	attacker.stats["speed"] = FASTEST_SPEED
	attacker.base_strike_rank = BattleStats.SMALLEST_SIZE_BAND
	var last_foe := _unit(battle, "eevee", ADJACENT_CELL, Battle.Side.ENEMY)
	last_foe.hit_points = 1
	var turn_order := TurnOrder.new(battle, _random())
	turn_order.use_move(_strength(battle, attacker, ADJACENT_CELL), _random())
	var round_at_end := turn_order.round_number
	var facing_at_end := attacker.facing
	assert_bool(battle.is_over()).is_true()
	assert_object(turn_order.active_unit()).is_null()
	assert_bool(turn_order.can_take_action(attacker)).is_false()
	var path: Array[Vector2i] = [ATTACKER_CELL + Vector2i(0, 1)]
	assert_bool(turn_order.move_unit(attacker, path, Facing.Direction.SOUTH)).is_false()
	assert_that(attacker.cell).is_equal(ATTACKER_CELL)
	turn_order.end_turn(Facing.Direction.WEST)
	assert_int(turn_order.round_number).is_equal(round_at_end)
	assert_that(attacker.facing).is_equal(facing_at_end)


## Relation 4: a Self-Destruct that faints the last foe and its own user, its side's last unit, wins for the user.
func test_last_self_destruct_wins_for_its_user() -> void:
	var battle := _battle()
	var user := _unit(battle, "geodude", ATTACKER_CELL, Battle.Side.ENEMY, ["self-destruct"])
	user.stats["speed"] = FASTEST_SPEED
	user.base_strike_rank = BattleStats.SMALLEST_SIZE_BAND
	var last_foe := _unit(battle, "eevee", ADJACENT_CELL, Battle.Side.PLAYER)
	last_foe.hit_points = 1
	var turn_order := TurnOrder.new(battle, _random())
	var self_destruct := MoveUse.new(battle, pack, user, "self-destruct", ATTACKER_CELL, Facing.Direction.EAST)
	turn_order.use_move(self_destruct, _random())
	assert_bool(user.has_fainted()).is_true()
	assert_bool(last_foe.has_fainted()).is_true()
	assert_int(battle.winning_side).is_equal(Battle.Side.ENEMY)


## Relation 5: the same seed and kind, AI against AI, gives the same result in the same number of rounds.
func test_an_ai_battle_replays_from_its_seed() -> void:
	var first := _ai_battle_record(TestBattleSetup.EncounterKind.BOSS, REPLAY_SEED)
	var second := _ai_battle_record(TestBattleSetup.EncounterKind.BOSS, REPLAY_SEED)
	assert_int(first[0]).is_not_equal(Battle.NO_WINNER)
	assert_array(second).is_equal(first)


## Ruling 2026-11-17-battle-end-m1 for the AI: a last unit takes the Self-Destruct that wins, over a hit that does
## not.
func test_ai_takes_a_winning_self_destruct() -> void:
	var battle := _battle()
	var user := _unit(battle, "geodude", ATTACKER_CELL, Battle.Side.ENEMY, ["strength", "self-destruct"])
	var last_foe := _unit(battle, "eevee", ADJACENT_CELL, Battle.Side.PLAYER)
	var blast_damage := MoveUse.hit_damage(pack, user, last_foe, "self-destruct", ATTACKER_CELL, ATTACKER_CELL, false)
	var strength_damage := MoveUse.hit_damage(pack, user, last_foe, "strength", ATTACKER_CELL, ADJACENT_CELL, false)
	# Preconditions: Self-Destruct knocks the healthy foe out, Strength does not.
	assert_int(blast_damage).is_greater_equal(last_foe.hit_points)
	assert_int(strength_damage).is_less(last_foe.hit_points)
	var choice := TurnAi.choose(battle, pack, user)
	assert_str(choice.move_name).is_equal("self-destruct")


## [winning side, rounds played] of a test battle played AI against AI from a seed.
func _ai_battle_record(encounter_kind: TestBattleSetup.EncounterKind, battle_seed: int) -> Array:
	var battle := TestBattleSetup.build(pack, encounter_kind, battle_seed)
	var random := RandomNumberGenerator.new()
	random.seed = battle_seed
	var turn_order := TurnOrder.new(battle, random)
	while not battle.is_over() and turn_order.round_number <= MAX_ROUNDS:
		var unit := turn_order.active_unit()
		var choice := TurnAi.choose(battle, pack, unit)
		if choice.has_walk():
			turn_order.move_unit(unit, choice.path, Movement.last_step_facing(unit.cell, choice.path))
		elif choice.has_move():
			var use := MoveUse.new(battle, pack, unit, choice.move_name, choice.target_cell, choice.direction)
			turn_order.use_move(use, random)
		else:
			turn_order.wait(unit, TurnAi.FALLBACK_WAIT)
		if not unit.has_fainted():
			turn_order.end_turn(choice.end_facing)
	return [battle.winning_side, turn_order.round_number]


func _battle() -> Battle:
	return Battle.new(BattleGrid.from_rows(PackedStringArray(BOARD_ROWS)))


func _unit(battle: Battle, unit_name: String, cell: Vector2i, side: int, move_names: Array = []) -> BattleUnit:
	var unit := BattleUnit.from_pack(pack, unit_name, LEVEL, cell, Facing.Direction.SOUTH)
	if not move_names.is_empty():
		unit.move_names.assign(move_names)
	battle.add_unit(unit, side)
	return unit


func _strength(battle: Battle, attacker: BattleUnit, target_cell: Vector2i) -> MoveUse:
	var direction := Facing.direction_of_step(target_cell - attacker.cell)
	return MoveUse.new(battle, pack, attacker, "strength", target_cell, direction)


func _random() -> RandomNumberGenerator:
	var random := RandomNumberGenerator.new()
	random.seed = 1
	return random
