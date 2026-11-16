class_name PortraitLoader
extends RefCounted
## The one way into the packed portraits (issue #16, docs/discussion-outputs/six-a-side-opening.md): one sheet per
## emotion and colour in assets/portraits/ (made by tools/pack_portraits.py), every sheet the same grid of 40x40
## cells, and portraits.json giving each sprite set's cell or the set it falls back to. Callers ask for a set and
## an emotion and get a texture back; how the cells are stored can change here without touching them.

const PACKED_FOLDER := "res://assets/portraits"
const INDEX_FILE := "portraits.json"
const NORMAL_EMOTION := "Normal"
const NORMAL_COLOUR := "normal"
const SHINY_COLOUR := "shiny"
const PLACEHOLDER := "placeholder"
const NORMAL_FORM_FOLDER := "0000"
const SHINY_FOLDER := "0001"
## Longer fallback chains than this mean the index loops, which the packer never writes.
const MAX_FALLBACK_STEPS := 4

static var _index: Dictionary
static var _sheets_by_path := {}


## The parsed portraits.json, loaded once.
static func index() -> Dictionary:
	if _index.is_empty():
		var text := FileAccess.get_file_as_string("%s/%s" % [PACKED_FOLDER, INDEX_FILE])
		var parsed = JSON.parse_string(text)
		assert(parsed is Dictionary, "assets/portraits/portraits.json is missing or broken; run tools/pack_portraits.py")
		_index = parsed
	return _index


## The sprite set id whose portrait a pack unit (or transformation) shows: its own sprite set, or else its
## species' normal set from the dex number. Shiny adds SpriteCollab's shiny folder.
static func set_id_for(pack_entry: Dictionary, dex_number: int, shiny := false) -> String:
	var set_id = pack_entry.get("sprite_set")
	if set_id == null:
		set_id = "%04d" % dex_number
	if not shiny:
		return set_id
	if set_id.contains("-"):
		return "%s-%s" % [set_id, SHINY_FOLDER]
	return "%s-%s-%s" % [set_id, NORMAL_FORM_FOLDER, SHINY_FOLDER]


## Follows fallbacks to the set whose cell is drawn. Returns {cell, colour, emotions, placeholder}; an unknown
## set or a chain ending in the placeholder gives the placeholder cell of the normal sheet.
static func resolve(set_id: String) -> Dictionary:
	var sets: Dictionary = index()["sets"]
	var current := set_id
	for _step in MAX_FALLBACK_STEPS:
		var entry = sets.get(current)
		if entry == null or entry.get("fallback") == PLACEHOLDER:
			break
		if entry.has("cell"):
			return {"cell": int(entry["cell"]), "colour": entry["colour"], "emotions": entry["emotions"], "placeholder": false}
		current = entry["fallback"]
	return {
		"cell": int(index()["placeholder_cell"]),
		"colour": NORMAL_COLOUR,
		"emotions": [NORMAL_EMOTION],
		"placeholder": true,
	}


## The pixel rectangle of a cell in every sheet.
static func cell_rect(cell: int) -> Rect2i:
	var cell_size := int(index()["cell_size"])
	var columns := int(index()["columns"])
	return Rect2i((cell % columns) * cell_size, floori(float(cell) / columns) * cell_size, cell_size, cell_size)


## A set's portrait for an emotion (Normal when the set lacks that emotion), as a 40x40 region of its sheet.
static func portrait(set_id: String, emotion := NORMAL_EMOTION) -> AtlasTexture:
	var resolved := resolve(set_id)
	var shown_emotion := emotion if resolved["emotions"].has(emotion) else NORMAL_EMOTION
	var sheet_name: String = index()["sheets"][resolved["colour"]][shown_emotion]
	var texture := AtlasTexture.new()
	texture.atlas = _sheet("%s/%s" % [PACKED_FOLDER, sheet_name])
	texture.region = Rect2(cell_rect(resolved["cell"]))
	return texture


## The middle of a portrait cut to crop_size (at most the cell), one portrait pixel per screen pixel.
static func cropped(full_portrait: AtlasTexture, crop_size: Vector2) -> AtlasTexture:
	var region := full_portrait.region
	var size := Vector2(minf(crop_size.x, region.size.x), minf(crop_size.y, region.size.y))
	var texture := AtlasTexture.new()
	texture.atlas = full_portrait.atlas
	texture.region = Rect2((region.get_center() - size / 2.0).floor(), size)
	return texture


static func _sheet(path: String) -> Texture2D:
	if not _sheets_by_path.has(path):
		_sheets_by_path[path] = load(path)
	return _sheets_by_path[path]
