class_name TownCta
extends Node2D
## Call to action on the ground of a town spot: a gold ring with a radar ping
## while `active`. Fades in and out; draws nothing when hidden.

@export var color: Color = Color(1.0, 0.85, 0.35)
@export var radius: float = 20.0

var active: bool = false
var _t: float = 0.0
var _a: float = 0.0


func _init() -> void:
	z_index = -5


func _process(delta: float) -> void:
	_t += delta
	_a = move_toward(_a, 1.0 if active else 0.0, delta * 5.0)
	if _a > 0.0 or active:
		queue_redraw()


func _draw() -> void:
	if _a <= 0.0:
		return
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.5))
	var pulse := 0.5 + 0.5 * sin(_t * 4.0)
	draw_circle(Vector2.ZERO, radius, Color(color, (0.12 + 0.08 * pulse) * _a))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 40, Color(color, 0.9 * _a), 1.0)
	# Radar ping: a ring that grows out and fades every second.
	var k := fmod(_t, 1.2) / 1.2
	draw_arc(Vector2.ZERO, radius + k * 12.0, 0.0, TAU, 40, Color(color, (1.0 - k) * 0.7 * _a), 1.0)
