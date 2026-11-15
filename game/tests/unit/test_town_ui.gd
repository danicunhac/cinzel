extends RefCounted
## Town panels, HUD and end screens.

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
	for i in 3:
		T.eq(p.floor_buttons[i].disabled, false, "floor %d is built" % (i + 1))
		T.eq(p.floor_buttons[i].text, "Andar %d" % (i + 1))
	p.travel = false
	var chosen: Array[int] = []
	p.floor_chosen.connect(func(n: int) -> void: chosen.append(n))
	p.floor_buttons[0].pressed.emit()
	T.eq(chosen, [1] as Array[int])
	T.eq(_tree().paused, false, "choosing closes the panel")
	town.free()
	_game().new_run()


func test_shop_starts_a_market_visit_on_each_town_load() -> void:
	_game().new_run()
	var town := await _spawn("res://world/town.tscn")
	T.eq(town.shop, _game().run.market, "town uses the run's market")
	T.eq(town.shop.stock.size(), Market.STOCK_SIZE)
	T.eq(town.shop.wanted.size(), Market.WANTED_COUNT)
	T.eq(town.shop.visits, 1)
	town.free()
	_game().new_run()


func test_shop_panel_buy_and_sell() -> void:
	_game().new_run()
	_game().run.add_gold(500)
	var town := await _spawn("res://world/town.tscn")
	var first: StringName = town.shop.stock[0]
	var price: int = town.shop.buy_price(first)
	var p := town.open_panel(&"shop") as ShopPanel
	p.select_tab(&"buy")
	p.select_buy(0)
	T.ok(p.buy_selected(), "bought")
	T.eq(_game().run.inventory.count(first), 1, "bought into the backpack")
	T.eq(_game().run.gold, 500 - price, "gold paid")
	T.ok(not town.shop.stock.has(first), "left the stock")
	p.select_tab(&"sell")
	p.select_sell(0)
	var sell: int = town.shop.sell_price(first)
	T.eq(p.sell_selected(), sell)
	T.eq(_game().run.inventory.count(first), 0, "sold")
	T.eq(_game().run.gold, 500 - price + sell)
	T.near(town.shop.factor(first), 1.0 - Market.DECAY_PER_SALE, 0.0001)
	p.close()
	town.free()
	_game().new_run()


func test_smith_forges_unlocked_recipe() -> void:
	_game().new_run()
	var town := await _spawn("res://world/town.tscn")
	var p := town.open_panel(&"smith") as SmithPanel
	T.eq(p.recipe_buttons.size(), Forge.unlocked(0).size(), "start recipes listed")
	var idx := Forge.unlocked(0).find(&"helm_iron")
	p.select(idx)
	T.eq(p.craft_button.disabled, true, "no materials: disabled")
	T.eq(p.reason, "Faltam materiais")
	p.close()
	_game().run.inventory.add(&"mat_iron_ore", 4)
	_game().run.add_gold(35)
	p = town.open_panel(&"smith") as SmithPanel
	p.select(idx)
	T.eq(p.craft_button.disabled, false, "materials and gold: enabled")
	p.craft_button.pressed.emit()
	T.eq(_game().run.inventory.count(&"helm_iron"), 0, "first press only arms")
	p.craft_button.pressed.emit()
	T.eq(_game().run.inventory.count(&"helm_iron"), 1, "forged")
	T.eq(_game().run.inventory.count(&"mat_iron_ore"), 0)
	T.eq(_game().run.gold, 0)
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


func test_space_that_closes_a_panel_does_not_roll() -> void:
	_game().new_run()
	var town := await _spawn("res://world/town.tscn")
	var player := town.get_node("Player") as Player
	await _tree().physics_frame
	var p := town.open_panel(&"teleport") as UiPanel
	# Space is both ui_accept (presses "Fechar") and roll.
	Input.action_press(&"roll")
	p.close()
	T.ok(UiKit.gameplay_input_blocked(), "input blocked right after closing")
	await _tree().physics_frame
	await _tree().physics_frame
	Input.action_release(&"roll")
	T.ok(player.state != Player.State.ROLL, "player did not roll")
	T.ok(not UiKit.gameplay_input_blocked(), "block lasts one physics frame")
	town.free()
	_game().new_run()


func test_pause_title_and_quit_need_two_presses() -> void:
	_game().new_run()
	var town := await _spawn("res://world/town.tscn")
	var pause := town.get_node("Pause") as PauseMenu
	pause.open()
	T.eq(pause.title_button.text, "Voltar ao título")
	T.eq(pause.quit_button.text, "Fechar o jogo")
	pause.quit_button.pressed.emit()
	T.eq(pause.quit_button.text, "Confirmar: a run se perde", "quit armed, not quit")
	pause.title_button.pressed.emit()
	T.eq(pause.quit_button.text, "Fechar o jogo", "arming one disarms the other")
	T.eq(pause.is_open(), true, "first press keeps the menu")
	pause.title_button.pressed.emit()
	T.eq(_tree().paused, false, "leaving unpauses")
	town.free()
	for i in 3:
		await _tree().process_frame
	var cur := _tree().current_scene
	T.ok(cur != null and cur.scene_file_path == "res://ui/title.tscn", "second press goes to the title")
	if cur != null:
		cur.free()
	_game().new_run()


class FakeBoss extends Node:
	signal boss_hp(hp: int, max_hp: int)

	func _ready() -> void:
		add_to_group(&"boss")


func test_walking_back_arrives_at_the_gate_unarmed() -> void:
	_game().new_run()
	_game().town_arrival = &"gate"
	var town := await _spawn("res://world/town.tscn")
	var player := town.get_node("Player") as Player
	T.eq(player.global_position, town.arrival_point(&"gate"), "arrives at the tower entrance")
	T.eq(_game().town_arrival, &"", "arrival is used once")
	T.ok(not player.armed, "no weapon in town")
	await _tree().physics_frame
	Input.action_press(&"attack")
	await _tree().physics_frame
	await _tree().process_frame
	Input.action_release(&"attack")
	T.eq(player.state, Player.State.FREE, "attack does not swing")
	town._update_note(0.0, true)
	T.ok(town._note.visible, "note says there are no weapons in town")
	town.free()
	_game().new_run()


func test_stepping_into_the_gate_opens_the_floor_list() -> void:
	_game().new_run()
	_game().run.unlock_floor(2)
	var town := await _spawn("res://world/town.tscn")
	var player := town.get_node("Player") as Player
	player.global_position = town.gate.get_center()
	await _tree().process_frame
	var p := town._panel as TeleportPanel
	T.ok(p != null, "floor list opens")
	T.eq(p.floor_buttons.size(), 2, "floors 1..2")
	p.close()
	await _tree().process_frame
	T.ok(town._panel == null, "standing still in the gate does not reopen it")
	town.free()
	_game().new_run()


func test_walking_up_the_tower_steps_reaches_the_door() -> void:
	_game().new_run()
	_game().run.unlock_floor(2)
	var town := await _spawn("res://world/town.tscn")
	var player := town.get_node("Player") as Player
	player.global_position = town.arrival_point(&"gate")
	await _tree().physics_frame
	Input.action_press(&"move_up")
	for i in 120:
		await _tree().physics_frame
		if town._panel != null:
			break
	Input.action_release(&"move_up")
	T.ok(town._panel is TeleportPanel, "walked through the door (y %.0f)" % player.global_position.y)
	if town._panel != null:
		town._panel.close()
	town.free()
	_game().new_run()
