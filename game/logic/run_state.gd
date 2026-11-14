class_name RunState
extends RefCounted
## Everything the player carries and has unlocked in this run. Death loses it
## all (equipment, backpack, gold, floors) except the unlocked outfits.

signal changed
## Loot that went into the run (take_loot): `qty` units of `id` (HUD toasts).
signal looted(id: StringName, qty: int)

## Relic slots (the HUD row and the swap panel).
const SLOTS := Equipment.RELIC_SLOTS
const MAX_FLOOR := 3

var gold: int = 0
var equipment: Equipment = Equipment.starter()
var inventory: Inventory = Inventory.new(equipment.capacity())
## Outfits the player can wear. Visual only, so they survive death.
var unlocked_outfits: Array[StringName] = [Equipment.STARTER_OUTFIT]
## The town market keeps its prices between visits; death starts a fresh one.
var market: Market = Market.new()
var unlocked_floors: int = 1
## Bosses beaten in this run (unlocks forge recipes).
var floors_beaten: int = 0
var hp: int = PlayerStats.new().max_hp
var clock: RunClock = RunClock.new()
## Floor 1 opens with the 3 tutorial rooms until they are finished in this run.
var tutorial_done: bool = false
## The equipped relics (old name kept for the HUD and the swap panel).
## Read-only: change relics with add_item/replace_item/remove_item or equip.
var items: Array[StringName]:
	get:
		return equipment.relics
	set(_value):
		push_error("RunState.items is read-only: use add_item, replace_item, remove_item or equip")


func can_take_item() -> bool:
	return equipment.relics.size() < SLOTS


## Puts a relic straight into a free relic slot.
func add_item(id: StringName) -> bool:
	if ItemDB.kind(id) != &"relic":
		push_error("RunState.add_item: not a relic '%s'" % id)
		return false
	if not can_take_item():
		return false
	equipment.relics.append(id)
	changed.emit()
	return true


## Replaces the relic at `slot` (not through the backpack). Returns the old one.
func replace_item(slot: int, id: StringName) -> StringName:
	if ItemDB.kind(id) != &"relic":
		push_error("RunState.replace_item: not a relic '%s'" % id)
		return &""
	if slot < 0 or slot >= equipment.relics.size():
		return &""
	var old: StringName = equipment.relics[slot]
	equipment.relics[slot] = id
	clamp_hp()
	changed.emit()
	return old


## Drops the relic at `slot` (not to the backpack). Returns it.
func remove_item(slot: int) -> StringName:
	if slot < 0 or slot >= equipment.relics.size():
		return &""
	var old: StringName = equipment.relics[slot]
	equipment.relics.remove_at(slot)
	clamp_hp()
	changed.emit()
	return old


## Loot picked up in the tower or bought. Outfits unlock. A relic, armor or
## helm goes straight into its slot when that slot is free; everything else
## goes to the backpack. Returns how many did not fit.
func take_loot(id: StringName, qty: int = 1) -> int:
	if not ItemDB.has(id):
		push_error("RunState.take_loot: unknown item '%s'" % id)
		return qty
	var kind := ItemDB.kind(id)
	if kind == &"outfit":
		unlock_outfit(id)
		looted.emit(id, 1)
		return 0
	var left := qty
	while left > 0 and _slot_free_for(kind):
		match kind:
			&"relic":
				equipment.relics.append(id)
			&"armor":
				equipment.armor = id
			&"helm":
				equipment.helm = id
		left -= 1
	left = inventory.add(id, left)
	clamp_hp()
	changed.emit()
	if left < qty:
		looted.emit(id, qty - left)
	return left


func equip(id: StringName, relic_slot: int = -1) -> bool:
	var ok := equipment.equip(id, inventory, relic_slot)
	if ok:
		clamp_hp()
		changed.emit()
	return ok


func unequip(kind: StringName, relic_slot: int = 0) -> bool:
	var ok := equipment.unequip(kind, inventory, relic_slot)
	if ok:
		clamp_hp()
		changed.emit()
	return ok


## Gear that lowers max hp (armor off, a lighter one on) cuts hp down to it.
func clamp_hp() -> void:
	hp = mini(hp, stats().max_hp)


func unlock_outfit(id: StringName) -> void:
	if ItemDB.kind(id) == &"outfit" and not unlocked_outfits.has(id):
		unlocked_outfits.append(id)
		changed.emit()


func set_outfit(id: StringName) -> bool:
	if not unlocked_outfits.has(id):
		return false
	equipment.outfit = id
	changed.emit()
	return true


## Wardrobe toggle: armor and helm over the outfit, or the outfit alone.
func set_show_armor(on: bool) -> void:
	if equipment.show_armor == on:
		return
	equipment.show_armor = on
	changed.emit()


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


## The boss of `floor_num` died: next floor opens, forge recipes unlock.
func beat_floor(floor_num: int) -> void:
	floors_beaten = maxi(floors_beaten, floor_num)
	unlock_floor(floor_num + 1)


## Loses everything and goes back to the starter kit; the market starts fresh.
## Unlocked outfits (and the one being worn) stay, and so does the
## "Mostrar armadura" choice.
func die() -> void:
	var outfit := equipment.outfit
	var show_armor := equipment.show_armor
	gold = 0
	market = Market.new()
	equipment = Equipment.starter()
	equipment.outfit = outfit
	equipment.show_armor = show_armor
	inventory = Inventory.new(equipment.capacity())
	unlocked_floors = 1
	floors_beaten = 0
	clock.reset()
	tutorial_done = false
	hp = stats().max_hp
	changed.emit()


func stats() -> PlayerStats:
	return PlayerStats.from_equipment(equipment)


func _slot_free_for(kind: StringName) -> bool:
	match kind:
		&"relic":
			return equipment.relics.size() < SLOTS
		&"armor":
			return equipment.armor == &""
		&"helm":
			return equipment.helm == &""
	return false
