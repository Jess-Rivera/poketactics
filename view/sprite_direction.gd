class_name SpriteDirection
## Which of the 8 SpriteCollab sheet rows to draw for a unit's grid facing in the current camera view.
## Sheet rows, top to bottom: down, down-right, right, up-right, up, up-left, left, down-left (screen directions).
## Pure functions, no nodes, so tests can check them headless.

const ROW_COUNT := 8
const VIEW_STEP_COUNT := 4
const FIRST_VIEW_YAW_DEGREES := 45.0
const DEGREES_PER_VIEW_STEP := 90.0


## Camera yaw for a view step: 45 degrees puts the camera south-east of the map, looking north-west.
static func camera_yaw_degrees(view_step: int) -> float:
	return FIRST_VIEW_YAW_DEGREES + DEGREES_PER_VIEW_STEP * posmod(view_step, VIEW_STEP_COUNT)


## The view step after rotating left (-1) or right (+1).
static func next_view_step(view_step: int, rotation_direction: int) -> int:
	return posmod(view_step + rotation_direction, VIEW_STEP_COUNT)


## Projects the facing onto the screen for this view and picks the nearest of the 8 sheet rows.
static func row_for(facing: Facing.Direction, view_step: int) -> int:
	var grid_step := Facing.grid_step(facing)
	var world_direction := Vector3(grid_step.x, 0.0, grid_step.y)
	var yaw := deg_to_rad(camera_yaw_degrees(view_step))
	var camera_forward := Vector3(-sin(yaw), 0.0, -cos(yaw))
	var camera_right := Vector3(cos(yaw), 0.0, -sin(yaw))
	var screen_right := world_direction.dot(camera_right)
	var screen_up := world_direction.dot(camera_forward)
	var screen_angle_degrees := rad_to_deg(atan2(screen_up, screen_right))
	# Down (-90 degrees) is row 0, and each row after it is 45 degrees further counterclockwise.
	return posmod(roundi((screen_angle_degrees + 90.0) / 45.0), ROW_COUNT)
