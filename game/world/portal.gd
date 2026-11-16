class_name Portal
extends Area2D
## Glowing ring shown after a boss falls. Touching it emits `used` once.

signal used

var color: Color = Color(0.5, 0.85, 1.0)
var text: String = ""
var _t: float = 0.0
var _done: bool = false


func _ready() -> void:
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 12.0
	shape.shape = circle
	add_child(shape)
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override(&"font_size", 8)
	label.add_theme_color_override(&"font_outline_color", Color.BLACK)
	label.add_theme_constant_override(&"outline_size", 3)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = Vector2(-40, -32)
	label.size = Vector2(80, 10)
	add_child(label)
	body_entered.connect(_on_body)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _on_body(body: Node2D) -> void:
	if _done or not body.is_in_group(&"player"):
		return
	_done = true
	Sfx.play(&"teleport", 0.0)
	Fx.burst(&"teleport", global_position)
	# Deferred: touching happens in a physics callback, and the handler may
	# change scene (freeing bodies mid-callback is not allowed).
	used.emit.call_deferred()


func _draw() -> void:
	var pulse := 0.5 + 0.5 * sin(_t * 4.0)
	draw_circle(Vector2.ZERO, 16.5, Color(color, 0.25 + 0.15 * pulse))
	draw_arc(Vector2.ZERO, 13.5, 0.0, TAU, 32, color, 3.0)
	draw_arc(Vector2.ZERO, 7.5 + pulse * 3.0, 0.0, TAU, 24, Color(color, 0.8), 1.0)
