"""Build one climber weapon layer per weapon item, in the colours (and shape)
of the item's icon.

python3 -I art-src/build_weapon_items.py <repo_root> [--force] [id ...]

Inputs: game/assets/items/<id>.png (the icon), climber/weapons/<type>.png
and the attack overrides climber/attacks/<type>_{body,hair,outfit}.png
(build_weapons.py), climber/{body,hair,outfit,weapon}.png.
Output: climber/weapons/<id>.png, 8x13 grid of 32x32 like the type sheet
(the game falls back to the type sheet when an item has none).

Palettes: each icon is split into parts (blade or head, handle or shaft,
guard, bow string, accents) by position along its diagonal and by colour;
each part's opaque pixels go through k-means (artlib.kmeans), sorted dark ->
light. Every frame lines up with the type sheet:
  - idle, walk, roll and death rows: redrawn with build_weapons.py's own
    grip and drawing code (same pixels as the type sheet) in the item's
    colours, plus the item's shape edits: a second axe blade (axe_war),
    wings and a red tassel under the spear head (spear_dragoon). The sword
    items recolour the shipped sword rows instead, and sword_knight gets
    its gold cross guard at the grip;
  - attack rows: the type sheet's attack rows recoloured by histogram
    matching (steel -> blade ramp, wood -> handle ramp). Where the weapon
    layer shows a long straight weapon (a spear thrust), the shaft pixels
    the colour split left in the body, hair and outfit strips (on the line
    through the weapon pixels) are copied onto the weapon layer in the
    handle colours, and the spear wings are added next to the tip.
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from PIL import Image  # noqa: E402

import build_climber as bc  # noqa: E402
import build_weapons as bw  # noqa: E402
from artlib import OUTLINE, colour_counts, icon_pixels, is_steel, kmeans, lum, quantile_index, save_guarded  # noqa: E402
from strips import drop_orphans  # noqa: E402

F = 32
COLS = 8
ROWS = bc.ROW_NAMES
ATTACK_ROWS = bw.ATTACK_ROWS


def diag(x, y):
    """Position along the icon's diagonal: 0 at the bottom-left pommel, 30
    at the top-right tip."""
    return x + 15 - y


def is_blue(c):
    return c[2] > c[0] + 15


def is_green(c):
    return c[1] > c[0] and c[1] > c[2] + 10


def is_grey(c):
    return max(c) - min(c) < 40


def is_gold(c):
    return c[0] > 140 and c[1] > 100 and max(c) - min(c) >= 40


def is_red(c):
    return c[0] > 90 and c[0] > c[1] * 1.6


# Icon parts per item: selector(x, y, colour) for the blade (or axe/spear
# head, or bow limbs), the handle (grip, shaft), and optional guard, string
# and accent (dragoon tassel). "shape" names the item's edits.
ITEMS = {
    "sword_iron": {"type": "sword", "blade": lambda x, y, c: diag(x, y) >= 13,
                   "handle": lambda x, y, c: diag(x, y) <= 8},
    "sword_knight": {"type": "sword", "blade": lambda x, y, c: diag(x, y) >= 13,
                     "handle": lambda x, y, c: diag(x, y) <= 12 and is_blue(c),
                     "guard": lambda x, y, c: diag(x, y) <= 12 and is_gold(c), "shape": "guard"},
    "longsword_steel": {"type": "longsword", "blade": lambda x, y, c: diag(x, y) >= 13,
                        "handle": lambda x, y, c: diag(x, y) <= 8},
    "longsword_ember": {"type": "longsword", "blade": lambda x, y, c: diag(x, y) >= 13,
                        "handle": lambda x, y, c: diag(x, y) <= 9},
    "axe_woodcutter": {"type": "axe", "blade": lambda x, y, c: diag(x, y) >= 13 and is_grey(c),
                       "handle": lambda x, y, c: not is_grey(c)},
    "axe_war": {"type": "axe", "blade": lambda x, y, c: diag(x, y) >= 15,
                "handle": lambda x, y, c: diag(x, y) <= 12, "shape": "double"},
    "spear_hunter": {"type": "spear", "blade": lambda x, y, c: diag(x, y) >= 23,
                     "handle": lambda x, y, c: diag(x, y) <= 21},
    "spear_dragoon": {"type": "spear", "blade": lambda x, y, c: diag(x, y) >= 17 and not is_red(c),
                      "handle": lambda x, y, c: diag(x, y) <= 13 and not is_red(c),
                      "accent": lambda x, y, c: is_red(c) and diag(x, y) > 6, "shape": "wings"},
    "dagger_rogue": {"type": "dagger", "blade": lambda x, y, c: diag(x, y) >= 14,
                     "handle": lambda x, y, c: diag(x, y) <= 11},
    "dagger_twin_fang": {"type": "dagger", "blade": lambda x, y, c: diag(x, y) >= 13,
                         "handle": lambda x, y, c: diag(x, y) <= 11},
    "bow_short": {"type": "bow", "blade": lambda x, y, c: not is_grey(c),
                  "string": lambda x, y, c: is_grey(c)},
    "bow_elven": {"type": "bow", "blade": lambda x, y, c: is_green(c),
                  "string": lambda x, y, c: not is_green(c)},
}


def ramp_of(path, select, k, dark=36):
    """(colours dark -> light, share of each), padded to k by repeating the
    lightest so ramp[i] always exists."""
    km = kmeans(icon_pixels(path, select, dark), k)
    cols = [c for c, _ in km]
    shares = [s for _, s in km]
    while len(cols) < k:
        cols.append(cols[-1])
        shares.append(0.0)
    return cols, shares


def palette(root, iid):
    spec = ITEMS[iid]
    path = os.path.join(root, "game/assets/items", iid + ".png")
    pal = {}
    pal["blade"], pal["blade_w"] = ramp_of(path, spec["blade"], 4)
    if "handle" in spec:
        pal["handle"], pal["handle_w"] = ramp_of(path, spec["handle"], 3, dark=24)
    else:
        pal["handle"], pal["handle_w"] = pal["blade"][:3], pal["blade_w"][:3]
    pal["guard"] = ramp_of(path, spec["guard"], 2)[0] if "guard" in spec else pal["handle"][1:]
    pal["string"] = ramp_of(path, spec["string"], 1)[0][0] if "string" in spec else bw.STRING_C
    pal["accent"] = ramp_of(path, spec["accent"], 2)[0] if "accent" in spec else None
    return pal


# --------------------------------------------------- procedural rows ----

def set_colours(pal):
    """Point build_weapons' drawing colours at the item palette."""
    b, h = pal["blade"], pal["handle"]
    bw.STEEL_D, bw.STEEL_M, bw.STEEL_L, bw.STEEL_H = b[0], b[1], b[2], b[3]
    bw.WOOD_D, bw.WOOD_M, bw.WOOD_L = h[0], h[1], h[2]
    bw.GUARD = pal["guard"][-1]
    bw.STRING_C = pal["string"]


def rpt(p):
    return tuple(map(round, p))


def draw_item(kind, shape, pal, h, d, L, row, sign):
    px = bw.draw(kind, h, d, L, row, sign)
    n = bw.perp(d)
    if shape == "double":
        # a second blade on the other side of the haft, mirrored
        for t in (5.6, 6.6, 7.6):
            for s in (1, 2, 3):
                px[rpt(bw.at(h, d, t, n, s))] = bw.STEEL_L if s < 3 else bw.STEEL_M
        px[rpt(bw.at(h, d, 8.4, n, 3))] = bw.STEEL_H
    elif shape == "wings":
        # swept wings under the head and a red tassel hanging from them
        for s in (-2, 2):
            px[rpt(bw.at(h, d, 9.6, n, s))] = bw.STEEL_L
            px[rpt(bw.at(h, d, 9.2, n, s * 1.5))] = bw.STEEL_M
        if pal["accent"]:
            px[rpt(bw.at(h, d, 8.6, n, 1))] = pal["accent"][-1]
            px[rpt(bw.at(h, d, 7.8, n, 1.4))] = pal["accent"][0]
    return px


def procedural_rows(kind, shape, pal, base, sheet):
    set_colours(pal)
    for r, row in enumerate(ROWS):
        if row in ATTACK_ROWS:
            continue
        sheet.paste((0, 0, 0, 0), (0, r * F, COLS * F, r * F + F))
        for i in range(bc.COUNTS[row.split("_")[0]]):
            others = Image.new("RGBA", (F, F), (0, 0, 0, 0))
            for k in ("body", "hair", "outfit"):
                others.alpha_composite(bw.cell(base[k], r, i))
            g = bw.grip(bw.cell(base["weapon"], r, i), others)
            if g is None:
                continue
            h, d, L = g
            px = draw_item(kind, shape, pal, h, d, L, row, bw.side_sign(row, h[0], others))
            sheet.alpha_composite(bw.render(px, others, h, row), (i * F, r * F))


# ---------------------------------------------------------- recolour ----

def recolour_maps(type_sheet, pal):
    counts = colour_counts([type_sheet], lambda p: None if bc.is_outline(p) else "steel" if is_steel(p) else "warm")
    maps = {}
    for k, ramp, shares in (("steel", pal["blade"], pal["blade_w"]), ("warm", pal["handle"], pal["handle_w"])):
        if k in counts:
            idx = quantile_index(counts[k], shares)
            maps.update({c: ramp[i] for c, i in idx.items()})
    return maps


def recolour(img, maps):
    out = img.copy()
    px = out.load()
    for y in range(out.height):
        for x in range(out.width):
            p = px[x, y]
            if p[3] and p[:3] in maps:
                px[x, y] = maps[p[:3]] + (255,)
    return out


def knight_guard(sheet, pal, base):
    """Gold cross guard at the grip of the shipped sword, every frame."""
    gold = pal["guard"]
    for r, row in enumerate(ROWS):
        for i in range(bc.COUNTS[row.split("_")[0]]):
            others = Image.new("RGBA", (F, F), (0, 0, 0, 0))
            for k in ("body", "hair", "outfit"):
                others.alpha_composite(bw.cell(base[k], r, i))
            g = bw.grip(bw.cell(base["weapon"], r, i), others)
            if g is None:
                continue
            h, d, _ = g
            n = bw.perp(d)
            for s, c in ((-1.4, gold[-1]), (1.4, gold[-1]), (-2.2, gold[0]), (2.2, gold[0])):
                x, y = rpt(bw.at(h, d, 0.3, n, s))
                if 0 <= x < F and 0 <= y <= bc.BASE:
                    sheet.putpixel((i * F + x, r * F + y), c + (255,))


# ------------------------------------------------------- attack shafts ----

def axis(pts):
    """(centre, unit direction, half length along it, spread across it)."""
    mx = sum(p[0] for p in pts) / len(pts)
    my = sum(p[1] for p in pts) / len(pts)
    sxx = sum((p[0] - mx) ** 2 for p in pts)
    syy = sum((p[1] - my) ** 2 for p in pts)
    sxy = sum((p[0] - mx) * (p[1] - my) for p in pts)
    a = 0.5 * math.atan2(2 * sxy, sxx - syy)
    d = (math.cos(a), math.sin(a))
    along = [(p[0] - mx) * d[0] + (p[1] - my) * d[1] for p in pts]
    across = [abs(-(p[0] - mx) * d[1] + (p[1] - my) * d[0]) for p in pts]
    return (mx, my), d, along, max(across)


def attack_shafts(sheet, strips, pal, shape):
    """Spear thrusts: copy the shaft pixels from the body, hair and outfit
    strips onto the weapon layer in the handle colours; dragoon wings by
    the tip."""
    handle = pal["handle"]
    for j, row in enumerate(ATTACK_ROWS):
        r = ROWS.index(row)
        for i in range(bc.COUNTS["attack"]):
            box = (i * F, r * F, i * F + F, r * F + F)
            w = sheet.crop(box)
            wp = w.load()
            pts = [(x, y) for y in range(F) for x in range(F) if wp[x, y][3] and not bc.is_outline(wp[x, y])]
            if len(pts) < 3:
                continue
            # a thrust runs along the facing: across the cell from the side,
            # up and down the cell from the front and the back
            d = (1.0, 0.0) if row.endswith("side") else (0.0, 1.0)
            ys = sorted(p[1] for p in pts)
            xs = sorted(p[0] for p in pts)
            cx, cy = xs[len(xs) // 2], ys[len(ys) // 2]
            along = [(p[0] - cx) * d[0] + (p[1] - cy) * d[1] for p in pts]
            if max(along) - min(along) < 3:
                continue
            lo, hi = min(along), max(along)
            comp = Image.new("RGBA", (F, F), (0, 0, 0, 0))
            for k in ("body", "hair", "outfit"):
                comp.alpha_composite(strips[k].crop((i * F, j * F, i * F + F, j * F + F)))
            sp = comp.load()

            def shaft_px(x, y):
                p = sp[x, y] if 0 <= x < F and 0 <= y < F else (0, 0, 0, 0)
                return p[3] and not bc.is_outline(p) and not bc.is_skin(p)

            # walk the line through the weapon pixels both ways from each
            # end while the strips have a (non-outline, non-skin) pixel on it
            add = {}
            for start, step in ((hi, 1), (lo, -1)):
                t, miss = start, 0
                while miss < 2 and abs(t - start) < 12:
                    t += step
                    x, y = rpt((cx + d[0] * t, cy + d[1] * t))
                    if not (0 <= x < F and 0 <= y < F):
                        break
                    if wp[x, y][3]:
                        miss = 0
                        continue
                    if shaft_px(x, y):
                        add[(x, y)] = handle[min(2, int(lum(sp[x, y]) / 60))]
                        miss = 0
                    else:
                        miss += 1
            for (x, y), c in add.items():
                sheet.putpixel((i * F + x, r * F + y), c + (255,))
            if shape == "wings":
                # the tip is the weapon end farther from the figure's centre
                fig = strips["outfit"].crop((i * F, j * F, i * F + F, j * F + F)).getbbox()
                fx = (fig[0] + fig[2]) / 2 if fig else 16
                fy = (fig[1] + fig[3]) / 2 if fig else 20
                ends = [(cx + d[0] * lo, cy + d[1] * lo), (cx + d[0] * hi, cy + d[1] * hi)]
                tip = max(ends, key=lambda e: math.dist(e, (fx, fy)))
                back = (cx - tip[0], cy - tip[1])
                bl = math.hypot(*back) or 1
                u = (back[0] / bl, back[1] / bl)
                n = (-u[1], u[0])
                others = Image.new("RGBA", (F, F), (0, 0, 0, 0))
                for k in ("body", "hair", "outfit"):
                    others.alpha_composite(strips[k].crop((i * F, j * F, i * F + F, j * F + F)))
                wings = {}
                for s in (-2, 2):
                    for t, c in ((3, pal["blade"][2]), (4, pal["blade"][1])):
                        x, y = rpt((tip[0] + u[0] * t + n[0] * s * (1 if t == 3 else 0.6),
                                    tip[1] + u[1] * t + n[1] * s * (1 if t == 3 else 0.6)))
                        if 0 <= x < F and 0 <= y <= bc.BASE and not wp[x, y][3]:
                            wings[(x, y)] = c
                cell = Image.new("RGBA", (F, F), (0, 0, 0, 0))
                for (x, y), c in wings.items():
                    cell.putpixel((x, y), c + (255,))
                # the outline only where it sits on the floor
                o = others.load()
                for (x, y) in wings:
                    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                        nx, ny = x + dx, y + dy
                        if 0 <= nx < F and 0 <= ny <= bc.BASE and (nx, ny) not in wings \
                                and not wp[nx, ny][3] and not o[nx, ny][3]:
                            cell.putpixel((nx, ny), OUTLINE)
                sheet.alpha_composite(cell, (i * F, r * F))


# ---------------------------------------------------------------- main ----

def build_item(root, iid, base):
    spec = ITEMS[iid]
    kind, shape = spec["type"], spec.get("shape")
    climber = os.path.join(root, "game/assets/characters/climber")
    type_sheet = Image.open(os.path.join(climber, "weapons", kind + ".png")).convert("RGBA")
    pal = palette(root, iid)
    sheet = recolour(type_sheet, recolour_maps(type_sheet, pal))
    if kind != "sword":
        procedural_rows(kind, shape, pal, base, sheet)
    if shape == "guard":
        knight_guard(sheet, pal, base)
    if kind == "spear":
        strips = {k: Image.open(os.path.join(climber, "attacks", "%s_%s.png" % (kind, k))).convert("RGBA")
                  for k in ("body", "hair", "outfit")}
        attack_shafts(sheet, strips, pal, shape)
    return drop_orphans(sheet)


def main():
    args = [a for a in sys.argv[1:] if a != "--force"]
    force = "--force" in sys.argv
    root = args[0]
    ids = args[1:] or list(ITEMS)
    climber = os.path.join(root, "game/assets/characters/climber")
    base = {k: bw.load(os.path.join(climber, k + ".png")) for k in ("body", "hair", "outfit", "weapon")}
    for iid in ids:
        save_guarded(build_item(root, iid, base), os.path.join(climber, "weapons", iid + ".png"), force)


if __name__ == "__main__":
    main()
