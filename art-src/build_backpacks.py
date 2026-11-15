"""Build the backpack layer of the climber, one sheet per backpack item.

python3 -I art-src/build_backpacks.py <repo_root> [--force] [id ...]

Inputs: game/assets/items/<id>.png (the icon), the pack pixels split_layers.py
took out of the starter layers (art-src/split/pack.png, pack_<type>.png),
the unsplit layers it kept (art-src/split/orig/, for the torso of each
frame), climber/body.png, and the armor and helm sheets in climber/gear/
(build_gear.py, for the front view).
Outputs, per backpack id (backpack_* in game/data/item_catalog.gd):
  climber/gear/<id>.png                  8x13 grid of 32x32
  climber/gear/attacks/<type>_<id>.png   8x3 (attack_down, attack_up,
    attack_side), one per attack override

The game draws it between the armor and the helm (LayeredSprite), whatever
the outfit, the armor and "Mostrar armadura" (a backpack is always worn).
Only this layer draws a pack: the outfit, hair and armor layers have a hole
where the starter pack was, and every backpack covers it. Per frame:
  - the starter pack pixels, repainted on the item's ramp by brightness rank
    (so the hole is always filled, roll and death included);
  - standing rows (idle, walk, attack) from behind and from the side: the
    item's pack drawn over them from the torso of that frame (sizes below),
    under the hood;
  - from the front: the item's shoulder straps over the jacket (width and
    colour per item) and the parts of the pack that stick out around the
    body, hair and every armor and helm (the blanket or bedroll ends by the
    shoulders).
Sizes: the small pack is a compact satchel, the medium one is taller with a
slate-grey blanket roll on top, the large one is a tall frame pack with a
thick bedroll. Colours: k-means on the icon (body: the lower part, roll: the
top rows), sorted dark -> light.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from PIL import Image  # noqa: E402

import build_climber as bc  # noqa: E402
import build_outfits as bo  # noqa: E402
import split_layers as sl  # noqa: E402
from artlib import OUTLINE, icon_ramp, lum, save_guarded  # noqa: E402

F = 32
COLS = 8
ROWS = bc.ROW_NAMES
ATTACK_ROWS = ["attack_down", "attack_up", "attack_side"]

# w, h: pack seen from behind; back: how far the pack reaches behind the
# back edge in the side view; roll: (width, height) of the roll on top
# (0 = none); strap: (width, ramp index) of the shoulder straps seen from
# the front. Icon parts: body (rows >= 6), roll (rows <= 5; the medium
# pack's roll is its slate-grey blanket, not the tan straps around it).
PACKS = {
    "backpack_small": {"w": 7, "h": 7, "back": 0, "roll": (0, 0), "strap": (1, 0)},
    "backpack_medium": {"w": 9, "h": 8, "back": 1, "roll": (15, 2), "strap": (1, 3),
                        "roll_select": lambda x, y, c: y <= 5 and c[2] >= c[0] - 12},
    "backpack_large": {"w": 11, "h": 10, "back": 2, "roll": (19, 3), "strap": (2, 2)},
}


def palette(root, pid):
    path = os.path.join(root, "game/assets/items", pid + ".png")
    spec = PACKS[pid]
    pal = {"body": icon_ramp(path, 4, None if spec["roll"][0] == 0 else lambda x, y, c: y >= 6)}
    if spec["roll"][0]:
        pal["roll"] = icon_ramp(path, 3, spec.get("roll_select", lambda x, y, c: y <= 5), dark=28)
    return pal


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


def straps(spec, pal, box, outfit):
    """Two shoulder straps over the jacket, seen from the front."""
    tx0, ty0, tx1, ty1 = box
    width, shade_i = spec["strap"]
    o = outfit.load()
    px = {}
    for x0 in (tx0 + 3, tx1 - 3 - (width - 1)):
        for x in range(x0, x0 + width):
            for y in range(ty0, min(ty0 + 6, ty1)):
                p = o[x, y]
                if p[3] and not bc.is_outline(p) and bo.group(p, "outfit") in ("leather", "khaki"):
                    c = pal["body"][shade_i]
                    if y == ty0 + 3:
                        c = pal["body"][3] if shade_i < 3 else pal["body"][1]  # buckle
                    px[(x, y)] = c
    return px


def pack_cell(row, body, hair, outfit, gear, extract, emap, spec, pal):
    """One frame: hair and outfit are the unsplit starter layers (for the
    torso), `extract` the starter pack pixels taken out of them."""
    out = Image.new("RGBA", (F, F), (0, 0, 0, 0))
    q = out.load()
    e = extract.load()
    for y in range(F):
        for x in range(F):
            if e[x, y][3]:
                q[x, y] = emap[e[x, y][:3]] + (255,)
    if row.startswith(("roll", "death")):
        return out
    box = sl.torso_box(body, hair, outfit)
    if not box:
        return out
    px = pack_pixels(spec, pal, box, row)
    h = hair.load()
    if row.endswith("_down"):
        sil = Image.new("RGBA", (F, F), (0, 0, 0, 0))
        for im in [body, hair, outfit] + gear:
            sil.alpha_composite(im)
        s = sil.load()
        for (x, y), c in px.items():
            if 0 <= x < F and 0 <= y <= bc.BASE and not s[x, y][3]:
                q[x, y] = c + (255,)
        for (x, y), c in straps(spec, pal, box, outfit).items():
            q[x, y] = c + (255,)
    else:
        for (x, y), c in px.items():
            if not (0 <= x < F and 0 <= y <= bc.BASE):
                continue
            if h[x, y][3] and bo.group(h[x, y], "hair") == "hood":
                continue  # the hood hangs over the pack
            q[x, y] = c + (255,)
    return out


def extract_map(extracts, pal):
    """Starter pack colour -> item ramp colour, by brightness rank."""
    cols = sorted({p[:3] for im in extracts for p in im.get_flattened_data() if p[3]}, key=lum)
    ramp = pal["body"]
    out = {}
    for i, c in enumerate(cols):
        out[c] = OUTLINE[:3] if bc.is_outline(c) else ramp[round(i * (len(ramp) - 1) / max(1, len(cols) - 1))]
    return out


def build_sheet(names, body, hair, outfit, gear, extract, emap, spec, pal):
    out = Image.new("RGBA", outfit.size, (0, 0, 0, 0))
    for r in range(outfit.height // F):
        for c in range(COLS):
            box = (c * F, r * F, c * F + F, r * F + F)
            cut = [im.crop(box) for im in (body, hair, outfit)]
            if not cut[2].getbbox():
                continue
            g = [im.crop(box) for im in gear]
            out.alpha_composite(pack_cell(names[r], *cut, g, extract.crop(box), emap, spec, pal), box[:2])
    return bo.no_orphans(out)


def main():
    args = [a for a in sys.argv[1:] if a != "--force"]
    force = "--force" in sys.argv
    root = args[0]
    ids = args[1:] or list(PACKS)
    climber = os.path.join(root, "game/assets/characters/climber")
    split = os.path.join(root, "art-src/split")
    orig = os.path.join(split, "orig")
    gdir = os.path.join(climber, "gear")
    load = bo.load
    body = load(os.path.join(climber, "body.png"))
    hair, outfit = load(os.path.join(orig, "hair.png")), load(os.path.join(orig, "outfit.png"))
    att_dir = os.path.join(climber, "attacks")
    kinds = sorted({f.split("_")[0] for f in os.listdir(att_dir) if f.endswith("_body.png")})
    extracts = {"": load(os.path.join(split, "pack.png"))}
    extracts.update({t: load(os.path.join(split, "pack_%s.png" % t)) for t in kinds})
    worn = sorted(f[:-4] for f in os.listdir(gdir) if f.startswith(("armor_", "helm_")) and f.endswith(".png"))
    gear = [load(os.path.join(gdir, g + ".png")) for g in worn]
    os.makedirs(os.path.join(gdir, "attacks"), exist_ok=True)
    for pid in ids:
        spec, pal = PACKS[pid], palette(root, pid)
        emap = extract_map(extracts.values(), pal)
        sheet = build_sheet(ROWS, body, hair, outfit, gear, extracts[""], emap, spec, pal)
        save_guarded(sheet, os.path.join(gdir, pid + ".png"), force)
        for t in kinds:
            a = {k: load(os.path.join(orig, "attacks", "%s_%s.png" % (t, k))) for k in ("body", "hair", "outfit")}
            ga = [load(os.path.join(gdir, "attacks", "%s_%s.png" % (t, g))) for g in worn]
            strip = build_sheet(ATTACK_ROWS, a["body"], a["hair"], a["outfit"], ga, extracts[t], emap, spec, pal)
            save_guarded(strip, os.path.join(gdir, "attacks", "%s_%s.png" % (t, pid)), force)


if __name__ == "__main__":
    main()
