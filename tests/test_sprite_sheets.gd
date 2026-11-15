extends GdUnitTestSuite
## Packed sprite sets (tools/pack_sprites.py, docs/discussion-outputs/sprite-pack-plan.md), checked for every set.
## Issue #1 relation 4, widened: every animation is 8 rows (one per facing) or 1 row (same for all facings) of its
## frame height, and one column per frame. Plus: every raw set is packed, sheets fit 8192, animations never overlap.

const RAW_FOLDER := "res://source/spritecollab"
const PACKED_FOLDER := "res://assets/pokemon"
const LARGEST_SHEET_SIZE := 8192
const ALLOWED_ROW_COUNTS := [1, 8]
const PNG_SIZE_OFFSET := 16


func test_every_raw_sprite_set_has_a_packed_set_and_no_more() -> void:
	var raw_set_ids := _raw_set_ids(ProjectSettings.globalize_path(RAW_FOLDER), "")
	var packed_set_ids := _packed_set_ids()
	assert_int(raw_set_ids.size()).is_greater(0)
	assert_array(packed_set_ids).contains_exactly_in_any_order(raw_set_ids)


func test_every_packed_animation_is_whole_rows_and_columns_of_its_frames() -> void:
	for set_id in _packed_set_ids():
		var description := SpritePack.read_description(set_id)
		for animation_name in description["animations"]:
			var entry: Dictionary = description["animations"][animation_name]
			if entry.has("copy_of"):
				continue
			var where := "%s %s" % [set_id, animation_name]
			var rows := int(entry["rows"])
			var frame_count: int = entry["durations"].size()
			assert_bool(rows in ALLOWED_ROW_COUNTS).override_failure_message(where).is_true()
			assert_int(int(entry["rect"][3])).override_failure_message(where).is_equal(rows * int(entry["frame_size"][1]))
			assert_int(int(entry["rect"][2])).override_failure_message(where).is_equal(frame_count * int(entry["frame_size"][0]))
			assert_int(entry["feet"].size()).override_failure_message(where).is_equal(rows * frame_count * 2)
			for colour_name in entry["anchors"]:
				assert_int(entry["anchors"][colour_name].size()).override_failure_message(where).is_equal(rows * frame_count * 2)


func test_every_sheet_fits_8192_matches_its_png_and_holds_its_animations_without_overlap() -> void:
	for set_id in _packed_set_ids():
		var description := SpritePack.read_description(set_id)
		var sheet_size := Vector2i(int(description["sheet_size"][0]), int(description["sheet_size"][1]))
		assert_bool(sheet_size.x <= LARGEST_SHEET_SIZE and sheet_size.y <= LARGEST_SHEET_SIZE) \
			.override_failure_message("%s is %s" % [set_id, sheet_size]).is_true()
		assert_that(_png_size("%s/%s" % [PACKED_FOLDER, description["sheet"]])) \
			.override_failure_message(set_id).is_equal(sheet_size)
		var sheet_rect := Rect2i(Vector2i.ZERO, sheet_size)
		var placed: Array[Rect2i] = []
		for animation_name in description["animations"]:
			var entry: Dictionary = description["animations"][animation_name]
			if entry.has("copy_of"):
				continue
			var rect := Rect2i(int(entry["rect"][0]), int(entry["rect"][1]), int(entry["rect"][2]), int(entry["rect"][3]))
			assert_bool(sheet_rect.encloses(rect)).override_failure_message("%s %s" % [set_id, animation_name]).is_true()
			for other in placed:
				assert_bool(rect.intersects(other)).override_failure_message("%s %s overlaps" % [set_id, animation_name]).is_false()
			placed.append(rect)


func test_every_copy_of_points_to_a_packed_animation() -> void:
	for set_id in _packed_set_ids():
		var animations: Dictionary = SpritePack.read_description(set_id)["animations"]
		for animation_name in animations:
			var entry: Dictionary = animations[animation_name]
			if entry.has("copy_of"):
				assert_bool(animations.has(entry["copy_of"]) and not animations[entry["copy_of"]].has("copy_of")) \
					.override_failure_message("%s %s" % [set_id, animation_name]).is_true()


func test_every_set_has_the_core_idle_animation() -> void:
	for set_id in _packed_set_ids():
		var animations: Dictionary = SpritePack.read_description(set_id)["animations"]
		assert_bool(animations.has("Idle")).override_failure_message(set_id).is_true()


## Raw set folders hold an AnimData.xml; the id is the folder path joined by dashes, as the packer names them.
func _raw_set_ids(folder_path: String, id_prefix: String) -> Array[String]:
	var set_ids: Array[String] = []
	if FileAccess.file_exists(folder_path.path_join("AnimData.xml")) and id_prefix != "":
		set_ids.append(id_prefix)
	for child_name in DirAccess.get_directories_at(folder_path):
		var child_id := child_name if id_prefix == "" else "%s-%s" % [id_prefix, child_name]
		set_ids.append_array(_raw_set_ids(folder_path.path_join(child_name), child_id))
	return set_ids


func _packed_set_ids() -> Array[String]:
	var set_ids: Array[String] = []
	for file_name in DirAccess.get_files_at(PACKED_FOLDER):
		if file_name.get_extension() == "json":
			set_ids.append(file_name.get_basename())
	return set_ids


## Width and height from a PNG file's header, without importing it.
func _png_size(png_path: String) -> Vector2i:
	var header := FileAccess.get_file_as_bytes(png_path).slice(PNG_SIZE_OFFSET, PNG_SIZE_OFFSET + 8)
	header.reverse()
	return Vector2i(header.decode_u32(4), header.decode_u32(0))
