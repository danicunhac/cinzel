class_name GroundShadow
extends Sprite2D
## Pixel ellipse shadow under a character's feet, in the town's shadow colour
## (build_town.py SHADOW): a darker core and a lighter rim. Add it as a child
## at the feet; it draws behind its parent's other children.

const COLOR := Color8(20, 12, 24)
## Cool purple-blue shadow of the detailed rooms (RoomAtmosphere): reads as
## shade under the warm torch light instead of a black hole.
const COOL := Color8(30, 22, 58)
const CORE_ALPHA := 0.55
const RIM_ALPHA := 0.32

static var _cache: Dictionary[String, ImageTexture] = {}


## Shadow `size` px wide and tall, centred on `feet` (in the parent's space),
## in `color` (COLOR, or COOL in the detailed rooms).
static func make(size: Vector2i, feet: Vector2, color: Color = COLOR) -> GroundShadow:
	var s := GroundShadow.new()
	s.texture = _texture(size, color)
	s.position = feet.round()
	s.show_behind_parent = true
	s.z_index = 0
	return s


static func _texture(size: Vector2i, color: Color = COLOR) -> ImageTexture:
	var key := "%s/%s" % [size, color.to_html()]
	if _cache.has(key):
		return _cache[key]
	var img := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	var c := Vector2(size.x - 1, size.y - 1) / 2.0
	var r := Vector2(size.x, size.y) / 2.0
	for y in size.y:
		for x in size.x:
			var d := pow((x - c.x) / r.x, 2) + pow((y - c.y) / r.y, 2)
			if d <= 0.45:
				img.set_pixel(x, y, Color(color, CORE_ALPHA))
			elif d <= 1.0:
				img.set_pixel(x, y, Color(color, RIM_ALPHA))
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex
