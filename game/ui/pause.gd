class_name PauseMenu
extends CanvasLayer
## Esc toggles pause (get_tree().paused). process_mode ALWAYS. Ignores Esc
## while another pause owner (a town panel, the swap panel) holds the tree.
## Debug: `--pause` opens it on start (for screenshots).

const CONTROLS := "WASD: mover   J ou clique: atacar\nEspaço: rolar   E: interagir\nQ (segurar): sair da torre"

var _root: Control
var _continue: Button
var _quit: Button
var _confirm_quit: bool = false


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
	get_tree().paused = false
	_confirm_quit = false
	_quit.text = "Sair do jogo"


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
	var box := UiKit.centred_frame(_root, Vector2(200, 128))
	box.add_child(UiKit.label("Pausa", UiKit.COLOR_TITLE, HORIZONTAL_ALIGNMENT_CENTER))
	_continue = UiKit.button("Continuar")
	_continue.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_continue.pressed.connect(close)
	box.add_child(_continue)
	_quit = UiKit.button("Sair do jogo")
	_quit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_quit.pressed.connect(_on_quit)
	box.add_child(_quit)
	var help := UiKit.label(CONTROLS, UiKit.COLOR_MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	box.add_child(help)


## Quitting loses the run (there is no save), so it takes a second press.
func _on_quit() -> void:
	if _confirm_quit:
		get_tree().quit()
		return
	_confirm_quit = true
	_quit.text = "Confirmar: a run se perde"
