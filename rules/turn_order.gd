class_name TurnOrder
extends RefCounted
## Who acts next (issue #8, docs/discussion-outputs/turn-order-plan.md): rounds in which every standing unit
## acts once, fastest first. Equal Speed is broken by a number drawn once per unit from the battle seed, so the
## order is stable and replayable. A round's order is fixed when it starts, so Speed changes count from the next
## round. A turn holds at most one move and one action (a move used, #10), in either order, and ends with the unit
## turned to a chosen facing. Rules only, no nodes.


## One forecast entry: a unit and the round it acts in.
class Slot:
	var unit: BattleUnit
	var round_number: int

	func _init(slot_unit: BattleUnit, slot_round_number: int) -> void:
		unit = slot_unit
		round_number = slot_round_number


## The round being played, from 1. Stays 0 only if no unit could ever act.
var round_number := 0
var _battle: Battle
var _tiebreak_by_unit := {}
## This round's units still to act, the active unit first.
var _still_to_act: Array[BattleUnit] = []
var _active_unit_has_moved := false
var _active_unit_has_acted := false


func _init(battle: Battle, random: RandomNumberGenerator) -> void:
	_battle = battle
	for unit in battle.units:
		_tiebreak_by_unit[unit] = random.randi()
	_start_round()


static func speed_of(unit: BattleUnit) -> int:
	return int(unit.stats.get("speed", 0))


## The unit whose turn it is, or null if no unit is standing or the battle is over (so nothing moves, acts or ends
## a turn after the end, #12).
func active_unit() -> BattleUnit:
	if _battle.is_over():
		return null
	_drop_fainted()
	return _still_to_act.front() if not _still_to_act.is_empty() else null


func can_move(unit: BattleUnit) -> bool:
	return unit != null and unit == active_unit() and not _active_unit_has_moved


## Moves the unit along a path (from Movement.reachable_paths) if it is the active unit and has not moved this
## turn. Returns whether it moved.
func move_unit(unit: BattleUnit, path: Array[Vector2i], end_facing: Facing.Direction) -> bool:
	if not can_move(unit):
		return false
	_battle.move_unit(unit, path, end_facing)
	_active_unit_has_moved = true
	return true


func can_act(unit: BattleUnit) -> bool:
	return unit != null and unit == active_unit() and not _active_unit_has_acted


## Carries out a move use if its user is the active unit, has not acted this turn, and the use is allowed.
## Returns whether it acted; the use then holds the outcomes, and the battle is settled if a side was routed.
func use_move(move_use: MoveUse, random: RandomNumberGenerator) -> bool:
	if not can_act(move_use.user) or not move_use.is_allowed():
		return false
	move_use.resolve(random)
	_battle.settle_rout(move_use.user.side)
	_active_unit_has_acted = true
	return true


## Turns the active unit to its end facing and passes the turn on, starting a new round when this one is done.
func end_turn(end_facing: Facing.Direction) -> void:
	var unit := active_unit()
	if unit == null:
		return
	unit.facing = end_facing
	_still_to_act.pop_front()
	_active_unit_has_moved = false
	_active_unit_has_acted = false
	_drop_fainted()
	if _still_to_act.is_empty():
		_start_round()


## The next count turns as they stand now: the rest of this round, then later rounds in the order the current
## Speeds give. Shorter only if no unit is standing.
func forecast(count: int) -> Array[Slot]:
	_drop_fainted()
	var slots: Array[Slot] = []
	for unit in _still_to_act:
		if slots.size() == count:
			return slots
		slots.append(Slot.new(unit, round_number))
	var later_order := _ranked_standing_units()
	if later_order.is_empty():
		return slots
	var later_round := round_number + 1
	while slots.size() < count:
		for unit in later_order:
			if slots.size() == count:
				break
			slots.append(Slot.new(unit, later_round))
		later_round += 1
	return slots


func _start_round() -> void:
	_still_to_act = _ranked_standing_units()
	if not _still_to_act.is_empty():
		round_number += 1


## Standing units, fastest first; equal Speed by the seeded tiebreak, then by join order.
func _ranked_standing_units() -> Array[BattleUnit]:
	var ranked: Array[BattleUnit] = []
	for unit in _battle.units:
		if not unit.has_fainted():
			ranked.append(unit)
	ranked.sort_custom(_acts_before)
	return ranked


func _acts_before(first: BattleUnit, second: BattleUnit) -> bool:
	if speed_of(first) != speed_of(second):
		return speed_of(first) > speed_of(second)
	if _tiebreak_by_unit[first] != _tiebreak_by_unit[second]:
		return _tiebreak_by_unit[first] > _tiebreak_by_unit[second]
	return _battle.units.find(first) < _battle.units.find(second)


func _drop_fainted() -> void:
	var was_active: BattleUnit = _still_to_act.front() if not _still_to_act.is_empty() else null
	_still_to_act.assign(_still_to_act.filter(func(unit: BattleUnit) -> bool: return not unit.has_fainted()))
	var active_now: BattleUnit = _still_to_act.front() if not _still_to_act.is_empty() else null
	if active_now != was_active:
		_active_unit_has_moved = false
		_active_unit_has_acted = false
	if _still_to_act.is_empty() and was_active != null:
		_start_round()
