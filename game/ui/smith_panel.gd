class_name SmithPanel
extends UiPanel
## Blacksmith: the unlocked Forge recipes as a grid of results (greyed when
## they cannot be made now). The recipe under the cursor shows the result
## with its stats against the gear worn, each material with its icon and
## have/need (red when short), the gold cost, and "Forjar", disabled with
## the reason (materials, gold, full backpack). The result goes to the
## backpack.

const GRID_COLS := 4
const LIST_W := 130.0
const INFO_W := 200.0

## Cells of the unlocked recipes, in Forge.unlocked order.
var recipe_buttons: Array[ItemCell] = []
var selected: int = 0
var craft_button: Button
var reason: String = ""
## First press on "Forjar" arms it; the second forges.
var armed: bool = false

var _recipes: Array[StringName] = []
var _msg: String = ""
var _msg_color: Color = UiKit.COLOR_MUTED


func _init() -> void:
	super._init()
	panel_size = Vector2(372, 214)
	panel_title = "Ferreiro"


func _build(box: VBoxContainer) -> void:
	var run := Game.run
	recipe_buttons.clear()
	_recipes = Forge.unlocked(run.floors_beaten)
	selected = clampi(selected, 0, maxi(_recipes.size() - 1, 0))
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 10)
	box.add_child(cols)

	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(LIST_W, 0)
	left.add_theme_constant_override("separation", 3)
	cols.add_child(left)
	left.add_child(UiKit.label("Receitas", UiKit.COLOR_MUTED))
	var grid := GridContainer.new()
	grid.columns = GRID_COLS
	grid.add_theme_constant_override("h_separation", 2)
	grid.add_theme_constant_override("v_separation", 2)
	left.add_child(grid)
	for i in _recipes.size():
		var r: Dictionary = Forge.RECIPES[_recipes[i]]
		var c := ItemCell.new().set_item(r["result"])
		c.key = i
		var ok := Forge.can_craft(run, _recipes[i])
		c.set_dim(not ok)
		if ok:
			c.set_marker(TrendArrow.make(true))
		c.set_selected(i == selected)
		c.focus_entered.connect(select.bind(i))
		c.activated.connect(_on_activated.bind(i))
		grid.add_child(c)
		recipe_buttons.append(c)
	var next := _next_unlock_floor(run.floors_beaten)
	if next > 0:
		var more := UiKit.label("Mais receitas após o chefe do andar %d." % next, UiKit.COLOR_MUTED)
		more.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		more.custom_minimum_size = Vector2(LIST_W, 0)
		left.add_child(more)
	left.add_child(UiKit.label("Ouro: %d" % run.gold, UiKit.COLOR_GOLD))

	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(INFO_W, 0)
	right.add_theme_constant_override("separation", 3)
	cols.add_child(right)
	if _recipes.is_empty():
		right.add_child(UiKit.label("Nenhuma receita ainda.", UiKit.COLOR_MUTED))
		return
	var id := _recipes[selected]
	var rec: Dictionary = Forge.RECIPES[id]
	var info := ItemInfo.new(INFO_W)
	info.show_item(rec["result"], ItemCompare.compare(run.equipment, rec["result"]))
	right.add_child(info)
	right.add_child(UiKit.label("Precisa", UiKit.COLOR_MUTED))
	var mats: Dictionary = rec["materials"]
	for m: StringName in mats:
		right.add_child(_material_row(m, run.inventory.count(m), int(mats[m])))
	var cost := int(rec["gold"])
	right.add_child(_gold_row(cost, run.gold))
	reason = Forge.block_reason(run, id)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	right.add_child(row)
	craft_button = UiKit.button("Confirmar" if armed else "Forjar")
	craft_button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	craft_button.custom_minimum_size = Vector2(60, 0)
	craft_button.disabled = reason != ""
	craft_button.pressed.connect(press_craft)
	row.add_child(craft_button)
	if reason != "":
		var why := UiKit.label(reason, UiKit.COLOR_DANGER)
		why.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(why)
	if _msg != "":
		right.add_child(UiKit.label(_msg, _msg_color))


## Icon, name and have/need (red when short).
func _material_row(m: StringName, have: int, need: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	var icon := TextureRect.new()
	icon.texture = UiKit.item_icon(m)
	icon.custom_minimum_size = Vector2(16, 16)
	row.add_child(icon)
	var name_l := UiKit.label(UiKit.item_name(m), UiKit.COLOR_TEXT)
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(name_l)
	var n := UiKit.label("%d/%d" % [have, need], UiKit.COLOR_GOOD if have >= need else UiKit.COLOR_DANGER, HORIZONTAL_ALIGNMENT_RIGHT)
	n.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(n)
	return row


func _gold_row(cost: int, gold: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	var icon := TextureRect.new()
	var coin := AtlasTexture.new()
	coin.atlas = Hud.COIN_TEX
	coin.region = Rect2(Vector2.ZERO, Hud.COIN_FRAME)
	icon.texture = coin
	icon.custom_minimum_size = Vector2(16, 9)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(icon)
	var name_l := UiKit.label("Ouro", UiKit.COLOR_TEXT)
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_l)
	row.add_child(UiKit.label("%d/%d" % [mini(gold, cost), cost], UiKit.COLOR_GOOD if gold >= cost else UiKit.COLOR_DANGER, HORIZONTAL_ALIGNMENT_RIGHT))
	return row


func _initial_focus() -> Button:
	return recipe_buttons[selected] if selected < recipe_buttons.size() else null


func _next_unlock_floor(beaten: int) -> int:
	var best := 0
	for id: StringName in Forge.RECIPES:
		var f := int(Forge.RECIPES[id]["floors"])
		if f > beaten and (best == 0 or f < best):
			best = f
	return best


func select(i: int) -> void:
	if i == selected:
		return
	selected = i
	armed = false
	_msg = ""
	refresh()


func _on_activated(i: int) -> void:
	if i != selected:
		select(i)
	elif craft_button != null and not craft_button.disabled:
		press_craft()


## Two-step forge: the first press arms ("Confirmar"), the second forges.
func press_craft() -> bool:
	if _recipes.is_empty() or Forge.block_reason(Game.run, _recipes[selected]) != "":
		armed = false
		return craft_selected()
	if not armed:
		armed = true
		_msg = "Aperte de novo para forjar."
		_msg_color = UiKit.COLOR_TITLE
		refresh()
		return false
	return craft_selected()


## Forges the selected recipe into the backpack.
func craft_selected() -> bool:
	if _recipes.is_empty():
		return false
	var id := _recipes[selected]
	var result: StringName = Forge.RECIPES[id]["result"]
	var why := Forge.block_reason(Game.run, id)
	armed = false
	var ok := why == "" and Forge.craft(Game.run, id)
	if ok:
		_msg = "Forjou: %s" % UiKit.item_name(result)
		_msg_color = UiKit.COLOR_ITEM
	else:
		_msg = why if why != "" else "Não deu para forjar."
		_msg_color = UiKit.COLOR_DANGER
	refresh()
	return ok
