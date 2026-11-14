"""Build the HUD kit: bar frames, item slot, plaque, button, panel, animated
heart and coin, hourglass, light ring and bar fills.

python3 -I art-src/build_hud.py <repo_root> [--force]

Inputs (see docs/assets.md):
  art-src/gen/hud-frames-sheet.png    HP bar frame (row 1), boss bar frame (row 2)
  art-src/gen/hud-frames-sheet-b.png  item slot, plaque, button, window panel
  art-src/gen/hud-icons-sheet.png     heart, coin, hourglass, light ring
Outputs in game/assets/ui/hud/ (sizes in the HUD constants of game/ui/hud.gd):
  hp_frame.png (9-slice), boss_frame.png (9-slice), slot.png, plaque.png
  (9-slice), button.png, button_hot.png, button_down.png, button_off.png
  (9-slice), panel.png (9-slice), heart.png (4 frames), coin.png (6 frames),
  hourglass.png, ring.png, fill_hp.png, fill_boss.png, fill_exit.png,
  fill_tip.png
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from PIL import Image  # noqa: E402

from artlib import OUTLINE, key_magenta, magenta_level, parse_args, save_guarded  # noqa: E402

COLORS = 32

# Source boxes (x0, y0, x1, y1) in the generated sheets, from artlib.frames()
# and by eye. Bars are rebuilt from their left half and mirrored, because the
# generated sheet has scenery bleeding under the right part of the boss bar.
HP_BAR = (69, 52, 1376, 266)        # left half of the HP frame
BOSS_BAR = (60, 300, 1000, 500)     # left half of the boss frame, horns to bar bottom
SLOT = (112, 120, 911, 912)
PLAQUE = (1249, 358, 1823, 666)
BUTTON = (61, 1280, 963, 1792)
PANEL = (1106, 1126, 1966, 1956)
HEART = (14, 50, 478, 475)
COIN = (584, 50, 1011, 475)
HOURGLASS = (1145, 50, 1412, 475)
RING = (1591, 50, 2014, 475)

# Ramps for the fills (dark to light). Red marks danger, amber marks the exit.
HP_RAMP = [(92, 18, 30), (168, 32, 38), (222, 62, 52), (246, 120, 92)]
BOSS_RAMP = [(70, 14, 24), (130, 22, 34), (186, 40, 44), (228, 92, 72)]
EXIT_RAMP = [(120, 64, 18), (196, 120, 34), (240, 176, 64), (255, 226, 140)]


def key(img):
    """Magenta key that also drops pink haze at the edges."""
    img = key_magenta(img)
    px = img.load()
    for y in range(img.height):
        for x in range(img.width):
            r, g, b, a = px[x, y]
            if a and magenta_level(r, g, b) > 35:
                px[x, y] = (0, 0, 0, 0)
    return img


def shrink(src, w, h):
    """Box downscale with binary alpha."""
    out = src.resize((w, h), Image.BOX)
    out.putalpha(out.getchannel("A").point(lambda v: 255 if v >= 110 else 0))
    return out


def outline(img):
    """Every opaque pixel touching transparency or the canvas edge becomes the
    dark outline, so each sprite has a crisp 1 px border."""
    out = img.copy()
    src = img.load()
    px = out.load()
    w, h = img.size
    for y in range(h):
        for x in range(w):
            if not src[x, y][3]:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if not (0 <= nx < w and 0 <= ny < h) or src[nx, ny][3] == 0:
                    px[x, y] = OUTLINE
                    break
    return out


def quantize(img, n=COLORS):
    alpha = img.getchannel("A").point(lambda v: 255 if v >= 128 else 0)
    q = img.convert("RGB").quantize(colors=n, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
    out = q.convert("RGBA")
    out.putalpha(alpha)
    px = out.load()
    for y in range(out.height):
        for x in range(out.width):
            if px[x, y][3] == 0:
                px[x, y] = (0, 0, 0, 0)
    return out


def crop(sheet, box):
    part = sheet.crop(box)
    return part.crop(part.getbbox())


def mirrored_bar(left_src, h, cap_w, total_w):
    """Downscale the left half to height h, keep cap_w px of cap plus one
    clean middle column, then tile it and mirror the cap on the right."""
    k = left_src.height / h
    half = shrink(left_src, round(left_src.width / k), h)
    cap = half.crop((0, 0, cap_w, h))
    col = half.crop((cap_w + 2, 0, cap_w + 3, h))
    out = Image.new("RGBA", (total_w, h), (0, 0, 0, 0))
    out.alpha_composite(cap, (0, 0))
    for x in range(cap_w, total_w - cap_w):
        out.alpha_composite(col, (x, 0))
    out.alpha_composite(cap.transpose(Image.FLIP_LEFT_RIGHT), (total_w - cap_w, 0))
    return out


def fill(ramp, h):
    """1 px wide vertical ramp: light top, dark bottom, a highlight row."""
    img = Image.new("RGBA", (1, h), (0, 0, 0, 0))
    for y in range(h):
        t = y / max(h - 1, 1)
        i = 3 if y == 0 else (2 if t < 0.45 else (1 if t < 0.85 else 0))
        img.putpixel((0, y), ramp[i] + (255,))
    return img


def tip(h):
    """Light pulse at the end of a fill: 3 px wide, white core, amber edge."""
    img = Image.new("RGBA", (3, h), (0, 0, 0, 0))
    for y in range(h):
        img.putpixel((0, y), (255, 196, 96, 255))
        img.putpixel((1, y), (255, 248, 220, 255))
        img.putpixel((2, y), (255, 196, 96, 255))
    return img


def tint(img, fn):
    out = img.copy()
    px = out.load()
    for y in range(out.height):
        for x in range(out.width):
            r, g, b, a = px[x, y]
            if a and (r, g, b) != OUTLINE[:3]:
                px[x, y] = fn(r, g, b) + (a,)
    return out


def brighten(r, g, b):
    """Hot (focused) button: bronze rim lifted toward amber, body warmer."""
    lum = (r * 3 + g * 6 + b) / 10
    if r > g + 25 and lum > 70:
        return (min(255, r + 50), min(255, g + 45), min(255, b + 15))
    return (min(255, r + 22), min(255, g + 12), b)


def darken(r, g, b):
    return (r * 3 // 4, g * 3 // 4, b * 3 // 4)


def grey(r, g, b):
    v = (r * 3 + g * 6 + b) // 10
    return (v * 3 // 4 + 10, v * 3 // 4 + 6, v * 3 // 4 + 6)


def hot_glow(img):
    """Hot button: 1 px amber glow ring outside the outline. The source keeps
    a transparent 1 px margin so the glow fits."""
    w, h = img.size
    out = Image.new("RGBA", (w + 2, h + 2), (0, 0, 0, 0))
    out.alpha_composite(img, (1, 1))
    src = out.copy().load()
    px = out.load()
    for y in range(h + 2):
        for x in range(w + 2):
            if src[x, y][3]:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < w + 2 and 0 <= ny < h + 2 and src[nx, ny][3]:
                    px[x, y] = (255, 196, 84, 255)
                    break
    return out


def symmetric(img, vertical=True):
    """Mirror the left half onto the right (and the top half onto the bottom
    when vertical) so frames read even after the downscale."""
    w, h = img.size
    out = img.copy()
    left = img.crop((0, 0, (w + 1) // 2, h))
    out.paste(left.transpose(Image.FLIP_LEFT_RIGHT), (w - left.width, 0))
    out.paste(left, (0, 0))
    if vertical:
        top = out.crop((0, 0, w, (h + 1) // 2))
        out.paste(top.transpose(Image.FLIP_TOP_BOTTOM), (0, h - top.height))
        out.paste(top, (0, 0))
    return out


def trim(img):
    return img.crop(img.getbbox())


def dark_body(img):
    """The generated window body is a mid brown that muted text cannot read
    on; take the body colours (the large flat area) down to a deep warm brown
    so 8 px text keeps its contrast."""
    out = img.copy()
    px = out.load()
    w, h = out.size
    body = px[w // 2, h // 2]
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a and abs(r - body[0]) + abs(g - body[1]) + abs(b - body[2]) < 40:
                px[x, y] = (r * 11 // 20, g * 11 // 20, b * 11 // 20, a)
    return out


def pad(img, n=1):
    out = Image.new("RGBA", (img.width + 2 * n, img.height + 2 * n), (0, 0, 0, 0))
    out.alpha_composite(img, (n, n))
    return out


def sprite(src, w, h):
    return quantize(outline(shrink(src, w, h)))


def strip(frames_):
    w = max(f.width for f in frames_)
    h = max(f.height for f in frames_)
    out = Image.new("RGBA", (w * len(frames_), h), (0, 0, 0, 0))
    for i, f in enumerate(frames_):
        out.alpha_composite(f, (i * w + (w - f.width) // 2, (h - f.height) // 2))
    return out


def heart_frames(src):
    """Beat: rest, swell, peak, settle. All frames share one canvas."""
    sizes = [(11, 10), (12, 11), (13, 12), (12, 11)]
    return [sprite(src, w, h) for w, h in sizes]


def coin_frames(src):
    """Spin by squashing the face; the back half is the face mirrored and a
    shade darker; the edge-on frame is a 2 px rim."""
    face = sprite(src, 9, 9)
    out = [face]
    for w in (7, 4):
        out.append(sprite(src, w, 9))
    rim = Image.new("RGBA", (2, 9), (0, 0, 0, 0))
    for y in range(9):
        edge = y in (0, 8)
        rim.putpixel((0, y), OUTLINE if edge else (170, 105, 30, 255))
        rim.putpixel((1, y), OUTLINE if edge else (235, 175, 50, 255))
    out.append(rim)
    for w in (4, 7):
        out.append(tint(sprite(src, w, 9), darken).transpose(Image.FLIP_LEFT_RIGHT))
    return out


def main():
    root, force = parse_args(sys.argv)
    gen = os.path.join(root, "art-src", "gen")
    out_dir = os.path.join(root, "game", "assets", "ui", "hud")
    os.makedirs(out_dir, exist_ok=True)

    def save(img, name):
        save_guarded(img, os.path.join(out_dir, name), force)

    frames_a = key(Image.open(os.path.join(gen, "hud-frames-sheet.png")))
    frames_b = key(Image.open(os.path.join(gen, "hud-frames-sheet-b.png")))
    icons = key(Image.open(os.path.join(gen, "hud-icons-sheet.png")))

    save(trim(quantize(outline(mirrored_bar(crop(frames_a, HP_BAR), 12, 9, 48)))), "hp_frame.png")
    save(trim(quantize(outline(mirrored_bar(crop(frames_a, BOSS_BAR), 16, 14, 64)))), "boss_frame.png")
    save(trim(symmetric(sprite(crop(frames_b, SLOT), 22, 22))), "slot.png")
    save(trim(symmetric(sprite(crop(frames_b, PLAQUE), 30, 16))), "plaque.png")

    button = trim(symmetric(sprite(crop(frames_b, BUTTON), 40, 22), vertical=False))
    save(pad(button), "button.png")
    save(hot_glow(tint(button, brighten)), "button_hot.png")
    save(pad(tint(button, darken)), "button_down.png")
    save(pad(tint(button, grey)), "button_off.png")
    save(trim(symmetric(dark_body(sprite(crop(frames_b, PANEL), 72, 70)))), "panel.png")

    save(quantize(strip(heart_frames(crop(icons, HEART)))), "heart.png")
    save(quantize(strip(coin_frames(crop(icons, COIN)))), "coin.png")
    save(sprite(crop(icons, HOURGLASS), 6, 9), "hourglass.png")
    ring = shrink(crop(icons, RING), 24, 24)
    save(quantize(ring, 8), "ring.png")

    save(fill(HP_RAMP, 6), "fill_hp.png")
    save(fill(BOSS_RAMP, 8), "fill_boss.png")
    save(fill(EXIT_RAMP, 6), "fill_exit.png")
    save(tip(8), "fill_tip.png")


if __name__ == "__main__":
    main()
