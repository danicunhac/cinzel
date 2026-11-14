class_name TeleportPanel
extends UiPanel
## Teleport stone: lists floors 1..unlocked_floors and enters the chosen one.

signal floor_chosen(floor_num: int)

var floor_buttons: Array[Button] = []
## Tests set this to false to keep the scene from changing.
var travel: bool = true


func _init() -> void:
	super._init()
	panel_size = Vector2(200, 0)
	panel_title = "Pedra de teleporte"


func _build(box: VBoxContainer) -> void:
	floor_buttons.clear()
	box.add_child(UiKit.label("Escolha um andar liberado.", UiKit.COLOR_MUTED))
	for n in range(1, Game.run.unlocked_floors + 1):
		var built := not Dungeon.templates_for(n).is_empty()
		var b := UiKit.button("Andar %d" % n if built else "Andar %d (em breve)" % n)
		b.alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.custom_minimum_size = Vector2(184, 16)
		b.disabled = not built
		b.pressed.connect(_choose.bind(n))
		box.add_child(b)
		floor_buttons.append(b)


func _choose(n: int) -> void:
	floor_chosen.emit(n)
	close()
	if travel:
		Dungeon.requested_floor = n
		Game.goto(Dungeon.SCENE)
