class_name CinzelLogo
extends RefCounted
## The CINZEL wordmark (art-src/build_logo.py) and a helper that hangs it
## above a UiKit frame, so it slides in with the frame (the one entrance).

const LARGE := preload("res://assets/ui/logo/logo_large.png")
const LARGE_GLOW := preload("res://assets/ui/logo/logo_large_glow.png")
const MEDIUM := preload("res://assets/ui/logo/logo_medium.png")
const SMALL := preload("res://assets/ui/logo/logo_small.png")
## logo_large_glow.png is the logo plus this many pixels on each side.
const GLOW_PAD := 4


static func rect(tex: Texture2D) -> TextureRect:
	var r := TextureRect.new()
	r.texture = tex
	r.size = tex.get_size()
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.name = "Logo"
	return r


## Logo centred above `frame`, its bottom `gap` px over the frame's top edge
## (the title plaque pokes 6 px above it). Stays centred if the frame grows.
static func above_frame(frame: Control, tex: Texture2D, gap: int = 8) -> TextureRect:
	var r := rect(tex)
	frame.add_child(r)
	var place := func() -> void:
		r.position = Vector2(floorf((frame.size.x - r.size.x) / 2.0), -gap - r.size.y)
	place.call()
	frame.resized.connect(place)
	return r


## The UiKit frame that centred_frame() built around `box`.
static func frame_of(box: VBoxContainer) -> Control:
	return box.get_parent().get_parent() as Control
