class_name SwapItemPanel
extends UiPanel
## Full-backpack choice, shown when gear or a relic is picked up with no room
## (Game.offer_item). Left: the new item, compared with what is worn. Right:
## "Trocar por..." and the backpack grid; the player picks the stack that
## drops in its place ("Trocar") or leaves the new item on the floor
## ("Deixar", Esc). Emits picked(slot) once, slot -1 when leaving.

signal picked(slot: int)

const GRID_COLS := 5
const INFO_W := 120.0

var new_item: StringName = &""
var selected: int = -1
var cells: Array[ItemCell] = []
var swap_button: Button
var leave_button: Button

var _picked_sent: bool = false
## Slot sent with picked() when the panel closes (-1: leave the item).
var _choice: int = -1
var _out_label: Label


func _init() -> void:
	super._init()
	panel_size = Vector2(300, 0)
	panel_title = "Mochila cheia"
	close_hint = "Esc: deixar"
	show_close_button = false


## Shows the choice for `item` (call after adding the panel to the tree).
func open_for(item: StringName) -> void:
	new_item = item
	open()


func _build(box: VBoxContainer) -> void:
	cells.clear()
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 10)
	box.add_child(cols)

	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 3)
	cols.add_child(left)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 4)
	left.add_child(head)
	var incoming := ItemCell.new().set_item(new_item)
	incoming.focus_mode = Control.FOCUS_NONE
	incoming.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(incoming)
	var new_label := UiKit.label("Novo item", UiKit.COLOR_TITLE)
	new_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(new_label)
	var info := ItemInfo.new(INFO_W)
	info.show_item(new_item, ItemCompare.compare(Game.run.equipment, new_item))
	left.add_child(info)

	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 3)
	cols.add_child(right)
	right.add_child(UiKit.label("Trocar por...", UiKit.COLOR_TITLE))
	var grid := GridContainer.new()
	grid.columns = GRID_COLS
	grid.add_theme_constant_override("h_separation", 2)
	grid.add_theme_constant_override("v_separation", 2)
	right.add_child(grid)
	var inv := Game.run.inventory
	for i in inv.capacity:
		var c := ItemCell.new().set_item(inv.id_at(i), inv.qty_at(i))
		c.key = i
		c.set_selected(i == selected)
		c.focus_entered.connect(select.bind(i))
		c.activated.connect(_on_activated.bind(i))
		grid.add_child(c)
		cells.append(c)
	_out_label = UiKit.label("", UiKit.COLOR_MUTED)
	_out_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_out_label.custom_minimum_size = Vector2(118, 20)
	right.add_child(_out_label)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_theme_constant_override("separation", 4)
	right.add_child(row)
	swap_button = UiKit.button("Trocar")
	swap_button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	swap_button.pressed.connect(confirm)
	row.add_child(swap_button)
	leave_button = UiKit.button("Deixar")
	leave_button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	leave_button.pressed.connect(leave_item)
	row.add_child(leave_button)
	_update()


## "Deixar" first, so a stray Enter never drops anything.
func _initial_focus() -> Button:
	return leave_button


## Picks the backpack slot that would drop (a second press confirms).
func select(slot: int) -> void:
	selected = slot
	_update()


func _on_activated(slot: int) -> void:
	if selected == slot:
		confirm()
	else:
		select(slot)


func _update() -> void:
	for c in cells:
		c.set_selected(c.key == selected)
	var id := Game.run.inventory.id_at(selected)
	swap_button.disabled = id == &""
	if id == &"":
		_out_label.text = "Escolha o que sai."
		_out_label.add_theme_color_override("font_color", UiKit.COLOR_MUTED)
	else:
		var n := Game.run.inventory.qty_at(selected)
		_out_label.text = "Sai: %s%s" % [UiKit.item_name(id), " x%d" % n if n > 1 else ""]
		_out_label.add_theme_color_override("font_color", UiKit.COLOR_DANGER)


## Drops the selected stack for the new item.
func confirm() -> void:
	if Game.run.inventory.id_at(selected) == &"":
		return
	_choice = selected
	close()


func leave_item() -> void:
	_choice = -1
	close()


## Unpauses first, then tells Game.offer_item (which resumes at once).
func close() -> void:
	if not is_open():
		return
	super.close()
	_send(_choice)


func _send(slot: int) -> void:
	if _picked_sent:
		return
	_picked_sent = true
	picked.emit(slot)
