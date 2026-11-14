class_name IcePatch
extends Area2D
## Floor 2 hazard: frozen floor that slows the player's walk a little while
## any of its shapes (built by build_rooms.gd from the "i" cells) overlaps
## the body. Rolls keep their speed. Draws a faint frost sheen over the
## painting so the patches read even where the painting is subtle.

const SLOW_MULT := 0.8
const SHEEN := Color(0.75, 0.92, 1.0, 0.16)
const EDGE := Color(0.85, 0.97, 1.0, 0.35)
const GLINT := Color(1.0, 1.0, 1.0, 0.55)

var _t: float = 0.0


func _ready() -> void:
	z_index = -4
	monitorable = false
	body_entered.connect(_on_body.bind(true))
	body_exited.connect(_on_body.bind(false))


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _on_body(body: Node2D, inside: bool) -> void:
	if body is Player:
		(body as Player).set_slowed(self, inside)


func _exit_tree() -> void:
	for body in get_overlapping_bodies():
		if body is Player:
			(body as Player).set_slowed(self, false)


func rects() -> Array[Rect2]:
	var out: Array[Rect2] = []
	for c in get_children():
		var shape := c as CollisionShape2D
		if shape != null and shape.shape is RectangleShape2D:
			var size := (shape.shape as RectangleShape2D).size
			out.append(Rect2(shape.position - size / 2.0, size))
	return out


func _draw() -> void:
	for r in rects():
		draw_rect(r.grow(-1), SHEEN)
		draw_rect(r.grow(-1), EDGE, false, 1.0)
		# A glint sliding along each run.
		var k := fmod(_t * 0.35 + r.position.x * 0.013, 1.0)
		var x := r.position.x + 3.0 + k * (r.size.x - 6.0)
		draw_line(Vector2(x, r.position.y + 4), Vector2(x + 3, r.position.y + 1), GLINT, 1.0)
