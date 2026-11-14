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


## Adds the item, or opens the swap panel when the slots are full.
## Returns true when the new item ended up in the inventory.
func offer_item(id: StringName) -> bool:
	if run.add_item(id):
		return true
	var panel := SwapItemPanelScene.instantiate() as SwapItemPanel
	get_tree().current_scene.add_child(panel)
	panel.open(id)
	return await panel.closed
