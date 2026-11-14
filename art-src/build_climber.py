"""Build the layered climber sheets from the generated sheets.

python3 -I art-src/build_climber.py <repo_root> [--force]

Existing output files are kept unless --force is passed: the shipped sheets
may be Daniel's hand-drawn layers (docs/personagem-guia.md).

Inputs (magenta background, generated with AI generator, see docs/assets.md):
  art-src/keyart/climber-turnaround-1.png  idle (front, back, side)
  art-src/gen/climber-walk-sheet.png       walk, 3 rows x 4
  art-src/gen/climber-attack-sheet.png     attack, 3 rows x 3
  art-src/gen/climber-roll-death-sheet.png roll 3 rows x 4, death 1 row x 4
Outputs: game/assets/characters/climber/{body,hair,outfit,weapon}.png
(4 cols x 13 rows of 24x24) and art-src/climber-reference.png (composite).

Method: key out magenta, cut frames by gaps, scale each sheet so the hood
has the same width as in the turnaround (turnaround figure = 22 px tall),
box-downscale, threshold alpha, anchor feet on y=22 and hood centre on x=12,
quantize all frames to one shared palette, then split pixels into layers by
colour class (see classify()).
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from PIL import Image  # noqa: E402

import walk_cycle  # noqa: E402
from artlib import OUTLINE, frames, is_green, is_steel, key_magenta, parse_args, save_guarded  # noqa: E402

F = 24
BASE = 22  # feet row
TARGET_H = 22
PALETTE_SIZE = 28
STEEL_COLORS = 4
ROW_NAMES = [
    "idle_down", "idle_up", "idle_side", "walk_down", "walk_up", "walk_side",
    "attack_down", "attack_up", "attack_side", "roll_down", "roll_up", "roll_side", "death",
]


def hood_box(img, box):
    x0, y0, x1, y1 = box
    px = img.load()
    xs, ys = [], []
    for y in range(y0, y1):
        for x in range(x0, x1):
            c = px[x, y]
            if c[3] and is_green(c):
                xs.append(x)
                ys.append(y)
    return min(xs), min(ys), max(xs) + 1, max(ys) + 1


def feet_y(img, box):
    """Lowest opaque row that is not the sword."""
    x0, y0, x1, y1 = box
    px = img.load()
    for y in range(y1 - 1, y0 - 1, -1):
        n = sum(1 for x in range(x0, x1) if px[x, y][3] and not is_steel(px[x, y]))
        if n >= 3:
            return y + 1
    return y1


def shrink(img, box, s):
    x0, y0, x1, y1 = box
    crop = img.crop(box)
    w, h = max(1, round(crop.width * s)), max(1, round(crop.height * s))
    small = crop.resize((w, h), Image.BOX)
    a = small.getchannel("A").point(lambda v: 255 if v >= 110 else 0)
    small.putalpha(a)
    hx0, _, hx1, _ = hood_box(img, box)
    cx = ((hx0 + hx1) / 2 - x0) * s
    fy = (feet_y(img, box) - y0) * s
    return small, cx, fy


def fit_shrink(img, box, s):
    """shrink(), but frames wider or taller than the cell (long slash arc,
    body lying down, the walk sheet's taller figure) are scaled down just
    enough to fit instead of being clipped."""
    small, cx, fy = shrink(img, box, s)
    k = min(1.0, (F - 1) / small.width, BASE / fy)  # BASE: room for the walk bob
    if k < 1.0:
        small, cx, fy = shrink(img, box, s * k)
    return small, cx, fy


def place(small, cx, fy):
    cell = Image.new("RGBA", (F, F), (0, 0, 0, 0))
    # Hood centre on x=12, but slide the frame so nothing leaves the cell.
    ox = min(max(round(F / 2 - cx), 0), F - small.width)
    oy = round(BASE + 1 - fy)
    cell.alpha_composite(small, (max(ox, 0), max(oy, 0)), (max(-ox, 0), max(-oy, 0)))
    return outline(cell)


def outline(cell):
    """Box downscaling washes out the 1 px dark outline; repaint silhouette
    edge pixels with the outline colour."""
    out = cell.copy()
    a = cell.getchannel("A").load()
    dst = out.load()
    for y in range(F):
        for x in range(F):
            if not a[x, y] or is_steel(dst[x, y]):
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if not (0 <= nx < F and 0 <= ny < F) or not a[nx, ny]:
                    if 0 <= nx < F and 0 <= ny < F:
                        dst[x, y] = OUTLINE
                    break
    return out


def breathe(cell):
    """Idle frame 2: everything above the boots drops 1 px."""
    out = cell.copy()
    a = cell.getchannel("A").load()
    rows = [y for y in range(F) if any(a[x, y] for x in range(F))]
    top, bottom = rows[0], rows[-1]
    cut = bottom - 4
    src = cell.load()
    dst = out.load()
    for y in range(top, cut + 1):
        for x in range(F):
            dst[x, y] = src[x, y - 1] if y > top else (0, 0, 0, 0)
    return out


def load(root, rel):
    img = key_magenta(Image.open(os.path.join(root, "art-src", rel)))
    return img, frames(img)


def sheet_scale(img, box, ref_hood_w):
    hx0, _, hx1, _ = hood_box(img, box)
    return ref_hood_w / (hx1 - hx0)


def build_frames(root):
    turn, tf = load(root, "keyart/climber-turnaround-1.png")
    front = tf[0][0]
    s_turn = TARGET_H / (feet_y(turn, front) - hood_box(turn, front)[1])
    hx0, _, hx1, _ = hood_box(turn, front)
    ref_hood = (hx1 - hx0) * s_turn  # hood width in 24px space

    rows = {}
    idle = []
    for b in tf[0]:
        small, cx, fy = shrink(turn, b, s_turn)
        idle.append(place(small, cx, fy))
    for name, cell in zip(("idle_down", "idle_up", "idle_side"), idle):
        rows[name] = [cell, breathe(cell)]

    def take(rel, names, counts, ref=(0, 0)):
        img, fr = load(root, rel)
        s = sheet_scale(img, fr[ref[0]][ref[1]], ref_hood)
        for name, boxes, n in zip(names, fr, counts):
            assert len(boxes) == n, (rel, name, len(boxes))
            rows[name] = [place(*fit_shrink(img, b, s)) for b in boxes]

    take("gen/climber-attack-sheet.png", ("attack_down", "attack_up", "attack_side"), (3, 3, 3), (0, 1))
    take("gen/climber-roll-death-sheet.png", ("roll_down", "roll_up", "roll_side", "death"), (4, 4, 4, 4))
    # Walk rows are hand-built from the idle frames after quantizing
    # (walk_cycle.py); the generated walk sheet barely moved at 24 px.
    return rows


def palette_of(colors, n):
    sample = Image.new("RGB", (len(colors), 1))
    sample.putdata(colors)
    q = sample.quantize(colors=n, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
    pal = q.getpalette()[: n * 3]
    return [tuple(pal[i:i + 3]) for i in range(0, len(pal), 3)]


def nearest(palette, p):
    return min(palette, key=lambda k: sum((k[i] - p[i]) ** 2 for i in range(3)))


def quantize(rows):
    """One shared palette: STEEL_COLORS for the blade and slash arc, the rest
    for everything else, so the sword never merges with the khaki trousers."""
    cells = [c for name in ROW_NAMES for c in rows.get(name, [])]
    steel, rest = [], []
    for c in cells:
        for p in c.get_flattened_data():
            if p[3] and p[:3] != OUTLINE[:3]:
                (steel if is_steel(p) else rest).append(p[:3])
    steel_pal = palette_of(steel, STEEL_COLORS)
    rest_pal = palette_of(rest, PALETTE_SIZE - STEEL_COLORS - 1) + [OUTLINE[:3]]
    out = {}
    for name in ROW_NAMES:
        new = []
        for c in rows.get(name, []):
            q = c.copy()
            px = q.load()
            for y in range(F):
                for x in range(F):
                    p = px[x, y]
                    if p[3]:
                        px[x, y] = nearest(steel_pal if is_steel(p) else rest_pal, p) + (255,)
            new.append(q)
        out[name] = new
    return out


def lum(c):
    return 0.3 * c[0] + 0.59 * c[1] + 0.11 * c[2]


def is_skin(c):
    r, g, b = c[:3]
    return r > 170 and 100 < g < 200 and b < 150 and r - b > 70 and r - g > 25


def is_face(c):
    """Skin in the shade of the hood: warm, and green close to red."""
    r, g, b = c[:3]
    return r > 120 and g >= r * 0.62 and b < g - 20 and not is_green(c)


def is_outline(c):
    return lum(c) < 40


def classify(cell, row):
    """Pixel -> layer name. Body: skin and boots. Hair: hood and hair under
    it. Outfit: jacket, scarf, trousers, backpack. Weapon: steel blade and
    slash arc. Outline pixels join the layer most of their neighbours use."""
    px = cell.load()
    pts = [(x, y) for y in range(F) for x in range(F) if px[x, y][3]]
    if not pts:
        return {}
    top = min(y for _, y in pts)
    bottom = max(y for _, y in pts)
    h = bottom - top + 1
    standing = not row.startswith(("roll", "death"))
    head = top + h * 0.42  # rows above this are hood and face
    lab = {}
    for x, y in pts:
        c = px[x, y]
        if is_outline(c):
            continue
        if is_steel(c):
            lab[(x, y)] = "weapon"
        elif standing and y < head:
            lab[(x, y)] = "body" if is_face(c) else "hair"
    face = [y for (x, y), k in lab.items() if k == "body"]
    chin = max(face) if face and not row.endswith("up") else None
    for x, y in pts:
        c = px[x, y]
        if is_outline(c) or (x, y) in lab:
            continue
        if is_green(c):
            lab[(x, y)] = "outfit" if chin is not None and y > chin else "hair"
        elif is_skin(c):
            lab[(x, y)] = "body"
        elif standing and y >= bottom - 2:
            lab[(x, y)] = "body"  # boots
        else:
            lab[(x, y)] = "outfit"
    # Outline pixels take the majority label of their labelled neighbours,
    # repeated so runs of outline (hood seams, hair) inherit from the region
    # they sit in rather than defaulting.
    pending = [p for p in pts if p not in lab]
    while pending:
        progress = {}
        for x, y in pending:
            votes = {}
            for dx in (-1, 0, 1):
                for dy in (-1, 0, 1):
                    k = lab.get((x + dx, y + dy))
                    if k:
                        votes[k] = votes.get(k, 0) + (2 if k == "hair" else 1)
            if votes:
                progress[(x, y)] = max(votes, key=votes.get)
        if not progress:
            for p in pending:
                lab[p] = "outfit"
            break
        lab.update(progress)
        pending = [p for p in pending if p not in lab]
    return despeckle(lab)


def despeckle(lab):
    """A hair pixel with no 8-neighbour in hair is a stray speck from the
    colour split (seen on the up rows): give it to its neighbours' layer
    (never to the weapon)."""
    out = dict(lab)
    for (x, y), k in lab.items():
        if k != "hair":
            continue
        votes = {}
        for dx in (-1, 0, 1):
            for dy in (-1, 0, 1):
                if dx or dy:
                    n = lab.get((x + dx, y + dy))
                    if n:
                        votes[n] = votes.get(n, 0) + 1
        if "hair" not in votes:
            votes.pop("weapon", None)
            if votes:
                out[(x, y)] = max(votes, key=votes.get)
    return out


def add_walk(rows, labels):
    colors = {p[:3] for cells in rows.values() for c in cells for p in c.get_flattened_data() if p[3]}

    def darker(c):
        t = tuple(int(v * 0.7) for v in c[:3])
        return nearest(list(colors), t) + (255,)

    for d in ("down", "up", "side"):
        idle = walk_cycle.frame_of(rows["idle_" + d][0], labels["idle_" + d][0])
        frames_ = walk_cycle.side(idle, darker) if d == "side" else walk_cycle.front_back(idle)
        cells, labs = zip(*(walk_cycle.to_cell(f, Image) for f in frames_))
        rows["walk_" + d] = list(cells)
        labels["walk_" + d] = list(labs)


def main():
    root, force = parse_args(sys.argv)
    rows = quantize(build_frames(root))
    labels = {name: [classify(c, name) for c in cells] for name, cells in rows.items()}
    add_walk(rows, labels)
    layers = {k: Image.new("RGBA", (F * 4, F * len(ROW_NAMES)), (0, 0, 0, 0)) for k in ("body", "hair", "outfit", "weapon")}
    comp = Image.new("RGBA", (F * 4, F * len(ROW_NAMES)), (0, 0, 0, 0))
    for r, name in enumerate(ROW_NAMES):
        for i, cell in enumerate(rows[name]):
            lab = labels[name][i]
            src = cell.load()
            for (x, y), layer in lab.items():
                layers[layer].putpixel((i * F + x, r * F + y), src[x, y])
            comp.alpha_composite(cell, (i * F, r * F))
    out = os.path.join(root, "game/assets/characters/climber")
    for k, img in layers.items():
        save_guarded(img, os.path.join(out, k + ".png"), force)
    save_guarded(comp, os.path.join(root, "art-src/climber-reference.png"), force)


if __name__ == "__main__":
    main()
