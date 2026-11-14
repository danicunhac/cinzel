extends Node
## Autoload. Holds the current run and scene flow.

const SwapItemPanelScene := preload("res://ui/swap_item_panel.tscn")

var run: RunState
var in_boss_room: bool = false


func _ready() -> void:
	if run == null:
		new_run()


func new_run() -> void:
	run = RunState.new()
	in_boss_room = false


func goto(scene_path: String) -> void:
	get_tree().change_scene_to_file(scene_path)


var _swap_open: bool = false


## Adds the item, or opens the swap panel when the slots are full.
## Returns {"taken": bool, "swapped_out": StringName}. "taken" is true when the
## new item is now in the inventory; "swapped_out" is the replaced item id
## (&"" when nothing was replaced). The caller must drop swapped_out as a pickup.
## Unknown ids, or a call while a panel is already open, return taken = false.
func offer_item(id: StringName) -> Dictionary:
	var none := {"taken": false, "swapped_out": &""}
	if not ItemDB.has(id) or _swap_open:
		return none
	if run.add_item(id):
		return {"taken": true, "swapped_out": &""}
	_swap_open = true
	var panel := SwapItemPanelScene.instantiate() as SwapItemPanel
	get_tree().current_scene.add_child(panel)
	panel.open(id)
	var old: StringName = await panel.closed
	_swap_open = false
	return {"taken": old != &"", "swapped_out": old}
