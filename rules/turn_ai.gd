class_name TurnAi
extends RefCounted
## The M1 enemy AI (issue #11, docs/discussion-outputs/enemy-turn-opening.md, ruling 2026-11-17-enemy-ai-m1): a
## one-turn scorer. It lists every cell the unit can stand on, every damaging move and every target from there,
## scores each option by what it would hit, and takes the best. With no attack worth making it walks toward the
## nearest foe. Rules only: it reads the board and returns a Choice, never changes the board, and never rolls, so
## the same board always gives the same choice.
##
## Score of one option, per unit in its footprint: hit chance x (expected non-crit damage, capped at the unit's HP,
## as a fraction of its max HP), plus KNOCKOUT_BONUS if that damage knocks it out. Foes add, allies and the user
## subtract; a move that makes its user faint subtracts the user as if knocked out. Ties go to the shorter walk.

## Worth a full unit, so any knockout outscores any hit that does not knock out (HP fractions never reach 1 without
## a knockout).
const KNOCKOUT_BONUS := 1.0


## What the unit does this turn: walk (path may be empty), then use a move (move_name may be empty), then face.
class Choice:
	## The cells stepped on in order, the start left out; empty to stay put.
	var path: Array[Vector2i] = []
	## Where the unit stands when it acts and ends its turn.
	var stand_cell: Vector2i
	## The move to use, or empty for no action.
	var move_name := ""
	var target_cell: Vector2i
	var direction: Facing.Direction
	var end_facing: Facing.Direction
	## The option's score; only compared while choosing.
	var score := 0.0

	func has_walk() -> bool:
		return not path.is_empty()

	func has_move() -> bool:
		return not move_name.is_empty()


## The unit's choice for this turn on the board as it stands.
static func choose(battle: Battle, pack: PackData, unit: BattleUnit) -> Choice:
	var paths := Movement.reachable_paths(battle, unit)
	var choice := _best_attack(battle, pack, unit, paths)
	if choice == null:
		choice = _approach(battle, unit, paths)
	choice.end_facing = _facing_toward_nearest_foe(battle, unit, choice.stand_cell)
	return choice


## The highest scoring attack from any stand cell, or null when no option scores above 0.
static func _best_attack(battle: Battle, pack: PackData, unit: BattleUnit, paths: Dictionary) -> Choice:
	var best: Choice = null
	for stand_cell in _stand_cells(unit, paths):
		for option in _options_from(battle, pack, unit, stand_cell):
			option.path = paths.get(stand_cell, [] as Array[Vector2i])
			option.score = _score(battle, pack, unit, option)
			if option.score > 0.0 and _beats(option, best):
				best = option
	return best


## The unit's own cell, then every cell it can walk to.
static func _stand_cells(unit: BattleUnit, paths: Dictionary) -> Array[Vector2i]:
	var cells: Array[Vector2i] = [unit.cell]
	cells.append_array(paths.keys())
	return cells


## A higher score wins; an equal score wins only with a shorter walk, so the first found keeps the rest of the ties.
static func _beats(option: Choice, best: Choice) -> bool:
	if best == null or option.score > best.score:
		return true
	return option.score == best.score and option.path.size() < best.path.size()


## Every damaging move and target the unit could use from a stand cell: each target cell in reach, or each of the
## four directions for a cone or line aimed from the user.
static func _options_from(battle: Battle, pack: PackData, unit: BattleUnit, stand_cell: Vector2i) -> Array[Choice]:
	var options: Array[Choice] = []
	for move_name in unit.move_names:
		var grid_entry = pack.move(move_name).get("grid")
		if grid_entry == null or not MoveUse.deals_damage(grid_entry):
			continue
		if MoveUse.is_aimed(grid_entry):
			for direction in Facing.ALL_DIRECTIONS:
				options.append(_option(stand_cell, move_name, stand_cell, direction))
			continue
		for target_cell in MoveArea.target_cells(battle.grid, grid_entry, stand_cell):
			var direction := unit.facing
			if target_cell != stand_cell:
				direction = Facing.direction_of_step(target_cell - stand_cell)
			options.append(_option(stand_cell, move_name, target_cell, direction))
	return options


static func _option(
	stand_cell: Vector2i, move_name: String, target_cell: Vector2i, direction: Facing.Direction
) -> Choice:
	var option := Choice.new()
	option.stand_cell = stand_cell
	option.move_name = move_name
	option.target_cell = target_cell
	option.direction = direction
	return option


## The option's score: foes hit add, allies and the user subtract, and a user that faints counts as knocked out.
static func _score(battle: Battle, pack: PackData, unit: BattleUnit, option: Choice) -> float:
	var move := pack.move(option.move_name)
	var chance := BattleStats.hit_chance(move)
	var total := 0.0
	for hit_unit in _units_hit_from(battle, pack, unit, option):
		var damage := MoveUse.hit_damage(
			pack, unit, hit_unit, option.move_name, option.stand_cell, option.target_cell, false
		)
		var value := chance * _damage_value(hit_unit, damage)
		total += value if hit_unit.side != unit.side else -value
	if MoveUse.has_effect(move["grid"], MoveUse.EFFECT_USER_FAINTS):
		total -= _damage_value(unit, unit.hit_points)
	return total


## The share of the unit's max HP the damage takes (capped at what it has left), plus KNOCKOUT_BONUS on a knockout.
static func _damage_value(unit: BattleUnit, damage: int) -> float:
	if damage <= 0 or unit.max_hit_points <= 0:
		return 0.0
	var value := float(mini(damage, unit.hit_points)) / unit.max_hit_points
	if damage >= unit.hit_points:
		value += KNOCKOUT_BONUS
	return value


## The units the option's footprint covers, as if the unit already stood on the option's cell: its start cell is
## empty and its stand cell holds it.
static func _units_hit_from(battle: Battle, pack: PackData, unit: BattleUnit, option: Choice) -> Array[BattleUnit]:
	var grid_entry: Dictionary = pack.move(option.move_name)["grid"]
	var hit: Array[BattleUnit] = []
	var footprint := MoveArea.footprint(
		pack.shapes, grid_entry, option.stand_cell, option.target_cell, option.direction
	)
	for cell in footprint:
		var standing := _unit_seen_at(battle, unit, option.stand_cell, cell)
		if standing != null and not hit.has(standing):
			hit.append(standing)
	return hit


static func _unit_seen_at(battle: Battle, unit: BattleUnit, stand_cell: Vector2i, cell: Vector2i) -> BattleUnit:
	if cell == stand_cell:
		return unit
	if cell == unit.cell:
		return null
	return battle.unit_at(cell)


## No attack worth making: walk to the reachable cell closest by path to any foe, or stay if none is closer.
## Paths come in breadth-first order, so of equally close cells the shortest walk is found first and kept.
static func _approach(battle: Battle, unit: BattleUnit, paths: Dictionary) -> Choice:
	var steps_to_foe := _steps_to_nearest_foe(battle, unit)
	var best_cell := unit.cell
	for cell in paths:
		if _is_closer(steps_to_foe, cell, best_cell):
			best_cell = cell
	var choice := Choice.new()
	choice.stand_cell = best_cell
	if best_cell != unit.cell:
		choice.path = paths[best_cell]
	return choice


static func _is_closer(steps_to_foe: Dictionary, cell: Vector2i, other_cell: Vector2i) -> bool:
	if not steps_to_foe.has(cell):
		return false
	if not steps_to_foe.has(other_cell):
		return true
	return steps_to_foe[cell] < steps_to_foe[other_cell]


## Walking steps from every cell to the nearest standing foe, by the height rule alone (units are ignored, so a
## walled-in foe still pulls). One breadth-first pass outward from all foes; cells no foe can be walked to from are
## left out.
static func _steps_to_nearest_foe(battle: Battle, unit: BattleUnit) -> Dictionary:
	var steps_to_foe := {}
	var frontier: Array[Vector2i] = []
	for foe in _standing_foes(battle, unit):
		steps_to_foe[foe.cell] = 0
		frontier.append(foe.cell)
	while not frontier.is_empty():
		var cell: Vector2i = frontier.pop_front()
		for direction in Facing.ALL_DIRECTIONS:
			var walker_cell: Vector2i = cell + Facing.grid_step(direction)
			if steps_to_foe.has(walker_cell) or not battle.grid.contains(walker_cell):
				continue
			if not Movement.can_step(battle.grid, walker_cell, cell):
				continue
			steps_to_foe[walker_cell] = steps_to_foe[cell] + 1
			frontier.append(walker_cell)
	return steps_to_foe


## Toward the nearest standing foe by grid distance (the first in join order on a tie); the current facing if none.
static func _facing_toward_nearest_foe(battle: Battle, unit: BattleUnit, stand_cell: Vector2i) -> Facing.Direction:
	var nearest: BattleUnit = null
	for foe in _standing_foes(battle, unit):
		if nearest == null or MoveArea.distance(stand_cell, foe.cell) < MoveArea.distance(stand_cell, nearest.cell):
			nearest = foe
	if nearest == null or nearest.cell == stand_cell:
		return unit.facing
	return Facing.direction_of_step(nearest.cell - stand_cell)


static func _standing_foes(battle: Battle, unit: BattleUnit) -> Array[BattleUnit]:
	var foes: Array[BattleUnit] = []
	for other in battle.units:
		if other.side != unit.side and not other.has_fainted():
			foes.append(other)
	return foes
