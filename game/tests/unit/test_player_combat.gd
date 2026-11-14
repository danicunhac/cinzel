extends RefCounted
## Player-level combat: swings, the special's hold, and what breaks it.


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _game() -> Node:
	return _tree().root.get_node("Game")


func _spawn(weapon: StringName = &"sword_iron") -> Player:
	_game().new_run()
	var run: RunState = _game().run
	if weapon != run.equipment.weapon:
		run.inventory.add(weapon)
		run.equip(weapon)
	var p := (load("res://actors/player/player.tscn") as PackedScene).instantiate() as Player
	_tree().root.add_child(p)
	p.rng.seed = 1
	return p


func _cleanup(p: Player) -> void:
	p.free()
	_game().new_run()


func _enemy_hurtbox() -> Hurtbox:
	var h := Hurtbox.new()
	h.team = &"enemy"
	return h


## Runs the swing until its hit window is open.
func _open_window(p: Player) -> void:
	for i in 30:
		p._process_attack(0.01)
		if p.hitbox._active:
			return


func test_combo_swing_hits_each_enemy_once() -> void:
	var p := _spawn()
	var h := _enemy_hurtbox()
	# Lambdas capture locals by value: count in an array.
	var hits: Array[int] = [0]
	h.hit.connect(func(_hb: Hitbox) -> void: hits[0] += 1)
	p._start_attack()
	_open_window(p)
	T.ok(p.hitbox._active, "window open")
	T.ok(h.receive(p.hitbox), "first contact hits")
	T.ok(not h.receive(p.hitbox), "same swing: no second hit")
	T.eq(hits[0], 1)
	# Finish the swing; the next combo step may hit again.
	for i in 40:
		p._process_attack(0.01)
		if p.state != Player.State.ATTACK:
			break
	p._start_attack()
	T.eq(p._combo_step, 1, "second combo step")
	_open_window(p)
	T.ok(h.receive(p.hitbox), "next step hits again")
	T.eq(hits[0], 2)
	h.free()
	_cleanup(p)


func test_hold_during_cooldown_cannot_fire_special() -> void:
	var p := _spawn()
	p.special.cooldown = 2.0
	p.charge_step(0.0, true, true)
	for i in 10:
		p.charge_step(0.1, false, true)
	T.ok(not p.special.is_charged(), "no charge on cooldown")
	p.charge_step(0.0, false, false)
	T.ok(p.state != Player.State.SPECIAL, "no special on cooldown")
	_cleanup(p)


func test_hold_off_cooldown_fires_special() -> void:
	var p := _spawn()
	p.charge_step(0.0, true, true)
	for i in 6:
		p.charge_step(0.1, false, true)
	p.charge_step(0.0, false, false)
	T.eq(p.state, Player.State.SPECIAL)
	T.near(p.special.cooldown, SpecialCharge.COOLDOWN)
	_cleanup(p)


func test_roll_cancels_charge() -> void:
	var p := _spawn()
	p.charge_step(0.0, true, true)
	p.charge_step(0.3, false, true)
	T.ok(p.special.holding, "holding")
	p._start_roll(Vector2.RIGHT)
	T.ok(not p.special.holding, "roll cancels")
	_cleanup(p)


func test_damage_cancels_charge_but_block_does_not() -> void:
	var p := _spawn()
	var hb := Hitbox.new()
	hb.damage = 10
	p.charge_step(0.0, true, true)
	p.charge_step(0.3, false, true)
	p.blocks_left = 1
	p._on_hurt(hb)
	T.ok(p.special.holding, "a blocked hit keeps the charge")
	p.invincible_time = 0.0
	p._on_hurt(hb)
	T.ok(not p.special.holding, "damage cancels the charge")
	T.near(p.special.glow(), 0.0)
	hb.free()
	_cleanup(p)


func test_arrow_freed_on_wall_not_on_enemy_body() -> void:
	var a := PlayerArrow.new()
	_tree().root.add_child(a)
	var foe := CharacterBody2D.new()
	a._on_body(foe)
	T.ok(not a.is_queued_for_deletion(), "enemy bodies do not stop it")
	var wall := StaticBody2D.new()
	a._on_body(wall)
	T.ok(a.is_queued_for_deletion(), "a wall stops it")
	foe.free()
	wall.free()
	a.free()


func test_summons_drop_no_loot() -> void:
	_game().new_run()
	var e := (load("res://actors/enemies/crawler.tscn") as PackedScene).instantiate() as EnemyBase
	e.drops_loot = false
	_tree().root.add_child(e)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	EnemyBase.loot_rng = rng
	for i in 20:
		T.eq(e.roll_loot().size(), 0)
	EnemyBase.loot_rng = null
	e.free()


func _pickup(id: StringName, qty: int) -> PickupItem:
	var p := (load("res://world/pickup_item.tscn") as PackedScene).instantiate() as PickupItem
	p.item_id = id
	p.qty = qty
	_tree().root.add_child(p)
	return p


func test_busy_swap_panel_is_not_a_full_backpack() -> void:
	_game().new_run()
	var toasts: Array[String] = []
	var on_toast := func(t: String) -> void: toasts.append(t)
	_game().toast_requested.connect(on_toast)
	_game()._swap_open = true
	var p := _pickup(&"sword_knight", 1)
	var left: int = await p.take()
	T.eq(left, 1, "stays on the floor")
	T.eq(toasts.size(), 0, "no false Mochila cheia")
	_game()._swap_open = false
	_game().toast_requested.disconnect(on_toast)
	p.free()


func test_leftover_stack_retries_after_space_frees() -> void:
	_game().new_run()
	var run: RunState = _game().run
	for i in run.inventory.capacity:
		run.inventory.add(&"mat_stone_shard", 10)
	var p := _pickup(&"mat_slime_gel", 2)
	p._near = true
	p._process(0.6)
	T.eq(p.qty, 2, "still full")
	run.inventory.remove(&"mat_stone_shard", 10)
	p._process(0.6)
	T.eq(run.inventory.count(&"mat_slime_gel"), 2, "taken on retry")
	T.ok(p.is_queued_for_deletion(), "gone")
	await _tree().process_frame
