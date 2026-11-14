extends Control
## Title screen: new run → town.

const BG := preload("res://assets/ui/title_bg.png")
const TOWN_SCENE := "res://world/town.tscn"


func _ready() -> void:
	UiKit.ensure_wasd_ui()
	if Game.run != null:
		Game.run.clock.running = false
	# The key art fills the screen whatever its size (320x180 art is drawn
	# at x1.5 until a 480x270 version exists).
	var bg := TextureRect.new()
	bg.texture = BG
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.position = Vector2.ZERO
	bg.size = UiKit.SCREEN
	add_child(bg)
	# Left half: shaded column with the title and the menu.
	var col_w := UiKit.SCREEN.x / 2.0
	var shade := ColorRect.new()
	shade.color = Color(0.04, 0.03, 0.08, 0.55)
	shade.position = Vector2(0, 0)
	shade.size = Vector2(col_w, UiKit.SCREEN.y)
	add_child(shade)

	var title := UiKit.label("Cinzel", UiKit.COLOR_TITLE, HORIZONTAL_ALIGNMENT_CENTER)
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_constant_override("outline_size", 6)
	title.position = Vector2(0, 40)
	title.size = Vector2(col_w, 40)
	add_child(title)
	var sub := UiKit.label("Na torre, o que custa\ncaro é o tempo.", UiKit.COLOR_MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	sub.position = Vector2(0, 88)
	sub.size = Vector2(col_w, 20)
	add_child(sub)

	var box := VBoxContainer.new()
	box.position = Vector2(roundf(col_w / 2.0) - 50, 138)
	box.size = Vector2(100, 0)
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
	help.position = Vector2(0, 228)
	help.size = Vector2(col_w, 20)
	add_child(help)


func _new_game() -> void:
	Game.new_run()
	Game.goto(TOWN_SCENE)
