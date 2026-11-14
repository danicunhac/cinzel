extends RefCounted


func test_starter_kit() -> void:
	var eq := Equipment.starter()
	T.eq(eq.weapon, &"sword_iron")
	T.eq(eq.backpack, &"backpack_small")
	T.eq(eq.outfit, &"outfit_starter")
	T.eq(eq.armor, &"")
	T.eq(eq.helm, &"")
	T.ok(eq.relics.is_empty(), "no relics")
	T.eq(eq.capacity(), 8)


func test_equip_weapon_swaps_through_backpack() -> void:
	var eq := Equipment.starter()
	var inv := Inventory.new(8)
	inv.add(&"axe_war")
	T.eq(eq.equip(&"axe_war", inv), true)
	T.eq(eq.weapon, &"axe_war")
	T.eq(inv.count(&"axe_war"), 0)
	T.eq(inv.count(&"sword_iron"), 1, "old weapon in the backpack")


func test_equip_needs_item_in_backpack() -> void:
	var eq := Equipment.starter()
	var inv := Inventory.new(8)
	T.eq(eq.equip(&"axe_war", inv), false)
	T.eq(eq.weapon, &"sword_iron")


func test_equip_wrong_kind_refused() -> void:
	var eq := Equipment.starter()
	var inv := Inventory.new(8)
	inv.add(&"mat_slime_gel")
	T.eq(eq.equip(&"mat_slime_gel", inv), false)
	T.eq(inv.count(&"mat_slime_gel"), 1)


func test_unequip_armor_to_backpack() -> void:
	var eq := Equipment.starter()
	var inv := Inventory.new(8)
	inv.add(&"armor_chain")
	eq.equip(&"armor_chain", inv)
	T.eq(eq.armor, &"armor_chain")
	T.eq(inv.used(), 0)
	T.eq(eq.unequip(&"armor", inv), true)
	T.eq(eq.armor, &"")
	T.eq(inv.count(&"armor_chain"), 1)


func test_unequip_refused_when_backpack_full() -> void:
	var eq := Equipment.starter()
	var inv := Inventory.new(8)
	inv.add(&"helm_iron")
	eq.equip(&"helm_iron", inv)
	inv.add(&"fang", 8)
	T.eq(inv.is_full(), true)
	T.eq(eq.unequip(&"helm", inv), false)
	T.eq(eq.helm, &"helm_iron")


func test_weapon_and_backpack_cannot_be_unequipped() -> void:
	var eq := Equipment.starter()
	var inv := Inventory.new(8)
	T.eq(eq.unequip(&"weapon", inv), false)
	T.eq(eq.unequip(&"backpack", inv), false)


func test_bigger_backpack_grows_inventory() -> void:
	var eq := Equipment.starter()
	var inv := Inventory.new(8)
	inv.add(&"backpack_medium")
	T.eq(eq.equip(&"backpack_medium", inv), true)
	T.eq(eq.backpack, &"backpack_medium")
	T.eq(inv.capacity, 14)
	T.eq(inv.count(&"backpack_small"), 1, "old backpack carried")


func test_smaller_backpack_refused_when_it_would_not_fit() -> void:
	var eq := Equipment.starter()
	var inv := Inventory.new(8)
	inv.add(&"backpack_medium")
	eq.equip(&"backpack_medium", inv)
	# 14 slots: small pack + 8 relics = 9 used. Swapping leaves 9 (medium in, small out).
	inv.add(&"fang", 8)
	T.eq(eq.equip(&"backpack_small", inv), false, "9 items do not fit in 8")
	T.eq(eq.backpack, &"backpack_medium")
	T.eq(inv.capacity, 14)
	T.eq(inv.count(&"backpack_small"), 1)
	inv.remove(&"fang", 1)
	T.eq(eq.equip(&"backpack_small", inv), true, "8 items (incl. the medium pack) fit")
	T.eq(inv.capacity, 8)
	T.eq(inv.count(&"backpack_medium"), 1)
	T.eq(inv.count(&"fang"), 7)


func test_relics_fill_then_swap() -> void:
	var eq := Equipment.starter()
	var inv := Inventory.new(8)
	for id: StringName in [&"fang", &"spark", &"wind_cape", &"glass_shield"]:
		inv.add(id)
	T.eq(eq.equip(&"fang", inv), true)
	T.eq(eq.equip(&"spark", inv), true)
	T.eq(eq.equip(&"wind_cape", inv), true)
	T.eq(eq.relics.size(), Equipment.RELIC_SLOTS)
	T.eq(eq.equip(&"glass_shield", inv), false, "full: needs a slot")
	T.eq(eq.equip(&"glass_shield", inv, 1), true)
	T.eq(eq.relics[1], &"glass_shield")
	T.eq(inv.count(&"spark"), 1, "swapped relic in backpack")
	T.eq(eq.unequip(&"relic", inv, 0), true)
	T.eq(eq.relics.size(), 2)
	T.eq(inv.count(&"fang"), 1)
