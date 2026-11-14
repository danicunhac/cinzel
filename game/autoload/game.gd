extends Node
## Autoload. Holds the current run and scene flow.

## A short message for the HUD (e.g. "Mochila cheia").
signal toast_requested(text: String)
## Loot that went into the run (RunState.looted of the current run): the HUD
## stacks a "+2 Gosma de Slime" toast for it.
signal loot_taken(id: StringName, qty: int)

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
	apply_debug_loadout()


func toast(text: String) -> void:
	toast_requested.emit(text)


func new_run() -> void:
	run = RunState.new()
	run.looted.connect(func(id: StringName, qty: int) -> void: loot_taken.emit(id, qty))
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
## outfits unlock). When the backpack is full, gear and relics open the
## full-backpack choice ("trocar por..."): the player picks a backpack slot
## to drop for it, or leaves it. Materials just stay on the floor.
## Returns {"taken": bool, "swapped_out": StringName, "swapped_qty": int,
## "busy": bool, "chose": bool}. "busy": the choice panel was already open
## (nothing was tried). "chose": the panel was shown (no "Mochila cheia"
## toast needed). "swapped_out" is the dropped backpack stack (&"" when none);
## the caller must drop it as a pickup.
func offer_item(id: StringName) -> Dictionary:
	if _swap_open:
		return {"taken": false, "swapped_out": &"", "swapped_qty": 0, "busy": true, "chose": false}
	var none := {"taken": false, "swapped_out": &"", "swapped_qty": 0, "busy": false, "chose": false}
	if not ItemDB.has(id):
		return none
	if run.take_loot(id) == 0:
		none["taken"] = true
		return none
	if ItemDB.kind(id) == &"material":
		return none
	_swap_open = true
	var panel := SwapItemPanelScene.instantiate() as SwapItemPanel
	var host: Node = get_tree().current_scene if get_tree().current_scene != null else get_tree().root
	host.add_child(panel)
	panel.open_for(id)
	var slot: int = await panel.picked
	_swap_open = false
	return swap_for(id, slot)


## Drops backpack `slot` and takes `id` in its place (slot < 0: leaves `id`).
func swap_for(id: StringName, slot: int) -> Dictionary:
	var out := {"taken": false, "swapped_out": &"", "swapped_qty": 0, "busy": false, "chose": true}
	if slot < 0 or run.inventory.id_at(slot) == &"":
		return out
	var dropped := run.inventory.take_slot(slot)
	if run.take_loot(id) > 0:
		run.inventory.add(dropped["id"], int(dropped["qty"]))
		return out
	out["taken"] = true
	out["swapped_out"] = dropped["id"]
	out["swapped_qty"] = int(dropped["qty"])
	return out


## Debug for screenshots, read once at start:
## `--give=<id>:<qty>,...` puts items in the backpack (outfits unlock),
## `--equip=<id>,...` gives and equips them.
func apply_debug_loadout() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--give="):
			for part in a.substr(7).split(",", false):
				var kv := part.split(":")
				var id := StringName(kv[0])
				if ItemDB.has(id):
					if ItemDB.kind(id) == &"outfit":
						run.unlock_outfit(id)
					else:
						run.inventory.add(id, int(kv[1]) if kv.size() > 1 else 1)
		elif a.begins_with("--equip="):
			for part in a.substr(8).split(",", false):
				var id := StringName(part)
				if ItemDB.has(id):
					run.inventory.add(id)
					run.equip(id)
