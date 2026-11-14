"""Build the armor and helm layers of the climber.

python3 -I art-src/build_gear.py <repo_root> [--force] [id ...]

Inputs: game/assets/characters/climber/{body,hair,outfit,weapon}.png and the
attack overrides climber/attacks/<type>_{body,hair,outfit}.png with
climber/weapons/<type>.png (build_weapons.py).
Outputs, per item id (armor_* and helm_* in game/data/item_catalog.gd):
  climber/gear/<id>.png                  8x13 grid of 32x32
  climber/gear/attacks/<type>_<id>.png   8x3 (attack_down, attack_up,
    attack_side), one per attack override

Every frame is derived from the starter layers of that same frame, so armor
and helm line up with body.png, every outfit and every weapon by
construction (the outfits are recolours of the starter, same pixels):
  - armor: the torso pixels of outfit.png (jacket, gloves, backpack, scarf
    and the belt above the trousers; never the trousers or a blade-coloured
    pixel of the slash) repainted by brightness rank onto the armor's ramp,
    plus a pattern per armor (quilting, a strap, chain dither, scales, plate
    bands and pauldrons that stick out 1 px past the shoulders);
  - helm: the visible head pixels of hair.png (hood and the fringe under it,
    where outfit.png does not cover them) repainted onto the helm's ramp, so
    the hair never pokes through; horns and the circlet band are drawn on
    top. The circlet only adds the band and leaves the hood and hair.
The game draws body, hair, outfit, armor, helm, weapon (LayeredSprite), so
the outfit's own dark outline stays visible under the armor and the helm.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from PIL import Image  # noqa: E402

import build_climber as bc  # noqa: E402
import build_outfits as bo  # noqa: E402
from artlib import OUTLINE, save_guarded  # noqa: E402

F = 32
COLS = 8
ROWS = bc.ROW_NAMES
ATTACK_ROWS = ["attack_down", "attack_up", "attack_side"]

# Ramps dark -> light. body: jacket and gloves; trim: belt and buckles above
# the trousers; collar: the scarf around the neck.
ARMORS = {
    # padded cloth: beige quilted gambeson
    "armor_cloth": {
        "body": [(112, 94, 68), (150, 130, 96), (188, 170, 130), (214, 198, 160), (232, 220, 186)],
        "trim": [(94, 70, 46), (128, 98, 64), (160, 128, 86)],
        "collar": [(150, 130, 96), (188, 170, 130), (214, 198, 160)],
        "pattern": "quilt",
    },
    # brown leather with a dark strap across the chest and a brass buckle
    "armor_leather": {
        "body": [(42, 28, 26), (62, 40, 32), (84, 56, 40), (106, 72, 50), (128, 90, 62)],
        "trim": [(150, 112, 44), (196, 156, 66), (232, 200, 104)],
        "collar": [(62, 40, 32), (84, 56, 40), (106, 72, 50)],
        "strap": [(134, 98, 58), (182, 140, 88)],
        "pattern": "strap",
    },
    # grey chain mail, dithered
    "armor_chain": {
        "body": [(70, 72, 80), (104, 108, 116), (140, 144, 150), (174, 178, 182), (204, 206, 208)],
        "trim": [(72, 50, 34), (104, 72, 44), (134, 96, 58)],
        "collar": [(70, 72, 80), (104, 108, 116), (140, 144, 150)],
        "pattern": "chain",
    },
    # green-bronze scales
    "armor_scale": {
        "body": [(46, 62, 40), (70, 92, 52), (100, 122, 62), (140, 148, 74), (182, 176, 98)],
        "trim": [(110, 76, 34), (160, 116, 50), (204, 160, 76)],
        "collar": [(46, 62, 40), (70, 92, 52), (100, 122, 62)],
        "pattern": "scale",
    },
    # bright steel plate with pauldrons
    "armor_plate": {
        "body": [(66, 70, 84), (108, 114, 128), (152, 158, 170), (192, 196, 204), (226, 228, 234)],
        "trim": [(66, 70, 84), (108, 114, 128), (152, 158, 170)],
        "collar": [(108, 114, 128), (152, 158, 170), (192, 196, 204)],
        "pattern": "plate",
    },
    # dark purple shadow cloth with a faint violet trim
    "armor_shadow": {
        "body": [(26, 18, 40), (40, 28, 62), (58, 40, 88), (78, 56, 116), (100, 74, 144)],
        "trim": [(110, 84, 168), (146, 116, 204), (186, 160, 232)],
        "collar": [(40, 28, 62), (58, 40, 88), (78, 56, 116)],
        "pattern": "shadow",
    },
}

HELMS = {
    # travel hood: dusty grey-brown wool, dark inside the brim
    "helm_hood": {
        "ramp": [(66, 58, 52), (96, 86, 74), (128, 116, 98), (160, 148, 124)],
        "inside": (40, 32, 30),
        "style": "hood",
    },
    "helm_iron": {
        "ramp": [(72, 76, 88), (110, 116, 128), (152, 158, 168), (196, 200, 206)],
        "inside": (44, 44, 52),
        "brim": (226, 228, 232),
        "style": "iron",
    },
    "helm_horned": {
        "ramp": [(72, 76, 88), (110, 116, 128), (152, 158, 168), (196, 200, 206)],
        "inside": (44, 44, 52),
        "brim": (226, 228, 232),
        "horn": [(160, 140, 108), (212, 196, 160), (240, 230, 204)],
        "style": "horned",
    },
    # thin gold band over the hood with a blue gem in front
    "helm_circlet": {
        "gold": [(150, 104, 30), (220, 176, 60), (252, 228, 128)],
        "gem": (80, 160, 236),
        "style": "circlet",
    },
}


def load(path):
    return Image.open(path).convert("RGBA")


def lum(c):
    return 0.3 * c[0] + 0.59 * c[1] + 0.11 * c[2]


def step(ramp, i, d):
    return ramp[max(0, min(len(ramp) - 1, i + d))]


def rank(ramps, c, src_group, ramp):
    """Index on `ramp` of starter colour c (brightness rank in its group)."""
    cols = ramps.groups[src_group]
    i = cols.index(c[:3]) if c[:3] in cols else min(range(len(cols)), key=lambda j: abs(lum(cols[j]) - lum(c)))
    return round(i * (len(ramp) - 1) / max(1, len(cols) - 1))


# ---------------------------------------------------------------- armor ----

def armor_cell(row, body, hair, outfit, weapon, spec, ramps):
    out = Image.new("RGBA", (F, F), (0, 0, 0, 0))
    q = out.load()
    o = outfit.load()
    standing = not row.startswith(("roll", "death"))
    legs = bo.legs_box(body, hair, outfit) if standing else None
    keep = bo.blade_khaki(outfit, weapon) if row.startswith("attack") else set()
    # (x, y) -> (ramp name, index)
    px = {}
    for y in range(F):
        for x in range(F):
            p = o[x, y]
            k = p[3] and bo.group(p, "outfit")
            if not k or (x, y) in keep:
                continue
            if k == "khaki":
                if not legs or y >= legs[0]:
                    continue
                px[(x, y)] = ("trim", rank(ramps, p, "khaki", spec["trim"]))
            elif k == "scarf":
                px[(x, y)] = ("collar", rank(ramps, p, "scarf", spec["collar"]))
            else:
                px[(x, y)] = ("body", rank(ramps, p, "leather", spec["body"]))
    if not px:
        return out
    xs = [p[0] for p in px]
    ys = [p[1] for p in px if px[p][0] != "collar"] or [p[1] for p in px]
    x0, x1, y0, y1 = min(xs), max(xs), min(ys), max(ys)
    pattern = spec["pattern"]
    extra = {}
    for (x, y), (name, i) in px.items():
        ramp = spec[name]
        c = ramp[i]
        if name == "body":
            if pattern == "quilt":
                if (y - y0) % 3 == 2 or (x - x0) % 4 == 3 and (y - y0) % 3 != 0:
                    c = step(ramp, i, -1)
            elif pattern == "strap":
                # left shoulder to right hip (mirrored on the back)
                d = (x - x0) - (y - y0) * (x1 - x0) / max(1, y1 - y0 + 2)
                if 0 <= d < 2 and y > y0:
                    c = spec["strap"][1 if d < 1 else 0]
            elif pattern == "chain":
                c = step(ramp, i, 1 if (x + y) % 2 == 0 else -1)
            elif pattern == "scale":
                band = (y - y0) // 2
                u = (x + 2 * (band % 2)) % 4
                if (y - y0) % 2 == 1 and u in (0, 3):
                    c = step(ramp, i, -2)
                elif (y - y0) % 2 == 0 and u in (1, 2):
                    c = step(ramp, i, 1)
            elif pattern == "plate":
                if standing and y == y0 + round((y1 - y0) * 0.55):
                    c = ramp[0]
            elif pattern == "shadow":
                if (x + 2 * y) % 7 == 0 and i >= 2:
                    c = step(ramp, i, 1)
        q[x, y] = c + (255,)
    if pattern == "strap" and standing and row.endswith("_down"):
        by = y0 + (y1 - y0) // 2
        bx = round(x0 + (by - y0) * (x1 - x0) / max(1, y1 - y0 + 2))
        if (bx, by) in px:
            q[bx, by] = spec["trim"][2] + (255,)
    if pattern == "plate" and standing:
        extra = pauldrons(row, body, hair, outfit, px, y0, spec["body"])
    for (x, y), c in extra.items():
        q[x, y] = c + (255,) if len(c) == 3 else c
    return out


def pauldrons(row, body, hair, outfit, px, y0, ramp):
    """Shoulder plates: the 3 top torso rows reach 1 px past the jacket
    outline on each visible side, with a new outline around them."""
    comp = Image.new("RGBA", (F, F), (0, 0, 0, 0))
    for im in (body, hair, outfit):
        comp.alpha_composite(im)
    a = comp.load()
    sides = [-1, 1]
    if row.endswith("side"):
        # only the front shoulder (facing right in the sheets)
        sides = [1]
    out = {}
    for s in sides:
        for dy, shade in ((0, 3), (1, 2), (2, 1)):
            y = y0 + 1 + dy
            row_px = [x for (x, yy) in px if yy == y]
            if not row_px:
                continue
            x = max(row_px) if s > 0 else min(row_px)
            # the outfit outline next to the jacket, then 1 px more
            for k in (1, 2):
                nx = x + s * k
                if 0 <= nx < F:
                    out[(nx, y)] = ramp[shade] if k == 1 else ramp[max(0, shade - 1)]
            ox = x + s * 3
            if 0 <= ox < F and not a[ox, y][3]:
                out[(ox, y)] = OUTLINE
        # outline above and below the pauldron
        for y in (y0, y0 + 4):
            for k in (1, 2):
                xs = [x for (x, yy) in px if yy == y0 + 1]
                if not xs:
                    continue
                x = (max(xs) if s > 0 else min(xs)) + s * k
                if 0 <= x < F and 0 <= y < F and (x, y) not in out and not (a[x, y][3] and not bc.is_outline(a[x, y])):
                    out[(x, y)] = OUTLINE
    return out


# ----------------------------------------------------------------- helm ----

def head(row, body, hair, outfit):
    """Visible head pixels of hair.png: {(x, y): ("hood"|"hair", colour)},
    the hood box and the row where the face opening starts (None from
    behind)."""
    h = hair.load()
    o = outfit.load()
    b = body.load()
    hood = [(x, y) for y in range(F) for x in range(F) if h[x, y][3] and bo.group(h[x, y], "hair") == "hood"]
    if not hood:
        return {}, None, None
    hx0 = min(p[0] for p in hood) - 1
    hx1 = max(p[0] for p in hood) + 1
    hy0 = min(p[1] for p in hood) - 1
    hy1 = max(p[1] for p in hood)
    px = {}
    for y in range(F):
        for x in range(F):
            p = h[x, y]
            k = p[3] and bo.group(p, "hair")
            if not k or o[x, y][3]:
                continue
            if k == "hood":
                px[(x, y)] = ("hood", p)
            elif not row.endswith("_up") and hx0 <= x <= hx1 and hy0 <= y <= hy1 + 1:
                px[(x, y)] = ("hair", p)
    face = [y for y in range(F) for x in range(hx0, hx1 + 1)
            if 0 <= x < F and hy0 <= y <= hy1 + 1 and (
                (b[x, y][3] and bc.is_skin(b[x, y])) or px.get((x, y), ("",))[0] == "hair")]
    face_top = min(face) if face and not row.endswith("_up") else None
    return px, (hx0 + 1, hy0 + 1, hx1 - 1, hy1), face_top


def helm_cell(row, body, hair, outfit, spec, hood_ramp):
    out = Image.new("RGBA", (F, F), (0, 0, 0, 0))
    q = out.load()
    px, box, face_top = head(row, body, hair, outfit)
    if not px:
        return out
    hx0, hy0, hx1, hy1 = box
    style = spec["style"]
    brim = face_top - 1 if face_top is not None else hy0 + 4
    standing = not row.startswith(("roll", "death"))
    if style == "circlet":
        gold = spec["gold"]
        xs = sorted(x for (x, y), (k, c) in px.items() if y == brim and k == "hood" and not bc.is_outline(c))
        for x in xs:
            q[x, brim] = gold[2 if x % 3 == 0 else 1] + (255,)
        if xs and row.endswith("_down"):
            mid = round((xs[0] + xs[-1]) / 2)
            q[mid, brim] = spec["gem"] + (255,)
            if (mid, brim - 1) in px:
                q[mid, brim - 1] = gold[1] + (255,)
        elif xs and row.endswith("_side") and standing:
            q[xs[-1], brim] = spec["gem"] + (255,)
        # dark under-edge so the thin band reads on a light hood
        for x in xs:
            if (x, brim + 1) in px and px[(x, brim + 1)][0] == "hood":
                q[x, brim + 1] = gold[0] + (255,)
        return out
    ramp = spec["ramp"]
    for (x, y), (k, c) in px.items():
        if k == "hair":
            q[x, y] = spec["inside"] + (255,)
        elif bc.is_outline(c):
            continue
        else:
            i = round(hood_ramp.index(c[:3]) * (len(ramp) - 1) / max(1, len(hood_ramp) - 1)) \
                if c[:3] in hood_ramp else 1
            q[x, y] = ramp[i] + (255,)
    if style in ("iron", "horned"):
        # bright brim band just above the face (or the same height behind),
        # and a nose guard down the middle of the face from the front
        xs = sorted(x for (x, y) in px if y == brim and q[x, y][3] and not bc.is_outline(q[x, y]))
        for x in xs:
            q[x, brim] = spec["brim"] + (255,)
        # a dark line under the brim across the fringe
        if face_top is not None:
            for x in range(hx0, hx1 + 1):
                if (x, face_top) in px and px[(x, face_top)][0] == "hair":
                    q[x, face_top] = spec["inside"] + (255,)
        if xs and row.endswith("_down") and face_top is not None:
            mid = round((xs[0] + xs[-1]) / 2)
            for y in (face_top, face_top + 1):
                q[mid, y] = ramp[2] + (255,)
        # rivet line down the crown
        if xs and (row.endswith("_down") or row.endswith("_up")):
            mid = round((xs[0] + xs[-1]) / 2)
            for y in range(hy0 + 1, brim):
                if q[mid, y][3] and not bc.is_outline(q[mid, y]):
                    q[mid, y] = ramp[3] + (255,)
    if style == "horned":
        horns(q, px, hy0, spec["horn"])
    return out


def horns(q, px, hy0, horn):
    """Two bone horns from the sides of the crown, curving up and out. From
    the side one points forward (right) and one back."""
    y = hy0 + 2
    xs = sorted(x for (x, yy) in px if yy == y)
    if not xs:
        return
    left, right = xs[0], xs[-1]
    pts = []
    for s, x in ((-1, left), (1, right)):
        shape = [(0, 0, 1), (1, -1, 1), (1, -2, 2), (2, -3, 2), (2, -4, 2)]
        for dx, dy, shade in shape:
            pts.append((x + s * dx, y + dy, horn[shade]))
    drawn = set()
    for x, yy, c in pts:
        if 0 <= x < F and 0 <= yy < F:
            q[x, yy] = c + (255,)
            drawn.add((x, yy))
    # outline around the horns where nothing else is
    for x, yy in list(drawn):
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = x + dx, yy + dy
            if 0 <= nx < F and 0 <= ny < F and (nx, ny) not in drawn and (nx, ny) not in px and not q[nx, ny][3]:
                q[nx, ny] = OUTLINE


# ---------------------------------------------------------------- sheets ----

def cells(img):
    for r in range(img.height // F):
        for c in range(COLS):
            yield r, c, (c * F, r * F, c * F + F, r * F + F)


def build_sheet(names, body, hair, outfit, weapon, gid, ramps, hood_ramp):
    out = Image.new("RGBA", outfit.size, (0, 0, 0, 0))
    for r, c, box in cells(outfit):
        cut = [im.crop(box) for im in (body, hair, outfit, weapon)]
        if not (cut[1].getbbox() or cut[2].getbbox()):
            continue
        if gid in ARMORS:
            cell = armor_cell(names[r], *cut, ARMORS[gid], ramps)
        else:
            cell = helm_cell(names[r], cut[0], cut[1], cut[2], HELMS[gid], hood_ramp)
        out.alpha_composite(cell, box[:2])
    return bo.no_orphans(out)


def main():
    args = [a for a in sys.argv[1:] if a != "--force"]
    force = "--force" in sys.argv
    root = args[0]
    ids = args[1:] or list(ARMORS) + list(HELMS)
    climber = os.path.join(root, "game/assets/characters/climber")
    base = {k: load(os.path.join(climber, k + ".png")) for k in ("body", "hair", "outfit", "weapon")}
    att_dir = os.path.join(climber, "attacks")
    kinds = sorted({f.split("_")[0] for f in os.listdir(att_dir) if f.endswith("_body.png")})
    attacks = {t: {k: load(os.path.join(att_dir, "%s_%s.png" % (t, k))) for k in ("body", "hair", "outfit")}
               for t in kinds}
    sheets = [("hair", base["hair"]), ("outfit", base["outfit"])]
    for t in kinds:
        sheets += [("hair", attacks[t]["hair"]), ("outfit", attacks[t]["outfit"])]
    ramps = bo.Ramps(sheets)
    hood_ramp = ramps.groups["hood"]
    gdir = os.path.join(climber, "gear")
    os.makedirs(os.path.join(gdir, "attacks"), exist_ok=True)
    for gid in ids:
        sheet = build_sheet(ROWS, base["body"], base["hair"], base["outfit"], base["weapon"], gid, ramps, hood_ramp)
        save_guarded(sheet, os.path.join(gdir, gid + ".png"), force)
        for t in kinds:
            a = attacks[t]
            wa = load(os.path.join(climber, "weapons", t + ".png")).crop((0, 6 * F, COLS * F, 9 * F))
            strip = build_sheet(ATTACK_ROWS, a["body"], a["hair"], a["outfit"], wa, gid, ramps, hood_ramp)
            save_guarded(strip, os.path.join(gdir, "attacks", "%s_%s.png" % (t, gid)), force)


if __name__ == "__main__":
    main()
