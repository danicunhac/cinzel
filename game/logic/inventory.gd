class_name Inventory
extends RefCounted
## The backpack: a grid of `capacity` slots. Each slot is empty ({}) or
## {"id": StringName, "qty": int}. Materials stack up to 10, the rest is 1 per
## slot (ItemDB.stack_max).

var capacity: int = 8
var slots: Array[Dictionary] = []


func _init(cap: int = 8) -> void:
	capacity = cap
	clear()


func clear() -> void:
	slots.clear()
	slots.resize(capacity)
	for i in capacity:
		slots[i] = {}


## Adds up to `qty`, filling stacks first, then empty slots. Returns what did
## not fit (0 when everything went in).
func add(id: StringName, qty: int = 1) -> int:
	if not ItemDB.has(id):
		push_error("Inventory.add: unknown item '%s'" % id)
		return qty
	var left := qty
	var stack := ItemDB.stack_max(id)
	for s: Dictionary in slots:
		if left <= 0:
			break
		if not s.is_empty() and s["id"] == id and int(s["qty"]) < stack:
			var put := mini(stack - int(s["qty"]), left)
			s["qty"] = int(s["qty"]) + put
			left -= put
	for i in slots.size():
		if left <= 0:
			break
		if slots[i].is_empty():
			var put := mini(stack, left)
			slots[i] = {"id": id, "qty": put}
			left -= put
	return left


## Removes `qty` units of `id` (from the last slots first). All or nothing.
func remove(id: StringName, qty: int = 1) -> bool:
	if count(id) < qty:
		return false
	var left := qty
	for i in range(slots.size() - 1, -1, -1):
		if left <= 0:
			break
		var s := slots[i]
		if s.is_empty() or s["id"] != id:
			continue
		var take := mini(int(s["qty"]), left)
		s["qty"] = int(s["qty"]) - take
		left -= take
		if int(s["qty"]) <= 0:
			slots[i] = {}
	return true


## Takes one unit from `slot`. Returns its id, or &"" when the slot is empty.
func remove_at(slot: int) -> StringName:
	if slot < 0 or slot >= slots.size() or slots[slot].is_empty():
		return &""
	var s := slots[slot]
	var id: StringName = s["id"]
	s["qty"] = int(s["qty"]) - 1
	if int(s["qty"]) <= 0:
		slots[slot] = {}
	return id


func id_at(slot: int) -> StringName:
	if slot < 0 or slot >= slots.size() or slots[slot].is_empty():
		return &""
	return slots[slot]["id"]


func qty_at(slot: int) -> int:
	if slot < 0 or slot >= slots.size() or slots[slot].is_empty():
		return 0
	return int(slots[slot]["qty"])


func count(id: StringName) -> int:
	var n := 0
	for s: Dictionary in slots:
		if not s.is_empty() and s["id"] == id:
			n += int(s["qty"])
	return n


func used() -> int:
	var n := 0
	for s: Dictionary in slots:
		if not s.is_empty():
			n += 1
	return n


func free_slots() -> int:
	return capacity - used()


func is_full() -> bool:
	return used() >= capacity


func is_empty() -> bool:
	return used() == 0


## New size (backpack swap). Refused when the used slots would not fit; the
## kept items are packed at the start of the grid.
func set_capacity(n: int) -> bool:
	if used() > n:
		return false
	var kept: Array[Dictionary] = []
	for s: Dictionary in slots:
		if not s.is_empty():
			kept.append(s)
	capacity = n
	clear()
	for i in kept.size():
		slots[i] = kept[i]
	return true
