"""Take the backpack and the weapon hafts out of the climber's body, hair and
outfit layers, so only the backpack layer draws a pack and only the weapon
layer draws a weapon.

python3 -I art-src/split_layers.py <repo_root> [--refresh]

Run after build_weapons.py and before build_weapon_items.py,
build_outfits.py, build_gear.py and build_backpacks.py.

Inputs: the unsplit layers kept in art-src/split/orig/ (climber/hair.png,
outfit.png and attacks/<type>_{body,hair,outfit}.png as build_climber.py and
build_weapons.py made them). The first run, or --refresh after those scripts
ran again, copies them there from game/assets/characters/climber/.
Outputs:
  game/assets/characters/climber/{hair,outfit}.png and
  attacks/<type>_{body,hair,outfit}.png without the pack and haft pixels;
  art-src/split/pack.png (8x13) and pack_<type>.png (8x3): the pack pixels
    taken out, in their own colours (build_backpacks.py repaints them);
  art-src/split/haft_<type>.png (8x3, axe and spear): the haft pixels taken
    out of the attack strips (build_weapon_items.py repaints them).

The pack, per frame (only colour pixels move; the dark outline stays):
  - standing rows (idle, walk, attack), from the side: the leather pixels of
    the back part of the torso (the back 38% of its width at the shoulders,
    above the trousers), plus the warm flap pixels of hair.png behind the
    hood; from behind: the leather in the middle of the back (the middle half
    of the torso), plus the flap; from the front: none;
  - roll and death: the leather inside a box per frame (PACK_BOXES), where
    the pack shows; none where it does not.
The haft, per attack frame of the axe and the spear: the longest thin
straight run of strip pixels (1 px wide, outline or nothing on both sides)
leaving the weapon pixels of weapons/<type>.png, up to two runs per frame.
"""
import math
import os
import shutil
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from PIL import Image  # noqa: E402

import build_climber as bc  # noqa: E402
import build_outfits as bo  # noqa: E402

F = 32
COLS = 8
ROWS = bc.ROW_NAMES
ATTACK_ROWS = ["attack_down", "attack_up", "attack_side"]
HAFT_TYPES = ["axe", "spear"]

# (row, frame) -> (x0, y0, x1, y1) inclusive: where the pack shows in the
# roll and death frames of the starter sheet (read off 12x crops).
PACK_BOXES = {
    ("roll_down", 3): (10, 14, 18, 22),
    ("roll_up", 0): (9, 17, 20, 24),
    ("roll_up", 2): (10, 18, 19, 27),
    ("roll_up", 3): (13, 19, 21, 27),
    ("roll_up", 4): (11, 18, 19, 24),
    ("roll_up", 5): (12, 17, 20, 24),
    ("roll_side", 0): (5, 14, 11, 21),
    ("roll_side", 1): (11, 11, 19, 16),
    ("roll_side", 2): (9, 11, 17, 19),
    ("roll_side", 3): (12, 18, 20, 26),
    ("roll_side", 4): (11, 11, 16, 16),
    ("roll_side", 5): (4, 13, 10, 20),
    ("death", 4): (4, 22, 7, 27),
    ("death", 5): (4, 22, 7, 27),
}


def load(path):
    return Image.open(path).convert("RGBA")


def leather(p):
    return p[3] and not bc.is_outline(p) and bo.group(p, "outfit") == "leather"


def torso_box(body, hair, outfit):
    """(x0, y0, x1, legs_top) of the jacket at the shoulders, or None."""
    legs = bo.legs_box(body, hair, outfit)
    if not legs:
        return None
    o = outfit.load()
    h = hair.load()
    # below the hood: arms raised over the head are not the back
    hood = [y for y in range(F) for x in range(F) if h[x, y][3] and bo.group(h[x, y], "hair") == "hood"]
    top = max(hood) - 1 if hood else 0
    pts = [(x, y) for y in range(top, legs[0]) for x in range(F) if o[x, y][3] and not bc.is_outline(o[x, y])]
    if not pts:
        return None
    y0 = min(p[1] for p in pts)
    xs = [p[0] for p in pts if y0 + 1 <= p[1] <= y0 + 4] or [p[0] for p in pts]
    return min(xs), y0, max(xs), legs[0]


def flap(row, hair):
    """Warm pixels of hair.png that are the pack's flap, not hair (the rule
    build_outfits.py uses)."""
    h = hair.load()
    hood = [(x, y) for y in range(F) for x in range(F) if h[x, y][3] and bo.group(h[x, y], "hair") == "hood"]
    if not hood:
        return set()
    hx0 = min(p[0] for p in hood) - 1
    hx1 = max(p[0] for p in hood) + 1
    hy0 = min(p[1] for p in hood) - 1
    hy1 = max(p[1] for p in hood)
    out = set()
    # the flap hangs below the hood; warm specks up on the hood stay hair
    for y in range(hy1 - 2, F):
        for x in range(F):
            p = h[x, y]
            if p[3] and not bc.is_outline(p) and bo.group(p, "hair") == "hair":
                if row.endswith("_up") or not (hx0 <= x <= hx1 and y >= hy0):
                    out.add((x, y))
    return out


def pack_mask(row, col, body, hair, outfit):
    """-> (outfit pixels, hair pixels) of the pack in this cell."""
    o = outfit.load()
    if row.startswith(("roll", "death")):
        box = PACK_BOXES.get((row, col))
        if not box:
            return set(), set()
        x0, y0, x1, y1 = box
        return {(x, y) for y in range(y0, y1 + 1) for x in range(x0, x1 + 1) if leather(o[x, y])}, set()
    if row.endswith("_down"):
        return set(), set()
    box = torso_box(body, hair, outfit)
    if not box:
        return set(), set()
    tx0, ty0, tx1, legs_top = box
    w = tx1 - tx0 + 1
    if row.endswith("side"):
        # (at most 5 px: an arm thrust forward widens the shoulders)
        def inside(x):
            return x < tx0 + min(5, round(0.38 * w))
    else:
        cx = (tx0 + tx1) / 2

        def inside(x):
            return abs(x - cx) <= w / 4
    out = {(x, y) for y in range(ty0, legs_top) for x in range(F) if inside(x) and leather(o[x, y])}
    # the flap hangs on the back, below the shoulders (hands raised over
    # the head are warm pixels of hair.png too)
    return out, {p for p in flap(row, hair) if p[1] >= ty0}


# ----------------------------------------------------------------- hafts ----

def haft_runs(strip, weapon):
    """Thin straight runs of `strip` pixels leaving the weapon pixels."""
    s = strip.load()
    w = weapon.load()
    W = {(x, y) for y in range(F) for x in range(F) if w[x, y][3] and not bc.is_outline(w[x, y])}
    if not W:
        return []

    def solid(x, y):
        p = s[x, y] if 0 <= x < F and 0 <= y < F else (0, 0, 0, 0)
        return p[3] and not bc.is_outline(p) and not bc.is_skin(p) and (x, y) not in W

    def wood(x, y):
        # the weapon's wood (palette of climber/weapon.png): yellower than
        # the jacket leather (g/r 0.65+ against 0.5-0.57), never green
        if not solid(x, y):
            return False
        p = s[x, y]
        return p[1] < p[0] and p[1] >= 0.62 * p[0]

    border = [p for p in W if any((p[0] + dx, p[1] + dy) not in W for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))]
    runs = []
    taken = set()
    for _ in range(2):
        best = []
        for k in range(64):
            a = k * math.tau / 64
            d = (math.cos(a), math.sin(a))
            for sx, sy in border:
                run = []
                for t in range(1, 22):
                    x, y = round(sx + d[0] * t), round(sy + d[1] * t)
                    if (x, y) in W or (x, y) in taken:
                        if run:
                            break
                        continue
                    if not wood(x, y):
                        break
                    # thin: no other colour pixel beside the line
                    side = 0
                    for dx in (-1, 0, 1):
                        for dy in (-1, 0, 1):
                            q = (x + dx, y + dy)
                            if (dx or dy) and solid(*q):
                                off = abs(-(q[0] - sx) * d[1] + (q[1] - sy) * d[0])
                                if off > 0.9:
                                    side += 1
                    if side > 1:
                        break
                    if (x, y) not in run:
                        run.append((x, y))
                if len(run) > len(best):
                    best = run
        if len(best) < 3:
            break
        runs.append(best)
        taken.update(best)
    return [p for r in runs for p in r]


# ------------------------------------------------------------------ main ----

def cell(img, r, c):
    return img.crop((c * F, r * F, c * F + F, r * F + F))


def split_sheet(names, body, hair, outfit, weapon=None):
    """-> (body, hair, outfit without pack and haft, pack pixels, haft pixels)."""
    body, hair, outfit = body.copy(), hair.copy(), outfit.copy()
    pack = Image.new("RGBA", outfit.size, (0, 0, 0, 0))
    haft = Image.new("RGBA", outfit.size, (0, 0, 0, 0))
    for r, row in enumerate(names):
        for c in range(COLS):
            cb, ch, co = cell(body, r, c), cell(hair, r, c), cell(outfit, r, c)
            if not (ch.getbbox() or co.getbbox()):
                continue
            mo, mh = pack_mask(row, c, cb, ch, co)
            for (x, y) in mo:
                pack.putpixel((c * F + x, r * F + y), outfit.getpixel((c * F + x, r * F + y)))
                outfit.putpixel((c * F + x, r * F + y), (0, 0, 0, 0))
            for (x, y) in mh:
                pack.putpixel((c * F + x, r * F + y), hair.getpixel((c * F + x, r * F + y)))
                hair.putpixel((c * F + x, r * F + y), (0, 0, 0, 0))
            if weapon is not None:
                comp = Image.new("RGBA", (F, F), (0, 0, 0, 0))
                for im in (cell(body, r, c), cell(hair, r, c), cell(outfit, r, c)):
                    comp.alpha_composite(im)
                for (x, y) in haft_runs(comp, cell(weapon, r, c)):
                    for layer in (outfit, hair, body):
                        p = layer.getpixel((c * F + x, r * F + y))
                        if p[3]:
                            haft.putpixel((c * F + x, r * F + y), p)
                            layer.putpixel((c * F + x, r * F + y), (0, 0, 0, 0))
                            break
    # specks left alone by the cut (an outline pixel of the pack's edge) go
    # with the pack
    for layer in (hair, outfit):
        a = layer.getchannel("A").load()
        w, h = layer.size
        for y in range(h):
            for x in range(w):
                if a[x, y] and not any(0 <= x + dx < w and 0 <= y + dy < h and a[x + dx, y + dy]
                                       for dx in (-1, 0, 1) for dy in (-1, 0, 1) if dx or dy):
                    pack.putpixel((x, y), layer.getpixel((x, y)))
                    layer.putpixel((x, y), (0, 0, 0, 0))
    return body, hair, outfit, pack, haft


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    root = args[0]
    climber = os.path.join(root, "game/assets/characters/climber")
    sdir = os.path.join(root, "art-src/split")
    odir = os.path.join(sdir, "orig")
    att = os.path.join(climber, "attacks")
    kinds = sorted({f.split("_")[0] for f in os.listdir(att) if f.endswith("_body.png")})
    files = ["hair.png", "outfit.png"] + ["attacks/%s_%s.png" % (t, k) for t in kinds for k in ("body", "hair", "outfit")]
    if "--refresh" in sys.argv or not os.path.isdir(odir):
        os.makedirs(os.path.join(odir, "attacks"), exist_ok=True)
        for f in files:
            shutil.copyfile(os.path.join(climber, f), os.path.join(odir, f))
        print("kept the unsplit layers in", odir)
    body = load(os.path.join(climber, "body.png"))
    _, hair, outfit, pack, _ = split_sheet(ROWS, body, load(os.path.join(odir, "hair.png")),
                                           load(os.path.join(odir, "outfit.png")))
    hair.save(os.path.join(climber, "hair.png"))
    outfit.save(os.path.join(climber, "outfit.png"))
    pack.save(os.path.join(sdir, "pack.png"))
    for t in kinds:
        a = {k: load(os.path.join(odir, "attacks", "%s_%s.png" % (t, k))) for k in ("body", "hair", "outfit")}
        weapon = None
        if t in HAFT_TYPES:
            weapon = load(os.path.join(climber, "weapons", t + ".png")).crop((0, 6 * F, COLS * F, 9 * F))
        b, h, o, pk, hf = split_sheet(ATTACK_ROWS, a["body"], a["hair"], a["outfit"], weapon)
        b.save(os.path.join(att, "%s_body.png" % t))
        h.save(os.path.join(att, "%s_hair.png" % t))
        o.save(os.path.join(att, "%s_outfit.png" % t))
        pk.save(os.path.join(sdir, "pack_%s.png" % t))
        if t in HAFT_TYPES:
            hf.save(os.path.join(sdir, "haft_%s.png" % t))
    print("split", len(files), "layers")


if __name__ == "__main__":
    main()
