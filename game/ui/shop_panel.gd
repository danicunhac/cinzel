class_name ShopPanel
extends UiPanel
## Town shop: buy from the 3-item stock, sell inventory items.

var shop: Shop
var _desc: Label
var _msg: String = ""
var _msg_color: Color = UiKit.COLOR_MUTED
## Selling takes two presses: the first arms this slot and says the price.
var _pending_sell: int = -1


func _init() -> void:
	super._init()
	panel_size = Vector2(344, 0)
	panel_title = "Loja"


func _build(box: VBoxContainer) -> void:
	var run := Game.run
	var head := HBoxContainer.new()
	head.alignment = BoxContainer.ALIGNMENT_END
	head.add_child(UiKit.label("Ouro: %d" % run.gold, UiKit.COLOR_GOLD))
	box.add_child(head)

	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 6)
	box.add_child(cols)
	var buy_col := _column(cols, "Comprar")
	if shop.stock.is_empty():
		buy_col.add_child(UiKit.label("Esgotado", UiKit.COLOR_MUTED))
	for i in shop.stock.size():
		var id: StringName = shop.stock[i]
		var price: int = ItemDB.get_def(id)["buy"]
		var b := _item_button(id, "%d" % price)
		if price > run.gold:
			(b.get_meta(&"price_label") as Label).add_theme_color_override("font_color", UiKit.COLOR_DANGER)
		b.pressed.connect(_buy.bind(i))
		buy_col.add_child(b)
	var sell_col := _column(cols, "Vender")
	if run.items.is_empty():
		sell_col.add_child(UiKit.label("Nada para vender", UiKit.COLOR_MUTED))
	for slot in run.items.size():
		var id: StringName = run.items[slot]
		var b := _item_button(id, "+%d" % int(ItemDB.get_def(id)["sell"]))
		b.pressed.connect(_sell.bind(slot))
		sell_col.add_child(b)

	_desc = UiKit.label("", UiKit.COLOR_ITEM)
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc.custom_minimum_size = Vector2(324, 18)
	box.add_child(_desc)
	var msg := UiKit.label(_msg, _msg_color)
	box.add_child(msg)


func _column(parent: HBoxContainer, title: String) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(159, 0)
	col.add_theme_constant_override("separation", 2)
	col.add_child(UiKit.label(title, UiKit.COLOR_MUTED))
	parent.add_child(col)
	return col


## Icon + name on the left, price on the right.
func _item_button(id: StringName, price: String) -> Button:
	var b := UiKit.button(UiKit.item_name(id), UiKit.item_icon(id))
	b.custom_minimum_size = Vector2(159, 20)
	b.clip_text = true
	b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var p := UiKit.label(price, UiKit.COLOR_GOLD, HORIZONTAL_ALIGNMENT_RIGHT)
	p.set_anchors_preset(Control.PRESET_FULL_RECT)
	p.offset_right = -4
	p.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(p)
	b.set_meta(&"price_label", p)
	# Room for the price so the name never runs under it.
	for state: StringName in [&"normal", &"hover", &"pressed", &"hover_pressed", &"disabled"]:
		var sb := b.get_theme_stylebox(state).duplicate() as StyleBox
		sb.content_margin_right = 22
		b.add_theme_stylebox_override(state, sb)
	var desc := String(ItemDB.get_def(id)["desc"])
	b.focus_entered.connect(func() -> void: _show_desc(desc))
	b.mouse_entered.connect(func() -> void: _show_desc(desc))
	return b


func _show_desc(text: String) -> void:
	if is_instance_valid(_desc):
		_desc.text = text


func _buy(index: int) -> void:
	_pending_sell = -1
	var run := Game.run
	var id: StringName = shop.stock[index]
	var price: int = ItemDB.get_def(id)["buy"]
	if not run.can_take_item():
		_set_msg("Inventário cheio: venda um item antes.", UiKit.COLOR_DANGER)
	elif price > run.gold:
		_set_msg("Ouro insuficiente.", UiKit.COLOR_DANGER)
	elif shop.buy(run, index):
		_set_msg("Comprou %s." % UiKit.item_name(id), UiKit.COLOR_ITEM)
	refresh()


func _sell(slot: int) -> void:
	var run := Game.run
	var id: StringName = run.items[slot]
	var price := int(ItemDB.get_def(id)["sell"])
	if _pending_sell != slot:
		_pending_sell = slot
		_set_msg("Aperte de novo para vender %s por %d." % [UiKit.item_name(id), price], UiKit.COLOR_TITLE)
		refresh()
		return
	_pending_sell = -1
	if shop.sell(run, slot):
		_set_msg("Vendeu %s por %d." % [UiKit.item_name(id), int(ItemDB.get_def(id)["sell"])], UiKit.COLOR_GOLD)
	refresh()


func _set_msg(text: String, color: Color) -> void:
	_msg = text
	_msg_color = color
