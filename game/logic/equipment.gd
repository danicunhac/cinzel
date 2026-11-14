class_name Equipment
extends RefCounted
## What the climber wears. Slots: weapon, armor, helm, backpack, up to 3
## relics and the (visual) outfit. Equipping takes the item from the backpack
## and puts the old one back in it. Ids are &"" when a slot is empty.

const RELIC_SLOTS := 3
const STARTER_WEAPON := &"sword_iron"
const STARTER_BACKPACK := &"backpack_small"
const STARTER_OUTFIT := &"outfit_starter"
## Kinds that have a slot here (outfits are set by RunState.set_outfit).
const SLOT_KINDS: Array[StringName] = [&"weapon", &"armor", &"helm", &"backpack", &"relic"]

var weapon: StringName = &""
var armor: StringName = &""
var helm: StringName = &""
var backpack: StringName = &""
var outfit: StringName = &""
var relics: Array[StringName] = []


## Common sword, 8-slot backpack, starter outfit.
static func starter() -> Equipment:
	var e := Equipment.new()
	e.weapon = STARTER_WEAPON
	e.backpack = STARTER_BACKPACK
	e.outfit = STARTER_OUTFIT
	return e


## Backpack slots given by the equipped backpack.
func capacity() -> int:
	return ItemDB.backpack_slots(backpack)


## Id in the slot of `kind` (relics: the one at `relic_slot`).
func get_slot(kind: StringName, relic_slot: int = 0) -> StringName:
	match kind:
		&"weapon":
			return weapon
		&"armor":
			return armor
		&"helm":
			return helm
		&"backpack":
			return backpack
		&"outfit":
			return outfit
		&"relic":
			return relics[relic_slot] if relic_slot >= 0 and relic_slot < relics.size() else &""
	return &""


## Every equipped item that gives stats (outfits do not).
func stat_items() -> Array[StringName]:
	var out: Array[StringName] = []
	for id: StringName in [weapon, armor, helm]:
		if id != &"":
			out.append(id)
	out.append_array(relics)
	return out


## Moves `id` from the backpack into its slot; the old item goes to the
## backpack. Relics fill a free slot, or replace `relic_slot` when all 3 are
## taken. A smaller backpack is refused when the items would not fit.
func equip(id: StringName, inv: Inventory, relic_slot: int = -1) -> bool:
	var kind := ItemDB.kind(id)
	if not SLOT_KINDS.has(kind) or inv.count(id) <= 0:
		return false
	match kind:
		&"relic":
			return _equip_relic(id, inv, relic_slot)
		&"backpack":
			return _equip_backpack(id, inv)
	inv.remove(id)
	var old := get_slot(kind)
	_set_slot(kind, id)
	if old != &"":
		inv.add(old)
	return true


## Moves the item in the slot of `kind` to the backpack. The weapon and the
## backpack cannot be taken off, only swapped. Refused when the backpack is full.
func unequip(kind: StringName, inv: Inventory, relic_slot: int = 0) -> bool:
	if kind not in [&"armor", &"helm", &"relic"]:
		return false
	var old := get_slot(kind, relic_slot)
	if old == &"" or inv.free_slots() <= 0:
		return false
	inv.add(old)
	if kind == &"relic":
		relics.remove_at(relic_slot)
	else:
		_set_slot(kind, &"")
	return true


func _equip_relic(id: StringName, inv: Inventory, relic_slot: int) -> bool:
	if relics.size() < RELIC_SLOTS and (relic_slot < 0 or relic_slot >= relics.size()):
		inv.remove(id)
		relics.append(id)
		return true
	if relic_slot < 0 or relic_slot >= relics.size():
		return false
	inv.remove(id)
	var old := relics[relic_slot]
	relics[relic_slot] = id
	inv.add(old)
	return true


func _equip_backpack(id: StringName, inv: Inventory) -> bool:
	var new_cap := ItemDB.backpack_slots(id)
	inv.remove(id)
	# After the swap the old backpack takes the slot the new one leaves.
	if inv.used() + 1 > new_cap:
		inv.add(id)
		return false
	inv.set_capacity(new_cap)
	inv.add(backpack)
	backpack = id
	return true


func _set_slot(kind: StringName, id: StringName) -> void:
	match kind:
		&"weapon":
			weapon = id
		&"armor":
			armor = id
		&"helm":
			helm = id
		&"backpack":
			backpack = id
