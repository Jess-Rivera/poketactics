class_name UnitSprite
extends Sprite3D
## Draws one unit from a packed sprite set: plays one animation, picks the sheet row for the unit's facing in the
## current view, keeps its pixels the same size as the map's, and stands its feet on the cell's top face. walk()
## plays Walk along a path, hopping on height changes, then turns to the end facing and goes back to Idle.
## For using a move (#10): play_once() plays an animation through once and announces its hit frame, an HP bar sits
## over the unit, float_text() shows damage and other results, and fade_out() takes a fainted unit off the map.

signal walk_finished
## A play_once() animation reached its hit frame (or its end, if it marks none).
signal hit_landed
## A play_once() animation ended; the sprite is back on Idle.
signal play_once_finished

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
const HIT_POINTS_BAR_SIZE := Vector2i(16, 2)
const HIT_POINTS_BAR_BACKGROUND := Color(0.0, 0.0, 0.0, 0.75)
## Extra room between the top of the Idle frame's feet column and the bar, in world units.
const HIT_POINTS_BAR_LIFT := 0.1
const FLOAT_TEXT_FONT_SIZE := 10
const FLOAT_TEXT_OUTLINE_SIZE := 4
const FLOAT_TEXT_RISE := 0.6
const FLOAT_TEXT_SECONDS := 1.0
const FADE_OUT_SECONDS := 0.6

var _unit: BattleUnit
var _sprite_pack: SpritePack
var _animation: SpritePack.PackedAnimation
var _shown_facing: Facing.Direction
var _feet_position: Vector3
var _frame_index := 0
var _seconds_in_frame := 0.0
var _view_step := 0
var _is_playing_once := false
var _has_hit_landed := false
var _hit_points_bar: Sprite3D
## World units from the feet up to where the HP bar and floating text sit.
var _overhead_height := 0.0


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
	_add_hit_points_bar()


## Switches animation from its first frame; a set without that animation keeps Idle.
func play(animation_name: String) -> void:
	var animation := _sprite_pack.resolved(animation_name)
	if animation == null:
		animation = _sprite_pack.resolved(IDLE_ANIMATION)
	_animation = animation
	_frame_index = 0
	_seconds_in_frame = 0.0
	_show_current_frame()


## Plays an animation through once (Idle if the set lacks it), emitting hit_landed at its hit frame and
## play_once_finished at its end, then goes back to Idle.
func play_once(animation_name: String) -> void:
	play(animation_name)
	_is_playing_once = true
	_has_hit_landed = false
	if _animation.hit_frame == 0:
		_land_hit()


## Redraws the HP bar from the unit's hit points.
func show_hit_points() -> void:
	var image := Image.create(HIT_POINTS_BAR_SIZE.x, HIT_POINTS_BAR_SIZE.y, false, Image.FORMAT_RGBA8)
	image.fill(HIT_POINTS_BAR_BACKGROUND)
	var share := float(_unit.hit_points) / maxf(_unit.max_hit_points, 1.0)
	var filled_width := ceili(HIT_POINTS_BAR_SIZE.x * share)
	if filled_width > 0:
		image.fill_rect(Rect2i(0, 0, filled_width, HIT_POINTS_BAR_SIZE.y), TurnBar.HIT_POINTS_COLOUR)
	_hit_points_bar.texture = ImageTexture.create_from_image(image)


## Text that rises over the unit and fades, for damage numbers and results such as "Miss".
func float_text(text: String, colour: Color) -> void:
	var label := Label3D.new()
	label.text = text
	label.modulate = colour
	label.font_size = FLOAT_TEXT_FONT_SIZE
	label.outline_size = FLOAT_TEXT_OUTLINE_SIZE
	label.pixel_size = 1.0 / PIXELS_PER_UNIT
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	label.no_depth_test = true
	label.render_priority = 2
	label.outline_render_priority = 1
	label.position = Vector3(0.0, _overhead_height, 0.0)
	add_child(label)
	var tween := label.create_tween()
	tween.set_parallel()
	tween.tween_property(label, "position:y", _overhead_height + FLOAT_TEXT_RISE, FLOAT_TEXT_SECONDS)
	tween.tween_property(label, "modulate:a", 0.0, FLOAT_TEXT_SECONDS).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(label.queue_free)


## Fades the unit and its HP bar out (a fainted unit leaves the map), then hides it.
func fade_out() -> void:
	_hit_points_bar.visible = false
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, FADE_OUT_SECONDS)
	tween.tween_callback(hide)


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


## Shows the unit's own facing (after the rules turned it without a walk).
func show_unit_facing() -> void:
	_face(_unit.facing)


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
	if _seconds_in_frame < seconds_for_frame:
		return
	_seconds_in_frame -= seconds_for_frame
	if _is_playing_once and _frame_index + 1 == _animation.frame_count():
		_finish_play_once()
		return
	_frame_index = (_frame_index + 1) % _animation.frame_count()
	_show_current_frame()
	if _is_playing_once and _frame_index == _animation.hit_frame:
		_land_hit()


func _land_hit() -> void:
	if not _has_hit_landed:
		_has_hit_landed = true
		hit_landed.emit()


func _finish_play_once() -> void:
	_is_playing_once = false
	_land_hit()
	play(IDLE_ANIMATION)
	play_once_finished.emit()


## The HP bar over the unit's head: as high above the feet as the Idle frame's top.
func _add_hit_points_bar() -> void:
	var idle := _sprite_pack.resolved(IDLE_ANIMATION)
	var feet_pixel := idle.feet_point(0, 0)
	var pixels_above_feet := feet_pixel.y + 1 if feet_pixel.x != SpritePack.NO_MARKER else idle.frame_size.y
	_overhead_height = pixels_above_feet / PIXELS_PER_UNIT + HIT_POINTS_BAR_LIFT
	_hit_points_bar = Sprite3D.new()
	_hit_points_bar.pixel_size = 1.0 / PIXELS_PER_UNIT
	_hit_points_bar.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_hit_points_bar.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_hit_points_bar.shaded = false
	_hit_points_bar.no_depth_test = true
	_hit_points_bar.render_priority = 1
	_hit_points_bar.position = Vector3(0.0, _overhead_height, 0.0)
	add_child(_hit_points_bar)
	show_hit_points()


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
