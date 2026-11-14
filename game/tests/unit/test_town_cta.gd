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
	T.ok(not TownLogic.cta_visible(&"smith", &"smith", 1), "smith needs two items")
	T.ok(TownLogic.cta_visible(&"smith", &"smith", 2), "smith with two items")
	T.ok(TownLogic.cta_visible(&"teleport", &"teleport", 0), "crystal always works")
	T.ok(not TownLogic.cta_visible(&"", &"", 0), "no spot")


func test_town_rings_follow_the_player() -> void:
	_game().new_run()
	var town := await _spawn("res://world/town.tscn")
	var player := town.get_node("Player") as Player
	player.global_position = TownScript.SPOTS[&"shop"]
	await _tree().process_frame
	T.eq(town.near, &"shop")
	T.ok(town._ctas[&"shop"].active, "shop ring on")
	T.ok(not town._ctas[&"smith"].active and not town._ctas[&"teleport"].active, "others off")
	T.ok(town._bubble.visible, "shopkeeper talks")
	player.global_position = TownScript.SPOTS[&"smith"]
	await _tree().process_frame
	T.eq(town.near, &"smith")
	T.ok(not town._ctas[&"smith"].active, "no items: no smith ring")
	T.ok(town._bubble.visible, "smith still talks")
	_game().run.add_item(&"fang")
	_game().run.add_item(&"spark")
	await _tree().process_frame
	T.ok(town._ctas[&"smith"].active, "two items: smith ring")
	player.global_position = TownScript.SPAWN
	await _tree().process_frame
	T.eq(town.near, &"")
	T.ok(not town._bubble.visible, "bubble hides away from NPCs")
	for id: StringName in town._ctas:
		T.ok(not town._ctas[id].active, "%s ring off" % id)
	town.free()
	_game().new_run()


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
	bubble.free()
