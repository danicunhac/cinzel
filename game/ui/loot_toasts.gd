class_name LootToasts
extends Control
## "+2 Gosma de Slime" toasts, top left under the life and gold: a plaque
## with the item icon in its rarity frame. They slide in, stack downward (at
## most MAX_VISIBLE; a new one pushes the oldest out) and fade after LIFE s.
## A pickup of an item that already has a toast adds to its count.

const MAX_VISIBLE := 3
const LIFE := 2.6
const FADE := 0.4
const ROW_H := 21.0
const BOX_H := 20.0

## Live toasts, oldest first: {"id", "qty", "box": NinePatchRect, "label", "life"}.
var toasts: Array[Dictionary] = []


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func push(id: StringName, qty: int) -> void:
	if not ItemDB.has(id) or qty <= 0:
		return
	for t in toasts:
		if t["id"] == id:
			t["qty"] = int(t["qty"]) + qty
			t["life"] = LIFE
			_set_text(t)
			(t["box"] as Control).modulate.a = 1.0
			return
	var box := UiKit.plaque(Vector2(40, BOX_H))
	add_child(box)
	var frame := TextureRect.new()
	frame.texture = ItemCell.FRAME_TEX.get(ItemDB.rarity(id))
	frame.position = Vector2(1, 1)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(frame)
	var icon := TextureRect.new()
	icon.texture = UiKit.item_icon(id)
	icon.position = Vector2(2, 2)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(icon)
	var label := UiKit.label("", UiKit.COLOR_ITEM)
	label.position = Vector2(22, 5)
	label.size = Vector2(10, 10)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(label)
	var t := {"id": id, "qty": qty, "box": box, "label": label, "life": LIFE}
	toasts.append(t)
	_set_text(t)
	while toasts.size() > MAX_VISIBLE:
		_remove(0)
	box.position = Vector2(0, (toasts.size() - 1) * ROW_H)
	UiKit.slide_in(box, Vector2(-box.size.x - 6, 0))
	_restack()


func _process(delta: float) -> void:
	var i := 0
	while i < toasts.size():
		var t := toasts[i]
		t["life"] = float(t["life"]) - delta
		var life: float = t["life"]
		if life <= 0.0:
			_remove(i)
			_restack()
			continue
		(t["box"] as Control).modulate.a = clampf(life / FADE, 0.0, 1.0)
		i += 1


func _set_text(t: Dictionary) -> void:
	var text := "+%d %s" % [int(t["qty"]), UiKit.item_name(t["id"])]
	var label := t["label"] as Label
	label.text = text
	var w := UiKit.text_width(text)
	label.size.x = w + 2
	(t["box"] as NinePatchRect).size.x = 22 + w + 6


func _remove(i: int) -> void:
	var box := toasts[i]["box"] as Control
	toasts.remove_at(i)
	box.queue_free()


## Moves every toast to its row (whole pixels), without replaying the slide.
func _restack() -> void:
	for i in toasts.size():
		var box := toasts[i]["box"] as Control
		var home := Vector2(0, i * ROW_H)
		box.set_meta(&"slide_home", home)
		var t := box.get_meta(&"slide_tween") as Tween if box.has_meta(&"slide_tween") else null
		if t == null or not t.is_valid() or not t.is_running():
			box.position = home
