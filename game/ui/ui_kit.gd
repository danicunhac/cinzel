class_name UiKit
extends RefCounted
## Shared helpers for the HUD, panels and screens (480x270 base resolution).

## Base resolution (project.godot viewport); every screen is laid out on it.
const SCREEN := Vector2(480, 270)
const PANEL_TEX := preload("res://assets/ui/panel.png")
const SLOT_TEX := preload("res://assets/ui/slot.png")
const PANEL_MARGIN := 4
const SLOT_MARGIN := 3

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


## Bronze frame (9-slice of panel.png) of the given size.
static func frame(size: Vector2) -> NinePatchRect:
	var f := NinePatchRect.new()
	f.texture = PANEL_TEX
	f.patch_margin_left = PANEL_MARGIN
	f.patch_margin_top = PANEL_MARGIN
	f.patch_margin_right = PANEL_MARGIN
	f.patch_margin_bottom = PANEL_MARGIN
	f.size = size
	return f


## Frame centred on the screen, with a margin box for content.
static func centred_frame(parent: Control, size: Vector2) -> VBoxContainer:
	var f := frame(size)
	f.position = ((SCREEN - size) / 2.0).floor()
	parent.add_child(f)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 8)
	f.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	margin.add_child(box)
	return box


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
