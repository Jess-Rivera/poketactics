extends GdUnitTestSuite
## Issue #15 relations (docs/discussion-outputs/hotseat-opening.md, ruling 2026-11-17-hotseat-m1b): hotseat teams
## are 6 pool units with no species twice, every pool unit can fight on the grid, two teams build a battle on their
## own sides, the AI plays no side in hotseat, a battle replays from its teams and seed, and a hotseat battle driven
## through the turn order ends with a result.

const REPLAY_SEED := 5
## A valid player 2 team (one Vulpix only), mirrors of player 1's units allowed.
const SECOND_TEAM := ["vulpix", "geodude", "gastly", "oddish", "mankey", "eevee"]
## Stall guard for the driven battle: a safety limit, not an expected battle length.
const MAX_ROUNDS := 200

var pack: PackData


func before() -> void:
	pack = PackData.shared()


## Relation 1: a valid team is TEAM_SIZE pool units with no species twice; short, long, off-pool and same-species
## teams are refused.
func test_team_rules() -> void:
	var valid := _team(TestBattleSetup.PLAYER_ROSTER)
	assert_bool(TestBattleSetup.is_valid_team(pack, valid)).is_true()
	assert_bool(TestBattleSetup.is_valid_team(pack, valid.slice(0, TestBattleSetup.TEAM_SIZE - 1))).is_false()
	var too_long := valid.duplicate()
	too_long.append("geodude")
	assert_bool(TestBattleSetup.is_valid_team(pack, too_long)).is_false()
	var off_pool := valid.duplicate()
	off_pool[0] = "mewtwo"
	assert_bool(TestBattleSetup.HOTSEAT_POOL.has("mewtwo")).is_false()
	assert_bool(TestBattleSetup.is_valid_team(pack, off_pool)).is_false()
	var same_species := _team(["vulpix", "vulpix-alola", "geodude", "gastly", "oddish", "mankey"])
	assert_str(pack.unit("vulpix")["species"]).is_equal(pack.unit("vulpix-alola")["species"])
	assert_bool(TestBattleSetup.is_valid_team(pack, same_species)).is_false()
	var repeated := _team(["geodude", "geodude", "gastly", "oddish", "mankey", "eevee"])
	assert_bool(TestBattleSetup.is_valid_team(pack, repeated)).is_false()
	assert_bool(TestBattleSetup.can_join_team(pack, _team(["vulpix"]), "vulpix-alola")).is_false()
	assert_bool(TestBattleSetup.can_join_team(pack, valid, "geodude")).is_false()


## Relation 2: every pool unit at the set level knows only moves with grid behaviour, and has a sprite set.
func test_every_pool_unit_can_fight_on_the_grid() -> void:
	for unit_name in TestBattleSetup.HOTSEAT_POOL:
		var unit := BattleUnit.from_pack(pack, unit_name, TestBattleSetup.UNIT_LEVEL)
		assert_array(unit.move_names).is_not_empty()
		for move_name in unit.move_names:
			assert_bool(pack.move(move_name).get("grid") != null).override_failure_message(
				"%s's %s has no grid behaviour" % [unit_name, move_name]
			).is_true()
		assert_bool(pack.unit(unit_name)["sprite_set"] != null).is_true()


## Relation 3: team 1 fills the player side and team 2 the enemy side, at the set level, on distinct cells.
func test_teams_take_their_own_sides() -> void:
	var team_one := _team(TestBattleSetup.PLAYER_ROSTER)
	var team_two := _team(SECOND_TEAM)
	var battle := TestBattleSetup.build_from_teams(pack, team_one, team_two)
	assert_bool(TestBattleSetup.is_valid_team(pack, team_two)).is_true()
	assert_array(_names(battle.units_on_side(Battle.Side.PLAYER))).is_equal(team_one)
	assert_array(_names(battle.units_on_side(Battle.Side.ENEMY))).is_equal(team_two)
	var cells := {}
	for unit in battle.units:
		assert_int(unit.level).is_equal(TestBattleSetup.UNIT_LEVEL)
		cells[unit.cell] = true
	assert_int(cells.size()).is_equal(battle.units.size())


## Relation 4: the AI plays no side in hotseat and only the enemy side against the player.
func test_who_the_ai_plays() -> void:
	assert_array(TestBattleSetup.AI_SIDES_BY_MODE[TestBattleSetup.PlayMode.HOTSEAT]).is_empty()
	assert_array(TestBattleSetup.AI_SIDES_BY_MODE[TestBattleSetup.PlayMode.AI_BATTLE]).is_equal([Battle.Side.ENEMY])


## Relation 5: the same teams and seed give the same battle and turn order.
func test_same_teams_and_seed_replay() -> void:
	assert_array(_battle_record(REPLAY_SEED)).is_equal(_battle_record(REPLAY_SEED))


## Relation 6: a hotseat battle with both sides driven through the turn order (by TurnAi) ends with a result.
func test_a_driven_hotseat_battle_ends() -> void:
	var battle := TestBattleSetup.build_from_teams(pack, _team(TestBattleSetup.PLAYER_ROSTER), _team(SECOND_TEAM))
	var random := RandomNumberGenerator.new()
	random.seed = REPLAY_SEED
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
	assert_bool(battle.is_over()).is_true()


## Unit names, cells and the first round's order of a hotseat battle with fixed teams and this seed.
func _battle_record(battle_seed: int) -> Array:
	var battle := TestBattleSetup.build_from_teams(pack, _team(TestBattleSetup.PLAYER_ROSTER), _team(SECOND_TEAM))
	var random := RandomNumberGenerator.new()
	random.seed = battle_seed
	var turn_order := TurnOrder.new(battle, random)
	var record := []
	for unit in battle.units:
		record.append([unit.unit_name, unit.side, unit.cell])
	for slot in turn_order.forecast(battle.units.size()):
		record.append(slot.unit.unit_name)
	return record


func _team(unit_names: Array) -> Array[String]:
	var team: Array[String] = []
	team.assign(unit_names)
	return team


func _names(units: Array[BattleUnit]) -> Array[String]:
	var names: Array[String] = []
	for unit in units:
		names.append(unit.unit_name)
	return names
