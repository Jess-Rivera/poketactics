extends GdUnitTestSuite
## Issue #6 relations (docs/discussion-outputs/units-on-map-plan.md): every unit and transformation points at a
## real sprite set of its own species and form, and the test battle is 4 a side on distinct cells, facing each
## other, with a camera that pans inside the map in whole sprite pixels.

const PACKED_FOLDER := "res://assets/pokemon"
const UNITS_PER_SIDE := 4
const PAN_DIRECTIONS: Array[Vector2] = [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT, Vector2(1, -1), Vector2(-1, 1)]

var pack: PackData


func before() -> void:
	pack = PackData.shared()


## Relation 1: every sprite_set in the pack is a packed set in assets/pokemon.
func test_every_sprite_set_is_packed() -> void:
	var failures: Array[String] = []
	var checked := 0
	for unit_name in pack.units:
		var unit: Dictionary = pack.units[unit_name]
		var named_sets := [[unit_name, unit["sprite_set"]]]
		for transformation in unit["transformations"]:
			named_sets.append([transformation["name"], transformation["sprite_set"]])
		for named_set in named_sets:
			if named_set[1] == null:
				continue
			checked += 1
			if not FileAccess.file_exists("%s/%s.json" % [PACKED_FOLDER, named_set[1]]):
				failures.append("%s points at %s, which is not packed" % named_set)
	assert_int(checked).is_greater(0)
	assert_array(failures).is_empty()


## Relation 2: a species default draws its dex number's normal set; a regional unit or a transformation draws a
## form of the same dex number and never the species' normal set.
func test_sprite_sets_belong_to_their_species_and_form() -> void:
	var failures: Array[String] = []
	for unit_name in pack.units:
		var unit: Dictionary = pack.units[unit_name]
		var dex := "%04d" % int(unit["dex_number"])
		var sprite_set = unit["sprite_set"]
		if sprite_set != null:
			if unit["is_species_default"] and sprite_set != dex:
				failures.append("%s draws %s, not %s" % [unit_name, sprite_set, dex])
			if not unit["is_species_default"] and not _is_a_form_of(sprite_set, dex):
				failures.append("regional %s draws %s, not a form of %s" % [unit_name, sprite_set, dex])
		for transformation in unit["transformations"]:
			var transformation_set = transformation["sprite_set"]
			if transformation_set != null and not _is_a_form_of(transformation_set, dex):
				failures.append("%s draws %s, not a form of %s" % [transformation["name"], transformation_set, dex])
	assert_array(failures).is_empty()


## Relation 3: 4 units a side, on different cells inside the grid, each built from the pack with 1 to 4 moves
## and a sprite set.
func test_the_test_battle_has_four_drawable_units_a_side_on_distinct_cells() -> void:
	var battle := TestBattleSetup.build(pack)
	assert_int(battle.units_on_side(Battle.Side.PLAYER).size()).is_equal(UNITS_PER_SIDE)
	assert_int(battle.units_on_side(Battle.Side.ENEMY).size()).is_equal(UNITS_PER_SIDE)
	var failures: Array[String] = []
	var used_cells := {}
	for unit in battle.units:
		if not battle.grid.contains(unit.cell):
			failures.append("%s stands outside the grid at %s" % [unit.unit_name, unit.cell])
		if used_cells.has(unit.cell):
			failures.append("%s shares %s with %s" % [unit.unit_name, unit.cell, used_cells[unit.cell]])
		used_cells[unit.cell] = unit.unit_name
		if unit.move_names.size() < 1 or unit.move_names.size() > BattleStats.MOVES_KNOWN:
			failures.append("%s knows %d moves" % [unit.unit_name, unit.move_names.size()])
		if pack.unit(unit.unit_name).get("sprite_set") == null:
			failures.append("%s has no sprite set" % unit.unit_name)
	assert_array(failures).is_empty()


## Relation 4: each side's units face toward the other side's start zone.
func test_each_side_faces_the_other() -> void:
	var battle := TestBattleSetup.build(pack)
	var failures: Array[String] = []
	for unit in battle.units:
		var other_side := Battle.Side.ENEMY if unit.side == Battle.Side.PLAYER else Battle.Side.PLAYER
		var toward_other := TestBattleSetup.start_zone_center(other_side) - Vector2(unit.cell)
		if Vector2(Facing.grid_step(unit.facing)).dot(toward_other) <= 0.0:
			failures.append("%s faces away from the other side" % unit.unit_name)
	assert_array(failures).is_empty()


## Relation 5: panning keeps the focus inside the map and on the sprite pixel grid, in every view.
func test_panning_stays_inside_the_map_on_whole_pixels() -> void:
	var bounds := Rect2(0, 0, 20, 20)
	var failures: Array[String] = []
	for view_step in SpriteDirection.VIEW_STEP_COUNT:
		var yaw := SpriteDirection.camera_yaw_degrees(view_step)
		for direction in PAN_DIRECTIONS:
			var focus := Vector3(10, 0.5, 10)
			for step in 300:
				focus = CameraRig.panned_focus(focus, direction, yaw, 4, bounds)
				if focus.x < bounds.position.x or focus.x > bounds.end.x or focus.z < bounds.position.y or focus.z > bounds.end.y:
					failures.append("view %d direction %s left the map at %s" % [view_step, direction, focus])
					break
				var in_pixels := focus * CameraRig.PIXELS_PER_UNIT
				if not in_pixels.is_equal_approx(in_pixels.round()):
					failures.append("view %d direction %s is between pixels at %s" % [view_step, direction, focus])
					break
	assert_array(failures).is_empty()


func test_panning_up_moves_away_from_the_viewer() -> void:
	var bounds := Rect2(0, 0, 20, 20)
	for view_step in SpriteDirection.VIEW_STEP_COUNT:
		var yaw := SpriteDirection.camera_yaw_degrees(view_step)
		var focus := Vector3(10, 0.5, 10)
		var moved := CameraRig.panned_focus(focus, Vector2.UP, yaw, 24, bounds)
		var camera_forward := Vector3(-sin(deg_to_rad(yaw)), 0.0, -cos(deg_to_rad(yaw)))
		assert_float((moved - focus).dot(camera_forward)).is_greater(0.0)


func _is_a_form_of(sprite_set: String, dex: String) -> bool:
	return sprite_set.begins_with(dex + "-")
