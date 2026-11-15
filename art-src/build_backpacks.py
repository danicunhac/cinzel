"""Build the backpack layer of the climber, one sheet per backpack item.

python3 -I art-src/build_backpacks.py <repo_root> [--force] [id ...]

Inputs: game/assets/items/<id>.png (the icon), climber/{body,hair,outfit}.png,
the attack overrides climber/attacks/<type>_{body,hair,outfit}.png and the
armor and helm sheets in climber/gear/ (build_gear.py).
Outputs, per backpack id (backpack_* in game/data/item_catalog.gd):
  climber/gear/<id>.png                  8x13 grid of 32x32
  climber/gear/attacks/<type>_<id>.png   8x3 (attack_down, attack_up,
    attack_side), one per attack override

The game draws it between the armor and the helm (LayeredSprite), whatever
the outfit, the armor and "Mostrar armadura" (a backpack is always worn).
Per standing frame (idle, walk, attack) the pack is drawn from the torso of
the starter outfit.png in that frame (the jacket above the trousers):
  - from behind (*_up): over the middle of the back, under the hood;
  - from the side (facing right): on the back edge of the torso, over the
    bulge the starter outfit already draws there, under the hood;
  - from the front (*_down): only the parts that stick out around the body,
    hair and every armor and helm (the bedroll over the shoulders), plus
    the two shoulder straps over the jacket.
Sizes and colours per item: the small pack is a compact satchel, the
medium one is taller with a grey blanket roll on top, the large one is a
tall frame pack with a thick bedroll. Colours: k-means on the icon (body:
the lower part, roll: the top rows), sorted dark -> light.
Roll and death rows draw nothing (the outfit's own pack shows there).
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from PIL import Image  # noqa: E402

import build_climber as bc  # noqa: E402
import build_outfits as bo  # noqa: E402
from artlib import OUTLINE, icon_ramp, save_guarded  # noqa: E402

F = 32
COLS = 8
ROWS = bc.ROW_NAMES
ATTACK_ROWS = ["attack_down", "attack_up", "attack_side"]

# w, h: pack seen from behind; back: how far the pack reaches behind the
# back edge in the side view; roll: (width, height) of the roll on top
# (0 = none). Icon parts: body (rows >= 6), roll (rows <= 5; the medium
# pack's roll is its slate-grey blanket, not the tan straps around it).
PACKS = {
    "backpack_small": {"w": 7, "h": 6, "back": 0, "roll": (0, 0)},
    "backpack_medium": {"w": 9, "h": 7, "back": 1, "roll": (15, 2),
                        "roll_select": lambda x, y, c: y <= 5 and c[2] >= c[0] - 12},
    "backpack_large": {"w": 11, "h": 9, "back": 2, "roll": (19, 3)},
}


def palette(root, pid):
    path = os.path.join(root, "game/assets/items", pid + ".png")
    spec = PACKS[pid]
    pal = {"body": icon_ramp(path, 4, None if spec["roll"][0] == 0 else lambda x, y, c: y >= 6)}
    if spec["roll"][0]:
        pal["roll"] = icon_ramp(path, 3, spec.get("roll_select", lambda x, y, c: y <= 5), dark=28)
    return pal


def torso(body, hair, outfit, row):
    """(x0, y0, x1, y1) of the jacket above the trousers, or None."""
    legs = bo.legs_box(body, hair, outfit)
    if not legs:
        return None
    o = outfit.load()
    pts = [(x, y) for y in range(legs[0]) for x in range(F)
           if o[x, y][3] and bo.group(o[x, y], "outfit") in ("leather", "scarf")]
    if not pts:
        return None
    x0 = min(p[0] for p in pts)
    x1 = max(p[0] for p in pts)
    y0 = min(p[1] for p in pts)
    if row.endswith("side"):
        # the back edge at the shoulders (arms hang lower and swing)
        xs = [p[0] for p in pts if y0 + 1 <= p[1] <= y0 + 3]
        x0 = min(xs) if xs else x0
    return x0, y0, x1, legs[0]


def shade(ramp, x, y, x0, y0, x1, y1):
    """Lit from the top-left: the outer edge darker, top-left lighter."""
    if x == x1 or y == y1:
        return ramp[0]
    if y == y0:
        return ramp[3]
    if x == x0 or y == y0 + 1:
        return ramp[2]
    return ramp[1] if (x - x0 + y - y0) % 5 else ramp[2]


def pack_pixels(spec, pal, box, row):
    """{(x, y): colour} of the whole pack (with its outline) in this frame."""
    tx0, ty0, tx1, ty1 = box
    px = {}
    body = pal["body"]
    if row.endswith("side"):
        x1 = tx0 + 4
        x0 = tx0 - spec["back"]
    else:
        cx = (tx0 + tx1 + 1) // 2
        x0 = cx - spec["w"] // 2
        x1 = x0 + spec["w"] - 1
    y0 = ty0 + 1
    # down to the hips at most (about 10 rows below the shoulders)
    y1 = min(y0 + spec["h"] - 1, ty0 + 10)
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            corner = (x in (x0, x1)) and (y in (y0, y1))
            if corner:
                continue
            edge = x in (x0, x1) or y in (y0, y1) or ((x in (x0 + 1, x1 - 1)) and (y in (y0, y1)))
            px[(x, y)] = OUTLINE[:3] if edge else shade(body, x, y, x0 + 1, y0 + 1, x1 - 1, y1 - 1)
    # flap: a darker line two rows down with a light buckle in the middle
    fy = y0 + 2
    for x in range(x0 + 1, x1):
        if (x, fy) in px and px[(x, fy)] != OUTLINE[:3]:
            px[(x, fy)] = body[0]
    bx = (x0 + x1) // 2 if not row.endswith("side") else x0 + 1
    if (bx, fy + 1) in px:
        px[(bx, fy + 1)] = body[3]
    rw, rh = spec["roll"]
    if rw:
        roll = pal["roll"]
        if row.endswith("side"):
            # the roll seen end-on: a disc on top of the pack
            rx0, rx1 = x0, x0 + rh + 1
        else:
            rcx = (x0 + x1 + 1) // 2
            rx0 = rcx - rw // 2
            rx1 = rx0 + rw - 1
        ry1 = y0
        ry0 = y0 - rh - 1
        for y in range(ry0, ry1 + 1):
            for x in range(rx0, rx1 + 1):
                if (x in (rx0, rx1)) and (y in (ry0, ry1)):
                    continue
                edge = x in (rx0, rx1) or y in (ry0, ry1)
                if edge:
                    px[(x, y)] = OUTLINE[:3]
                else:
                    band = (y - ry0 - 1) * len(roll) // max(1, ry1 - ry0 - 1)
                    c = roll[min(len(roll) - 1, len(roll) - 1 - band)]
                    if (x - rx0) % 4 == 0 and not row.endswith("side"):
                        c = roll[0]  # tie straps around the roll
                    px[(x, y)] = c
    return px


def straps(pal, box, outfit, hair):
    """Two shoulder straps over the jacket, seen from the front."""
    tx0, ty0, tx1, ty1 = box
    o = outfit.load()
    px = {}
    for x in (tx0 + 3, tx1 - 3):
        for y in range(ty0, min(ty0 + 5, ty1)):
            p = o[x, y]
            if p[3] and not bc.is_outline(p) and bo.group(p, "outfit") == "leather":
                px[(x, y)] = pal["body"][3] if y == ty0 + 2 else pal["body"][1]
    return px


def pack_cell(row, body, hair, outfit, gear, spec, pal):
    out = Image.new("RGBA", (F, F), (0, 0, 0, 0))
    if row.startswith(("roll", "death")):
        return out
    box = torso(body, hair, outfit, row)
    if not box:
        return out
    px = pack_pixels(spec, pal, box, row)
    h = hair.load()
    q = out.load()
    if row.endswith("_down"):
        sil = Image.new("RGBA", (F, F), (0, 0, 0, 0))
        for im in [body, hair, outfit] + gear:
            sil.alpha_composite(im)
        s = sil.load()
        for (x, y), c in px.items():
            if 0 <= x < F and 0 <= y <= bc.BASE and not s[x, y][3]:
                q[x, y] = c + (255,)
        for (x, y), c in straps(pal, box, outfit, hair).items():
            q[x, y] = c + (255,)
    else:
        for (x, y), c in px.items():
            if not (0 <= x < F and 0 <= y <= bc.BASE):
                continue
            if h[x, y][3] and bo.group(h[x, y], "hair") == "hood":
                continue  # the hood hangs over the pack
            q[x, y] = c + (255,)
    return out


def build_sheet(names, body, hair, outfit, gear, spec, pal):
    out = Image.new("RGBA", outfit.size, (0, 0, 0, 0))
    for r in range(outfit.height // F):
        for c in range(COLS):
            box = (c * F, r * F, c * F + F, r * F + F)
            cut = [im.crop(box) for im in (body, hair, outfit)]
            if not cut[2].getbbox():
                continue
            g = [im.crop(box) for im in gear]
            out.alpha_composite(pack_cell(names[r], *cut, g, spec, pal), box[:2])
    return bo.no_orphans(out)


def main():
    args = [a for a in sys.argv[1:] if a != "--force"]
    force = "--force" in sys.argv
    root = args[0]
    ids = args[1:] or list(PACKS)
    climber = os.path.join(root, "game/assets/characters/climber")
    gdir = os.path.join(climber, "gear")
    load = bo.load
    base = {k: load(os.path.join(climber, k + ".png")) for k in ("body", "hair", "outfit")}
    att_dir = os.path.join(climber, "attacks")
    kinds = sorted({f.split("_")[0] for f in os.listdir(att_dir) if f.endswith("_body.png")})
    worn = sorted(f[:-4] for f in os.listdir(gdir) if f.startswith(("armor_", "helm_")) and f.endswith(".png"))
    gear = [load(os.path.join(gdir, g + ".png")) for g in worn]
    os.makedirs(os.path.join(gdir, "attacks"), exist_ok=True)
    for pid in ids:
        spec, pal = PACKS[pid], palette(root, pid)
        sheet = build_sheet(ROWS, base["body"], base["hair"], base["outfit"], gear, spec, pal)
        save_guarded(sheet, os.path.join(gdir, pid + ".png"), force)
        for t in kinds:
            a = {k: load(os.path.join(att_dir, "%s_%s.png" % (t, k))) for k in ("body", "hair", "outfit")}
            ga = [load(os.path.join(gdir, "attacks", "%s_%s.png" % (t, g))) for g in worn]
            strip = build_sheet(ATTACK_ROWS, a["body"], a["hair"], a["outfit"], ga, spec, pal)
            save_guarded(strip, os.path.join(gdir, "attacks", "%s_%s.png" % (t, pid)), force)


if __name__ == "__main__":
    main()
