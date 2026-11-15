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


## The direction of a one-cell grid step (the inverse of grid_step). Steps that are not one orthogonal cell fall
## back to the nearest axis, x first on a tie.
static func direction_of_step(step: Vector2i) -> Direction:
	if absi(step.x) >= absi(step.y):
		return Direction.EAST if step.x > 0 else Direction.WEST
	return Direction.SOUTH if step.y > 0 else Direction.NORTH
