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
## While the player stands on a leftover stack, try again this often.
const RETRY_TIME := 0.5

@export var item_id: StringName = &""
@export var qty: int = 1
## Dropped by the player (backpack, full-backpack swap): not taken on touch
## until the player has stepped off it once.
var wait_exit: bool = false

var _near: bool = false
var _busy: bool = false
var _t: float = 0.0
var _retry: float = 0.0

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
	elif _near and is_material() and not wait_exit and qty > 0 and not is_queued_for_deletion():
		_retry -= delta
		if _retry <= 0.0:
			_retry = RETRY_TIME
			_take_stack(false)


## Puts what fits into the run; frees the pickup when nothing is left.
## Returns how many units are still on the floor.
func take() -> int:
	if is_material():
		return _take_stack()
	_busy = true
	var result: Dictionary = await Game.offer_item(item_id)
	_busy = false
	if not bool(result["taken"]):
		if not bool(result.get("busy", false)) and not bool(result.get("chose", false)):
			Game.toast(FULL_TEXT)
		return qty
	var out: StringName = result["swapped_out"]
	if out != &"":
		var p := (load(scene_file_path) as PackedScene).instantiate() as PickupItem
		p.item_id = out
		p.qty = int(result.get("swapped_qty", 1))
		p.wait_exit = true
		p.position = position
		get_parent().add_child.call_deferred(p)
	qty = 0
	_picked()
	queue_free()
	return 0


func _picked() -> void:
	Sfx.play(&"item_pickup")
	Fx.burst(&"ring", global_position)


## `toast`: say "Mochila cheia" when something is left (not on quiet retries).
func _take_stack(toast: bool = true) -> int:
	if Game.run.inventory.free_slots() <= 0 and not _has_room_in_stack():
		if toast:
			Game.toast(FULL_TEXT)
		return qty
	var left := Game.run.take_loot(item_id, qty)
	if left < qty:
		_picked()
	if left > 0 and toast:
		Game.toast(FULL_TEXT)
	qty = left
	if qty <= 0:
		queue_free()
	else:
		_update_prompt()
	return qty


func _has_room_in_stack() -> bool:
	for i in Game.run.inventory.capacity:
		if Game.run.inventory.id_at(i) == item_id and Game.run.inventory.qty_at(i) < ItemDB.stack_max(item_id):
			return true
	return false


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
		if not inside:
			wait_exit = false
		elif wait_exit:
			return
		if inside and is_material() and not is_queued_for_deletion():
			_retry = RETRY_TIME
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
