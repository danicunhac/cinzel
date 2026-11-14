extends Node2D
## Pulsing blue ring under the town's teleport stone (drawing only).

const COLOR := Color(0.5, 0.85, 1.0)
var _t: float = 0.0


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var pulse := 0.5 + 0.5 * sin(_t * 3.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.5))
	draw_circle(Vector2.ZERO, 18.0, Color(COLOR, 0.18 + 0.12 * pulse))
	draw_arc(Vector2.ZERO, 16.0, 0.0, TAU, 32, Color(COLOR, 0.8), 1.0)
