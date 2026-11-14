class_name ItemCell
extends Button
## One 22x22 item slot (hud/slot.png): the item icon inside its rarity frame
## (items/frames), a stack count in the corner, an optional marker (trend
## arrow) top right. Empty cells can show a faded hint icon (the slot kind).
## Focus ring from the theme; `selected` adds a gold border.
## Keyboard: focus = cursor, accept = activated. Mouse: the first click
## focuses, a click on the focused cell = activated; hover = hovered(true).

signal activated
signal hovered(inside: bool)

const SIZE := Vector2(22, 22)
const SLOT_TEX := preload("res://assets/ui/hud/slot.png")
const FOCUS_TEX := preload("res://assets/ui/hud/button_focus.png")
const FRAME_TEX: Dictionary[StringName, Texture2D] = {
	&"common": preload("res://assets/items/frames/common.png"),
	&"rare": preload("res://assets/items/frames/rare.png"),
	&"epic": preload("res://assets/items/frames/epic.png"),
}
const SELECT_COLOR := Color(1.0, 0.85, 0.35)

var item_id: StringName = &""
var qty: int = 0
## Extra data the panel keys on (slot index, slot kind...).
var key: Variant = null

var _frame: TextureRect
var _icon: TextureRect
var _qty: Label
var _select: ReferenceRect
var _focus_frame: int = -1

static var _styles: Dictionary[StringName, StyleBox] = {}


func _init() -> void:
	custom_minimum_size = SIZE
	size = SIZE
	focus_mode = Control.FOCUS_ALL
	text = ""
	for state: StringName in [&"normal", &"hover", &"pressed", &"hover_pressed", &"disabled", &"focus"]:
		add_theme_stylebox_override(state, _style(state))
	_frame = _rect(Vector2(2, 2), Vector2(18, 18))
	_icon = _rect(Vector2(3, 3), Vector2(16, 16))
	_qty = Label.new()
	_qty.position = Vector2(0, 11)
	_qty.size = Vector2(21, 10)
	_qty.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_qty.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_qty)
	_select = ReferenceRect.new()
	_select.editor_only = false
	_select.border_color = SELECT_COLOR
	_select.border_width = 1.0
	_select.position = Vector2(1, 1)
	_select.size = Vector2(20, 20)
	_select.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_select.visible = false
	add_child(_select)
	focus_entered.connect(func() -> void: _focus_frame = Engine.get_process_frames())
	mouse_entered.connect(func() -> void: hovered.emit(true))
	mouse_exited.connect(func() -> void: hovered.emit(false))
	pressed.connect(func() -> void: activated.emit())


## Shows `id` (&"" = empty) with `count` (shown when above 1). `hint` is a
## faded icon for an empty equipment slot.
func set_item(id: StringName, count: int = 1, hint: Texture2D = null) -> ItemCell:
	item_id = id
	qty = count if id != &"" else 0
	if id == &"":
		_frame.texture = null
		_icon.texture = hint
		_icon.modulate = Color(1, 1, 1, 0.22)
	else:
		_frame.texture = FRAME_TEX.get(ItemDB.rarity(id))
		_icon.texture = UiKit.item_icon(id)
		_icon.modulate = Color.WHITE
	_qty.text = str(qty) if qty > 1 else ""
	return self


func set_selected(on: bool) -> void:
	_select.visible = on


## Greys the icon (locked outfit, recipe that cannot be made, too expensive).
func set_dim(on: bool) -> void:
	var c := Color(0.6, 0.56, 0.56) if on else Color.WHITE
	_frame.modulate = c
	if item_id != &"":
		_icon.modulate = c


## Small square mark (outlined) for set_marker: the outfit worn now.
static func dot(c: Color) -> Control:
	var out := ColorRect.new()
	out.color = TrendArrow.OUTLINE
	out.size = Vector2(5, 5)
	out.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var inner := ColorRect.new()
	inner.color = c
	inner.position = Vector2(1, 1)
	inner.size = Vector2(3, 3)
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	out.add_child(inner)
	return out


## Small padlock for set_marker: a locked outfit (not by colour alone).
static func lock_mark() -> Control:
	var root := Control.new()
	root.size = Vector2(7, 8)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var parts: Array[Rect2] = [
		Rect2(1, 0, 5, 4), Rect2(0, 3, 7, 5),
	]
	for r in parts:
		var o := ColorRect.new()
		o.color = TrendArrow.OUTLINE
		o.position = r.position
		o.size = r.size
		o.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(o)
	var metal := Color(0.82, 0.78, 0.7)
	for r: Rect2 in [Rect2(2, 1, 3, 1), Rect2(2, 1, 1, 3), Rect2(4, 1, 1, 3), Rect2(1, 4, 5, 3)]:
		var m := ColorRect.new()
		m.color = metal
		m.position = r.position
		m.size = r.size
		m.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(m)
	return root


## Puts `c` in the top-right corner (a TrendArrow, a mark).
func set_marker(c: Control) -> void:
	var old := get_node_or_null(^"Marker")
	if old != null:
		remove_child(old)
		old.queue_free()
	if c == null:
		return
	c.name = "Marker"
	c.position = Vector2(SIZE.x - c.size.x - 1, 1)
	add_child(c)


func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb == null or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	accept_event()
	if not mb.pressed:
		return
	if not has_focus():
		grab_focus()
	elif _focus_frame != Engine.get_process_frames():
		activated.emit()


func _rect(pos: Vector2, s: Vector2) -> TextureRect:
	var t := TextureRect.new()
	t.position = pos
	t.size = s
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(t)
	return t


static func _style(state: StringName) -> StyleBox:
	if _styles.has(state):
		return _styles[state]
	var sb := StyleBoxTexture.new()
	if state == &"focus":
		sb.texture = FOCUS_TEX
		for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
			sb.set_texture_margin(side, 6)
			sb.set_expand_margin(side, 1)
	else:
		sb.texture = SLOT_TEX
		for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
			sb.set_texture_margin(side, 5)
		match state:
			&"hover", &"hover_pressed":
				sb.modulate_color = Color(1.25, 1.18, 1.1)
			&"pressed":
				sb.modulate_color = Color(0.85, 0.8, 0.78)
	_styles[state] = sb
	return sb
