extends RefCounted
## Scripted version of the brief's manual cycle: title → town → floor 1 →
## Q-exit → sell → teleport back; then death → game over → town, all zeroed.


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _game() -> Node:
	return _tree().root.get_node("Game")


## Waits until the current scene is `path` (scene changes are deferred).
func _wait_scene(path: String) -> Node:
	for i in 300:
		var cur := _tree().current_scene
		if cur != null and cur.scene_file_path == path and cur.is_node_ready():
			return cur
		await _tree().process_frame
	return null


func _press(b: Button) -> void:
	b.pressed.emit()


func test_title_town_tower_and_back() -> void:
	_tree().change_scene_to_file("res://ui/title.tscn")
	var title := await _wait_scene("res://ui/title.tscn")
	T.ok(title != null, "title loaded")
	title.call("_new_game")
	var town := await _wait_scene(Dungeon.TOWN_SCENE)
	T.ok(town != null, "new game goes to town")
	var tp := town.call("open_panel", &"teleport") as TeleportPanel
	_press(tp.floor_buttons[0])
	var d := await _wait_scene(Dungeon.SCENE) as Dungeon
	T.ok(d != null, "teleport enters the tower")
	T.eq(d.current_floor, 1)
	T.eq(_game().run.clock.running, true, "clock runs in the tower")
	_game().run.take_loot(&"fang")
	_game().run.take_loot(&"axe_war")
	_game().run.add_gold(10)
	T.eq(_game().run.items, [&"fang"] as Array[StringName], "relic equipped")
	T.eq(_game().run.inventory.count(&"axe_war"), 1, "weapon in the backpack")
	d.player.exited.emit()
	town = await _wait_scene(Dungeon.TOWN_SCENE)
	T.ok(town != null, "Q-exit returns to town")
	T.eq(_game().run.clock.running, false)
	var axe_price: int = _game().run.market.sell_price(&"axe_war")
	var shop := town.call("open_panel", &"shop") as ShopPanel
	shop.select_tab(&"sell")
	shop.select_sell(0)
	shop.sell_selected()
	T.eq(_game().run.inventory.count(&"axe_war"), 0, "sold in town")
	T.eq(_game().run.gold, 10 + axe_price)
	shop.close()
	tp = town.call("open_panel", &"teleport") as TeleportPanel
	_press(tp.floor_buttons[0])
	d = await _wait_scene(Dungeon.SCENE) as Dungeon
	T.ok(d != null, "back in the tower")
	d.player.health.damage(10000, Vector2.ZERO)
	var over := await _wait_scene("res://ui/game_over.tscn")
	T.ok(over != null, "death shows game over")
	T.eq(int(_game().last_run.get("gold", -1)), 10 + axe_price, "game over reads the snapshot")
	over.call("_back_to_town")
	town = await _wait_scene(Dungeon.TOWN_SCENE)
	T.ok(town != null, "game over returns to town")
	T.eq(_game().run.gold, 0, "gold zeroed")
	T.eq(_game().run.items.size(), 0, "relics zeroed")
	T.eq(_game().run.equipment.weapon, Equipment.STARTER_WEAPON, "starter kit back")
	T.eq(_game().run.unlocked_floors, 1, "floors zeroed")
	T.near(_game().run.clock.seconds, 0.0)
	town.free()
	await _tree().process_frame
	_game().new_run()
