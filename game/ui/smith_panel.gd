class_name SmithPanel
extends UiPanel
## Blacksmith: forge the unlocked recipes (Forge) with backpack materials and
## gold. Placeholder list until the screens are redone (E4).

var recipe_buttons: Array[Button] = []
var _recipes: Array[StringName] = []
var _desc: Label
var _msg: String = ""
var _msg_color: Color = UiKit.COLOR_MUTED


func _init() -> void:
	super._init()
	panel_size = Vector2(260, 0)
	panel_title = "Ferreiro"


func _build(box: VBoxContainer) -> void:
	var run := Game.run
	box.add_child(UiKit.label("Ouro: %d" % run.gold, UiKit.COLOR_GOLD))
	recipe_buttons.clear()
	_recipes = Forge.unlocked(run.floors_beaten)
	for id in _recipes:
		var r: Dictionary = Forge.RECIPES[id]
		var b := UiKit.button("%s (%d)" % [UiKit.item_name(r["result"]), int(r["gold"])], UiKit.item_icon(r["result"]))
		b.custom_minimum_size = Vector2(244, 20)
		b.disabled = not Forge.can_craft(run, id)
		b.pressed.connect(_craft.bind(id))
		var need := _needs_text(r)
		b.focus_entered.connect(func() -> void: _show_desc(need))
		b.mouse_entered.connect(func() -> void: _show_desc(need))
		box.add_child(b)
		recipe_buttons.append(b)
	_desc = UiKit.label("", UiKit.COLOR_ITEM)
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc.custom_minimum_size = Vector2(244, 18)
	box.add_child(_desc)
	box.add_child(UiKit.label(_msg, _msg_color))


func _needs_text(r: Dictionary) -> String:
	var parts: Array[String] = []
	var mats: Dictionary = r["materials"]
	for m: StringName in mats:
		parts.append("%d %s" % [int(mats[m]), UiKit.item_name(m)])
	return ", ".join(parts)


func _show_desc(text: String) -> void:
	if is_instance_valid(_desc):
		_desc.text = text


func _craft(id: StringName) -> void:
	var result: StringName = Forge.RECIPES[id]["result"]
	if Forge.craft(Game.run, id):
		_msg = "Forjou: %s" % UiKit.item_name(result)
		_msg_color = UiKit.COLOR_ITEM
	else:
		_msg = "Faltam materiais, ouro ou espaço."
		_msg_color = UiKit.COLOR_DANGER
	refresh()
