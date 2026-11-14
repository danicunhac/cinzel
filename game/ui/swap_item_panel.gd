class_name SwapItemPanel
extends CanvasLayer
## Shown when add_item fails. Pauses the tree; the player picks a slot to
## replace ("Trocar") or keeps the inventory as is ("Deixar"). Same frame,
## title plaque and slide-in as the other panels.

signal closed(swapped_out: StringName)

var _new_item: StringName = &""
var _selected: int = -1
var _slot_buttons: Array[Button] = []
var _swap_button: Button


## Debug for screenshots: `--swap=<item id>` opens the panel on start, with
## the slots filled if the run has none.
func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--swap=") and _new_item == &"":
			while Game.run.can_take_item():
				Game.run.add_item([&"fang", &"glass_shield", &"light_boots"][Game.run.items.size()])
			open.call_deferred(StringName(a.substr(7)))


func open(new_item: StringName) -> void:
	_new_item = new_item
	get_tree().paused = true
	UiKit.ensure_wasd_ui()
	_build()


func _build() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.02, 0.04, 0.7)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)

	var box := UiKit.centred_frame(root, Vector2(200, 0), "Inventário cheio")
	box.add_child(UiKit.label("Escolha o item que sai.", UiKit.COLOR_MUTED, HORIZONTAL_ALIGNMENT_CENTER))

	var items: Array[StringName] = Game.run.items
	for i in RunState.SLOTS:
		var has := i < items.size()
		var b := UiKit.button(_item_name(items[i]) if has else "(vazio)", UiKit.item_icon(items[i]) if has else null)
		b.toggle_mode = true
		b.disabled = not has
		b.pressed.connect(_select.bind(i))
		box.add_child(b)
		_slot_buttons.append(b)

	var incoming := HBoxContainer.new()
	incoming.alignment = BoxContainer.ALIGNMENT_CENTER
	incoming.add_child(UiKit.label("Novo:", UiKit.COLOR_MUTED))
	var icon := TextureRect.new()
	icon.texture = UiKit.item_icon(_new_item)
	incoming.add_child(icon)
	incoming.add_child(UiKit.label(_item_name(_new_item), UiKit.COLOR_ITEM))
	box.add_child(incoming)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 6)
	box.add_child(row)
	_swap_button = UiKit.button("Trocar")
	_swap_button.disabled = true
	_swap_button.pressed.connect(_swap)
	row.add_child(_swap_button)
	var leave := UiKit.button("Deixar")
	leave.pressed.connect(_leave)
	row.add_child(leave)
	leave.grab_focus.call_deferred()


func _item_name(id: StringName) -> String:
	return UiKit.item_name(id)


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
