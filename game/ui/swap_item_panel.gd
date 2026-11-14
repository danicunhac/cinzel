class_name SwapItemPanel
extends CanvasLayer
## Shown when add_item fails. Pauses the tree; the player picks a slot to
## replace ("trocar") or keeps the inventory as is ("deixar").

signal closed(swapped_out: StringName)

var _new_item: StringName = &""
var _selected: int = -1
var _slot_buttons: Array[Button] = []
var _swap_button: Button


func open(new_item: StringName) -> void:
	_new_item = new_item
	get_tree().paused = true
	_build()


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	box.add_theme_constant_override("separation", 4)
	add_child(box)

	var title := Label.new()
	title.text = "Inventário cheio"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	var items: Array[StringName] = Game.run.items
	for i in RunState.SLOTS:
		var b := Button.new()
		b.toggle_mode = true
		b.text = _item_name(items[i]) if i < items.size() else "(vazio)"
		b.disabled = i >= items.size()
		b.pressed.connect(_select.bind(i))
		box.add_child(b)
		_slot_buttons.append(b)

	var incoming := Label.new()
	incoming.text = "Novo: %s" % _item_name(_new_item)
	incoming.add_theme_color_override("font_color", Color(1.0, 0.9, 0.2))
	incoming.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(incoming)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(row)
	_swap_button = Button.new()
	_swap_button.text = "trocar"
	_swap_button.disabled = true
	_swap_button.pressed.connect(_swap)
	row.add_child(_swap_button)
	var leave := Button.new()
	leave.text = "deixar"
	leave.pressed.connect(_leave)
	row.add_child(leave)
	leave.grab_focus()


func _item_name(id: StringName) -> String:
	return String(ItemDB.get_def(id)["name"])


func _select(slot: int) -> void:
	_selected = slot
	for i in _slot_buttons.size():
		_slot_buttons[i].set_pressed_no_signal(i == slot)
	_swap_button.disabled = false


func _swap() -> void:
	var old := Game.run.replace_item(_selected, _new_item)
	_close(old)


func _leave() -> void:
	_close(&"")


func _close(swapped_out: StringName) -> void:
	get_tree().paused = false
	closed.emit(swapped_out)
	queue_free()
