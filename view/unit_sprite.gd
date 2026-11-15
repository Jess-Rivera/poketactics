class_name UnitSprite
extends Sprite3D
## Draws one unit from a packed sprite set: plays one animation, picks the sheet row for the unit's facing in the
## current view, keeps its pixels the same size as the map's, and stands its feet on the cell's top face.

const PIXELS_PER_UNIT := 24.0
const TICKS_PER_SECOND := 60.0
## Moves the sprite toward the camera so its top does not sink into a taller block behind it. The camera is
## orthographic, so this changes only what hides what, never where the sprite appears on screen.
const TOWARD_CAMERA_UNITS := 0.6

var _unit: BattleUnit
var _animation: SpritePack.PackedAnimation
var _feet_position: Vector3
var _frame_index := 0
var _seconds_in_frame := 0.0
var _view_step := 0


## sprite_set_id is a packed set in assets/pokemon/, for example "0004" (Charmander).
func show_unit(unit: BattleUnit, sprite_set_id: String, animation_name: String, feet_position: Vector3) -> void:
	_unit = unit
	_feet_position = feet_position
	var pack := SpritePack.load_set(sprite_set_id)
	_animation = pack.resolved(animation_name)
	assert(_animation != null, "%s has no %s animation" % [sprite_set_id, animation_name])
	texture = pack.sheet
	region_enabled = true
	pixel_size = 1.0 / PIXELS_PER_UNIT
	billboard = BaseMaterial3D.BILLBOARD_ENABLED
	texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	shaded = false
	_show_current_frame()


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
	var row := SpriteDirection.row_for(_unit.facing, _view_step)
	region_rect = _animation.frame_region(row, _frame_index)
	offset = _feet_offset(_animation.feet_point(row, _frame_index))


## Offset (pixels, y up) that puts the frame's feet pixel at this node's origin; bottom centre if unmarked.
func _feet_offset(feet_pixel: Vector2i) -> Vector2:
	var frame_size := Vector2(_animation.frame_size)
	if feet_pixel.x == SpritePack.NO_MARKER:
		return Vector2(0.0, frame_size.y / 2.0)
	var feet_centre := Vector2(feet_pixel) + Vector2(0.5, 0.5)
	return Vector2(frame_size.x / 2.0 - feet_centre.x, feet_centre.y - frame_size.y / 2.0)
