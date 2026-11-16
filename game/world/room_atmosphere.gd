class_name RoomAtmosphere
extends Node2D
## Depth and light of a detailed room (build_rooms.gd "detail"): a soft cool
## vignette at the screen edges, slow dust motes in each torch's light, a
## gentle torch flicker, and cool ground shadows under the hero and the
## enemies while they are in this room. Child of the Room, next to Torches.

## Vignette: cool dark purple, clear in the middle of the screen.
const VIGNETTE := Color(0.06, 0.03, 0.14)
const VIGNETTE_ALPHA := 0.36
## Under the HUD (layer 5) and the fades.
const VIGNETTE_LAYER := 1
const MOTES := 6
const MOTE_LIFE := 6.0
const MOTE_COLOR := Color(1.0, 0.86, 0.6, 0.6)
## Area the motes drift in, below a top-wall torch (above a bottom one).
const MOTE_BOX := Vector2(30, 22)
const MOTE_DROP := 30.0
const FLICKER := 0.06
const PLAYER_SHADOW := Vector2i(16, 6)
## Same feet offset as the town (town.gd).
const PLAYER_FEET := Vector2(0, 7)

var _torches: Array[PointLight2D] = []
var _energy: Array[float] = []
var _time: float = 0.0
var _player_shadow: GroundShadow = null


func _ready() -> void:
	_add_vignette()
	var lights := get_parent().get_node_or_null(^"Torches")
	if lights != null:
		for t in lights.get_children():
			if t is PointLight2D:
				_torches.append(t as PointLight2D)
				_energy.append((t as PointLight2D).energy)
				_add_motes(t as PointLight2D)
	var room := get_parent()
	room.child_entered_tree.connect(_on_room_child)
	for c in room.get_children():
		_on_room_child(c)
	_shade_player.call_deferred()


func _exit_tree() -> void:
	if _player_shadow != null and is_instance_valid(_player_shadow):
		# Renamed first, so the next room's atmosphere can add its own now.
		_player_shadow.name = "RoomShadowGone"
		_player_shadow.queue_free()
	_player_shadow = null


func _process(delta: float) -> void:
	_time += delta
	for i in _torches.size():
		var k := 1.0 + FLICKER * (sin(_time * 7.0 + i * 1.7) * 0.6 + sin(_time * 12.9 + i * 0.9) * 0.4)
		_torches[i].energy = _energy[i] * k


func _add_vignette() -> void:
	var layer := CanvasLayer.new()
	layer.name = "Vignette"
	layer.layer = VIGNETTE_LAYER
	add_child(layer)
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.55, 0.8, 1.0])
	g.colors = PackedColorArray([
		Color(VIGNETTE, 0.0), Color(VIGNETTE, 0.0),
		Color(VIGNETTE, VIGNETTE_ALPHA * 0.4), Color(VIGNETTE, VIGNETTE_ALPHA)])
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	# An ellipse that reaches the middle of each screen edge; corners stay
	# at the darkest step.
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 240
	tex.height = 135
	var rect := TextureRect.new()
	rect.texture = tex
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(rect)


func _add_motes(torch: PointLight2D) -> void:
	var p := CPUParticles2D.new()
	p.name = "Motes"
	var down := 1.0 if torch.position.y < 128.0 else -1.0
	p.position = torch.position + Vector2(0, MOTE_DROP * down)
	p.amount = MOTES
	p.lifetime = MOTE_LIFE
	p.preprocess = MOTE_LIFE
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = MOTE_BOX / 2.0
	p.direction = Vector2.UP
	p.spread = 180.0
	p.gravity = Vector2(0, -1.5)
	p.initial_velocity_min = 1.0
	p.initial_velocity_max = 3.5
	p.scale_amount_min = 1.0
	p.scale_amount_max = 1.0
	p.color = MOTE_COLOR
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.25, 0.75, 1.0])
	ramp.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	p.color_ramp = ramp
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	p.material = mat
	# Over the floor and the props, under the actors' Y-sort.
	p.z_index = -1
	add_child(p)


func _on_room_child(n: Node) -> void:
	var e := n as EnemyBase
	if e == null or e.has_node(^"RoomShadow"):
		return
	var w := roundi(e.frame_size * 0.6)
	var s := GroundShadow.make(Vector2i(w, maxi(4, w / 3)), Vector2(0, -1), GroundShadow.COOL)
	s.name = "RoomShadow"
	e.add_child(s)
	e.move_child(s, 0)
	e.killed.connect(func() -> void:
		if is_instance_valid(s):
			s.queue_free())


func _shade_player() -> void:
	if not is_inside_tree():
		return
	var p := get_tree().get_first_node_in_group(&"player") as Node2D
	if p == null or p.has_node(^"RoomShadow"):
		return
	_player_shadow = GroundShadow.make(PLAYER_SHADOW, PLAYER_FEET, GroundShadow.COOL)
	_player_shadow.name = "RoomShadow"
	p.add_child(_player_shadow)
	p.move_child(_player_shadow, 0)
