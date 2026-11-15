extends RefCounted
## Armor and helm on the hero sprite: one sheet per item, attack strips per
## weapon type, the wardrobe's "Mostrar armadura" toggle, and the player
## sprite following equipment changes.

const WEAPON_TYPES: Array[StringName] = [&"sword", &"longsword", &"axe", &"spear", &"dagger", &"bow"]


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _game() -> Node:
	return _tree().root.get_node("Game")


func _sprite() -> LayeredSprite:
	var s := LayeredSprite.new()
	_tree().root.add_child(s)
	return s


func _layer(s: LayeredSprite, layer: StringName) -> Sprite2D:
	return s.get_node(String(layer)) as Sprite2D


func _gear_ids() -> Array[StringName]:
	var out := ItemDB.ids(&"armor")
	out.append_array(ItemDB.ids(&"helm"))
	return out


func test_every_armor_and_helm_has_a_sheet() -> void:
	var ids := _gear_ids()
	T.eq(ids.size(), 10, "6 armors and 4 helms")
	for id in ids:
		var path := LayeredSprite.gear_sheet_path(id)
		T.eq(path, "res://assets/characters/climber/gear/%s.png" % id)
		var tex := load(path) as Texture2D
		T.eq(tex.get_size(), Vector2(LayeredSprite.COLS, LayeredSprite.VFRAMES) * LayeredSprite.FRAME_SIZE, String(id))
	T.eq(LayeredSprite.gear_sheet_path(&""), "", "no item, no sheet")
	T.eq(LayeredSprite.gear_sheet_path(&"armor_nope"), "", "unknown item, no sheet")


func test_gear_attack_strips_follow_the_outfit_overrides() -> void:
	for id in _gear_ids():
		for type in WEAPON_TYPES:
			var has_override := LayeredSprite.attack_strip_path(type, &"outfit") != ""
			var path := LayeredSprite.gear_attack_path(type, id)
			T.eq(path != "", has_override, "%s %s" % [type, id])
			if has_override:
				T.eq(path, "res://assets/characters/climber/gear/attacks/%s_%s.png" % [type, id])
	T.eq(LayeredSprite.gear_attack_path(&"sword", &"armor_plate"), "", "the sword keeps the sheet rows")


func test_dress_draws_armor_and_helm() -> void:
	var s := _sprite()
	var e := Equipment.starter()
	e.armor = &"armor_plate"
	e.helm = &"helm_horned"
	s.dress(e)
	T.eq(_layer(s, &"armor").texture.resource_path, LayeredSprite.gear_sheet_path(&"armor_plate"))
	T.eq(_layer(s, &"helm").texture.resource_path, LayeredSprite.gear_sheet_path(&"helm_horned"))
	T.eq(s.get_child(LayeredSprite.LAYERS.find(&"armor")).name, &"armor", "armor above the outfit")
	T.ok(LayeredSprite.LAYERS.find(&"helm") > LayeredSprite.LAYERS.find(&"hair"), "helm above the hair")
	s.free()


func test_toggle_off_hides_armor_and_helm() -> void:
	var s := _sprite()
	s.set_weapon(&"axe")
	s.set_gear(&"armor_chain", &"helm_iron", true)
	T.ok(_layer(s, &"armor").texture != null, "armor shown")
	s.set_gear(&"armor_chain", &"helm_iron", false)
	T.eq(_layer(s, &"armor").texture, null, "armor hidden")
	T.eq(_layer(s, &"helm").texture, null, "helm hidden")
	s.play(&"attack", Vector2.RIGHT, true)
	T.eq(_layer(s, &"armor").texture, null, "no axe attack strip either")
	T.ok(_layer(s, &"outfit").texture != null, "the outfit stays")
	s.set_gear(&"armor_chain", &"helm_iron", true)
	T.eq(_layer(s, &"armor").texture.resource_path, LayeredSprite.gear_attack_path(&"axe", &"armor_chain"),
			"shown again, on the axe's attack rows")
	s.play(&"idle", Vector2.DOWN)
	T.eq(_layer(s, &"armor").texture.resource_path, LayeredSprite.gear_sheet_path(&"armor_chain"))
	s.set_gear(&"", &"", true)
	T.eq(_layer(s, &"armor").texture, null, "nothing equipped")
	s.free()


func test_show_armor_survives_death() -> void:
	var run := RunState.new()
	T.eq(run.equipment.show_armor, true, "on by default")
	run.set_show_armor(false)
	T.eq(run.equipment.copy().show_armor, false, "copied")
	run.die()
	T.eq(run.equipment.show_armor, false, "kept like the outfit")


func test_equipment_change_updates_player_sprite() -> void:
	_game().new_run()
	var run: RunState = _game().run
	var town := (load("res://world/town.tscn") as PackedScene).instantiate()
	_tree().root.add_child(town)
	await _tree().process_frame
	var player := town.get_node("Player") as Player
	T.eq(_layer(player.sprite, &"armor").texture, null, "starter: no armor")
	run.inventory.add(&"armor_scale")
	T.ok(run.equip(&"armor_scale"))
	T.eq(player.sprite.armor_id, &"armor_scale")
	T.eq(_layer(player.sprite, &"armor").texture.resource_path, LayeredSprite.gear_sheet_path(&"armor_scale"))
	run.take_loot(&"helm_circlet")
	T.eq(player.sprite.helm_id, &"helm_circlet", "a helm picked up goes on")
	run.set_show_armor(false)
	T.eq(_layer(player.sprite, &"armor").texture, null, "toggle off")
	T.eq(_layer(player.sprite, &"helm").texture, null)
	run.set_show_armor(true)
	T.ok(run.unequip(&"armor"))
	T.eq(_layer(player.sprite, &"armor").texture, null, "taken off")
	T.ok(_layer(player.sprite, &"helm").texture != null, "helm still on")
	town.free()
	_game().new_run()


func test_wardrobe_toggle_and_preview() -> void:
	_game().new_run()
	var run: RunState = _game().run
	run.inventory.add(&"armor_plate")
	run.equip(&"armor_plate")
	var town := (load("res://world/town.tscn") as PackedScene).instantiate()
	_tree().root.add_child(town)
	await _tree().process_frame
	var p := town.open_panel(&"wardrobe") as WardrobePanel
	T.eq(p.armor_toggle.button_pressed, true, "on by default")
	T.eq(p.armor_toggle.text, "Mostrar armadura")
	T.ok(_layer(p.hero, &"armor").texture != null, "preview shows the armor")
	p.armor_toggle.button_pressed = false
	T.eq(run.equipment.show_armor, false)
	T.eq(_layer(p.hero, &"armor").texture, null, "preview follows the toggle")
	p.preview(&"outfit_starter")
	T.eq(_layer(p.hero, &"armor").texture, null, "still hidden after a preview")
	p.close()
	await _tree().process_frame
	var player := town.get_node("Player") as Player
	T.eq(_layer(player.sprite, &"armor").texture, null, "the hero follows it")
	town.free()
	_game().new_run()


func test_every_weapon_item_has_its_own_sheet() -> void:
	var ids := ItemDB.ids(&"weapon")
	T.eq(ids.size(), 12, "12 weapons")
	for id in ids:
		var type := ItemDB.weapon_type(id)
		var path := LayeredSprite.weapon_sheet_path(type, id)
		T.eq(path, "res://assets/characters/climber/weapons/%s.png" % id)
		var tex := load(path) as Texture2D
		T.eq(tex.get_size(), Vector2(LayeredSprite.COLS, LayeredSprite.VFRAMES) * LayeredSprite.FRAME_SIZE, String(id))
	T.eq(LayeredSprite.weapon_sheet_path(&"axe", &"axe_nope"), "res://assets/characters/climber/weapons/axe.png",
			"unknown item: the type's sheet")
	T.eq(LayeredSprite.weapon_sheet_path(&"axe"), "res://assets/characters/climber/weapons/axe.png", "no item: the type's sheet")
	T.eq(LayeredSprite.weapon_sheet_path(&"nope"), "res://assets/characters/climber/weapon.png", "unknown type: the default")


func test_every_backpack_has_a_layer() -> void:
	var ids := ItemDB.ids(&"backpack")
	T.eq(ids.size(), 3)
	for id in ids:
		T.eq(LayeredSprite.gear_sheet_path(id), "res://assets/characters/climber/gear/%s.png" % id)
		for type in WEAPON_TYPES:
			var has_override := LayeredSprite.attack_strip_path(type, &"outfit") != ""
			T.eq(LayeredSprite.gear_attack_path(type, id) != "", has_override, "%s %s" % [type, id])
	T.ok(LayeredSprite.LAYERS.find(&"backpack") > LayeredSprite.LAYERS.find(&"armor"), "backpack over the armor")
	T.ok(LayeredSprite.LAYERS.find(&"backpack") < LayeredSprite.LAYERS.find(&"helm"), "helm over the backpack")


func test_dress_draws_weapon_item_and_backpack() -> void:
	var s := _sprite()
	var e := Equipment.starter()
	e.weapon = &"spear_dragoon"
	e.backpack = &"backpack_large"
	e.show_armor = false
	s.dress(e)
	T.eq(_layer(s, &"weapon").texture.resource_path, "res://assets/characters/climber/weapons/spear_dragoon.png")
	T.eq(_layer(s, &"backpack").texture.resource_path, LayeredSprite.gear_sheet_path(&"backpack_large"),
			"the backpack shows with the armor hidden")
	s.play(&"attack", Vector2.RIGHT, true)
	T.eq(_layer(s, &"backpack").texture.resource_path, LayeredSprite.gear_attack_path(&"spear", &"backpack_large"),
			"the spear's attack rows")
	s.set_backpack(&"backpack_small")
	T.eq(_layer(s, &"backpack").texture.resource_path, LayeredSprite.gear_attack_path(&"spear", &"backpack_small"))
	s.free()


func test_player_sprite_follows_weapon_and_backpack() -> void:
	_game().new_run()
	var run: RunState = _game().run
	var town := (load("res://world/town.tscn") as PackedScene).instantiate()
	_tree().root.add_child(town)
	await _tree().process_frame
	var player := town.get_node("Player") as Player
	T.eq(_layer(player.sprite, &"backpack").texture.resource_path, LayeredSprite.gear_sheet_path(&"backpack_small"),
			"starter backpack")
	T.eq(_layer(player.sprite, &"weapon").texture.resource_path, "res://assets/characters/climber/weapons/sword_iron.png")
	run.inventory.add(&"axe_war")
	T.ok(run.equip(&"axe_war"))
	T.eq(player.sprite.weapon_id, &"axe_war")
	T.eq(_layer(player.sprite, &"weapon").texture.resource_path, "res://assets/characters/climber/weapons/axe_war.png")
	run.inventory.add(&"backpack_medium")
	T.ok(run.equip(&"backpack_medium"))
	T.eq(_layer(player.sprite, &"backpack").texture.resource_path, LayeredSprite.gear_sheet_path(&"backpack_medium"))
	town.free()
	_game().new_run()


func test_weapon_light_takes_the_item_colour() -> void:
	for id: StringName in [&"longsword_ember", &"bow_elven", &"spear_dragoon"]:
		T.ok(ItemDB.fx_color(id).a > 0.0, "%s has its own light" % id)
	T.eq(ItemDB.fx_color(&"sword_iron").a, 0.0, "steel keeps the default light")
	var fx := WeaponFx.new()
	T.eq(fx.slash_color(), WeaponFx.SLASH_COLOR)
	T.eq(fx.skill_color(), WeaponFx.SKILL_COLOR)
	fx.tint = ItemDB.fx_color(&"longsword_ember")
	T.eq(fx.slash_color(), ItemDB.fx_color(&"longsword_ember"), "ember swings orange")
	T.ok(fx.skill_color() != WeaponFx.SKILL_COLOR, "and its specials too")
	fx.free()
