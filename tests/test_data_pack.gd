extends GdUnitTestSuite
## The data pack in data/ (tools/export_pack.py, issue #2), read with Godot's built-in JSON parser, no loader.
## Each test is one relation of the slice's end-goal test (docs/discussion-outputs/data-pack-opening.md); relation 9
## (rerun gives no diff) is `python tools/export_pack.py --check`, run by tools\run-tests.cmd.
## Every test collects all violations, so a failure lists each entry that broke the relation.

const PACK_FOLDER := "res://data"
const STAT_KEYS := ["hp", "attack", "defense", "special_attack", "special_defense", "speed"]
const REGIONS := ["alola", "galar", "hisui", "paldea"]
const TRANSFORMATION_KINDS := ["mega", "gigantamax", "primal"]
const LEARN_METHODS := ["level-up", "machine", "egg", "tutor"]
const PREFERRED_LEARNSET_GAME := "scarlet-violet"
const SKIPPED_LEARNSET_GAMES := ["legends-arceus", "champions"]
const ALLOWED_MULTIPLIERS := [0.0, 0.5, 1.0, 2.0]
const ATTACK_TYPE_COUNT := 18
## Name parts of variants the variant-scope ruling leaves out (2026-11-15-variant-scope).
const EXCLUDED_NAME_PARTS := ["totem", "cap", "mega", "gmax", "primal"]

var units: Dictionary
var moves: Dictionary
var abilities: Dictionary
var types: Dictionary


func before() -> void:
	units = _read_pack_file("units.json")
	moves = _read_pack_file("moves.json")
	abilities = _read_pack_file("abilities.json")
	types = _read_pack_file("types.json")


func test_every_pack_file_parses_and_has_entries() -> void:
	for table in [units, moves, abilities, types]:
		assert_int(table.size()).is_greater(0)


## Relation 1: six base stats above 0 and one or two types, each one of the 18 attack types.
func test_every_unit_has_six_positive_base_stats_and_one_or_two_known_types() -> void:
	var failures: Array[String] = []
	for unit_name in units:
		var unit: Dictionary = units[unit_name]
		var stats: Dictionary = unit["base_stats"]
		if stats.keys().size() != STAT_KEYS.size():
			failures.append("%s has stats %s" % [unit_name, stats.keys()])
		for stat_key in STAT_KEYS:
			if float(stats.get(stat_key, 0)) <= 0:
				failures.append("%s %s is not above 0" % [unit_name, stat_key])
		var unit_types: Array = unit["types"]
		if unit_types.size() < 1 or unit_types.size() > 2:
			failures.append("%s has %d types" % [unit_name, unit_types.size()])
		for type_name in unit_types:
			if not types.has(type_name):
				failures.append("%s has unknown type %s" % [unit_name, type_name])
	assert_int(types.size()).is_equal(ATTACK_TYPE_COUNT)
	assert_array(failures).is_empty()


## Relation 2: units are exactly the species defaults plus regional forms.
func test_units_are_exactly_species_defaults_plus_regional_forms() -> void:
	var failures: Array[String] = []
	var defaults_per_species := {}
	for unit_name in units:
		var unit: Dictionary = units[unit_name]
		var regional_form = unit["regional_form"]
		if unit["is_species_default"]:
			defaults_per_species[unit["species"]] = defaults_per_species.get(unit["species"], 0) + 1
			if regional_form != null:
				failures.append("%s is a species default with a regional form" % unit_name)
		elif not regional_form in REGIONS:
			failures.append("%s is neither a species default nor a regional form" % unit_name)
		elif not (regional_form as String) in (unit_name as String).split("-"):
			failures.append("%s says regional form %s but its name does not" % [unit_name, regional_form])
		for part in (unit_name as String).split("-"):
			if part in EXCLUDED_NAME_PARTS:
				failures.append("%s is an excluded variant" % unit_name)
	for unit_name in units:
		var species: String = units[unit_name]["species"]
		if defaults_per_species.get(species, 0) != 1:
			failures.append("species %s has %d default units" % [species, defaults_per_species.get(species, 0)])
	assert_array(failures).is_empty()


## Relation 3: every Mega, Gigantamax and Primal hangs off an existing base unit and is not itself a unit.
func test_every_transformation_belongs_to_a_unit_and_is_not_a_unit() -> void:
	var failures: Array[String] = []
	var transformation_count := 0
	for unit_name in units:
		for transformation in units[unit_name]["transformations"]:
			transformation_count += 1
			var name: String = transformation["name"]
			if units.has(name):
				failures.append("%s is also a unit" % name)
			if not transformation["kind"] in TRANSFORMATION_KINDS:
				failures.append("%s has kind %s" % [name, transformation["kind"]])
			if not name.begins_with(units[unit_name]["species"]):
				failures.append("%s is attached to %s, another species" % [name, unit_name])
	assert_int(transformation_count).is_greater(0)
	assert_array(failures).is_empty()


## Relation 4: every name the pack points at exists in it.
func test_every_referenced_name_exists() -> void:
	var failures: Array[String] = []
	for unit_name in units:
		var unit: Dictionary = units[unit_name]
		var battle_forms: Array = [unit]
		battle_forms.append_array(unit["transformations"])
		for battle_form in battle_forms:
			for ability_entry in battle_form["abilities"]:
				if not abilities.has(ability_entry["ability"]):
					failures.append("%s has unknown ability %s" % [unit_name, ability_entry["ability"]])
			for type_name in battle_form["types"]:
				if not types.has(type_name):
					failures.append("%s has unknown type %s" % [unit_name, type_name])
		for entry in unit["learnset"]["moves"]:
			if not moves.has(entry["move"]):
				failures.append("%s learns unknown move %s" % [unit_name, entry["move"]])
		for evolution in unit["evolutions"]:
			if not units.has(evolution["into"]):
				failures.append("%s evolves into unknown unit %s" % [unit_name, evolution["into"]])
	for move_name in moves:
		if not types.has(moves[move_name]["type"]):
			failures.append("move %s has unknown type %s" % [move_name, moves[move_name]["type"]])
	assert_array(failures).is_empty()


## Relation 5: an 18 by 18 chart of 0, 0.5, 1 and 2; Fire on Grass beats neutral; Normal on Ghost is 0.
func test_type_chart_is_complete_and_follows_mainline_rules() -> void:
	var failures: Array[String] = []
	for attacking in types:
		var against: Dictionary = types[attacking]["against"]
		if against.size() != ATTACK_TYPE_COUNT:
			failures.append("%s has %d chart entries" % [attacking, against.size()])
		for defending in against:
			if not types.has(defending):
				failures.append("%s against unknown type %s" % [attacking, defending])
			if not float(against[defending]) in ALLOWED_MULTIPLIERS:
				failures.append("%s against %s is %s" % [attacking, defending, against[defending]])
	assert_array(failures).is_empty()
	assert_float(float(types["fire"]["against"]["grass"])).is_greater(float(types["fire"]["against"]["normal"]))
	assert_float(float(types["normal"]["against"]["ghost"])).is_equal(0.0)


## Relation 6: at least one level-up move each; every entry is one of the four methods; level-up entries carry a level.
func test_every_learnset_has_level_up_moves_and_only_the_four_methods() -> void:
	var failures: Array[String] = []
	for unit_name in units:
		var level_up_count := 0
		for entry in units[unit_name]["learnset"]["moves"]:
			var method: String = entry["method"]
			if not method in LEARN_METHODS:
				failures.append("%s learns %s by %s" % [unit_name, entry["move"], method])
			if method == "level-up":
				level_up_count += 1
				if not entry.has("level") or entry["level"] == null or float(entry["level"]) < 0:
					failures.append("%s level-up move %s has no level" % [unit_name, entry["move"]])
			elif entry.has("level"):
				failures.append("%s %s move %s has a level" % [unit_name, method, entry["move"]])
		if level_up_count == 0:
			failures.append("%s has no level-up moves" % unit_name)
	assert_array(failures).is_empty()


## Relation 7: one learnset game per unit, Scarlet/Violet whenever it has level-up data there, never a skipped game.
func test_every_learnset_comes_from_the_ruled_game() -> void:
	var failures: Array[String] = []
	for unit_name in units:
		var learnset: Dictionary = units[unit_name]["learnset"]
		var game: String = learnset["game"]
		var available: Array = learnset["games_with_level_up"]
		if not game in available:
			failures.append("%s uses %s, which has no level-up data for it" % [unit_name, game])
		if game in SKIPPED_LEARNSET_GAMES or available.any(func(name): return name in SKIPPED_LEARNSET_GAMES):
			failures.append("%s considers a skipped game" % unit_name)
		if PREFERRED_LEARNSET_GAME in available and game != PREFERRED_LEARNSET_GAME:
			failures.append("%s uses %s although Scarlet/Violet has its level-up data" % [unit_name, game])
	assert_array(failures).is_empty()


## Relation 8: every unit, move, ability and type has an English name.
func test_every_entry_has_an_english_name() -> void:
	var failures: Array[String] = []
	for table in [units, moves, abilities, types]:
		for entry_name in table:
			if str(table[entry_name].get("english_name", "")).strip_edges() == "":
				failures.append("%s has no English name" % entry_name)
	for unit_name in units:
		for transformation in units[unit_name]["transformations"]:
			if str(transformation.get("english_name", "")).strip_edges() == "":
				failures.append("%s has no English name" % transformation["name"])
	assert_array(failures).is_empty()


## Relation 10: a regional unit evolves into the same region's form of its target species when one exists.
func test_regional_units_evolve_into_their_own_regions_forms() -> void:
	var failures: Array[String] = []
	var regional_unit_of := {}
	for unit_name in units:
		var unit: Dictionary = units[unit_name]
		if unit["regional_form"] != null:
			regional_unit_of["%s/%s" % [unit["species"], unit["regional_form"]]] = unit_name
	var checked := 0
	for unit_name in units:
		var unit: Dictionary = units[unit_name]
		if unit["regional_form"] == null:
			continue
		for evolution in unit["evolutions"]:
			var target_species: String = units[evolution["into"]]["species"]
			var key := "%s/%s" % [target_species, unit["regional_form"]]
			if regional_unit_of.has(key):
				checked += 1
				if evolution["into"] != regional_unit_of[key]:
					failures.append("%s evolves into %s, not %s" % [unit_name, evolution["into"], regional_unit_of[key]])
	assert_int(checked).is_greater(0)
	assert_array(failures).is_empty()


func _read_pack_file(file_name: String) -> Dictionary:
	var text := FileAccess.get_file_as_string("%s/%s" % [PACK_FOLDER, file_name])
	var parsed = JSON.parse_string(text)
	assert_bool(parsed is Dictionary).override_failure_message("%s did not parse" % file_name).is_true()
	return parsed if parsed is Dictionary else {}
