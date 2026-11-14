class_name SmithPanel
extends UiPanel
## Blacksmith: pick 2 inventory items, trade them for 1 random other item.

var shop: Shop
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _selected: Array[int] = []
var _msg: String = ""
var _msg_color: Color = UiKit.COLOR_MUTED
var trade_button: Button


func _init() -> void:
	super._init()
	panel_size = Vector2(220, 150)
	rng.randomize()


func _build(box: VBoxContainer) -> void:
	var run := Game.run
	box.add_child(UiKit.label("Ferreiro", UiKit.COLOR_TITLE))
	box.add_child(UiKit.label("Troca 2 itens por 1 aleatório.", UiKit.COLOR_MUTED))
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 2)
	box.add_child(list)
	for slot in RunState.SLOTS:
		if slot < run.items.size():
			var id: StringName = run.items[slot]
			var picked := slot in _selected
			var b := UiKit.button(("[x] " if picked else "[ ] ") + UiKit.item_name(id), UiKit.item_icon(id))
			b.toggle_mode = true
			b.custom_minimum_size = Vector2(204, 20)
			b.set_pressed_no_signal(picked)
			b.toggled.connect(_toggle.bind(slot))
			list.add_child(b)
		else:
			var empty := UiKit.label("(espaço vazio)", UiKit.COLOR_MUTED)
			empty.custom_minimum_size = Vector2(204, 20)
			empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			list.add_child(empty)
	trade_button = UiKit.button("Trocar (%d/2)" % _selected.size())
	trade_button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	trade_button.disabled = not shop.can_trade(run) or _selected.size() != 2
	trade_button.pressed.connect(_trade)
	box.add_child(trade_button)
	if not shop.can_trade(run) and _msg == "":
		box.add_child(UiKit.label("Precisa de pelo menos 2 itens.", UiKit.COLOR_DANGER))
	else:
		box.add_child(UiKit.label(_msg, _msg_color))


func _toggle(on: bool, slot: int) -> void:
	if on and slot not in _selected:
		_selected.append(slot)
		if _selected.size() > 2:
			_selected.pop_front()
	elif not on:
		_selected.erase(slot)
	_msg = ""
	refresh()


func _trade() -> void:
	if _selected.size() != 2:
		return
	var got := shop.trade(Game.run, _selected[0], _selected[1], rng)
	_selected.clear()
	if got != &"":
		_msg = "Recebeu: %s" % UiKit.item_name(got)
		_msg_color = UiKit.COLOR_ITEM
	refresh()
