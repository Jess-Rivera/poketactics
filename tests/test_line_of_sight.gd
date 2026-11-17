extends GdUnitTestSuite
## Issue #18 end-goal test (docs/discussion-outputs/line-of-sight-opening.md and line-of-sight-plan.md; rulings
## 2026-11-16-height-and-sight, 2026-11-17-line-of-sight-rules, 2026-11-17-height-range-all-ranged). Relations
## only. Relation 11 (seeded battles stay deterministic) is the seeded replay test in test_win_lose.gd.

const BOARD_SIZE := 15
const ROW := 7
const USER_CELL := Vector2i(2, ROW)
const BETWEEN_CELL := Vector2i(4, ROW)
const AIMED_CELL := Vector2i(6, ROW)
const WALL_LEVEL := 3
## Flamethrower: a ranged single tile without arcing (a projectile). Rock Blast: ballistics, so arcing.
const DIRECT_MOVE := "flamethrower"
const ARCING_MOVE := "rock-blast"
## A circle centred on a cell at range, without arcing (a blast that bursts on the first unit in its way).
const BLAST_MOVE := "stealth-rock"
## A cone running forward from the user.
const CONE_MOVE := "incinerate"
const MELEE_MOVE := "strength"
const ON_USER_TILE_MOVE := "agility"
const ATTACKER := "charmander"
const OTHER_UNIT := "machop"
const SYMMETRY_SEED := 18
const SYMMETRY_PAIRS := 400
const KNOWN_TAGS := [
	"contact", "charge", "recharge", "protect", "reflectable", "snatch", "mirror", "punch", "sound", "gravity",
	"defrost", "distance", "heal", "authentic", "powder", "bite", "pulse", "ballistics", "mental", "non-sky-battle",
	"dance", "arcing",
]

var pack: PackData


func before() -> void:
	pack = PackData.shared()


## Relation 1: on flat open ground with only the user, every cell in reach is aimable and the move lands there.
func test_open_ground_changes_nothing() -> void:
	var battle := _battle({})
	var user := _add(battle, ATTACKER, USER_CELL, Battle.Side.PLAYER)
	for move_name in _roster_moves():
		var recipe := MoveRecipe.built(pack, user, move_name)
		var aimable := MoveArea.target_cells(battle, recipe, user, user.cell)
		assert_array(MoveArea.walled_cells(battle, recipe, user, user.cell)).override_failure_message(move_name) \
			.is_empty()
		for cell in aimable:
			assert_bool(MoveArea.can_reach(battle.grid, recipe, user.cell, cell)).is_true()
			assert_that(MoveArea.landing_cell(battle, recipe, user, user.cell, cell)).is_equal(cell)


## Relation 2: a wall taller than both ends, on the line, makes the cell unaimable for direct and arcing moves.
func test_a_tall_wall_blocks_direct_and_arcing_moves() -> void:
	var battle := _battle({BETWEEN_CELL: WALL_LEVEL})
	var user := _add(battle, ATTACKER, USER_CELL, Battle.Side.PLAYER)
	for move_name in [DIRECT_MOVE, ARCING_MOVE]:
		var recipe := MoveRecipe.built(pack, user, move_name)
		assert_bool(MoveArea.can_target(battle, recipe, user, user.cell, AIMED_CELL)).override_failure_message(
			move_name
		).is_false()
		assert_array(MoveArea.walled_cells(battle, recipe, user, user.cell)).contains([AIMED_CELL])
		assert_bool(MoveUse.new(battle, pack, user, move_name, AIMED_CELL, Facing.Direction.EAST).is_allowed()) \
			.is_false()


## Relation 3: a wall no taller than the higher end never blocks; at an exact corner, one tall tile does not block
## and two do.
func test_a_wall_no_taller_than_the_higher_end_does_not_block() -> void:
	var from_high := BattleGrid.from_rows(_rows({USER_CELL: WALL_LEVEL, BETWEEN_CELL: WALL_LEVEL}))
	assert_bool(SightLine.is_walled(from_high, USER_CELL, AIMED_CELL)).is_false()
	var to_high := BattleGrid.from_rows(_rows({AIMED_CELL: WALL_LEVEL, BETWEEN_CELL: WALL_LEVEL}))
	assert_bool(SightLine.is_walled(to_high, USER_CELL, AIMED_CELL)).is_false()
	var diagonal_end := USER_CELL + Vector2i(2, 2)
	var corner_tiles := [USER_CELL + Vector2i(1, 0), USER_CELL + Vector2i(0, 1)]
	var one_tall := BattleGrid.from_rows(_rows({corner_tiles[0]: WALL_LEVEL}))
	assert_bool(SightLine.is_walled(one_tall, USER_CELL, diagonal_end)).is_false()
	var both_tall := BattleGrid.from_rows(_rows({corner_tiles[0]: WALL_LEVEL, corner_tiles[1]: WALL_LEVEL}))
	assert_bool(SightLine.is_walled(both_tall, USER_CELL, diagonal_end)).is_true()


## Relation 4: a direct move centred on its aimed cell, aimed past a unit, lands on that unit (an ally too); an
## arcing one lands on the aimed cell; a blast bursts centred on the unit in its way.
func test_a_direct_shot_lands_on_the_first_unit_in_its_way() -> void:
	for move_name in [DIRECT_MOVE, ARCING_MOVE]:
		var battle := _battle({})
		var user := _add(battle, ATTACKER, USER_CELL, Battle.Side.PLAYER)
		user.move_names.assign([move_name])
		var ally := _add(battle, OTHER_UNIT, BETWEEN_CELL, Battle.Side.PLAYER)
		var foe := _add(battle, OTHER_UNIT, AIMED_CELL, Battle.Side.ENEMY)
		var use := MoveUse.new(battle, pack, user, move_name, AIMED_CELL, Facing.Direction.EAST)
		assert_bool(use.is_allowed()).is_true()
		var is_arcing := MoveRecipe.has_tag(use.recipe, MoveRecipe.TAG_ARCING)
		assert_array(use.units_hit()).override_failure_message(move_name).is_equal([foe if is_arcing else ally])
	var blast_battle := _battle({})
	var blaster := _add(blast_battle, ATTACKER, USER_CELL, Battle.Side.PLAYER)
	blaster.move_names.assign([BLAST_MOVE])
	_add(blast_battle, OTHER_UNIT, BETWEEN_CELL, Battle.Side.ENEMY)
	var blast := MoveUse.new(blast_battle, pack, blaster, BLAST_MOVE, AIMED_CELL, Facing.Direction.EAST)
	assert_that(blast.landing_cell()).is_equal(BETWEEN_CELL)
	assert_array(blast.footprint()).is_equal(
		MoveArea.footprint(blast_battle.grid, pack.shapes, blast.recipe, USER_CELL, BETWEEN_CELL, blast.direction)
	)


## Relation 4, corners: a projectile crossing an exact corner stops only when both tiles hold a unit, and then on
## the first in reading order.
func test_a_corner_stops_a_shot_only_when_both_tiles_hold_units() -> void:
	var aimed_cell := USER_CELL + Vector2i(2, 2)
	var upper_tile := USER_CELL + Vector2i(1, 0)
	var lower_tile := USER_CELL + Vector2i(0, 1)
	var battle := _battle({})
	var user := _add(battle, ATTACKER, USER_CELL, Battle.Side.PLAYER)
	var recipe := MoveRecipe.built(pack, user, DIRECT_MOVE)
	_add(battle, OTHER_UNIT, lower_tile, Battle.Side.ENEMY)
	assert_that(MoveArea.landing_cell(battle, recipe, user, user.cell, aimed_cell)).is_equal(aimed_cell)
	_add(battle, OTHER_UNIT, upper_tile, Battle.Side.ENEMY)
	assert_that(MoveArea.landing_cell(battle, recipe, user, user.cell, aimed_cell)).is_equal(upper_tile)


## Relation 5: an area hits every unit in it (units never shelter each other); walls shelter the tiles behind them.
func test_areas_hit_everyone_and_walls_shelter() -> void:
	var near_cell := USER_CELL + Vector2i(1, 0)
	var far_cell := USER_CELL + Vector2i(2, 0)
	var open_battle := _battle({})
	var user := _add(open_battle, ATTACKER, USER_CELL, Battle.Side.PLAYER)
	user.move_names.assign([CONE_MOVE])
	var near := _add(open_battle, OTHER_UNIT, near_cell, Battle.Side.ENEMY)
	var far := _add(open_battle, OTHER_UNIT, far_cell, Battle.Side.ENEMY)
	var cone := MoveUse.new(open_battle, pack, user, CONE_MOVE, USER_CELL, Facing.Direction.EAST)
	assert_array(cone.units_hit()).contains([near, far])
	var walled_battle := _battle({near_cell: WALL_LEVEL})
	var walled_user := _add(walled_battle, ATTACKER, USER_CELL, Battle.Side.PLAYER)
	walled_user.move_names.assign([CONE_MOVE])
	var sheltered := _add(walled_battle, OTHER_UNIT, far_cell, Battle.Side.ENEMY)
	var walled_cone := MoveUse.new(walled_battle, pack, walled_user, CONE_MOVE, USER_CELL, Facing.Direction.EAST)
	assert_array(walled_cone.footprint()).not_contains([far_cell])
	assert_array(walled_cone.units_hit()).not_contains([sheltered])


## Relation 6: melee moves and moves on the user's own tile never need sight, even boxed in by tall tiles.
func test_melee_and_own_tile_moves_never_need_sight() -> void:
	var tall_around := {}
	for grid_y in BOARD_SIZE:
		for grid_x in BOARD_SIZE:
			if Vector2i(grid_x, grid_y) != USER_CELL:
				tall_around[Vector2i(grid_x, grid_y)] = WALL_LEVEL
	var battle := _battle(tall_around)
	var user := _add(battle, ATTACKER, USER_CELL, Battle.Side.PLAYER)
	for move_name in [MELEE_MOVE, ON_USER_TILE_MOVE]:
		var recipe := MoveRecipe.built(pack, user, move_name)
		assert_array(MoveArea.walled_cells(battle, recipe, user, user.cell)).override_failure_message(move_name) \
			.is_empty()
		assert_array(MoveArea.target_cells(battle, recipe, user, user.cell)).is_not_empty()


## Relation 7: sight is symmetric: if A can see B, B can see A.
func test_sight_is_symmetric() -> void:
	var random := RandomNumberGenerator.new()
	random.seed = SYMMETRY_SEED
	var heights := {}
	for grid_y in BOARD_SIZE:
		for grid_x in BOARD_SIZE:
			heights[Vector2i(grid_x, grid_y)] = random.randi_range(0, BattleGrid.HIGHEST_LEVEL)
	var grid := BattleGrid.from_rows(_rows(heights))
	for pair in SYMMETRY_PAIRS:
		var cell_a := Vector2i(random.randi_range(0, BOARD_SIZE - 1), random.randi_range(0, BOARD_SIZE - 1))
		var cell_b := Vector2i(random.randi_range(0, BOARD_SIZE - 1), random.randi_range(0, BOARD_SIZE - 1))
		assert_bool(SightLine.is_walled(grid, cell_a, cell_b)).override_failure_message(
			"%s to %s" % [cell_a, cell_b]
		).is_equal(SightLine.is_walled(grid, cell_b, cell_a))


## Relation 8: tags are known and unrepeated; contact matches the move's contact flag; a ballistics move is arcing.
func test_tags_come_from_the_move_flags() -> void:
	for move_name in _roster_moves():
		var move := pack.move(move_name)
		var tags: Array = move["recipe"]["tags"]
		for tag in tags:
			assert_array(KNOWN_TAGS).override_failure_message("%s: %s" % [move_name, tag]).contains([tag])
			assert_int(tags.count(tag)).is_equal(1)
		assert_bool(tags.has("contact")).override_failure_message(move_name).is_equal(move["contact"])
		assert_bool(tags.has("arcing")).override_failure_message(move_name).is_equal(tags.has("ballistics"))


## Relation 9: range from height is the same for direct and arcing moves.
func test_arcing_does_not_change_reach() -> void:
	var battle := _battle({USER_CELL: WALL_LEVEL})
	var user := _add(battle, ATTACKER, USER_CELL, Battle.Side.PLAYER)
	var direct := MoveRecipe.built(pack, user, DIRECT_MOVE)
	var arcing := direct.duplicate(true)
	arcing["tags"].append(MoveRecipe.TAG_ARCING)
	assert_array(MoveArea.target_cells(battle, arcing, user, user.cell)).is_equal(
		MoveArea.target_cells(battle, direct, user, user.cell)
	)


## Relation 10: the AI scores the unit a shot really hits, so it never fires a projectile into its own ally.
func test_the_ai_scores_the_unit_really_hit() -> void:
	var battle := _battle({})
	var shooter := _add(battle, ATTACKER, USER_CELL, Battle.Side.ENEMY)
	shooter.move_names.assign([DIRECT_MOVE])
	_add(battle, OTHER_UNIT, BETWEEN_CELL, Battle.Side.ENEMY)
	_add(battle, OTHER_UNIT, AIMED_CELL, Battle.Side.PLAYER)
	var choice := TurnAi.choose(battle, pack, shooter)
	if not choice.has_move():
		return
	var recipe := MoveRecipe.built(pack, shooter, choice.move_name)
	assert_bool(MoveArea.can_target(battle, recipe, shooter, choice.stand_cell, choice.target_cell)).is_true()
	var landing := MoveArea.landing_cell(battle, recipe, shooter, choice.stand_cell, choice.target_cell)
	var hit := battle.unit_at(landing)
	assert_bool(hit != null and hit.side == Battle.Side.PLAYER).is_true()


func _roster_moves() -> Array[String]:
	var names: Array[String] = []
	for move_name in pack.moves:
		if pack.move(move_name).get("recipe") != null:
			names.append(move_name)
	return names


## A flat board at level 0, with the given cells at the given levels.
func _rows(levels_by_cell: Dictionary) -> PackedStringArray:
	var rows := PackedStringArray()
	for grid_y in BOARD_SIZE:
		var row := ""
		for grid_x in BOARD_SIZE:
			row += str(levels_by_cell.get(Vector2i(grid_x, grid_y), 0))
		rows.append(row)
	return rows


func _battle(levels_by_cell: Dictionary) -> Battle:
	return Battle.new(BattleGrid.from_rows(_rows(levels_by_cell)))


func _add(battle: Battle, unit_name: String, cell: Vector2i, side: int) -> BattleUnit:
	var unit := BattleUnit.from_pack(pack, unit_name, TestBattleSetup.UNIT_LEVEL, cell, Facing.Direction.EAST)
	battle.add_unit(unit, side)
	return unit
