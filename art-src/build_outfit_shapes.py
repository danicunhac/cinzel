"""Build the visual outfits with their own silhouette (every outfit but the
starter, which build_outfits.py copies).

python3 -I art-src/build_outfit_shapes.py <repo_root> [--force] [id ...]

Run after split_layers.py (it reads the split starter layers) and before
build_items.py (the outfit icons are busts of these sheets).

Inputs: game/assets/characters/climber/{body,hair,outfit}.png, the attack
overrides climber/attacks/<type>_{body,hair,outfit}.png and the weapon
sheets (to keep the blade and slash pixels of the outfit layer).
Outputs, per outfit id in OUTFITS:
  climber/outfits/<id>/hair.png, outfit.png        8x13 grid of 32x32
  climber/outfits/<id>/attacks/<type>_hair.png, <type>_outfit.png  8x3

Each cell starts as the starter cell recoloured by brightness rank
(build_outfits.repaint), then gets shape edits drawn from the masks of that
same cell, so everything lines up with body.png, the weapons, the armor and
the backpacks frame by frame. Shapes (keys of an outfit's "shape"):
  - skirt: cloth over the legs from the belt down to `hem` rows above the
    sole. Full width: each row spans the trousers of that row plus a flare
    toward the hem (side view: the back edge flares more the wider the
    stride; a leg stepping past the front of the jacket stays out). Panel:
    a straight band down the middle (tabard, apron), `panel` px each side
    of the centre. Front: open (an opening widening toward the hem, the
    legs show between the two sides), seam (a dark line) or closed; back:
    a vent. The hem rows lag behind the legs (they shift by the leg
    movement since the previous frame). With `tails`, roll frames trail
    tails behind the ball and the lying death frames spread a flap on the
    floor;
  - apron: a panel skirt seen from the front and the side only;
  - pauldrons: shoulder plates 1 px past each visible shoulder;
  - sleeves: wide bell cuffs over the wrists;
  - collar: the front collar rises 1 px over the chin;
  - cape: a short cape over one shoulder down to the hips, behind the arm,
    swaying with the walk, with one thin line of `edge` colour at its hem;
  - hair "spiky": the hood repainted as short dark hair, spikes on the
    crown and a jagged fringe over the forehead.
Light comes from the top left: the left edge of new cloth gets the light rim
of its ramp, so near-black cloth still reads on dark floors. New cloth gets
the 1 px dark outline; nothing goes below the ground row.
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
GROUND = 30

# Recolour ramps (dark -> light), the keys build_outfits.repaint reads: hood
# and hair (hair.png), scarf, leather (jacket, gloves), trim (khaki above
# the legs), legs (trousers), apron (optional: the front of the torso).
# "shape" holds the silhouette edits (see the module doc); a skirt's `ramp`
# names one of the ramps, hem_ramp/edge_ramp a (ramp, index) for the line
# on its hem and on the edges of the front opening.
OUTFITS = {
    # long dark coat to the feet, closed with a seam, high grey collar
    "casaco_longo": {
        "hood": [(36, 35, 50), (52, 51, 70), (70, 69, 94), (94, 93, 122)],
        "hair": [(30, 28, 38), (44, 42, 56), (60, 58, 76)],
        "scarf": [(48, 48, 64), (82, 84, 106), (130, 134, 156)],
        "leather": [(32, 31, 44), (44, 43, 60), (58, 57, 80), (78, 77, 104), (104, 103, 134)],
        "trim": [(96, 98, 118), (146, 148, 166), (196, 198, 210)],
        "legs": [(40, 40, 50), (56, 56, 70), (74, 74, 92)],
        "shape": {
            "skirt": {"ramp": "leather", "hem": 1, "flare": 0.8, "front": "seam", "vent": True,
                      "hem_ramp": ("leather", 1)},
        },
    },
    # light knight: mail coif, white-silver plate, crimson tabard to the
    # knees, shoulder plates
    "cavaleiro_leve": {
        "hood": [(62, 66, 80), (98, 104, 120), (138, 144, 160), (178, 184, 198)],
        "hair": None,
        "scarf": [(70, 24, 32), (102, 36, 44), (134, 54, 60)],
        "leather": [(92, 94, 110), (134, 138, 154), (178, 182, 194), (214, 216, 224), (240, 240, 244)],
        "trim": [(96, 34, 42), (132, 52, 58), (162, 74, 76)],
        "legs": [(52, 22, 30), (78, 32, 40), (104, 44, 50)],
        "tabard": [(70, 24, 32), (102, 36, 44), (134, 54, 60), (166, 80, 82)],
        "shape": {
            "skirt": {"ramp": "tabard", "hem": 3, "panel": 3, "front": "closed", "hem_ramp": ("trim", 2)},
            "pauldrons": "leather",
        },
    },
    # smith: red bandana, linen tunic to mid-thigh, leather apron to the
    # knees in front, dark trousers
    "tunica_ferreiro": {
        "hood": [(72, 28, 26), (102, 42, 34), (132, 60, 44), (156, 82, 60)],
        "hair": None,
        "scarf": [(50, 33, 22), (74, 49, 30), (98, 67, 40)],
        "leather": [(108, 94, 78), (146, 131, 106), (182, 167, 136), (210, 197, 164), (230, 218, 188)],
        "trim": [(58, 39, 24), (88, 59, 34), (118, 82, 48)],
        "legs": [(44, 33, 28), (64, 49, 40), (86, 67, 54)],
        "apron": [(56, 37, 24), (82, 55, 32), (108, 75, 44), (134, 96, 58)],
        "shape": {
            "skirt": {"ramp": "leather", "hem": 5, "flare": 0.6, "front": "closed"},
            "apron": {"ramp": "apron", "hem": 2, "panel": 2},
        },
    },
    # mage: deep violet hood, robe to the floor with wide sleeves, pale teal
    # trim on the hem
    "manto_mago": {
        "hood": [(30, 22, 52), (45, 33, 77), (62, 47, 102), (82, 65, 128)],
        "hair": None,
        "scarf": [(56, 92, 100), (92, 136, 142), (146, 186, 186)],
        "leather": [(31, 23, 53), (46, 35, 78), (64, 49, 104), (86, 69, 132), (110, 93, 158)],
        "trim": [(56, 92, 100), (92, 136, 142), (146, 186, 186)],
        "legs": [(31, 23, 53), (46, 35, 78), (64, 49, 104)],
        "shape": {
            "skirt": {"ramp": "leather", "hem": 0, "flare": 1.7, "front": "seam", "hem_ramp": ("trim", 1)},
            "sleeves": "leather",
        },
    },
    # long black leather greatcoat below the knees with a split tail, dark
    # grey shirt, thin silver edge, black gloves, black hood
    "sobretudo_noite": {
        "hood": [(30, 32, 44), (44, 48, 64), (62, 68, 90), (92, 100, 128)],
        "hair": [(26, 26, 34), (38, 38, 50), (54, 54, 70)],
        "scarf": [(50, 52, 58), (68, 70, 78), (90, 92, 100)],
        "leather": [(28, 30, 40), (40, 43, 56), (54, 58, 74), (74, 80, 100), (116, 124, 150)],
        "trim": [(108, 114, 130), (156, 162, 176), (206, 210, 220)],
        "legs": [(34, 34, 42), (46, 46, 56), (62, 62, 74)],
        "shape": {
            "skirt": {"ramp": "leather", "hem": 2, "flare": 1.2, "front": "open", "vent": True,
                      "hem_ramp": ("trim", 0), "edge_ramp": ("trim", 1), "tails": True},
        },
    },
    # fitted black jacket with a high collar, short cape on one shoulder,
    # charcoal trousers, short dark hair, one thin deep red line (the
    # cape's hem)
    "traje_sombra": {
        "hood": [(22, 22, 32), (34, 36, 50), (50, 54, 74), (76, 82, 108)],
        "hair": [(22, 22, 32), (34, 36, 50), (50, 54, 74)],
        "scarf": [(40, 40, 48), (56, 56, 66), (78, 78, 90)],
        "leather": [(26, 26, 32), (36, 36, 44), (50, 50, 60), (68, 68, 80), (104, 104, 120)],
        "trim": [(46, 46, 54), (66, 66, 76), (96, 96, 108)],
        "legs": [(50, 50, 58), (66, 66, 76), (86, 86, 98)],
        "cape": [(28, 28, 36), (40, 40, 50), (56, 56, 68), (96, 96, 112)],
        "shape": {
            "hair": "spiky",
            "collar": True,
            "cape": {"ramp": "cape", "edge": (128, 26, 38)},
        },
    },
}


def rgba(c):
    return tuple(c[:3]) + (255,)


def facing(row):
    if row == "death":
        return "death"
    return row.rsplit("_", 1)[1]


def composite(*layers):
    comp = Image.new("RGBA", (F, F), (0, 0, 0, 0))
    for im in layers:
        if im is not None:
            comp.alpha_composite(im)
    return comp


def is_line(p):
    return p[3] and p[:3] == OUTLINE[:3]


def leg_pixels(src_o, body, waist, keep):
    """Trouser and boot pixels from the belt down."""
    o = src_o.load()
    b = body.load()
    out = set()
    for y in range(waist, F):
        for x in range(F):
            p = o[x, y]
            if p[3] and (x, y) not in keep and bo.group(p, "outfit") == "khaki":
                out.add((x, y))
            q = b[x, y]
            if q[3] and not bc.is_skin(q) and not bc.is_outline(q):
                out.add((x, y))
    return out


def leg_centre(legs, lo):
    xs = [x for x, y in legs if y >= lo]
    return sum(xs) / len(xs) if xs else None


def torso_span(src_o, keep, y):
    """x range of the jacket on row y, or None."""
    so = src_o.load()
    xs = [x for x in range(F) if so[x, y][3] and (x, y) not in keep and bo.group(so[x, y], "outfit") == "leather"]
    return (min(xs), max(xs)) if xs else None


def outline_around(o, solid, pixels, max_y=GROUND):
    """Outline (4-neighbours) around `pixels` where nothing is drawn."""
    for x, y in list(pixels):
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = x + dx, y + dy
            if 0 <= nx < F and 0 <= ny <= max_y and not solid[nx, ny][3] and not o[nx, ny][3]:
                o[nx, ny] = OUTLINE


def rim(o, solid, pixels, ramp):
    """Shade new cloth: light rim on the left edge, shadow on the right."""
    for x, y in pixels:
        left = x == 0 or is_line(o[x - 1, y]) or not (o[x - 1, y][3] or solid[x - 1, y][3])
        right = x == F - 1 or is_line(o[x + 1, y]) or not (o[x + 1, y][3] or solid[x + 1, y][3])
        if left:
            o[x, y] = rgba(ramp[-1])
        elif right:
            o[x, y] = rgba(ramp[1])


class Cell:
    """Masks of one 32x32 cell of the starter layers."""

    def __init__(self, row, fi, body, hair, src_o, weapon):
        self.row, self.fi = row, fi
        self.body, self.hair, self.src_o = body, hair, src_o
        self.face = facing(row)
        self.standing = not row.startswith(("roll", "death"))
        self.keep = bo.blade_khaki(src_o, weapon) if row.startswith("attack") else set()
        lb = bo.legs_box(body, Image.new("RGBA", (F, F)), src_o)
        self.waist, self.sole = lb if lb else (None, None)
        self.legs = leg_pixels(src_o, body, self.waist, self.keep) if lb else set()

    def upright(self):
        """Standing, or still falling (first death frames)."""
        return self.standing or (self.row == "death" and self.fi < 2)


# ---------------------------------------------------------------- skirt ----

def skirt(cell, o, solid, spec, sk, lag):
    """Cloth over the legs of an upright cell (o is edited). Returns the
    pixels drawn."""
    if cell.waist is None or not cell.legs:
        return set()
    waist, sole = cell.waist, cell.sole
    hem = min(sole - sk["hem"], GROUND - 1)
    if hem - waist < 2:
        return set()
    face = cell.face
    legs, keep = cell.legs, cell.keep
    ramp = spec[sk["ramp"]]
    b = cell.body.load()
    so = cell.src_o.load()
    feet = [x for x, y in legs if y >= sole - 1]
    stride = (max(feet) - min(feet)) if feet else 6
    hips = None
    for y in range(waist - 1, waist - 4, -1):
        hips = torso_span(cell.src_o, keep, y)
        if hips:
            break
    panel = sk.get("panel")
    flare = sk.get("flare", 0.0)
    spans = {}
    prev = None
    for y in range(waist, hem + 1):
        xs = [x for x, yy in legs if yy == y]
        if xs:
            prev = (min(xs) - 1, max(xs) + 1)
        if prev is None:
            continue
        t = (y - waist) / max(1, hem - waist)
        x0, x1 = prev
        if panel:
            if face == "side":
                # from the side: a band in front (apron) or the hips' width
                # (tabard)
                c0 = hips[0] if hips else x0
                c1 = hips[1] if hips else x1
                x0, x1 = (c1 - 1, c1 + 1) if sk.get("front_only") else (c0, c1)
            else:
                mid = ((hips[0] + hips[1] + 1) / 2) if hips else (x0 + x1 + 1) / 2
                x0, x1 = round(mid - panel), round(mid + panel) - 1
        elif face == "side":
            if hips:
                x0 = min(x0, hips[0])
                x1 = min(x1, hips[1] + 1)
            x0 -= round(t * (flare * 0.8 + max(0, stride - 7) * 0.3))
        else:
            if hips:
                x0 = min(x0, hips[0])
                x1 = max(x1, hips[1])
            fl = round(t * flare)
            x0 -= fl
            x1 += fl
        if t > 0.55 and not panel:
            x0 += lag
            x1 += lag
        spans[y] = (max(1, x0), min(F - 2, x1))
    if not spans:
        return set()
    # middle line: the gap between the legs at the hem (front and back)
    split = None
    if face in ("down", "up") and hem in spans:
        x0, x1 = spans[hem]
        gap = [x for x in range(x0 + 2, x1 - 1) if (x, hem) not in legs]
        split = round(sum(gap) / len(gap)) if gap else round((x0 + x1) / 2)
        split = min(max(split, x0 + 2), x1 - 2)
    front = sk.get("front", "closed")
    filled = set()
    gaps = {}
    for y, (x0, x1) in spans.items():
        t = (y - waist) / max(1, hem - waist)
        sx = None if split is None else split + (lag if t > 0.55 and not panel else 0)
        if sx is not None and face == "down" and front == "open" and y > waist:
            half = round(t * 1.6)
            gaps[y] = (sx - half + (1 if half else 0), sx + half)
        for x in range(x0, x1 + 1):
            if y in gaps and gaps[y][0] <= x <= gaps[y][1]:
                continue
            q = b[x, y]
            if q[3] and bc.is_skin(q):
                continue
            p = so[x, y]
            g = p[3] and bo.group(p, "outfit")
            if (x, y) in keep or g in ("leather", "scarf"):
                # arms, gloves and blades stay in front of the cloth
                continue
            if g == "khaki" and y < waist + 1 and not panel:
                # the belt stays
                continue
            o[x, y] = rgba(ramp[2])
            filled.add((x, y))
    edges = set()
    for y, (g0, g1) in gaps.items():
        for p in ((g0 - 1, y), (g1 + 1, y)):
            if p in filled:
                edges.add(p)
    seam = (face == "down" and front == "seam") or (face == "up" and sk.get("vent"))
    if seam and split is not None:
        for x, y in filled:
            t = (y - waist) / max(1, hem - waist)
            if x == split + (lag if t > 0.55 else 0) and y >= waist + (3 if face == "up" else 2):
                o[x, y] = rgba(ramp[0])
    if sk.get("hem_ramp"):
        name, i = sk["hem_ramp"]
        for x, y in filled:
            if y == hem:
                o[x, y] = rgba(spec[name][i])
    if sk.get("edge_ramp"):
        name, i = sk["edge_ramp"]
        for p in edges:
            o[p] = rgba(spec[name][i])
    if face == "up" and sk.get("vent") and split is not None:
        sx = split + lag
        if (sx, hem) in filled:
            o[sx, hem] = OUTLINE
            filled.discard((sx, hem))
    if not panel and hem in spans:
        # rounded corners at the hem; from the side, with a long stride,
        # the back corner of the tail flicks up
        x0, x1 = spans[hem]
        drop = [x0, x1]
        if face == "side" and stride > 7:
            drop.append(x0 + 1)
        for x in drop:
            if (x, hem) in filled:
                o[x, hem] = (0, 0, 0, 0)
                filled.discard((x, hem))
    if panel:
        for x, y in filled:
            if y < hem and (x - 1, y) not in filled:
                o[x, y] = rgba(ramp[-1])
            elif y < hem and (x + 1, y) not in filled:
                o[x, y] = rgba(ramp[1])
    else:
        rim(o, solid, [p for p in filled if p[1] < hem and p not in edges], ramp)
    outline_around(o, solid, filled)
    return filled


def tails(cell, oimg, solid, ramp, hem_col):
    """Tails trailing the roll, or a flap on the floor in death. They start
    on the outline of the ball, so they hang from it."""
    comp = composite(cell.body, oimg)
    o = oimg.load()
    bb = comp.getbbox()
    if not bb:
        return
    x0, y0, x1, y1 = bb
    face, fi = cell.face, cell.fi
    a = comp.load()

    def edge_x(y, side):
        xs = [x for x in range(F) if a[x, y][3]]
        if not xs:
            return None
        return min(xs) if side < 0 else max(xs)

    pts = []
    if face == "side":
        length = [2, 5, 6, 6, 5, 3][fi]
        wave = [0, -1, 0, 1, 0, -1][fi]
        cy = y1 - 6
        ex = edge_x(cy, -1)
        if ex is None:
            return
        for i in range(0, length + 1):
            dy = round(wave * i / 2.5)
            thick = 3 if i < length // 2 else 2
            for w in range(thick):
                pts.append((ex - i + 1, cy + dy + w - 1))
    elif face in ("down", "up"):
        length = [1, 3, 3, 3, 3, 2][fi]
        wave = [0, 1, 0, -1, 0, 1][fi]
        cy = y1 - 6 if face == "up" else y0 + 7
        for s in (-1, 1):
            ex = edge_x(cy, s)
            if ex is None:
                continue
            for i in range(0, length + 1):
                dy = round(wave * s * i / 2) + (i // 2 if face == "up" else -(i // 2))
                for w in range(2):
                    pts.append((ex + s * (i - 1), cy + dy + w))
    else:
        if fi < 3:
            return
        length = 2 + (fi - 3)
        for yy in (y1 - 3, y1 - 2):
            ex = edge_x(yy, 1)
            if ex is None:
                continue
            for i in range(0, length + 1):
                pts.append((ex + i - 1, yy))
    new = set()
    for x, y in pts:
        if not (0 <= x < F and 0 <= y <= GROUND - 1) or solid[x, y][3]:
            continue
        p = o[x, y]
        if p[3] and not bc.is_outline(p):
            continue
        o[x, y] = rgba(ramp[2])
        new.add((x, y))
    if not new:
        return
    for x, y in new:
        if (x, y + 1) not in new and not (y + 1 <= GROUND and (o[x, y + 1][3] or solid[x, y + 1][3])):
            o[x, y] = rgba(hem_col)
    rim(o, solid, [p for p in new if o[p][:3] != tuple(hem_col)], ramp)
    outline_around(o, solid, new, GROUND)


# ------------------------------------------------------------ pauldrons ----

def torso_pixels(cell):
    so = cell.src_o.load()
    return [(x, y) for y in range(F) for x in range(F)
            if so[x, y][3] and (x, y) not in cell.keep and bo.group(so[x, y], "outfit") in ("leather", "scarf")]


def pauldrons(cell, o, solid, ramp):
    """Shoulder plates: the top torso rows reach 1 px past each visible
    shoulder (only the front one from the side), outlined."""
    if not cell.standing:
        return
    torso = torso_pixels(cell)
    if not torso:
        return
    y0 = min(y for x, y in torso)
    sides = [1] if cell.face == "side" else [-1, 1]
    new = set()
    for dy, shade in ((1, 4), (2, 3), (3, 2)):
        y = y0 + dy
        xs = [x for x, yy in torso if yy == y]
        if not xs:
            continue
        for s in sides:
            ex = (max(xs) if s > 0 else min(xs)) + s
            if 0 <= ex < F and not solid[ex, y][3]:
                o[ex, y] = rgba(ramp[shade])
                new.add((ex, y))
    outline_around(o, solid, new)


# -------------------------------------------------------------- sleeves ----

def sleeves(cell, o, solid, ramp):
    """Bell cuffs: the arm pixels just above each hand widen by 1 px outward
    and hang 1 px past the wrist."""
    if not cell.standing or cell.waist is None:
        return
    b = cell.body.load()
    so = cell.src_o.load()
    hands = [(x, y) for y in range(max(0, cell.waist - 7), min(F, cell.waist + 4)) for x in range(F)
             if b[x, y][3] and bc.is_skin(b[x, y])]
    if not hands:
        return
    mid = sum(x for x, y in cell.legs) / len(cell.legs) if cell.legs else 16
    groups = {}
    for x, y in hands:
        groups.setdefault(x < mid, []).append((x, y))
    new = set()
    for left, pts in groups.items():
        hx = round(sum(p[0] for p in pts) / len(pts))
        hy = min(p[1] for p in pts)
        s = -1 if left else 1
        arm = [(x, y) for y in range(hy - 3, hy + 1) for x in range(hx - 3, hx + 4)
               if 0 <= y < F and 0 <= x < F and so[x, y][3] and (x, y) not in cell.keep
               and bo.group(so[x, y], "outfit") == "leather"]
        for x, y in arm:
            for nx, ny in ((x + s, y), (x + s, y + 1)):
                if 0 <= nx < F and ny <= GROUND - 1 and not solid[nx, ny][3] and not o[nx, ny][3]:
                    o[nx, ny] = rgba(ramp[2] if ny > y else ramp[3])
                    new.add((nx, ny))
    outline_around(o, solid, new)


# ----------------------------------------------------------- spiky hair ----

def spiky_hair(cell, h, ramp):
    """The hood read as short dark hair: spikes on the crown (and the back
    of the head from the side), a jagged fringe over the forehead."""
    hp = h.load()
    b = cell.body.load()
    pix = [(x, y) for y in range(F) for x in range(F) if hp[x, y][3]]
    if not pix:
        return
    xs = [p[0] for p in pix]
    ys = [p[1] for p in pix]
    hx0, hx1, hy0 = min(xs), max(xs), min(ys)
    face = cell.face
    if face in ("down", "up"):
        # tufts sticking out of both sides of the crown
        for y in (hy0 + 1, hy0 + 3):
            row = [x for x in range(F) if hp[x, y][3]]
            for x, s in ((row[0], -1), (row[-1], 1)) if row else ():
                if 0 <= x + s < F and not hp[x + s, y][3]:
                    hp[x + s, y] = OUTLINE
                    hp[x, y] = rgba(ramp[1])
    if face == "side":
        for y in range(hy0 + 2, hy0 + 8, 2):
            row = [x for x in range(F) if hp[x, y][3]]
            if row and row[0] >= 1:
                hp[row[0] - 1, y] = OUTLINE
                hp[row[0], y] = rgba(ramp[1])
    if face in ("down", "side"):
        skin = [(x, y) for y in range(hy0, min(F, hy0 + 14)) for x in range(hx0, hx1 + 1)
                if b[x, y][3] and bc.is_skin(b[x, y]) and not hp[x, y][3]]
        if skin:
            top = min(y for x, y in skin)
            for x, y in skin:
                if y == top and x % 2 == 0:
                    hp[x, y] = rgba(ramp[1])
    for y in range(hy0 + 2, hy0 + 4):
        row = [x for x in range(F) if hp[x, y][3] and not is_line(hp[x, y])]
        if len(row) > 4:
            hp[row[1], y] = rgba(ramp[3])


# ------------------------------------------------------- collar, cape ----

def high_collar(cell, o, spec):
    """Front views: the collar (scarf pixels) rises 1 px over the chin."""
    if cell.face != "down":
        return
    op = o.load()
    b = cell.body.load()
    scarf = [tuple(c) for c in spec["scarf"]]
    cols = {}
    for y in range(F):
        for x in range(F):
            p = op[x, y]
            if p[3] and p[:3] in scarf:
                cols.setdefault(x, y)
    for x, y in cols.items():
        if y >= 2 and not op[x, y - 1][3]:
            op[x, y - 1] = rgba(spec["scarf"][2])
            if not op[x, y - 2][3] and b[x, y - 2][3] and bc.is_skin(b[x, y - 2]):
                op[x, y - 2] = OUTLINE


def cape(cell, h, o, spec, cp, sway):
    """Short cape over one shoulder (the screen-left one from the front,
    screen-right from behind, the back from the side) down to the hips,
    behind the arm. One thin line of the edge colour along its hem."""
    if not cell.standing:
        return
    ramp = spec[cp["ramp"]]
    edge = rgba(cp["edge"])
    so = cell.src_o.load()
    op = o.load()
    keep = cell.keep
    torso = torso_pixels(cell)
    if not torso:
        return
    face = cell.face
    ty0 = min(y for x, y in torso)
    waist = cell.waist if cell.waist is not None else max(y for x, y in torso)
    bottom = min(waist + (2 if cell.face == "side" else 0), GROUND - 2)
    solid = composite(cell.body, h).load()
    new = {}
    for y in range(ty0 + 1, bottom + 1):
        xs = [x for x, yy in torso if yy == y]
        if not xs:
            continue
        t = (y - ty0) / max(1, bottom - ty0)
        sw = round(sway * t)
        if face == "down":
            x_out = min(xs) - 1 - round(t * 1.5) + sw
            for x in range(x_out, min(xs)):
                new[(x, y)] = 2
        elif face == "up":
            mid = (min(xs) + max(xs)) // 2
            x_out = max(xs) + 1 + round(t * 1.5) + sw
            for x in range(mid + 1, x_out + 1):
                new[(x, y)] = 2 if x < x_out else 1
        else:
            back = min(xs)
            x_out = back - 1 - round(t * (1 + sway))
            for x in range(x_out, back + 2):
                new[(x, y)] = 2 if x > x_out else 1
    if face == "down":
        xs = [x for x, yy in torso if yy == ty0 + 1]
        if xs:
            for x in range(min(xs), min(xs) + 3):
                new[(x, ty0)] = 3
                new[(x, ty0 + 1)] = 2
    painted = set()
    for (x, y), i in new.items():
        if not (0 <= x < F and 0 <= y <= GROUND - 1) or solid[x, y][3] or (x, y) in keep:
            continue
        p = so[x, y]
        g = p[3] and bo.group(p, "outfit")
        if g == "leather" and face == "down" and y > ty0 + 1:
            # from the front the arm stays over the cape
            continue
        if g == "khaki" and y >= waist:
            continue
        op[x, y] = rgba(ramp[i])
        painted.add((x, y))
    if not painted:
        return
    low = max(y for x, y in painted)
    rim(op, solid, [p for p in painted if p[1] < low], ramp)
    for x, y in painted:
        if y == low:
            op[x, y] = edge
    outline_around(op, composite(cell.body, h, o).load(), painted)


# ------------------------------------------------------------- sheets ----

def lags(cells):
    """Hem lag per frame of a row: the leg movement since the frame before."""
    centres = [leg_centre(c.legs, c.sole - 3) if c.waist is not None else None for c in cells]
    n = len(centres)
    out = []
    for i, cell in enumerate(cells):
        lag = 0
        if cell.standing and n > 1 and centres[i] is not None:
            j = (i - 1) % n if cell.row.startswith(("walk", "idle")) else max(0, i - 1)
            if centres[j] is not None:
                lag = max(-1, min(1, round(centres[j] - centres[i])))
        out.append(lag)
    return out


def build_cell(cell, weapon, spec, ramps, lag):
    shape = spec["shape"]
    rec = dict(spec, skirt=None, legs_cover=0.0)
    hh, oo = bo.repaint(cell.row, cell.body, cell.hair, cell.src_o, weapon, rec, ramps)
    if shape.get("hair") == "spiky":
        spiky_hair(cell, hh, spec["hood"])
    sk = shape.get("skirt")
    if sk:
        solid = composite(cell.body, hh).load()
        if cell.upright():
            skirt(cell, oo.load(), solid, spec, sk, lag)
        elif sk.get("tails"):
            hem = spec[sk["hem_ramp"][0]][sk["hem_ramp"][1]] if sk.get("hem_ramp") else spec[sk["ramp"]][1]
            tails(cell, oo, solid, spec[sk["ramp"]], hem)
    ap = shape.get("apron")
    if ap and cell.face in ("down", "side") and cell.upright():
        skirt(cell, oo.load(), composite(cell.body, hh).load(), spec, dict(ap, front="closed", front_only=True), 0)
    if shape.get("pauldrons"):
        pauldrons(cell, oo.load(), composite(cell.body, hh).load(), spec[shape["pauldrons"]])
    if shape.get("sleeves"):
        sleeves(cell, oo.load(), composite(cell.body, hh).load(), spec[shape["sleeves"]])
    if shape.get("collar"):
        high_collar(cell, oo, spec)
    cp = shape.get("cape")
    if cp:
        sway = 0
        if cell.row.startswith("walk"):
            sway = [0, 1, 1, 0, 0, 1, 1, 0][cell.fi] if cell.face == "side" else [0, 1, 0, -1, 0, 1, 0, -1][cell.fi]
        elif cell.row.startswith("attack"):
            sway = 1 if cell.fi in (2, 3) else 0
        cape(cell, hh, oo, spec, cp, sway)
    return hh, oo


def build_sheet(names, body, hair, outfit, weapon, spec, ramps):
    out_h = Image.new("RGBA", hair.size, (0, 0, 0, 0))
    out_o = Image.new("RGBA", outfit.size, (0, 0, 0, 0))
    for r in range(hair.height // F):
        row = names[r]
        cells = []
        for c in range(COLS):
            box = (c * F, r * F, c * F + F, r * F + F)
            if hair.crop(box).getbbox() or outfit.crop(box).getbbox():
                cells.append((box, Cell(row, c, body.crop(box), hair.crop(box), outfit.crop(box), weapon.crop(box))))
        lag = lags([c for _, c in cells])
        for i, (box, cell) in enumerate(cells):
            hh, oo = build_cell(cell, weapon.crop(box), spec, ramps, lag[i])
            out_h.alpha_composite(hh, box[:2])
            out_o.alpha_composite(oo, box[:2])
    return bo.no_orphans(out_h), bo.no_orphans(out_o)


def load(path):
    return Image.open(path).convert("RGBA")


def main():
    args = [a for a in sys.argv[1:] if a != "--force"]
    root, only = args[0], args[1:]
    force = "--force" in sys.argv
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
    for oid, spec in OUTFITS.items():
        if only and oid not in only:
            continue
        odir = os.path.join(climber, "outfits", oid)
        os.makedirs(os.path.join(odir, "attacks"), exist_ok=True)
        h, o = build_sheet(ROWS, base["body"], base["hair"], base["outfit"], base["weapon"], spec, ramps)
        save_guarded(h, os.path.join(odir, "hair.png"), force)
        save_guarded(o, os.path.join(odir, "outfit.png"), force)
        for t in kinds:
            a = attacks[t]
            wa = load(os.path.join(climber, "weapons", t + ".png")).crop((0, 6 * F, COLS * F, 9 * F))
            h, o = build_sheet(ATTACK_ROWS, a["body"], a["hair"], a["outfit"], wa, spec, ramps)
            save_guarded(h, os.path.join(odir, "attacks", "%s_hair.png" % t), force)
            save_guarded(o, os.path.join(odir, "attacks", "%s_outfit.png" % t), force)


if __name__ == "__main__":
    main()
