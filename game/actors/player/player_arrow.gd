class_name PlayerArrow
extends Hitbox
## The bow's arrow. Flies `max_dist` px at `speed`, hits up to pierce + 1
## enemies (one each) and stops at a wall. A charged arrow glows.

const LENGTH := 10.0
const NORMAL_COLOR := Color(0.92, 0.85, 0.7)
const CHARGED_COLOR := Color(0.6, 0.95, 1.0)

var direction: Vector2 = Vector2.RIGHT
var speed: float = 540.0
var max_dist: float = 240.0
var pierce: int = 0
var charged: bool = false
## Enemies hit so far.
var hits: int = 0

var _dist: float = 0.0


func _ready() -> void:
	team = &"player"
	rotation = direction.angle()
	if get_child_count() == 0:
		var cs := CollisionShape2D.new()
		var rs := RectangleShape2D.new()
		rs.size = Vector2(LENGTH, 4)
		cs.shape = rs
		add_child(cs)
	set_active(true)
	landed.connect(_on_landed)
	body_entered.connect(_on_body)


## A spent arrow (past its pierce count) hits nothing more this frame.
func can_hit(hurtbox: Hurtbox) -> bool:
	if hits > pierce:
		return false
	return super(hurtbox)


func _physics_process(delta: float) -> void:
	var step := speed * delta
	position += direction * step
	_dist += step
	if _dist >= max_dist:
		queue_free()


func _on_landed(_h: Hurtbox) -> void:
	hits += 1
	if hits > pierce:
		set_active(false)
		queue_free()


func _on_body(body: Node2D) -> void:
	if not body is CharacterBody2D:
		queue_free()


func _draw() -> void:
	var c := CHARGED_COLOR if charged else NORMAL_COLOR
	if charged:
		draw_line(Vector2(-LENGTH * 2.2, 0), Vector2(0, 0), Color(c, 0.35), 4.0)
	draw_line(Vector2(-LENGTH * 0.5, 0), Vector2(LENGTH * 0.5, 0), Color(0.45, 0.3, 0.15), 1.0)
	draw_colored_polygon(PackedVector2Array([Vector2(LENGTH * 0.5 + 3, 0), Vector2(LENGTH * 0.5 - 1, -2), Vector2(LENGTH * 0.5 - 1, 2)]), c)
	draw_line(Vector2(-LENGTH * 0.5, -1.5), Vector2(-LENGTH * 0.5 + 2, 0), c, 1.0)
	draw_line(Vector2(-LENGTH * 0.5, 1.5), Vector2(-LENGTH * 0.5 + 2, 0), c, 1.0)
