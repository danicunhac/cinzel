extends RefCounted
## The scenes hold their content as nodes (what the editor shows), and the
## scripts only add behaviour: nothing is built twice at runtime.


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _game() -> Node:
	return _tree().root.get_node("Game")


func _count(root: Node, cls: String) -> int:
	var n := 1 if root.is_class(cls) else 0
	for c in root.get_children():
		n += _count(c, cls)
	return n


func test_town_layout_is_in_the_scene_and_built_once() -> void:
	_game().new_run()
	var town := (load("res://world/town.tscn") as PackedScene).instantiate()
	for path: String in ["Ground", "Buildings/Shop", "Buildings/Forge", "Buildings/HouseA", "Tower", "Crystal/Glow",
			"Npcs/Shopkeeper", "Spots/Shop/Ring", "Gate/Shape", "Arrivals/Spawn", "Walks/Walk1",
			"Lamps/Lamp1/Light", "Effects/Smoke/Particles", "Collision/Bounds", "Collision/TowerWalls", "Tint"]:
		T.ok(town.has_node(path), "town.tscn has %s" % path)
	var saved := {}
	for cls: String in ["PointLight2D", "CPUParticles2D", "StaticBody2D", "CanvasModulate"]:
		saved[cls] = _count(town, cls)
	_tree().root.add_child(town)
	await _tree().process_frame
	for cls: String in saved:
		T.eq(_count(town, cls), saved[cls], "%s not added at runtime" % cls)
	T.ok(not town.has_node("Npcs/Shopkeeper/EditorPreview"), "NPC editor preview dropped")
	T.eq(town.spots.size(), 3, "three spots read from the markers")
	T.eq(town._villagers.size(), town.get_node("Walks").get_child_count(), "one villager per walk")
	town.free()
	_game().new_run()


func test_title_layout_is_in_the_scene() -> void:
	var title := (load("res://ui/title.tscn") as PackedScene).instantiate()
	for path: String in ["Background", "Logo", "LogoGlow", "Tagline", "Menu/NewGame", "Menu/Credits", "Menu/Quit",
			"Help", "Foreground/Hero/body", "Embers/Town", "FogFar/Fog1"]:
		T.ok(title.has_node(path), "title.tscn has %s" % path)
	T.ok((title.get_node("Tagline") as Control).visible, "saved as the finished screen")
	_tree().root.add_child(title)
	await _tree().process_frame
	T.ok(not (title.get_node("Tagline") as Control).visible, "intro starts with the tagline hidden")
	T.eq(title.buttons.size(), 3, "three menu buttons")
	T.eq((title.get_node("Foreground/Hero") as Node).get_child_count(), LayeredSprite.LAYERS.size(),
			"hero layers reused, not added")
	title.free()


func test_dungeon_preview_room_is_editor_only() -> void:
	_game().new_run()
	var d := (load("res://world/dungeon.tscn") as PackedScene).instantiate() as Dungeon
	T.ok(d.has_node("Rooms/EditorPreview"), "dungeon.tscn shows an example room")
	_tree().root.add_child(d)
	await _tree().process_frame
	T.ok(not d.has_node("Rooms/EditorPreview"), "preview gone at runtime")
	T.ok(d.get_node("Rooms").get_child_count() <= 1, "only the real room under Rooms")
	d.free()
	_game().new_run()


func test_player_layers_are_in_the_scene() -> void:
	var p := (load("res://actors/player/player.tscn") as PackedScene).instantiate()
	T.eq(p.get_node("Sprite").get_child_count(), LayeredSprite.LAYERS.size(), "layer sprites saved")
	T.ok((p.get_node("Sprite/body") as Sprite2D).texture != null, "default look saved")
	p.free()
