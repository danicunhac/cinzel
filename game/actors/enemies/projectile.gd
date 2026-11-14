class_name Projectile
extends Hitbox

const LIFETIME := 3.0
const RADIUS := 2.5
const RED := Color(1.0, 0.15, 0.15)

var direction: Vector2 = Vector2.RIGHT
var speed: float = 90.0
var _age: float = 0.0


func _ready() -> void:
	team = &"enemy"
	set_active(true)
	landed.connect(func(_h: Hurtbox) -> void: queue_free())
	body_entered.connect(_on_body)


func _physics_process(delta: float) -> void:
	position += direction * speed * delta
	_age += delta
	if _age >= LIFETIME:
		queue_free()


func _on_body(body: Node2D) -> void:
	if not body is CharacterBody2D:
		queue_free()


func _draw() -> void:
	draw_circle(Vector2.ZERO, RADIUS, RED)
	draw_circle(Vector2.ZERO, RADIUS * 0.45, Color(1.0, 0.7, 0.6))
