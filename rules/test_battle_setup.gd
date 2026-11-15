class_name TestBattleSetup
extends RefCounted
## The greybox test battle (issue #6, docs/discussion-outputs/units-on-map-plan.md): a hand-made 20 by 20 map and
## 4 units a side at level 30, starting in opposite corners and facing each other. Rules only; view/test_map.gd
## draws it and tests check it.

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
const UNIT_LEVEL := 30
const PLAYER_ROSTER := ["charmander", "squirtle", "bulbasaur", "pikachu"]
const ENEMY_ROSTER := ["vulpix", "vulpix-alola", "geodude", "gastly"]
const PLAYER_START_CELLS: Array[Vector2i] = [Vector2i(14, 17), Vector2i(16, 17), Vector2i(15, 15), Vector2i(17, 15)]
const ENEMY_START_CELLS: Array[Vector2i] = [Vector2i(2, 1), Vector2i(4, 2), Vector2i(1, 3), Vector2i(3, 4)]
const PLAYER_FACING := Facing.Direction.NORTH
const ENEMY_FACING := Facing.Direction.SOUTH


static func build(pack: PackData) -> Battle:
	var battle := Battle.new(BattleGrid.from_rows(PackedStringArray(HEIGHT_ROWS)))
	for index in PLAYER_ROSTER.size():
		battle.add_unit(
			BattleUnit.from_pack(pack, PLAYER_ROSTER[index], UNIT_LEVEL, PLAYER_START_CELLS[index], PLAYER_FACING),
			Battle.Side.PLAYER
		)
	for index in ENEMY_ROSTER.size():
		battle.add_unit(
			BattleUnit.from_pack(pack, ENEMY_ROSTER[index], UNIT_LEVEL, ENEMY_START_CELLS[index], ENEMY_FACING),
			Battle.Side.ENEMY
		)
	return battle


## The middle of a side's start zone, in grid cells (the average of its start cells).
static func start_zone_center(side: int) -> Vector2:
	var cells := PLAYER_START_CELLS if side == Battle.Side.PLAYER else ENEMY_START_CELLS
	var total := Vector2.ZERO
	for cell in cells:
		total += Vector2(cell)
	return total / cells.size()
