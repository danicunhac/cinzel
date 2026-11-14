extends RefCounted


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _game() -> Node:
	return _tree().root.get_node("Game")


func _hurtbox() -> Hurtbox:
	var h := Hurtbox.new()
	h.team = &"enemy"
	return h


func test_normal_arrow_hits_one() -> void:
	var a := PlayerArrow.new()
	a.pierce = 0
	_tree().root.add_child(a)
	var h1 := _hurtbox()
	var h2 := _hurtbox()
	T.ok(h1.receive(a), "first hit")
	T.ok(not h2.receive(a), "spent after one")
	T.eq(a.hits, 1)
	a.free()
	h1.free()
	h2.free()


func test_charged_arrow_pierces_one() -> void:
	var bow := WeaponDef.for_item(&"bow_short")
	var a := PlayerArrow.new()
	a.pierce = bow.charged_pierce
	_tree().root.add_child(a)
	var hs: Array[Hurtbox] = [_hurtbox(), _hurtbox(), _hurtbox()]
	T.ok(hs[0].receive(a), "first enemy")
	T.ok(not a.is_queued_for_deletion(), "passes through the first")
	T.ok(hs[1].receive(a), "second enemy")
	T.ok(not hs[2].receive(a), "stops after pierce + 1")
	T.eq(a.hits, 2)
	T.ok(a.is_queued_for_deletion(), "freed")
	a.free()
	for h in hs:
		h.free()


func _crawler() -> EnemyBase:
	var e := (load("res://actors/enemies/crawler.tscn") as PackedScene).instantiate() as EnemyBase
	_tree().root.add_child(e)
	return e


func test_axe_hit_stuns_for_its_time() -> void:
	_game().new_run()
	var e := _crawler()
	var hb := Hitbox.new()
	hb.team = &"player"
	hb.damage = 1
	hb.stun = WeaponDef.for_type(&"axe").stun
	e._on_hit(hb)
	T.near(e.stunned, 0.4)
	e._physics_process(0.25)
	T.near(e.stunned, 0.15)
	T.eq(e.velocity, Vector2.ZERO, "no moving while stunned")
	e._physics_process(0.2)
	T.near(e.stunned, 0.0)
	hb.free()
	e.free()


func test_sword_hit_does_not_stun() -> void:
	_game().new_run()
	var e := _crawler()
	var hb := Hitbox.new()
	hb.damage = 1
	e._on_hit(hb)
	T.near(e.stunned, 0.0)
	hb.free()
	e.free()


func test_enemy_loot_type() -> void:
	_game().new_run()
	var e := _crawler()
	T.eq(e.loot_type(), &"crawler")
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	EnemyBase.loot_rng = rng
	var got := 0
	for i in 20:
		for d: LootDrop in e.roll_loot():
			T.eq(d.id, &"mat_slime_gel")
			got += 1
	T.ok(got > 0, "crawlers drop slime gel")
	EnemyBase.loot_rng = null
	e.free()


func _pickup(id: StringName, qty: int) -> PickupItem:
	var p := (load("res://world/pickup_item.tscn") as PackedScene).instantiate() as PickupItem
	p.item_id = id
	p.qty = qty
	_tree().root.add_child(p)
	return p


func test_material_pickup_goes_to_backpack() -> void:
	_game().new_run()
	var p := _pickup(&"mat_slime_gel", 3)
	var left: int = await p.take()
	T.eq(left, 0)
	T.eq(_game().run.inventory.count(&"mat_slime_gel"), 3)
	T.ok(p.is_queued_for_deletion(), "pickup gone")
	await _tree().process_frame


func test_full_backpack_leaves_the_rest_on_floor() -> void:
	_game().new_run()
	var run: RunState = _game().run
	var toasts: Array[String] = []
	var on_toast := func(t: String) -> void: toasts.append(t)
	_game().toast_requested.connect(on_toast)
	# 7 slots of other stuff, 1 slot holding 8 gel: 2 more gel fit.
	for i in run.inventory.capacity - 1:
		run.inventory.add(&"mat_stone_shard", 10)
	run.inventory.add(&"mat_slime_gel", 8)
	var p := _pickup(&"mat_slime_gel", 5)
	var left: int = await p.take()
	T.eq(left, 3)
	T.eq(p.qty, 3)
	T.eq(run.inventory.count(&"mat_slime_gel"), 10)
	T.ok(not p.is_queued_for_deletion(), "stays on the floor")
	T.eq(toasts, ["Mochila cheia"] as Array[String])
	_game().toast_requested.disconnect(on_toast)
	p.free()


func test_full_backpack_keeps_gear_on_floor() -> void:
	_game().new_run()
	var run: RunState = _game().run
	for i in run.inventory.capacity:
		run.inventory.add(&"mat_stone_shard", 10)
	var p := _pickup(&"sword_knight", 1)
	var toasts: Array[String] = []
	var on_toast := func(t: String) -> void: toasts.append(t)
	_game().toast_requested.connect(on_toast)
	var panels: Array[SwapItemPanel] = []
	var on_added := func(n: Node) -> void:
		if n is SwapItemPanel:
			panels.append(n)
	_tree().node_added.connect(on_added)
	var leave_later := func() -> void:
		await _tree().process_frame
		panels[0].leave_item()
	leave_later.call()
	var left: int = await p.take()
	_tree().node_added.disconnect(on_added)
	_game().toast_requested.disconnect(on_toast)
	T.eq(panels.size(), 1, "full backpack: the choice panel opened")
	T.eq(left, 1)
	T.ok(not p.is_queued_for_deletion(), "left: gear stays")
	T.eq(toasts.size(), 0, "the panel said it, no toast")
	T.eq(_tree().paused, false, "unpaused")
	p.free()


func test_unequip_armor_clamps_hp() -> void:
	_game().new_run()
	var run: RunState = _game().run
	run.inventory.add(&"armor_plate")
	T.ok(run.equip(&"armor_plate"), "equip")
	T.eq(run.stats().max_hp, 140)
	run.hp = 140
	T.ok(run.unequip(&"armor"), "unequip")
	T.eq(run.hp, 100)


func test_unequip_clamps_player_health() -> void:
	_game().new_run()
	var run: RunState = _game().run
	run.inventory.add(&"armor_plate")
	run.equip(&"armor_plate")
	run.hp = 140
	var player := (load("res://actors/player/player.tscn") as PackedScene).instantiate() as Player
	_tree().root.add_child(player)
	T.eq(player.health.hp, 140)
	run.unequip(&"armor")
	T.eq(player.health.max_hp, 100)
	T.eq(player.health.hp, 100)
	T.eq(run.hp, 100)
	player.free()
	_game().new_run()


func test_player_defense_reduces_damage() -> void:
	_game().new_run()
	var run: RunState = _game().run
	run.inventory.add(&"armor_chain")
	run.equip(&"armor_chain")
	var player := (load("res://actors/player/player.tscn") as PackedScene).instantiate() as Player
	_tree().root.add_child(player)
	var hb := Hitbox.new()
	hb.damage = 12
	player._on_hurt(hb)
	# defense 4: 12 * 20 / 24 = 10 (hp starts at the run's 100)
	T.eq(player.health.hp, 100 - 10)
	hb.free()
	player.free()
	_game().new_run()


func test_player_uses_equipped_weapon() -> void:
	_game().new_run()
	var run: RunState = _game().run
	run.inventory.add(&"axe_woodcutter")
	run.equip(&"axe_woodcutter")
	var player := (load("res://actors/player/player.tscn") as PackedScene).instantiate() as Player
	_tree().root.add_child(player)
	T.eq(player.weapon.type, &"axe")
	T.eq(player.sprite.weapon_type, &"axe")
	run.inventory.add(&"bow_short")
	run.equip(&"bow_short")
	T.ok(player.weapon.ranged, "swapped to the bow")
	T.near(player.special.special_hold, 1.0)
	player.free()
	_game().new_run()
