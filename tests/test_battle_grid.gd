extends GdUnitTestSuite
## Grid rules: a grid built from rows has one cell per digit, and each cell's height level is its digit.


func test_grid_size_follows_the_rows() -> void:
	var grid := BattleGrid.from_rows(PackedStringArray(["012", "345"]))
	assert_int(grid.width).is_equal(3)
	assert_int(grid.depth).is_equal(2)


func test_height_level_is_the_digit_at_that_cell() -> void:
	var grid := BattleGrid.from_rows(PackedStringArray(["012", "345"]))
	assert_int(grid.height_level_at(Vector2i(0, 0))).is_equal(0)
	assert_int(grid.height_level_at(Vector2i(2, 0))).is_equal(2)
	assert_int(grid.height_level_at(Vector2i(1, 1))).is_equal(4)


func test_contains_only_cells_inside_the_grid() -> void:
	var grid := BattleGrid.from_rows(PackedStringArray(["00", "00"]))
	assert_bool(grid.contains(Vector2i(1, 1))).is_true()
	assert_bool(grid.contains(Vector2i(2, 0))).is_false()
	assert_bool(grid.contains(Vector2i(0, -1))).is_false()
