extends GdUnitTestSuite
## Issue #27 end-goal test (docs/discussion-outputs/move-recipes-plan.md, ruling 2026-11-17-move-recipes-build):
## recipes change nothing. Footprints and seeded AI battles are compared with tests/fixtures/move_parity.json,
## recorded with the code before #27 (plan D4; delete the fixture and those two tests when #28 closes).

const FIXTURE_PATH := "res://tests/fixtures/move_parity.json"
const OVERRIDES_PATH := "res://authored/move_recipe_overrides.json"
const BOARD_SIZE := 15
const MAX_ROUNDS := 200
const UNHANDLED_ONLY_MOVE := "agility"

var pack: PackData
var fixture: Dictionary
var roster_moves: Array


func before() -> void:
	pack = PackData.shared()
	fixture = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE_PATH))
	roster_moves = JSON.parse_string(FileAccess.get_file_as_string(OVERRIDES_PATH)).keys()


## Every roster move builds, and resolves at every cell it can reach without error.
func test_every_roster_move_builds_and_resolves() -> void:
	for move_name in roster_moves:
		var battle := _open_board()
		var user := _unit_knowing(battle, move_name)
		var recipe := MoveRecipe.built(pack, user, move_name)
		assert_bool(recipe.is_empty()).override_failure_message(move_name).is_false()
		for target_cell in MoveArea.target_cells(battle.grid, recipe, user.cell):
			var use := MoveUse.new(battle, pack, user, move_name, target_cell, Facing.Direction.EAST)
			assert_bool(use.is_allowed()).override_failure_message("%s at %s" % [move_name, target_cell]).is_true()
			use.resolve(_seeded(1))


## Every roster move covers the same tiles, at every target and aim, as before the recipe rewrite.
func test_footprints_match_the_old_shapes() -> void:
	var battle := _open_board()
	var centre := Vector2i(BOARD_SIZE / 2, BOARD_SIZE / 2)
	var recorded: Dictionary = fixture["footprints"]
	var keys_now := {}
	for move_name in roster_moves:
		var user := BattleUnit.new(centre)
		var recipe := MoveRecipe.built(pack, user, move_name)
		for target_cell in MoveArea.target_cells(battle.grid, recipe, centre):
			for direction in Facing.ALL_DIRECTIONS:
				var key := "%s|%d,%d|%d" % [move_name, target_cell.x, target_cell.y, direction]
				keys_now[key] = true
				var cells := []
				for cell in MoveArea.footprint(pack.shapes, recipe, centre, target_cell, direction):
					cells.append([cell.x, cell.y])
				cells.sort()
				assert_str(_as_json(cells)).override_failure_message(key).is_equal(JSON.stringify(recorded.get(key)))
	assert_int(keys_now.size()).is_equal(recorded.size())


## Seeded AI-against-AI battles play out turn for turn as before: same actions, cells and hit points.
func test_seeded_battles_replay_as_before() -> void:
	for recorded in fixture["battles"]:
		var replayed := _battle_log(int(recorded["kind"]), int(recorded["seed"]))
		var label := "kind %d seed %d" % [recorded["kind"], recorded["seed"]]
		assert_str(_as_json(replayed)).override_failure_message(label).is_equal(JSON.stringify(recorded))


## With no upgrades, the built recipe is the pack's recipe.
func test_built_recipe_equals_the_base_recipe() -> void:
	var user := BattleUnit.new()
	for move_name in roster_moves:
		var built := MoveRecipe.built(pack, user, move_name)
		assert_dict(built).override_failure_message(move_name).is_equal(pack.move(move_name)["recipe"])


## A move whose components all lack a handler changes no hit points and makes no rolls.
func test_effects_without_a_handler_change_nothing() -> void:
	var recipe: Dictionary = pack.move(UNHANDLED_ONLY_MOVE)["recipe"]
	for component in recipe["components"]:
		assert_bool(MoveEffects.has_handler(component["effect"])).is_false()
	var battle := _open_board()
	var user := _unit_knowing(battle, UNHANDLED_ONLY_MOVE)
	var hit_points_before := user.hit_points
	var random := _seeded(5)
	var state_before := random.state
	var use := MoveUse.new(battle, pack, user, UNHANDLED_ONLY_MOVE, user.cell, Facing.Direction.EAST)
	use.resolve(random)
	assert_int(user.hit_points).is_equal(hit_points_before)
	assert_int(random.state).is_equal(state_before)
	assert_array(use.outcomes).is_empty()


func _open_board() -> Battle:
	var rows: Array[String] = []
	for row_index in BOARD_SIZE:
		rows.append("0".repeat(BOARD_SIZE))
	return Battle.new(BattleGrid.from_rows(PackedStringArray(rows)))


## A unit in the middle of the board that knows the move, with a foe on every other cell.
func _unit_knowing(battle: Battle, move_name: String) -> BattleUnit:
	var centre := Vector2i(BOARD_SIZE / 2, BOARD_SIZE / 2)
	var user := BattleUnit.from_pack(pack, "pikachu", TestBattleSetup.UNIT_LEVEL, centre, Facing.Direction.EAST)
	user.move_names.assign([move_name])
	battle.add_unit(user, Battle.Side.PLAYER)
	for grid_y in BOARD_SIZE:
		for grid_x in BOARD_SIZE:
			var cell := Vector2i(grid_x, grid_y)
			if cell != centre:
				var foe := BattleUnit.from_pack(pack, "rattata", TestBattleSetup.UNIT_LEVEL, cell, Facing.Direction.WEST)
				battle.add_unit(foe, Battle.Side.ENEMY)
	return user


## JSON text of a value after one round trip, so its numbers read as the fixture's do (JSON numbers are floats).
func _as_json(value: Variant) -> String:
	return JSON.stringify(JSON.parse_string(JSON.stringify(value)))


func _seeded(seed_value: int) -> RandomNumberGenerator:
	var random := RandomNumberGenerator.new()
	random.seed = seed_value
	return random


## The same turn log the fixture recorder kept: per turn the unit index, its action, its cell and every unit's HP.
func _battle_log(encounter_kind: int, battle_seed: int) -> Dictionary:
	var battle := TestBattleSetup.build(pack, encounter_kind, battle_seed)
	var random := _seeded(battle_seed)
	var turn_order := TurnOrder.new(battle, random)
	var turns := []
	while not battle.is_over() and turn_order.round_number <= MAX_ROUNDS:
		var unit := turn_order.active_unit()
		var choice := TurnAi.choose(battle, pack, unit)
		var action := "wait"
		if choice.has_walk():
			action = "walk"
			turn_order.move_unit(unit, choice.path, Movement.last_step_facing(unit.cell, choice.path))
		elif choice.has_move():
			action = "%s@%d,%d|%d" % [choice.move_name, choice.target_cell.x, choice.target_cell.y, choice.direction]
			var use := MoveUse.new(battle, pack, unit, choice.move_name, choice.target_cell, choice.direction)
			turn_order.use_move(use, random)
		else:
			turn_order.wait(unit, TurnAi.FALLBACK_WAIT)
		if not unit.has_fainted():
			turn_order.end_turn(choice.end_facing)
		var hit_points := []
		for each_unit in battle.units:
			hit_points.append(each_unit.hit_points)
		turns.append([battle.units.find(unit), action, [unit.cell.x, unit.cell.y], hit_points])
	return {"kind": encounter_kind, "seed": battle_seed, "winner": battle.winning_side, "turns": turns}
