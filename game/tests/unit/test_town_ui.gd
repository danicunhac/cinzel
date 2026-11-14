extends RefCounted
## Town panels, HUD and end screens.


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _game() -> Node:
	return _tree().root.get_node("Game")


func _spawn(path: String) -> Node:
	var n := (load(path) as PackedScene).instantiate()
	_tree().root.add_child(n)
	await _tree().process_frame
	return n


func test_teleport_lists_unlocked_floors() -> void:
	_game().new_run()
	var town := await _spawn("res://world/town.tscn")
	var p := town.open_panel(&"teleport") as TeleportPanel
	T.eq(p.floor_buttons.size(), 1, "only floor 1 at start")
	T.eq(p.floor_buttons[0].disabled, false, "floor 1 is built")
	p.close()
	_game().run.unlock_floor(3)
	p = town.open_panel(&"teleport") as TeleportPanel
	T.eq(p.floor_buttons.size(), 3, "floors 1..3")
	p.travel = false
	var chosen: Array[int] = []
	p.floor_chosen.connect(func(n: int) -> void: chosen.append(n))
	p.floor_buttons[0].pressed.emit()
	T.eq(chosen, [1] as Array[int])
	T.eq(_tree().paused, false, "choosing closes the panel")
	town.free()
	_game().new_run()


func test_shop_restocks_on_each_town_load() -> void:
	_game().new_run()
	var town := await _spawn("res://world/town.tscn")
	T.eq(town.shop.stock.size(), Shop.STOCK_SIZE)
	town.free()
	_game().new_run()


func test_shop_panel_buy_and_sell() -> void:
	_game().new_run()
	_game().run.add_gold(500)
	var town := await _spawn("res://world/town.tscn")
	var first: StringName = town.shop.stock[0]
	var price: int = ItemDB.get_def(first)["buy"]
	var p := town.open_panel(&"shop") as ShopPanel
	p._buy(0)
	T.eq(_game().run.items, [first] as Array[StringName], "bought")
	T.eq(_game().run.gold, 500 - price)
	p._sell(0)
	T.eq(_game().run.items.size(), 1, "first press only asks")
	p._sell(0)
	T.eq(_game().run.items.size(), 0, "sold")
	T.eq(_game().run.gold, 500 - price + int(ItemDB.get_def(first)["sell"]))
	p.close()
	town.free()
	_game().new_run()


func test_smith_trade_button_needs_two_items() -> void:
	_game().new_run()
	_game().run.add_item(&"fang")
	var town := await _spawn("res://world/town.tscn")
	var p := town.open_panel(&"smith") as SmithPanel
	T.eq(p.trade_button.disabled, true, "one item: no trade")
	p.close()
	_game().run.add_item(&"spark")
	p = town.open_panel(&"smith") as SmithPanel
	p._toggle(true, 0)
	p._toggle(true, 1)
	T.eq(p.trade_button.disabled, false, "two picked: trade")
	p._trade()
	T.eq(_game().run.items.size(), 1, "2 for 1")
	T.ok(_game().run.items[0] != &"fang" and _game().run.items[0] != &"spark", "new item differs")
	p.close()
	town.free()
	_game().new_run()


func test_game_over_reads_last_run() -> void:
	_game().new_run()
	var last: Dictionary[String, Variant] = {"floor": 2, "seconds": 125.0, "gold": 77}
	_game().last_run = last
	var s := await _spawn("res://ui/game_over.tscn")
	T.eq(s.summary_label.text, "Andar: 2\nTempo: 02:05\nOuro: 77")
	s.free()
	(_game().last_run as Dictionary).clear()


func test_hud_shows_blocked_message_and_boss_bar() -> void:
	_game().new_run()
	var d := await _spawn("res://world/dungeon.tscn") as Dungeon
	var hud := d.get_node("Hud") as Hud
	await _tree().process_frame
	T.eq(hud.player, d.player, "HUD found the player")
	d.player.exit_blocked.emit()
	T.eq(hud.blocked_label.visible, true)
	T.eq(hud.blocked_label.text, "Não dá para sair durante o chefe")
	d.player.exit_progress.emit(0.5)
	T.eq(hud.exit_box.visible, true, "exit bar while channeling")
	d.player.exit_progress.emit(0.0)
	T.eq(hud.exit_box.visible, false)
	T.eq(hud.boss_box.visible, false, "no boss, no bar")
	var boss := FakeBoss.new()
	d.add_child(boss)
	await _tree().process_frame
	T.eq(hud.boss_box.visible, true, "boss bar shows")
	boss.boss_hp.emit(30, 120)
	T.eq(hud.boss_hp, 30)
	T.eq(hud.boss_max, 120)
	boss.free()
	await _tree().process_frame
	T.eq(hud.boss_box.visible, false, "bar hides when the boss is gone")
	d.leave_to_town()
	d.free()
	await _tree().process_frame
	await _tree().process_frame
	var cur := _tree().current_scene
	if cur != null and cur.scene_file_path == Dungeon.TOWN_SCENE:
		cur.free()
	_game().new_run()


class FakeBoss extends Node:
	signal boss_hp(hp: int, max_hp: int)

	func _ready() -> void:
		add_to_group(&"boss")
