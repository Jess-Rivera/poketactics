extends GdUnitTestSuite
## Issue #27 end-goal test (docs/discussion-outputs/move-recipes-plan.md, ruling 2026-11-17-move-recipes-build):
## every roster move builds from its recipe and resolves. The parity fixture that proved #27 changed nothing was
## retired in #17 (facing-height-plan.md D1), since facing and height change damage.

const OVERRIDES_PATH := "res://authored/move_recipe_overrides.json"
const BOARD_SIZE := 15
const UNHANDLED_ONLY_MOVE := "agility"

var pack: PackData
var roster_moves: Array


func before() -> void:
	pack = PackData.shared()
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


func _seeded(seed_value: int) -> RandomNumberGenerator:
	var random := RandomNumberGenerator.new()
	random.seed = seed_value
	return random

