class_name Facing
## The four grid directions a unit can face. Grid x grows east, grid y grows south.

enum Direction { NORTH, EAST, SOUTH, WEST }
## Where an attacker stands relative to a defender's facing (2026-11-16-facing-arcs).
enum Arc { FRONT, SIDE, BACK }

## Front or back when the sideways offset is at most this many times the forward (or backward) offset.
const ARC_SIDEWAYS_PER_FORWARD := 2

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


## The defender's arc a cell lies in: front or back when its sideways offset is at most ARC_SIDEWAYS_PER_FORWARD
## times its forward (or backward) offset, the line itself included, else side. The defender's own cell is front.
static func arc_of(defender_cell: Vector2i, defender_facing: Direction, origin_cell: Vector2i) -> Arc:
	var offset := origin_cell - defender_cell
	if offset == Vector2i.ZERO:
		return Arc.FRONT
	var forward_step := grid_step(defender_facing)
	var forward := offset.x * forward_step.x + offset.y * forward_step.y
	var sideways := absi(offset.x * forward_step.y - offset.y * forward_step.x)
	if sideways > ARC_SIDEWAYS_PER_FORWARD * absi(forward):
		return Arc.SIDE
	return Arc.FRONT if forward > 0 else Arc.BACK
