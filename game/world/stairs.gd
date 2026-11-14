class_name Stairs
extends Area2D
## Stairs down in the first room of each floor. Taken with E (interact), like
## chests and items: the player arrives next to them when walking back, and
## touch would send them down at once. `used` fires once; the Dungeon sends the
## player to the previous floor's beaten boss room, or to town from floor 1.

signal used

## Prompt text, set before the node enters the tree.
var label: String = "E: descer"
var _near: bool = false
var _done: bool = false

@onready var prompt: Label = $Prompt


func _ready() -> void:
	prompt.text = label
	prompt.visible = false
	body_entered.connect(_on_body.bind(true))
	body_exited.connect(_on_body.bind(false))


func _process(_delta: float) -> void:
	if _near and Input.is_action_just_pressed(&"interact"):
		use()


func use() -> void:
	if _done:
		return
	_done = true
	prompt.visible = false
	used.emit()


func _on_body(body: Node2D, inside: bool) -> void:
	if body.is_in_group(&"player"):
		_near = inside
		prompt.visible = inside and not _done
