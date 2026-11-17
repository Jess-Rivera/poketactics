extends GdUnitTestSuite
## Issue #17 end-goal test (docs/discussion-outputs/facing-height-plan.md; rulings 2026-11-16-facing-arcs,
## 2026-11-16-height-and-sight, 2026-11-17-facing-height-rules). Relations only. Relation 10 (seeded battles stay
## deterministic, now on the height map with facing in play) is the seeded replay test in test_win_lose.gd.

const BOARD_SIZE := 15
const CENTRE := Vector2i(7, 7)
const MELEE_MOVE := "strength"
const RANGED_MOVE := "flamethrower"
const FIXED_DAMAGE_MOVE := "night-shade"
const ATTACKER := "machop"
const DEFENDER := "eevee"
## Night Shade is Ghost, which a Normal defender is immune to.
const FIXED_DAMAGE_DEFENDER := "machop"
## Far enough that every 2:1 cell of the arc chart (8 across, 4 deep) and beyond is checked.
const ARC_CHECK_STEPS := 8

var pack: PackData


func before() -> void:
	pack = PackData.shared()


## Relation 1: same attacker and defender, only the attacker's cell changes: back beats side, side beats front.
func test_back_beats_side_beats_front() -> void:
	var front := _melee_damage_from(Vector2i(0, -1), 0, 0)
	var side := _melee_damage_from(Vector2i(1, 0), 0, 0)
	var back := _melee_damage_from(Vector2i(0, 1), 0, 0)
	assert_int(back).is_greater(side)
	assert_int(side).is_greater(front)


## Relation 2: cells exactly on the 2:1 line are front or back, never side, at any distance and facing; one step
## further sideways is side.
func test_the_two_to_one_line_is_front_or_back() -> void:
	for facing in Facing.ALL_DIRECTIONS:
		var forward_step := Facing.grid_step(facing)
		var sideways_step := Vector2i(-forward_step.y, forward_step.x)
		for forward in range(-ARC_CHECK_STEPS, ARC_CHECK_STEPS + 1):
			if forward == 0:
				continue
			for sideways_sign in [-1, 1]:
				var sideways: int = sideways_sign * 2 * absi(forward)
				var on_line := CENTRE + forward_step * forward + sideways_step * sideways
				var expected := Facing.Arc.FRONT if forward > 0 else Facing.Arc.BACK
				var label := "facing %d, forward %d, sideways %d" % [facing, forward, sideways]
				assert_int(Facing.arc_of(CENTRE, facing, on_line)).override_failure_message(label).is_equal(expected)
				var past_line: Vector2i = on_line + sideways_step * sideways_sign
				assert_int(Facing.arc_of(CENTRE, facing, past_line)).override_failure_message(label).is_equal(
					Facing.Arc.SIDE
				)


## Relation 3: same pair, only height changes: attacking down beats flat, flat beats attacking up.
func test_attacking_down_beats_flat_beats_up() -> void:
	var down := _melee_damage_from(Vector2i(0, -1), 1, 0)
	var flat := _melee_damage_from(Vector2i(0, -1), 0, 0)
	var up := _melee_damage_from(Vector2i(0, -1), 0, 1)
	assert_int(down).is_greater(flat)
	assert_int(flat).is_greater(up)


## Relation 4: the height factor stops at 2 levels, down and up.
func test_height_factor_is_capped_at_two_levels() -> void:
	assert_int(_ranged_damage_from(Vector2i(0, -2), 3, 0)).is_equal(_ranged_damage_from(Vector2i(0, -2), 2, 0))
	assert_int(_ranged_damage_from(Vector2i(0, -2), 0, 3)).is_equal(_ranged_damage_from(Vector2i(0, -2), 0, 2))


## Relation 5: a ranged move's reach from higher ground covers its flat reach; from lower ground it is a subset of
## it; it never drops below its min range.
func test_ranged_reach_grows_from_above_and_shrinks_from_below() -> void:
	var recipe := MoveRecipe.built(pack, BattleUnit.new(), RANGED_MOVE)
	var flat := MoveArea.target_cells(_board(0, 0), recipe, BattleUnit.new(), CENTRE)
	var from_above := MoveArea.target_cells(_board(4, 0), recipe, BattleUnit.new(), CENTRE)
	var from_below := MoveArea.target_cells(_board(0, 4), recipe, BattleUnit.new(), CENTRE)
	assert_array(from_above).contains(flat)
	assert_int(from_above.size()).is_greater(flat.size())
	assert_array(flat).contains(from_below)
	assert_int(from_below.size()).is_less(flat.size())
	var from_far_below := MoveArea.target_cells(_board(0, BattleGrid.HIGHEST_LEVEL), recipe, BattleUnit.new(), CENTRE)
	var range_min := int(recipe["shape"]["range_min"])
	for cell in flat:
		if MoveArea.distance(CENTRE, cell) == range_min:
			assert_array(from_far_below).contains([cell])


## Relation 6: range change never shrinks as the height difference grows, is never more than one tile per level,
## takes ever more levels for each further tile (diminishing), and mirrors exactly when attacking up.
func test_range_change_from_height_is_diminishing_and_symmetric() -> void:
	var levels_for_tile: Array[int] = []
	for levels in range(1, BattleGrid.HIGHEST_LEVEL + 1):
		var change := BattleStats.range_change_from_height(levels)
		assert_int(change).is_greater_equal(BattleStats.range_change_from_height(levels - 1))
		assert_int(change).is_less_equal(levels)
		assert_int(BattleStats.range_change_from_height(-levels)).is_equal(-change)
		if change > BattleStats.range_change_from_height(levels - 1):
			levels_for_tile.append(levels)
	for index in range(2, levels_for_tile.size()):
		var gap := levels_for_tile[index] - levels_for_tile[index - 1]
		assert_int(gap).is_greater(levels_for_tile[index - 1] - levels_for_tile[index - 2])


## Relation 7: a melee move's reach is the same at any height.
func test_melee_reach_ignores_height() -> void:
	var recipe := MoveRecipe.built(pack, BattleUnit.new(), MELEE_MOVE)
	var flat := MoveArea.target_cells(_board(0, 0), recipe, BattleUnit.new(), CENTRE)
	assert_array(MoveArea.target_cells(_board(1, 0), recipe, BattleUnit.new(), CENTRE)).is_equal(flat)
	assert_array(MoveArea.target_cells(_board(0, 1), recipe, BattleUnit.new(), CENTRE)).is_equal(flat)


## Relation 8: fixed damage is the same from any arc and any height.
func test_fixed_damage_ignores_facing_and_height() -> void:
	var front_flat := _fixed_damage_from(Vector2i(0, -2), 0, 0)
	assert_int(front_flat).is_greater(0)
	assert_int(_fixed_damage_from(Vector2i(0, 2), 0, 0)).is_equal(front_flat)
	assert_int(_fixed_damage_from(Vector2i(2, 0), 0, 0)).is_equal(front_flat)
	assert_int(_fixed_damage_from(Vector2i(0, -2), 2, 0)).is_equal(front_flat)
	assert_int(_fixed_damage_from(Vector2i(0, -2), 0, 2)).is_equal(front_flat)


## Relation 9: an area bigger than one tile centred away from the user is measured from its centre, and the unit on
## the centre from the user; single-tile, forward and user-centred moves are measured from the user.
func test_hit_origin_is_the_blast_centre_only_for_distant_areas() -> void:
	var user_cell := CENTRE
	var aimed_cell := CENTRE + Vector2i(3, 0)
	var beside_centre := aimed_cell + Vector2i(0, 1)
	var blast := {"shape": {"anchor": "centered", "kind": "circle", "radius": 1, "angle": 360, "range_min": 1,
		"range_max": 4}}
	assert_that(MoveArea.hit_origin(blast, user_cell, aimed_cell, beside_centre)).is_equal(aimed_cell)
	assert_that(MoveArea.hit_origin(blast, user_cell, aimed_cell, aimed_cell)).is_equal(user_cell)
	for move_name in [RANGED_MOVE, "incinerate", "self-destruct"]:
		var recipe := MoveRecipe.built(pack, BattleUnit.new(), move_name)
		assert_that(MoveArea.hit_origin(recipe, user_cell, aimed_cell, beside_centre)).override_failure_message(
			move_name
		).is_equal(user_cell)


## A flat board with the attacker's cell at attacker_level and the defender's (CENTRE) at defender_level; every
## other cell is at defender_level.
func _board(attacker_level: int, defender_level: int, attacker_cell: Vector2i = CENTRE) -> Battle:
	var rows: Array[String] = []
	for grid_y in BOARD_SIZE:
		var row := ""
		for grid_x in BOARD_SIZE:
			row += str(attacker_level if Vector2i(grid_x, grid_y) == attacker_cell else defender_level)
		rows.append(row)
	return Battle.new(BattleGrid.from_rows(PackedStringArray(rows)))


func _melee_damage_from(offset: Vector2i, attacker_level: int, defender_level: int) -> int:
	return _damage_from(MELEE_MOVE, offset, attacker_level, defender_level)


func _ranged_damage_from(offset: Vector2i, attacker_level: int, defender_level: int) -> int:
	return _damage_from(RANGED_MOVE, offset, attacker_level, defender_level)


func _fixed_damage_from(offset: Vector2i, attacker_level: int, defender_level: int) -> int:
	return _damage_from(FIXED_DAMAGE_MOVE, offset, attacker_level, defender_level, FIXED_DAMAGE_DEFENDER)


## The non-crit damage of a move on a defender at CENTRE facing north, from an attacker at CENTRE + offset.
func _damage_from(
	move_name: String, offset: Vector2i, attacker_level: int, defender_level: int, defender_name: String = DEFENDER
) -> int:
	var attacker_cell := CENTRE + offset
	var battle := _board(attacker_level, defender_level, attacker_cell)
	var attacker := BattleUnit.from_pack(pack, ATTACKER, TestBattleSetup.UNIT_LEVEL, attacker_cell)
	attacker.move_names.assign([move_name])
	battle.add_unit(attacker, Battle.Side.PLAYER)
	var defender := BattleUnit.from_pack(pack, defender_name, TestBattleSetup.UNIT_LEVEL, CENTRE, Facing.Direction.NORTH)
	battle.add_unit(defender, Battle.Side.ENEMY)
	return MoveUse.hit_damage(battle, pack, attacker, defender, move_name, attacker_cell, CENTRE, false)
