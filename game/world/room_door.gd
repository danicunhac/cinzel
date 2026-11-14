class_name RoomDoor
extends Node2D
## Exit door painted into the room's Walls layer. Locked (red, solid tile)
## until the room is cleared; walking into the open doorway emits `entered`.
## The cell comes from this node's position, so moving it moves the door.
## In painted rooms the Walls layer is hidden (collision only) and the child
## Sprite2D "Sprite" (door overlay, columns shut / locked / open) shows it.

signal entered

const FRAME_LOCKED := 1
const FRAME_OPEN := 2

@export var walls_path: NodePath = ^"../Walls"

var is_open: bool = false
var _walls: TileMapLayer
var _cell: Vector2i
var _alt: int = 0
var _trigger: Area2D
var _sprite: Sprite2D


func _ready() -> void:
	_walls = get_node(walls_path) as TileMapLayer
	_cell = _walls.local_to_map(_walls.to_local(global_position))
	_alt = _walls.get_cell_alternative_tile(_cell)
	_sprite = get_node_or_null(^"Sprite") as Sprite2D
	_trigger = Area2D.new()
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(RoomTiles.SIZE, RoomTiles.SIZE)
	shape.shape = rect
	_trigger.add_child(shape)
	add_child(_trigger)
	_trigger.body_entered.connect(_on_body_entered)
	set_open(false)


func set_open(open: bool) -> void:
	is_open = open
	_walls.set_cell(_cell, RoomTiles.SOURCE, RoomTiles.DOOR_OPEN if open else RoomTiles.DOOR_LOCKED, _alt)
	_trigger.set_deferred("monitoring", open)
	if _sprite != null:
		var row := _sprite.frame / _sprite.hframes
		_sprite.frame = row * _sprite.hframes + (FRAME_OPEN if open else FRAME_LOCKED)


func _on_body_entered(body: Node2D) -> void:
	if is_open and body.is_in_group(&"player"):
		entered.emit()
