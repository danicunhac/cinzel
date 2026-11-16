class_name PauseMenu
extends CanvasLayer
## Esc toggles pause (get_tree().paused). process_mode ALWAYS. Ignores Esc
## while another pause owner (a town panel, the swap panel) holds the tree.
## "Voltar ao título" and "Fechar o jogo" lose the run (there is no save), so
## each takes a second press.
## It also owns the backpack screen (InventoryScreen): Tab opens it during
## play, "Mochila" opens it from the pause menu. Not while another panel or
## pause holds the tree, after death, or in a boss room before the boss
## falls (no pausing to swap gear mid-fight).
## Debug: `--pause` opens it on start (for screenshots); `--inventory[=slot]`
## opens the backpack with the cursor on that slot; `--offer=<id>` offers an
## item as loot (full-backpack choice when the backpack is full);
## `--loot=<id>:<qty>,...` takes loot one item every few frames (toasts).

const TITLE_SCENE := "res://ui/title.tscn"
const CONTROLS := "WASD: mover   J ou clique: atacar\nEspaço: rolar   E: interagir\nTab: mochila   Q (segurar): sair"
const CONFIRM_TEXT := "Confirmar: a run se perde"
const TITLE_TEXT := "Voltar ao título"
const QUIT_TEXT := "Fechar o jogo"
const BOSS_TEXT := "Agora não: chefe à frente"

var title_button: Button
var quit_button: Button
var bag_button: Button
## The backpack screen while it is open.
var inventory: InventoryScreen = null
var _root: Control
var _continue: Button
var _armed: Button = null
var _frame: Control


func _ready() -> void:
	_build()
	_root.visible = false
	for a in OS.get_cmdline_user_args():
		if a == "--pause":
			open.call_deferred()
		elif a.begins_with("--inventory"):
			_debug_inventory.call_deferred(int(a.substr(12)) if a.length() > 12 else -1)
		elif a.begins_with("--offer="):
			_debug_offer.call_deferred(StringName(a.substr(8)))
		elif a.begins_with("--loot="):
			_debug_loot.call_deferred(a.substr(7))


func is_open() -> bool:
	return _root.visible


func open() -> void:
	if is_open():
		return
	UiKit.ensure_wasd_ui()
	_root.visible = true
	UiKit.slide_in(_frame, UiKit.SLIDE_PANEL)
	bag_button.disabled = Game.in_boss_room and not is_in_town()
	get_tree().paused = true
	_continue.grab_focus.call_deferred()


func close() -> void:
	if not is_open():
		return
	_root.visible = false
	_disarm()
	# The key that pressed "Continuar" (Space) must not also roll the player.
	UiKit.block_gameplay_input()
	get_tree().paused = false


## Why the backpack cannot open now: "" when it can, BOSS_TEXT in a boss
## fight, "busy" while something else holds the tree or the hero is dead.
func inventory_block_reason() -> String:
	if inventory != null or UiPanel.open_count > 0 or UiPanel.last_closed_frame == Engine.get_process_frames():
		return "busy"
	var p := get_tree().get_first_node_in_group(&"player") as Player
	if p != null and p.state == Player.State.DEAD:
		return "busy"
	if Game.in_boss_room and not is_in_town():
		return BOSS_TEXT
	return ""


func is_in_town() -> bool:
	return not (get_parent() is Dungeon)


## Opens the backpack (from play or from this menu). Returns it, or null
## when it cannot open now (see inventory_block_reason).
func open_inventory() -> InventoryScreen:
	if is_open():
		close()
	var why := inventory_block_reason()
	if why != "":
		if why == BOSS_TEXT:
			Game.toast(why)
		return null
	inventory = InventoryScreen.new()
	inventory.in_town = is_in_town()
	inventory.closed.connect(func() -> void: inventory = null)
	get_parent().add_child(inventory)
	inventory.open()
	return inventory


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"inventory") and not is_open() and not get_tree().paused:
		get_viewport().set_input_as_handled()
		open_inventory()
		return
	if not event.is_action_pressed(&"pause"):
		if is_open() and event.is_action_pressed(&"ui_cancel"):
			get_viewport().set_input_as_handled()
			close()
		return
	if is_open():
		get_viewport().set_input_as_handled()
		close()
	elif not get_tree().paused and UiPanel.open_count == 0 \
			and UiPanel.last_closed_frame != Engine.get_process_frames():
		get_viewport().set_input_as_handled()
		open()


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.02, 0.04, 0.7)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)
	var box := UiKit.centred_frame(_root, Vector2(200, 0), "Pausa")
	_frame = CinzelLogo.frame_of(box)
	CinzelLogo.above_frame(_frame, CinzelLogo.MEDIUM)
	_continue = _add_button(box, "Continuar")
	_continue.pressed.connect(close)
	bag_button = _add_button(box, "Mochila")
	bag_button.pressed.connect(open_inventory)
	title_button = _add_button(box, TITLE_TEXT)
	title_button.pressed.connect(_on_title)
	quit_button = _add_button(box, QUIT_TEXT)
	quit_button.pressed.connect(_on_quit)
	box.add_child(Sfx.volume_row("Música", Sfx.MUSIC_BUS))
	box.add_child(Sfx.volume_row("Efeitos", Sfx.SFX_BUS))
	box.add_child(UiKit.label(CONTROLS, UiKit.COLOR_MUTED, HORIZONTAL_ALIGNMENT_CENTER))


func _add_button(box: VBoxContainer, text: String) -> Button:
	var b := UiKit.button(text)
	b.alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(b)
	return b


## First press arms the button (asks to confirm); the second runs it.
func _confirm(b: Button) -> bool:
	if _armed == b:
		return true
	_disarm()
	_armed = b
	b.text = CONFIRM_TEXT
	return false


func _disarm() -> void:
	_armed = null
	title_button.text = TITLE_TEXT
	quit_button.text = QUIT_TEXT


func _on_title() -> void:
	if not _confirm(title_button):
		return
	close()
	Game.new_run()
	Game.goto(TITLE_SCENE)


func _on_quit() -> void:
	if _confirm(quit_button):
		Sfx.quit_clean()


func _debug_inventory(slot: int) -> void:
	for i in 4:
		await get_tree().process_frame
	var inv := open_inventory()
	if inv != null and slot >= 0:
		inv.select_bag(slot)
		inv._grab.call_deferred(inv.bag_cells[slot])


func _debug_offer(id: StringName) -> void:
	for i in 4:
		await get_tree().process_frame
	Game.offer_item(id)


func _debug_loot(list: String) -> void:
	for part in list.split(",", false):
		for i in 6:
			await get_tree().process_frame
		var kv := part.split(":")
		Game.run.take_loot(StringName(kv[0]), int(kv[1]) if kv.size() > 1 else 1)
