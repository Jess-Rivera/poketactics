class_name TestBattleSetup
extends RefCounted
## The greybox test battle (issue #6, docs/discussion-outputs/units-on-map-plan.md): a hand-made 20 by 20 map, 6
## player units against a wild, trainer or boss enemy count (#16, six-a-side-opening.md), all at level 30, starting
## in opposite corners and facing each other. Rules only; view/test_map.gd draws it and tests check it.

## One digit per cell, the height level (grid x grows east along a row, grid y grows south down the rows).
## Enemy start zone: a raised corner in the north-west. Player start zone: flat ground in the south-east.
## Between them: a central hill up to level 4, a ridge in the north-east and a sunken valley in the south-west.
const HEIGHT_ROWS := [
	"11111110000000000000",
	"11111110000000122000",
	"11111110000001233200",
	"11111100000012332100",
	"11111100000123321000",
	"11111000000233210000",
	"11110000001232100000",
	"00000000012221000000",
	"00000001122110000000",
	"00000012233210000000",
	"00000123344321000000",
	"00000123444321000000",
	"11111012343210000000",
	"10001101232100000000",
	"10000100121000000000",
	"10000100010000000000",
	"10000100000000000000",
	"11111100000000000000",
	"00000000000000000000",
	"00000000000000000000",
]
## Encounter kinds (2026-11-16-party-and-battles): the player always fields 6; the enemy count depends on the node.
enum EncounterKind { WILD, TRAINER, BOSS }

const UNIT_LEVEL := 30
## Kanto units for the first build (2026-11-16-first-build-scope), agreed for #16.
const PLAYER_ROSTER := ["charmander", "squirtle", "bulbasaur", "pikachu", "eevee", "machop"]
const ENEMY_POOL := ["vulpix", "vulpix-alola", "geodude", "gastly", "oddish", "mankey"]
## Smallest and largest enemy count per encounter kind ([Proposed] counts in 2026-11-16-party-and-battles).
const ENEMY_COUNT_RANGES := {
	EncounterKind.WILD: Vector2i(2, 4),
	EncounterKind.TRAINER: Vector2i(3, 6),
	EncounterKind.BOSS: Vector2i(6, 6),
}
const ENCOUNTER_NAMES := {EncounterKind.WILD: "Wild", EncounterKind.TRAINER: "Trainer", EncounterKind.BOSS: "Boss"}
const PLAYER_START_CELLS: Array[Vector2i] = [
	Vector2i(14, 17), Vector2i(16, 17), Vector2i(15, 15), Vector2i(17, 15), Vector2i(18, 17), Vector2i(16, 13),
]
const ENEMY_START_CELLS: Array[Vector2i] = [
	Vector2i(2, 1), Vector2i(4, 2), Vector2i(1, 3), Vector2i(3, 4), Vector2i(5, 1), Vector2i(1, 5),
]
const PLAYER_FACING := Facing.Direction.NORTH
const ENEMY_FACING := Facing.Direction.SOUTH

## Who plays the battle (#15, ruling 2026-11-17-hotseat-m1b): the player against TurnAi, or two players on one
## machine (player 1 on the player side, player 2 on the enemy side).
enum PlayMode { AI_BATTLE, HOTSEAT }

## The sides TurnAi plays in each mode.
const AI_SIDES_BY_MODE := {
	PlayMode.AI_BATTLE: [Battle.Side.ENEMY],
	PlayMode.HOTSEAT: [],
}
## A hotseat team: this many units from HOTSEAT_POOL, no species twice.
const TEAM_SIZE := 6
## The units hotseat players pick from: every unit whose level-up moves at UNIT_LEVEL have grid behaviour (#26
## widens it).
const HOTSEAT_POOL := PLAYER_ROSTER + ENEMY_POOL


## The test battle for an encounter kind. The seed picks the enemy count inside the kind's range and which units
## of the pool appear, so the same seed always gives the same battle. The default is a full 6 against 6.
static func build(pack: PackData, encounter_kind := EncounterKind.BOSS, battle_seed := 0) -> Battle:
	var player_team: Array[String] = []
	player_team.assign(PLAYER_ROSTER)
	return build_from_teams(pack, player_team, enemy_roster(encounter_kind, battle_seed))


## The test map with the first team on the player side and the second on the enemy side, at UNIT_LEVEL, in
## start-cell order.
static func build_from_teams(pack: PackData, player_team: Array[String], enemy_team: Array[String]) -> Battle:
	var battle := Battle.new(BattleGrid.from_rows(PackedStringArray(HEIGHT_ROWS)))
	for index in player_team.size():
		battle.add_unit(
			BattleUnit.from_pack(pack, player_team[index], UNIT_LEVEL, PLAYER_START_CELLS[index], PLAYER_FACING),
			Battle.Side.PLAYER
		)
	for index in enemy_team.size():
		battle.add_unit(
			BattleUnit.from_pack(pack, enemy_team[index], UNIT_LEVEL, ENEMY_START_CELLS[index], ENEMY_FACING),
			Battle.Side.ENEMY
		)
	return battle


## Whether a unit may join a hotseat team: it is in the pool, the team is not full, and no unit of its species is
## on the team yet (Vulpix and Alolan Vulpix are one species).
static func can_join_team(pack: PackData, team: Array[String], unit_name: String) -> bool:
	if not HOTSEAT_POOL.has(unit_name) or team.size() >= TEAM_SIZE:
		return false
	var species: String = pack.unit(unit_name)["species"]
	for member in team:
		if pack.unit(member)["species"] == species:
			return false
	return true


## Whether a team is ready for battle: exactly TEAM_SIZE units, each allowed to join the ones before it.
static func is_valid_team(pack: PackData, team: Array[String]) -> bool:
	if team.size() != TEAM_SIZE:
		return false
	var built: Array[String] = []
	for unit_name in team:
		if not can_join_team(pack, built, unit_name):
			return false
		built.append(unit_name)
	return true


## Which pool units the enemy fields for an encounter kind and seed, in start-cell order.
static func enemy_roster(encounter_kind: EncounterKind, battle_seed: int) -> Array[String]:
	var random := RandomNumberGenerator.new()
	random.seed = battle_seed
	var count_range: Vector2i = ENEMY_COUNT_RANGES[encounter_kind]
	var enemy_count := random.randi_range(count_range.x, count_range.y)
	var remaining: Array[String] = []
	remaining.assign(ENEMY_POOL)
	var chosen: Array[String] = []
	for _pick in enemy_count:
		chosen.append(remaining.pop_at(random.randi_range(0, remaining.size() - 1)))
	return chosen


## The middle of a side's start zone, in grid cells (the average of its start cells).
static func start_zone_center(side: int) -> Vector2:
	var cells := PLAYER_START_CELLS if side == Battle.Side.PLAYER else ENEMY_START_CELLS
	var total := Vector2.ZERO
	for cell in cells:
		total += Vector2(cell)
	return total / cells.size()
