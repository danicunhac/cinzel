class_name Chest
extends StaticBody2D
## Opens with E (interact). Gives one item rolled by LootTable.roll_chest
## through Game.offer_item (into the backpack, or a free gear/relic slot);
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
		if ItemDB.kind(id) != &"relic":
			Game.toast(PickupItem.FULL_TEXT)
		_drop(id, Vector2(0, 21))
	var out: StringName = result["swapped_out"]
	if out != &"":
		_drop(out, Vector2(21, 15))
	opened.emit(id)


## Random gear or relic from the loot table (rarity by floor and clock).
func roll_item() -> StringName:
	var dungeon := get_tree().current_scene as Dungeon
	var floor_num := dungeon.current_floor if dungeon != null else 1
	return LootTable.roll_chest(floor_num, Game.run.clock.level(), _rng, Game.run.unlocked_outfits)


func _drop(id: StringName, offset: Vector2) -> void:
	var p := PickupScene.instantiate() as PickupItem
	p.item_id = id
	p.position = position + offset
	get_parent().add_child(p)


func _on_reach(body: Node2D, inside: bool) -> void:
	if body.is_in_group(&"player"):
		_near = inside
		prompt.visible = inside and not is_open
