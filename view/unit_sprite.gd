class_name UnitSprite
extends Sprite3D
## Draws one unit from a packed sprite set: plays one animation, picks the sheet row for the unit's facing in the
## current view, keeps its pixels the same size as the map's, and stands its feet on the cell's top face. walk()
## plays Walk along a path, hopping on height changes, then turns to the end facing and goes back to Idle.

signal walk_finished

const PIXELS_PER_UNIT := 24.0
const TICKS_PER_SECOND := 60.0
## Moves the sprite toward the camera so its top does not sink into a taller block behind it. The camera is
## orthographic, so this changes only what hides what, never where the sprite appears on screen.
const TOWARD_CAMERA_UNITS := 0.6
const WALK_ANIMATION := "Walk"
const IDLE_ANIMATION := "Idle"
const SECONDS_PER_STEP := 0.2
## Extra rise at the middle of a step that changes height, in world units.
const HOP_HEIGHT := 0.35

var _unit: BattleUnit
var _sprite_pack: SpritePack
var _animation: SpritePack.PackedAnimation
var _shown_facing: Facing.Direction
var _feet_position: Vector3
var _frame_index := 0
var _seconds_in_frame := 0.0
var _view_step := 0


## sprite_set_id is a packed set in assets/pokemon/, for example "0004" (Charmander).
func show_unit(unit: BattleUnit, sprite_set_id: String, animation_name: String, feet_position: Vector3) -> void:
	_unit = unit
	_feet_position = feet_position
	_shown_facing = unit.facing
	_sprite_pack = SpritePack.load_set(sprite_set_id)
	_animation = _sprite_pack.resolved(animation_name)
	assert(_animation != null, "%s has no %s animation" % [sprite_set_id, animation_name])
	texture = _sprite_pack.sheet
	region_enabled = true
	pixel_size = 1.0 / PIXELS_PER_UNIT
	billboard = BaseMaterial3D.BILLBOARD_ENABLED
	texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	shaded = false
	_show_current_frame()


## Switches animation from its first frame; a set without that animation keeps Idle.
func play(animation_name: String) -> void:
	var animation := _sprite_pack.resolved(animation_name)
	if animation == null:
		animation = _sprite_pack.resolved(IDLE_ANIMATION)
	_animation = animation
	_frame_index = 0
	_seconds_in_frame = 0.0
	_show_current_frame()


## Walks through each feet position in turn (one per path cell), facing each step's direction, then shows the
## unit's own facing (already set by the rules) and emits walk_finished.
func walk(step_feet_positions: Array[Vector3], step_facings: Array[Facing.Direction]) -> void:
	play(WALK_ANIMATION)
	var tween := create_tween()
	var from_position := _feet_position
	for step_index in step_feet_positions.size():
		var to_position := step_feet_positions[step_index]
		tween.tween_callback(_face.bind(step_facings[step_index]))
		tween.tween_method(_step_between.bind(from_position, to_position), 0.0, 1.0, SECONDS_PER_STEP)
		from_position = to_position
	tween.tween_callback(_finish_walk)


func _step_between(progress: float, from_position: Vector3, to_position: Vector3) -> void:
	var position_now := from_position.lerp(to_position, progress)
	if not is_equal_approx(from_position.y, to_position.y):
		position_now.y += HOP_HEIGHT * 4.0 * progress * (1.0 - progress)
	_feet_position = position_now


func _face(direction: Facing.Direction) -> void:
	_shown_facing = direction
	_show_current_frame()


func _finish_walk() -> void:
	_shown_facing = _unit.facing
	play(IDLE_ANIMATION)
	walk_finished.emit()


func set_view_step(view_step: int) -> void:
	_view_step = view_step
	_show_current_frame()


func _process(delta: float) -> void:
	if _unit == null:
		return
	var camera := get_viewport().get_camera_3d()
	if camera != null:
		global_position = _feet_position + camera.global_basis.z * TOWARD_CAMERA_UNITS
	_seconds_in_frame += delta
	var seconds_for_frame := _animation.frame_durations[_frame_index] / TICKS_PER_SECOND
	if _seconds_in_frame >= seconds_for_frame:
		_seconds_in_frame -= seconds_for_frame
		_frame_index = (_frame_index + 1) % _animation.frame_count()
		_show_current_frame()


func _show_current_frame() -> void:
	if _unit == null:
		return
	var row := SpriteDirection.row_for(_shown_facing, _view_step)
	region_rect = _animation.frame_region(row, _frame_index)
	offset = _feet_offset(_animation.feet_point(row, _frame_index))


## Offset (pixels, y up) that puts the frame's feet pixel at this node's origin; bottom centre if unmarked.
func _feet_offset(feet_pixel: Vector2i) -> Vector2:
	var frame_size := Vector2(_animation.frame_size)
	if feet_pixel.x == SpritePack.NO_MARKER:
		return Vector2(0.0, frame_size.y / 2.0)
	var feet_centre := Vector2(feet_pixel) + Vector2(0.5, 0.5)
	return Vector2(frame_size.x / 2.0 - feet_centre.x, feet_centre.y - frame_size.y / 2.0)
