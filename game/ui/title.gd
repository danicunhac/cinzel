extends Control
## Title screen: a night scene in layers around the key art (fog, torch
## glows, embers, the climber on a parapet looking up at the tower), the
## CINZEL logo dropping in, then the menu. New run → town.
## The title is the one screen with ambient motion (docs/gdd.md);
## the logo and the menu enter with the UiKit slide.
## The layout lives in title.tscn (the finished screen, as the editor shows
## it); _ready hides the logo glow, the tagline and the menu for the intro.
## Debug: `--title-focus=N` focuses button N once the menu is in (screenshots).

const TOWN_SCENE := "res://world/town.tscn"
const CREDITS_SCENE := "res://ui/credits.tscn"

const LOGO_DROP_FROM := -72.0
const LOGO_DROP_TIME := 0.42
## Parallax: px of travel per layer at full mouse offset (0 = fixed).
const DEPTH_FOG_FAR := 2.0
const DEPTH_EMBERS := 3.0
const DEPTH_FOG_NEAR := 4.0
const DEPTH_PARAPET := 7.0
## Fog drift, px/s (FogFar, FogNear).
const FOG_FAR_SPEED := 5.0
const FOG_NEAR_SPEED := -8.0

var buttons: Array[Button] = []

var _logo_tween: Tween
var _menu_in: bool = false
## Where the logo rests: its position in title.tscn.
var _logo_home: Vector2
var _parallax: Array[Dictionary] = []
var _fogs: Array[Dictionary] = []
var _flicker: Array[Sprite2D] = []
var _time: float = 0.0
var _mouse_seen: bool = false
var _look := Vector2.ZERO
var _rng := RandomNumberGenerator.new()

@onready var _logo: TextureRect = $Logo
@onready var _logo_glow: TextureRect = $LogoGlow
@onready var _tagline: Label = $Tagline
@onready var _cursor: Sprite2D = $Cursor
@onready var _burst: CPUParticles2D = $Burst
## Tower top glow (breathes); the other Lights flicker.
@onready var _tower_glow: Sprite2D = $Lights/TowerTop


func _ready() -> void:
	UiKit.ensure_wasd_ui()
	Sfx.music(&"town")
	if Game.run != null:
		Game.run.clock.running = false
	_read_scene()
	_read_menu()
	_drop_logo()


# --- Scene -----------------------------------------------------------------

## Parallax layers (home = their place in the scene), fog drift and torch
## glows from title.tscn.
func _read_scene() -> void:
	_add_parallax($FogFar, DEPTH_FOG_FAR)
	_add_parallax($Embers, DEPTH_EMBERS)
	_add_parallax($FogNear, DEPTH_FOG_NEAR)
	_add_parallax($Foreground, DEPTH_PARAPET)
	_add_fog($FogFar, FOG_FAR_SPEED)
	_add_fog($FogNear, FOG_NEAR_SPEED)
	for s: Sprite2D in $Lights.get_children():
		if s != _tower_glow:
			_flicker.append(s)
	($Foreground/Hero as LayeredSprite).play(&"idle", Vector2.UP)


func _add_parallax(layer: Node2D, depth: float) -> void:
	_parallax.append({"node": layer, "home": layer.position, "depth": depth})


## A fog layer holds two copies of the fog strip side by side.
func _add_fog(layer: Node2D, speed: float) -> void:
	var w := float((layer.get_child(0) as Sprite2D).texture.get_width())
	_fogs.append({"node": layer, "speed": speed, "x": 0.0, "w": w})


# --- UI --------------------------------------------------------------------

## Menu buttons (Menu/NewGame, Credits, Quit) and the intro's start state:
## no logo glow, tagline and menu hidden until the logo lands.
func _read_menu() -> void:
	_setup_button($Menu/NewGame, _new_game)
	_setup_button($Menu/Credits, func() -> void: Game.goto(CREDITS_SCENE))
	_setup_button($Menu/Quit, func() -> void: Sfx.quit_clean())
	for i in buttons.size():
		var b := buttons[i]
		b.focus_neighbor_top = b.get_path_to(buttons[(i - 1 + buttons.size()) % buttons.size()])
		b.focus_neighbor_bottom = b.get_path_to(buttons[(i + 1) % buttons.size()])
	_logo_home = _logo.position
	_logo_glow.modulate.a = 0.0
	_tagline.visible = false
	_cursor.visible = false


func _setup_button(b: Button, action: Callable) -> void:
	b.visible = false
	b.pressed.connect(func() -> void:
		_sfx(&"ui_confirm")
		action.call())
	b.focus_entered.connect(_on_focus.bind(b))
	b.mouse_entered.connect(func() -> void:
		if _menu_in:
			b.grab_focus())
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
	_logo.position = Vector2(_logo_home.x, LOGO_DROP_FROM)
	_logo_tween = create_tween()
	_logo_tween.tween_interval(0.25)
	_logo_tween.tween_property(_logo, "position:y", _logo_home.y, LOGO_DROP_TIME) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_logo_tween.tween_callback(_land_logo)
	for k in [Vector2(0, 2), Vector2(-2, -1), Vector2(1, 1), Vector2(-1, 0), Vector2.ZERO]:
		_logo_tween.tween_property(_logo, "position", _logo_home + k, 0.035)
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
	_logo.position = _logo_home
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
