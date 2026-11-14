class_name RoomDoor
extends Node2D
## Exit door painted into the room's Walls layer. Locked (red, solid tile)
## until the room is cleared; walking into the open doorway emits `entered`.
## The cell comes from this node's position, so moving it moves the door.
## In painted rooms the Walls layer is hidden (collision only) and the child
## Sprite2D "Sprite" (door overlay, columns shut / locked / open) shows it.
## The entry door ("Back") is a RoomDoor too, with starts_shut: it stays shut
## in a floor's first room and leads back to the previous room otherwise.

signal entered

const FRAME_SHUT := 0
const FRAME_LOCKED := 1
const FRAME_OPEN := 2

@export var walls_path: NodePath = ^"../Walls"
## Starts shut (no way through) instead of locked.
@export var starts_shut: bool = false

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
	if starts_shut:
		set_shut()
	else:
		set_open(false)


func set_open(open: bool) -> void:
	_show(RoomTiles.DOOR_OPEN if open else RoomTiles.DOOR_LOCKED, FRAME_OPEN if open else FRAME_LOCKED)
	is_open = open
	_trigger.set_deferred("monitoring", open)


## Plain shut door: solid, no lock, no way through.
func set_shut() -> void:
	_show(RoomTiles.DOOR_SHUT, FRAME_SHUT)
	is_open = false
	_trigger.set_deferred("monitoring", false)


## Where a player coming through this door stands: inside the room, clear of
## the trigger (body circle of 6 px, 6 px below the origin).
func arrival() -> Vector2:
	var inward := Vector2.UP
	if _cell.x <= 0:
		inward = Vector2.RIGHT
	elif _cell.x >= _walls.get_used_rect().end.x - 1:
		inward = Vector2.LEFT
	elif _cell.y <= 0:
		inward = Vector2.DOWN
	return global_position + inward * 24.0


func _show(tile: Vector2i, frame: int) -> void:
	_walls.set_cell(_cell, RoomTiles.SOURCE, tile, _alt)
	if _sprite != null:
		var row := _sprite.frame / _sprite.hframes
		_sprite.frame = row * _sprite.hframes + frame


func _on_body_entered(body: Node2D) -> void:
	if is_open and body.is_in_group(&"player"):
		entered.emit()
