extends RefCounted
## E4: backpack/equipment screen, full-backpack choice, loot toasts, shop
## tabs, forge, wardrobe, and the rules around them (clock, Tab gate).


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _game() -> Node:
	return _tree().root.get_node("Game")


func _spawn(path: String) -> Node:
	var n := (load(path) as PackedScene).instantiate()
	_tree().root.add_child(n)
	await _tree().process_frame
	return n


## leave_to_town changes scene; drop the town it adds so later tests start clean.
func _cleanup_dungeon(d: Dungeon) -> void:
	_tree().paused = false
	if is_instance_valid(d):
		d.free()
	await _tree().process_frame
	await _tree().process_frame
	var cur := _tree().current_scene
	if cur != null and cur.scene_file_path == Dungeon.TOWN_SCENE:
		cur.free()
	_game().new_run()


func _open_inventory(scene: Node, in_town: bool) -> InventoryScreen:
	var inv := InventoryScreen.new()
	inv.in_town = in_town
	scene.add_child(inv)
	inv.open()
	return inv


# --- logic -------------------------------------------------------------------

func test_compare_marks_better_and_worse() -> void:
	var eq := Equipment.starter()
	var rows := ItemCompare.compare(eq, &"axe_woodcutter")
	var by: Dictionary = {}
	for r in rows:
		by[r["label"]] = r
	T.eq(by["Dano"]["old"], "10")
	T.eq(by["Dano"]["new"], "18")
	T.eq(by["Dano"]["delta"], 1, "more damage is better")
	T.eq(by["Vel. ataque"]["delta"], -1, "slower is worse")
	eq.armor = &"armor_chain"
	rows = ItemCompare.compare(eq, &"armor_shadow")
	by.clear()
	for r in rows:
		by[r["label"]] = r
	T.eq(by["Peso"]["delta"], 1, "lighter armor is better")
	T.eq(ItemCompare.compare(eq, &"mat_slime_gel").size(), 0, "materials do not compare")
	var bp := ItemCompare.compare(eq, &"backpack_large")
	T.eq(bp[0]["label"], "Espaços")
	T.eq(bp[0]["new"], "20")
	T.ok(ItemCompare.own(&"sword_iron").size() >= 4, "a weapon lists its numbers")


func test_inventory_take_slot_empties_the_whole_stack() -> void:
	var inv := Inventory.new(8)
	inv.add(&"mat_slime_gel", 7)
	T.eq(inv.take_slot(0), {"id": &"mat_slime_gel", "qty": 7})
	T.ok(inv.is_empty())
	T.eq(inv.take_slot(0), {}, "empty slot")


func test_market_trend_and_total_follow_decay() -> void:
	var m := Market.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 2
	m.begin_visit(rng)
	m.wanted.clear()
	T.eq(m.trend(&"fang"), 0, "normal")
	var run := RunState.new()
	run.inventory.add(&"mat_slime_core", 5)
	var expected := m.sell_total(&"mat_slime_core", 3)
	var base := ItemDB.price(&"mat_slime_core")
	T.eq(expected, roundi(base * 1.0) + roundi(base * 0.85) + roundi(base * 0.7))
	T.eq(m.sell_many(run, 0, 3), expected, "selling 3 pays the previewed total")
	T.eq(run.inventory.count(&"mat_slime_core"), 2)
	T.eq(m.trend(&"mat_slime_core"), -1, "sold too much: falling")
	m.wanted.append(&"mat_slime_core")
	T.eq(m.trend(&"mat_slime_core"), 1, "wanted wins")


func test_market_stock_follows_opened_floors() -> void:
	for seed_value in 20:
		var m := Market.new()
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		m.begin_visit(rng, 1)
		for id in m.stock:
			T.eq(ItemDB.rarity(id), &"common", "floor 1 stock is common: %s" % id)
		for id in m.wanted:
			T.ok(Market.available(id, 1), "wanted item of an open floor: %s" % id)


func test_forge_block_reason_in_order() -> void:
	var run := RunState.new()
	T.eq(Forge.block_reason(run, &"sword_knight"), "Vença o chefe do andar 1")
	T.eq(Forge.block_reason(run, &"helm_iron"), "Faltam materiais")
	run.inventory.add(&"mat_stone_shard", 4)
	T.eq(Forge.block_reason(run, &"helm_iron"), "Ouro insuficiente")
	run.add_gold(35)
	T.eq(Forge.block_reason(run, &"helm_iron"), "")
	for i in 7:
		run.inventory.add(&"fang")
	T.eq(Forge.block_reason(run, &"helm_iron"), "", "the shards' slot frees up for the helm")
	run.inventory.add(&"mat_stone_shard", 1)
	T.eq(Forge.block_reason(run, &"helm_iron"), "Mochila cheia", "shards stay: no room")


# --- backpack screen ---------------------------------------------------------

func test_inventory_screen_equips_and_unequips() -> void:
	_game().new_run()
	var run: RunState = _game().run
	run.inventory.add(&"axe_war")
	run.inventory.add(&"armor_chain")
	var town := await _spawn("res://world/town.tscn")
	var inv := _open_inventory(town, true)
	T.eq(_tree().paused, true, "the screen pauses")
	T.eq(inv.bag_cells.size(), run.inventory.capacity, "one cell per backpack slot")
	inv.select_bag(0)
	T.eq(inv.primary_kind(), &"equip")
	T.ok(inv.primary(), "equip the axe")
	T.eq(run.equipment.weapon, &"axe_war")
	T.eq(run.inventory.count(&"sword_iron"), 1, "old sword back in the backpack")
	inv.select_bag(run.inventory.slots.find({"id": &"armor_chain", "qty": 1}))
	T.ok(inv.primary(), "equip the armor")
	T.eq(run.equipment.armor, &"armor_chain")
	inv.select_doll(&"armor")
	T.eq(inv.primary_kind(), &"unequip")
	T.ok(inv.primary(), "take the armor off")
	T.eq(run.equipment.armor, &"")
	T.eq(run.inventory.count(&"armor_chain"), 1)
	inv.select_doll(&"weapon")
	T.eq(inv.primary_kind(), &"", "the weapon only swaps")
	inv.select_doll(&"outfit")
	T.eq(inv.primary_kind(), &"", "outfit is read-only here")
	inv.close()
	T.eq(_tree().paused, false)
	town.free()
	_game().new_run()


func test_inventory_relic_swap_asks_which_relic() -> void:
	_game().new_run()
	var run: RunState = _game().run
	for id: StringName in [&"fang", &"spark", &"light_boots"]:
		run.add_item(id)
	run.inventory.add(&"glass_shield")
	var town := await _spawn("res://world/town.tscn")
	var inv := _open_inventory(town, true)
	inv.select_bag(0)
	inv.primary()
	T.eq(inv.relic_pick, &"glass_shield", "waits for the relic to replace")
	inv.select_doll(&"relic", 1)
	T.eq(inv.primary_kind(), &"pick")
	T.ok(inv.primary())
	T.eq(run.items, [&"fang", &"glass_shield", &"light_boots"] as Array[StringName])
	T.eq(run.inventory.count(&"spark"), 1)
	inv.close()
	town.free()
	_game().new_run()


func test_drop_spawns_pickup_in_dungeon_and_is_off_in_town() -> void:
	_game().new_run()
	var run: RunState = _game().run
	run.inventory.add(&"mat_slime_gel", 6)
	var town := await _spawn("res://world/town.tscn")
	var tinv := _open_inventory(town, true)
	tinv.select_bag(0)
	T.eq(tinv.drop_button.disabled, true, "no dropping in town")
	T.eq(tinv.drop(), false)
	T.eq(run.inventory.count(&"mat_slime_gel"), 6, "nothing lost in town")
	tinv.close()
	town.free()

	var d := await _spawn("res://world/dungeon.tscn") as Dungeon
	var inv := _open_inventory(d, false)
	inv.select_bag(0)
	T.eq(inv.drop_button.disabled, false)
	T.ok(inv.drop(), "dropped")
	T.eq(run.inventory.count(&"mat_slime_gel"), 0, "the whole stack left")
	var drops: Array[PickupItem] = []
	for n in d.room.get_children():
		if n is PickupItem and (n as PickupItem).item_id == &"mat_slime_gel":
			drops.append(n)
	T.eq(drops.size(), 1, "one pickup in the room")
	T.eq(drops[0].qty, 6)
	T.ok(drops[0].wait_exit, "not taken back at once")
	T.ok(drops[0].global_position.distance_to(d.player.global_position) < 8.0, "at the player's feet")
	inv.close()
	for i in 3:
		await _tree().physics_frame
	T.eq(run.inventory.count(&"mat_slime_gel"), 0, "standing on it does not take it back")
	await _cleanup_dungeon(d)


func test_clock_frozen_while_screens_are_open() -> void:
	_game().new_run()
	var d := await _spawn("res://world/dungeon.tscn") as Dungeon
	await _tree().process_frame
	var pause := d.get_node("Pause") as PauseMenu
	var inv := pause.open_inventory()
	T.ok(inv != null, "Tab opens the backpack in a normal room")
	var before: float = _game().run.clock.seconds
	for i in 5:
		await _tree().process_frame
	T.near(_game().run.clock.seconds, before)
	inv.close()
	var panel := SwapItemPanel.new()
	d.add_child(panel)
	panel.open_for(&"axe_war")
	before = _game().run.clock.seconds
	for i in 5:
		await _tree().process_frame
	T.near(_game().run.clock.seconds, before)
	panel.close()
	for i in 3:
		await _tree().process_frame
	T.ok(_game().run.clock.seconds > before, "runs again after closing")
	await _cleanup_dungeon(d)


func test_tab_gate() -> void:
	_game().new_run()
	var d := await _spawn("res://world/dungeon.tscn") as Dungeon
	await _tree().process_frame
	var pause := d.get_node("Pause") as PauseMenu
	var panel := SwapItemPanel.new()
	d.add_child(panel)
	panel.open_for(&"axe_war")
	T.eq(pause.open_inventory(), null, "not over another panel")
	panel.close()
	await _tree().process_frame
	_game().in_boss_room = true
	var toasts: Array[String] = []
	var on_toast := func(t: String) -> void: toasts.append(t)
	_game().toast_requested.connect(on_toast)
	T.eq(pause.open_inventory(), null, "not during a boss fight")
	_game().toast_requested.disconnect(on_toast)
	T.eq(toasts, [PauseMenu.BOSS_TEXT] as Array[String], "says why")
	pause.open()
	T.eq(pause.bag_button.disabled, true, "pause menu button off in the boss room")
	pause.close()
	_game().in_boss_room = false
	await _tree().process_frame
	var inv := pause.open_inventory()
	T.ok(inv != null, "opens once the boss is down")
	T.eq(inv.in_town, false)
	T.eq(pause.open_inventory(), null, "not twice")
	inv.close()
	await _cleanup_dungeon(d)


# --- full backpack, toasts ---------------------------------------------------

func test_full_backpack_swap_drops_the_chosen_stack() -> void:
	_game().new_run()
	var run: RunState = _game().run
	run.inventory.add(&"mat_slime_gel", 7)
	for i in run.inventory.capacity - 1:
		run.inventory.add(&"fang")
	T.ok(run.inventory.is_full())
	var p := (load("res://world/pickup_item.tscn") as PackedScene).instantiate() as PickupItem
	p.item_id = &"axe_war"
	_tree().root.add_child(p)
	var panels: Array[SwapItemPanel] = []
	var on_added := func(n: Node) -> void:
		if n is SwapItemPanel:
			panels.append(n)
	_tree().node_added.connect(on_added)
	var pick_later := func() -> void:
		await _tree().process_frame
		panels[0].select(0)
		panels[0].confirm()
	pick_later.call()
	var left: int = await p.take()
	_tree().node_added.disconnect(on_added)
	T.eq(left, 0, "taken")
	T.eq(run.inventory.count(&"axe_war"), 1)
	T.eq(run.inventory.count(&"mat_slime_gel"), 0, "the chosen stack left")
	await _tree().process_frame
	var dropped: PickupItem = null
	for n in _tree().root.get_children():
		if n is PickupItem and (n as PickupItem).item_id == &"mat_slime_gel":
			dropped = n
	T.ok(dropped != null, "dropped where the axe was")
	if dropped != null:
		T.eq(dropped.qty, 7, "the whole stack")
		T.ok(dropped.wait_exit)
		dropped.free()
	T.eq(_tree().paused, false)
	_game().new_run()


func test_loot_toasts_stack_merge_and_cap() -> void:
	_game().new_run()
	var town := await _spawn("res://world/town.tscn")
	var hud := town.get_node("Hud") as Hud
	_game().run.take_loot(&"mat_slime_gel", 2)
	T.eq(hud.loot_toasts.toasts.size(), 1)
	T.eq((hud.loot_toasts.toasts[0]["label"] as Label).text, "+2 Gosma de Slime")
	_game().run.take_loot(&"mat_slime_gel", 1)
	T.eq(hud.loot_toasts.toasts.size(), 1, "same item adds up")
	T.eq((hud.loot_toasts.toasts[0]["label"] as Label).text, "+3 Gosma de Slime")
	for id: StringName in [&"mat_stone_shard", &"mat_slime_core", &"fang"]:
		_game().run.take_loot(id)
	T.eq(hud.loot_toasts.toasts.size(), LootToasts.MAX_VISIBLE, "at most 3")
	T.eq(hud.loot_toasts.toasts[0]["id"], &"mat_stone_shard", "the oldest left")
	hud.loot_toasts._process(LootToasts.LIFE + 0.1)
	T.eq(hud.loot_toasts.toasts.size(), 0, "they fade out")
	town.free()
	_game().new_run()


# --- town panels -------------------------------------------------------------

func test_shop_sell_stack_with_quantity() -> void:
	_game().new_run()
	var run: RunState = _game().run
	run.inventory.add(&"mat_beetle_horn", 5)
	var town := await _spawn("res://world/town.tscn")
	var shop: Market = town.shop
	shop.wanted.clear()
	var p := town.open_panel(&"shop") as ShopPanel
	T.eq(p.tab, &"sell")
	p.select_sell(0)
	p.set_qty(3)
	var total := shop.sell_total(&"mat_beetle_horn", 3)
	T.eq(p.sell_selected(), total)
	T.eq(run.gold, total)
	T.eq(run.inventory.count(&"mat_beetle_horn"), 2)
	T.near(shop.factor(&"mat_beetle_horn"), 1.0 - 3 * Market.DECAY_PER_SALE, 0.0001)
	T.ok(shop.sell_price(&"mat_beetle_horn") < ItemDB.price(&"mat_beetle_horn"), "price fell")
	p.close()
	town.free()
	_game().new_run()


func test_shop_buy_needs_gold_and_buys_outfits() -> void:
	_game().new_run()
	var run: RunState = _game().run
	var town := await _spawn("res://world/town.tscn")
	var p := town.open_panel(&"shop") as ShopPanel
	p.select_tab(&"buy")
	p.select_buy(0)
	T.eq(p.buy_selected(), false, "no gold")
	T.eq(p.action_button.disabled, true)
	run.add_gold(1000)
	var list := p.buy_list()
	var outfit := list.find(&"outfit_casaco_longo")
	T.ok(outfit >= 0, "market outfits are on sale")
	p.select_buy(outfit)
	T.ok(p.buy_selected())
	T.ok(run.unlocked_outfits.has(&"outfit_casaco_longo"), "unlocked for the wardrobe")
	T.eq(run.gold, 1000 - town.shop.buy_price(&"outfit_casaco_longo"))
	T.ok(not p.buy_list().has(&"outfit_casaco_longo"), "not sold twice")
	p.close()
	town.free()
	_game().new_run()


func test_forge_craft_consumes_and_adds() -> void:
	_game().new_run()
	var run: RunState = _game().run
	run.inventory.add(&"mat_slime_gel", 4)
	run.inventory.add(&"mat_slime_core", 1)
	run.add_gold(50)
	var town := await _spawn("res://world/town.tscn")
	var p := town.open_panel(&"smith") as SmithPanel
	p.select(Forge.unlocked(0).find(&"armor_leather"))
	T.eq(p.reason, "")
	T.ok(p.craft_selected())
	T.eq(run.inventory.count(&"armor_leather"), 1)
	T.eq(run.inventory.count(&"mat_slime_gel"), 0)
	T.eq(run.inventory.count(&"mat_slime_core"), 0)
	T.eq(run.gold, 10)
	T.eq(p.craft_button.disabled, true, "nothing left to forge it again")
	p.close()
	town.free()
	_game().new_run()


func test_wardrobe_spot_and_outfit() -> void:
	_game().new_run()
	var run: RunState = _game().run
	var town := await _spawn("res://world/town.tscn")
	var player := town.get_node("Player") as Player
	player.global_position = town.SPOTS[&"wardrobe"]
	await _tree().process_frame
	T.eq(town.near, &"wardrobe")
	T.ok(town._ctas[&"wardrobe"].active, "wardrobe ring on")
	var p := town.open_panel(&"wardrobe") as WardrobePanel
	T.eq(p.wear(&"outfit_manto_mago"), false, "locked outfit")
	T.eq(run.equipment.outfit, Equipment.STARTER_OUTFIT)
	run.unlock_outfit(&"outfit_manto_mago")
	p.preview(&"outfit_manto_mago")
	T.eq(p.hero.outfit_dir, "manto_mago", "live preview")
	T.eq(run.equipment.outfit, Equipment.STARTER_OUTFIT, "preview does not wear")
	T.ok(p.wear(&"outfit_manto_mago"))
	T.eq(run.equipment.outfit, &"outfit_manto_mago")
	p.close()
	await _tree().process_frame
	T.eq(player.sprite.outfit_dir, "manto_mago", "the hero wears it")
	run.die()
	T.eq(run.equipment.outfit, &"outfit_manto_mago", "survives death")
	town.free()
	_game().new_run()


func test_shop_gear_sells_on_second_press_only() -> void:
	_game().new_run()
	var run: RunState = _game().run
	run.inventory.add(&"axe_war")
	run.inventory.add(&"mat_slime_gel", 2)
	var town := await _spawn("res://world/town.tscn")
	var p := town.open_panel(&"shop") as ShopPanel
	p.select_sell(0)
	p._on_sell_activated(0)
	T.eq(run.inventory.count(&"axe_war"), 1, "a press on the cell only selects")
	p.action_button.pressed.emit()
	T.eq(run.inventory.count(&"axe_war"), 1, "first press arms")
	T.ok(p.sell_armed)
	p.action_button.pressed.emit()
	T.eq(run.inventory.count(&"axe_war"), 0, "second press sells")
	p.select_sell(run.inventory.slots.find({"id": &"mat_slime_gel", "qty": 2}))
	p.action_button.pressed.emit()
	T.eq(run.inventory.count(&"mat_slime_gel"), 1, "materials sell at once")
	p.close()
	town.free()
	_game().new_run()
