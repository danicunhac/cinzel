"""Build the equipment, material and outfit icons (16x16) and the rarity
frames (18x18).

python3 -I art-src/build_items.py <repo_root> [--force]

Inputs (see docs/assets.md), all on magenta:
  art-src/gen/icons-weapons-sheet.png    12 weapons, 4x3, reading order = WEAPONS
  art-src/gen/icons-armor-sheet.png      6 armors, 3x2
  art-src/gen/icons-helms-packs-sheet.png  4 helms + 2 backpacks, 3x2
  art-src/gen/icons-backpack-large.png   1 backpack
  art-src/gen/icons-materials-sheet.png  10 materials, 5x2 (only 4 still used)
  art-src/gen/icons-materials2-sheet.png 6 materials, 3x2
  game/assets/characters/climber/{body.png, outfits/<id>/{hair,outfit}.png}
    (outfit icons: head-and-shoulders crop of the front idle frame, 1:1)
Outputs:
  game/assets/items/<id>.png              16x16, transparent, <= 16 colours
  game/assets/items/frames/{common,rare,epic}.png  18x18 rarity rings: the
    16x16 icon goes at (1, 1) inside the ring; centre transparent.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from PIL import Image, ImageEnhance  # noqa: E402

from artlib import OUTLINE, frames, key_magenta, parse_args, save_guarded  # noqa: E402

SHEETS = [
    ("icons-weapons-sheet.png", [
        "sword_iron", "sword_knight", "longsword_steel", "longsword_ember",
        "axe_woodcutter", "axe_war", "spear_hunter", "spear_dragoon",
        "dagger_rogue", "dagger_twin_fang", "bow_short", "bow_elven"]),
    ("icons-armor-sheet.png", [
        "armor_cloth", "armor_leather", "armor_chain",
        "armor_scale", "armor_plate", "armor_shadow"]),
    ("icons-helms-packs-sheet.png", [
        "helm_hood", "helm_iron", "helm_horned",
        "helm_circlet", "backpack_small", "backpack_medium"]),
    ("icons-backpack-large.png", ["backpack_large"]),
    ("icons-materials-sheet.png", [
        None, None, None, None, None,
        "mat_beetle_horn", "mat_obsidian", None, "mat_specter_cloth", "mat_tower_crystal"]),
    ("icons-materials2-sheet.png", [
        "mat_iron_ore", "mat_old_leather", "mat_ash_wood",
        "mat_chitin", "mat_silver_ore", "mat_coal"]),
]
OUTFITS = ["starter", "casaco_longo", "cavaleiro_leve", "tunica_ferreiro", "manto_mago"]
COLORS = 16
BRIGHTEN = {"armor_shadow": 1.6, "mat_obsidian": 1.5}
# Rarity ring colours: (outer dark edge, main, highlight on the top-left).
RARITY = {
    "common": ((60, 56, 60), (214, 210, 200), (250, 248, 240)),
    "rare": ((20, 34, 80), (60, 120, 230), (150, 200, 255)),
    "epic": ((44, 16, 64), (150, 70, 210), (220, 160, 255)),
}


def fit(src, w, h):
    """Trim, pad to the target aspect (centred), box-downscale, binary alpha."""
    src = src.crop(src.getbbox())
    sw, sh = src.size
    k = max(sw / w, sh / h)
    cw, ch = max(sw, round(w * k)), max(sh, round(h * k))
    canvas = Image.new("RGBA", (cw, ch), (0, 0, 0, 0))
    canvas.alpha_composite(src, ((cw - sw) // 2, (ch - sh) // 2))
    small = canvas.resize((w, h), Image.BOX)
    small.putalpha(small.getchannel("A").point(lambda v: 255 if v >= 100 else 0))
    return small


def quantize(img, n=COLORS):
    alpha = img.getchannel("A")
    q = img.convert("RGB").quantize(colors=n, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
    out = q.convert("RGBA")
    out.putalpha(alpha)
    px = out.load()
    for y in range(out.height):
        for x in range(out.width):
            if px[x, y][3] == 0:
                px[x, y] = (0, 0, 0, 0)
    return out


def icon(src, crisp):
    """crisp (thin weapons): box-downscale to 30x30 inside a 32 canvas, then
    nearest to 16x16, which keeps the 1 px outline, blades and bow strings.
    Otherwise (bulky, textured icons): straight box-downscale to 14x14."""
    if crisp:
        cell = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
        cell.alpha_composite(fit(src, 30, 30), (1, 1))
        return quantize(cell.resize((16, 16), Image.NEAREST))
    cell = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    cell.alpha_composite(fit(src, 14, 14), (1, 1))
    return quantize(cell)


def brighten(img, k):
    """Lift very dark icons (black armor, obsidian) so they read on the dark
    slot background."""
    rgb = ImageEnhance.Brightness(img.convert("RGB")).enhance(k).convert("RGBA")
    rgb.putalpha(img.getchannel("A"))
    return rgb


def boxes(img):
    """Icon boxes in reading order (rows of frames(), left to right)."""
    out = []
    for row in frames(img, min_gap=30):
        out.extend(sorted(row))
    return out


def ring(colors):
    """2 px ring: bright outer line (lit on the top-left), dark inner line,
    clipped corners."""
    dark, main, hi = colors
    img = Image.new("RGBA", (18, 18), (0, 0, 0, 0))
    px = img.load()
    for y in range(18):
        for x in range(18):
            if x in (0, 17) and y in (0, 17):
                continue
            if x in (0, 17) or y in (0, 17):
                lit = (y == 0 and x < 12) or (x == 0 and y < 12)
                px[x, y] = (hi if lit else main) + (255,)
            elif x in (1, 16) or y in (1, 16):
                corner = x in (1, 16) and y in (1, 16)
                px[x, y] = (main if corner else dark) + (255,)
    return img


def bust(root, outfit_id):
    """Head-and-shoulders crop (16x16, 1:1) of idle_down frame 0."""
    base = os.path.join(root, "game/assets/characters/climber")
    cell = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    for path in ("body.png", "outfits/%s/hair.png" % outfit_id, "outfits/%s/outfit.png" % outfit_id):
        cell.alpha_composite(Image.open(os.path.join(base, path)).convert("RGBA").crop((0, 0, 32, 32)))
    top = cell.getbbox()[1]
    crop = cell.crop((8, top - 1, 24, top + 15))
    # close the cut at the bottom with the outline colour
    px = crop.load()
    for x in range(16):
        if px[x, 15][3]:
            px[x, 15] = OUTLINE
    return crop


def main():
    root, force = parse_args(sys.argv)
    gen = os.path.join(root, "art-src/gen")
    out = os.path.join(root, "game/assets/items")
    os.makedirs(os.path.join(out, "frames"), exist_ok=True)
    for fn, ids in SHEETS:
        img = key_magenta(Image.open(os.path.join(gen, fn)))
        bx = boxes(img)
        assert len(bx) == len(ids), "%s: found %d icons, want %d" % (fn, len(bx), len(ids))
        for name, box in zip(ids, bx):
            if name is None:  # retired material, cell kept for the box count
                continue
            src = img.crop(box)
            if name in BRIGHTEN:
                src = brighten(src, BRIGHTEN[name])
            save_guarded(icon(src, fn == SHEETS[0][0]), os.path.join(out, name + ".png"), force)
    for oid in OUTFITS:
        if os.path.exists(os.path.join(root, "game/assets/characters/climber/outfits", oid, "outfit.png")):
            save_guarded(quantize(bust(root, oid), 24), os.path.join(out, "outfit_%s.png" % oid), force)
    for name, colors in RARITY.items():
        save_guarded(ring(colors), os.path.join(out, "frames", name + ".png"), force)


if __name__ == "__main__":
    main()
