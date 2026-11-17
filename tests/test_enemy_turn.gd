extends GdUnitTestSuite
## Issue #11 relations (docs/discussion-outputs/enemy-turn-opening.md, ruling 2026-11-17-enemy-ai-m1): the
## one-turn scorer makes only legal choices, prefers super effective hits and sure knockouts, never attacks only
## its own side, closes in when nothing is in reach, chooses the same way on the same board without rolling, and
## an AI-against-AI battle ends with one side standing.

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
## High enough that no single hit at LEVEL knocks the unit out (a precondition of relation 2, not an outcome).
const UNBREAKABLE_HIT_POINTS := 10000
## One seed per encounter kind for the AI-against-AI battles.
const BATTLE_SEEDS := [11, 22, 33]
## Stall guard for relation 7: a safety limit, not an expected battle length.
const MAX_ROUNDS := 200

var pack: PackData


func before() -> void:
	pack = PackData.shared()


## Relation 2: from the same reach, a super effective target is chosen over a neutral one when neither knocks out.
func test_super_effective_beats_neutral() -> void:
	var battle := _battle()
	var user := _unit(battle, "charmander", Vector2i(4, 4), Battle.Side.ENEMY, ["flamethrower"])
	var neutral_foe := _unit(battle, "machop", Vector2i(4, 2), Battle.Side.PLAYER)
	var weak_foe := _unit(battle, "machop", Vector2i(6, 4), Battle.Side.PLAYER)
	neutral_foe.types.assign(["normal"])
	weak_foe.types.assign(["grass"])
	for foe in [neutral_foe, weak_foe]:
		foe.max_hit_points = UNBREAKABLE_HIT_POINTS
		foe.hit_points = UNBREAKABLE_HIT_POINTS
	var choice := TurnAi.choose(battle, pack, user)
	assert_str(choice.move_name).is_equal("flamethrower")
	assert_that(choice.target_cell).is_equal(weak_foe.cell)


## Relation 3: a sure knockout is chosen over a bigger hit that does not knock out.
func test_sure_knockout_beats_bigger_hit() -> void:
	var battle := _battle()
	var user := _unit(battle, "machop", Vector2i(4, 4), Battle.Side.ENEMY, ["strength"])
	var healthy_foe := _unit(battle, "eevee", Vector2i(4, 3), Battle.Side.PLAYER)
	var wounded_foe := _unit(battle, "geodude", Vector2i(5, 4), Battle.Side.PLAYER)
	wounded_foe.hit_points = 1
	var healthy_damage := MoveUse.hit_damage(pack, user, healthy_foe, "strength", user.cell, healthy_foe.cell, false)
	var wounded_damage := MoveUse.hit_damage(pack, user, wounded_foe, "strength", user.cell, wounded_foe.cell, false)
	# Preconditions: the hit on the healthy foe is bigger and does not knock it out.
	assert_int(healthy_damage).is_greater(wounded_damage)
	assert_int(healthy_damage).is_less(healthy_foe.hit_points)
	var choice := TurnAi.choose(battle, pack, user)
	assert_that(choice.target_cell).is_equal(wounded_foe.cell)


## Relation 4: with only allies (or the user itself, by Self-Destruct) to hit, the unit does not act.
func test_never_attacks_only_its_own_side() -> void:
	var battle := _battle()
	var user := _unit(battle, "geodude", Vector2i(1, 1), Battle.Side.ENEMY, ["strength", "self-destruct"])
	_unit(battle, "geodude", Vector2i(2, 1), Battle.Side.ENEMY)
	_unit(battle, "eevee", Vector2i(9, 9), Battle.Side.PLAYER)
	var choice := TurnAi.choose(battle, pack, user)
	assert_bool(choice.has_move()).is_false()


## Relation 5: with no foe in reach, the unit walks and ends closer to the nearest foe (flat board: grid distance
## is path distance).
func test_closes_in_when_nothing_is_in_reach() -> void:
	var battle := _battle()
	var user := _unit(battle, "machop", Vector2i(0, 0), Battle.Side.ENEMY, ["strength"])
	var foe := _unit(battle, "eevee", Vector2i(9, 9), Battle.Side.PLAYER)
	var choice := TurnAi.choose(battle, pack, user)
	assert_bool(choice.has_move()).is_false()
	assert_bool(choice.has_walk()).is_true()
	assert_int(MoveArea.distance(choice.stand_cell, foe.cell)).is_less(MoveArea.distance(user.cell, foe.cell))


## Relation 6: the same board gives the same choice, and choosing changes nothing on the board.
func test_same_board_same_choice() -> void:
	var battle := TestBattleSetup.build(pack, TestBattleSetup.EncounterKind.BOSS, BATTLE_SEEDS[0])
	# Crowd the two sides together so attacks are on offer.
	for unit in battle.units_on_side(Battle.Side.PLAYER):
		unit.cell -= Vector2i(9, 9)
	var board_before := _board_record(battle)
	for unit in battle.units:
		var first := _choice_record(TurnAi.choose(battle, pack, unit))
		var second := _choice_record(TurnAi.choose(battle, pack, unit))
		assert_array(second).is_equal(first)
	assert_array(_board_record(battle)).is_equal(board_before)


## Relations 1 and 7: on the real test battle, AI against AI for each encounter kind, every choice is legal and
## the battle ends with a result from the rules (#12 relation 6).
func test_ai_battle_is_legal_and_ends() -> void:
	for kind_index in BATTLE_SEEDS.size():
		var encounter_kind: TestBattleSetup.EncounterKind = TestBattleSetup.EncounterKind.values()[kind_index]
		var battle_seed: int = BATTLE_SEEDS[kind_index]
		var battle := TestBattleSetup.build(pack, encounter_kind, battle_seed)
		var random := RandomNumberGenerator.new()
		random.seed = battle_seed
		var turn_order := TurnOrder.new(battle, random)
		while not battle.is_over() and turn_order.round_number <= MAX_ROUNDS:
			_play_turn(battle, turn_order, random)
		assert_bool(battle.is_over()).override_failure_message(
			"%s battle, seed %d: no side won within %d rounds" % [
				TestBattleSetup.ENCOUNTER_NAMES[encounter_kind], battle_seed, MAX_ROUNDS
			]
		).is_true()


## One AI turn through the turn order, checking the choice is legal first (relation 1): exactly one action, a
## walk along a reachable path, a move in reach from where the unit stands, or the fallback Wait (#13).
func _play_turn(battle: Battle, turn_order: TurnOrder, random: RandomNumberGenerator) -> void:
	var unit := turn_order.active_unit()
	var paths := Movement.reachable_paths(battle, unit)
	var choice := TurnAi.choose(battle, pack, unit)
	assert_bool(choice.has_walk() and choice.has_move()).is_false()
	if choice.has_walk():
		assert_array(paths.get(choice.stand_cell, [])).is_equal(choice.path)
		var walk_facing := Movement.last_step_facing(unit.cell, choice.path)
		assert_bool(turn_order.move_unit(unit, choice.path, walk_facing)).is_true()
	elif choice.has_move():
		assert_that(choice.stand_cell).is_equal(unit.cell)
		assert_bool(unit.move_names.has(choice.move_name)).is_true()
		var recipe := MoveRecipe.built(pack, unit, choice.move_name)
		assert_bool(MoveArea.can_reach(recipe, unit.cell, choice.target_cell)).is_true()
		var move_use := MoveUse.new(battle, pack, unit, choice.move_name, choice.target_cell, choice.direction)
		assert_bool(turn_order.use_move(move_use, random)).is_true()
	else:
		assert_bool(turn_order.wait(unit, TurnAi.FALLBACK_WAIT)).is_true()
	if not unit.has_fainted() and not battle.is_over():
		assert_bool(turn_order.end_turn(choice.end_facing)).is_true()


func _battle() -> Battle:
	return Battle.new(BattleGrid.from_rows(PackedStringArray(BOARD_ROWS)))


func _unit(battle: Battle, unit_name: String, cell: Vector2i, side: int, move_names: Array = []) -> BattleUnit:
	var unit := BattleUnit.from_pack(pack, unit_name, LEVEL, cell, Facing.Direction.SOUTH)
	if not move_names.is_empty():
		unit.move_names.assign(move_names)
	battle.add_unit(unit, side)
	return unit


func _choice_record(choice: TurnAi.Choice) -> Array:
	return [choice.path, choice.stand_cell, choice.move_name, choice.target_cell, choice.direction, choice.end_facing]


func _board_record(battle: Battle) -> Array:
	var record := []
	for unit in battle.units:
		record.append([unit.cell, unit.facing, unit.hit_points])
	return record
