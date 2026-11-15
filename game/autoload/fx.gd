extends Node
## Autoload. Combat feel on one S/M/L ladder (docs/gdd.md,
## feedback): the size of the answer matches the size of the action.
##   S: a common hit, a coin, a step. White flash 0.08 s, hit-stop 3 frames,
##      small burst, no screen shake.
##   M: crit, combo finisher, special, hero hurt, big pickup. Hit-stop 5
##      frames, bigger burst; hero hurt shakes the camera a little.
##   L: boss hit by its own attack, boss or hero death, floor clear. Long
##      hit-stop and a real shake.
## Every effect runs on real time (ignores Engine.time_scale), so a hit-stop
## never stretches the effect that came with it.

const S := 0
const M := 1
const L := 2
## Hit-stop frames per level (60 fps frames).
const STOP_FRAMES: Array[int] = [3, 5, 8]
## Time scale while a hit-stop holds (near zero keeps physics stepping).
const STOP_SCALE := 0.02
const FLASH_WHITE := Color(3.0, 3.0, 3.0)
const FLASH_CRIT := Color(3.0, 2.4, 0.8)
const FLASH_HURT := Color(2.6, 0.55, 0.5)
const FLASH_TIME := 0.08
const HURT_FLASH_TIME := 0.1
## Damage numbers: font size (pixel font, multiple of 8), time on screen
## and how far they rise. Big enough to read over a 24 px enemy.
const NUMBER_SIZE := 16
const NUMBER_LIFE := 0.9
const NUMBER_RISE := 16.0
const COIN_TEX := preload("res://assets/ui/hud/coin.png")
const COIN_FRAME := Vector2(9, 9)
const COIN_FLY_TIME := 0.4

## Burst presets: amount, lifetime, speed range, colour, size range, gravity,
## spread (deg), additive (white sparks) or plain (dust), emission radius.
const BURSTS: Dictionary[StringName, Dictionary] = {
	&"hit": {"amount": 6, "life": 0.18, "speed": Vector2(40, 75), "color": Color(1, 1, 1), "size": Vector2(1, 2), "add": true},
	&"crit": {"amount": 12, "life": 0.26, "speed": Vector2(60, 115), "color": Color(1.0, 0.85, 0.35), "size": Vector2(1, 2), "add": true},
	&"enemy_die": {"amount": 14, "life": 0.45, "speed": Vector2(15, 45), "color": Color(0.62, 0.56, 0.5, 0.85), "size": Vector2(1, 3), "gravity": Vector2(0, -20), "radius": 5.0},
	&"heal": {"amount": 8, "life": 0.6, "speed": Vector2(5, 15), "color": Color(0.75, 1.0, 0.45), "size": Vector2(1, 1), "gravity": Vector2(0, -40), "radius": 6.0, "add": true},
	&"coin": {"amount": 8, "life": 0.3, "speed": Vector2(25, 50), "color": Color(1.0, 0.85, 0.3), "size": Vector2(1, 1), "add": true},
	&"teleport": {"amount": 24, "life": 0.6, "speed": Vector2(10, 30), "color": Color(0.55, 0.9, 1.0), "size": Vector2(1, 2), "gravity": Vector2(0, -60), "radius": 10.0, "add": true},
	&"roll_dust": {"amount": 6, "life": 0.35, "speed": Vector2(10, 25), "color": Color(0.6, 0.55, 0.5, 0.7), "size": Vector2(1, 2), "gravity": Vector2(0, -10), "radius": 3.0},
	&"step_dust": {"amount": 3, "life": 0.3, "speed": Vector2(6, 14), "color": Color(0.6, 0.55, 0.5, 0.55), "size": Vector2(1, 1), "gravity": Vector2(0, -8), "radius": 2.0},
	&"chest_open": {"amount": 16, "life": 0.55, "speed": Vector2(30, 60), "color": Color(1.0, 0.85, 0.35), "size": Vector2(1, 2), "gravity": Vector2(0, 40), "spread": 60.0, "dir": Vector2.UP, "add": true},
	&"turn_dust": {"amount": 4, "life": 0.28, "speed": Vector2(8, 16), "color": Color(0.6, 0.55, 0.5, 0.6), "size": Vector2(1, 1), "gravity": Vector2(0, -8), "radius": 2.0},
	&"pot_shards": {"amount": 10, "life": 0.4, "speed": Vector2(30, 60), "color": Color(0.72, 0.42, 0.24), "size": Vector2(1, 2), "gravity": Vector2(0, 160), "spread": 70.0, "dir": Vector2.UP},
	&"crate_splinters": {"amount": 10, "life": 0.4, "speed": Vector2(30, 60), "color": Color(0.62, 0.42, 0.22), "size": Vector2(1, 2), "gravity": Vector2(0, 160), "spread": 70.0, "dir": Vector2.UP},
	&"ring": {"amount": 20, "life": 0.4, "speed": Vector2(40, 40), "color": Color(1.0, 0.95, 0.75), "size": Vector2(1, 1), "radius": 4.0, "ring": true, "add": true},
}

## Off in tests that count frames; the Fx tests turn it back on.
var enabled: bool = true

## Hit-stops still running, and their generation (reset() starts a new one,
## so timers of an older one end nothing).
var _stops: int = 0
var _gen: int = 0
## Unscaled seconds the longest running stop has left (safety net).
var _stop_left: float = 0.0
var _shake_left: float = 0.0
var _shake_time: float = 0.0
var _shake_strength: float = 0.0
var _shake_cam: Camera2D = null
var _world: Node2D
var _overlay: CanvasLayer
var _add_material: CanvasItemMaterial


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_world = Node2D.new()
	_world.name = "World"
	_world.z_index = 40
	add_child(_world)
	_overlay = CanvasLayer.new()
	_overlay.name = "Overlay"
	_overlay.layer = 15
	add_child(_overlay)
	_add_material = CanvasItemMaterial.new()
	_add_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD


func _process(delta: float) -> void:
	# Unscaled step: delta comes scaled by Engine.time_scale.
	var real := delta / maxf(Engine.time_scale, 0.0001)
	# Safety net: a hit-stop never outlives its time (plus a margin),
	# whatever happened to its timer.
	if Engine.time_scale != 1.0:
		_stop_left -= real
		if _stop_left < -0.1:
			reset()
	_update_shake(real)


# --- hit-stop ---

## Freezes the game for `frames` 60 fps frames of real time. Overlapping
## calls extend the stop to the latest end, they never stack the scale.
func hit_stop(frames: int) -> void:
	if not enabled or frames <= 0 or not is_inside_tree():
		return
	var secs := frames / 60.0
	_stop_left = maxf(_stop_left, secs)
	_stops += 1
	Engine.time_scale = STOP_SCALE
	var t := get_tree().create_timer(secs, true, false, true)
	t.timeout.connect(_end_stop.bind(_gen))


## The last running stop to end gives time back.
func _end_stop(gen: int) -> void:
	if gen != _gen:
		return
	_stops = maxi(_stops - 1, 0)
	if _stops == 0:
		_stop_left = 0.0
		Engine.time_scale = 1.0


## True while a hit-stop holds.
func is_stopped() -> bool:
	return Engine.time_scale != 1.0


## Back to normal time and a still camera, and no leftover numbers or
## bursts (scene changes call it).
func reset() -> void:
	_gen += 1
	_stops = 0
	_stop_left = 0.0
	Engine.time_scale = 1.0
	_shake_left = 0.0
	if is_instance_valid(_shake_cam):
		_shake_cam.offset = Vector2.ZERO
	_shake_cam = null
	# Numbers, bursts and flying coins of the old scene go with it.
	for layer: Node in [_world, _overlay]:
		if layer == null:
			continue
		for c in layer.get_children():
			c.queue_free()


# --- shake ---

## Shakes the active Camera2D by up to `strength` px for `duration` s, fading
## out. For M and L only (a common hit never shakes).
func shake(strength: float, duration: float) -> void:
	if not enabled or not is_inside_tree():
		return
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return
	if _shake_left > 0.0 and _shake_strength * (_shake_left / _shake_time) > strength:
		return
	_shake_cam = cam
	_shake_strength = strength
	_shake_time = maxf(duration, 0.01)
	_shake_left = _shake_time


func _update_shake(real: float) -> void:
	if _shake_left <= 0.0:
		return
	_shake_left = maxf(_shake_left - real, 0.0)
	if not is_instance_valid(_shake_cam):
		_shake_left = 0.0
		return
	var k := _shake_left / _shake_time
	var amp := _shake_strength * k
	_shake_cam.offset = Vector2(randf_range(-amp, amp), randf_range(-amp, amp)).round() if _shake_left > 0.0 else Vector2.ZERO


# --- flash ---

## Tints `node` (and its direct sprite children, for layered sprites) with
## `color` for `t` s of real time, then back. Uses self_modulate, so it
## stacks on any tint the node keeps in modulate (telegraph, stun).
func flash(node: CanvasItem, color: Color, t: float = FLASH_TIME) -> void:
	if node == null or not is_instance_valid(node) or not node.is_inside_tree():
		return
	var targets: Array[CanvasItem] = [node]
	for c in node.get_children():
		if c is CanvasItem:
			targets.append(c as CanvasItem)
	# The tint to come back to; a flash over a flash keeps the first one's.
	for c in targets:
		if not c.has_meta(&"fx_base"):
			c.set_meta(&"fx_base", c.self_modulate)
		c.self_modulate = color
	var serial := int(node.get_meta(&"fx_serial", 0)) + 1
	node.set_meta(&"fx_serial", serial)
	var tw := node.create_tween()
	tw.set_ignore_time_scale(true)
	tw.tween_interval(t)
	tw.tween_callback(func() -> void:
		if int(node.get_meta(&"fx_serial", 0)) != serial:
			return
		for c in targets:
			if is_instance_valid(c):
				c.self_modulate = c.get_meta(&"fx_base", Color.WHITE)
				c.remove_meta(&"fx_base"))


# --- damage numbers ---

## Floating number at world `pos`: rises and fades. Crits are gold, larger
## and pop. Returns the label (freed on its own).
func number(pos: Vector2, value: int, color: Color = Color(1, 1, 1), crit: bool = false) -> Label:
	if not is_inside_tree():
		return null
	var l := Label.new()
	l.text = ("%d!" % value) if crit else str(value)
	l.add_theme_font_size_override(&"font_size", NUMBER_SIZE)
	l.add_theme_color_override(&"font_color", color)
	l.add_theme_color_override(&"font_outline_color", Color(0.05, 0.03, 0.05))
	l.add_theme_constant_override(&"outline_size", 3)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.size = Vector2(48, 18)
	l.pivot_offset = Vector2(24, 9)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.position = (pos - Vector2(24, 12) + Vector2(randf_range(-5, 5), randf_range(-3, 0))).round()
	_world.add_child(l)
	var tw := l.create_tween()
	tw.set_ignore_time_scale(true)
	if crit:
		l.scale = Vector2(1.6, 1.6)
		tw.tween_property(l, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "position:y", l.position.y - NUMBER_RISE, NUMBER_LIFE).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.parallel().tween_property(l, "modulate:a", 0.0, NUMBER_LIFE * 0.4).set_delay(NUMBER_LIFE * 0.6)
	tw.tween_callback(l.queue_free)
	return l


# --- bursts ---

## One-shot particle burst at world `pos`. Unknown ids warn and return null.
func burst(id: StringName, pos: Vector2) -> CPUParticles2D:
	if not BURSTS.has(id):
		push_warning("Fx.burst: unknown id '%s'" % id)
		return null
	if not is_inside_tree():
		return null
	var d: Dictionary = BURSTS[id]
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.explosiveness = 0.9
	p.amount = int(d["amount"])
	p.lifetime = float(d["life"])
	var speed: Vector2 = d["speed"]
	p.initial_velocity_min = speed.x
	p.initial_velocity_max = speed.y
	var size: Vector2 = d["size"]
	p.scale_amount_min = size.x
	p.scale_amount_max = size.y
	p.color = d["color"]
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 1))
	ramp.set_color(1, Color(1, 1, 1, 0))
	p.color_ramp = ramp
	p.gravity = d.get("gravity", Vector2.ZERO)
	p.direction = d.get("dir", Vector2.RIGHT)
	p.spread = float(d.get("spread", 180.0))
	var radius := float(d.get("radius", 0.0))
	if bool(d.get("ring", false)):
		p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE_SURFACE
		p.emission_sphere_radius = radius
		p.spread = 0.0
		p.radial_accel_min = 60.0
		p.radial_accel_max = 60.0
		p.initial_velocity_min = 0.0
		p.initial_velocity_max = 0.0
	elif radius > 0.0:
		p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
		p.emission_sphere_radius = radius
	if bool(d.get("add", false)):
		p.material = _add_material
	p.position = pos.round()
	_world.add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)
	return p


# --- coin to the counter ---

## A coin flies from world `pos` to the HUD gold counter (the HUD bounces it
## when the gold lands). No-op without a HUD.
func fly_coin(pos: Vector2) -> void:
	if not enabled or not is_inside_tree():
		return
	var scene := get_tree().current_scene
	var hud := scene.get_node_or_null(^"Hud") if scene != null else null
	var target: Control = hud.get(&"coin") as Control if hud != null else null
	if target == null:
		return
	var from := get_viewport().get_canvas_transform() * pos
	var to := target.get_global_rect().get_center()
	var icon := TextureRect.new()
	var tex := AtlasTexture.new()
	tex.atlas = COIN_TEX
	tex.region = Rect2(Vector2.ZERO, COIN_FRAME)
	icon.texture = tex
	icon.size = COIN_FRAME
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.position = from - COIN_FRAME / 2.0
	_overlay.add_child(icon)
	var mid := (from + to) / 2.0 + Vector2(0, -30)
	var tw := icon.create_tween()
	tw.set_ignore_time_scale(true)
	tw.tween_method(func(k: float) -> void:
		var a := from.lerp(mid, k)
		var b := mid.lerp(to, k)
		icon.position = (a.lerp(b, k) - COIN_FRAME / 2.0).round(), 0.0, 1.0, COIN_FLY_TIME).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.tween_callback(icon.queue_free)


# --- ladder helpers ---

## Feedback for a hit that landed on `target` (its sprite flashes) at world
## `pos` for `dmg`. `level`: S common, M crit/finisher/special, L boss-sized.
## `freeze`: false for hits the player did not deal (no hit-stop).
func impact(sprite: CanvasItem, pos: Vector2, dmg: int, crit: bool, level: int, freeze: bool = true) -> void:
	flash(sprite, FLASH_CRIT if crit else FLASH_WHITE, FLASH_TIME)
	number(pos, dmg, Color(1.0, 0.85, 0.3) if crit else Color(1, 1, 1), crit)
	burst(&"crit" if crit else &"hit", pos)
	if freeze:
		hit_stop(STOP_FRAMES[clampi(level, S, L)])
	if level >= L:
		shake(3.0, 0.3)
