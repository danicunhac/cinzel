class_name FloorState
extends RefCounted
## What the tower remembers while the player stays inside it: for each floor
## visited, its room sequence (FloorPlan), chest rooms, the room the player is
## in, and per room whether it was cleared, which chests were opened and which
## items were left on the floor. The Dungeon owns one per tower visit, so
## leaving to town (or dying) starts the next visit from fresh plans.


## Saved state of one room.
class RoomSave:
	extends RefCounted
	var cleared: bool = false
	## Indices of the room's chests that were opened (a room has at most one: 0).
	var chests_opened: Array[int] = []
	## Items lying on the floor: {"id": StringName, "qty": int, "pos": Vector2}.
	var floor_items: Array[Dictionary] = []


## One floor: its plan, chest rooms, current room and room saves.
class FloorRecord:
	extends RefCounted
	var plan: Array[String] = []
	var chest_rooms: Array[int] = []
	var index: int = 0
	var rooms: Array[RoomSave] = []


var _floors: Dictionary[int, FloorRecord] = {}


func has_floor(floor_num: int) -> bool:
	return _floors.has(floor_num)


## Stores a new plan for `floor_num` (replacing any older one) with every room
## uncleared, and returns it.
func start_floor(floor_num: int, plan: Array[String], chest_rooms: Array[int]) -> FloorRecord:
	var rec := FloorRecord.new()
	rec.plan.assign(plan)
	rec.chest_rooms.assign(chest_rooms)
	for i in plan.size():
		rec.rooms.append(RoomSave.new())
	_floors[floor_num] = rec
	return rec


func get_floor(floor_num: int) -> FloorRecord:
	return _floors.get(floor_num) as FloorRecord


func room(floor_num: int, index: int) -> RoomSave:
	var rec := get_floor(floor_num)
	if rec == null or index < 0 or index >= rec.rooms.size():
		return null
	return rec.rooms[index]


func floor_count() -> int:
	return _floors.size()


func reset() -> void:
	_floors.clear()
