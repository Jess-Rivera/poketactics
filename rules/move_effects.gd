class_name MoveEffects
extends RefCounted
## One handler per component effect (issue #27, ruling 2026-11-17-move-recipe-structure, plan
## docs/discussion-outputs/move-recipes-plan.md). MoveUse picks a component's units and rolls; the handler only
## does the effect to one unit. A new kind of effect is a new handler here, never a branch in MoveUse.
## Effects with no handler yet (status, stat, heal, drain, recoil, multi_hit, flinch, element, needs_rule) are
## skipped before any roll. Rules only: no nodes and no drawing.

## Effect name to handler. Each handler takes (move_use, component, unit, outcome, random); outcome is the unit's
## Outcome for on-hit components and null for on-use ones.
static var _handlers := {
	MoveRecipe.EFFECT_DAMAGE: _damage,
	MoveRecipe.EFFECT_FIXED_DAMAGE: _fixed_damage,
	MoveRecipe.EFFECT_FAINT: _faint,
}


static func has_handler(effect_name: String) -> bool:
	return _handlers.has(effect_name)


## Does the component's effect to one unit. Call only when has_handler().
static func run(
	move_use: MoveUse,
	component: Dictionary,
	unit: BattleUnit,
	outcome: MoveUse.Outcome,
	random: RandomNumberGenerator
) -> void:
	_handlers[component["effect"]].call(move_use, component, unit, outcome, random)


## Formula damage: a crit roll, then the damage.
static func _damage(
	move_use: MoveUse,
	component: Dictionary,
	unit: BattleUnit,
	outcome: MoveUse.Outcome,
	random: RandomNumberGenerator
) -> void:
	outcome.is_critical_hit = BattleStats.rolls_critical_hit(move_use.critical_hit_stage(), random)
	outcome.damage = move_use.damage_to(unit, component, outcome.is_critical_hit)
	unit.take_damage(outcome.damage)


## Fixed damage (Night Shade): no crit roll.
static func _fixed_damage(
	move_use: MoveUse,
	component: Dictionary,
	unit: BattleUnit,
	outcome: MoveUse.Outcome,
	_random: RandomNumberGenerator
) -> void:
	outcome.damage = move_use.damage_to(unit, component, false)
	unit.take_damage(outcome.damage)


static func _faint(
	_move_use: MoveUse,
	_component: Dictionary,
	unit: BattleUnit,
	_outcome: MoveUse.Outcome,
	_random: RandomNumberGenerator
) -> void:
	unit.take_damage(unit.hit_points)
