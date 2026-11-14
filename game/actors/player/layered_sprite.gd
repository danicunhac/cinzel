class_name LayeredSprite
extends Node2D

## Sheets are COLS x 13 frames of FRAME_SIZE px; a strip uses the first
## FRAME_COUNT[anim] frames of its row. Feet sit on row FEET_ROW of the frame.
const FRAME_SIZE := 32
const COLS := 8
const VFRAMES := 13
const FEET_ROW := 30
const ROW_ORDER: Array[StringName] = [
	&"idle_down", &"idle_up", &"idle_side",
	&"walk_down", &"walk_up", &"walk_side",
	&"attack_down", &"attack_up", &"attack_side",
	&"roll_down", &"roll_up", &"roll_side",
	&"death",
]
const FRAME_COUNT: Dictionary[StringName, int] = {
	&"idle": 4, &"walk": 8, &"attack": 6, &"roll": 6, &"death": 6,
}
## Attack plays its 6 frames in about one swing (Player.SWING_TIME 0.27 s),
## roll in one roll (Player.ROLL_TIME 0.4 s).
const FPS: Dictionary[StringName, float] = {
	&"idle": 6.0, &"walk": 12.0, &"attack": 22.0, &"roll": 15.0, &"death": 9.0,
}
const LOOPING: Array[StringName] = [&"idle", &"walk"]
const LAYERS: Array[StringName] = [&"body", &"hair", &"outfit", &"weapon"]
const CLIMBER_DIR := "res://assets/characters/climber/"
## Layers whose attack rows a weapon type can replace (attacks/<type>_<layer>.png,
## 8x3 frames: attack_down, attack_up, attack_side).
const ATTACK_LAYERS: Array[StringName] = [&"body", &"hair", &"outfit"]
const ATTACK_ROW := 6

var speed_scale: float = 1.0
var anim: StringName = &""
var finished: bool = false

var _sprites: Dictionary = {}
## Layer -> full 8x13 sheet, and layer -> the weapon type's 8x3 attack strip.
var _sheets: Dictionary[StringName, Texture2D] = {}
var _attack_strips: Dictionary[StringName, Texture2D] = {}
var weapon_type: StringName = &""
var _row: int = 0
var _frame: int = 0
var _time: float = 0.0


func _ready() -> void:
	for layer in LAYERS:
		var s := Sprite2D.new()
		s.name = String(layer)
		s.hframes = COLS
		s.vframes = VFRAMES
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(s)
		_sprites[layer] = s
		var path := "%s%s.png" % [CLIMBER_DIR, layer]
		if ResourceLoader.exists(path):
			s.texture = load(path) as Texture2D
			_sheets[layer] = s.texture
	play(&"idle", Vector2.DOWN)


## Layer swap (docs/assets.md): weapon from weapons/<type>.png (else the
## default weapon.png); hair and outfit from outfits/<id>/<layer>.png (else
## the default sheets). The weapon type's own attack rows (8x3 strips) come
## from outfits/<id>/attacks/<type>_<layer>.png for hair and outfit, else
## attacks/<type>_<layer>.png; the sword has none and keeps rows 6-8.
static func weapon_sheet_path(type: StringName) -> String:
	var path := "%sweapons/%s.png" % [CLIMBER_DIR, type]
	return path if ResourceLoader.exists(path) else "%sweapon.png" % CLIMBER_DIR


static func layer_sheet_path(layer: StringName, outfit_dir: String) -> String:
	if outfit_dir != "" and layer in [&"hair", &"outfit"]:
		var path := "%soutfits/%s/%s.png" % [CLIMBER_DIR, outfit_dir, layer]
		if ResourceLoader.exists(path):
			return path
	return "%s%s.png" % [CLIMBER_DIR, layer]


static func attack_strip_path(type: StringName, layer: StringName, outfit_dir: String = "") -> String:
	if outfit_dir != "" and layer in [&"hair", &"outfit"]:
		var own := "%soutfits/%s/attacks/%s_%s.png" % [CLIMBER_DIR, outfit_dir, type, layer]
		if ResourceLoader.exists(own):
			return own
	var path := "%sattacks/%s_%s.png" % [CLIMBER_DIR, type, layer]
	return path if ResourceLoader.exists(path) else ""


var outfit_dir: String = ""


func set_weapon(type: StringName) -> void:
	weapon_type = type
	_reload()


## Outfit item id (outfit_<dir>); &"" is the default climber sheets.
func set_outfit(id: StringName) -> void:
	outfit_dir = String(id).trim_prefix("outfit_")
	_reload()


func _reload() -> void:
	for layer in LAYERS:
		var path := weapon_sheet_path(weapon_type) if layer == &"weapon" else layer_sheet_path(layer, outfit_dir)
		if ResourceLoader.exists(path):
			_sheets[layer] = load(path) as Texture2D
	_attack_strips.clear()
	if weapon_type != &"":
		for layer in ATTACK_LAYERS:
			var p := attack_strip_path(weapon_type, layer, outfit_dir)
			if p != "":
				_attack_strips[layer] = load(p) as Texture2D
	if not _sprites.is_empty():
		_apply()


func set_layer(layer: StringName, texture: Texture2D, tint: Color = Color.WHITE) -> void:
	var s := _sprites.get(layer) as Sprite2D
	if s == null:
		return
	s.texture = texture
	s.modulate = tint
	_sheets[layer] = texture


## Facing is a direction vector; the dominant axis picks down/up/side and
## a left-facing vector flips the sprite horizontally.
func play(anim_name: StringName, facing: Vector2, restart: bool = false) -> void:
	var dir := &"side"
	var flip: bool = (_sprites[&"body"] as Sprite2D).flip_h
	if absf(facing.y) > absf(facing.x):
		dir = &"down" if facing.y > 0.0 else &"up"
		flip = false
	elif facing.x != 0.0:
		flip = facing.x < 0.0
	for s: Sprite2D in _sprites.values():
		s.flip_h = flip
	var row_name: StringName = &"death" if anim_name == &"death" else StringName("%s_%s" % [anim_name, dir])
	var row := ROW_ORDER.find(row_name)
	if row < 0:
		push_error("LayeredSprite: unknown anim '%s'" % row_name)
		return
	if anim_name != anim or restart:
		_frame = 0
		_time = 0.0
		finished = false
	anim = anim_name
	_row = row
	_apply()


func _process(delta: float) -> void:
	if finished or anim == &"":
		return
	_time += delta * speed_scale
	var frame_time := 1.0 / FPS[anim]
	while _time >= frame_time:
		_time -= frame_time
		_frame += 1
		var count := FRAME_COUNT[anim]
		if _frame >= count:
			if anim in LOOPING:
				_frame = 0
			else:
				_frame = count - 1
				finished = true
				break
	_apply()


func _apply() -> void:
	var strip_row := _row - ATTACK_ROW if anim == &"attack" else -1
	for layer: StringName in _sprites:
		var s := _sprites[layer] as Sprite2D
		var strip: Texture2D = _attack_strips.get(layer) if strip_row >= 0 else null
		if strip != null:
			if s.texture != strip:
				s.frame = 0
				s.texture = strip
				s.vframes = 3
			s.frame_coords = Vector2i(_frame, strip_row)
		else:
			var sheet: Texture2D = _sheets.get(layer)
			if sheet != null and s.texture != sheet:
				s.frame = 0
				s.texture = sheet
				s.vframes = VFRAMES
			s.frame_coords = Vector2i(_frame, _row)
