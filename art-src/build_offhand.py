"""Build the off-hand sword sheets (Lâminas Gêmeas) and the sheathed weapon
sheets (town), per weapon item, from the item's own weapon sheet and colours.

python3 -I art-src/build_offhand.py <repo_root> [--force] [id ...]

Inputs: climber/weapons/<id>.png (build_weapon_items.py), the item icon
palette (build_weapon_items.palette), climber/{body,hair,outfit}.png (the
figure, to find the hands, the hip and the back in each frame).
Outputs (8x13 grids of 32x32, same rows as the climber):
  climber/offhand/<id>.png            one-handed swords only: the sword in
    the other hand. Front and back rows: the weapon cell mirrored across the
    figure's centre (walk rows take the frame half a cycle away, so the
    other arm swings opposite). Side rows: the cell 2 px back and 1 px up
    (the game draws it behind the body, the far hand). Attack rows: the
    idle frame 0 pose, moved with the figure (the main sword swings, this
    one is held).
  climber/offhand/<id>_sheathed.png   swords: in the scabbard on the other
    hip (idle, walk, roll rows).
  climber/weapons/<id>_sheathed.png   every weapon put away (idle, walk,
    roll rows): sword and dagger at the hip, hilt up, in a dark leather
    scabbard with the item's guard, grip and chape colours (outlined, so it
    reads on the coat); longsword, axe, spear and bow across the back,
    diagonal (the game draws it behind the body in front views, so only the
    hilt or head shows over the shoulder, and over the backpack in back and
    side views).
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from PIL import Image  # noqa: E402

import build_climber as bc  # noqa: E402
import build_weapon_items as bwi  # noqa: E402
import build_weapons as bw  # noqa: E402
from artlib import OUTLINE, save_guarded  # noqa: E402
from strips import drop_orphans  # noqa: E402

F = 32
COLS = 8
ROWS = bc.ROW_NAMES
SHEATHE_ROWS = [r for r in ROWS if r.split("_")[0] in ("idle", "walk", "roll")]
HIP_TYPES = ("sword", "dagger")
SCABBARD = ((52, 34, 28), (84, 54, 36))
SIDE_SHIFT = (-2, -1)


def rpt(p):
    return (round(p[0]), round(p[1]))


def figure(base, r, i):
    out = Image.new("RGBA", (F, F), (0, 0, 0, 0))
    for k in ("body", "hair", "outfit"):
        out.alpha_composite(bw.cell(base[k], r, i))
    return out


def shift(cell, dx, dy):
    out = Image.new("RGBA", (F, F), (0, 0, 0, 0))
    out.paste(cell, (dx, dy), cell)
    # nothing below the ground row
    px = out.load()
    for y in range(bc.BASE + 1, F):
        for x in range(F):
            px[x, y] = (0, 0, 0, 0)
    return out


def mirror(cell, fig):
    """Mirror across the figure's centre column."""
    bb = fig.getbbox()
    m = cell.transpose(Image.FLIP_LEFT_RIGHT)
    if not bb:
        return m
    # flip maps x -> 31 - x; the figure's centre c needs x -> 2c - x
    dx = bb[0] + bb[2] - 1 - (F - 1)
    return shift(m, dx, 0)


# ------------------------------------------------------------- off-hand ----

def offhand_sheet(sheet, base):
    out = Image.new("RGBA", sheet.size, (0, 0, 0, 0))
    idle0 = {}
    for r, row in enumerate(ROWS):
        if row in bw.ATTACK_ROWS:
            continue
        n = bc.COUNTS[row.split("_")[0]]
        for i in range(n):
            j = (i + n // 2) % n if row.startswith("walk") else i
            src = bw.cell(sheet, r, j)
            if row.endswith("side"):
                c = shift(src, *SIDE_SHIFT)
            else:
                c = mirror(src, figure(base, r, i))
            out.alpha_composite(c, (i * F, r * F))
            if row.startswith("idle") and i == 0:
                idle0[row.split("_")[1]] = (c, figure(base, r, 0).getbbox())
    for row in bw.ATTACK_ROWS:
        r = ROWS.index(row)
        held, bb0 = idle0[row.split("_")[1]]
        for i in range(bc.COUNTS["attack"]):
            bb = figure(base, r, i).getbbox()
            if not bb or not bb0:
                continue
            dx = round((bb[0] + bb[2] - bb0[0] - bb0[2]) / 2)
            dy = bb[1] - bb0[1]
            out.alpha_composite(shift(held, dx, dy), (i * F, r * F))
    return drop_orphans(out)


# ------------------------------------------------------------- sheathed ----

def render(px, fig, over=False):
    """Pixels -> cell, dark outline where it sits on the floor (and over the
    figure too when `over`, so a scabbard on the coat reads), clipped to the
    ground row."""
    o = fig.load()
    out = Image.new("RGBA", (F, F), (0, 0, 0, 0))
    q = out.load()
    keep = {p: c for p, c in px.items() if 0 <= p[0] < F and 0 <= p[1] <= bc.BASE}
    for (x, y), c in keep.items():
        q[x, y] = c + (255,)
    for (x, y) in keep:
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = x + dx, y + dy
            if 0 <= nx < F and 0 <= ny <= bc.BASE and (nx, ny) not in keep and (over or not o[nx, ny][3]):
                q[nx, ny] = OUTLINE[:3] + (255,)
    return out


def anchors(fig, row):
    """(hip of the weapon hand, other hip, upper back centre, figure centre x)."""
    bb = fig.getbbox()
    x0, y0, x1, y1 = bb
    px = fig.load()
    wy = max(y0, y1 - 11)
    xs = [x for x in range(F) if px[x, wy][3]] or [x0, x1 - 1]
    cx = (x0 + x1 - 1) / 2
    return (max(xs), wy), (min(xs), wy), (cx, y0 + 10), cx


def hip_sword(kind, pal, h, d):
    """Scabbard hanging from the hip along d (down), hilt up: grip and
    pommel above h, guard across at h, leather scabbard with a metal chape."""
    bwi.set_colours(pal)
    n = bw.perp(d)
    blade = 6.0 if kind == "sword" else 3.5
    px = {}
    for p in bw.line(bw.at(h, d, 1), bw.at(h, d, blade)):
        px[p] = SCABBARD[1]
    for p in bw.line(bw.at(h, d, 1.6, n, 0.8), bw.at(h, d, blade - 0.6, n, 0.8)):
        px.setdefault(p, SCABBARD[0])
    px[rpt(bw.at(h, d, blade + 0.8))] = pal["blade"][2]
    for s in ((-1.2, 1.2, -2.2, 2.2) if kind == "sword" else (-1.2, 1.2)):
        px[rpt(bw.at(h, d, 0.2, n, s))] = bw.GUARD
    px[rpt(h)] = bw.GUARD
    px[rpt(bw.at(h, d, -1))] = pal["handle"][1]
    px[rpt(bw.at(h, d, -2))] = pal["handle"][2] if kind == "sword" else pal["handle"][1]
    return px


def back_weapon(kind, shape, pal, c, u, row):
    """Weapon across the back centred on c, u = unit vector along it toward
    the hilt or head end (up)."""
    bwi.set_colours(pal)
    neg = (-u[0], -u[1])
    if kind == "longsword":
        h, d = bw.at(c, u, 6), neg
    elif kind == "axe":
        h, d = bw.at(c, u, -2), u
    elif kind == "spear":
        h, d = bw.at(c, u, -4.5), u
    else:  # bow, along the diagonal, belly away from the back
        return bwi.draw_item(kind, shape, pal, c, u, 0, "roll_" + row.split("_")[1], 1)
    return bwi.draw_item(kind, shape, pal, h, d, 0, row, 1)


def sheathed_sheet(iid, pal, base, offhand=False):
    spec = bwi.ITEMS[iid]
    kind, shape = spec["type"], spec.get("shape")
    out = Image.new("RGBA", (COLS * F, len(ROWS) * F), (0, 0, 0, 0))
    for row in SHEATHE_ROWS:
        r = ROWS.index(row)
        view = row.split("_")[1]
        for i in range(bc.COUNTS[row.split("_")[0]]):
            fig = figure(base, r, i)
            if not fig.getbbox():
                continue
            hip, other_hip, back, cx = anchors(fig, row)
            if kind in HIP_TYPES:
                if view == "side":
                    # near hip in front; the other one behind the body
                    h = (cx + (-1 if offhand else 0), hip[1])
                    d = (-0.45, 0.89)
                elif offhand:
                    h, d = (other_hip[0] + 1, other_hip[1]), (-0.35, 0.94)
                else:
                    h, d = (hip[0] - 1, hip[1]), (0.35, 0.94)
                px = hip_sword(kind, pal, h, d)
            else:
                if view == "side":
                    c, u = (cx - 3, back[1] + 1), (-0.4, -0.92)
                elif view == "up":
                    c, u = (back[0] + 1, back[1] + 2), (0.7, -0.71)
                else:
                    # behind the body: shifted out so the hilt or head shows
                    # over the shoulder, beside the hood
                    c, u = (back[0] + 4, back[1]), (0.6, -0.8)
                px = back_weapon(kind, shape, pal, c, u, row)
            over = kind in HIP_TYPES or row.endswith("_up") or row.endswith("_side")
            out.alpha_composite(drop_orphans(render(px, fig, over)), (i * F, r * F))
    return out


# ---------------------------------------------------------------- main ----

def main():
    args = [a for a in sys.argv[1:] if a != "--force"]
    force = "--force" in sys.argv
    root = args[0]
    ids = args[1:] or list(bwi.ITEMS)
    climber = os.path.join(root, "game/assets/characters/climber")
    base = {k: bw.load(os.path.join(climber, k + ".png")) for k in ("body", "hair", "outfit")}
    os.makedirs(os.path.join(climber, "offhand"), exist_ok=True)
    for iid in ids:
        pal = bwi.palette(root, iid)
        save_guarded(sheathed_sheet(iid, pal, base), os.path.join(climber, "weapons", iid + "_sheathed.png"), force)
        if bwi.ITEMS[iid]["type"] != "sword":
            continue
        sheet = bw.load(os.path.join(climber, "weapons", iid + ".png"))
        save_guarded(offhand_sheet(sheet, base), os.path.join(climber, "offhand", iid + ".png"), force)
        save_guarded(sheathed_sheet(iid, pal, base, True),
                     os.path.join(climber, "offhand", iid + "_sheathed.png"), force)


if __name__ == "__main__":
    main()
