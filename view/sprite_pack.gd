class_name SpritePack
extends RefCounted
## One packed sprite set from assets/pokemon/ (made by tools/pack_sprites.py): one sheet with every animation of the
## set, and its JSON description (where each animation sits, frame timing, feet and anchor points per frame).

const PACKED_FOLDER := "res://assets/pokemon"
const FACING_ROWS := 8
const NO_MARKER := -1


class PackedAnimation:
	var name: String
	## Where the animation's frames sit in the sheet: one column per frame, one row per facing.
	var region: Rect2i
	var frame_size: Vector2i
	## 8 (one row per facing) or 1 (drawn the same for every facing).
	var row_count := FACING_ROWS
	## How long each frame shows, in ticks of 1/60 second.
	var frame_durations: PackedInt32Array
	## The frame where an attack lands, or -1.
	var hit_frame := NO_MARKER
	var _feet_points: PackedInt32Array

	func frame_count() -> int:
		return frame_durations.size()

	## The part of the sheet to draw for this facing row and frame (one-row animations use their only row).
	func frame_region(row: int, frame_index: int) -> Rect2:
		var sheet_row := row if row_count == FACING_ROWS else 0
		return Rect2(region.position + Vector2i(frame_index * frame_size.x, sheet_row * frame_size.y), frame_size)

	## Frame-local pixel where the feet are (from the Shadow sheet), or (-1, -1) if the frame has no marker.
	func feet_point(row: int, frame_index: int) -> Vector2i:
		var sheet_row := row if row_count == FACING_ROWS else 0
		var point_index := (sheet_row * frame_count() + frame_index) * 2
		return Vector2i(_feet_points[point_index], _feet_points[point_index + 1])


var set_id: String
var sheet: Texture2D
var _animations_by_name: Dictionary = {}
var _copy_of_by_name: Dictionary = {}


## set_id is the packed file name without extension, for example "0004" or "0004-0000-0001".
static func load_set(sprite_set_id: String) -> SpritePack:
	var pack := SpritePack.new()
	pack.set_id = sprite_set_id
	var description := read_description(sprite_set_id)
	pack.sheet = load("%s/%s" % [PACKED_FOLDER, description["sheet"]])
	var animations: Dictionary = description["animations"]
	for animation_name in animations:
		var entry: Dictionary = animations[animation_name]
		if entry.has("copy_of"):
			pack._copy_of_by_name[animation_name] = entry["copy_of"]
			continue
		var animation := PackedAnimation.new()
		animation.name = animation_name
		var rect: Array = entry["rect"]
		animation.region = Rect2i(int(rect[0]), int(rect[1]), int(rect[2]), int(rect[3]))
		animation.frame_size = Vector2i(int(entry["frame_size"][0]), int(entry["frame_size"][1]))
		animation.row_count = int(entry["rows"])
		animation.frame_durations = PackedInt32Array(entry["durations"])
		animation.hit_frame = int(entry["hit_frame"])
		animation._feet_points = PackedInt32Array(entry["feet"])
		pack._animations_by_name[animation_name] = animation
	return pack


## The parsed JSON description of one packed set.
static func read_description(sprite_set_id: String) -> Dictionary:
	var json_text := FileAccess.get_file_as_string("%s/%s.json" % [PACKED_FOLDER, sprite_set_id])
	assert(json_text != "", "no packed sprite set %s" % sprite_set_id)
	return JSON.parse_string(json_text)


func has_animation(animation_name: String) -> bool:
	return _animations_by_name.has(animation_name) or _copy_of_by_name.has(animation_name)


## The animation drawn for this name (follows CopyOf), or null if the set does not have it.
func resolved(animation_name: String) -> PackedAnimation:
	return _animations_by_name.get(_copy_of_by_name.get(animation_name, animation_name))
