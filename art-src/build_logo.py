"""Build the CINZEL logo: wordmark (large, medium), its ember glow, the square
emblem (16/32/64/256), the Windows .ico and the boot splash.

python3 -I art-src/build_logo.py <repo_root> [--force]

Inputs (see docs/assets.md):
  art-src/gen/logo/wordmark-1-2.png  "CINZEL" in carved stone, the I is a tower
  art-src/gen/logo/emblem-1-1.png    stone C with a tower and a sword
Outputs in game/assets/ui/logo/:
  logo_large.png (240 wide), logo_large_glow.png (logo + GLOW_PAD on each
  side), logo_medium.png (120 wide), logo_small.png (80 wide),
  emblem_16.png, emblem_32.png, emblem_64.png, emblem_256.png (64 x4),
  icon.ico (16/32/48/64/128/256), boot_splash.png (large x3, transparent)
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from PIL import Image  # noqa: E402

from artlib import count_colors, parse_args, save_guarded, upscale  # noqa: E402
from build_hud import key, outline, quantize, shrink  # noqa: E402

COLORS = 32
GLOW_PAD = 4
# Ember glow bands, outer to inner (alpha rises toward the letters).
GLOW_BANDS = [(255, 120, 40, 40), (255, 140, 50, 80), (255, 170, 70, 130)]


def keyed(path):
    img = key(Image.open(path))
    return img.crop(img.getbbox())


def wordmark(src, w):
    h = round(src.height * w / src.width)
    return quantize(outline(shrink(src, w, h)), COLORS)


def glow(logo):
    """Logo-shaped halo, GLOW_PAD px wide in hard bands (pixel art, no blur).
    Drawn behind the logo with additive blend; its alpha pulses in Godot."""
    w, h = logo.width + GLOW_PAD * 2, logo.height + GLOW_PAD * 2
    mask = Image.new("L", (w, h), 0)
    mask.paste(logo.getchannel("A"), (GLOW_PAD, GLOW_PAD))
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    px = out.load()
    m = mask.load()
    # Chebyshev-ish distance to the letters, capped at GLOW_PAD.
    dist = [[99] * w for _ in range(h)]
    for y in range(h):
        for x in range(w):
            if m[x, y]:
                dist[y][x] = 0
    for _ in range(GLOW_PAD):
        nxt = [row[:] for row in dist]
        for y in range(h):
            for x in range(w):
                if dist[y][x] < 99:
                    continue
                best = 99
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (-1, -1), (1, -1), (-1, 1)):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < w and 0 <= ny < h:
                        best = min(best, dist[ny][nx] + 1)
                nxt[y][x] = best
        dist = nxt
    for y in range(h):
        for x in range(w):
            d = dist[y][x]
            if 1 <= d <= GLOW_PAD:
                # d = 1, 2 inner band; 3 middle; 4 outer.
                band = GLOW_BANDS[2] if d <= 2 else (GLOW_BANDS[1] if d == 3 else GLOW_BANDS[0])
                px[x, y] = band
    return out


def emblem(src, size):
    side = max(src.width, src.height)
    sq = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    sq.alpha_composite(src, ((side - src.width) // 2, (side - src.height) // 2))
    inner = size - 2 if size >= 32 else size
    small = shrink(sq, inner, inner)
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    canvas.alpha_composite(small, ((size - inner) // 2, (size - inner) // 2))
    return quantize(outline(canvas), 16 if size <= 16 else COLORS)


def main():
    root, force = parse_args(sys.argv)
    gen = os.path.join(root, "art-src", "gen", "logo")
    out_dir = os.path.join(root, "game", "assets", "ui", "logo")
    os.makedirs(out_dir, exist_ok=True)

    def save(img, name):
        save_guarded(img, os.path.join(out_dir, name), force)
        if img.mode == "RGBA":
            print("  %s %dx%d, %d colors" % (name, img.width, img.height, count_colors(img)))

    word = keyed(os.path.join(gen, "wordmark-1-2.png"))
    large = wordmark(word, 240)
    save(large, "logo_large.png")
    save(glow(large), "logo_large_glow.png")
    save(wordmark(word, 120), "logo_medium.png")
    save(wordmark(word, 80), "logo_small.png")
    save(upscale(large, 3), "boot_splash.png")

    emb = keyed(os.path.join(gen, "emblem-1-1.png"))
    e16, e32, e64 = emblem(emb, 16), emblem(emb, 32), emblem(emb, 64)
    save(e16, "emblem_16.png")
    save(e32, "emblem_32.png")
    save(e64, "emblem_64.png")
    e256 = upscale(e64, 4)
    save(e256, "emblem_256.png")
    ico = os.path.join(out_dir, "icon.ico")
    if os.path.exists(ico) and not force:
        print("skip %s (exists; pass --force to overwrite)" % ico)
    else:
        # Largest first; Pillow picks each size from the closest frame given.
        e256.save(ico, format="ICO", sizes=[(256, 256), (128, 128), (64, 64), (48, 48), (32, 32), (16, 16)],
                  append_images=[upscale(e64, 2), e64, emblem(emb, 48), e32, e16])
        print("wrote %s" % ico)


if __name__ == "__main__":
    main()
