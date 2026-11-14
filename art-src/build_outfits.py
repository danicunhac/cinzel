"""Build the visual outfits (hair and outfit layers) of the climber.

python3 -I art-src/build_outfits.py <repo_root> [--force]

Inputs: game/assets/characters/climber/{body,hair,outfit}.png and the attack
overrides climber/attacks/<type>_{body,hair,outfit}.png (build_weapons.py).
Outputs, per outfit id:
  climber/outfits/<id>/hair.png, outfit.png        8x13 grid of 32x32
  climber/outfits/<id>/attacks/<type>_hair.png, <type>_outfit.png
    8x3 (attack_down, attack_up, attack_side), one pair per attack override

Every outfit is the shipped starter layers repainted pixel by pixel, so it
lines up with body.png and every weapon in every frame by construction:
  - each colour group of the starter (green hood, olive scarf, leather
    jacket/gloves/backpack, khaki trousers and buckles, brown hair) is
    remapped by brightness rank onto the outfit's own ramp;
  - shape edits on the standing rows (idle, walk, attack): coat tails or a
    robe over the legs (the gap between the legs is filled and closed with
    the outline), and a leather apron down the front for the smith.
Skin and the dark outline are never touched. Starter = plain copies.
"""
import os
import shutil
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from PIL import Image  # noqa: E402

import build_climber as bc  # noqa: E402
from artlib import OUTLINE, is_green, save_guarded  # noqa: E402

F = 32
COLS = 8
ROWS = bc.ROW_NAMES
ATTACK_ROWS = ["attack_down", "attack_up", "attack_side"]

# Ramps dark -> light. Keys: hood (green in hair.png), hair (warm in
# hair.png), scarf (green in outfit.png), leather (jacket, gloves, backpack),
# trim (khaki above the legs: belt, buckles, straps), legs (trousers), and
# skirt (what covers the upper legs: coat tails, robe, apron; None = legs).
# legs_cover: fraction of the leg length the skirt covers (0 = none).
OUTFITS = {
    # SAO-like long dark coat with a high collar, dark hair under a black hood
    "casaco_longo": {
        "hood": [(36, 35, 50), (52, 51, 70), (70, 69, 94), (94, 93, 122)],
        "hair": [(30, 28, 38), (44, 42, 56), (60, 58, 76)],
        "scarf": [(48, 48, 64), (82, 84, 106), (130, 134, 156)],
        "leather": [(32, 31, 44), (44, 43, 60), (58, 57, 80), (78, 77, 104), (104, 103, 134)],
        "trim": [(96, 98, 118), (146, 148, 166), (196, 198, 210)],
        "legs": [(40, 40, 50), (56, 56, 70), (74, 74, 92)],
        "skirt": "leather",
        "legs_cover": 0.6,
    },
    # light knight: chainmail coif, white-silver plate, muted crimson
    "cavaleiro_leve": {
        "hood": [(62, 66, 80), (98, 104, 120), (138, 144, 160), (178, 184, 198)],
        "hair": None,
        "scarf": [(70, 24, 32), (102, 36, 44), (134, 54, 60)],
        "leather": [(92, 94, 110), (134, 138, 154), (178, 182, 194), (214, 216, 224), (240, 240, 244)],
        "trim": [(96, 34, 42), (132, 52, 58), (162, 74, 76)],
        "legs": [(52, 22, 30), (78, 32, 40), (104, 44, 50)],
        "skirt": "scarf",
        "legs_cover": 0.35,
    },
    # smith: red bandana, linen tunic, leather apron, dark trousers
    "tunica_ferreiro": {
        "hood": [(72, 28, 26), (102, 42, 34), (132, 60, 44), (156, 82, 60)],
        "hair": None,
        "scarf": [(50, 33, 22), (74, 49, 30), (98, 67, 40)],
        "leather": [(108, 94, 78), (146, 131, 106), (182, 167, 136), (210, 197, 164), (230, 218, 188)],
        "trim": [(58, 39, 24), (88, 59, 34), (118, 82, 48)],
        "legs": [(44, 33, 28), (64, 49, 40), (86, 67, 54)],
        "apron": [(56, 37, 24), (82, 55, 32), (108, 75, 44)],
        "skirt": None,
        "legs_cover": 0.0,
    },
    # mage: deep violet hood and floor-length robe, pale teal trim
    "manto_mago": {
        "hood": [(30, 22, 52), (45, 33, 77), (62, 47, 102), (82, 65, 128)],
        "hair": None,
        "scarf": [(56, 92, 100), (92, 136, 142), (146, 186, 186)],
        "leather": [(31, 23, 53), (46, 35, 78), (64, 49, 104), (86, 69, 132), (110, 93, 158)],
        "trim": [(56, 92, 100), (92, 136, 142), (146, 186, 186)],
        "legs": [(31, 23, 53), (46, 35, 78), (64, 49, 104)],
        "skirt": "leather",
        "legs_cover": 0.86,
    },
}


def lum(c):
    return 0.3 * c[0] + 0.59 * c[1] + 0.11 * c[2]


def group(c, layer):
    """Colour group of a starter pixel, or None (outline, skin: kept)."""
    if bc.is_outline(c) or bc.is_skin(c):
        return None
    if is_green(c):
        return "hood" if layer == "hair" else "scarf"
    if layer == "hair":
        return "hair"
    r, g = c[0], c[1]
    return "khaki" if r > 100 and g / r >= 0.66 else "leather"


class Ramps:
    """Starter colours per group sorted by brightness, to map rank -> ramp."""

    def __init__(self, sheets):
        groups = {}
        for layer, img in sheets:
            for p in img.get_flattened_data():
                if p[3]:
                    k = group(p, layer)
                    if k:
                        groups.setdefault(k, set()).add(p[:3])
        self.groups = {k: sorted(v, key=lum) for k, v in groups.items()}

    def map(self, c, src_group, ramp):
        cols = self.groups[src_group]
        i = cols.index(c[:3]) if c[:3] in cols else min(range(len(cols)), key=lambda j: abs(lum(cols[j]) - lum(c)))
        j = round(i * (len(ramp) - 1) / max(1, len(cols) - 1))
        return ramp[j] + (255,)


def cells(img):
    rows = img.height // F
    for r in range(rows):
        for c in range(COLS):
            yield r, c, (c * F, r * F, c * F + F, r * F + F)


def legs_box(body, hair, outfit):
    """(top of the trousers, sole row) in a standing cell, or None."""
    comp = Image.new("RGBA", (F, F), (0, 0, 0, 0))
    for im in (body, hair, outfit):
        comp.alpha_composite(im)
    bb = comp.getbbox()
    if not bb:
        return None
    top, sole = bb[1], bb[3] - 1
    o = outfit.load()
    ys = [y for y in range(F) for x in range(F)
          if o[x, y][3] and group(o[x, y], "outfit") == "khaki" and y >= top + 0.55 * (sole - top)]
    return (min(ys), sole) if ys else None


def blade_khaki(outfit, weapon):
    """Khaki pixels of the outfit layer that belong to the blade or the slash
    arc (the colour split put them there): connected through khaki pixels to
    a weapon pixel. They keep their colour in every outfit."""
    o = outfit.load()
    w = weapon.load() if weapon else None
    if w is None:
        return set()

    def khaki(x, y):
        return o[x, y][3] and group(o[x, y], "outfit") == "khaki"

    seen = set()
    todo = [(x, y) for y in range(F) for x in range(F) if khaki(x, y) and any(
        0 <= x + dx < F and 0 <= y + dy < F and w[x + dx, y + dy][3]
        for dx in (-1, 0, 1) for dy in (-1, 0, 1))]
    while todo:
        x, y = todo.pop()
        if (x, y) in seen:
            continue
        seen.add((x, y))
        for dx in (-1, 0, 1):
            for dy in (-1, 0, 1):
                nx, ny = x + dx, y + dy
                if 0 <= nx < F and 0 <= ny < F and (nx, ny) not in seen and khaki(nx, ny):
                    todo.append((nx, ny))
    return seen if len(seen) < 40 else set()


def repaint(row, body, hair, outfit, weapon, spec, ramps):
    """One 32x32 cell -> (hair, outfit) repainted for this outfit."""
    hair, outfit = hair.copy(), outfit.copy()
    h = hair.load()
    hood = [(x, y) for y in range(F) for x in range(F) if h[x, y][3] and group(h[x, y], "hair") == "hood"]
    hx0 = min((p[0] for p in hood), default=0) - 1
    hx1 = max((p[0] for p in hood), default=F) + 1
    hy0 = min((p[1] for p in hood), default=0) - 1
    for y in range(F):
        for x in range(F):
            p = h[x, y]
            k = p[3] and group(p, "hair")
            if not k:
                continue
            if k == "hair" and (row.endswith("_up") or not (hx0 <= x <= hx1 and y >= hy0)):
                # from behind, the warm pixels in the hair layer are the
                # backpack flap, not hair
                h[x, y] = ramps.map(p, "hair", spec["leather"])
            elif spec.get(k):
                h[x, y] = ramps.map(p, k, spec[k])
    standing = not row.startswith(("roll", "death"))
    legs = legs_box(body, hair, outfit) if standing else None
    cover_end = -1
    if legs:
        cover_end = legs[0] + round(spec["legs_cover"] * (legs[1] - legs[0]))
        cover_end = min(cover_end, legs[1] - 3)
    skirt = spec[spec["skirt"]] if spec.get("skirt") else spec["legs"]
    o = outfit.load()
    src = outfit.copy().load()
    bbx = outfit.getbbox()
    cx = (bbx[0] + bbx[2]) / 2 if bbx else 16
    apron = spec.get("apron") if row.endswith("_down") and standing else None
    neck = None
    if apron:
        ys = [y for y in range(F) for x in range(F) if src[x, y][3] and group(src[x, y], "outfit") == "scarf"]
        neck = max(ys) + 1 if ys else None
    keep = blade_khaki(outfit, weapon) if row.startswith("attack") else set()
    for y in range(F):
        for x in range(F):
            p = src[x, y]
            k = p[3] and group(p, "outfit")
            if not k or (x, y) in keep:
                continue
            if k == "khaki":
                if not standing:
                    ramp = spec["legs"]
                elif legs and y >= legs[0]:
                    ramp = skirt if y <= cover_end else spec["legs"]
                else:
                    ramp = spec["trim"]
            else:
                ramp = spec[k]
            if apron and neck is not None and abs(x + 0.5 - cx) <= 3 and y >= neck and k in ("leather", "khaki") \
                    and (not legs or y <= legs[0] + 3):
                ramp = apron
            o[x, y] = ramps.map(p, "khaki" if k == "khaki" else k, ramp)
    if legs and spec["legs_cover"] > 0:
        fill_skirt(o, body.load(), legs[0], cover_end, skirt)
    return hair, outfit


def fill_skirt(o, b, y0, y1, ramp):
    """Close the gap between the legs from y0 to y1 with the skirt colour,
    and draw the outline under the hem where nothing else is."""
    mid = ramp[len(ramp) // 2] + (255,)
    dark = ramp[max(0, len(ramp) // 2 - 1)] + (255,)
    filled = {}
    for y in range(y0, y1 + 1):
        xs = [x for x in range(F) if o[x, y][3]]
        if not xs:
            continue
        x0, x1 = min(xs), max(xs)
        if x1 - x0 > 12:
            continue
        # the gap and the inner outlines of the legs become cloth; the
        # silhouette edge keeps its outline
        for x in range(x0 + 1, x1):
            if not o[x, y][3] or (y > y0 + 1 and bc.is_outline(o[x, y])):
                o[x, y] = dark if y == y1 else mid
                filled[x] = y
        o[x0, y] = OUTLINE
        o[x1, y] = OUTLINE
    for x, y in filled.items():
        if y + 1 < F and not o[x, y + 1][3] and not b[x, y + 1][3]:
            o[x, y + 1] = OUTLINE


def no_orphans(img):
    """Drop pixels with no opaque 8-neighbour in this layer."""
    px = img.load()
    w, hgt = img.size
    for y in range(hgt):
        for x in range(w):
            if px[x, y][3] and not any(
                    0 <= x + dx < w and 0 <= y + dy < hgt and px[x + dx, y + dy][3]
                    for dx in (-1, 0, 1) for dy in (-1, 0, 1) if dx or dy):
                px[x, y] = (0, 0, 0, 0)
    return img


def repaint_sheet(names, body, hair, outfit, weapon, spec, ramps):
    out_h = Image.new("RGBA", hair.size, (0, 0, 0, 0))
    out_o = Image.new("RGBA", outfit.size, (0, 0, 0, 0))
    for r, c, box in cells(hair):
        if not (hair.crop(box).getbbox() or outfit.crop(box).getbbox()):
            continue
        hh, oo = repaint(names[r], body.crop(box), hair.crop(box), outfit.crop(box), weapon.crop(box), spec, ramps)
        out_h.alpha_composite(hh, box[:2])
        out_o.alpha_composite(oo, box[:2])
    return no_orphans(out_h), no_orphans(out_o)


def load(path):
    return Image.open(path).convert("RGBA")


def main():
    root = [a for a in sys.argv[1:] if a != "--force"][0]
    force = "--force" in sys.argv
    climber = os.path.join(root, "game/assets/characters/climber")
    base = {k: load(os.path.join(climber, k + ".png")) for k in ("body", "hair", "outfit", "weapon")}
    att_dir = os.path.join(climber, "attacks")
    kinds = sorted({f.split("_")[0] for f in os.listdir(att_dir) if f.endswith("_body.png")}) \
        if os.path.isdir(att_dir) else []
    attacks = {t: {k: load(os.path.join(att_dir, "%s_%s.png" % (t, k))) for k in ("body", "hair", "outfit")}
               for t in kinds}
    sheets = [("hair", base["hair"]), ("outfit", base["outfit"])]
    for t in kinds:
        sheets += [("hair", attacks[t]["hair"]), ("outfit", attacks[t]["outfit"])]
    ramps = Ramps(sheets)
    # starter: plain copies
    sdir = os.path.join(climber, "outfits", "starter")
    os.makedirs(os.path.join(sdir, "attacks"), exist_ok=True)
    for k in ("hair", "outfit"):
        dst = os.path.join(sdir, k + ".png")
        if force or not os.path.exists(dst):
            shutil.copyfile(os.path.join(climber, k + ".png"), dst)
            print("wrote", dst)
        for t in kinds:
            dst = os.path.join(sdir, "attacks", "%s_%s.png" % (t, k))
            if force or not os.path.exists(dst):
                shutil.copyfile(os.path.join(att_dir, "%s_%s.png" % (t, k)), dst)
                print("wrote", dst)
    for oid, spec in OUTFITS.items():
        odir = os.path.join(climber, "outfits", oid)
        os.makedirs(os.path.join(odir, "attacks"), exist_ok=True)
        h, o = repaint_sheet(ROWS, base["body"], base["hair"], base["outfit"], base["weapon"], spec, ramps)
        save_guarded(h, os.path.join(odir, "hair.png"), force)
        save_guarded(o, os.path.join(odir, "outfit.png"), force)
        for t in kinds:
            a = attacks[t]
            wa = load(os.path.join(climber, "weapons", t + ".png")).crop((0, 6 * F, COLS * F, 9 * F))
            h, o = repaint_sheet(ATTACK_ROWS, a["body"], a["hair"], a["outfit"], wa, spec, ramps)
            save_guarded(h, os.path.join(odir, "attacks", "%s_hair.png" % t), force)
            save_guarded(o, os.path.join(odir, "attacks", "%s_outfit.png" % t), force)


if __name__ == "__main__":
    main()
