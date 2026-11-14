extends Control
## Defeat: floor, time and gold of the run that just ended (Game.last_run,
## written before RunState.die() zeroed the run). The run is already reset.

const TOWN_SCENE := "res://world/town.tscn"

var summary_label: Label


func _ready() -> void:
	UiKit.ensure_wasd_ui()
	Game.run.clock.running = false
	UiKit.apply_debug_last_run()
	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.04, 0.05)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var box := UiKit.centred_frame(self, Vector2(200, 0), "Você caiu", UiKit.COLOR_DANGER)
	CinzelLogo.above_frame(CinzelLogo.frame_of(box), CinzelLogo.SMALL)
	summary_label = UiKit.label(summary_text(Game.last_run), Color(0.95, 0.9, 0.82), HORIZONTAL_ALIGNMENT_CENTER)
	box.add_child(summary_label)
	var lost := UiKit.label("Ouro, itens e andares\nforam perdidos.", UiKit.COLOR_MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	box.add_child(lost)
	var back := UiKit.button("Voltar à cidade")
	back.alignment = HORIZONTAL_ALIGNMENT_CENTER
	back.pressed.connect(_back_to_town)
	box.add_child(back)
	back.grab_focus.call_deferred()


func _back_to_town() -> void:
	Game.goto(TOWN_SCENE)


static func summary_text(last: Dictionary) -> String:
	var floor_num := int(last.get("floor", 1))
	var seconds := float(last.get("seconds", 0.0))
	var gold := int(last.get("gold", 0))
	return "Andar: %d\nTempo: %s\nOuro: %d" % [floor_num, UiKit.format_time(seconds), gold]
