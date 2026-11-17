extends GdUnitTestSuite
## Issues #9 and #27 relations (move-schema-opening.md, move-recipes-plan.md; rulings
## 2026-11-16-move-shapes-and-range, 2026-11-17-move-recipe-structure): every roster move has a valid recipe,
## defaults follow pokeapi facts, and footprints behave as shapes should. Relation 7 (resolving twice gives
## identical output) is checked by tools/export_pack.py --check in tools/run-tests.cmd.

const OVERRIDES_PATH := "res://authored/move_recipe_overrides.json"
const RECIPE_FIELDS := ["type", "damage_class", "accuracy", "sr_cost", "tags", "shape", "components", "modifiers"]
const SHAPE_COMMON_FIELDS := ["kind", "range_min", "range_max", "anchor"]
const SHAPE_SIZE_FIELDS := {"square": ["length", "width"], "circle": ["radius", "angle"]}
const RADIUS_LIMIT := 50
const SPREAD_STEP := 15
const FULL_TURN := 360
const RADII_TRIED := [1, 2, 3, 4, 6, 10]
const BOARD_SIZE := 15

var pack: PackData
var overrides: Dictionary


func before() -> void:
	pack = PackData.shared()
	overrides = JSON.parse_string(FileAccess.get_file_as_string(OVERRIDES_PATH))


## Relation 1: every move a roster unit knows has a recipe, and every recipe has exactly the recipe fields and
## the fields its shape kind needs. Every move in the pack says whether it makes contact.
func test_every_roster_move_has_a_valid_entry() -> void:
	var failures: Array[String] = []
	for move_name in _roster_move_names():
		if pack.move(move_name)["recipe"] == null:
			failures.append("%s has no recipe" % move_name)
	for move_name in pack.moves:
		var move: Dictionary = pack.moves[move_name]
		if not move["contact"] is bool:
			failures.append("%s has no contact flag" % move_name)
		if move["recipe"] == null:
			continue
		var recipe: Dictionary = move["recipe"]
		_check_fields(failures, move_name, recipe, RECIPE_FIELDS)
		var shape: Dictionary = recipe.get("shape", {})
		if not SHAPE_SIZE_FIELDS.has(shape.get("kind")):
			failures.append("%s: unknown shape kind %s" % [move_name, shape.get("kind")])
			continue
		_check_fields(failures, move_name, shape, SHAPE_COMMON_FIELDS + SHAPE_SIZE_FIELDS[shape["kind"]])
	assert_array(failures).is_empty()


## Relation 2: every override names a move in the pack, and every overridden field is a recipe field.
func test_overrides_name_real_moves_and_fields() -> void:
	var failures: Array[String] = []
	for move_name in overrides:
		if not pack.moves.has(move_name):
			failures.append("override names unknown move %s" % move_name)
		for field in overrides[move_name]:
			if not RECIPE_FIELDS.has(field):
				failures.append("%s overrides unknown field %s" % [move_name, field])
	assert_array(failures).is_empty()


## Relation 3: with the same pokeapi target, a contact move never reaches farther than a non-contact move, unless
## its shape is overridden.
func test_contact_moves_never_outreach_ranged_moves() -> void:
	var farthest_contact := {}
	var nearest_ranged := {}
	for move_name in _entries_without_override("shape"):
		var move: Dictionary = pack.moves[move_name]
		var reach := int(move["recipe"]["shape"]["range_max"])
		var target: String = move["target"]
		if move["contact"]:
			farthest_contact[target] = maxi(reach, farthest_contact.get(target, 0))
		else:
			nearest_ranged[target] = mini(reach, nearest_ranged.get(target, 1 << 30))
	for target in farthest_contact:
		if nearest_ranged.has(target):
			assert_int(farthest_contact[target]).is_less_equal(nearest_ranged[target])


## Relation 4: an area hits exactly the units standing in its footprint, whatever their side; a range-0 shape
## bigger than one tile leaves the user out; a range-0 single tile hits only the user.
func test_areas_hit_exactly_the_units_inside_whatever_their_side() -> void:
	var battle := _board_full_of_units()
	var centre := Vector2i(BOARD_SIZE / 2, BOARD_SIZE / 2)
	var user := battle.unit_at(centre)
	for move_name in overrides:
		var recipe: Dictionary = pack.move(move_name)["recipe"]
		var on_user_tile := MoveRecipe.is_on_user_tile(recipe)
		var is_single_tile := _is_single_tile(recipe["shape"])
		var target_cell := centre if on_user_tile else centre + Vector2i(2, 0)
		for direction in Facing.ALL_DIRECTIONS:
			var hit := MoveArea.units_hit(battle, pack.shapes, recipe, user, target_cell, direction)
			var expected := {}
			for cell in MoveArea.footprint(battle.grid, pack.shapes, recipe, centre, target_cell, direction):
				if battle.grid.contains(cell):
					expected[battle.unit_at(cell)] = true
			assert_int(hit.size()).override_failure_message(move_name).is_equal(expected.size())
			for unit in hit:
				assert_bool(expected.has(unit)).override_failure_message(move_name).is_true()
			if on_user_tile and is_single_tile:
				assert_int(hit.size()).is_equal(1)
				assert_object(hit[0]).is_same(user)
			if on_user_tile and not is_single_tile:
				assert_bool(hit.has(user)).override_failure_message(move_name).is_false()
			if not is_single_tile:
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
				assert_int(int(first_move["recipe"]["sr_cost"])).override_failure_message(
					"%s costs less than %s" % [first, second]
				).is_greater_equal(int(second_move["recipe"]["sr_cost"]))


## Relation 6: a damaging move leaves its own type on the tiles it touches; a status move leaves none, unless its
## components are overridden.
func test_tile_element_follows_the_move_type() -> void:
	for move_name in _entries_without_override("components"):
		var move: Dictionary = pack.moves[move_name]
		var elements: Array = []
		for component in move["recipe"]["components"]:
			if component["effect"] == "element":
				assert_str(component["touches"]).override_failure_message(move_name).is_equal("tiles")
				elements.append(component["element"])
		if move["damage_class"] == "status":
			assert_array(elements).override_failure_message(move_name).is_empty()
		else:
			assert_array(elements).override_failure_message(move_name).contains_exactly([move["type"]])


## Relation 8: a shape aimed north, south or west covers the east-aimed tiles turned by quarter turns.
func test_footprints_rotate_with_the_aim() -> void:
	var shapes: Array[Dictionary] = [
		_square(5, 1, "forward", 0),
		_square(3, 1, "forward", 3),
		_square(3, 3, "centered", 2),
		_circle(3, FULL_TURN, "centered", 0),
	]
	for spread in [15, 60, 90, 135, 180, 270, 360]:
		shapes.append(_circle(4, spread, "forward", 0))
	for shape in shapes:
		var east := _offset_set(shape, Facing.Direction.EAST)
		for direction in [Facing.Direction.SOUTH, Facing.Direction.WEST, Facing.Direction.NORTH]:
			var expected := {}
			for offset in east:
				var turned: Vector2i = offset
				# One clockwise quarter turn per step from east (grid y grows south): (x, y) becomes (-y, x).
				for quarter in _quarter_turns_from_east(direction):
					turned = Vector2i(-turned.y, turned.x)
				expected[turned] = true
			assert_dict(_offset_set(shape, direction)).override_failure_message(str(shape)).is_equal(expected)
		if shape["kind"] == "circle" and shape["angle"] < FULL_TURN:
			assert_bool(east.has(Vector2i(1, 0))).is_true()


## Relation 9: a circle is symmetric about its centre; a cone lies inside the circle of the same radius; a larger
## radius or angle never covers fewer tiles.
func test_circles_and_cones_nest() -> void:
	for radius in RADII_TRIED + [RADIUS_LIMIT]:
		var circle := _offset_set(_circle(radius, FULL_TURN, "centered", 0), Facing.Direction.EAST)
		for offset in circle:
			for mirrored in [Vector2i(-offset.x, offset.y), Vector2i(offset.x, -offset.y), Vector2i(offset.y, offset.x)]:
				assert_bool(circle.has(mirrored)).override_failure_message("radius %d at %s" % [radius, offset]).is_true()
	for radius in RADII_TRIED:
		var circle := _offset_set(_circle(radius, FULL_TURN, "centered", 0), Facing.Direction.EAST)
		var wider_circle := _offset_set(_circle(radius + 1, FULL_TURN, "centered", 0), Facing.Direction.EAST)
		_assert_subset(circle, wider_circle, "circle %d inside %d" % [radius, radius + 1])
		var previous_cone := {}
		for spread in range(SPREAD_STEP, FULL_TURN + 1, SPREAD_STEP):
			var cone := _offset_set(_circle(radius, spread, "forward", 0), Facing.Direction.EAST)
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


## Moves with a recipe whose override leaves this field to the derived default.
func _entries_without_override(field: String) -> Array[String]:
	var names: Array[String] = []
	for move_name in overrides:
		if pack.moves.has(move_name) and pack.moves[move_name]["recipe"] != null and not overrides[move_name].has(field):
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


## A shape's footprint as offsets from its anchor, as a set.
func _offset_set(shape: Dictionary, direction: Facing.Direction) -> Dictionary:
	var origin := Vector2i(100, 100)
	var offsets := {}
	for cell in MoveArea.footprint(BattleGrid.new(), pack.shapes, {"shape": shape}, origin, origin, direction):
		offsets[cell - origin] = true
	return offsets


func _is_single_tile(shape: Dictionary) -> bool:
	return shape["kind"] == "square" and int(shape["length"]) == 1 and int(shape["width"]) == 1


func _square(length: int, width: int, anchor: String, reach: int) -> Dictionary:
	return {
		"kind": "square",
		"length": length,
		"width": width,
		"anchor": anchor,
		"range_min": mini(reach, 1),
		"range_max": reach,
	}


func _circle(radius: int, angle: int, anchor: String, reach: int) -> Dictionary:
	return {
		"kind": "circle",
		"radius": radius,
		"angle": angle,
		"anchor": anchor,
		"range_min": mini(reach, 1),
		"range_max": reach,
	}


func _check_fields(failures: Array[String], move_name: String, entry: Dictionary, expected_fields: Array) -> void:
	for field in expected_fields:
		if not entry.has(field):
			failures.append("%s is missing %s" % [move_name, field])
	for field in entry:
		if not expected_fields.has(field):
			failures.append("%s has an unexpected field %s" % [move_name, field])


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
