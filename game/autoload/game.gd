extends Node
## Autoload. Holds the current run and scene flow.

const SwapItemPanelScene := preload("res://ui/swap_item_panel.tscn")
## Scene-change fade-in (see goto).
const FADE_TIME := 0.35

var run: RunState
var in_boss_room: bool = false
## Summary of the run that just ended (death or victory), written by Dungeon
## before RunState.die() zeroes it: {"floor": int, "seconds": float, "gold": int}.
## Empty until a run ends.
var last_run: Dictionary[String, Variant] = {}

var _fade: ColorRect
var _fade_tween: Tween


func _ready() -> void:
	if run == null:
		new_run()


func new_run() -> void:
	run = RunState.new()
	in_boss_room = false


## Every scene change uses the same transition: the screen cuts to black and
## the new scene fades in (DoD, one transition type). The change itself is not
## delayed, so code that waits for the next scene keeps working.
func goto(scene_path: String) -> void:
	get_tree().change_scene_to_file(scene_path)
	_fade_in()


func _fade_in() -> void:
	if _fade == null:
		var layer := CanvasLayer.new()
		layer.layer = 100
		layer.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(layer)
		_fade = ColorRect.new()
		_fade.color = Color(0.03, 0.02, 0.04)
		_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
		layer.add_child(_fade)
	if _fade_tween != null:
		_fade_tween.kill()
	_fade.modulate.a = 1.0
	_fade_tween = create_tween()
	_fade_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_fade_tween.tween_property(_fade, "modulate:a", 0.0, FADE_TIME).set_delay(0.05)


var _swap_open: bool = false


## Takes the item as loot (RunState.take_loot: free slot, else backpack;
## outfits unlock). When the backpack is full a relic opens the swap panel
## over the relic slots; anything else stays on the floor.
## Returns {"taken": bool, "swapped_out": StringName}. "taken" is true when the
## new item is now carried; "swapped_out" is the replaced item id
## (&"" when nothing was replaced). The caller must drop swapped_out as a pickup.
## Unknown ids, or a call while a panel is already open, return taken = false.
func offer_item(id: StringName) -> Dictionary:
	var none := {"taken": false, "swapped_out": &""}
	if not ItemDB.has(id) or _swap_open:
		return none
	if run.take_loot(id) == 0:
		return {"taken": true, "swapped_out": &""}
	if ItemDB.kind(id) != &"relic":
		return none
	_swap_open = true
	var panel := SwapItemPanelScene.instantiate() as SwapItemPanel
	get_tree().current_scene.add_child(panel)
	panel.open(id)
	var old: StringName = await panel.closed
	_swap_open = false
	return {"taken": old != &"", "swapped_out": old}
