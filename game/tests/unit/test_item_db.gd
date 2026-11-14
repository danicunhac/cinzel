extends RefCounted
## Catalog contents (GDD content B) and lookups.


func test_content_counts() -> void:
	T.eq(ItemDB.ids(&"weapon").size(), 12, "weapons")
	T.eq(ItemDB.ids(&"armor").size(), 6, "armors")
	T.eq(ItemDB.ids(&"helm").size(), 4, "helms")
	T.eq(ItemDB.ids(&"backpack").size(), 3, "backpacks")
	T.eq(ItemDB.ids(&"relic").size(), 8, "relics")
	T.eq(ItemDB.ids(&"outfit").size(), 5, "outfits")
	T.eq(ItemDB.ids(&"material").size(), 10, "materials")


func test_two_weapons_per_type() -> void:
	var per_type: Dictionary[StringName, int] = {}
	for id: StringName in ItemDB.ids(&"weapon"):
		var t := ItemDB.weapon_type(id)
		per_type[t] = per_type.get(t, 0) + 1
	for t: StringName in ItemDB.WEAPON_TYPES:
		T.eq(per_type.get(t, 0), 2, "type %s" % t)


func test_backpack_sizes() -> void:
	T.eq(ItemDB.backpack_slots(&"backpack_small"), 8)
	T.eq(ItemDB.backpack_slots(&"backpack_medium"), 14)
	T.eq(ItemDB.backpack_slots(&"backpack_large"), 20)


func test_every_item_has_schema() -> void:
	for id: StringName in ItemDB.ids():
		var d := ItemDB.get_def(id)
		T.ok(ItemDB.KINDS.has(d["kind"]), "%s kind" % id)
		T.ok(ItemDB.RARITY_MULT.has(d["rarity"]), "%s rarity" % id)
		T.ok(String(d["name"]) != "" and String(d["desc"]) != "", "%s text" % id)
		T.ok(int(d["base_price"]) >= 0, "%s price" % id)
		T.eq(d["icon"], "res://assets/items/%s.png" % id)


func test_materials_by_floor() -> void:
	for f in [1, 2, 3]:
		T.eq(ItemDB.materials_of_floor(f).size(), 3, "floor %d" % f)
	T.eq(ItemDB.materials_of_floor(0), [&"mat_tower_crystal"] as Array[StringName], "boss material")


func test_stack_sizes() -> void:
	T.eq(ItemDB.stack_max(&"mat_slime_gel"), 10)
	T.eq(ItemDB.stack_max(&"sword_iron"), 1)
	T.eq(ItemDB.stack_max(&"fang"), 1)


func test_price_uses_rarity() -> void:
	var d := ItemDB.get_def(&"sword_knight")
	T.eq(ItemDB.price(&"sword_knight"), roundi(int(d["base_price"]) * ItemDB.RARITY_MULT[&"rare"]))


func test_sprite_paths() -> void:
	T.eq(ItemDB.sprite_path(&"axe_war"), "res://assets/characters/climber/weapons/axe.png")
	T.eq(ItemDB.sprite_path(&"outfit_manto_mago", &"hair"), "res://assets/characters/climber/outfits/manto_mago/hair.png")
	T.eq(ItemDB.sprite_path(&"outfit_starter"), "res://assets/characters/climber/outfits/starter/outfit.png")
	T.eq(ItemDB.sprite_path(&"fang"), "")
