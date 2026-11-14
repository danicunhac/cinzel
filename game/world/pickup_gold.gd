class_name PickupGold
extends Area2D

const MAGNET_RADIUS := 48.0
const MAGNET_SPEED := 180.0

var amount: int = 1
var _collected: bool = false


func _ready() -> void:
	body_entered.connect(_on_body)


func _physics_process(delta: float) -> void:
	var p := get_tree().get_first_node_in_group(&"player") as Node2D
	if p == null:
		return
	var to := p.global_position - global_position
	if to.length() <= MAGNET_RADIUS:
		position += to.normalized() * minf(MAGNET_SPEED * delta, to.length())


func _on_body(body: Node2D) -> void:
	if body.is_in_group(&"player"):
		collect()


## Adds the gold to the run once. Also used for coins left behind in a room.
func collect() -> void:
	if _collected:
		return
	_collected = true
	Game.run.add_gold(amount)
	queue_free()


func _draw() -> void:
	draw_circle(Vector2.ZERO, 4.5, Color(0.6, 0.45, 0.05))
	draw_circle(Vector2.ZERO, 3.5, Color(1.0, 0.85, 0.2))
	draw_rect(Rect2(-0.5, -2, 1, 4), Color(0.7, 0.5, 0.05))
