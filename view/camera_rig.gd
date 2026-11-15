class_name CameraRig
extends Node3D
## Isometric camera: orthographic, tilted down, turned in 90 degree steps with Q (left) and E (right), panned with
## WASD or the arrow keys (relative to the screen, kept inside map_bounds, in whole sprite pixels), zoomed in whole
## steps (1x to 3x) with the mouse wheel or + and -, so a sprite pixel is always a whole number of screen pixels.
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
const PAN_TO_SECONDS := 0.35
const PAN_KEYS := {
	KEY_W: Vector2.UP, KEY_UP: Vector2.UP,
	KEY_S: Vector2.DOWN, KEY_DOWN: Vector2.DOWN,
	KEY_A: Vector2.LEFT, KEY_LEFT: Vector2.LEFT,
	KEY_D: Vector2.RIGHT, KEY_RIGHT: Vector2.RIGHT,
}
## 1x shows one sprite pixel per screen pixel; zooming out further would split pixels, so 1x is the floor.
const MIN_ZOOM_LEVEL := 1
const MAX_ZOOM_LEVEL := 3
const ZOOM_IN_KEYS := [KEY_EQUAL, KEY_PLUS, KEY_KP_ADD]
const ZOOM_OUT_KEYS := [KEY_MINUS, KEY_KP_SUBTRACT]

## The ground area (world x and z) the camera's focus may move over; set it to the map's extent.
var map_bounds := Rect2(0, 0, 0, 0)
var _unspent_pan_pixels := 0.0

var view_step := 0
var zoom_level := MIN_ZOOM_LEVEL
var camera: Camera3D
var _turn_tween: Tween
var _pan_tween: Tween


func _ready() -> void:
	# Keep the pivot on the sprite pixel grid so the resting view never lands between pixels.
	position = position.snapped(Vector3.ONE / PIXELS_PER_UNIT)
	rotation_degrees.y = SpriteDirection.camera_yaw_degrees(view_step)
	var pitch := Node3D.new()
	pitch.name = "Pitch"
	pitch.rotation_degrees.x = PITCH_DEGREES
	add_child(pitch)
	camera = Camera3D.new()
	camera.name = "Camera"
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = orthographic_height_for(zoom_level)
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
	# Key panning takes over from a pan to a unit.
	if _pan_tween != null and _pan_tween.is_running():
		_pan_tween.kill()
	# Pan speed is in screen pixels, so it feels the same at every zoom; the focus still moves in sprite pixels.
	_unspent_pan_pixels += PAN_PIXELS_PER_SECOND / zoom_level * delta
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


## The zoom level after zooming in (+1) or out (-1), kept between MIN_ZOOM_LEVEL and MAX_ZOOM_LEVEL.
static func zoomed_level(current_level: int, zoom_direction: int) -> int:
	return clampi(current_level + zoom_direction, MIN_ZOOM_LEVEL, MAX_ZOOM_LEVEL)


## The orthographic camera height (world units) that shows zoom_level screen pixels per sprite pixel.
static func orthographic_height_for(level: int) -> float:
	return ORTHOGRAPHIC_HEIGHT_UNITS / level


func zoom(zoom_direction: int) -> void:
	zoom_level = zoomed_level(zoom_level, zoom_direction)
	camera.size = orthographic_height_for(zoom_level)


func _unhandled_input(event: InputEvent) -> void:
	var mouse_button := event as InputEventMouseButton
	if mouse_button != null and mouse_button.pressed:
		if mouse_button.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom(1)
		elif mouse_button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom(-1)
		return
	var key_event := event as InputEventKey
	if key_event == null or not key_event.pressed or key_event.echo:
		return
	if key_event.keycode == KEY_Q:
		turn(-1)
	elif key_event.keycode == KEY_E:
		turn(1)
	elif key_event.keycode in ZOOM_IN_KEYS:
		zoom(1)
	elif key_event.keycode in ZOOM_OUT_KEYS:
		zoom(-1)


## Eases the focus to a world point (kept inside map_bounds), landing on the sprite pixel grid at every step.
func pan_to(world_point: Vector3) -> void:
	if _pan_tween != null and _pan_tween.is_running():
		_pan_tween.kill()
	var target := Vector3(
		clampf(world_point.x, map_bounds.position.x, map_bounds.end.x),
		position.y,
		clampf(world_point.z, map_bounds.position.y, map_bounds.end.y)
	)
	_pan_tween = create_tween()
	_pan_tween.tween_method(_set_focus_between.bind(position, target), 0.0, 1.0, PAN_TO_SECONDS) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _set_focus_between(progress: float, from_focus: Vector3, to_focus: Vector3) -> void:
	position = from_focus.lerp(to_focus, progress).snapped(Vector3.ONE / PIXELS_PER_UNIT)


func is_turning() -> bool:
	return _turn_tween != null and _turn_tween.is_running()


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
