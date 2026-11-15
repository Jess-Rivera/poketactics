extends GdUnitTestSuite
## Issue #1 end-goal relations 1 to 3: rotating the view changes which of the 8 sheet rows a facing draws.
## Rows and steps come from the ruling (8 facing rows per sheet, 4 views 90 degrees apart), not from code output.


func test_four_views_give_four_different_rows_for_each_facing() -> void:
	for facing in Facing.ALL_DIRECTIONS:
		var rows_seen := {}
		for view_step in SpriteDirection.VIEW_STEP_COUNT:
			rows_seen[SpriteDirection.row_for(facing, view_step)] = true
		assert_int(rows_seen.size()).override_failure_message(
			"facing %s should show 4 different rows across 4 views" % facing).is_equal(4)


func test_one_view_step_moves_the_row_by_two_the_same_way_every_time() -> void:
	var row_shifts := {}
	for facing in Facing.ALL_DIRECTIONS:
		for view_step in SpriteDirection.VIEW_STEP_COUNT:
			var row_before := SpriteDirection.row_for(facing, view_step)
			var row_after := SpriteDirection.row_for(facing, SpriteDirection.next_view_step(view_step, 1))
			row_shifts[posmod(row_after - row_before, SpriteDirection.ROW_COUNT)] = true
	# One quarter turn is 2 of 8 rows; every facing and view must shift the same way.
	assert_int(row_shifts.size()).is_equal(1)
	assert_array(row_shifts.keys()).contains_exactly_in_any_order([2]) \
		if row_shifts.has(2) else assert_array(row_shifts.keys()).contains_exactly_in_any_order([6])


func test_four_view_steps_return_to_the_start_row() -> void:
	for facing in Facing.ALL_DIRECTIONS:
		for start_step in SpriteDirection.VIEW_STEP_COUNT:
			var view_step := start_step
			for turn_count in 4:
				view_step = SpriteDirection.next_view_step(view_step, 1)
			assert_int(SpriteDirection.row_for(facing, view_step)).is_equal(SpriteDirection.row_for(facing, start_step))


func test_turning_left_then_right_returns_to_the_start_view_and_row() -> void:
	for facing in Facing.ALL_DIRECTIONS:
		for start_step in SpriteDirection.VIEW_STEP_COUNT:
			var left_then_right := SpriteDirection.next_view_step(SpriteDirection.next_view_step(start_step, -1), 1)
			var right_then_left := SpriteDirection.next_view_step(SpriteDirection.next_view_step(start_step, 1), -1)
			assert_int(left_then_right).is_equal(start_step)
			assert_int(right_then_left).is_equal(start_step)
			assert_int(SpriteDirection.row_for(facing, left_then_right)).is_equal(SpriteDirection.row_for(facing, start_step))


func test_every_row_is_one_of_the_eight_sheet_rows() -> void:
	for facing in Facing.ALL_DIRECTIONS:
		for view_step in SpriteDirection.VIEW_STEP_COUNT:
			assert_int(SpriteDirection.row_for(facing, view_step)).is_between(0, SpriteDirection.ROW_COUNT - 1)
