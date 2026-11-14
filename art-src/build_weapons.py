"""Build the per-weapon climber layers.

python3 -I art-src/build_weapons.py <repo_root> [--force] [type ...]

Outputs (8x13 grid of 32x32, same rows as the climber sheets):
  game/assets/characters/climber/weapons/<type>.png   weapon pixels only
  game/assets/characters/climber/attacks/<type>_{body,hair,outfit}.png
    8 cols x 3 rows (attack_down, attack_up, attack_side; 6 frames each),
    only for the types in OVERRIDES: their attack swaps the body pose too.

Idle, walk, roll and death rows: the weapon is drawn by script in the hand.
Per frame, the shipped sword (climber/weapon.png) gives the grip (the blade
end touching the glove) and the direction it points; each type draws its own
shape from that grip (longer blade, axe head, spear shaft, bow held upright).
In the *_up rows the weapon hides behind the body except at the grip.

Attack rows: sword keeps the shipped rows. Types in OVERRIDES use generated
strips (art-src/gen/r2/climber32-attack-<type>-<dir>-N.png, AI generator
edit_image, see docs/assets.md) cut and scaled with the build_climber.py
recipe (feet on row 30, centre column 16, figure 25 px tall), split into
layers with its classify(), and mapped onto the colours already used by the
shipped layers, so a swapped attack matches the rest of the sheet.
"""
import math
import os
import statistics
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from PIL import Image  # noqa: E402

import build_climber as bc  # noqa: E402
from artlib import OUTLINE, is_steel, save_guarded  # noqa: E402
from strips import drop_orphans, key, nearest, outline, runs, shrink  # noqa: E402

F = 32
COLS = 8
ROWS = bc.ROW_NAMES
ATTACK_ROWS = ["attack_down", "attack_up", "attack_side"]
TYPES = ["sword", "longsword", "axe", "spear", "dagger", "bow"]
DIRS = ["down", "up", "side"]

# type -> dir -> (strip file in art-src/gen/r2, x shift of the anchor, one
# value or one per frame (negative moves the figure left, so a weapon
# reaching right fits the cell), source boxes to erase first)
OVERRIDES = {
    "axe": {
        "down": ("climber32-attack-axe-down-1.png", 0, ()),
        "up": ("climber32-attack-axe-up-1.png", 0, ()),
        "side": ("climber32-attack-axe-side-1.png", -2, ()),
    },
    "spear": {
        "down": ("climber32-attack-spear-down-1.png", 0, ()),
        "up": ("climber32-attack-spear-up-2.png", 0, ()),
        "side": ("climber32-attack-spear-side-2.png", (-4, -4, -6, -7, -4, -4), ()),
    },
    "dagger": {
        "down": ("climber32-attack-dagger-down-1.png", 0, ()),
        "up": ("climber32-attack-dagger-up-1.png", 0, ()),
        "side": ("climber32-attack-dagger-side-1.png", (0, -3, 0, -3, 0, 0), ()),
    },
    "longsword": {
        "down": ("climber32-attack-longsword-down-1.png", 0, ()),
        "up": ("climber32-attack-longsword-up-2.png", 0, ()),
        "side": ("climber32-attack-longsword-side-1.png", (-2, -3, -5, -5, -3, -2), ()),
    },
    "bow": {
        "down": ("climber32-attack-bow-down-2.png", 0, ()),
        "up": ("climber32-attack-bow-up-2.png", 0, ()),
        # the arrow flying off in frame 5 (the game spawns its own arrow)
        "side": ("climber32-attack-bow-side-1.png", -2, ((845, 240, 945, 285),)),
    },
}

STEEL_D, STEEL_M, STEEL_L, STEEL_H = (96, 94, 92), (157, 154, 144), (208, 200, 187), (248, 233, 214)
WOOD_D, WOOD_M, WOOD_L = (94, 46, 22), (137, 75, 32), (171, 123, 64)
GUARD = (142, 103, 46)
STRING_C = (157, 154, 144)


def load(path):
    return Image.open(path).convert("RGBA")


def cell(img, r, c):
    return img.crop((c * F, r * F, c * F + F, r * F + F))


# ---------------------------------------------------------------- grip ----

def lum(c):
    return 0.3 * c[0] + 0.59 * c[1] + 0.11 * c[2]


def blade_pixels(wcell):
    px = wcell.load()
    return [(x, y) for y in range(F) for x in range(F)
            if px[x, y][3] and lum(px[x, y]) > 110 and max(px[x, y][:3]) - min(px[x, y][:3]) < 70]


def grip(wcell, others):
    """(grip point, unit direction grip->tip, blade length) of the shipped
    sword in this frame, or None when the frame shows no sword."""
    pts = blade_pixels(wcell)
    if len(pts) < 2:
        return None
    mx = sum(p[0] for p in pts) / len(pts)
    my = sum(p[1] for p in pts) / len(pts)
    sxx = sum((p[0] - mx) ** 2 for p in pts)
    syy = sum((p[1] - my) ** 2 for p in pts)
    sxy = sum((p[0] - mx) * (p[1] - my) for p in pts)
    ang = 0.5 * math.atan2(2 * sxy, sxx - syy)
    ax = (math.cos(ang), math.sin(ang))
    proj = [((p[0] - mx) * ax[0] + (p[1] - my) * ax[1], p) for p in pts]
    a = min(proj)[1]
    b = max(proj)[1]
    o = others.load()

    def touch(p):
        return sum(1 for dx in (-1, 0, 1) for dy in (-1, 0, 1)
                   if 0 <= p[0] + dx < F and 0 <= p[1] + dy < F and o[p[0] + dx, p[1] + dy][3])

    if touch(a) == touch(b):
        # tie: the end nearer the body centre is the grip
        bb = others.getbbox()
        cx, cy = ((bb[0] + bb[2]) / 2, (bb[1] + bb[3]) / 2) if bb else (16, 20)
        hilt, tip = (a, b) if math.dist(a, (cx, cy)) < math.dist(b, (cx, cy)) else (b, a)
    else:
        hilt, tip = (a, b) if touch(a) > touch(b) else (b, a)
    L = math.dist(hilt, tip)
    d = ((tip[0] - hilt[0]) / L, (tip[1] - hilt[1]) / L) if L else (0.7071, 0.7071)
    return hilt, d, L


# ------------------------------------------------------------- drawing ----

def line(p0, p1):
    x0, y0 = round(p0[0]), round(p0[1])
    x1, y1 = round(p1[0]), round(p1[1])
    dx, dy = abs(x1 - x0), -abs(y1 - y0)
    sx, sy = (1 if x0 < x1 else -1), (1 if y0 < y1 else -1)
    err = dx + dy
    out = []
    while True:
        out.append((x0, y0))
        if (x0, y0) == (x1, y1):
            return out
        e2 = 2 * err
        if e2 >= dy:
            err += dy
            x0 += sx
        if e2 <= dx:
            err += dx
            y0 += sy


def at(h, d, t, n=(0, 0), s=0.0):
    return (h[0] + d[0] * t + n[0] * s, h[1] + d[1] * t + n[1] * s)


def perp(d):
    """Perpendicular pointing down the screen (or right when vertical)."""
    n = (-d[1], d[0])
    if n[1] < 0 or (n[1] == 0 and n[0] < 0):
        n = (-n[0], -n[1])
    return n


def draw_longsword(h, d, row):
    n = perp(d)
    px = {}
    for p in line(at(h, d, 1), at(h, d, 10)):
        px[p] = STEEL_L
    for p in line(at(h, d, 1, n, 1), at(h, d, 9, n, 1)):
        px.setdefault(p, STEEL_M)
    px[tuple(map(round, at(h, d, 10.6)))] = STEEL_H
    for s in (-1.5, 1.5, 2.2):
        px[tuple(map(round, at(h, d, 0.6, n, s)))] = GUARD
    px[tuple(map(round, h))] = WOOD_D
    return px


def draw_dagger(h, d, row):
    px = {}
    for p in line(at(h, d, 1), at(h, d, 3.4)):
        px[p] = STEEL_L
    px[tuple(map(round, at(h, d, 4.2)))] = STEEL_H
    return px


def draw_axe(h, d, row):
    n = perp(d)
    px = {}
    for p in line(at(h, d, -1), at(h, d, 8)):
        px[p] = WOOD_L
    # head on the side away from n (up the screen), a 3x3 wedge
    for t in (5.6, 6.6, 7.6):
        for s in (1, 2, 3):
            px[tuple(map(round, at(h, d, t, n, -s)))] = STEEL_L if s < 3 else STEEL_M
    px[tuple(map(round, at(h, d, 8.4, n, -3)))] = STEEL_H
    return px


def draw_spear(h, d, row):
    n = perp(d)
    px = {}
    for p in line(at(h, d, -4), at(h, d, 10)):
        px[p] = WOOD_L
    for p in line(at(h, d, 10.5), at(h, d, 13)):
        px[p] = STEEL_L
    for s in (-1, 1):
        px[tuple(map(round, at(h, d, 11, n, s)))] = STEEL_M
    return px


def draw_bow(h, d, row, side_sign):
    """Bow limbs along axis a with the belly pushed toward b; the grip is the
    hand. Upright (a = down the screen) while standing; along the dropped
    sword when rolling or dead."""
    if row.startswith(("roll", "death")):
        a = d
        b = perp(d)
        b = (-b[0], -b[1])  # belly up, away from the floor
    else:
        a = (0, 1)
        b = (side_sign, 0)
    px = {}
    prev = None
    tips = []
    # 15 px long, 3 px deep; upright, the grip sits 2 px below the middle so
    # the bow rises above the hand instead of dragging on the floor
    lift = 2 if a == (0, 1) else 0
    c = (h[0] + b[0] * 1 - a[0] * lift, h[1] + b[1] * 1 - a[1] * lift)
    for i in range(-14, 15):
        t = i / 2
        off = 3 * (1 - (t / 7) ** 2)
        p = (c[0] + a[0] * t + b[0] * (off - 3), c[1] + a[1] * t + b[1] * (off - 3))
        if prev is not None:
            for q in line(prev, p):
                px[q] = STEEL_L if abs(t) < 5 else STEEL_M  # grey bow, as in the attack strips
        prev = p
        if i in (-14, 14):
            tips.append(p)
    for q in line(tips[0], tips[1]):
        px.setdefault(q, STRING_C)
    return px


def draw(kind, h, d, L, row, side_sign):
    if kind == "longsword":
        return draw_longsword(h, d, row)
    if kind == "dagger":
        return draw_dagger(h, d, row)
    if kind == "axe":
        return draw_axe(h, d, row)
    if kind == "spear":
        return draw_spear(h, d, row)
    if kind == "bow":
        return draw_bow(h, d, row, side_sign)
    raise ValueError(kind)


def render(px, others, h, row):
    """Weapon pixels -> 32x32 cell with a dark outline where it sits on the
    floor (not over the climber), clipped to the cell and the ground row."""
    o = others.load()
    out = Image.new("RGBA", (F, F), (0, 0, 0, 0))
    q = out.load()
    hidden = row.endswith("_up")
    grip_zone = {(round(h[0]) + dx, round(h[1]) + dy) for dx in (-1, 0, 1) for dy in (-1, 0, 1)}
    keep = {}
    for (x, y), c in px.items():
        if not (0 <= x < F and 0 <= y <= bc.BASE):
            continue
        if hidden and o[x, y][3] and (x, y) not in grip_zone:
            continue
        keep[(x, y)] = c
    for (x, y), c in keep.items():
        q[x, y] = c + (255,)
    for (x, y) in list(keep):
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = x + dx, y + dy
            if 0 <= nx < F and 0 <= ny <= bc.BASE and (nx, ny) not in keep and not o[nx, ny][3]:
                q[nx, ny] = OUTLINE
    return drop_orphans(out)


# ------------------------------------------------------ attack overrides ----

def split_body(img, n):
    """n frame boxes: column runs of non-steel (body) pixels merged to n,
    frame borders halfway between neighbouring runs, so arcs and long blades
    that reach toward a neighbour stay with their own pose."""
    w, h = img.size
    px = img.load()
    cols = [sum(1 for y in range(h) if px[x, y][3] and not is_steel(px[x, y]) and not bc.is_arc(px[x, y]))
            for x in range(w)]
    rs = [r for r in runs(cols) if sum(cols[r[0]:r[1]]) >= 200]
    while len(rs) > n:
        gaps = [rs[i + 1][0] - rs[i][1] for i in range(len(rs) - 1)]
        i = gaps.index(min(gaps))
        rs[i] = [rs[i][0], rs[i + 1][1]]
        del rs[i + 1]
    assert len(rs) == n, "found %d poses, want %d" % (len(rs), n)
    cuts = [0] + [(rs[i][1] + rs[i + 1][0]) // 2 for i in range(n - 1)] + [w]
    a = img.getchannel("A")
    boxes = []
    for i in range(n):
        bb = a.crop((cuts[i], 0, cuts[i + 1], h)).getbbox()
        boxes.append((cuts[i] + bb[0], bb[1], cuts[i] + bb[2], bb[3]))
    return boxes


def coloured(c):
    """A body pixel with colour: not steel, not the slash arc, not outline."""
    return bc.solid(c) and not bc.is_arc(c) and not bc.is_outline(c)


def sole(img, box):
    """Boot sole: lowest coloured row (at least 8 source pixels), extended
    down through the outline under the boots. A spear head, axe sparks or a
    slash arc below the feet are steel, cream or outline, so they are not
    taken for feet."""
    x0, y0, x1, y1 = box
    px = img.load()
    for y in range(y1 - 1, y0 - 1, -1):
        xs = [x for x in range(x0, x1) if coloured(px[x, y])]
        if len(xs) >= 8:
            lo, hi = min(xs), max(xs) + 1
            for _ in range(6):  # the outline is about 4 source rows thick
                if y + 1 >= y1 or sum(1 for x in range(lo, hi) if bc.solid(px[x, y + 1])) < 3:
                    break
                y += 1
            return y + 1
    return y1


def feet_cx(img, box):
    """Centre of the solid pixels in the 12 rows above the sole, ignoring
    thin runs (a weapon shaft next to the legs)."""
    x0, y0, x1, y1 = box
    px = img.load()
    s = sole(img, box)
    cols = [x for x in range(x0, x1) if sum(1 for y in range(s - 12, s) if bc.solid(px[x, y])) >= 4]
    if not cols:
        return bc.feet_cx(img, box)
    return (min(cols) + max(cols) + 1) / 2


def override_frames(root, fn, shift, erase):
    img = key(Image.open(os.path.join(root, "art-src/gen/r2", fn)))
    for box in erase:
        img.paste((0, 0, 0, 0), box)
    boxes = split_body(img, 6)
    hgt = statistics.median(sole(img, boxes[i]) - bc.hood_top(img, boxes[i]) for i in (0, 5))
    s = bc.FIG_H / hgt
    # the prompt asks for one ground line: the median sole is that line, and
    # it holds even where a slash arc hides the boots of one pose
    ground = statistics.median(sole(img, b) for b in boxes)
    out, lost = [], []
    for i, b in enumerate(boxes):
        small = shrink(img.crop(b), s, bc.is_arc)
        ax = feet_cx(img, b) - b[0]
        dx = shift[i] if isinstance(shift, tuple) else shift
        c = bc.place(small, ax * s - dx, (ground - b[1]) * s)
        # nothing below the ground row (a blade tip or a boot heel)
        c.paste((0, 0, 0, 0), (0, bc.BASE + 1, F, F))
        lost.append(sum(1 for p in small.get_flattened_data() if p[3]) - sum(1 for p in c.get_flattened_data() if p[3]))
        out.append(outline(c, is_steel))
    return out, lost


def base_palettes(root):
    """Colours of the shipped layers grouped by build_climber colour class."""
    pals = {}
    for k in ("body", "hair", "outfit", "weapon"):
        for p in load(os.path.join(root, "game/assets/characters/climber", k + ".png")).get_flattened_data():
            if p[3]:
                pals.setdefault(bc.colour_class(p), set()).add(p[:3])
    return {k: sorted(v) for k, v in pals.items()}


def to_palette(c, pals, cache):
    q = c.copy()
    px = q.load()
    for y in range(F):
        for x in range(F):
            p = px[x, y]
            if p[3]:
                if p[:3] not in cache:
                    k = bc.colour_class(p)
                    cache[p[:3]] = nearest(pals.get(k) or pals["warm"], p[:3])
                px[x, y] = cache[p[:3]] + (255,)
    return drop_orphans(q)


def build_override(root, kind, pals):
    """-> {layer: 8x3 sheet} for body, hair, outfit, weapon."""
    size = (F * COLS, F * 3)
    layers = {k: Image.new("RGBA", size, (0, 0, 0, 0)) for k in ("body", "hair", "outfit", "weapon")}
    cache = {}
    for r, d in enumerate(DIRS):
        fn, shift, erase = OVERRIDES[kind][d]
        cells, lost = override_frames(root, fn, shift, erase)
        if any(lost):
            print("%s %s: px clipped per frame %s" % (kind, d, lost))
        row = "attack_" + d
        for i, c in enumerate(cells):
            labels = bc.classify(c, row)
            q = to_palette(c, pals, cache)
            src = q.load()
            lab = {p: k for p, k in labels.items() if src[p][3]}
            for (x, y), layer in bc.no_orphans(lab).items():
                layers[layer].putpixel((i * F + x, r * F + y), src[x, y])
    return layers


# ---------------------------------------------------------------- main ----

def side_sign(row, hx, others):
    if row.endswith("side"):
        return 1
    bb = others.getbbox()
    cx = (bb[0] + bb[2]) / 2 if bb else 16
    return 1 if hx >= cx else -1


def build_type(root, kind, base, pals):
    sheet = Image.new("RGBA", (F * COLS, F * len(ROWS)), (0, 0, 0, 0))
    override = build_override(root, kind, pals) if kind in OVERRIDES else None
    for r, row in enumerate(ROWS):
        n = bc.COUNTS[row.split("_")[0]]
        for i in range(n):
            if row in ATTACK_ROWS:
                if override is None:
                    c = cell(base["weapon"], r, i)
                else:
                    c = cell(override["weapon"], ATTACK_ROWS.index(row), i)
                sheet.alpha_composite(c, (i * F, r * F))
                continue
            others = Image.new("RGBA", (F, F), (0, 0, 0, 0))
            for k in ("body", "hair", "outfit"):
                others.alpha_composite(cell(base[k], r, i))
            g = grip(cell(base["weapon"], r, i), others)
            if g is None:
                continue
            h, d, L = g
            px = draw(kind, h, d, L, row, side_sign(row, h[0], others))
            sheet.alpha_composite(render(px, others, h, row), (i * F, r * F))
    return sheet, override


def main():
    args = [a for a in sys.argv[1:] if a != "--force"]
    force = "--force" in sys.argv
    root = args[0]
    kinds = args[1:] or TYPES
    climber = os.path.join(root, "game/assets/characters/climber")
    os.makedirs(os.path.join(climber, "weapons"), exist_ok=True)
    os.makedirs(os.path.join(climber, "attacks"), exist_ok=True)
    base = {k: load(os.path.join(climber, k + ".png")) for k in ("body", "hair", "outfit", "weapon")}
    pals = base_palettes(root)
    for kind in kinds:
        if kind == "sword":
            save_guarded(base["weapon"], os.path.join(climber, "weapons", "sword.png"), force)
            continue
        sheet, override = build_type(root, kind, base, pals)
        save_guarded(sheet, os.path.join(climber, "weapons", kind + ".png"), force)
        if override:
            for k in ("body", "hair", "outfit"):
                save_guarded(override[k], os.path.join(climber, "attacks", "%s_%s.png" % (kind, k)), force)


if __name__ == "__main__":
    main()
