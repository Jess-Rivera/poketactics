class_name PackData
extends RefCounted
## The data pack (data/*.json, built by tools/export_pack.py), loaded once and looked up by pokeapi name.
## Entries stay as the pack's dictionaries; their fields are described in data/README.md.
## Rules only: no nodes and no drawing. Ruling: docs/decisions/2026-11-15-data-pack-shape.md.

const PACK_FOLDER := "res://data"

static var _shared: PackData

var units: Dictionary
var moves: Dictionary
var abilities: Dictionary
var types: Dictionary


## The pack, read from disk on first use and kept for the rest of the run.
static func shared() -> PackData:
	if _shared == null:
		_shared = PackData.new()
		_shared.units = _read_pack_file("units.json")
		_shared.moves = _read_pack_file("moves.json")
		_shared.abilities = _read_pack_file("abilities.json")
		_shared.types = _read_pack_file("types.json")
	return _shared


func unit(unit_name: String) -> Dictionary:
	return _look_up(units, "unit", unit_name)


func move(move_name: String) -> Dictionary:
	return _look_up(moves, "move", move_name)


func ability(ability_name: String) -> Dictionary:
	return _look_up(abilities, "ability", ability_name)


func type_entry(type_name: String) -> Dictionary:
	return _look_up(types, "type", type_name)


## A name not in the pack is a bug in the caller, so it is reported loudly and an empty entry comes back.
func _look_up(table: Dictionary, kind: String, entry_name: String) -> Dictionary:
	if not table.has(entry_name):
		push_error("data pack has no %s named '%s'" % [kind, entry_name])
		return {}
	return table[entry_name]


static func _read_pack_file(file_name: String) -> Dictionary:
	var path := "%s/%s" % [PACK_FOLDER, file_name]
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		push_error("data pack file %s is missing or does not parse; run python tools/export_pack.py" % path)
		return {}
	return parsed
