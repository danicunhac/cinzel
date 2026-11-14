class_name Chest
extends StaticBody2D
## Opens with E (interact). Gives one random item through Game.offer_item;
## an item that does not end up in the inventory (the new one when the player
## keeps the old set, or the swapped-out one) drops as a PickupItem.

signal opened(item: StringName)

const PickupScene := preload("res://world/pickup_item.tscn")

var is_open: bool = false
var _near: bool = false
var _rng := RandomNumberGenerator.new()

@onready var sprite: Sprite2D = $Sprite
@onready var reach: Area2D = $Reach
@onready var prompt: Label = $Prompt


func _ready() -> void:
	_rng.randomize()
	sprite.region_rect = RoomTiles.region(RoomTiles.CHEST_CLOSED)
	prompt.visible = false
	reach.body_entered.connect(_on_reach.bind(true))
	reach.body_exited.connect(_on_reach.bind(false))


func _process(_delta: float) -> void:
	if _near and not is_open and Input.is_action_just_pressed(&"interact"):
		open()


func open() -> void:
	if is_open:
		return
	is_open = true
	prompt.visible = false
	sprite.region_rect = RoomTiles.region(RoomTiles.CHEST_OPEN)
	var id := roll_item()
	var result: Dictionary = await Game.offer_item(id)
	if not bool(result["taken"]):
		_drop(id, Vector2(0, 21))
	var out: StringName = result["swapped_out"]
	if out != &"":
		_drop(out, Vector2(21, 15))
	opened.emit(id)


## Random item, preferring ones the player does not carry yet.
func roll_item() -> StringName:
	var pool := ItemDB.ids().filter(func(id: StringName) -> bool: return not Game.run.items.has(id))
	if pool.is_empty():
		pool = ItemDB.ids()
	return pool[_rng.randi_range(0, pool.size() - 1)]


func _drop(id: StringName, offset: Vector2) -> void:
	var p := PickupScene.instantiate() as PickupItem
	p.item_id = id
	p.position = position + offset
	get_parent().add_child(p)


func _on_reach(body: Node2D, inside: bool) -> void:
	if body.is_in_group(&"player"):
		_near = inside
		prompt.visible = inside and not is_open
