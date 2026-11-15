extends RefCounted
## Town call to action (ring only in range and with an action) and the NPC
## speech bubbles (at most 25 words, 3 lines).

const TownScript := preload("res://world/town.gd")


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _game() -> Node:
	return _tree().root.get_node("Game")


func _spawn(path: String) -> Node:
	var n := (load(path) as PackedScene).instantiate()
	_tree().root.add_child(n)
	await _tree().process_frame
	return n


func test_nearest_spot_respects_reach() -> void:
	var spots: Dictionary[StringName, Vector2] = {&"a": Vector2(0, 0), &"b": Vector2(100, 0)}
	T.eq(TownLogic.nearest_spot(Vector2(10, 0), spots, 30.0), &"a")
	T.eq(TownLogic.nearest_spot(Vector2(85, 0), spots, 30.0), &"b")
	T.eq(TownLogic.nearest_spot(Vector2(50, 0), spots, 30.0), &"", "between spots: none")
	T.eq(TownLogic.nearest_spot(Vector2(0, 30), spots, 30.0), &"", "reach is exclusive")


func test_cta_needs_range_and_an_action() -> void:
	T.ok(TownLogic.cta_visible(&"shop", &"shop", 0), "shop in range")
	T.ok(not TownLogic.cta_visible(&"shop", &"", 3), "out of range")
	T.ok(not TownLogic.cta_visible(&"shop", &"smith", 3), "in range of another spot")
	T.ok(not TownLogic.cta_visible(&"smith", &"smith", 5, false), "smith needs a craftable recipe")
	T.ok(TownLogic.cta_visible(&"smith", &"smith", 0, true), "smith with a craftable recipe")
	T.ok(TownLogic.cta_visible(&"wardrobe", &"wardrobe", 0), "wardrobe always works")
	T.ok(not TownLogic.cta_visible(&"", &"", 0), "no spot")


func test_town_rings_follow_the_player() -> void:
	_game().new_run()
	var town := await _spawn("res://world/town.tscn")
	var player := town.get_node("Player") as Player
	player.global_position = town.spots[&"shop"]
	await _tree().process_frame
	T.eq(town.near, &"shop")
	T.ok(town._ctas[&"shop"].active, "shop ring on")
	T.ok(not town._ctas[&"smith"].active and not town._ctas[&"wardrobe"].active, "others off")
	T.ok(town._bubble.visible, "shopkeeper talks")
	player.global_position = town.spots[&"smith"]
	await _tree().process_frame
	T.eq(town.near, &"smith")
	T.ok(not town._ctas[&"smith"].active, "nothing to forge: no smith ring")
	T.ok(town._bubble.visible, "smith still talks")
	T.eq(town._bubble.label.text, TownScript.LINES["smith_wait"])
	_game().run.inventory.add(&"mat_iron_ore", 4)
	_game().run.add_gold(35)
	await _tree().process_frame
	T.ok(town._ctas[&"smith"].active, "craftable recipe: smith ring")
	T.eq(town._bubble.label.text, TownScript.LINES["smith"])
	player.global_position = town.arrival_point(&"")
	await _tree().process_frame
	T.eq(town.near, &"")
	T.ok(not town._bubble.visible, "bubble hides away from NPCs")
	for id: StringName in town._ctas:
		T.ok(not town._ctas[id].active, "%s ring off" % id)
	town.free()
	_game().new_run()


func test_shop_line_counts_the_backpack() -> void:
	_game().new_run()
	var town := await _spawn("res://world/town.tscn")
	var player := town.get_node("Player") as Player
	player.global_position = town.spots[&"shop"]
	_game().run.add_item(&"fang")
	_game().run.add_item(&"spark")
	await _tree().process_frame
	T.eq(town._bubble.label.text, TownScript.LINES["shop"], "equipped relics are not for sale")
	_game().run.inventory.add(&"mat_old_leather")
	await _tree().process_frame
	T.eq(town._bubble.label.text, TownScript.LINES["shop_sell"], "backpack item: sell line")
	town.free()
	_game().new_run()


func test_smith_lines_talk_about_forging() -> void:
	for key: String in ["smith", "smith_wait"]:
		var text: String = TownScript.LINES[key]
		T.ok(not text.contains("dois itens"), "%s: no more 2-for-1 trade" % key)
		T.ok(text.contains("materia"), "%s mentions materials" % key)


func test_bubble_lines_fit_25_words_3_lines() -> void:
	for key: String in TownScript.LINES:
		var text: String = TownScript.LINES[key]
		T.ok(TownLogic.bubble_fits(text), "%s: %d words" % [key, TownLogic.word_count(text)])
	T.ok(not TownLogic.bubble_fits(" ".join(PackedStringArray(range(26).map(func(i: int) -> String: return "w")))), "26 words rejected")
	var bubble := SpeechBubble.new()
	_tree().root.add_child(bubble)
	for key: String in TownScript.LINES:
		bubble.say(TownScript.LINES[key])
		await _tree().process_frame
		T.ok(bubble.line_count() <= TownLogic.BUBBLE_MAX_LINES, "%s: %d lines" % [key, bubble.line_count()])
		var f := bubble.label.get_parent() as Control
		T.ok(bubble.label.position.y + bubble.label.size.y <= f.size.y - UiKit.PLAQUE_MARGIN + 1, "%s: text inside the frame" % key)
	bubble.free()


func test_backs_of_buildings_are_blocked_paths_open() -> void:
	_game().new_run()
	var town := await _spawn("res://world/town.tscn")
	await _tree().physics_frame
	await _tree().physics_frame
	var space := (town as Node2D).get_world_2d().direct_space_state
	var q := PhysicsPointQueryParameters2D.new()
	var blocked: Array[Vector2] = [Vector2(60, 60), Vector2(166, 50), Vector2(316, 50), Vector2(418, 60), Vector2(440, 230), Vector2(150, 256)]
	for p in blocked:
		q.position = p
		T.ok(not space.intersect_point(q).is_empty(), "blocked at %s" % p)
	var open: Array[Vector2] = [Vector2(240, 40), Vector2(240, 200), Vector2(240, 258), town.spots[&"shop"], town.spots[&"smith"], town.gate.get_center(), town.arrival_point(&"crystal")]
	for p in open:
		q.position = p
		var walls := space.intersect_point(q).filter(func(h: Dictionary) -> bool: return h["collider"] is StaticBody2D)
		T.ok(walls.is_empty(), "open at %s" % p)
	town.free()
	_game().new_run()


func test_villagers_have_distinct_looks_shadows_and_lines() -> void:
	_game().new_run()
	var town := await _spawn("res://world/town.tscn")
	var vs: Array[Villager] = town._villagers
	T.ok(vs.size() >= 4 and vs.size() <= 6, "4 to 6 villagers (%d)" % vs.size())
	var names := {}
	for v in vs:
		names[v.name] = true
		T.ok(v.line != "", "%s has a line" % v.name)
		T.ok(TownLogic.bubble_fits(v.line), "%s line fits" % v.name)
		var shadows := v.get_children().filter(func(c: Node) -> bool: return c is GroundShadow)
		T.eq(shadows.size(), 1, "%s has a ground shadow" % v.name)
		T.ok(String(v.animation()).begins_with("idle_") or String(v.animation()).begins_with("walk_"), "%s uses directional animations" % v.name)
	T.eq(names.size(), vs.size(), "no duplicate looks")
	# Standing next to a villager away from the spots: it stops and talks.
	var v := vs[0]
	var player := town.get_node("Player") as Player
	player.global_position = v.position - Vector2(0, 6) + Vector2(10, 0)
	await _tree().process_frame
	if town.near == &"":
		T.ok(town._bubble.visible, "villager talks")
		T.ok(v.talking, "villager stops to talk")
	town.free()
	_game().new_run()
