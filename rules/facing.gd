class_name Facing
## The four grid directions a unit can face. Grid x grows east, grid y grows south.

enum Direction { NORTH, EAST, SOUTH, WEST }

const ALL_DIRECTIONS: Array[Direction] = [Direction.NORTH, Direction.EAST, Direction.SOUTH, Direction.WEST]


static func grid_step(direction: Direction) -> Vector2i:
	match direction:
		Direction.NORTH:
			return Vector2i(0, -1)
		Direction.EAST:
			return Vector2i(1, 0)
		Direction.SOUTH:
			return Vector2i(0, 1)
		_:
			return Vector2i(-1, 0)
