extends RefCounted
## Lâminas Gêmeas (off-hand sword), the Lâmina da Meia-Noite, and weapons
## put away in town.


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _game() -> Node:
	return _tree().root.get_node("Game")


func _dual_eq() -> Equipment:
	var eq := Equipment.starter()
	eq.dual = true
	return eq


func test_offhand_slot_absent_without_the_skill() -> void:
	var eq := Equipment.starter()
	var inv := Inventory.new(8)
	inv.add(&"sword_knight")
	T.eq(eq.can_offhand(&"sword_knight"), false)
	T.eq(eq.equip_offhand(&"sword_knight", inv), false, "no slot")
	T.eq(eq.offhand, &"")
	T.eq(inv.count(&"sword_knight"), 1, "still in the backpack")
	T.eq(eq.dual_active(), false)
	var run := RunState.new()
	T.eq(run.dual_blades, false, "off by default")
	T.eq(run.equipment.dual, false)


func test_offhand_takes_only_swords() -> void:
	var eq := _dual_eq()
	var inv := Inventory.new(8)
	for id: StringName in [&"axe_war", &"dagger_rogue", &"longsword_steel", &"bow_short", &"armor_chain", &"sword_knight"]:
		inv.add(id)
	for id: StringName in [&"axe_war", &"dagger_rogue", &"longsword_steel", &"bow_short", &"armor_chain"]:
		T.eq(eq.equip_offhand(id, inv), false, "%s refused" % id)
	T.eq(eq.equip_offhand(&"sword_knight", inv), true)
	T.eq(eq.offhand, &"sword_knight")
	T.eq(eq.dual_active(), true, "iron sword + knight sword")


func test_offhand_equip_unequip_round_trip() -> void:
	var eq := _dual_eq()
	var inv := Inventory.new(8)
	inv.add(&"sword_knight")
	inv.add(&"sword_midnight")
	T.eq(eq.equip_offhand(&"sword_knight", inv), true)
	T.eq(inv.count(&"sword_knight"), 0)
	T.eq(eq.equip_offhand(&"sword_midnight", inv), true, "swap")
	T.eq(inv.count(&"sword_knight"), 1, "old one back in the backpack")
	T.eq(eq.get_slot(&"offhand"), &"sword_midnight")
	T.eq(eq.unequip(&"offhand", inv), true)
	T.eq(eq.offhand, &"")
	T.eq(inv.count(&"sword_midnight"), 1)
	T.eq(eq.weapon, &"sword_iron", "main weapon untouched")


func test_offhand_unused_without_a_main_sword() -> void:
	var eq := _dual_eq()
	var inv := Inventory.new(8)
	inv.add(&"sword_knight")
	inv.add(&"axe_war")
	eq.equip_offhand(&"sword_knight", inv)
	eq.equip(&"axe_war", inv)
	T.eq(eq.dual_active(), false, "axe in the main hand")
	T.eq(PlayerStats.from_equipment(eq).offhand_damage, 0)


func test_skill_survives_death() -> void:
	var run := RunState.new()
	run.set_dual_blades(true)
	run.inventory.add(&"sword_knight")
	T.eq(run.equip_offhand(&"sword_knight"), true)
	run.die()
	T.eq(run.dual_blades, true, "skill kept")
	T.eq(run.equipment.dual, true, "slot back")
	T.eq(run.equipment.offhand, &"", "the sword is lost with the rest")


func test_dual_def_combo_of_four_alternating_hands() -> void:
	var single := WeaponDef.for_item(&"sword_midnight")
	var d := WeaponDef.dual_swords(&"sword_midnight")
	T.eq(d.combo, 4)
	T.eq(d.combo_mult.size(), 4)
	T.eq(d.special, &"cross_flurry")
	T.ok(absf(d.swing_time(1.0) - single.swing_time(1.0) * 0.85) < 0.0001, "15% faster swings")
	T.eq([d.is_offhand_step(0), d.is_offhand_step(1), d.is_offhand_step(2), d.is_offhand_step(3)],
			[false, true, false, true])
	T.eq(single.is_offhand_step(1), false, "one sword: no off-hand")
	T.eq(single.combo, 3, "one sword keeps the 3-hit combo")


func test_offhand_share_of_damage() -> void:
	var eq := _dual_eq()
	var inv := Inventory.new(8)
	inv.add(&"sword_knight")
	eq.equip_offhand(&"sword_knight", inv)
	var knight_dmg := int(ItemDB.get_def(&"sword_knight")["stats"]["damage"])
	T.eq(PlayerStats.from_equipment(eq).offhand_damage, roundi(knight_dmg * WeaponDef.DUAL_OFFHAND_SHARE))
	T.eq(PlayerStats.from_equipment(Equipment.starter()).offhand_damage, 0)


func _spawn_dual() -> Player:
	_game().new_run()
	var run: RunState = _game().run
	run.set_dual_blades(true)
	run.inventory.add(&"sword_midnight")
	run.equip(&"sword_midnight")
	run.inventory.add(&"sword_knight")
	run.equip_offhand(&"sword_knight")
	var p := (load("res://actors/player/player.tscn") as PackedScene).instantiate() as Player
	_tree().root.add_child(p)
	p.rng.seed = 1
	return p


func _finish_swing(p: Player) -> void:
	for i in 60:
		p._process_attack(0.01)
		if p.state != Player.State.ATTACK:
			return


func test_player_combo_of_four_with_offhand_bonus() -> void:
	var p := _spawn_dual()
	p._stats.crit_chance = 0.0
	T.eq(p.weapon.combo, 4)
	T.eq(p.offhand_id, &"sword_knight")
	T.eq(p.sprite.offhand_id, &"sword_knight", "second sword drawn")
	var base := p.stats().damage
	var bonus := p.stats().offhand_damage
	T.ok(bonus > 0, "off-hand adds damage")
	var dmg: Array[int] = []
	var off: Array[bool] = []
	for i in 4:
		p._start_attack()
		dmg.append(p.hitbox.damage)
		off.append(p.sprite.offhand_swing)
		_finish_swing(p)
	T.eq(off, [false, true, false, true] as Array[bool], "hands alternate")
	T.eq(dmg[0], base)
	T.eq(dmg[1], base + bonus)
	T.eq(dmg[2], base)
	T.eq(dmg[3], roundi((base + bonus) * WeaponDef.DUAL_COMBO_MULT[3]), "finisher by the off-hand")
	p._start_attack()
	T.eq(p.hitbox.damage, base, "the combo wraps to the main hand")
	p.free()
	_game().new_run()


func test_player_without_offhand_unchanged() -> void:
	_game().new_run()
	var p := (load("res://actors/player/player.tscn") as PackedScene).instantiate() as Player
	_tree().root.add_child(p)
	T.eq(p.weapon.combo, 3)
	T.eq(p.weapon.special, &"thrust_line")
	T.eq(p.offhand_id, &"")
	T.eq(p.sprite.offhand_id, &"")
	p.free()


func test_cross_special_hits_with_both_swords() -> void:
	var p := _spawn_dual()
	p._stats.crit_chance = 0.0
	p._start_special()
	T.eq(p.state, Player.State.SPECIAL)
	var want := roundi((p.stats().damage + p.stats().offhand_damage) * WeaponDef.DUAL_SPECIAL_MULT)
	T.eq(p.hitbox.damage, want)
	var cuts: Array[int] = [1]
	for i in 100:
		var before := p._special_step
		p._process_special(0.01)
		if p._special_step != before:
			cuts[0] += 1
		if p.state != Player.State.SPECIAL:
			break
	T.eq(cuts[0], WeaponDef.CROSS_CUTS)
	T.eq(p.state, Player.State.FREE)
	p.free()
	_game().new_run()


func test_midnight_has_no_source() -> void:
	T.eq(ItemDB.kind(&"sword_midnight"), &"weapon")
	T.eq(ItemDB.weapon_type(&"sword_midnight"), &"sword")
	T.eq(ItemDB.rarity(&"sword_midnight"), &"epic")
	T.eq(ItemDB.has_source(&"sword_midnight"), false)
	T.ok(not ItemDB.sourced_by(&"weapon", &"epic").has(&"sword_midnight"), "not in the epic pool")
	T.ok(ResourceLoader.exists(ItemDB.icon_path(&"sword_midnight")), "icon")
	T.ok(ResourceLoader.exists("res://assets/characters/climber/weapons/sword_midnight.png"), "weapon sheet")
	var knight: Dictionary = ItemDB.get_def(&"sword_knight")["stats"]
	var mid: Dictionary = ItemDB.get_def(&"sword_midnight")["stats"]
	T.ok(int(mid["damage"]) > int(knight["damage"]), "stronger than the knight's sword")
	T.ok(ItemDB.fx_color(&"sword_midnight").a > 0.0, "own swing colour")


func test_midnight_not_in_loot_market_or_forge() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 3000:
		var f := 1 + i % 3
		T.ok(LootTable.roll_chest(f, 4, rng) != &"sword_midnight", "chest")
		for d: LootDrop in LootTable.roll_boss(f, 4, rng):
			if d.id == &"sword_midnight":
				T.ok(false, "boss drop")
	for t: StringName in [&"crawler", &"shooter", &"charger"]:
		for i in 200:
			for d: LootDrop in LootTable.roll_enemy(t, 1 + i % 3, rng):
				T.ok(d.id != &"sword_midnight", "enemy drop")
	for i in 300:
		var m := Market.new()
		m.begin_visit(rng, RunState.MAX_FLOOR)
		T.ok(not m.stock.has(&"sword_midnight"), "market stock")
		T.ok(not m.wanted.has(&"sword_midnight"), "market wanted")
	for r: StringName in Forge.RECIPES:
		T.ok(Forge.RECIPES[r]["result"] != &"sword_midnight", "forge recipe")


func test_offhand_layer_behind_body_in_side_view() -> void:
	var s := LayeredSprite.new()
	_tree().root.add_child(s)
	var eq := _dual_eq()
	var inv := Inventory.new(8)
	inv.add(&"sword_knight")
	eq.equip_offhand(&"sword_knight", inv)
	s.dress(eq)
	s.play(&"idle", Vector2.DOWN)
	var off := s.get_node("offhand") as Sprite2D
	T.ok(off.texture != null, "off-hand drawn")
	T.ok(off.get_index() > s.get_node("body").get_index(), "front view: over the body")
	s.play(&"idle", Vector2.RIGHT)
	T.ok(off.get_index() < s.get_node("body").get_index(), "side view: behind the body")
	s.offhand_swing = true
	s.play(&"attack", Vector2.DOWN, true)
	T.eq((s.get_node("weapon") as Sprite2D).texture.resource_path,
			"res://assets/characters/climber/weapons/sword_knight.png", "off-hand swing: its sword swings")
	T.eq((s.get_node("body") as Sprite2D).flip_h, true, "from the other side")
	s.free()


func test_sheathed_sprite_uses_put_away_sheets() -> void:
	var s := LayeredSprite.new()
	_tree().root.add_child(s)
	s.set_weapon(&"axe", &"axe_war")
	s.set_sheathed(true)
	s.play(&"idle", Vector2.DOWN)
	var w := s.get_node("weapon") as Sprite2D
	T.eq(w.texture.resource_path, "res://assets/characters/climber/weapons/axe_war_sheathed.png")
	T.ok(w.get_index() < s.get_node("body").get_index(), "on the back, behind in front view")
	s.play(&"walk", Vector2.UP)
	T.ok(w.get_index() > s.get_node("body").get_index(), "over the pack in back view")
	s.set_sheathed(false)
	T.eq(w.texture.resource_path, "res://assets/characters/climber/weapons/axe_war.png", "in hand again")
	s.free()


func test_every_weapon_has_sheathed_sheet() -> void:
	for id: StringName in ItemDB.ids(&"weapon"):
		T.ok(LayeredSprite.sheathed_sheet_path(id) != "", "%s sheathed" % id)
		if ItemDB.weapon_type(id) == &"sword":
			T.ok(LayeredSprite.offhand_sheet_path(id) != "", "%s off-hand" % id)
			T.ok(LayeredSprite.offhand_sheet_path(id, true) != "", "%s off-hand sheathed" % id)


func test_weapons_put_away_in_town_in_hand_in_dungeon() -> void:
	_game().new_run()
	var p := (load("res://actors/player/player.tscn") as PackedScene).instantiate() as Player
	_tree().root.add_child(p)
	T.eq(p.sprite.sheathed, false, "armed: in hand")
	p.free()
	var town := (load("res://world/town.tscn") as PackedScene).instantiate()
	_tree().root.add_child(town)
	await _tree().process_frame
	var tp := town.get("player") as Player
	T.eq(tp.armed, false)
	T.eq(tp.sprite.sheathed, true, "town: put away")
	town.free()
	_game().new_run()
