class_name PlayerBlast
extends Hitbox
## Area attacks of the specials, placed in the room (not on the player).
##   RAIN (bow): a light circle warns for `warn_time`, then `volleys` volleys
##   of arrows fall every `volley_gap` s; each volley hits every enemy inside.
##   WAVE (axe): a ring grows to `radius` in `grow_time`; every enemy the
##   ring passes takes one hit.
## `damage_roll` gives the damage of each volley (one crit roll per volley).

enum Kind { RAIN, WAVE }

const RAIN_COLOR := Color(0.6, 0.95, 1.0)
const WAVE_COLOR := Color(1.0, 0.85, 0.5)

var kind: Kind = Kind.RAIN
var radius: float = 36.0
var warn_time: float = 0.35
var volleys: int = 4
var volley_gap: float = 0.15
var grow_time: float = 0.3
var damage_roll: Callable

var _t: float = 0.0
var _volley: int = 0
var _streaks: Array[Vector2] = []


func _ready() -> void:
	team = &"player"
	heavy = true
	var cs := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = radius
	cs.shape = shape
	add_child(cs)
	set_active(true)
	# Hurtboxes do not see it enter: hits are dealt by hand (_pulse, _wave).
	monitorable = false


func _physics_process(delta: float) -> void:
	_t += delta
	queue_redraw()
	match kind:
		Kind.RAIN:
			_rain()
		Kind.WAVE:
			_wave()


func _rain() -> void:
	if _t < warn_time:
		return
	var due := int((_t - warn_time) / volley_gap) + 1
	while _volley < mini(due, volleys):
		_volley += 1
		_streaks.clear()
		for i in 7:
			_streaks.append(Vector2.from_angle(randf() * TAU) * sqrt(randf()) * radius)
		_pulse(func(_d: float) -> bool: return true)
	if _t >= warn_time + volley_gap * volleys + 0.15:
		queue_free()


func _wave() -> void:
	var k := minf(_t / grow_time, 1.0)
	var r := radius * k
	if _volley == 0:
		_volley = 1
		_refresh_damage()
	for area in get_overlapping_areas():
		if area is Hurtbox and area.global_position.distance_to(global_position) <= r + 6.0:
			(area as Hurtbox).receive(self)
	if k >= 1.0 and _t >= grow_time + 0.12:
		queue_free()


## One volley: new damage roll, every enemy inside takes one hit.
func _pulse(inside: Callable) -> void:
	reset_hits()
	_refresh_damage()
	for area in get_overlapping_areas():
		if area is Hurtbox and bool(inside.call(area.global_position.distance_to(global_position))):
			(area as Hurtbox).receive(self)


func _refresh_damage() -> void:
	if damage_roll.is_valid():
		damage = int(damage_roll.call())


func _draw() -> void:
	match kind:
		Kind.RAIN:
			var warn := _t < warn_time
			var a := 0.5 + 0.3 * sin(_t * 30.0) if warn else 0.25
			draw_circle(Vector2.ZERO, radius, Color(RAIN_COLOR, 0.12 if warn else 0.08))
			draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, Color(RAIN_COLOR, a), 1.5)
			if not warn:
				for p in _streaks:
					draw_line(p + Vector2(-3, -14), p, Color(RAIN_COLOR, 0.9), 1.5)
					draw_circle(p, 1.5, Color.WHITE)
		Kind.WAVE:
			var k := minf(_t / grow_time, 1.0)
			var fade := 1.0 - maxf(_t - grow_time, 0.0) / 0.12
			draw_arc(Vector2.ZERO, radius * k, 0.0, TAU, 48, Color(WAVE_COLOR, 0.9 * fade), 3.0)
			draw_arc(Vector2.ZERO, maxf(radius * k - 4.0, 0.0), 0.0, TAU, 48, Color(1, 1, 1, 0.5 * fade), 1.5)
