class_name ShopPanel
extends UiPanel
## Town market, two tabs.
## Vender: the backpack grid with today's price of each item (Market supply
## and demand) and a trend arrow on the cell: green up = wanted today (+50%),
## red down = sold too much (price fell). Stacks take a quantity; the total
## counts the drop after each unit sold.
## Comprar: the visit's stock (gear and relics of the floors opened so far)
## and the market outfits, with prices and a comparison with the gear worn.

const GRID_COLS := 5
const LIST_W := 190.0
const INFO_W := 222.0

var shop: Market
var tab: StringName = &"sell"
## Sell tab: backpack slot under the cursor (-1 none) and how many to sell.
var sel_slot: int = -1
var sell_qty: int = 1
## Buy tab: index in buy_list() (-1 none).
var buy_index: int = -1
var sell_cells: Array[ItemCell] = []
var buy_buttons: Array[Button] = []
var action_button: Button
var tab_buttons: Dictionary[StringName, Button] = {}
## Gear and relics sell on a second press of the button (no buy-back).
var sell_armed: bool = false

var _info: ItemInfo
var _msg: String = ""
var _msg_color: Color = UiKit.COLOR_MUTED


func _init() -> void:
	super._init()
	# Fixed size, as tall as the longest entry (stats, price, quantity): a
	# window that grew with the selection moved the list under the mouse.
	panel_size = Vector2(458, 244)
	panel_title = "Loja"


## What the Comprar tab offers: the stock, then market outfits not owned yet.
func buy_list() -> Array[StringName]:
	var out: Array[StringName] = shop.stock.duplicate()
	for id in shop.outfits():
		if not Game.run.unlocked_outfits.has(id):
			out.append(id)
	return out


func select_tab(t: StringName) -> void:
	tab = t
	_msg = ""
	refresh()


func _build(box: VBoxContainer) -> void:
	var run := Game.run
	sell_cells.clear()
	buy_buttons.clear()
	tab_buttons.clear()
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 4)
	box.add_child(head)
	for t: Array in [[&"sell", "Vender"], [&"buy", "Comprar"]]:
		var b := UiKit.button(t[1])
		b.alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.custom_minimum_size = Vector2(70, 0)
		if tab == t[0]:
			# The open tab: lit like a hovered button, gold text.
			var lit := b.get_theme_stylebox(&"hover")
			for state: StringName in [&"normal", &"pressed", &"hover_pressed"]:
				b.add_theme_stylebox_override(state, lit)
			for c: StringName in [&"font_color", &"font_hover_color", &"font_focus_color", &"font_pressed_color"]:
				b.add_theme_color_override(c, UiKit.COLOR_ITEM)
		b.pressed.connect(select_tab.bind(t[0]))
		head.add_child(b)
		tab_buttons[t[0]] = b
	var gold := UiKit.label("Ouro: %d" % run.gold, UiKit.COLOR_GOLD, HORIZONTAL_ALIGNMENT_RIGHT)
	gold.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(gold)

	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 10)
	box.add_child(cols)
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(LIST_W, 0)
	left.add_theme_constant_override("separation", 3)
	cols.add_child(left)
	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(INFO_W, 0)
	right.add_theme_constant_override("separation", 3)
	cols.add_child(right)
	_info = ItemInfo.new(INFO_W)
	right.add_child(_info)
	if tab == &"sell":
		_build_sell(left, right)
	else:
		_build_buy(left, right)
	var msg := UiKit.label(_msg, _msg_color)
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	msg.custom_minimum_size = Vector2(INFO_W, 10)
	right.add_child(msg)


func _initial_focus() -> Button:
	if tab == &"sell" and sel_slot >= 0 and sel_slot < sell_cells.size():
		return sell_cells[sel_slot]
	if tab == &"buy" and buy_index >= 0 and buy_index < buy_buttons.size():
		return buy_buttons[buy_index]
	return null


# --- sell --------------------------------------------------------------------

func _build_sell(left: VBoxContainer, right: VBoxContainer) -> void:
	var inv := Game.run.inventory
	if sel_slot >= 0 and inv.id_at(sel_slot) == &"":
		sel_slot = _first_filled()
	elif sel_slot < 0:
		sel_slot = _first_filled()
	left.add_child(UiKit.label("Mochila %d/%d" % [inv.used(), inv.capacity], UiKit.COLOR_MUTED))
	var grid := GridContainer.new()
	grid.columns = GRID_COLS
	grid.add_theme_constant_override("h_separation", 2)
	grid.add_theme_constant_override("v_separation", 2)
	left.add_child(grid)
	for i in inv.capacity:
		var id := inv.id_at(i)
		var c := ItemCell.new().set_item(id, inv.qty_at(i))
		c.key = i
		c.set_selected(i == sel_slot)
		var trend := shop.trend(id) if id != &"" else 0
		if trend != 0:
			c.set_marker(TrendArrow.make(trend > 0))
		c.focus_entered.connect(select_sell.bind(i))
		c.activated.connect(_on_sell_activated.bind(i))
		grid.add_child(c)
		sell_cells.append(c)
	# Legend for the arrows (always visible, DP UX6).
	left.add_child(_legend(true, "Procurado hoje: +50%"))
	left.add_child(_legend(false, "Em baixa: vendeu demais"))

	var id := inv.id_at(sel_slot)
	if id == &"":
		_info.show_item(&"", [], "Nada para vender." if inv.is_empty() else "Escolha um item da mochila.")
		return
	_info.show_item(id, ItemCompare.compare(Game.run.equipment, id))
	var price_row := HBoxContainer.new()
	price_row.add_theme_constant_override("separation", 3)
	right.add_child(price_row)
	price_row.add_child(UiKit.label("Preço hoje: %d" % shop.sell_price(id), UiKit.COLOR_GOLD))
	var trend := shop.trend(id)
	if trend != 0:
		var a := TrendArrow.make(trend > 0)
		a.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		price_row.add_child(a)
		var base := ItemDB.price(id)
		var pct := roundi((float(shop.sell_price(id)) / base - 1.0) * 100.0) if trend > 0 and base > 0 \
				else roundi((1.0 - shop.factor(id)) * 100.0)
		price_row.add_child(UiKit.label("+%d%%" % pct if trend > 0 else "-%d%%" % pct,
				UiKit.COLOR_GOOD if trend > 0 else UiKit.COLOR_DANGER))
	var have := inv.qty_at(sel_slot)
	sell_qty = clampi(sell_qty, 1, have)
	if have > 1:
		var qty_row := HBoxContainer.new()
		qty_row.add_theme_constant_override("separation", 3)
		right.add_child(qty_row)
		qty_row.add_child(UiKit.label("Quantidade", UiKit.COLOR_MUTED))
		var minus := _small_button("-")
		minus.disabled = sell_qty <= 1
		minus.pressed.connect(set_qty.bind(-1, true))
		qty_row.add_child(minus)
		var n := UiKit.label("%d/%d" % [sell_qty, have], UiKit.COLOR_TEXT, HORIZONTAL_ALIGNMENT_CENTER)
		n.custom_minimum_size = Vector2(30, 0)
		qty_row.add_child(n)
		var plus := _small_button("+")
		plus.disabled = sell_qty >= have
		plus.pressed.connect(set_qty.bind(1, true))
		qty_row.add_child(plus)
	right.add_child(UiKit.label("Total: %d" % shop.sell_total(id, sell_qty), UiKit.COLOR_GOLD))
	var sell_text := "Vender %d" % sell_qty if sell_qty > 1 else "Vender"
	action_button = UiKit.button("Confirmar venda" if sell_armed else sell_text)
	action_button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	action_button.custom_minimum_size = Vector2(80, 0)
	action_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	action_button.pressed.connect(_on_sell_button)
	right.add_child(action_button)


func _legend(up: bool, text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 3)
	var a := TrendArrow.make(up)
	a.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(a)
	row.add_child(UiKit.label(text, UiKit.COLOR_MUTED))
	return row


func select_sell(slot: int) -> void:
	if slot == sel_slot:
		return
	sel_slot = slot
	sell_qty = 1
	sell_armed = false
	_msg = ""
	refresh()


## A press on a cell only selects it: selling is always the button.
func _on_sell_activated(slot: int) -> void:
	select_sell(slot)
	if action_button != null and action_button.is_inside_tree():
		_grab.call_deferred(action_button)


## Materials sell at once; gear and relics ask for a second press.
func _on_sell_button() -> void:
	var id := Game.run.inventory.id_at(sel_slot)
	if id == &"":
		return
	if ItemDB.kind(id) != &"material" and not sell_armed:
		sell_armed = true
		_msg = "Aperte de novo: a loja não devolve."
		_msg_color = UiKit.COLOR_TITLE
		refresh()
		return
	sell_selected()


## `n` units (absolute), or a step of `n` when `relative`.
func set_qty(n: int, relative: bool = false) -> void:
	var have := Game.run.inventory.qty_at(sel_slot)
	sell_qty = clampi(sell_qty + n if relative else n, 1, maxi(have, 1))
	sell_armed = false
	refresh()


## Sells sell_qty units of the selected slot. Returns the gold received.
func sell_selected() -> int:
	var run := Game.run
	var id := run.inventory.id_at(sel_slot)
	if id == &"":
		return 0
	var n := mini(sell_qty, run.inventory.qty_at(sel_slot))
	var got := shop.sell_many(run, sel_slot, n)
	if got > 0:
		_msg = "Vendeu %s%s por %d." % [UiKit.item_name(id), " x%d" % n if n > 1 else "", got]
		_msg_color = UiKit.COLOR_GOLD
	sell_qty = 1
	sell_armed = false
	refresh()
	return got


func _first_filled() -> int:
	var inv := Game.run.inventory
	for i in inv.capacity:
		if inv.id_at(i) != &"":
			return i
	return -1


# --- buy ---------------------------------------------------------------------

func _build_buy(left: VBoxContainer, right: VBoxContainer) -> void:
	var run := Game.run
	var list := buy_list()
	if buy_index >= list.size():
		buy_index = list.size() - 1
	if buy_index < 0 and not list.is_empty():
		buy_index = 0
	left.add_child(UiKit.label("Estoque de hoje", UiKit.COLOR_MUTED))
	if list.is_empty():
		left.add_child(UiKit.label("Esgotado", UiKit.COLOR_MUTED))
	for i in list.size():
		var id := list[i]
		var b := _item_button(id, price_of(id))
		b.toggle_mode = true
		b.set_pressed_no_signal(i == buy_index)
		b.focus_entered.connect(select_buy.bind(i))
		b.pressed.connect(_on_buy_pressed.bind(i))
		left.add_child(b)
		buy_buttons.append(b)
	if buy_index < 0:
		_info.show_item(&"", [], "Volte depois de subir a torre.")
		return
	var id := list[buy_index]
	var note := "Vai para o guarda-roupa." if ItemDB.kind(id) == &"outfit" else ""
	_info.show_item(id, ItemCompare.compare(run.equipment, id), note)
	var price := price_of(id)
	right.add_child(UiKit.label("Preço: %d" % price, UiKit.COLOR_GOLD if price <= run.gold else UiKit.COLOR_DANGER))
	var why := buy_block_reason(id)
	action_button = UiKit.button("Comprar")
	action_button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	action_button.custom_minimum_size = Vector2(80, 0)
	action_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	action_button.disabled = why != ""
	action_button.pressed.connect(buy_selected)
	right.add_child(action_button)
	if why != "":
		right.add_child(UiKit.label(why, UiKit.COLOR_DANGER))


func price_of(id: StringName) -> int:
	return shop.buy_price(id)


## "" when `id` can be bought now.
func buy_block_reason(id: StringName) -> String:
	if price_of(id) > Game.run.gold:
		return "Ouro insuficiente"
	if ItemDB.kind(id) != &"outfit" and Game.run.inventory.free_slots() <= 0:
		return "Mochila cheia"
	return ""


func select_buy(i: int) -> void:
	if i == buy_index:
		return
	buy_index = i
	_msg = ""
	refresh()


func _on_buy_pressed(i: int) -> void:
	if i != buy_index:
		select_buy(i)
	else:
		refresh()


## Buys the selected entry: stock goes to the backpack, an outfit unlocks.
func buy_selected() -> bool:
	var list := buy_list()
	if buy_index < 0 or buy_index >= list.size():
		return false
	var id := list[buy_index]
	var why := buy_block_reason(id)
	var ok := false
	if why == "":
		if ItemDB.kind(id) == &"outfit":
			ok = shop.buy_outfit(Game.run, id)
		else:
			ok = shop.buy(Game.run, shop.stock.find(id))
	if ok:
		_msg = "Comprou %s." % UiKit.item_name(id)
		_msg_color = UiKit.COLOR_ITEM
	else:
		_msg = why if why != "" else "Não deu para comprar."
		_msg_color = UiKit.COLOR_DANGER
	refresh()
	return ok


## Icon + name on the left, price on the right (red when too expensive).
func _item_button(id: StringName, price: int) -> Button:
	var b := UiKit.button(UiKit.item_name(id), UiKit.item_icon(id))
	b.custom_minimum_size = Vector2(LIST_W, 20)
	b.clip_text = true
	b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	b.add_theme_color_override("font_color", UiKit.rarity_color(id))
	var p := UiKit.label(str(price), UiKit.COLOR_GOLD if price <= Game.run.gold else UiKit.COLOR_DANGER, HORIZONTAL_ALIGNMENT_RIGHT)
	p.set_anchors_preset(Control.PRESET_FULL_RECT)
	p.offset_right = -6
	p.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(p)
	for state: StringName in [&"normal", &"hover", &"pressed", &"hover_pressed", &"disabled"]:
		var sb := b.get_theme_stylebox(state).duplicate() as StyleBox
		sb.content_margin_right = 30
		b.add_theme_stylebox_override(state, sb)
	return b


func _small_button(text: String) -> Button:
	var b := UiKit.button(text)
	b.alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.custom_minimum_size = Vector2(18, 0)
	return b
