extends RefCounted


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _count_epics(floor_num: int, level: int) -> int:
	var rng := _rng(42)
	var n := 0
	for i in 600:
		if LootTable.roll_rarity(floor_num, level, rng) == &"epic":
			n += 1
	return n


func test_same_seed_same_loot() -> void:
	var a := _rng(9)
	var b := _rng(9)
	for i in 30:
		T.eq(LootTable.roll_chest(2, 3, a), LootTable.roll_chest(2, 3, b))
		T.eq(_flat(LootTable.roll_enemy(&"crawler", 1, a)), _flat(LootTable.roll_enemy(&"crawler", 1, b)))
		T.eq(_flat(LootTable.roll_boss(3, 1, a)), _flat(LootTable.roll_boss(3, 1, b)))


func _flat(drops: Array[LootDrop]) -> Array[String]:
	var out: Array[String] = []
	for d in drops:
		out.append("%s:%d" % [d.id, d.qty])
	return out


func test_rarity_weights_shift_with_floor_and_clock() -> void:
	var w1 := LootTable.rarity_weights(1, 0)
	var w3 := LootTable.rarity_weights(3, 0)
	var w1late := LootTable.rarity_weights(1, 6)
	T.ok(w3[&"epic"] > w1[&"epic"], "deeper floor: more epic weight")
	T.ok(w3[&"common"] < w1[&"common"], "deeper floor: less common weight")
	T.ok(w1late[&"epic"] > w1[&"epic"], "later clock: more epic weight")
	T.ok(w1[&"common"] > w1[&"rare"] and w1[&"rare"] > w1[&"epic"], "floor 1 mostly common")


func test_rarity_rolls_follow_weights() -> void:
	var early := _count_epics(1, 0)
	var deep := _count_epics(3, 8)
	T.ok(early < 60, "floor 1 epics are rare (%d/600)" % early)
	T.ok(deep > early * 2, "floor 3 late has many more epics (%d vs %d)" % [deep, early])


func test_chest_gives_equipment_or_relic() -> void:
	var rng := _rng(3)
	var kinds: Array[StringName] = [&"weapon", &"armor", &"helm", &"relic", &"backpack", &"outfit"]
	for i in 100:
		var id := LootTable.roll_chest(2, 2, rng)
		T.ok(ItemDB.has(id), "valid id %s" % id)
		T.ok(kinds.has(ItemDB.kind(id)), "chest kind %s" % ItemDB.kind(id))


func test_chest_skips_excluded_outfits() -> void:
	var rng := _rng(5)
	var all_outfits := ItemDB.ids(&"outfit")
	for i in 300:
		var id := LootTable.roll_chest(3, 5, rng, all_outfits)
		T.ok(ItemDB.kind(id) != &"outfit", "no outfit when all are owned")


func test_enemy_materials_by_floor_and_type() -> void:
	var rng := _rng(1)
	var seen: Dictionary[StringName, bool] = {}
	for i in 200:
		for drop: LootDrop in LootTable.roll_enemy(&"shooter", 2, rng):
			seen[drop.id] = true
	var table: Array = LootTable.ENEMY_MATERIALS[2][&"shooter"]
	for id: StringName in seen:
		T.ok(table.has(id), "%s is in the shooter's floor 2 table" % id)
	T.eq(seen.size(), table.size(), "every listed material drops")
	T.ok(LootTable.roll_enemy(&"ghost", 1, rng).is_empty(), "unknown enemy drops nothing")


func test_enemy_tables_use_real_materials() -> void:
	for f: int in LootTable.ENEMY_MATERIALS:
		var has_floor_material := false
		for type: StringName in LootTable.ENEMY_MATERIALS[f]:
			for id: StringName in LootTable.ENEMY_MATERIALS[f][type]:
				T.eq(ItemDB.kind(id), &"material", "%s on floor %d" % [id, f])
				if ItemDB.materials_of_floor(f).has(id):
					has_floor_material = true
		T.ok(has_floor_material, "floor %d drops its own materials" % f)


func test_every_recipe_material_drops_somewhere() -> void:
	var dropped: Dictionary[StringName, bool] = {LootTable.BOSS_CRYSTAL: true}
	for f: int in LootTable.ENEMY_MATERIALS:
		for type: StringName in LootTable.ENEMY_MATERIALS[f]:
			for id: StringName in LootTable.ENEMY_MATERIALS[f][type]:
				dropped[id] = true
	for r: StringName in Forge.RECIPES:
		for m: StringName in Forge.RECIPES[r]["materials"]:
			T.ok(dropped.has(m), "%s (%s) drops from an enemy" % [m, r])


func test_start_recipes_use_floor_one_materials() -> void:
	for r: StringName in Forge.unlocked(0):
		for m: StringName in Forge.RECIPES[r]["materials"]:
			T.eq(ItemDB.materials_of_floor(1).has(m), true, "%s needs %s" % [r, m])


func test_enemy_drop_chance() -> void:
	var rng := _rng(11)
	var drops := 0
	for i in 400:
		drops += LootTable.roll_enemy(&"crawler", 1, rng).size()
	T.ok(drops > 120 and drops < 280, "about half drop (%d/400)" % drops)


func test_boss_drop_has_gear_and_materials() -> void:
	var rng := _rng(2)
	var drops := LootTable.roll_boss(1, 0, rng)
	var gear := 0
	var mats := 0
	for d: LootDrop in drops:
		var k := ItemDB.kind(d.id)
		if k == &"material":
			mats += d.qty
		else:
			gear += 1
			if k != &"outfit":
				T.ok(ItemDB.rarity(d.id) != &"common", "boss gear is at least rare")
	T.ok(gear >= 1, "boss gives gear")
	T.ok(mats >= LootTable.BOSS_MATERIALS, "boss gives materials")


func test_floor_three_boss_always_gives_crystal() -> void:
	var rng := _rng(8)
	for i in 20:
		var has := false
		for d: LootDrop in LootTable.roll_boss(3, 0, rng):
			if d.id == &"mat_tower_crystal":
				has = true
		T.ok(has, "crystal on floor 3 boss")



func _outfits_in(drops: Array[LootDrop]) -> Array[StringName]:
	var out: Array[StringName] = []
	for d: LootDrop in drops:
		if ItemDB.kind(d.id) == &"outfit":
			out.append(d.id)
	return out


func test_each_boss_gives_its_outfit_once() -> void:
	var want: Dictionary[int, StringName] = {
		1: &"outfit_cavaleiro_leve", 2: &"outfit_sobretudo_noite", 3: &"outfit_traje_sombra",
	}
	for floor_num: int in want:
		var id := want[floor_num]
		T.eq(ItemCatalog.ITEMS[id]["unlock"], &"boss", String(id))
		T.eq(_outfits_in(LootTable.roll_boss(floor_num, 0, _rng(3))), [id] as Array[StringName],
				"first kill of floor %d" % floor_num)
		var owned: Array[StringName] = [id]
		T.eq(_outfits_in(LootTable.roll_boss(floor_num, 0, _rng(3), owned)).size(), 0,
				"not again once unlocked (floor %d)" % floor_num)
	T.eq(ItemDB.rarity(&"outfit_sobretudo_noite"), &"epic")
	T.eq(ItemDB.rarity(&"outfit_traje_sombra"), &"epic")


func test_boss_outfit_pickup_unlocks_with_a_toast() -> void:
	var run := RunState.new()
	var toasts: Array[StringName] = []
	run.looted.connect(func(id: StringName, _qty: int) -> void: toasts.append(id))
	for d: LootDrop in LootTable.roll_boss(2, 0, _rng(5), run.unlocked_outfits):
		run.take_loot(d.id, d.qty)
	T.ok(run.unlocked_outfits.has(&"outfit_sobretudo_noite"), "floor 2 boss unlocks the greatcoat")
	T.ok(toasts.has(&"outfit_sobretudo_noite"), "loot toast for the outfit")
	for d: LootDrop in LootTable.roll_boss(3, 0, _rng(6), run.unlocked_outfits):
		run.take_loot(d.id, d.qty)
	T.ok(run.unlocked_outfits.has(&"outfit_traje_sombra"), "floor 3 boss unlocks the swordsman suit")
