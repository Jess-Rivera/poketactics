extends GdUnitTestSuite
## Issue #5 relations 2 to 8 (docs/discussion-outputs/pack-loader-plan.md): the stats module follows the mainline
## formulas as ruled (2026-11-15-unit-stats-and-moves, 2026-11-15-damage-and-hit). Relations only, no numbers
## copied from output.

const HIGHEST_BASE := 255
const HIGHEST_LEVEL := 100
const SEEDS_TRIED := 2000
const LEVELS := [1, 5, 20, 50, 100]
const POWERS := [10, 40, 90, 150, 250]
const ATTACK_DEFENSE_PAIRS := [[5, 400], [20, 200], [100, 100], [200, 50], [400, 5]]

var pack: PackData


func before() -> void:
	pack = PackData.shared()


## Relation 2: a higher base never gives a lower stat at the same level, and a higher level never lowers a stat.
func test_stats_never_drop_with_a_higher_base_or_level() -> void:
	var failures: Array[String] = []
	for level in range(1, HIGHEST_LEVEL + 1):
		for base_value in range(1, HIGHEST_BASE):
			if BattleStats.other_stat(base_value + 1, level) < BattleStats.other_stat(base_value, level):
				failures.append("stat drops from base %d to %d at level %d" % [base_value, base_value + 1, level])
			if BattleStats.hit_points(base_value + 1, level) < BattleStats.hit_points(base_value, level):
				failures.append("HP drops from base %d to %d at level %d" % [base_value, base_value + 1, level])
			if level < HIGHEST_LEVEL:
				if BattleStats.other_stat(base_value, level + 1) < BattleStats.other_stat(base_value, level):
					failures.append("stat drops at base %d from level %d" % [base_value, level])
				if BattleStats.hit_points(base_value, level + 1) < BattleStats.hit_points(base_value, level):
					failures.append("HP drops at base %d from level %d" % [base_value, level])
	assert_array(failures).is_empty()


## Relation 3: HP comes out larger than any other stat from the same base and level.
func test_hit_points_exceed_other_stats_from_the_same_base() -> void:
	var failures: Array[String] = []
	for level in range(1, HIGHEST_LEVEL + 1):
		for base_value in range(1, HIGHEST_BASE + 1):
			if BattleStats.hit_points(base_value, level) <= BattleStats.other_stat(base_value, level):
				failures.append("base %d level %d" % [base_value, level])
	assert_array(failures).is_empty()


## Relation 4: super effective beats neutral beats not very effective; immune takes 0. Checked on the core formula
## and through the real type chart (Ember on Grass, Normal, Water; Tackle on Ghost).
func test_type_matchups_order_damage() -> void:
	var failures: Array[String] = []
	for inputs in _damage_inputs():
		var super_effective := _damage_with(inputs, false, 2.0, false)
		var neutral := _damage_with(inputs, false, 1.0, false)
		var resisted := _damage_with(inputs, false, 0.5, false)
		if not (super_effective > neutral and neutral > resisted):
			failures.append("%s gives %d, %d, %d" % [inputs, super_effective, neutral, resisted])
		if _damage_with(inputs, false, 0.0, false) != 0:
			failures.append("%s hurts an immune target" % [inputs])
	assert_array(failures).is_empty()

	var attacker := BattleUnit.from_pack(pack, "charmander", 50)
	var defender := BattleUnit.from_pack(pack, "rattata", 50)
	var damage_on := {}
	for defending_types in [["grass"], ["normal"], ["water"]]:
		defender.types.assign(defending_types)
		damage_on[defending_types[0]] = BattleStats.move_damage(pack, attacker, defender, "ember", false)
	assert_int(damage_on["grass"]).is_greater(damage_on["normal"])
	assert_int(damage_on["normal"]).is_greater(damage_on["water"])
	defender.types.assign(["ghost"])
	assert_int(BattleStats.move_damage(pack, attacker, defender, "tackle", false)).is_equal(0)


## Relation 5: a same-type move beats an otherwise equal move of another type.
func test_same_type_moves_do_more_damage() -> void:
	var failures: Array[String] = []
	for inputs in _damage_inputs():
		if _damage_with(inputs, true, 1.0, false) <= _damage_with(inputs, false, 1.0, false):
			failures.append("%s" % [inputs])
	assert_array(failures).is_empty()


## Relation 6: a crit beats the same hit without one, and a hit that is not immune does at least 1.
func test_critical_hits_do_more_and_every_hit_does_at_least_one() -> void:
	var failures: Array[String] = []
	for inputs in _damage_inputs():
		if _damage_with(inputs, false, 1.0, true) <= _damage_with(inputs, false, 1.0, false):
			failures.append("crit no stronger at %s" % [inputs])
		for multiplier in [0.25, 0.5, 1.0, 2.0, 4.0]:
			if _damage_with(inputs, false, multiplier, false) < 1:
				failures.append("under 1 at %s times %s" % [inputs, multiplier])
	assert_array(failures).is_empty()


func test_status_moves_deal_no_damage() -> void:
	var attacker := BattleUnit.from_pack(pack, "charmander", 50)
	var defender := BattleUnit.from_pack(pack, "bulbasaur", 50)
	assert_int(BattleStats.move_damage(pack, attacker, defender, "growl", false)).is_equal(0)


## Relation 7: the same inputs always give the same damage.
func test_damage_has_no_random_spread() -> void:
	var attacker := BattleUnit.from_pack(pack, "charmander", 50)
	var defender := BattleUnit.from_pack(pack, "bulbasaur", 50)
	var first := BattleStats.move_damage(pack, attacker, defender, "ember", false)
	for repeat in 50:
		assert_int(BattleStats.move_damage(pack, attacker, defender, "ember", false)).is_equal(first)


## Relation 8: 100 percent or no-accuracy moves always hit; a less accurate move hits and misses; a seed replays.
func test_accuracy_rolls() -> void:
	var always := {"accuracy": 100}
	var never_misses := {"accuracy": null}
	var sometimes := {"accuracy": 70}
	var hits := 0
	var random := RandomNumberGenerator.new()
	for seed_value in SEEDS_TRIED:
		random.seed = seed_value
		assert_bool(BattleStats.rolls_hit(always, random)).is_true()
		assert_bool(BattleStats.rolls_hit(never_misses, random)).is_true()
		if BattleStats.rolls_hit(sometimes, random):
			hits += 1
	assert_int(hits).is_greater(0).is_less(SEEDS_TRIED)
	assert_bool(_replays(func(random_source): return BattleStats.rolls_hit(sometimes, random_source))).is_true()


func test_critical_hit_rolls() -> void:
	var crits_at_stage_zero := 0
	var crits_at_stage_two := 0
	var random := RandomNumberGenerator.new()
	for seed_value in SEEDS_TRIED:
		random.seed = seed_value
		assert_bool(BattleStats.rolls_critical_hit(3, random)).is_true()
		if BattleStats.rolls_critical_hit(0, random):
			crits_at_stage_zero += 1
		if BattleStats.rolls_critical_hit(2, random):
			crits_at_stage_two += 1
	assert_int(crits_at_stage_zero).is_greater(0).is_less(SEEDS_TRIED)
	assert_int(crits_at_stage_two).is_greater(crits_at_stage_zero)
	assert_bool(_replays(func(random_source): return BattleStats.rolls_critical_hit(0, random_source))).is_true()


func _damage_inputs() -> Array:
	var inputs := []
	for level in LEVELS:
		for power in POWERS:
			for pair in ATTACK_DEFENSE_PAIRS:
				inputs.append([level, power, pair[0], pair[1]])
	return inputs


func _damage_with(inputs: Array, is_same_type: bool, multiplier: float, is_critical_hit: bool) -> int:
	return BattleStats.damage(inputs[0], inputs[1], inputs[2], inputs[3], is_same_type, multiplier, is_critical_hit)


## The same seed gives the same sequence of results.
func _replays(roll: Callable) -> bool:
	var first_run := []
	var second_run := []
	var random := RandomNumberGenerator.new()
	for run in [first_run, second_run]:
		random.seed = 1234
		for roll_index in 200:
			run.append(roll.call(random))
	return first_run == second_run
