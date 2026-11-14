extends Control
## Title screen: a night scene in layers around the key art (fog, torch
## glows, embers, the climber on a parapet looking up at the tower), the
## CINZEL logo dropping in, then the menu. New run → town.
## The title is the one screen with ambient motion (docs/gdd.md);
## the logo and the menu enter with the UiKit slide.
## Debug: `--title-focus=N` focuses button N once the menu is in (screenshots).

const BG := preload("res://assets/ui/title_bg.png")
const PARAPET := preload("res://assets/ui/title/parapet.png")
const FOG := preload("res://assets/ui/title/fog.png")
const GLOW := preload("res://assets/ui/title/glow.png")
const TOWN_SCENE := "res://world/town.tscn"
const CREDITS_SCENE := "res://ui/credits.tscn"
const TAGLINE := "Uma torre. Um relógio.\nNenhuma segunda chance."
const HELP := "WASD mover  J atacar  Espaço rolar  E interagir"

## Left column (logo and menu) width; the tower fills the right side.
const COLUMN_W := 252.0
const LOGO_HOME := Vector2(6, 18)
const LOGO_DROP_FROM := -72.0
const LOGO_DROP_TIME := 0.42
const BUTTON_W := 112.0
const BUTTON_TOP := 118.0
const BUTTON_STEP := 21.0
## Parallax: px of travel per layer at full mouse offset (0 = fixed).
const DEPTH_FOG_FAR := 2.0
const DEPTH_EMBERS := 3.0
const DEPTH_FOG_NEAR := 4.0
const DEPTH_PARAPET := 7.0
## Where the light sits in title_bg (tower top, windows, torches, lamps).
const TOWER_TOP := Vector2(334, 2)
const LIGHTS: Array[Vector2] = [
	Vector2(362, 68), Vector2(268, 152), Vector2(388, 101),
	Vector2(258, 219), Vector2(320, 236), Vector2(404, 214),
]

var buttons: Array[Button] = []

var _logo: TextureRect
var _logo_glow: TextureRect
var _logo_tween: Tween
var _menu_in: bool = false
var _tagline: Label
var _cursor: Sprite2D
var _burst: CPUParticles2D
var _parallax: Array[Dictionary] = []
var _fogs: Array[Dictionary] = []
var _flicker: Array[Sprite2D] = []
var _tower_glow: Sprite2D
var _time: float = 0.0
var _mouse_seen: bool = false
var _look := Vector2.ZERO
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	UiKit.ensure_wasd_ui()
	Sfx.music(&"town")
	if Game.run != null:
		Game.run.clock.running = false
	_build_scene()
	_build_ui()
	_drop_logo()


# --- Scene -----------------------------------------------------------------

func _build_scene() -> void:
	var bg := TextureRect.new()
	bg.texture = BG
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.size = UiKit.SCREEN
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var lights := Node2D.new()
	add_child(lights)
	_tower_glow = _glow(lights, TOWER_TOP, 3.0)
	for p in LIGHTS:
		_flicker.append(_glow(lights, p, 1.0))

	_add_fog(150.0, DEPTH_FOG_FAR, 5.0, 0.8)
	_add_embers()
	_add_fog(222.0, DEPTH_FOG_NEAR, -8.0, 0.55)

	# Shade under the left column so the logo and menu read on the sky.
	var shade := TextureRect.new()
	var grad := GradientTexture2D.new()
	grad.width = int(COLUMN_W) + 60
	grad.height = 1
	grad.gradient = Gradient.new()
	grad.gradient.set_color(0, Color(0.04, 0.03, 0.08, 0.62))
	grad.gradient.set_color(1, Color(0.04, 0.03, 0.08, 0.0))
	grad.gradient.add_point(0.7, Color(0.04, 0.03, 0.08, 0.45))
	shade.texture = grad
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.size = Vector2(COLUMN_W + 60, UiKit.SCREEN.y)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)

	# Foreground: a parapet and the climber looking up at the tower (x2, a
	# step nearer than the town), drawn a little dark against the torchlight.
	var fg := Node2D.new()
	add_child(fg)
	_parallax.append({"node": fg, "home": Vector2.ZERO, "depth": DEPTH_PARAPET})
	var parapet := Sprite2D.new()
	parapet.texture = PARAPET
	parapet.centered = false
	parapet.position = Vector2(-8, UiKit.SCREEN.y - PARAPET.get_height())
	fg.add_child(parapet)
	var hero := LayeredSprite.new()
	hero.name = "Hero"
	hero.scale = Vector2(2, 2)
	# Feet (row 30 of a centred 32 px frame) on top of a merlon (y 240).
	hero.position = Vector2(224, 242 - (LayeredSprite.FEET_ROW - 16) * 2)
	hero.modulate = Color(0.58, 0.5, 0.62)
	fg.add_child(hero)
	hero.play(&"idle", Vector2.UP)


func _glow(parent: Node2D, at: Vector2, size: float) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = GLOW
	s.position = at
	s.scale = Vector2(size, size)
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	s.material = mat
	parent.add_child(s)
	return s


func _add_fog(y: float, depth: float, speed: float, alpha: float) -> void:
	var layer := Node2D.new()
	layer.modulate.a = alpha
	add_child(layer)
	var w := float(FOG.get_width())
	for i in 2:
		var s := Sprite2D.new()
		s.texture = FOG
		s.centered = false
		s.position = Vector2(i * w, 0)
		layer.add_child(s)
	_parallax.append({"node": layer, "home": Vector2(-16, y), "depth": depth})
	_fogs.append({"node": layer, "speed": speed, "x": 0.0, "w": w})


func _add_embers() -> void:
	var layer := Node2D.new()
	add_child(layer)
	_parallax.append({"node": layer, "home": Vector2.ZERO, "depth": DEPTH_EMBERS})
	# Rising from the town around the tower foot, drifting with the wind.
	var e := _embers(110, 3.6)
	e.position = Vector2(330, 262)
	e.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	e.emission_rect_extents = Vector2(110, 6)
	e.direction = Vector2(0.25, -1)
	e.spread = 18.0
	e.initial_velocity_min = 14.0
	e.initial_velocity_max = 30.0
	layer.add_child(e)
	# A few sparks off the tower torches, higher up.
	var t := _embers(18, 2.4)
	t.position = Vector2(330, 120)
	t.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	t.emission_rect_extents = Vector2(66, 40)
	t.direction = Vector2(0.4, -1)
	t.spread = 25.0
	t.initial_velocity_min = 6.0
	t.initial_velocity_max = 14.0
	layer.add_child(t)


func _embers(amount: int, life: float) -> CPUParticles2D:
	var e := CPUParticles2D.new()
	e.amount = amount
	e.lifetime = life
	e.preprocess = life
	e.gravity = Vector2(4, -3)
	e.scale_amount_min = 1.0
	e.scale_amount_max = 2.0
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.86, 0.5, 1.0))
	ramp.set_color(1, Color(0.8, 0.25, 0.12, 0.0))
	ramp.add_point(0.4, Color(1.0, 0.55, 0.2, 0.9))
	e.color_ramp = ramp
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	e.material = mat
	return e


# --- UI --------------------------------------------------------------------

func _build_ui() -> void:
	_logo_glow = CinzelLogo.rect(CinzelLogo.LARGE_GLOW)
	_logo_glow.name = "LogoGlow"
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_logo_glow.material = add
	_logo_glow.modulate.a = 0.0
	add_child(_logo_glow)
	_logo = CinzelLogo.rect(CinzelLogo.LARGE)
	add_child(_logo)

	_burst = _embers(36, 0.9)
	_burst.preprocess = 0.0
	_burst.one_shot = true
	_burst.explosiveness = 1.0
	_burst.emitting = false
	_burst.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_burst.emission_rect_extents = Vector2(110, 2)
	_burst.direction = Vector2(0, -1)
	_burst.spread = 70.0
	_burst.initial_velocity_min = 20.0
	_burst.initial_velocity_max = 55.0
	_burst.gravity = Vector2(0, 40)
	_burst.position = LOGO_HOME + Vector2(120, CinzelLogo.LARGE.get_height() - 4)
	add_child(_burst)

	_tagline = UiKit.label(TAGLINE, UiKit.COLOR_TITLE, HORIZONTAL_ALIGNMENT_CENTER)
	_tagline.position = Vector2(0, LOGO_HOME.y + CinzelLogo.LARGE.get_height() + 8)
	_tagline.size = Vector2(COLUMN_W, 20)
	_tagline.visible = false
	add_child(_tagline)

	_cursor = Sprite2D.new()
	_cursor.texture = GLOW
	_cursor.scale = Vector2(0.5, 0.5)
	var cm := CanvasItemMaterial.new()
	cm.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_cursor.material = cm
	_cursor.visible = false
	add_child(_cursor)

	_add_button("Novo jogo", _new_game)
	_add_button("Créditos", func() -> void: Game.goto(CREDITS_SCENE))
	_add_button("Sair", func() -> void: Sfx.quit_clean())
	for i in buttons.size():
		var b := buttons[i]
		b.focus_neighbor_top = b.get_path_to(buttons[(i - 1 + buttons.size()) % buttons.size()])
		b.focus_neighbor_bottom = b.get_path_to(buttons[(i + 1) % buttons.size()])

	var help := UiKit.label(HELP, UiKit.COLOR_MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	help.position = Vector2(0, UiKit.SCREEN.y - 13)
	help.size = Vector2(UiKit.SCREEN.x, 10)
	add_child(help)


func _add_button(text: String, action: Callable) -> void:
	var b := UiKit.button(text)
	b.alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.custom_minimum_size = Vector2(BUTTON_W, 0)
	b.size = Vector2(BUTTON_W, 0)
	b.position = Vector2(floorf((COLUMN_W - BUTTON_W) / 2.0), BUTTON_TOP + buttons.size() * BUTTON_STEP)
	b.visible = false
	b.pressed.connect(func() -> void:
		_sfx(&"ui_confirm")
		action.call())
	b.focus_entered.connect(_on_focus.bind(b))
	b.mouse_entered.connect(func() -> void:
		if _menu_in:
			b.grab_focus())
	add_child(b)
	buttons.append(b)


## The ember cursor slides to the focused button.
func _on_focus(b: Button) -> void:
	_sfx(&"ui_move")
	var at := b.get_meta(&"slide_home", b.position) as Vector2 + Vector2(-5, b.size.y / 2.0)
	if not _cursor.visible:
		_cursor.position = at
		_cursor.visible = true
	var ct := _cursor.create_tween()
	ct.tween_property(_cursor, "position", at, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## Logo falls from above the screen (the slide, with weight), lands with a
## small shake of the logo and a burst of embers, then the menu slides in.
func _drop_logo() -> void:
	_logo.position = Vector2(LOGO_HOME.x, LOGO_DROP_FROM)
	_logo_tween = create_tween()
	_logo_tween.tween_interval(0.25)
	_logo_tween.tween_property(_logo, "position:y", LOGO_HOME.y, LOGO_DROP_TIME) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_logo_tween.tween_callback(_land_logo)
	for k in [Vector2(0, 2), Vector2(-2, -1), Vector2(1, 1), Vector2(-1, 0), Vector2.ZERO]:
		_logo_tween.tween_property(_logo, "position", LOGO_HOME + k, 0.035)
	_logo_tween.tween_callback(_show_menu)


func _land_logo() -> void:
	_sfx(&"logo_land")
	_burst.restart()
	_burst.emitting = true
	_logo_glow.modulate.a = 1.0


func _show_menu() -> void:
	if _menu_in:
		return
	_menu_in = true
	_logo.position = LOGO_HOME
	_tagline.visible = true
	UiKit.slide_in(_tagline, Vector2(0, 8))
	for i in buttons.size():
		buttons[i].visible = true
		UiKit.slide_in(buttons[i], Vector2(0, 12), 0.06 * (i + 1))
	var focus := 0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--title-focus="):
			focus = clampi(int(a.substr(14)), 0, buttons.size() - 1)
	buttons[focus].grab_focus.call_deferred()


## Any key or click during the drop skips to the menu.
func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_mouse_seen = true
		return
	if _menu_in or not event.is_pressed():
		return
	if event is InputEventKey or event is InputEventMouseButton:
		get_viewport().set_input_as_handled()
		if _logo_tween != null:
			_logo_tween.kill()
		_logo_glow.modulate.a = 1.0
		_show_menu()


func _process(delta: float) -> void:
	_time += delta
	# Parallax target: the mouse when it has moved, else a slow idle sway.
	var target := Vector2(sin(_time * 0.31), sin(_time * 0.23) * 0.4)
	if _mouse_seen:
		target = ((get_local_mouse_position() - UiKit.SCREEN / 2.0) / (UiKit.SCREEN / 2.0)).clampf(-1.0, 1.0)
	_look = _look.lerp(target, minf(delta * 2.0, 1.0))
	for p in _parallax:
		(p["node"] as Node2D).position = ((p["home"] as Vector2) - _look * float(p["depth"])).round()
	for f in _fogs:
		f["x"] = fposmod(float(f["x"]) + float(f["speed"]) * delta, float(f["w"]))
		var n := f["node"] as Node2D
		n.position.x = roundf(n.position.x - float(f["x"]))
	# Tower top breathes slowly; torches flicker.
	_tower_glow.modulate.a = 0.35 + 0.15 * sin(_time * 1.7)
	for s in _flicker:
		if _rng.randf() < 0.18:
			s.modulate.a = _rng.randf_range(0.55, 1.0)
	# Logo: after the landing flash, a slow warm glow.
	if _menu_in:
		var idle := 0.3 + 0.15 * sin(_time * 2.1)
		_logo_glow.modulate.a = move_toward(_logo_glow.modulate.a, idle, delta * 1.5)
	_logo_glow.position = _logo.position - Vector2(CinzelLogo.GLOW_PAD, CinzelLogo.GLOW_PAD)


func _new_game() -> void:
	Game.new_run()
	Game.goto(TOWN_SCENE)


## Sound hook: plays through an `Sfx` autoload when the project has one.
func _sfx(id: StringName) -> void:
	var sfx := get_node_or_null(^"/root/Sfx")
	if sfx != null and sfx.has_method(&"play"):
		sfx.call(&"play", id)
