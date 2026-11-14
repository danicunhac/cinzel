extends Control
## Victory: total time of the run (Game.last_run), then the credits.

const CREDITS_SCENE := "res://ui/credits.tscn"

var time_label: Label


func _ready() -> void:
	UiKit.ensure_wasd_ui()
	Game.run.clock.running = false
	UiKit.apply_debug_last_run()
	var bg := ColorRect.new()
	bg.color = Color(0.1, 0.07, 0.05)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var box := UiKit.centred_frame(self, Vector2(200, 112))
	box.add_child(UiKit.label("Vitória!", UiKit.COLOR_ITEM, HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(UiKit.label("O topo da torre é seu.", Color(0.95, 0.9, 0.82), HORIZONTAL_ALIGNMENT_CENTER))
	var seconds := float(Game.last_run.get("seconds", Game.run.clock.seconds))
	time_label = UiKit.label("Tempo total: %s" % UiKit.format_time(seconds), UiKit.COLOR_TITLE, HORIZONTAL_ALIGNMENT_CENTER)
	box.add_child(time_label)
	var next := UiKit.button("Continuar")
	next.alignment = HORIZONTAL_ALIGNMENT_CENTER
	next.pressed.connect(func() -> void: Game.goto(CREDITS_SCENE))
	box.add_child(next)
	next.grab_focus.call_deferred()
