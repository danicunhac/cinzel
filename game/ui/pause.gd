class_name PauseMenu
extends CanvasLayer
## Esc toggles pause (get_tree().paused). process_mode ALWAYS. Ignores Esc
## while another pause owner (a town panel, the swap panel) holds the tree.
## "Voltar ao título" and "Fechar o jogo" lose the run (there is no save), so
## each takes a second press.
## Debug: `--pause` opens it on start (for screenshots).

const TITLE_SCENE := "res://ui/title.tscn"
const CONTROLS := "WASD: mover   J ou clique: atacar\nEspaço: rolar   E: interagir\nQ (segurar): sair da torre"
const CONFIRM_TEXT := "Confirmar: a run se perde"
const TITLE_TEXT := "Voltar ao título"
const QUIT_TEXT := "Fechar o jogo"

var title_button: Button
var quit_button: Button
var _root: Control
var _continue: Button
var _armed: Button = null


func _ready() -> void:
	_build()
	_root.visible = false
	if "--pause" in OS.get_cmdline_user_args():
		open.call_deferred()


func is_open() -> bool:
	return _root.visible


func open() -> void:
	if is_open():
		return
	UiKit.ensure_wasd_ui()
	_root.visible = true
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


func _unhandled_input(event: InputEvent) -> void:
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
	var box := UiKit.centred_frame(_root, Vector2(200, 148))
	box.add_child(UiKit.label("Pausa", UiKit.COLOR_TITLE, HORIZONTAL_ALIGNMENT_CENTER))
	_continue = _add_button(box, "Continuar")
	_continue.pressed.connect(close)
	title_button = _add_button(box, TITLE_TEXT)
	title_button.pressed.connect(_on_title)
	quit_button = _add_button(box, QUIT_TEXT)
	quit_button.pressed.connect(_on_quit)
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
		get_tree().quit()
