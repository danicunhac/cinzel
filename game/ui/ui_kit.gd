class_name UiKit
extends RefCounted
## Shared helpers for the HUD, panels and screens (480x270 base resolution).

## Base resolution (project.godot viewport); every screen is laid out on it.
const SCREEN := Vector2(480, 270)
const PANEL_TEX := preload("res://assets/ui/hud/panel.png")
const PLAQUE_TEX := preload("res://assets/ui/hud/plaque.png")
const PANEL_MARGIN := 18
const PLAQUE_MARGIN := 4
## Inner padding of a centred frame (its iron edge is 8 px; corners 17 px).
const FRAME_PAD := 12
## Entrance: every HUD element and panel slides in, this long, this far.
const SLIDE_TIME := 0.28
const SLIDE_PANEL := Vector2(0, 18)

const COLOR_TEXT := Color(0.95, 0.9, 0.82)
const COLOR_TITLE := Color(1.0, 0.82, 0.55)
const COLOR_ITEM := Color(1.0, 0.88, 0.3)
const COLOR_GOLD := Color(1.0, 0.8, 0.3)
const COLOR_DANGER := Color(1.0, 0.38, 0.32)
const COLOR_MUTED := Color(0.7, 0.64, 0.6)


## "mm:ss" for the run clock.
static func format_time(seconds: float) -> String:
	var s := maxi(int(seconds), 0)
	return "%02d:%02d" % [s / 60, s % 60]


static func item_icon(id: StringName) -> Texture2D:
	if not ItemDB.has(id):
		return null
	return load(String(ItemDB.get_def(id)["icon"])) as Texture2D


static func item_name(id: StringName) -> String:
	return String(ItemDB.get_def(id)["name"]) if ItemDB.has(id) else ""


## Bronze-and-iron window frame (9-slice of hud/panel.png) of the given size.
static func frame(size: Vector2) -> NinePatchRect:
	var f := NinePatchRect.new()
	f.texture = PANEL_TEX
	f.patch_margin_left = PANEL_MARGIN
	f.patch_margin_top = PANEL_MARGIN
	f.patch_margin_right = PANEL_MARGIN
	f.patch_margin_bottom = PANEL_MARGIN
	f.size = size
	return f


## Dark iron plaque (9-slice of hud/plaque.png): clock block, boss name,
## panel titles.
static func plaque(size: Vector2) -> NinePatchRect:
	var p := NinePatchRect.new()
	p.texture = PLAQUE_TEX
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		p.set_patch_margin(side, PLAQUE_MARGIN)
	p.size = size
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


## Width of a one-line string in the theme font (8 px Silkscreen).
static func text_width(text: String) -> int:
	var font := ThemeDB.get_project_theme().default_font if ThemeDB.get_project_theme() != null else ThemeDB.fallback_font
	return int(ceilf(font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x))


## Plaque with centred text, sized to the text. Returns the plaque.
static func titled_plaque(text: String, color: Color = COLOR_TITLE) -> NinePatchRect:
	var p := plaque(Vector2(text_width(text) + 14, 14))
	var l := label(text, color, HORIZONTAL_ALIGNMENT_CENTER)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.set_anchors_preset(Control.PRESET_FULL_RECT)
	l.offset_top = -1
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(l)
	return p


## Frame centred on the screen, with a margin box for content. A title sits
## on a plaque across the top edge. The frame slides in (the one entrance).
static func centred_frame(parent: Control, size: Vector2, title: String = "", title_color: Color = COLOR_TITLE) -> VBoxContainer:
	var f := frame(size)
	f.position = ((SCREEN - size) / 2.0).floor()
	parent.add_child(f)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, FRAME_PAD)
	if title != "":
		margin.add_theme_constant_override("margin_top", FRAME_PAD + 3)
	f.add_child(margin)
	if title != "":
		var p := titled_plaque(title, title_color)
		p.position = Vector2(floorf((f.size.x - p.size.x) / 2.0), -6)
		p.name = "Title"
		f.add_child(p)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	margin.add_child(box)
	margin.minimum_size_changed.connect(_fit_frame.bind(f, margin, size))
	_fit_frame(f, margin, size)
	slide_in(f, SLIDE_PANEL)
	return box


## Grows a centred frame to its content (never below `base`) and keeps it
## centred, so taller buttons or a longer list never spill over the edge.
static func _fit_frame(f: NinePatchRect, margin: MarginContainer, base: Vector2) -> void:
	var need := base.max(margin.get_combined_minimum_size()).ceil()
	if need == f.size:
		return
	f.size = need
	var title := f.get_node_or_null(^"Title") as Control
	if title != null:
		title.position.x = floorf((need.x - title.size.x) / 2.0)
	var home := ((SCREEN - need) / 2.0).floor()
	var sliding := false
	if f.has_meta(&"slide_tween"):
		var t := f.get_meta(&"slide_tween") as Tween
		sliding = t != null and t.is_valid() and t.is_running()
	if f.has_meta(&"slide_home"):
		f.set_meta(&"slide_home", home)
	if not sliding:
		f.position = home


static func label(text: String, color: Color = Color(0.95, 0.9, 0.82), align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = align
	l.add_theme_color_override("font_color", color)
	return l


static func button(text: String, icon: Texture2D = null) -> Button:
	var b := Button.new()
	b.text = text
	b.icon = icon
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.focus_mode = Control.FOCUS_ALL
	return b


## The one entrance: the control slides from `offset` away to where it is
## now, on whole pixels, easing out. Runs while the tree is paused.
## Calling it again replays the slide toward the same resting place.
static func slide_in(c: Control, offset: Vector2, delay: float = 0.0) -> Tween:
	if not c.has_meta(&"slide_home"):
		c.set_meta(&"slide_home", c.position)
	var target: Vector2 = c.get_meta(&"slide_home")
	if c.has_meta(&"slide_tween"):
		var old := c.get_meta(&"slide_tween") as Tween
		if old != null and old.is_valid():
			old.kill()
	c.position = target + offset
	var t := c.create_tween()
	c.set_meta(&"slide_tween", t)
	t.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	# Reads the home each step: _fit_frame may move it mid-slide.
	t.tween_method(func(k: float) -> void:
			c.position = ((c.get_meta(&"slide_home") as Vector2) + offset * (1.0 - k)).round(),
			0.0, 1.0, SLIDE_TIME).set_delay(delay).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	return t


## Lets WASD drive menus too (the built-in ui_* actions only have arrows).
static func ensure_wasd_ui() -> void:
	var pairs := {&"ui_up": KEY_W, &"ui_down": KEY_S, &"ui_left": KEY_A, &"ui_right": KEY_D}
	for action: StringName in pairs:
		var key: Key = pairs[action]
		var has := false
		for e in InputMap.action_get_events(action):
			if e is InputEventKey and (e as InputEventKey).physical_keycode == key:
				has = true
		if not has:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			InputMap.action_add_event(action, ev)


## Last physics frame on which the player ignores just-pressed actions.
static var _input_blocked_until: int = -1


## Called when a menu closes and unpauses. A key pressed outside a physics
## step counts as just pressed on the next one (even if released), so Space
## on "Fechar" would also roll; block that next physics frame.
static func block_gameplay_input() -> void:
	_input_blocked_until = Engine.get_physics_frames() + 1


static func gameplay_input_blocked() -> bool:
	return Engine.get_physics_frames() <= _input_blocked_until


## Debug for screenshots: `--last-run=floor,seconds,gold` seeds Game.last_run.
static func apply_debug_last_run() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--last-run="):
			var v := a.substr(11).split(",")
			if v.size() == 3:
				var last: Dictionary[String, Variant] = {
					"floor": int(v[0]), "seconds": float(v[1]), "gold": int(v[2])}
				Game.last_run = last
