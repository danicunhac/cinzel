extends RefCounted


func _fill(run: RunState, recipe_id: StringName) -> void:
	var r: Dictionary = Forge.RECIPES[recipe_id]
	var mats: Dictionary = r["materials"]
	for m: StringName in mats:
		run.inventory.add(m, int(mats[m]))
	run.gold += int(r["gold"])


func test_recipes_point_to_real_items() -> void:
	for id: StringName in Forge.RECIPES:
		var r: Dictionary = Forge.RECIPES[id]
		T.ok(ItemDB.has(r["result"]), "%s result" % id)
		var mats: Dictionary = r["materials"]
		for m: StringName in mats:
			T.eq(ItemDB.kind(m), &"material", "%s uses materials" % id)


func test_recipes_unlock_by_floors_beaten() -> void:
	var at0 := Forge.unlocked(0)
	var at1 := Forge.unlocked(1)
	var at2 := Forge.unlocked(2)
	T.ok(at0.size() > 0, "some recipes from the start")
	T.ok(at1.size() > at0.size(), "beating floor 1 unlocks more")
	T.ok(at2.size() > at1.size(), "beating floor 2 unlocks more")
	T.eq(Forge.unlocked(3).size(), Forge.RECIPES.size())
	T.ok(not at0.has(&"armor_shadow"), "late recipe locked at start")


func test_craft_consumes_materials_and_gold() -> void:
	var run := RunState.new()
	_fill(run, &"armor_leather")
	run.gold += 7
	T.eq(Forge.can_craft(run, &"armor_leather"), true)
	T.eq(Forge.craft(run, &"armor_leather"), true)
	T.eq(run.gold, 7)
	T.eq(run.inventory.count(&"mat_slime_gel"), 0)
	T.eq(run.inventory.count(&"mat_slime_core"), 0)
	T.eq(run.inventory.count(&"armor_leather"), 1)


func test_craft_locked_recipe_refused() -> void:
	var run := RunState.new()
	_fill(run, &"armor_shadow")
	T.eq(Forge.craft(run, &"armor_shadow"), false)
	run.beat_floor(1)
	run.beat_floor(2)
	T.eq(Forge.craft(run, &"armor_shadow"), true)


func test_craft_missing_material_or_gold_refused() -> void:
	var run := RunState.new()
	_fill(run, &"spear_hunter")
	run.gold -= 1
	T.eq(Forge.craft(run, &"spear_hunter"), false, "1 gold short")
	run.gold += 1
	run.inventory.remove(&"mat_stone_shard", 1)
	T.eq(Forge.craft(run, &"spear_hunter"), false, "1 material short")
	T.eq(run.inventory.count(&"mat_slime_gel"), 3, "nothing consumed")


func test_craft_refused_when_result_does_not_fit() -> void:
	var run := RunState.new()
	_fill(run, &"helm_iron")
	run.inventory.add(&"fang", 7)
	T.eq(run.inventory.is_full(), true)
	# Using 4 shards frees their slot, so the helm fits.
	T.eq(Forge.craft(run, &"helm_iron"), true)
	var run2 := RunState.new()
	_fill(run2, &"spear_hunter")
	run2.inventory.add(&"mat_slime_gel", 7)
	run2.inventory.add(&"fang", 6)
	# Slot 1: 10 gel (3 used leaves 7), slot 2: shards (all used), 6 relics: one free slot after.
	T.eq(Forge.craft(run2, &"spear_hunter"), true)
	var run3 := RunState.new()
	_fill(run3, &"spear_hunter")
	run3.inventory.add(&"mat_slime_gel", 7)
	run3.inventory.add(&"mat_stone_shard", 8)
	run3.inventory.add(&"fang", 5)
	# 10 gel, 10 shards, 5 relics... all slots stay used after paying: refused.
	T.eq(run3.inventory.is_full(), false)
	run3.inventory.add(&"fang")
	T.eq(Forge.craft(run3, &"spear_hunter"), false)
	T.eq(run3.inventory.count(&"mat_slime_gel"), 10, "rolled back")
	T.eq(run3.inventory.count(&"mat_stone_shard"), 10, "rolled back")
