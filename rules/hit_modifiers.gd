class_name HitModifiers
extends RefCounted
## The resolve-time modifiers on one hit of a move (issue #17, rulings 2026-11-17-facing-height-rules and
## 2026-11-17-move-recipe-structure, plan docs/discussion-outputs/facing-height-plan.md): close range from the
## move, facing and height from where the hit comes from. Every source brings its own entry; damage multiplies
## them all and rounds once (BattleStats.modified_damage), so their order never changes the result. Later sources
## (status, ability, item, upgrade, tile, weather) add entries here. Rules only: no nodes and no drawing.

const SOURCE_CLOSE_RANGE := "close_range"
const SOURCE_FACING := "facing"
const SOURCE_HEIGHT := "height"


## One source's factor on the hit.
class Modifier:
	var source: String
	var factor: float

	func _init(modifier_source: String, modifier_factor: float) -> void:
		source = modifier_source
		factor = modifier_factor


## The defender's arc the hit comes from.
var arc := Facing.Arc.FRONT
## Height levels of the hit's origin above the defender (below 0 when attacking up), before the cap.
var levels_above := 0
var modifiers: Array[Modifier] = []


## The modifiers on a hit by the user (standing on user_cell, aimed at aimed_cell) on the defender.
static func for_hit(
	grid: BattleGrid,
	recipe: Dictionary,
	defender: BattleUnit,
	user_cell: Vector2i,
	aimed_cell: Vector2i
) -> HitModifiers:
	var hit := HitModifiers.new()
	var is_close := MoveArea.distance(user_cell, aimed_cell) == 1
	if is_close and MoveRecipe.has_modifier(recipe, MoveRecipe.MODIFIER_CLOSE_RANGE):
		hit.modifiers.append(Modifier.new(SOURCE_CLOSE_RANGE, BattleStats.CLOSE_RANGE_FACTOR))
	var origin := MoveArea.hit_origin(recipe, user_cell, aimed_cell, defender.cell)
	hit.arc = Facing.arc_of(defender.cell, defender.facing, origin)
	hit.levels_above = grid.height_level_at(origin) - grid.height_level_at(defender.cell)
	hit.modifiers.append(Modifier.new(SOURCE_FACING, BattleStats.arc_factor(hit.arc)))
	hit.modifiers.append(Modifier.new(SOURCE_HEIGHT, BattleStats.height_factor(hit.levels_above)))
	return hit


## The product of every modifier's factor (formula damage).
func product() -> float:
	var total := 1.0
	for modifier in modifiers:
		total *= modifier.factor
	return total


## The product of the modifiers that apply to fixed damage: close range only (facing and height do not).
func fixed_damage_product() -> float:
	var total := 1.0
	for modifier in modifiers:
		if modifier.source == SOURCE_CLOSE_RANGE:
			total *= modifier.factor
	return total
