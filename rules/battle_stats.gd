class_name BattleStats
extends RefCounted
## The one stats module: every combat formula lives here (CLAUDE.md "Coding conventions").
## Mainline formulas per docs/decisions/2026-11-15-unit-stats-and-moves.md and 2026-11-15-damage-and-hit.md:
## IVs and EVs count as 0 with a neutral nature, no random damage spread, and only the accuracy and crit
## checks are random. Random checks take a RandomNumberGenerator from the caller, so tests can replay a seed.
## Plan: docs/discussion-outputs/pack-loader-plan.md (issue #5).

const STAT_KEYS := ["hp", "attack", "defense", "special_attack", "special_defense", "speed"]
const MOVES_KNOWN := 4
const SAME_TYPE_BONUS := 1.5
const CRITICAL_HIT_BONUS := 1.5
## Mainline crit chance (Gen 6 on) by crit stage: 1 in 24, 1 in 8, 1 in 2, then always.
const CRITICAL_HIT_ODDS_BY_STAGE := [24, 8, 2, 1]
const ALWAYS_HITS_ACCURACY := 100
## A ranged move that hits from range 1 does this share of its damage (2026-11-16-move-shapes-and-range).
const CLOSE_RANGE_FACTOR := 0.5
const LEVEL_UP := "level-up"


## Hit points at a level: floor(2 x base x level / 100) + level + 10.
static func hit_points(base_hit_points: int, level: int) -> int:
	return (2 * base_hit_points * level) / 100 + level + 10


## Any stat other than HP at a level: floor(2 x base x level / 100) + 5.
static func other_stat(base_value: int, level: int) -> int:
	return (2 * base_value * level) / 100 + 5


## All six battle stats from a pack unit's base_stats at a level.
static func battle_stats(base_stats: Dictionary, level: int) -> Dictionary:
	var stats := {}
	for stat_key in STAT_KEYS:
		var base_value := int(base_stats[stat_key])
		stats[stat_key] = hit_points(base_value, level) if stat_key == "hp" else other_stat(base_value, level)
	return stats


## Damage multiplier of an attacking type on a defender's one or two types (0, 0.25, 0.5, 1, 2 or 4).
static func type_multiplier(pack: PackData, attacking_type: String, defending_types: Array) -> float:
	var against: Dictionary = pack.type_entry(attacking_type).get("against", {})
	var multiplier := 1.0
	for defending_type in defending_types:
		multiplier *= float(against.get(defending_type, 1.0))
	return multiplier


## The mainline damage formula with no random spread:
## floor(floor(floor(2 x level / 5 + 2) x power x attack / defense) / 50) + 2, then crit, same-type bonus and
## type multiplier in that order. A hit that is not immune does at least 1.
static func damage(
	level: int, power: int, attack: int, defense: int, is_same_type: bool, multiplier: float, is_critical_hit: bool
) -> int:
	if multiplier == 0.0 or power <= 0:
		return 0
	var amount := ((2 * level) / 5 + 2) * power * attack / maxi(defense, 1) / 50 + 2
	if is_critical_hit:
		amount = _round_half_down(amount * CRITICAL_HIT_BONUS)
	if is_same_type:
		amount = _round_half_down(amount * SAME_TYPE_BONUS)
	amount = floori(amount * multiplier)
	return maxi(amount, 1)


## Damage one unit's move does to another. Status moves, and moves with no power value, deal none here.
static func move_damage(
	pack: PackData, attacker: BattleUnit, defender: BattleUnit, move_name: String, is_critical_hit: bool
) -> int:
	var move := pack.move(move_name)
	if move.is_empty() or move["damage_class"] == "status" or move["power"] == null:
		return 0
	var is_physical: bool = move["damage_class"] == "physical"
	var attack: int = attacker.stats["attack" if is_physical else "special_attack"]
	var defense: int = defender.stats["defense" if is_physical else "special_defense"]
	var move_type: String = move["type"]
	return damage(
		attacker.level,
		int(move["power"]),
		attack,
		defense,
		move_type in attacker.types,
		type_multiplier(pack, move_type, defender.types),
		is_critical_hit
	)


## Damage from a ranged move used at range 1: CLOSE_RANGE_FACTOR of the full amount, rounded down, at least 1
## unless the full amount was 0.
static func close_range_damage(full_damage: int) -> int:
	if full_damage <= 0:
		return 0
	return maxi(floori(full_damage * CLOSE_RANGE_FACTOR), 1)


## Damage equal to the user's level (Night Shade), whatever the stats; only immunity stops it.
static func level_damage(level: int, multiplier: float) -> int:
	return 0 if multiplier == 0.0 else level


## The chance from 0 to 1 that a move hits: no accuracy value or 100 always hits, otherwise its accuracy out of 100.
static func hit_chance(move: Dictionary) -> float:
	var accuracy = move.get("accuracy")
	if accuracy == null or int(accuracy) >= ALWAYS_HITS_ACCURACY:
		return 1.0
	return float(accuracy) / ALWAYS_HITS_ACCURACY


## Whether a move hits: one roll against its hit chance, or none when it always hits.
## Reach and environment (range, line of sight, height) are checked by the battle, not here.
static func rolls_hit(move: Dictionary, random: RandomNumberGenerator) -> bool:
	if hit_chance(move) >= 1.0:
		return true
	return random.randi_range(1, ALWAYS_HITS_ACCURACY) <= int(move["accuracy"])


## Whether a hit is critical, from the crit stage (the move's critical_hit_stage, later plus other boosts).
static func rolls_critical_hit(critical_hit_stage: int, random: RandomNumberGenerator) -> bool:
	var stage := clampi(critical_hit_stage, 0, CRITICAL_HIT_ODDS_BY_STAGE.size() - 1)
	var odds: int = CRITICAL_HIT_ODDS_BY_STAGE[stage]
	return odds == 1 or random.randi_range(1, odds) == 1


## The 4 most recently learned level-up moves at or below a level (the mainline wild rule). Moves learned on
## evolution (level 0) count as learned. Learned last comes last; a move learned twice counts at its latest level.
static func moves_known_at(learnset_moves: Array, level: int) -> Array[String]:
	var latest_level_of := {}
	var first_seen_order := []
	for entry in learnset_moves:
		if entry["method"] != LEVEL_UP or int(entry["level"]) > level:
			continue
		var move_name: String = entry["move"]
		if not latest_level_of.has(move_name):
			first_seen_order.append(move_name)
		latest_level_of[move_name] = maxi(int(entry["level"]), int(latest_level_of.get(move_name, 0)))
	# sort_custom is not stable, so ties at one level keep the pack's order through an explicit tiebreak.
	var pack_order := {}
	for index in first_seen_order.size():
		pack_order[first_seen_order[index]] = index
	var ordered := first_seen_order.duplicate()
	ordered.sort_custom(func(move_a, move_b):
		if latest_level_of[move_a] != latest_level_of[move_b]:
			return latest_level_of[move_a] < latest_level_of[move_b]
		return pack_order[move_a] < pack_order[move_b])
	var known: Array[String] = []
	for move_name in ordered.slice(maxi(ordered.size() - MOVES_KNOWN, 0)):
		known.append(move_name)
	return known


static func _round_half_down(value: float) -> int:
	var whole := floori(value)
	return whole + 1 if value - whole > 0.5 else whole
