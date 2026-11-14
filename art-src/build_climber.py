"""Build the layered climber sheets (32 px) from the generated strips.

python3 -I art-src/build_climber.py <repo_root> [--force]

Existing output files are kept unless --force is passed: the shipped sheets
may be Daniel's hand-drawn layers (docs/personagem-guia.md).

Inputs (magenta background, AI generator edit_image with the approved
turnaround art-src/keyart/climber-turnaround-1.png as reference, see
docs/assets.md): art-src/gen/r2/climber32-<anim>-<dir>-N.png, one strip per
animation and direction (STRIPS below): idle 4 poses, walk 8, attack 6,
roll 6, death 6
Outputs: game/assets/characters/climber/{body,hair,outfit,weapon}.png
(8 cols x 13 rows of 32x32, unused cells empty) and
art-src/climber-reference.png (the 4 layers composited).

Method per strip: key out magenta, cut the strip into its N poses, scale so
the standing figure is FIG_H px tall (hood top to boot sole), box-downscale,
threshold alpha, put the boot soles on row BASE and the anchor (hood centre
for walk, planted feet for idle and attack, bounding box centre for roll and
death) on the cell's centre column, repaint the outline, quantize every frame
to one shared palette, then split pixels into layers by colour class
(classify()).
"""
import os
import statistics
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from PIL import Image  # noqa: E402

from artlib import OUTLINE, is_green, is_steel, parse_args, save_guarded  # noqa: E402
from strips import drop_orphans, load_strip, nearest, outline, palette_of, shrink  # noqa: E402

F = 32
COLS = 8
BASE = 30  # boot soles on this row
FIG_H = 25  # standing figure, hood top to boot sole
# Colours per class in the shared palette (plus the outline): 30 in all.
PALETTE = {"steel": 5, "skin": 4, "green": 8, "warm": 12}
ROW_NAMES = [
    "idle_down", "idle_up", "idle_side", "walk_down", "walk_up", "walk_side",
    "attack_down", "attack_up", "attack_side", "roll_down", "roll_up", "roll_side", "death",
]
COUNTS = {"idle": 4, "walk": 8, "attack": 6, "roll": 6, "death": 6}

# row -> (strip file in art-src/gen/r2, poses in the strip, anchor, standing
# poses used to measure the figure height, extra scale, x shift of the anchor
# (one value, or one per pose: the side strike pulls back so the arc fits),
# poses kept for this row)
STRIPS = {
    "idle_down": ("climber32-idle-down-up-1.png", 8, "feet", range(8), 1.0, -1, range(0, 4)),
    "idle_up": ("climber32-idle-down-up-1.png", 8, "feet", range(8), 1.0, -1, range(4, 8)),
    "idle_side": ("climber32-idle-side-1.png", 4, "feet", range(4), 1.0, 0),
    "walk_down": ("climber32-walk-down-2.png", 8, "hood", range(8), 1.0, 0),
    "walk_up": ("climber32-walk-up-1.png", 8, "hood", range(8), 1.0, 0),
    "walk_side": ("climber32-walk-side-1.png", 8, "hood", range(8), 1.0, 0),
    "attack_down": ("climber32-attack-down-1.png", 6, "feet", (0, 5), 1.0, 0),
    "attack_up": ("climber32-attack-up-2.png", 6, "feet", (0, 5), 1.0, -1),
    "attack_side": ("climber32-attack-side-1.png", 6, "feet", (0, 5), 1.0, (-2, -2, -6, -5, -3, -2)),
    "roll_down": ("climber32-roll-down-1.png", 6, "box", (5,), 1.0, 0),
    "roll_up": ("climber32-roll-up-1.png", 6, "box", (5,), 1.0, 0),
    "roll_side": ("climber32-roll-side-1.png", 6, "box", (5,), 1.0, 0),
    "death": ("climber32-death-1.png", 6, "box", (0,), 1.0, 0),
}


def is_arc(c):
    r, g, b = c[:3]
    return min(r, g, b) > 170 and max(r, g, b) - min(r, g, b) < 70


def solid(c):
    return c[3] and not is_steel(c)


def hood_top(img, box):
    x0, y0, x1, y1 = box
    px = img.load()
    for y in range(y0, y1):
        if sum(1 for x in range(x0, x1) if px[x, y][3] and is_green(px[x, y])) > 3:
            return y
    return y0


def hood_cx(img, box):
    """Centre of the green pixels in the top 40 source rows of the hood."""
    x0, y0, x1, y1 = box
    px = img.load()
    t = hood_top(img, box)
    xs = [x for y in range(t, min(y1, t + 40)) for x in range(x0, x1) if px[x, y][3] and is_green(px[x, y])]
    return (min(xs) + max(xs) + 1) / 2


def sole(img, box):
    """Lowest row with at least 3 non-steel pixels, +1."""
    x0, y0, x1, y1 = box
    px = img.load()
    for y in range(y1 - 1, y0 - 1, -1):
        if sum(1 for x in range(x0, x1) if solid(px[x, y])) >= 3:
            return y + 1
    return y1


def feet_cx(img, box):
    x0, y0, x1, y1 = box
    px = img.load()
    s = sole(img, box)
    xs = [x for y in range(s - 12, s) for x in range(x0, x1) if solid(px[x, y])]
    return (min(xs) + max(xs) + 1) / 2


def place(crop_small, ax, sy):
    """Paste a downscaled pose so its anchor x lands on the centre column
    and its sole row on BASE. Pixels leaving the cell are clipped."""
    cell = Image.new("RGBA", (F, F), (0, 0, 0, 0))
    ox = round(F / 2 - ax)
    oy = round(BASE + 1 - sy)
    cell.alpha_composite(crop_small, (max(ox, 0), max(oy, 0)), (max(-ox, 0), max(-oy, 0)))
    return cell


def strip_frames(root, name):
    rel, n, anchor, standing, extra, shift, *take = STRIPS[name]
    img, boxes = load_strip(os.path.join(root, "art-src/gen/r2", rel), n)
    h = statistics.median(sole(img, boxes[i]) - hood_top(img, boxes[i]) for i in standing)
    s = FIG_H / h * extra
    out, clipped = [], []
    for i in (take[0] if take else range(n)):
        b = boxes[i]
        x0, y0 = b[0], b[1]
        small = shrink(img.crop(b), s, is_arc)
        if anchor == "hood":
            ax = hood_cx(img, b) - x0
        elif anchor == "feet":
            ax = feet_cx(img, b) - x0
        else:
            ax = (b[2] - b[0]) / 2
        dx = shift[i] if isinstance(shift, tuple) else shift
        cell = place(small, ax * s - dx, (sole(img, b) - y0) * s)
        lost = sum(1 for p in small.get_flattened_data() if p[3]) - sum(1 for p in cell.get_flattened_data() if p[3])
        clipped.append(lost)
        out.append(cell)
    return out, clipped


def build(root):
    rows = {}
    report = {}
    for name in STRIPS:
        rows[name], report[name] = strip_frames(root, name)
    for name in rows:
        rows[name] = [outline(c, is_steel) for c in rows[name]]
    return rows, report


def lum(c):
    return 0.3 * c[0] + 0.59 * c[1] + 0.11 * c[2]


def is_skin(c):
    """Peach skin, lit or in the hood's shade. Khaki trousers have the same
    hue but less blue and a higher green/red ratio."""
    r, g, b = c[:3]
    if r < 140 or is_green(c):
        return False
    gr, br = g / r, b / r
    return (0.55 < gr < 0.79 and br > 0.37) or (r > 225 and 0.6 < gr < 0.77 and br > 0.28) or (
        r > 190 and 0.6 < gr < 0.7 and br > 0.27)


def is_outline(c):
    return lum(c) < 40


def colour_class(c):
    if is_outline(c):
        return "outline"
    if is_steel(c):
        return "steel"
    if is_skin(c):
        return "skin"
    if is_green(c):
        return "green"
    return "warm"


def quantize(rows):
    """One shared palette split by colour class, so skin never merges with
    the khaki trousers and the blade never merges with anything."""
    samples = {k: [] for k in PALETTE}
    for cells in rows.values():
        for c in cells:
            for p in c.get_flattened_data():
                k = p[3] and colour_class(p)
                if k and k != "outline":
                    samples[k].append(p[:3])
    pals = {k: palette_of(v, PALETTE[k]) for k, v in samples.items()}
    pals["outline"] = [OUTLINE[:3]]
    cache = {}
    out = {}
    for name, cells in rows.items():
        new = []
        for c in cells:
            q = c.copy()
            px = q.load()
            for y in range(F):
                for x in range(F):
                    p = px[x, y]
                    if p[3]:
                        if p[:3] not in cache:
                            cache[p[:3]] = nearest(pals[colour_class(p)], p[:3])
                        px[x, y] = cache[p[:3]] + (255,)
            new.append(drop_orphans(q))
        out[name] = new
    return out


def neighbours(x, y):
    for dx in (-1, 0, 1):
        for dy in (-1, 0, 1):
            if dx or dy:
                yield x + dx, y + dy


def classify(cell, row):
    """Pixel -> layer name, from the full-colour cell. Body: skin and boots.
    Hair: hood and the hair under it. Outfit: jacket, scarf, trousers,
    backpack. Weapon: blade and slash arc. Outline pixels join the layer
    most of their neighbours use."""
    px = cell.load()
    pts = [(x, y) for y in range(F) for x in range(F) if px[x, y][3]]
    body_pts = [p for p in pts if not is_steel(px[p])]
    if not body_pts:
        return {p: "weapon" for p in pts}
    top = min(y for _, y in body_pts)
    bottom = max(y for _, y in body_pts)
    h = bottom - top + 1
    standing = not row.startswith(("roll", "death"))
    head = top + h * 0.42  # rows above this are hood, hair and face
    skin = [y for (x, y) in pts if is_skin(px[x, y]) and y < top + h * 0.55]
    chin = max(skin) if skin and standing and not row.endswith("up") else top + h * 0.4
    lab = {}
    for x, y in pts:
        k = colour_class(px[x, y])
        if k == "outline":
            continue
        if k == "steel":
            lab[(x, y)] = "weapon"
        elif k == "skin":
            lab[(x, y)] = "body"
        elif k == "green":
            lab[(x, y)] = "outfit" if standing and y > chin else "hair"
        elif standing and y < head:
            lab[(x, y)] = "hair"  # hair under the hood
        elif standing and y >= bottom - 2:
            lab[(x, y)] = "body"  # boots
        else:
            lab[(x, y)] = "outfit"
    # Outline pixels take the majority label of their labelled neighbours,
    # repeated so runs of outline inherit from the region they sit in.
    pending = [p for p in pts if p not in lab]
    while pending:
        progress = {}
        for x, y in pending:
            votes = {}
            for n in neighbours(x, y):
                k = lab.get(n)
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
    """A pixel with no 8-neighbour in its own layer is a stray speck from the
    colour split: give it to its neighbours' layer (never to the weapon,
    unless it is a weapon pixel touching nothing else)."""
    out = dict(lab)
    for _ in range(2):
        cur = dict(out)
        for (x, y), k in cur.items():
            votes = {}
            for n in neighbours(x, y):
                m = cur.get(n)
                if m:
                    votes[m] = votes.get(m, 0) + 1
            if k not in votes and votes:
                votes.pop("weapon", None)
                if votes:
                    out[(x, y)] = max(votes, key=votes.get)
    return out


def no_orphans(lab):
    """Final pass after quantizing (which drops a few pixels): a pixel with
    no 8-neighbour in its own layer joins the layer most of its neighbours
    use; a pixel with no neighbours at all is dropped."""
    out = dict(lab)
    for (x, y), k in lab.items():
        votes = {}
        for n in neighbours(x, y):
            m = out.get(n)
            if m:
                votes[m] = votes.get(m, 0) + 1
        if not votes:
            del out[(x, y)]
        elif k not in votes:
            out[(x, y)] = max(votes, key=votes.get)
    return out


def main():
    root, force = parse_args(sys.argv)
    rows, clipped = build(root)
    labels = {name: [classify(c, name) for c in cells] for name, cells in rows.items()}
    rows = quantize(rows)
    for name, n in clipped.items():
        if any(n):
            print("%s: px clipped at the cell edge per frame %s" % (name, n))
    size = (F * COLS, F * len(ROW_NAMES))
    layers = {k: Image.new("RGBA", size, (0, 0, 0, 0)) for k in ("body", "hair", "outfit", "weapon")}
    comp = Image.new("RGBA", size, (0, 0, 0, 0))
    for r, name in enumerate(ROW_NAMES):
        assert len(rows[name]) == COUNTS[name.split("_")[0]], name
        for i, cell in enumerate(rows[name]):
            src = cell.load()
            lab = {p: k for p, k in labels[name][i].items() if src[p][3]}
            for (x, y), layer in no_orphans(lab).items():
                layers[layer].putpixel((i * F + x, r * F + y), src[x, y])
    for k in ("body", "hair", "outfit", "weapon"):
        comp.alpha_composite(layers[k])
    out = os.path.join(root, "game/assets/characters/climber")
    for k, img in layers.items():
        save_guarded(img, os.path.join(out, k + ".png"), force)
    save_guarded(comp, os.path.join(root, "art-src/climber-reference.png"), force)


if __name__ == "__main__":
    main()
