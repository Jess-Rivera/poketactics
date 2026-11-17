extends GdUnitTestSuite
## Issue #7 relations (docs/discussion-outputs/select-and-move-plan.md), with #13's walk cost
## (2026-11-17-elevation-cost): reachability (orthogonal steps, climb 1, drop 2, at most MAX_WALK_COST SR; allies
## passable, enemies block, nobody ends on a unit), moving to a chosen facing, picking the cell under a screen point
## in every view and zoom, and whole-step zoom limits.

const FLAT_ROWS := ["000000000000", "000000000000", "000000000000", "000000000000", "000000000000", "000000000000",
	"000000000000", "000000000000", "000000000000", "000000000000", "000000000000", "000000000000"]
const FLAT_START := Vector2i(6, 6)


func _flat_battle() -> Battle:
	return Battle.new(BattleGrid.from_rows(PackedStringArray(FLAT_ROWS)))


func _add(battle: Battle, cell: Vector2i, side: int) -> BattleUnit:
	var unit := BattleUnit.new(cell)
	# A unit with no hit points has fainted and no longer stands on its cell.
	unit.hit_points = 1
	battle.add_unit(unit, side)
	return unit


func _manhattan(from_cell: Vector2i, to_cell: Vector2i) -> int:
	return absi(from_cell.x - to_cell.x) + absi(from_cell.y - to_cell.y)


## Relations 1, 3, 4 and 6 checked over every unit of the real test battle (its hill, ridge and valley).
func test_every_path_in_the_test_battle_obeys_the_movement_rules() -> void:
	var battle := TestBattleSetup.build(PackData.shared())
	var failures: Array[String] = []
	for unit in battle.units:
		var paths := Movement.reachable_paths(battle, unit)
		if paths.is_empty():
			failures.append("%s can reach nothing" % unit.unit_name)
		for target in paths:
			var path: Array[Vector2i] = paths[target]
			if not battle.grid.contains(target):
				failures.append("%s reaches %s, outside the grid" % [unit.unit_name, target])
			if path.is_empty() or path.back() != target:
				failures.append("%s has a bad path to %s: %s" % [unit.unit_name, target, path])
				continue
			if Movement.walk_cost(battle.grid, unit.cell, path) > Movement.MAX_WALK_COST:
				failures.append("%s path to %s costs more than %d SR" % [unit.unit_name, target, Movement.MAX_WALK_COST])
			if battle.unit_at(target) != null:
				failures.append("%s would end on a unit at %s" % [unit.unit_name, target])
			var previous := unit.cell
			for cell in path:
				if _manhattan(previous, cell) != 1:
					failures.append("%s path to %s jumps %s to %s" % [unit.unit_name, target, previous, cell])
				var rise := battle.grid.height_level_at(cell) - battle.grid.height_level_at(previous)
				if rise > Movement.MAX_CLIMB_LEVELS or -rise > Movement.MAX_DROP_LEVELS:
					failures.append("%s path to %s changes height by %d at %s" % [unit.unit_name, target, rise, cell])
				var standing := battle.unit_at(cell)
				if standing != null and standing.side != unit.side:
					failures.append("%s path to %s passes an enemy at %s" % [unit.unit_name, target, cell])
				previous = cell
	assert_array(failures).is_empty()


## Relation 2: on flat open ground every cell within the SR cap is reachable, at round up(distance / 2) SR, the
## cheapest a flat walk can be (2026-11-17-elevation-cost).
func test_flat_open_ground_costs_half_the_distance() -> void:
	var battle := _flat_battle()
	var unit := _add(battle, FLAT_START, Battle.Side.PLAYER)
	var paths := Movement.reachable_paths(battle, unit)
	var expected := []
	for grid_y in battle.grid.depth:
		for grid_x in battle.grid.width:
			var cell := Vector2i(grid_x, grid_y)
			var distance := _manhattan(FLAT_START, cell)
			if distance >= 1 and (distance + 1) / 2 <= Movement.MAX_WALK_COST:
				expected.append(cell)
	assert_array(paths.keys()).contains_exactly_in_any_order(expected)
	for cell in paths:
		var cost := Movement.walk_cost(battle.grid, FLAT_START, paths[cell])
		assert_int(cost).is_equal((_manhattan(FLAT_START, cell) + 1) / 2)


## Relation 5: a pillar 2 levels above everything around it is not reachable, and becomes reachable once one
## neighbour is a 1 level ledge.
func test_a_two_level_pillar_needs_a_ledge() -> void:
	var walled := Battle.new(BattleGrid.from_rows(PackedStringArray(["00000", "00000", "00200", "00000", "00000"])))
	var walled_unit := _add(walled, Vector2i(0, 2), Battle.Side.PLAYER)
	assert_bool(Movement.reachable_paths(walled, walled_unit).has(Vector2i(2, 2))).is_false()
	var ledged := Battle.new(BattleGrid.from_rows(PackedStringArray(["00000", "00000", "01200", "00000", "00000"])))
	var ledged_unit := _add(ledged, Vector2i(0, 2), Battle.Side.PLAYER)
	assert_bool(Movement.reachable_paths(ledged, ledged_unit).has(Vector2i(2, 2))).is_true()


func test_a_drop_of_two_is_allowed_and_three_is_not() -> void:
	var battle := Battle.new(BattleGrid.from_rows(PackedStringArray(["3200", "0999"])))
	var unit := _add(battle, Vector2i(0, 0), Battle.Side.PLAYER)
	var paths := Movement.reachable_paths(battle, unit)
	assert_bool(paths.has(Vector2i(1, 0))).is_true()
	assert_bool(paths.has(Vector2i(0, 1))).is_false()


## Relation 6: allies can be walked through but not stood on; enemies block.
func test_allies_are_passable_and_enemies_block() -> void:
	var corridor := ["00000", "99999"]
	var through_ally := Battle.new(BattleGrid.from_rows(PackedStringArray(corridor)))
	var walker := _add(through_ally, Vector2i(0, 0), Battle.Side.PLAYER)
	_add(through_ally, Vector2i(1, 0), Battle.Side.PLAYER)
	var ally_paths := Movement.reachable_paths(through_ally, walker)
	assert_bool(ally_paths.has(Vector2i(1, 0))).is_false()
	assert_bool(ally_paths.has(Vector2i(2, 0))).is_true()

	var past_enemy := Battle.new(BattleGrid.from_rows(PackedStringArray(corridor)))
	var blocked := _add(past_enemy, Vector2i(0, 0), Battle.Side.PLAYER)
	_add(past_enemy, Vector2i(1, 0), Battle.Side.ENEMY)
	assert_bool(Movement.reachable_paths(past_enemy, blocked).is_empty()).is_true()


## Relation 7: after moving, the unit stands on the target facing the chosen way; nobody else changes.
func test_moving_puts_the_unit_on_the_target_with_the_chosen_facing() -> void:
	for facing in Facing.ALL_DIRECTIONS:
		var battle := _flat_battle()
		var unit := _add(battle, FLAT_START, Battle.Side.PLAYER)
		var bystander := _add(battle, Vector2i(0, 0), Battle.Side.ENEMY)
		var bystander_facing := bystander.facing
		var target := FLAT_START + Vector2i(2, 1)
		battle.move_unit(unit, Movement.reachable_paths(battle, unit)[target], facing)
		assert_that(unit.cell).is_equal(target)
		assert_int(unit.facing).is_equal(facing)
		assert_that(bystander.cell).is_equal(Vector2i(0, 0))
		assert_int(bystander.facing).is_equal(bystander_facing)


## Relation 7b: the facing offered first is the direction of the last step.
func test_the_first_offered_facing_is_the_last_step_direction() -> void:
	var battle := _flat_battle()
	var unit := _add(battle, FLAT_START, Battle.Side.PLAYER)
	var paths := Movement.reachable_paths(battle, unit)
	for target in paths:
		var path: Array[Vector2i] = paths[target]
		var before_last := FLAT_START if path.size() < 2 else path[path.size() - 2]
		var offered := Movement.last_step_facing(FLAT_START, path)
		assert_that(before_last + Facing.grid_step(offered)).is_equal(target)


## Relation 8: the top centre of every cell, projected to the screen, picks back that cell in every view and zoom,
## unless a taller column nearer the camera hides it (then that column is picked, as it is the one drawn there).
func test_the_cell_under_a_cells_top_centre_is_that_cell() -> void:
	var grid := BattleGrid.from_rows(PackedStringArray(TestBattleSetup.HEIGHT_ROWS))
	var camera_rig: CameraRig = auto_free(CameraRig.new())
	camera_rig.position = Vector3(grid.width / 2.0, BattleMap.BASE_THICKNESS, grid.depth / 2.0)
	add_child(camera_rig)
	var failures: Array[String] = []
	var picked_back := 0
	var checked := 0
	for view_step in SpriteDirection.VIEW_STEP_COUNT:
		camera_rig.rotation_degrees.y = SpriteDirection.camera_yaw_degrees(view_step)
		for zoom_level in range(CameraRig.MIN_ZOOM_LEVEL, CameraRig.MAX_ZOOM_LEVEL + 1):
			camera_rig.camera.size = CameraRig.orthographic_height_for(zoom_level)
			for grid_y in grid.depth:
				for grid_x in grid.width:
					var cell := Vector2i(grid_x, grid_y)
					var top_centre := Vector3(cell.x + 0.5, CellPicker.top_y_of(grid, cell), cell.y + 0.5)
					var screen_point := camera_rig.camera.unproject_position(top_centre)
					var picked := CellPicker.cell_under_ray(grid, camera_rig.camera.project_ray_origin(screen_point),
						camera_rig.camera.project_ray_normal(screen_point))
					checked += 1
					if picked == cell:
						picked_back += 1
						continue
					var camera_side := camera_rig.camera.global_basis.z
					var toward_camera := Vector3(picked.x - cell.x, 0.0, picked.y - cell.y).dot(camera_side)
					if not grid.contains(picked) or grid.height_level_at(picked) <= grid.height_level_at(cell) or toward_camera <= 0.0:
						failures.append("view %d zoom %d: %s picked %s" % [view_step, zoom_level, cell, picked])
	assert_array(failures).is_empty()
	# Most of the map is open, so most tops are visible and must pick themselves.
	assert_int(picked_back).is_greater(checked / 2)


## Relation 9: zoom stays between 1x and 3x in whole steps, and the camera height scales as 1 over the level.
func test_zoom_moves_in_whole_steps_between_one_and_three() -> void:
	var level := CameraRig.MIN_ZOOM_LEVEL
	for step in 10:
		level = CameraRig.zoomed_level(level, -1)
		assert_int(level).is_greater_equal(1)
	for step in 10:
		var next_level := CameraRig.zoomed_level(level, 1)
		assert_int(next_level - level).is_between(0, 1)
		level = next_level
	assert_int(level).is_equal(CameraRig.MAX_ZOOM_LEVEL)
	assert_int(CameraRig.MAX_ZOOM_LEVEL).is_equal(3)
	assert_int(CameraRig.MIN_ZOOM_LEVEL).is_equal(1)
	for zoom_level in range(CameraRig.MIN_ZOOM_LEVEL, CameraRig.MAX_ZOOM_LEVEL + 1):
		var ratio := CameraRig.orthographic_height_for(1) / CameraRig.orthographic_height_for(zoom_level)
		assert_float(ratio).is_equal_approx(float(zoom_level), 0.0001)
