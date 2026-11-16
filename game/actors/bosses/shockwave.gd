class_name Shockwave
extends Hitbox
## Ring attack. Shows a red warning disc for `warn_time`, then a ring grows
## from the centre to `max_radius`; a player hurtbox inside the ring band
## takes one hit (rolling still dodges it, Hurtbox.receive checks that).

signal finished

const RED := Color(1.0, 0.15, 0.1)
const BAND := 12.0

@export var max_radius: float = 132.0
@export var warn_time: float = 0.8
@export var grow_time: float = 0.45

var warning: bool = false
var radius: float = 0.0
var _t: float = -1.0


func _ready() -> void:
	team = &"enemy"
	set_active(false)


func trigger() -> void:
	_t = 0.0
	radius = 0.0
	warning = true
	set_active(true)
	visible = true
	queue_redraw()


func cancel() -> void:
	_t = -1.0
	warning = false
	visible = false
	set_active(false)


func is_running() -> bool:
	return _t >= 0.0


func _physics_process(delta: float) -> void:
	if _t < 0.0:
		return
	_t += delta
	if _t < warn_time:
		queue_redraw()
		return
	if warning:
		# The ring leaves the boss: M on the ladder.
		Sfx.play(&"shockwave", 0.03)
		Fx.shake(2.5, 0.3)
	warning = false
	var k := minf((_t - warn_time) / grow_time, 1.0)
	radius = max_radius * k
	_hit_player()
	queue_redraw()
	if k >= 1.0:
		cancel()
		finished.emit()


func _hit_player() -> void:
	for n in get_tree().get_nodes_in_group(&"player"):
		var hb := n.get_node_or_null(^"Hurtbox") as Hurtbox
		if hb == null:
			continue
		var d := hb.global_position.distance_to(global_position)
		if absf(d - radius) <= BAND:
			hb.receive(self)


func _draw() -> void:
	if _t < 0.0:
		return
	if warning:
		var pulse := 0.5 + 0.5 * sin(_t * 24.0)
		draw_circle(Vector2.ZERO, max_radius, Color(RED, 0.16 + 0.10 * pulse))
		draw_arc(Vector2.ZERO, max_radius, 0.0, TAU, 96, Color(RED, 0.7 + 0.3 * pulse), 2.0)
		# The inner ring grows to the edge as the warning runs out.
		draw_arc(Vector2.ZERO, max_radius * (_t / warn_time), 0.0, TAU, 64, Color(RED, 0.6), 1.0)
	else:
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 64, Color(1.0, 0.45, 0.3, 0.9), 4.0)
		draw_arc(Vector2.ZERO, maxf(radius - 4.0, 0.0), 0.0, TAU, 64, Color(RED, 0.5), 3.0)
