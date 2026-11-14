class_name RunState
extends RefCounted

signal changed

const SLOTS := 3
const MAX_FLOOR := 3

var gold: int = 0
var items: Array[StringName] = []
var unlocked_floors: int = 1
var hp: int = PlayerStats.new().max_hp
var clock: RunClock = RunClock.new()


func can_take_item() -> bool:
	return items.size() < SLOTS


func add_item(id: StringName) -> bool:
	if not ItemDB.has(id):
		push_error("RunState.add_item: unknown item '%s'" % id)
		return false
	if not can_take_item():
		return false
	items.append(id)
	changed.emit()
	return true


func replace_item(slot: int, id: StringName) -> StringName:
	if not ItemDB.has(id):
		push_error("RunState.replace_item: unknown item '%s'" % id)
		return &""
	if slot < 0 or slot >= items.size():
		return &""
	var old: StringName = items[slot]
	items[slot] = id
	changed.emit()
	return old


func remove_item(slot: int) -> StringName:
	if slot < 0 or slot >= items.size():
		return &""
	var old: StringName = items[slot]
	items.remove_at(slot)
	changed.emit()
	return old


func add_gold(n: int) -> void:
	gold += n
	changed.emit()


func spend_gold(n: int) -> bool:
	if n > gold:
		return false
	gold -= n
	changed.emit()
	return true


func unlock_floor(n: int) -> void:
	unlocked_floors = maxi(unlocked_floors, mini(n, MAX_FLOOR))
	changed.emit()


func die() -> void:
	gold = 0
	items.clear()
	unlocked_floors = 1
	clock.reset()
	hp = stats().max_hp
	changed.emit()


func stats() -> PlayerStats:
	return PlayerStats.from_items(items)
