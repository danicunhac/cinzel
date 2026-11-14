extends Control
## Credits, then back to the title with a fresh run.

const TITLE_SCENE := "res://ui/title.tscn"
const LINES := "Design e programação: Daniel\nArte: AI generator, preset cinzel-pixel\nFonte: Silkscreen (SIL OFL 1.1)\nMotor: Godot 4"


func _ready() -> void:
	UiKit.ensure_wasd_ui()
	Game.run.clock.running = false
	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.05, 0.08)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var box := UiKit.centred_frame(self, Vector2(240, 120))
	box.add_child(UiKit.label("Créditos", UiKit.COLOR_TITLE, HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(UiKit.label(LINES, Color(0.95, 0.9, 0.82), HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(UiKit.label("Obrigado por jogar!", UiKit.COLOR_ITEM, HORIZONTAL_ALIGNMENT_CENTER))
	var back := UiKit.button("Voltar ao título")
	back.alignment = HORIZONTAL_ALIGNMENT_CENTER
	back.pressed.connect(_back)
	box.add_child(back)
	back.grab_focus.call_deferred()


func _back() -> void:
	Game.new_run()
	Game.goto(TITLE_SCENE)
