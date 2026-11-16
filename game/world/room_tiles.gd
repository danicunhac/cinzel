class_name RoomTiles
extends RefCounted
## Atlas coordinates shared by every floor tileset (floor1.png, later floor2/3).
## Same layout as TILES in art-src/make_placeholders.py.

const SOURCE := 0
const SIZE := 16

const FLOOR_A := Vector2i(0, 0)
const FLOOR_B := Vector2i(1, 0)
const FLOOR_CRACK := Vector2i(2, 0)
const FLOOR_MOSS := Vector2i(3, 0)
const WALL_FACE := Vector2i(4, 0)
const WALL_TOP := Vector2i(5, 0)
const PILLAR := Vector2i(6, 0)
const CRATE := Vector2i(7, 0)
const DOOR_LOCKED := Vector2i(0, 1)
const DOOR_OPEN := Vector2i(1, 1)
const DOOR_SHUT := Vector2i(2, 1)
const CHEST_CLOSED := Vector2i(3, 1)
const CHEST_OPEN := Vector2i(4, 1)
const WALL_TORCH := Vector2i(5, 1)

const ALL: Array[Vector2i] = [
	FLOOR_A, FLOOR_B, FLOOR_CRACK, FLOOR_MOSS, WALL_FACE, WALL_TOP, PILLAR, CRATE,
	DOOR_LOCKED, DOOR_OPEN, DOOR_SHUT, CHEST_CLOSED, CHEST_OPEN, WALL_TORCH,
]
const SOLID: Array[Vector2i] = [WALL_FACE, WALL_TOP, WALL_TORCH, PILLAR, CRATE, DOOR_LOCKED, DOOR_SHUT]


static func region(coords: Vector2i) -> Rect2:
	return Rect2(coords * SIZE, Vector2(SIZE, SIZE))
