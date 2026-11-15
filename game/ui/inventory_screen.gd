class_name InventoryScreen
extends UiPanel
## Backpack and equipment (Tab, or "Mochila" in the pause menu). It pauses the
## tree, so the run clock stops while it is open.
## Left: the hero as he looks now (outfit, armor, helm and weapon) with the equipment
## slots around him. Middle: the backpack grid. Right: the tooltip of the
## item under the cursor, compared with what is worn (green/red arrows).
## Actions: equip (E, or a second press on the item), take off, and drop (X).
## Dropping works in the tower only: the stack falls at the player's feet as
## a pickup. In town dropping is disabled (sell at the shop instead).
## The outfit is read-only here; it changes at the wardrobe in town.

const PickupScene := preload("res://world/pickup_item.tscn")
const GRID_COLS := 5
const DOLL_W := 128.0
const INFO_W := 148.0
const TOWN_DROP_TEXT := "Na cidade não dá para largar: venda na loja."
## Doll slots: [kind, relic index, position in the doll box].
const DOLL: Array = [
	[&"weapon", 0, Vector2(0, 8)],
	[&"armor", 0, Vector2(0, 34)],
	[&"helm", 0, Vector2(0, 60)],
	[&"backpack", 0, Vector2(106, 8)],
	[&"outfit", 0, Vector2(106, 34)],
	[&"relic", 0, Vector2(28, 98)],
	[&"relic", 1, Vector2(53, 98)],
	[&"relic", 2, Vector2(78, 98)],
]
## Faded icon in an empty slot, so its kind reads without words.
const HINT_ICON: Dictionary[StringName, StringName] = {
	&"weapon": &"sword_iron", &"armor": &"armor_cloth", &"helm": &"helm_hood",
	&"backpack": &"backpack_small", &"outfit": &"outfit_starter", &"relic": &"glass_shield",
}

## True in town: drop is disabled.
var in_town: bool = true
## Cursor: &"bag" (sel_slot) or &"doll" (sel_kind, sel_relic).
var sel_where: StringName = &"bag"
var sel_slot: int = 0
var sel_kind: StringName = &""
var sel_relic: int = 0
## A relic waiting for the equipped relic it replaces (all 3 are taken).
var relic_pick: StringName = &""
var bag_cells: Array[ItemCell] = []
var doll_cells: Array[ItemCell] = []
var primary_button: Button
var drop_button: Button
var hero: LayeredSprite

var _info: ItemInfo
var _msg: String = ""
var _msg_color: Color = UiKit.COLOR_MUTED
var _msg_label: Label
var _hover: ItemCell = null


func _init() -> void:
	super._init()
	# Fixed size, as tall as the longest item text: a window that grew with
	# the hovered item slid the cells under the mouse and flickered.
	panel_size = Vector2(458, 224)
	panel_title = "Mochila"
	close_hint = "Tab: fechar   E: equipar   X: largar"
	close_actions = [&"ui_cancel", &"pause"]


func _build(box: VBoxContainer) -> void:
	var run := Game.run
	bag_cells.clear()
	doll_cells.clear()
	_hover = null
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 10)
	box.add_child(cols)
	_build_doll(run, cols)
	cols.add_child(_build_bag(run))
	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(INFO_W, 0)
	right.add_theme_constant_override("separation", 4)
	cols.add_child(right)
	_info = ItemInfo.new(INFO_W)
	_info.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(_info)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 4)
	right.add_child(actions)
	primary_button = UiKit.button("Equipar")
	primary_button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	primary_button.custom_minimum_size = Vector2(72, 0)
	primary_button.pressed.connect(primary)
	actions.add_child(primary_button)
	drop_button = UiKit.button("Largar")
	drop_button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	drop_button.custom_minimum_size = Vector2(72, 0)
	drop_button.pressed.connect(drop)
	actions.add_child(drop_button)
	_msg_label = UiKit.label(_msg, _msg_color)
	_msg_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_msg_label.custom_minimum_size = Vector2(INFO_W, 20)
	right.add_child(_msg_label)
	_show_selection()


## Added to `parent` first, so the hero sprite is in the tree (its _ready
## builds the layers) before it is dressed.
func _build_doll(run: RunState, parent: Control) -> void:
	var doll := Control.new()
	doll.custom_minimum_size = Vector2(DOLL_W, 150)
	parent.add_child(doll)
	var portrait := UiKit.plaque(Vector2(76, 86))
	portrait.position = Vector2(26, 2)
	doll.add_child(portrait)
	var holder := Node2D.new()
	holder.position = Vector2(64, 44)
	holder.scale = Vector2(2, 2)
	doll.add_child(holder)
	holder.add_child(GroundShadow.make(Vector2i(16, 6), Vector2(0, 14)))
	hero = LayeredSprite.new()
	holder.add_child(hero)
	hero.dress(run.equipment)
	hero.play(&"idle", Vector2.DOWN)
	var relic_label := UiKit.label("Relíquias", UiKit.COLOR_MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	relic_label.position = Vector2(0, 87)
	relic_label.size = Vector2(DOLL_W, 10)
	doll.add_child(relic_label)
	for d: Array in DOLL:
		var kind: StringName = d[0]
		var id := run.equipment.get_slot(kind, d[1])
		var hint := UiKit.item_icon(HINT_ICON[kind])
		var c := ItemCell.new().set_item(id, 1, hint)
		c.key = [kind, d[1]]
		c.position = d[2]
		if kind == &"outfit":
			c.set_dim(true)
		if relic_pick != &"" and kind == &"relic":
			c.set_marker(TrendArrow.make(false, UiKit.COLOR_TITLE))
		c.focus_entered.connect(select_doll.bind(kind, int(d[1])))
		c.activated.connect(_on_doll_activated.bind(kind, int(d[1])))
		c.hovered.connect(_on_hover.bind(c))
		c.set_selected(sel_where == &"doll" and sel_kind == kind and sel_relic == d[1])
		doll.add_child(c)
		doll_cells.append(c)
	var s := run.stats()
	var stats := UiKit.label("Vida %d  Def %d\nDano %d  Crit %d%%" % [s.max_hp, s.defense, s.damage, roundi(s.crit_chance * 100.0)],
			UiKit.COLOR_TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	stats.position = Vector2(0, 124)
	stats.size = Vector2(DOLL_W, 22)
	doll.add_child(stats)


func _build_bag(run: RunState) -> Control:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	var inv := run.inventory
	var head := UiKit.label("Mochila %d/%d" % [inv.used(), inv.capacity],
			UiKit.COLOR_DANGER if inv.is_full() else UiKit.COLOR_MUTED)
	col.add_child(head)
	var grid := GridContainer.new()
	grid.columns = GRID_COLS
	grid.add_theme_constant_override("h_separation", 2)
	grid.add_theme_constant_override("v_separation", 2)
	col.add_child(grid)
	for i in inv.capacity:
		var c := ItemCell.new().set_item(inv.id_at(i), inv.qty_at(i))
		c.key = i
		c.focus_entered.connect(select_bag.bind(i))
		c.activated.connect(_on_bag_activated.bind(i))
		c.hovered.connect(_on_hover.bind(c))
		c.set_selected(sel_where == &"bag" and sel_slot == i)
		grid.add_child(c)
		bag_cells.append(c)
	return col


func _initial_focus() -> Button:
	return bag_cells[clampi(sel_slot, 0, bag_cells.size() - 1)] if not bag_cells.is_empty() else null


# --- selection and tooltip ---------------------------------------------------

func select_bag(slot: int) -> void:
	sel_where = &"bag"
	sel_slot = clampi(slot, 0, Game.run.inventory.capacity - 1)
	_show_selection()


func select_doll(kind: StringName, relic_slot: int = 0) -> void:
	sel_where = &"doll"
	sel_kind = kind
	sel_relic = relic_slot
	_show_selection()


## Item under the cursor (&"" for an empty slot).
func selected_id() -> StringName:
	if sel_where == &"bag":
		return Game.run.inventory.id_at(sel_slot)
	return Game.run.equipment.get_slot(sel_kind, sel_relic)


func _show_selection() -> void:
	if _info == null:
		return
	for c in bag_cells:
		c.set_selected(sel_where == &"bag" and c.key == sel_slot)
	for c in doll_cells:
		var k: Array = c.key
		c.set_selected(sel_where == &"doll" and k[0] == sel_kind and k[1] == sel_relic)
	if _hover != null and is_instance_valid(_hover):
		_show_cell(_hover)
	else:
		_show_info(sel_where, selected_id(), sel_kind)
	_update_actions()


func _on_hover(inside: bool, c: ItemCell) -> void:
	_hover = c if inside else null
	if inside:
		_show_cell(c)
	else:
		_show_info(sel_where, selected_id(), sel_kind)


func _show_cell(c: ItemCell) -> void:
	if c.key is Array:
		_show_info(&"doll", c.item_id, (c.key as Array)[0])
	else:
		_show_info(&"bag", c.item_id, &"")


func _show_info(where: StringName, id: StringName, kind: StringName) -> void:
	var eq := Game.run.equipment
	if id == &"":
		var empty := "Espaço vazio" if where == &"bag" else "%s: vazio" % UiKit.KIND_NAME.get(kind, "")
		_info.show_item(&"", [], empty)
		return
	if where == &"doll":
		var note := "Troque no guarda-roupa da cidade." if kind == &"outfit" else "Equipado"
		_info.show_item(id, ItemCompare.own(id), note)
		return
	var rows := ItemCompare.compare(eq, id)
	var note := ""
	match ItemDB.kind(id):
		&"material":
			note = "Material de forja. Vende na loja."
		&"relic":
			note = "Soma às relíquias." if eq.relics.size() < Equipment.RELIC_SLOTS else "Troca por uma relíquia."
	if rows.is_empty() and Equipment.SLOT_KINDS.has(ItemDB.kind(id)) and ItemDB.kind(id) != &"relic":
		note = "Igual ao equipado."
	_info.show_item(id, rows, note)


# --- actions -----------------------------------------------------------------

## What the primary button does now: &"equip", &"unequip", &"pick" (choose
## the relic to replace), &"cancel" (leave relic choice) or &"" (nothing).
func primary_kind() -> StringName:
	if relic_pick != &"":
		return &"pick" if sel_where == &"doll" and sel_kind == &"relic" else &"cancel"
	var id := selected_id()
	if id == &"":
		return &""
	if sel_where == &"bag":
		return &"equip" if Equipment.SLOT_KINDS.has(ItemDB.kind(id)) else &""
	return &"unequip" if sel_kind in [&"armor", &"helm", &"relic"] else &""


## Equip, take off or finish the relic swap, by what is selected.
func primary() -> bool:
	match primary_kind():
		&"equip":
			return equip_selected()
		&"unequip":
			return unequip_selected()
		&"pick":
			return _finish_relic_pick(sel_relic)
		&"cancel":
			relic_pick = &""
			_set_msg("", UiKit.COLOR_MUTED)
			refresh()
	return false


func equip_selected() -> bool:
	var run := Game.run
	var id := selected_id()
	if sel_where != &"bag" or id == &"":
		return false
	if ItemDB.kind(id) == &"relic" and run.equipment.relics.size() >= Equipment.RELIC_SLOTS:
		relic_pick = id
		_set_msg("Escolha a relíquia que sai.", UiKit.COLOR_TITLE)
		refresh()
		_focus_doll(&"relic", 0)
		return false
	var ok := run.equip(id)
	if ok:
		_set_msg("Equipou %s." % UiKit.item_name(id), UiKit.COLOR_ITEM)
	elif ItemDB.kind(id) == &"backpack":
		_set_msg("Os itens não cabem nessa mochila.", UiKit.COLOR_DANGER)
	else:
		_set_msg("Não dá para equipar.", UiKit.COLOR_DANGER)
	refresh()
	return ok


func unequip_selected() -> bool:
	var run := Game.run
	if sel_where != &"doll":
		return false
	var id := selected_id()
	if id == &"":
		return false
	if not (sel_kind in [&"armor", &"helm", &"relic"]):
		_set_msg("Só dá para trocar por outro.", UiKit.COLOR_DANGER)
		refresh()
		return false
	var ok := run.unequip(sel_kind, sel_relic)
	if ok:
		_set_msg("Guardou %s." % UiKit.item_name(id), UiKit.COLOR_ITEM)
		if sel_kind == &"relic" and run.equipment.relics.size() <= sel_relic:
			sel_relic = maxi(run.equipment.relics.size() - 1, 0)
	else:
		_set_msg("Mochila cheia.", UiKit.COLOR_DANGER)
	refresh()
	return ok


## Drops the whole stack of the selected backpack slot at the player's feet
## (tower only). Returns false in town or when nothing is selected.
func drop() -> bool:
	if sel_where != &"bag" or selected_id() == &"":
		return false
	if in_town:
		_set_msg(TOWN_DROP_TEXT, UiKit.COLOR_DANGER)
		refresh()
		return false
	var taken := Game.run.inventory.take_slot(sel_slot)
	if _spawn_drop(taken["id"], int(taken["qty"])) == null:
		Game.run.inventory.slots[sel_slot] = taken
		_set_msg("Nada para largar aqui.", UiKit.COLOR_DANGER)
		refresh()
		return false
	Game.run.changed.emit()
	_set_msg("Largou %s." % UiKit.item_name(taken["id"]), UiKit.COLOR_MUTED)
	refresh()
	return true


## Pickup at the player's feet, in the current room when there is one.
## It waits for the player to step off before it can be taken again.
func _spawn_drop(id: StringName, qty: int) -> PickupItem:
	var player := get_tree().get_first_node_in_group(&"player") as Node2D
	if player == null:
		return null
	var host: Node = player.get_parent()
	var d := host as Dungeon
	if d != null and d.room != null:
		host = d.room
	var p := PickupScene.instantiate() as PickupItem
	p.item_id = id
	p.qty = qty
	p.wait_exit = true
	host.add_child(p)
	p.global_position = player.global_position + Vector2(0, 4)
	return p


func _finish_relic_pick(relic_slot: int) -> bool:
	var id := relic_pick
	relic_pick = &""
	var old := Game.run.equipment.get_slot(&"relic", relic_slot)
	var ok := Game.run.equip(id, relic_slot)
	if ok:
		_set_msg("Trocou %s por %s." % [UiKit.item_name(old), UiKit.item_name(id)], UiKit.COLOR_ITEM)
	refresh()
	return ok


func _on_bag_activated(slot: int) -> void:
	select_bag(slot)
	primary()


func _on_doll_activated(kind: StringName, relic_slot: int) -> void:
	select_doll(kind, relic_slot)
	primary()


func _update_actions() -> void:
	if primary_button == null:
		return
	var k := primary_kind()
	var labels := {&"equip": "Equipar", &"unequip": "Tirar", &"pick": "Trocar", &"cancel": "Cancelar"}
	primary_button.text = labels.get(k, "Tirar" if sel_where == &"doll" else "Equipar")
	primary_button.disabled = k == &""
	drop_button.disabled = sel_where != &"bag" or selected_id() == &"" or in_town or relic_pick != &""
	# Why "Largar" is off in town, before anyone tries it.
	if in_town and _msg == "" and _msg_label != null:
		_msg_label.text = TOWN_DROP_TEXT
		_msg_label.add_theme_color_override("font_color", UiKit.COLOR_MUTED)


func _focus_doll(kind: StringName, relic_slot: int) -> void:
	for c in doll_cells:
		var k: Array = c.key
		if k[0] == kind and k[1] == relic_slot:
			_grab.call_deferred(c)


func _set_msg(text: String, color: Color) -> void:
	_msg = text
	_msg_color = color


# --- input -------------------------------------------------------------------

## Tab is also the GUI's focus-next key, so it is read before the GUI.
func _input(event: InputEvent) -> void:
	if is_open() and event.is_action_pressed(&"inventory"):
		get_viewport().set_input_as_handled()
		close()


func _unhandled_input(event: InputEvent) -> void:
	if not is_open():
		return
	if relic_pick != &"" and event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		relic_pick = &""
		_set_msg("", UiKit.COLOR_MUTED)
		refresh()
		return
	if event.is_action_pressed(&"interact"):
		get_viewport().set_input_as_handled()
		primary()
		return
	if event.is_action_pressed(&"drop", false, true):
		get_viewport().set_input_as_handled()
		drop()
		return
	super._unhandled_input(event)
