extends GdUnitTestSuite
## Issue #9 relations (docs/discussion-outputs/move-schema-opening.md, ruling 2026-11-16-move-shapes-and-range):
## every roster move has a valid grid entry, defaults follow pokeapi facts, and footprints behave as shapes should.
## Relation 7 (resolving twice gives identical output) is checked by tools/export_pack.py --check in
## tools/run-tests.cmd.

const OVERRIDES_PATH := "res://authored/move_grid_overrides.json"
const ALLOWED_PAIRS := {
	"single": ["self", "other", "point"],
	"line": ["self", "point"],
	"cone": ["self"],
	"circle": ["self", "other", "point"],
}
const SHAPE_SIZE_FIELDS := {"single": [], "line": ["length"], "cone": ["radius", "spread_degrees"], "circle": ["radius"]}
const COMMON_FIELDS := [
	"shape", "target", "range_min", "range_max", "close_penalty", "sr_cost", "tile_element", "arcing", "payload"
]
const RADIUS_LIMIT := 50
const SPREAD_STEP := 15
const RADII_TRIED := [1, 2, 3, 4, 6, 10]
const BOARD_SIZE := 15

var pack: PackData
var overrides: Dictionary


func before() -> void:
	pack = PackData.shared()
	overrides = JSON.parse_string(FileAccess.get_file_as_string(OVERRIDES_PATH))


## Relation 1: every move a roster unit knows has a grid entry, and every entry is a valid shape and target pair
## with exactly the fields its shape needs. Every move in the pack says whether it makes contact.
func test_every_roster_move_has_a_valid_entry() -> void:
	var failures: Array[String] = []
	for move_name in _roster_move_names():
		if pack.move(move_name)["grid"] == null:
			failures.append("%s has no grid entry" % move_name)
	for move_name in pack.moves:
		var move: Dictionary = pack.moves[move_name]
		if not move["contact"] is bool:
			failures.append("%s has no contact flag" % move_name)
		if move["grid"] == null:
			continue
		var entry: Dictionary = move["grid"]
		if not ALLOWED_PAIRS.has(entry["shape"]) or not ALLOWED_PAIRS[entry["shape"]].has(entry["target"]):
			failures.append("%s: %s from %s is not an allowed pair" % [move_name, entry["shape"], entry["target"]])
			continue
		var expected_fields: Array = COMMON_FIELDS + SHAPE_SIZE_FIELDS[entry["shape"]]
		for field in expected_fields:
			if not entry.has(field):
				failures.append("%s is missing %s" % [move_name, field])
		for field in entry:
			if not expected_fields.has(field):
				failures.append("%s has a field its shape does not use: %s" % [move_name, field])
	assert_array(failures).is_empty()


## Relation 2: every override names a move in the pack, and every overridden field is a schema field.
func test_overrides_name_real_moves_and_fields() -> void:
	var schema_fields: Array = COMMON_FIELDS + ["length", "radius", "spread_degrees"]
	var failures: Array[String] = []
	for move_name in overrides:
		if not pack.moves.has(move_name):
			failures.append("override names unknown move %s" % move_name)
		for field in overrides[move_name]:
			if not schema_fields.has(field):
				failures.append("%s overrides unknown field %s" % [move_name, field])
	assert_array(failures).is_empty()


## Relation 3: with the same pokeapi target, a contact move never reaches farther than a non-contact move, unless
## its range is overridden.
func test_contact_moves_never_outreach_ranged_moves() -> void:
	var farthest_contact := {}
	var nearest_ranged := {}
	for move_name in _entries_without_override("range_max"):
		var move: Dictionary = pack.moves[move_name]
		var reach := int(move["grid"]["range_max"])
		var target: String = move["target"]
		if move["contact"]:
			farthest_contact[target] = maxi(reach, farthest_contact.get(target, 0))
		else:
			nearest_ranged[target] = mini(reach, nearest_ranged.get(target, 1 << 30))
	for target in farthest_contact:
		if nearest_ranged.has(target):
			assert_int(farthest_contact[target]).is_less_equal(nearest_ranged[target])


## Relation 4: an area hits exactly the units standing in its footprint, whatever their side; a circle around the
## user leaves the user out; a single {self} move hits only the user.
func test_areas_hit_exactly_the_units_inside_whatever_their_side() -> void:
	var battle := _board_full_of_units()
	var centre := Vector2i(BOARD_SIZE / 2, BOARD_SIZE / 2)
	var user := battle.unit_at(centre)
	for move_name in overrides:
		var entry: Dictionary = pack.move(move_name)["grid"]
		var target_cell := centre if entry["target"] == "self" else centre + Vector2i(2, 0)
		for direction in Facing.ALL_DIRECTIONS:
			var hit := MoveArea.units_hit(battle, pack.shapes, entry, user, target_cell, direction)
			var expected := {}
			for cell in MoveArea.footprint(pack.shapes, entry, centre, target_cell, direction):
				if battle.grid.contains(cell):
					expected[battle.unit_at(cell)] = true
			assert_int(hit.size()).override_failure_message(move_name).is_equal(expected.size())
			for unit in hit:
				assert_bool(expected.has(unit)).override_failure_message(move_name).is_true()
			if entry["shape"] == "single" and entry["target"] == "self":
				assert_int(hit.size()).is_equal(1)
				assert_object(hit[0]).is_same(user)
			if entry["shape"] == "circle" and entry["target"] == "self":
				assert_bool(hit.has(user)).override_failure_message(move_name).is_false()
			if entry["shape"] in ["cone", "circle"]:
				var sides := {}
				for unit in hit:
					sides[unit.side] = true
				assert_int(sides.size()).override_failure_message("%s hits only one side" % move_name).is_equal(2)


## Relation 5: lower PP never gives a cheaper strike rank cost than higher PP, unless the cost is overridden.
func test_lower_pp_never_costs_less() -> void:
	var names := _entries_without_override("sr_cost")
	for first in names:
		for second in names:
			var first_move: Dictionary = pack.moves[first]
			var second_move: Dictionary = pack.moves[second]
			if first_move["pp"] != null and second_move["pp"] != null and first_move["pp"] < second_move["pp"]:
				assert_int(int(first_move["grid"]["sr_cost"])).override_failure_message(
					"%s costs less than %s" % [first, second]
				).is_greater_equal(int(second_move["grid"]["sr_cost"]))


## Relation 6: a damaging move leaves its own type on the tiles it hits; a status move leaves none, unless
## overridden.
func test_tile_element_follows_the_move_type() -> void:
	for move_name in _entries_without_override("tile_element"):
		var move: Dictionary = pack.moves[move_name]
		if move["damage_class"] == "status":
			assert_object(move["grid"]["tile_element"]).override_failure_message(move_name).is_null()
		else:
			assert_str(move["grid"]["tile_element"]).override_failure_message(move_name).is_equal(move["type"])


## Relation 8: a shape aimed north, south or west covers the east-aimed tiles turned by quarter turns.
func test_footprints_rotate_with_the_aim() -> void:
	var entries: Array[Dictionary] = [
		{"shape": "line", "target": "self", "length": 5},
		{"shape": "line", "target": "point", "length": 3},
		{"shape": "circle", "target": "self", "radius": 3},
	]
	for spread in [15, 60, 90, 135, 180, 270, 360]:
		entries.append({"shape": "cone", "target": "self", "radius": 4, "spread_degrees": spread})
	for entry in entries:
		var east := _offset_set(entry, Facing.Direction.EAST)
		for direction in [Facing.Direction.SOUTH, Facing.Direction.WEST, Facing.Direction.NORTH]:
			var expected := {}
			for offset in east:
				var turned: Vector2i = offset
				# One clockwise quarter turn per step from east (grid y grows south): (x, y) becomes (-y, x).
				for quarter in _quarter_turns_from_east(direction):
					turned = Vector2i(-turned.y, turned.x)
				expected[turned] = true
			assert_dict(_offset_set(entry, direction)).override_failure_message(str(entry)).is_equal(expected)
		if entry["shape"] == "cone":
			assert_bool(east.has(Vector2i(1, 0))).is_true()


## Relation 9: a circle is symmetric about its origin; a cone lies inside the circle of the same radius; a larger
## radius or spread never covers fewer tiles.
func test_circles_and_cones_nest() -> void:
	for radius in RADII_TRIED + [RADIUS_LIMIT]:
		var circle := _offset_set({"shape": "circle", "target": "self", "radius": radius}, Facing.Direction.EAST)
		for offset in circle:
			for mirrored in [Vector2i(-offset.x, offset.y), Vector2i(offset.x, -offset.y), Vector2i(offset.y, offset.x)]:
				assert_bool(circle.has(mirrored)).override_failure_message("radius %d at %s" % [radius, offset]).is_true()
	for radius in RADII_TRIED:
		var circle := _offset_set({"shape": "circle", "target": "self", "radius": radius}, Facing.Direction.EAST)
		var wider_circle := _offset_set({"shape": "circle", "target": "self", "radius": radius + 1}, Facing.Direction.EAST)
		_assert_subset(circle, wider_circle, "circle %d inside %d" % [radius, radius + 1])
		var previous_cone := {}
		for spread in range(SPREAD_STEP, 360 + 1, SPREAD_STEP):
			var cone := _offset_set(
				{"shape": "cone", "target": "self", "radius": radius, "spread_degrees": spread}, Facing.Direction.EAST
			)
			_assert_subset(cone, circle, "cone %d %d inside circle" % [radius, spread])
			_assert_subset(previous_cone, cone, "cone %d grows with spread at %d" % [radius, spread])
			previous_cone = cone
		assert_dict(previous_cone).override_failure_message("a full-turn cone is the circle").is_equal(circle)


func _roster_move_names() -> Array[String]:
	var names: Array[String] = []
	for unit_name in TestBattleSetup.PLAYER_ROSTER + TestBattleSetup.ENEMY_POOL:
		var unit := BattleUnit.from_pack(pack, unit_name, TestBattleSetup.UNIT_LEVEL, Vector2i.ZERO, Facing.Direction.SOUTH)
		for move_name in unit.move_names:
			if not names.has(move_name):
				names.append(move_name)
	return names


## Moves with a grid entry whose override leaves this field to the derived default.
func _entries_without_override(field: String) -> Array[String]:
	var names: Array[String] = []
	for move_name in overrides:
		if pack.moves.has(move_name) and pack.moves[move_name]["grid"] != null and not overrides[move_name].has(field):
			names.append(move_name)
	return names


## A flat board with a unit on every cell, sides alternating like a chessboard, all with hit points.
func _board_full_of_units() -> Battle:
	var rows: Array[String] = []
	for row_index in BOARD_SIZE:
		rows.append("0".repeat(BOARD_SIZE))
	var battle := Battle.new(BattleGrid.from_rows(PackedStringArray(rows)))
	for grid_y in BOARD_SIZE:
		for grid_x in BOARD_SIZE:
			var unit := BattleUnit.new(Vector2i(grid_x, grid_y))
			unit.hit_points = 1
			battle.add_unit(unit, Battle.Side.PLAYER if (grid_x + grid_y) % 2 == 0 else Battle.Side.ENEMY)
	return battle


## A shape's footprint as offsets from its origin (the user, or the point for a point target), as a set.
func _offset_set(entry: Dictionary, direction: Facing.Direction) -> Dictionary:
	var origin := Vector2i(100, 100)
	var offsets := {}
	for cell in MoveArea.footprint(pack.shapes, entry, origin, origin, direction):
		offsets[cell - origin] = true
	return offsets


func _quarter_turns_from_east(direction: Facing.Direction) -> Array:
	match direction:
		Facing.Direction.SOUTH:
			return [1]
		Facing.Direction.WEST:
			return [1, 2]
		_:
			return [1, 2, 3]


func _assert_subset(smaller: Dictionary, larger: Dictionary, label: String) -> void:
	for offset in smaller:
		assert_bool(larger.has(offset)).override_failure_message("%s: %s" % [label, offset]).is_true()
