class_name ItemDB
extends RefCounted
## Lookups over the item catalog (game/data/item_catalog.gd). Paths are only
## returned, never loaded: icons and sprite sheets come from the art tasks.

const KINDS: Array[StringName] = [&"weapon", &"armor", &"helm", &"backpack", &"relic", &"material", &"outfit"]
const WEAPON_TYPES: Array[StringName] = [&"sword", &"longsword", &"axe", &"spear", &"dagger", &"bow"]
const RARITY_MULT: Dictionary[StringName, float] = {&"common": 1.0, &"rare": 1.5, &"epic": 2.5}
const MATERIAL_STACK := 10
const ICON_DIR := "res://assets/items/"
const WEAPON_SPRITE_DIR := "res://assets/characters/climber/weapons/"
const OUTFIT_SPRITE_DIR := "res://assets/characters/climber/outfits/"


## All ids, or only the ones of `kind`, in catalog order.
static func ids(kind: StringName = &"") -> Array[StringName]:
	var out: Array[StringName] = []
	for k: StringName in ItemCatalog.ITEMS:
		if kind == &"" or ItemCatalog.ITEMS[k]["kind"] == kind:
			out.append(k)
	return out


## Ids of `kind` and `rarity`.
static func ids_by(kind: StringName, rarity: StringName) -> Array[StringName]:
	var out: Array[StringName] = []
	for k: StringName in ids(kind):
		if ItemCatalog.ITEMS[k]["rarity"] == rarity:
			out.append(k)
	return out


## Ids of `kind` and `rarity` (&"" = any) that loot and the market can hand
## out: no "no_source" items.
static func sourced_by(kind: StringName, rarity: StringName = &"") -> Array[StringName]:
	var out: Array[StringName] = []
	for k: StringName in ids(kind):
		if has_source(k) and (rarity == &"" or ItemCatalog.ITEMS[k]["rarity"] == rarity):
			out.append(k)
	return out


## False for catalog items nothing in the game hands out yet (no loot, no
## market stock, no forge recipe): "no_source" in the catalog.
static func has_source(id: StringName) -> bool:
	return has(id) and not bool(ItemCatalog.ITEMS[id].get("no_source", false))


static func has(id: StringName) -> bool:
	return ItemCatalog.ITEMS.has(id)


## A copy of the entry, plus "icon" (see item_catalog.gd for the schema).
static func get_def(id: StringName) -> Dictionary:
	var d := (ItemCatalog.ITEMS[id] as Dictionary).duplicate(true)
	d["icon"] = icon_path(id)
	return d


static func kind(id: StringName) -> StringName:
	return ItemCatalog.ITEMS[id]["kind"] if has(id) else &""


static func rarity(id: StringName) -> StringName:
	return ItemCatalog.ITEMS[id]["rarity"] if has(id) else &""


static func item_name(id: StringName) -> String:
	return String(ItemCatalog.ITEMS[id]["name"]) if has(id) else ""


static func weapon_type(id: StringName) -> StringName:
	return ItemCatalog.ITEMS[id].get("weapon_type", &"") if has(id) else &""


## Light colour of a weapon's swings and specials when its icon is not the
## plain steel the default light fits (alpha 0 = default).
static func fx_color(id: StringName) -> Color:
	return ItemCatalog.ITEMS[id].get("fx_color", Color(0, 0, 0, 0)) if has(id) else Color(0, 0, 0, 0)


static func backpack_slots(id: StringName) -> int:
	return int(ItemCatalog.ITEMS[id].get("slots", 0)) if has(id) else 0


## Materials stack up to 10 in one backpack slot; everything else is 1.
static func stack_max(id: StringName) -> int:
	return MATERIAL_STACK if kind(id) == &"material" else 1


## Materials of a tower floor (1..3); floor 0 is the boss material.
static func materials_of_floor(floor_num: int) -> Array[StringName]:
	var out: Array[StringName] = []
	for k: StringName in ids(&"material"):
		if int(ItemCatalog.ITEMS[k]["floor"]) == floor_num:
			out.append(k)
	return out


## Base price x rarity multiplier (before the market's supply and demand).
static func price(id: StringName) -> int:
	if not has(id):
		return 0
	return roundi(int(ItemCatalog.ITEMS[id]["base_price"]) * RARITY_MULT[rarity(id)])


static func icon_path(id: StringName) -> String:
	return "%s%s.png" % [ICON_DIR, id]


## Sprite sheet shown on the character: the weapon layer for weapons, the
## `layer` (hair or outfit) for outfits, "" for anything else.
static func sprite_path(id: StringName, layer: StringName = &"outfit") -> String:
	match kind(id):
		&"weapon":
			return "%s%s.png" % [WEAPON_SPRITE_DIR, weapon_type(id)]
		&"outfit":
			return "%s%s/%s.png" % [OUTFIT_SPRITE_DIR, String(id).trim_prefix("outfit_"), layer]
	return ""
