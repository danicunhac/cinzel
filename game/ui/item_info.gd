class_name ItemInfo
extends VBoxContainer
## Tooltip body shared by the backpack, shop, forge and wardrobe: name in its
## rarity colour, kind and rarity, description, then stat rows (ItemCompare)
## with green/red arrows when they compare with the gear worn now.

var width: float = 150.0


func _init(w: float = 150.0) -> void:
	width = w
	custom_minimum_size = Vector2(w, 0)
	add_theme_constant_override("separation", 2)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func clear() -> void:
	for c in get_children():
		remove_child(c)
		c.queue_free()


## `rows` from ItemCompare.compare (arrows) or ItemCompare.own (no arrows).
func show_item(id: StringName, rows: Array[Dictionary] = [], note: String = "") -> void:
	clear()
	if id == &"" or not ItemDB.has(id):
		if note != "":
			add_child(_wrap(note, UiKit.COLOR_MUTED))
		return
	add_child(_wrap(UiKit.item_name(id), UiKit.rarity_color(id)))
	add_child(UiKit.label(UiKit.kind_line(id), UiKit.COLOR_MUTED))
	add_child(_wrap(String(ItemDB.get_def(id)["desc"]), UiKit.COLOR_TEXT))
	if not rows.is_empty():
		add_child(stat_grid(rows))
	if note != "":
		add_child(_wrap(note, UiKit.COLOR_MUTED))


## Label | value ("10 > 13", green or red) | arrow.
func stat_grid(rows: Array[Dictionary]) -> GridContainer:
	var g := GridContainer.new()
	g.columns = 3
	g.add_theme_constant_override("h_separation", 4)
	g.add_theme_constant_override("v_separation", 0)
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for r in rows:
		var delta := int(r["delta"])
		var l := UiKit.label(String(r["label"]), UiKit.COLOR_MUTED)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		g.add_child(l)
		var old := String(r["old"])
		var value := String(r["new"]) if old == "" else "%s > %s" % [old, r["new"]]
		var color := UiKit.COLOR_TEXT
		if delta > 0:
			color = UiKit.COLOR_GOOD
		elif delta < 0:
			color = UiKit.COLOR_DANGER
		g.add_child(UiKit.label(value, color, HORIZONTAL_ALIGNMENT_RIGHT))
		if delta != 0:
			var a := TrendArrow.make(delta > 0)
			a.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			g.add_child(a)
		else:
			var gap := Control.new()
			gap.custom_minimum_size = Vector2(9, 6)
			g.add_child(gap)
	return g


func _wrap(text: String, color: Color) -> Label:
	var l := UiKit.label(text, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(width, 0)
	return l
