class_name PickupItem
extends Area2D
## Item lying on the floor. Taken with E (interact), not on touch: a dropped
## item lands next to the player, and touch would reopen the swap panel at once.

const YELLOW := Color(1.0, 0.85, 0.2)

@export var item_id: StringName = &""

var _near: bool = false
var _busy: bool = false
var _t: float = 0.0

@onready var prompt: Label = $Prompt


func _ready() -> void:
	prompt.visible = false
	if ItemDB.has(item_id):
		prompt.text = "E: %s" % String(ItemDB.get_def(item_id)["name"])
	body_entered.connect(_on_body.bind(true))
	body_exited.connect(_on_body.bind(false))


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()
	if _near and not _busy and Input.is_action_just_pressed(&"interact"):
		take()


func take() -> void:
	_busy = true
	var result: Dictionary = await Game.offer_item(item_id)
	_busy = false
	if not bool(result["taken"]):
		return
	var out: StringName = result["swapped_out"]
	if out != &"":
		var p := (load(scene_file_path) as PackedScene).instantiate() as PickupItem
		p.item_id = out
		p.position = position
		get_parent().add_child.call_deferred(p)
	queue_free()


func _on_body(body: Node2D, inside: bool) -> void:
	if body.is_in_group(&"player"):
		_near = inside
		prompt.visible = inside


func _draw() -> void:
	var y := -6.0 + sin(_t * 3.0) * 1.5
	draw_circle(Vector2(0, 3), 4.5, Color(0, 0, 0, 0.35))
	var gem := PackedVector2Array([Vector2(0, y - 6), Vector2(6, y), Vector2(0, y + 6), Vector2(-6, y)])
	draw_colored_polygon(gem, YELLOW)
	draw_polyline(gem + PackedVector2Array([gem[0]]), Color(0.55, 0.4, 0.05), 1.0)
	draw_rect(Rect2(-2, y - 3, 2, 2), Color.WHITE)
