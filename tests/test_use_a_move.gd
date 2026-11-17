extends GdUnitTestSuite
## Issue #10 relations (docs/discussion-outputs/use-a-move-opening.md, ruling 2026-11-16-use-a-move-m1): using a
## move checks reach, rolls accuracy and crit per unit hit, does mainline damage to everyone in the footprint, and
## faints units at 0 HP. Every comparison uses the same seed on both sides, so the rolls match.

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
const SEEDS_TRIED := 300
const USER_CELL := Vector2i(2, 5)
## Two steps east of the user: in range for ranged moves, past the 0.5x close range.
const RANGED_TARGET_CELL := Vector2i(4, 5)
const ADJACENT_CELL := Vector2i(3, 5)

var pack: PackData


func before() -> void:
	pack = PackData.shared()


## Relation 1: super effective beats neutral beats resisted, and an immune target takes 0.
func test_type_effectiveness_orders_damage() -> void:
	var super_effective := _damage_to_types("flamethrower", ["grass"])
	var neutral := _damage_to_types("flamethrower", ["normal"])
	var resisted := _damage_to_types("flamethrower", ["water"])
	assert_int(super_effective).is_greater(neutral)
	assert_int(neutral).is_greater(resisted)
	assert_int(_damage_to_types("strength", ["ghost"])).is_equal(0)


## Relation 2: a same-type move does more than the same move off-type, and a crit does more than a non-crit.
func test_same_type_and_crit_add_damage() -> void:
	var battle := _battle()
	var user := _unit(battle, "eevee", USER_CELL, Battle.Side.PLAYER, ["strength"])
	var target := _unit(battle, "machop", ADJACENT_CELL, Battle.Side.ENEMY)
	var same_type := _damage_with_seed(battle, user, "strength", ADJACENT_CELL, target, 1)
	user.types.assign(["fire"])
	var off_type := _damage_with_seed(battle, user, "strength", ADJACENT_CELL, target, 1)
	assert_int(same_type).is_greater(off_type)
	var crit_damage: Array[int] = []
	var plain_damage: Array[int] = []
	for seed_value in SEEDS_TRIED:
		target.hit_points = target.max_hit_points
		var use := _use(battle, user, "strength", ADJACENT_CELL, seed_value)
		(crit_damage if use.outcomes[0].is_critical_hit else plain_damage).append(use.outcomes[0].damage)
	assert_array(crit_damage).is_not_empty()
	assert_array(plain_damage).is_not_empty()
	assert_int(crit_damage.min()).is_greater(plain_damage.max())


## Relation 3: higher Defense takes less from a physical move, higher Special Defense less from a special move.
func test_higher_defenses_take_less() -> void:
	var battle := _battle()
	var user := _unit(battle, "charmander", USER_CELL, Battle.Side.PLAYER, ["strength", "flamethrower"])
	var target := _unit(battle, "machop", ADJACENT_CELL, Battle.Side.ENEMY)
	var low_defense := _damage_with_seed(battle, user, "strength", ADJACENT_CELL, target, 1)
	target.stats["defense"] *= 2
	assert_int(_damage_with_seed(battle, user, "strength", ADJACENT_CELL, target, 1)).is_less(low_defense)
	target.cell = RANGED_TARGET_CELL
	var low_special_defense := _damage_with_seed(battle, user, "flamethrower", RANGED_TARGET_CELL, target, 1)
	target.stats["special_defense"] *= 2
	var high_special_defense := _damage_with_seed(battle, user, "flamethrower", RANGED_TARGET_CELL, target, 1)
	assert_int(high_special_defense).is_less(low_special_defense)


## Relation 4: a 100 percent move hits on every seed, and the same seed and inputs give the same outcome.
func test_sure_moves_always_hit_and_seeds_replay() -> void:
	var battle := _battle()
	var user := _unit(battle, "charmander", USER_CELL, Battle.Side.PLAYER, ["flamethrower"])
	var target := _unit(battle, "machop", RANGED_TARGET_CELL, Battle.Side.ENEMY)
	for seed_value in SEEDS_TRIED:
		target.hit_points = target.max_hit_points
		assert_bool(_use(battle, user, "flamethrower", RANGED_TARGET_CELL, seed_value).outcomes[0].is_hit).is_true()
	for seed_value in SEEDS_TRIED:
		assert_array(_icy_wind_record(seed_value)).is_equal(_icy_wind_record(seed_value))


## Relation 5: a move cannot target a cell out of range; a contact move reaches only adjacent cells; a cell in range
## with nobody on it is allowed, spends the action and changes no HP.
func test_reach_and_empty_targets() -> void:
	var battle := _battle()
	var user := _unit(battle, "charmander", USER_CELL, Battle.Side.PLAYER, ["flamethrower", "strength"])
	var bystander := _unit(battle, "machop", Vector2i(8, 8), Battle.Side.ENEMY)
	var far_cell := USER_CELL + Vector2i(5, 0)
	assert_bool(_move_use(battle, user, "flamethrower", far_cell).is_allowed()).is_false()
	assert_bool(_move_use(battle, user, "strength", RANGED_TARGET_CELL).is_allowed()).is_false()
	for move_name in _roster_move_names():
		if not pack.move(move_name)["contact"]:
			continue
		user.move_names.assign([move_name])
		assert_bool(_move_use(battle, user, move_name, ADJACENT_CELL).is_allowed()).is_true()
		assert_bool(_move_use(battle, user, move_name, RANGED_TARGET_CELL).is_allowed()) \
			.override_failure_message("%s reaches past adjacent" % move_name).is_false()
	user.move_names.assign(["flamethrower"])
	user.stats["speed"] = 999
	var turn_order := TurnOrder.new(battle, _random(1))
	var empty_use := _move_use(battle, user, "flamethrower", RANGED_TARGET_CELL)
	assert_bool(turn_order.use_move(empty_use, _random(1))).is_true()
	assert_bool(turn_order.can_act(user)).is_false()
	assert_int(bystander.hit_points).is_equal(bystander.max_hit_points)
	assert_int(user.hit_points).is_equal(user.max_hit_points)


## Relation 6: a ranged damaging move at range 1 does less than the same move at range 2.
func test_ranged_moves_do_less_at_range_one() -> void:
	for move_name in ["flamethrower", "night-shade"]:
		var battle := _battle()
		var user := _unit(battle, "charmander", USER_CELL, Battle.Side.PLAYER, [move_name])
		var target := _unit(battle, "machop", ADJACENT_CELL, Battle.Side.ENEMY)
		var close := _damage_with_seed(battle, user, move_name, ADJACENT_CELL, target, 1)
		target.cell = RANGED_TARGET_CELL
		var far := _damage_with_seed(battle, user, move_name, RANGED_TARGET_CELL, target, 1)
		assert_int(close).override_failure_message(move_name).is_less(far)


## Relation 7: an area move damages every unit in its footprint, ally or enemy, and no unit outside it.
func test_areas_damage_everyone_inside_and_nobody_outside() -> void:
	var battle := _battle()
	var user := _unit(battle, "eevee", USER_CELL, Battle.Side.PLAYER, ["swift"])
	var units: Array[BattleUnit] = []
	var unit_names := ["charmander", "squirtle", "bulbasaur", "pikachu", "machop"]
	var cells := [Vector2i(3, 5), Vector2i(4, 5), Vector2i(5, 4), Vector2i(1, 5), Vector2i(2, 8)]
	for index in unit_names.size():
		var side := Battle.Side.PLAYER if index % 2 == 0 else Battle.Side.ENEMY
		units.append(_unit(battle, unit_names[index], cells[index], side))
	var use := MoveUse.new(battle, pack, user, "swift", USER_CELL, Facing.Direction.EAST)
	var footprint := use.footprint()
	use.resolve(_random(1))
	var sides_hit := {}
	for unit in units:
		var lost_hit_points := unit.hit_points < unit.max_hit_points
		assert_bool(lost_hit_points).override_failure_message(str(unit.cell)).is_equal(footprint.has(unit.cell))
		if lost_hit_points:
			sides_hit[unit.side] = true
	assert_int(sides_hit.size()).is_equal(2)
	assert_int(user.hit_points).is_equal(user.max_hit_points)


## Relation 8: HP never drops below 0, and a unit at 0 HP has fainted, frees its cell and never gets another turn.
func test_fainted_units_leave_the_battle() -> void:
	var battle := _battle()
	var user := _unit(battle, "charmander", USER_CELL, Battle.Side.PLAYER, ["flamethrower"])
	var target := _unit(battle, "bulbasaur", RANGED_TARGET_CELL, Battle.Side.ENEMY)
	target.hit_points = 1
	_use(battle, user, "flamethrower", RANGED_TARGET_CELL, 1)
	assert_int(target.hit_points).is_equal(0)
	assert_bool(target.has_fainted()).is_true()
	assert_object(battle.unit_at(RANGED_TARGET_CELL)).is_null()
	var turn_order := TurnOrder.new(battle, _random(1))
	for slot in turn_order.forecast(10):
		assert_object(slot.unit).is_not_same(target)


## Relation 9: a unit acts at most once per turn.
func test_a_unit_acts_once_per_turn() -> void:
	var battle := _battle()
	var user := _unit(battle, "charmander", USER_CELL, Battle.Side.PLAYER, ["flamethrower"])
	_unit(battle, "machop", RANGED_TARGET_CELL, Battle.Side.ENEMY)
	user.stats["speed"] = 999
	var turn_order := TurnOrder.new(battle, _random(1))
	assert_bool(turn_order.use_move(_move_use(battle, user, "flamethrower", RANGED_TARGET_CELL), _random(1))).is_true()
	assert_bool(turn_order.use_move(_move_use(battle, user, "flamethrower", RANGED_TARGET_CELL), _random(1))).is_false()


## Relation 10: a status move deals no damage and changes no HP.
func test_status_moves_change_no_hit_points() -> void:
	var battle := _battle()
	var user := _unit(battle, "bulbasaur", USER_CELL, Battle.Side.PLAYER, ["toxic"])
	var target := _unit(battle, "machop", RANGED_TARGET_CELL, Battle.Side.ENEMY)
	for seed_value in SEEDS_TRIED:
		var use := _use(battle, user, "toxic", RANGED_TARGET_CELL, seed_value)
		assert_array(use.outcomes).is_empty()
	assert_int(target.hit_points).is_equal(target.max_hit_points)
	assert_int(user.hit_points).is_equal(user.max_hit_points)


## Relation 11: Self-Destruct leaves its user fainted, whether or not it hits anyone.
func test_self_destruct_faints_its_user() -> void:
	var lonely_battle := _battle()
	var lonely_user := _unit(lonely_battle, "geodude", USER_CELL, Battle.Side.PLAYER, ["self-destruct"])
	_use(lonely_battle, lonely_user, "self-destruct", USER_CELL, 1)
	assert_bool(lonely_user.has_fainted()).is_true()
	var crowded_battle := _battle()
	var crowded_user := _unit(crowded_battle, "geodude", USER_CELL, Battle.Side.PLAYER, ["self-destruct"])
	var neighbour := _unit(crowded_battle, "machop", ADJACENT_CELL, Battle.Side.ENEMY)
	_use(crowded_battle, crowded_user, "self-destruct", USER_CELL, 1)
	assert_bool(crowded_user.has_fainted()).is_true()
	assert_int(neighbour.hit_points).is_less(neighbour.max_hit_points)


## Relation 12: fixed damage does the same to targets with different defenses, and 0 to an immune target.
func test_fixed_damage_ignores_defenses() -> void:
	var battle := _battle()
	var user := _unit(battle, "gastly", USER_CELL, Battle.Side.PLAYER, ["night-shade"])
	var target := _unit(battle, "machop", RANGED_TARGET_CELL, Battle.Side.ENEMY)
	var against_low := _damage_with_seed(battle, user, "night-shade", RANGED_TARGET_CELL, target, 1)
	target.stats["defense"] *= 3
	target.stats["special_defense"] *= 3
	assert_int(_damage_with_seed(battle, user, "night-shade", RANGED_TARGET_CELL, target, 1)).is_equal(against_low)
	assert_int(against_low).is_greater(0)
	target.types.assign(["normal"])
	assert_int(_damage_with_seed(battle, user, "night-shade", RANGED_TARGET_CELL, target, 1)).is_equal(0)


func _battle() -> Battle:
	return Battle.new(BattleGrid.from_rows(PackedStringArray(BOARD_ROWS)))


func _unit(battle: Battle, unit_name: String, cell: Vector2i, side: int, move_names: Array = []) -> BattleUnit:
	var unit := BattleUnit.from_pack(pack, unit_name, LEVEL, cell, Facing.Direction.SOUTH)
	if not move_names.is_empty():
		unit.move_names.assign(move_names)
	battle.add_unit(unit, side)
	return unit


func _random(seed_value: int) -> RandomNumberGenerator:
	var random := RandomNumberGenerator.new()
	random.seed = seed_value
	return random


## A use aimed from the user toward the target cell (the direction cones and lines would take).
func _move_use(battle: Battle, user: BattleUnit, move_name: String, target_cell: Vector2i) -> MoveUse:
	var direction := Facing.direction_of_step(target_cell - user.cell) if target_cell != user.cell else user.facing
	return MoveUse.new(battle, pack, user, move_name, target_cell, direction)


func _use(battle: Battle, user: BattleUnit, move_name: String, target_cell: Vector2i, seed_value: int) -> MoveUse:
	var use := _move_use(battle, user, move_name, target_cell)
	use.resolve(_random(seed_value))
	return use


## Damage one use does to the target, starting the target from full HP.
func _damage_with_seed(
	battle: Battle, user: BattleUnit, move_name: String, target_cell: Vector2i, target: BattleUnit, seed_value: int
) -> int:
	target.hit_points = target.max_hit_points
	var use := _use(battle, user, move_name, target_cell, seed_value)
	assert_int(use.outcomes.size()).is_equal(1)
	return use.outcomes[0].damage


## Damage from a move to a defender whose types are replaced, all else the same.
func _damage_to_types(move_name: String, defender_types: Array) -> int:
	var battle := _battle()
	var user := _unit(battle, "charmander", USER_CELL, Battle.Side.PLAYER, [move_name])
	var target_cell := ADJACENT_CELL if pack.move(move_name)["contact"] else RANGED_TARGET_CELL
	var target := _unit(battle, "machop", target_cell, Battle.Side.ENEMY)
	target.types.assign(defender_types)
	return _damage_with_seed(battle, user, move_name, target_cell, target, 1)


## What Icy Wind (95 percent, a cone) did to three units, from a fresh battle with this seed.
func _icy_wind_record(seed_value: int) -> Array:
	var battle := _battle()
	var user := _unit(battle, "squirtle", USER_CELL, Battle.Side.PLAYER, ["icy-wind"])
	for cell in [Vector2i(3, 5), Vector2i(4, 5), Vector2i(4, 4)]:
		_unit(battle, "machop", cell, Battle.Side.ENEMY)
	var use := MoveUse.new(battle, pack, user, "icy-wind", USER_CELL, Facing.Direction.EAST)
	use.resolve(_random(seed_value))
	var record := []
	for outcome in use.outcomes:
		record.append([outcome.unit.cell, outcome.is_hit, outcome.is_critical_hit, outcome.damage])
	return record


func _roster_move_names() -> Array[String]:
	var names: Array[String] = []
	for unit_name in TestBattleSetup.PLAYER_ROSTER + TestBattleSetup.ENEMY_POOL:
		for move_name in BattleUnit.from_pack(pack, unit_name, LEVEL).move_names:
			if not names.has(move_name):
				names.append(move_name)
	return names
