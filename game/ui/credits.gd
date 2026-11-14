extends Control
## Credits, then back to the title with a fresh run.

const TITLE_SCENE := "res://ui/title.tscn"
const LINES := "Design: Daniel\nProgramação: Daniel, com assistência de IA (Claude)\nArte: gerada por IA (preset\ncinzel-pixel); personagem redesenhado\nà mão por Daniel\nFonte: Silkscreen (OFL)\nMotor: Godot 4"


func _ready() -> void:
	UiKit.ensure_wasd_ui()
	Game.run.clock.running = false
	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.05, 0.08)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var box := UiKit.centred_frame(self, Vector2(304, 164))
	box.add_child(UiKit.label("Créditos", UiKit.COLOR_TITLE, HORIZONTAL_ALIGNMENT_CENTER))
	var lines := UiKit.label(LINES, Color(0.95, 0.9, 0.82), HORIZONTAL_ALIGNMENT_CENTER)
	lines.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lines.custom_minimum_size = Vector2(288, 0)
	box.add_child(lines)
	box.add_child(UiKit.label("Obrigado por jogar!", UiKit.COLOR_ITEM, HORIZONTAL_ALIGNMENT_CENTER))
	var back := UiKit.button("Voltar ao título")
	back.alignment = HORIZONTAL_ALIGNMENT_CENTER
	back.pressed.connect(_back)
	box.add_child(back)
	back.grab_focus.call_deferred()


func _back() -> void:
	Game.new_run()
	Game.goto(TITLE_SCENE)
