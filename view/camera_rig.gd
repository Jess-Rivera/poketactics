class_name CameraRig
extends Node3D
## Isometric camera: orthographic, tilted down, turned in 90 degree steps with Q (left) and E (right), panned with
## WASD or the arrow keys (relative to the screen, kept inside map_bounds, in whole sprite pixels).
## Place the rig at the map centre. It announces the new view step halfway through each turn, which is when unit
## sprites switch to their new facing row.

signal view_step_changed(view_step: int)

const PITCH_DEGREES := -30.0
const CAMERA_DISTANCE := 30.0
## 360 screen pixels tall at 24 pixels per world unit: one sprite pixel is exactly one screen pixel.
const ORTHOGRAPHIC_HEIGHT_UNITS := 360.0 / 24.0
const TURN_SECONDS := 0.25
const PIXELS_PER_UNIT := 24.0
const PAN_PIXELS_PER_SECOND := 240.0
const PAN_KEYS := {
	KEY_W: Vector2.UP, KEY_UP: Vector2.UP,
	KEY_S: Vector2.DOWN, KEY_DOWN: Vector2.DOWN,
	KEY_A: Vector2.LEFT, KEY_LEFT: Vector2.LEFT,
	KEY_D: Vector2.RIGHT, KEY_RIGHT: Vector2.RIGHT,
}

## The ground area (world x and z) the camera's focus may move over; set it to the map's extent.
var map_bounds := Rect2(0, 0, 0, 0)
var _unspent_pan_pixels := 0.0

var view_step := 0
var _turn_tween: Tween


func _ready() -> void:
	# Keep the pivot on the sprite pixel grid so the resting view never lands between pixels.
	position = position.snapped(Vector3.ONE / PIXELS_PER_UNIT)
	rotation_degrees.y = SpriteDirection.camera_yaw_degrees(view_step)
	var pitch := Node3D.new()
	pitch.name = "Pitch"
	pitch.rotation_degrees.x = PITCH_DEGREES
	add_child(pitch)
	var camera := Camera3D.new()
	camera.name = "Camera"
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = ORTHOGRAPHIC_HEIGHT_UNITS
	camera.position.z = CAMERA_DISTANCE
	camera.near = 0.1
	camera.far = CAMERA_DISTANCE * 3.0
	pitch.add_child(camera)
	camera.make_current()


func _process(delta: float) -> void:
	var screen_direction := Vector2.ZERO
	for keycode in PAN_KEYS:
		if Input.is_key_pressed(keycode):
			screen_direction += PAN_KEYS[keycode]
	if screen_direction == Vector2.ZERO:
		_unspent_pan_pixels = 0.0
		return
	_unspent_pan_pixels += PAN_PIXELS_PER_SECOND * delta
	var whole_pixels := floori(_unspent_pan_pixels)
	if whole_pixels == 0:
		return
	_unspent_pan_pixels -= whole_pixels
	position = panned_focus(position, screen_direction, rotation_degrees.y, whole_pixels, map_bounds)


## Where the focus lands after panning distance_pixels toward a screen direction (up is away from the viewer) at
## a camera yaw. The result stays inside bounds (world x and z) and on the sprite pixel grid.
static func panned_focus(focus: Vector3, screen_direction: Vector2, yaw_degrees: float, distance_pixels: int, bounds: Rect2) -> Vector3:
	var yaw := deg_to_rad(yaw_degrees)
	var camera_right := Vector3(cos(yaw), 0.0, -sin(yaw))
	var camera_forward := Vector3(-sin(yaw), 0.0, -cos(yaw))
	var direction := screen_direction.normalized()
	var world_step := (camera_right * direction.x - camera_forward * direction.y) * (distance_pixels / PIXELS_PER_UNIT)
	var moved := focus + world_step
	moved.x = clampf(moved.x, bounds.position.x, bounds.end.x)
	moved.z = clampf(moved.z, bounds.position.y, bounds.end.y)
	return moved.snapped(Vector3.ONE / PIXELS_PER_UNIT)


func _unhandled_input(event: InputEvent) -> void:
	var key_event := event as InputEventKey
	if key_event == null or not key_event.pressed or key_event.echo:
		return
	if key_event.keycode == KEY_Q:
		turn(-1)
	elif key_event.keycode == KEY_E:
		turn(1)


## Starts a 90 degree turn left (-1) or right (+1). Ignored while a turn is still running.
func turn(rotation_direction: int) -> void:
	if _turn_tween != null and _turn_tween.is_running():
		return
	var new_view_step := SpriteDirection.next_view_step(view_step, rotation_direction)
	var target_yaw := rotation_degrees.y + SpriteDirection.DEGREES_PER_VIEW_STEP * rotation_direction
	_turn_tween = create_tween()
	_turn_tween.tween_property(self, "rotation_degrees:y", target_yaw, TURN_SECONDS) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_turn_tween.parallel().tween_callback(_announce_view_step.bind(new_view_step)).set_delay(TURN_SECONDS / 2.0)
	_turn_tween.tween_callback(_settle_yaw)


func _announce_view_step(new_view_step: int) -> void:
	view_step = new_view_step
	view_step_changed.emit(view_step)


## After a turn, set the exact yaw for the step so rounding never builds up.
func _settle_yaw() -> void:
	rotation_degrees.y = SpriteDirection.camera_yaw_degrees(view_step)
