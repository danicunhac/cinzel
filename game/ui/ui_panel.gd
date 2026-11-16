class_name UiPanel
extends CanvasLayer
## Base for the town panels. open() pauses the tree and builds the content;
## Esc or the "Fechar" button closes it and unpauses. Subclasses override
## _build(body) and call refresh() after a change.

signal closed

## Panels open right now, and the frame the last one closed on: the pause
## menu ignores the same Esc press that closed a panel.
static var open_count: int = 0
static var last_closed_frame: int = -1

var panel_size: Vector2 = Vector2(240, 140)
## Shown on a plaque across the top edge of the frame.
var panel_title: String = ""
## Key hints on the bottom row, next to "Fechar".
var close_hint: String = "Esc: fechar"
## The bottom-row "Fechar" button (off when the panel has its own way out).
var show_close_button: bool = true
## Actions besides Esc that close the panel (the backpack closes on Tab too).
var close_actions: Array[StringName] = [&"ui_cancel", &"pause"]
var _root: Control
var _body: VBoxContainer
var _open: bool = false


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 30


## Call after adding the panel to the tree.
func open() -> void:
	if _open:
		return
	_open = true
	open_count += 1
	UiKit.ensure_wasd_ui()
	get_tree().paused = true
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.02, 0.04, 0.65)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)
	_body = UiKit.centred_frame(_root, panel_size, panel_title)
	refresh()


func close() -> void:
	if not _open:
		return
	_open = false
	open_count -= 1
	last_closed_frame = Engine.get_process_frames()
	# The key that pressed "Fechar" (Space) must not also roll the player.
	UiKit.block_gameplay_input()
	get_tree().paused = false
	closed.emit()
	queue_free()


func is_open() -> bool:
	return _open


## Rebuilds the content, keeping focus on the same button index if possible.
func refresh() -> void:
	var focus_index := _focused_index()
	for c in _body.get_children():
		_body.remove_child(c)
		c.queue_free()
	_build(_body)
	var close_row := HBoxContainer.new()
	close_row.alignment = BoxContainer.ALIGNMENT_END
	close_row.size_flags_vertical = Control.SIZE_SHRINK_END | Control.SIZE_EXPAND
	var hint := UiKit.label(close_hint, UiKit.COLOR_MUTED)
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	close_row.add_child(hint)
	if show_close_button:
		var close_btn := UiKit.button("Fechar")
		close_btn.pressed.connect(close)
		close_row.add_child(close_btn)
	_body.add_child(close_row)
	_focus_index(focus_index)


func _build(_box: VBoxContainer) -> void:
	pass


func _buttons() -> Array[Button]:
	var out: Array[Button] = []
	if _body == null:
		return out
	for n in _body.find_children("*", "Button", true, false):
		var b := n as Button
		if not b.is_queued_for_deletion() and b.focus_mode != Control.FOCUS_NONE:
			out.append(b)
	return out


func _focused_index() -> int:
	var owner_focus := get_viewport().gui_get_focus_owner() if is_inside_tree() else null
	var list := _buttons()
	return list.find(owner_focus as Button) if owner_focus is Button else -1


## Button that gets the cursor when the panel opens (null: the first one).
func _initial_focus() -> Button:
	return null


func _focus_index(i: int) -> void:
	var first := _initial_focus() if i < 0 else null
	if first != null:
		_grab.call_deferred(first)
		return
	var list := _buttons()
	if i >= 0 and i < list.size() and not list[i].disabled:
		_grab.call_deferred(list[i])
		return
	for b in list:
		if not b.disabled:
			_grab.call_deferred(b)
			return


func _grab(b: Button) -> void:
	if _open and is_instance_valid(b) and b.is_inside_tree():
		b.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if not _open:
		return
	for action in close_actions:
		if event.is_action_pressed(action):
			get_viewport().set_input_as_handled()
			close()
			return
