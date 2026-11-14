class_name PickupItem
extends Area2D
## Loot lying on the floor (`qty` of `item_id`). Materials are taken on touch;
## gear and relics with E (interact), so an item dropped next to the player
## does not reopen the swap panel at once. Loot goes to the backpack
## (RunState.take_loot); what does not fit stays here and the HUD says
## "Mochila cheia".

const YELLOW := Color(1.0, 0.85, 0.2)
const MATERIAL_COLOR := Color(0.55, 0.9, 0.75)
const FULL_TEXT := "Mochila cheia"

@export var item_id: StringName = &""
@export var qty: int = 1

var _near: bool = false
var _busy: bool = false
var _t: float = 0.0

@onready var prompt: Label = $Prompt


func _ready() -> void:
	prompt.visible = false
	_update_prompt()
	body_entered.connect(_on_body.bind(true))
	body_exited.connect(_on_body.bind(false))


func is_material() -> bool:
	return ItemDB.kind(item_id) == &"material"


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()
	if _near and not _busy and not is_material() and Input.is_action_just_pressed(&"interact"):
		take()


## Puts what fits into the run; frees the pickup when nothing is left.
## Returns how many units are still on the floor.
func take() -> int:
	if is_material():
		return _take_stack()
	_busy = true
	var result: Dictionary = await Game.offer_item(item_id)
	_busy = false
	if not bool(result["taken"]):
		if ItemDB.kind(item_id) != &"relic":
			Game.toast(FULL_TEXT)
		return qty
	var out: StringName = result["swapped_out"]
	if out != &"":
		var p := (load(scene_file_path) as PackedScene).instantiate() as PickupItem
		p.item_id = out
		p.position = position
		get_parent().add_child.call_deferred(p)
	qty = 0
	queue_free()
	return 0


func _take_stack() -> int:
	var left := Game.run.take_loot(item_id, qty)
	if left > 0:
		Game.toast(FULL_TEXT)
	qty = left
	if qty <= 0:
		queue_free()
	else:
		_update_prompt()
	return qty


func _update_prompt() -> void:
	if not ItemDB.has(item_id):
		return
	var item_name := String(ItemDB.get_def(item_id)["name"])
	var count := " x%d" % qty if qty > 1 else ""
	prompt.text = ("%s%s" if is_material() else "E: %s%s") % [item_name, count]


func _on_body(body: Node2D, inside: bool) -> void:
	if body.is_in_group(&"player"):
		_near = inside
		prompt.visible = inside
		if inside and is_material() and not is_queued_for_deletion():
			_take_stack()


func _draw() -> void:
	var y := -6.0 + sin(_t * 3.0) * 1.5
	draw_circle(Vector2(0, 3), 4.5, Color(0, 0, 0, 0.35))
	if is_material():
		var s := 4.0
		var gem := PackedVector2Array([Vector2(0, y - s), Vector2(s, y), Vector2(0, y + s), Vector2(-s, y)])
		draw_colored_polygon(gem, MATERIAL_COLOR)
		draw_polyline(gem + PackedVector2Array([gem[0]]), Color(0.15, 0.35, 0.3), 1.0)
		return
	var gem := PackedVector2Array([Vector2(0, y - 6), Vector2(6, y), Vector2(0, y + 6), Vector2(-6, y)])
	draw_colored_polygon(gem, YELLOW)
	draw_polyline(gem + PackedVector2Array([gem[0]]), Color(0.55, 0.4, 0.05), 1.0)
	draw_rect(Rect2(-2, y - 3, 2, 2), Color.WHITE)
