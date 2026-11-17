class_name TurnOrder
extends RefCounted
## Whose turn it is, on the strike rank clock (issue #13, rulings 2026-11-16-strike-rank-clock,
## 2026-11-17-size-bands, 2026-11-17-wait-action; plan docs/discussion-outputs/strike-rank-plan.md).
##
## The clock counts SR from 1 across the whole battle; a round is ROUND_LENGTH SR, and the upkeep step runs once
## for every round boundary the clock passes. Each unit's first turn is at SR 1 + its base SR. On its turn a unit
## takes exactly one action (a walk, a move used, or a Wait) and then ends the turn facing a chosen way; its next
## turn is at now + cost + base SR, or now + w after a Wait of w. On the same SR a unit that waited goes first,
## then higher Speed, then a number drawn once per unit from the battle seed, so the order replays. Rules only.

const ROUND_LENGTH := 12
## The turn's cost before the active unit has taken its action.
const NO_ACTION := -1


## One forecast entry: a unit, the round and SR of its turn, and whether it is the active unit's landing preview.
class Slot:
	var unit: BattleUnit
	var round_number: int
	var strike_rank: int
	var is_landing: bool

	func _init(slot_unit: BattleUnit, clock_position: int, slot_is_landing := false) -> void:
		unit = slot_unit
		round_number = TurnOrder.round_of(clock_position)
		strike_rank = TurnOrder.strike_rank_in_round(clock_position)
		is_landing = slot_is_landing


## The round being played, from 1; it goes up in the upkeep step. Stays 0 only if no unit could ever act.
var round_number := 0
var _battle: Battle
var _tiebreak_by_unit := {}
## Clock position of each unit's next turn (the active unit's is now).
var _next_turn_by_unit := {}
## Units whose next turn comes from a Wait.
var _waited_by_unit := {}
var _clock := 1
## The unit the turn state below belongs to.
var _turn_unit: BattleUnit
var _turn_cost := NO_ACTION
var _turn_is_wait := false


func _init(battle: Battle, random: RandomNumberGenerator) -> void:
	_battle = battle
	for unit in battle.units:
		_tiebreak_by_unit[unit] = random.randi()
		_next_turn_by_unit[unit] = 1 + unit.base_strike_rank
		_waited_by_unit[unit] = false
	var first := _earliest_standing_unit()
	if first != null:
		round_number = 1
		_clock = _next_turn_by_unit[first]
		_turn_unit = first


static func speed_of(unit: BattleUnit) -> int:
	return int(unit.stats.get("speed", 0))


## The round a clock position falls in, from 1.
static func round_of(clock_position: int) -> int:
	return (clock_position - 1) / ROUND_LENGTH + 1


## The SR within its round of a clock position, 1 to ROUND_LENGTH.
static func strike_rank_in_round(clock_position: int) -> int:
	return (clock_position - 1) % ROUND_LENGTH + 1


## The unit whose turn it is, or null if no unit is standing or the battle is over (so nothing moves, acts or ends
## a turn after the end, #12).
func active_unit() -> BattleUnit:
	if _battle.is_over():
		return null
	_settle()
	return _turn_unit


## The SR within the round of the turn being played.
func current_strike_rank() -> int:
	return strike_rank_in_round(_clock)


## Clock position of a unit's next turn (now for the active unit); round_of and strike_rank_in_round read it.
func next_turn_of(unit: BattleUnit) -> int:
	return _next_turn_by_unit.get(unit, 0)


## Whether the unit is the active unit and has not yet taken its one action (a walk, a move used or a Wait).
func can_take_action(unit: BattleUnit) -> bool:
	return unit != null and unit == active_unit() and _turn_cost == NO_ACTION


## Whether the active unit has taken its action, so the turn may end.
func has_taken_action() -> bool:
	return active_unit() != null and _turn_cost != NO_ACTION


## Walks the unit along a path (from Movement.reachable_paths) if it is the active unit and has taken no action.
## Returns whether it walked.
func move_unit(unit: BattleUnit, path: Array[Vector2i], end_facing: Facing.Direction) -> bool:
	if not can_take_action(unit) or path.is_empty():
		return false
	var cost := Movement.walk_cost(_battle.grid, unit.cell, path)
	if cost > Movement.MAX_WALK_COST:
		return false
	_battle.move_unit(unit, path, end_facing)
	_turn_cost = cost
	return true


## Carries out a move use if its user is the active unit, has taken no action, and the use is allowed. Returns
## whether it acted; the use then holds the outcomes, and the battle is settled if a side was routed.
func use_move(move_use: MoveUse, random: RandomNumberGenerator) -> bool:
	if not can_take_action(move_use.user) or not move_use.is_allowed():
		return false
	move_use.resolve(random)
	_battle.settle_rout(move_use.user.side)
	_turn_cost = move_use.strike_rank_cost()
	return true


## The longest Wait allowed now: up to the end of this round, and at least 1 (from SR 12 it lands on SR 1 next round).
func wait_limit() -> int:
	return maxi(ROUND_LENGTH - current_strike_rank(), 1)


## Waits strike_ranks SR (1 to wait_limit()) if the unit is the active unit and has taken no action. Returns whether
## it waited.
func wait(unit: BattleUnit, strike_ranks: int) -> bool:
	if not can_take_action(unit) or strike_ranks < 1 or strike_ranks > wait_limit():
		return false
	_turn_cost = strike_ranks
	_turn_is_wait = true
	return true


## Turns the active unit to its end facing and schedules its next turn, once it has taken its action. The clock
## then moves on to the next turn, running upkeep for every round boundary it passes. Returns whether the turn ended.
func end_turn(end_facing: Facing.Direction) -> bool:
	var unit := active_unit()
	if unit == null or _turn_cost == NO_ACTION:
		return false
	unit.facing = end_facing
	_next_turn_by_unit[unit] = _landing_of(_turn_cost, _turn_is_wait)
	_waited_by_unit[unit] = _turn_is_wait
	_turn_unit = null
	_settle()
	return true


## Each standing unit's next turn, soonest first (the active unit first), at most count. With a landing cost, the
## active unit also appears where that action would put it, marked as the landing.
func forecast(count: int, landing_cost := NO_ACTION, landing_is_wait := false) -> Array[Slot]:
	var slots: Array[Slot] = []
	_settle()
	if _turn_unit == null:
		return slots
	for unit in _ranked_standing_units():
		slots.append(Slot.new(unit, _next_turn_by_unit[unit]))
	if landing_cost != NO_ACTION:
		var landing := _landing_of(landing_cost, landing_is_wait)
		var index := 1
		while index < slots.size() and _turn_comes_before(
			slots[index].unit, _next_turn_by_unit[slots[index].unit], _waited_by_unit[slots[index].unit],
			_turn_unit, landing, landing_is_wait
		):
			index += 1
		slots.insert(index, Slot.new(_turn_unit, landing, true))
	return slots.slice(0, count)


## Clock position the active unit's next turn would be at after an action of this cost (a Wait adds no base SR).
func _landing_of(cost: int, is_wait: bool) -> int:
	return _clock + cost + (0 if is_wait else _turn_unit.base_strike_rank)


## Makes the earliest standing unit the active one. When it changes (a turn ended, or the active unit fainted on
## its own move) its turn starts fresh and the clock moves to it.
func _settle() -> void:
	var earliest := _earliest_standing_unit()
	if earliest == _turn_unit:
		return
	_turn_unit = earliest
	_turn_cost = NO_ACTION
	_turn_is_wait = false
	if earliest == null:
		return
	var next_clock: int = _next_turn_by_unit[earliest]
	while round_of(_clock) < round_of(next_clock):
		_clock += ROUND_LENGTH
		_upkeep()
	_clock = next_clock


## Between rounds: the round number goes up. Status, weather and tile effects join it in later slices.
func _upkeep() -> void:
	round_number += 1


func _earliest_standing_unit() -> BattleUnit:
	var ranked := _ranked_standing_units()
	return ranked.front() if not ranked.is_empty() else null


## Standing units by next turn, by the tie rule in _turn_comes_before.
func _ranked_standing_units() -> Array[BattleUnit]:
	var ranked: Array[BattleUnit] = []
	for unit in _battle.units:
		if not unit.has_fainted():
			ranked.append(unit)
	ranked.sort_custom(_acts_before)
	return ranked


func _acts_before(first: BattleUnit, second: BattleUnit) -> bool:
	return _turn_comes_before(
		first, _next_turn_by_unit[first], _waited_by_unit[first], second, _next_turn_by_unit[second], _waited_by_unit[second]
	)


## The tie rule for two turns: earlier first; on the same SR a Wait first, then higher Speed, then the seeded
## tiebreak, then join order.
func _turn_comes_before(
	first: BattleUnit, first_turn: int, first_waited: bool, second: BattleUnit, second_turn: int, second_waited: bool
) -> bool:
	if first_turn != second_turn:
		return first_turn < second_turn
	if first_waited != second_waited:
		return first_waited
	if speed_of(first) != speed_of(second):
		return speed_of(first) > speed_of(second)
	if _tiebreak_by_unit[first] != _tiebreak_by_unit[second]:
		return _tiebreak_by_unit[first] > _tiebreak_by_unit[second]
	return _battle.units.find(first) < _battle.units.find(second)
