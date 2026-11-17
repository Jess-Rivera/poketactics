class_name BattleGrid
extends RefCounted
## The battlefield as rules see it: a width by depth grid of cells, each with a height level.
## No nodes and no drawing, so battles can run headless.

## Height levels run 0 to 9 (one digit per cell).
const HIGHEST_LEVEL := 9

var width: int
var depth: int
var _height_levels: PackedInt32Array


## Builds a grid from rows of digits, one row per grid y, one digit (height level 0 to 9) per cell.
static func from_rows(rows: PackedStringArray) -> BattleGrid:
	var grid := BattleGrid.new()
	grid.depth = rows.size()
	grid.width = rows[0].length() if rows.size() > 0 else 0
	grid._height_levels.resize(grid.width * grid.depth)
	for grid_y in grid.depth:
		assert(rows[grid_y].length() == grid.width, "every row must have the same width")
		for grid_x in grid.width:
			grid._height_levels[grid_y * grid.width + grid_x] = rows[grid_y].unicode_at(grid_x) - "0".unicode_at(0)
	return grid


func contains(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < width and cell.y < depth


func height_level_at(cell: Vector2i) -> int:
	assert(contains(cell), "cell outside the grid")
	return _height_levels[cell.y * width + cell.x]
