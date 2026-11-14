class_name WardrobePanel
extends UiPanel
## Wardrobe in the hero's house (town). The outfits are visual only: the
## cursor previews one on the hero (idle facing down, with the weapon worn
## now); "Vestir" wears it. Locked outfits show greyed, with where to get
## them. The worn outfit survives death (RunState.die keeps it).
## "Mostrar armadura" (on by default) draws the equipped armor and helm over
## the outfit; off shows the outfit alone. The preview follows it, and the
## choice survives death like the outfit.

const GRID_COLS := 5
const INFO_W := 150.0
const UNLOCK_TEXT: Dictionary[StringName, String] = {
	&"market": "À venda na loja.",
	&"chest": "Achada em baús da torre.",
	&"boss": "Prêmio do primeiro chefe.",
	&"start": "",
}

var outfit_cells: Array[ItemCell] = []
var wear_button: Button
var armor_toggle: CheckBox
## Outfit under the cursor (shown on the preview).
var preview_id: StringName = &""
var hero: LayeredSprite

var _info: ItemInfo


func _init() -> void:
	super._init()
	panel_size = Vector2(320, 0)
	panel_title = "Guarda-roupa"


func _build(box: VBoxContainer) -> void:
	var run := Game.run
	outfit_cells.clear()
	if preview_id == &"":
		preview_id = run.equipment.outfit
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 10)
	box.add_child(cols)

	# Preview: the hero at 3x on a plaque, the armor toggle under it.
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 4)
	cols.add_child(left)
	var stage := Control.new()
	stage.custom_minimum_size = Vector2(112, 124)
	left.add_child(stage)
	var plate := UiKit.plaque(Vector2(112, 124))
	stage.add_child(plate)
	var holder := Node2D.new()
	holder.position = Vector2(56, 58)
	holder.scale = Vector2(3, 3)
	stage.add_child(holder)
	holder.add_child(GroundShadow.make(Vector2i(16, 6), Vector2(0, 14)))
	hero = LayeredSprite.new()
	holder.add_child(hero)
	hero.dress(run.equipment)
	hero.set_outfit(preview_id)
	hero.play(&"idle", Vector2.DOWN)
	armor_toggle = CheckBox.new()
	armor_toggle.text = "Mostrar armadura"
	armor_toggle.focus_mode = Control.FOCUS_ALL
	armor_toggle.set_pressed_no_signal(run.equipment.show_armor)
	armor_toggle.toggled.connect(set_show_armor)
	left.add_child(armor_toggle)

	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(INFO_W, 0)
	right.add_theme_constant_override("separation", 4)
	cols.add_child(right)
	var grid := GridContainer.new()
	grid.columns = GRID_COLS
	grid.add_theme_constant_override("h_separation", 2)
	right.add_child(grid)
	for id: StringName in ItemDB.ids(&"outfit"):
		var c := ItemCell.new().set_item(id)
		c.key = id
		c.set_dim(not run.unlocked_outfits.has(id))
		if id == run.equipment.outfit:
			c.set_marker(ItemCell.dot(UiKit.COLOR_TITLE))
		elif not run.unlocked_outfits.has(id):
			c.set_marker(ItemCell.lock_mark())
		c.set_selected(id == preview_id)
		c.focus_entered.connect(preview.bind(id))
		c.activated.connect(_on_activated.bind(id))
		c.hovered.connect(func(inside: bool) -> void:
				if inside:
					preview(id))
		grid.add_child(c)
		outfit_cells.append(c)
	_info = ItemInfo.new(INFO_W)
	right.add_child(_info)
	wear_button = UiKit.button("Vestir")
	wear_button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	wear_button.custom_minimum_size = Vector2(70, 0)
	wear_button.pressed.connect(func() -> void: wear(preview_id))
	right.add_child(wear_button)
	_show(preview_id)


func _initial_focus() -> Button:
	for c in outfit_cells:
		if c.key == preview_id:
			return c
	return null


## Shows `id` on the hero and in the info box.
func preview(id: StringName) -> void:
	preview_id = id
	for c in outfit_cells:
		c.set_selected(c.key == id)
	if hero != null:
		hero.set_outfit(id)
		hero.play(&"idle", Vector2.DOWN)
	_show(id)


func _show(id: StringName) -> void:
	var run := Game.run
	var owned := run.unlocked_outfits.has(id)
	var note := ""
	if id == run.equipment.outfit:
		note = "Vestindo agora."
	elif not owned:
		note = "Bloqueada. " + UNLOCK_TEXT.get(ItemCatalog.ITEMS[id]["unlock"], "")
	_info.show_item(id, [], note)
	wear_button.disabled = not owned or id == run.equipment.outfit
	wear_button.text = "Vestindo" if id == run.equipment.outfit else "Vestir"


func _on_activated(id: StringName) -> void:
	if id != preview_id:
		preview(id)
	else:
		wear(id)


## Armor and helm over the outfit (on) or the outfit alone (off), on the
## run and on the preview.
func set_show_armor(on: bool) -> void:
	Game.run.set_show_armor(on)
	if armor_toggle != null:
		armor_toggle.set_pressed_no_signal(on)
	if hero != null:
		var e := Game.run.equipment
		hero.set_gear(e.armor, e.helm, on)


## Wears an unlocked outfit (cosmetic). Returns false when it is locked.
func wear(id: StringName) -> bool:
	var ok := Game.run.set_outfit(id)
	refresh()
	return ok
