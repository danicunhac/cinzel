extends Control
## Title screen: new run → town.

const BG := preload("res://assets/ui/title_bg.png")
const TOWN_SCENE := "res://world/town.tscn"


func _ready() -> void:
	UiKit.ensure_wasd_ui()
	if Game.run != null:
		Game.run.clock.running = false
	var bg := TextureRect.new()
	bg.texture = BG
	add_child(bg)
	var shade := ColorRect.new()
	shade.color = Color(0.04, 0.03, 0.08, 0.55)
	shade.position = Vector2(0, 0)
	shade.size = Vector2(160, 180)
	add_child(shade)

	var title := UiKit.label("Cinzel", UiKit.COLOR_TITLE, HORIZONTAL_ALIGNMENT_CENTER)
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_constant_override("outline_size", 4)
	title.position = Vector2(0, 26)
	title.size = Vector2(160, 30)
	add_child(title)
	var sub := UiKit.label("Na torre, o que custa\ncaro é o tempo.", UiKit.COLOR_MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	sub.position = Vector2(0, 58)
	sub.size = Vector2(160, 20)
	add_child(sub)

	var box := VBoxContainer.new()
	box.position = Vector2(40, 92)
	box.size = Vector2(80, 0)
	box.add_theme_constant_override("separation", 4)
	add_child(box)
	var start := UiKit.button("Novo jogo")
	start.alignment = HORIZONTAL_ALIGNMENT_CENTER
	start.pressed.connect(_new_game)
	box.add_child(start)
	var quit := UiKit.button("Sair")
	quit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	quit.pressed.connect(func() -> void: get_tree().quit())
	box.add_child(quit)
	start.grab_focus.call_deferred()

	var help := UiKit.label("WASD mover  J atacar\nEspaço rolar  E interagir", UiKit.COLOR_MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	help.position = Vector2(0, 150)
	help.size = Vector2(160, 20)
	add_child(help)


func _new_game() -> void:
	Game.new_run()
	Game.goto(TOWN_SCENE)
