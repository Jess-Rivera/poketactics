class_name CameraRig
extends Node3D
## Isometric camera: orthographic, tilted down, turned in 90 degree steps with Q (left) and E (right).
## Place the rig at the map centre. It announces the new view step halfway through each turn, which is when unit
## sprites switch to their new facing row.

signal view_step_changed(view_step: int)

const PITCH_DEGREES := -30.0
const CAMERA_DISTANCE := 30.0
## 360 screen pixels tall at 24 pixels per world unit: one sprite pixel is exactly one screen pixel.
const ORTHOGRAPHIC_HEIGHT_UNITS := 360.0 / 24.0
const TURN_SECONDS := 0.25
const PIXELS_PER_UNIT := 24.0

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
