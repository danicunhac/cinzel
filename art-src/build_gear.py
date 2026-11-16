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
  - armor: the torso pixels of outfit.png (jacket, gloves, scarf and the
    belt above the trousers; never the trousers, the pack, which
    split_layers.py took out, or a blade-coloured pixel of the slash)
    repainted onto the armor's ramp (the icon's tones topped by its
    highlight, by brightness rank spread up by `lift`, so the sprite's light
    tones land on the icon's highlights),
    plus a pattern per armor (quilting, a strap, chain dither, scales, plate
    bands and pauldrons that stick out 1 px past the shoulders);
  - helm: the visible head pixels of hair.png (hood and the fringe under it,
    where outfit.png does not cover them) repainted onto the helm's ramp, so
    the hair never pokes through; horns and the circlet band are drawn on
    top. The circlet only adds the band and leaves the hood and hair.
The game draws body, hair, outfit, armor, backpack, helm, weapon
(LayeredSprite), so the outfit's own dark outline stays visible under the
armor and the helm, and the backpack layer (build_backpacks.py) covers the
pack on the armor's back.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from PIL import Image  # noqa: E402

import build_climber as bc  # noqa: E402
import build_outfits as bo  # noqa: E402
from artlib import OUTLINE, colour_counts, icon_pixels, icon_ramp, icon_ramp_shares, quantile_index, save_guarded  # noqa: E402

F = 32
COLS = 8
ROWS = bc.ROW_NAMES
ATTACK_ROWS = ["attack_down", "attack_up", "attack_side"]
GROUND_ROW = 30

# Colours come from the item icon (game/assets/items/<id>.png): k-means on
# its opaque pixels (artlib.icon_ramp), sorted dark -> light, so the sprite
# wears the icon's own tones. Armor ramps: body (jacket and gloves: the icon
# minus its belt row), trim (belt and buckles above the trousers: the icon's
# belt row), collar (the scarf: the darker body tones). Selectors take
# (x, y, colour) on the 16x16 icon.
BELT_ROW = 10


def not_belt(x, y, c):
    return y != BELT_ROW


def belt(x, y, c):
    return y == BELT_ROW


def blue(x, y, c):
    return c[2] > c[0] + 20


ARMORS = {
    # padded cloth: light beige quilted gambeson
    "armor_cloth": {"pattern": "quilt", "lift": 0.5, "skirt": (3, 0.5, False)},
    # red-brown leather with a strap across the chest and a buckle
    "armor_leather": {"pattern": "strap", "lift": 0.8, "skirt": (2, 0.0, False), "shoulders": "flaps"},
    # grey chain mail, dithered (the icon's brown straps stay out of the mail)
    "armor_chain": {"pattern": "chain", "lift": 0.45, "shine": 0.35,
                    "select": lambda x, y, c: y != BELT_ROW and c[0] - c[2] < 25, "skirt": (3, 0.5, False)},
    # dark olive-bronze scales
    "armor_scale": {"pattern": "scale", "lift": 0.8, "skirt": (4, 0.6, False)},
    # pale steel plate with pauldrons
    "armor_plate": {"pattern": "plate", "lift": 0.45, "shine": 0.15, "skirt": (2, 0.0, False)},
    # dark purple-brown shadow cloth
    "armor_shadow": {"pattern": "shadow", "lift": 0.8, "skirt": (3, 0.8, True), "shoulders": "spikes"},
}

HELMS = {
    # travel hood: orange-brown leather, dark inside the brim
    "helm_hood": {"style": "hood"},
    # bronze cap with a bright brim and a nose guard
    "helm_iron": {"style": "iron"},
    # bronze cap with yellow-bone horns (the icon's outer columns)
    "helm_horned": {"style": "horned", "select": lambda x, y, c: 4 <= x <= 11,
                    "horn_select": lambda x, y, c: x <= 3 or x >= 12},
    # thin gold band over the hood with a blue gem in front
    "helm_circlet": {"style": "circlet"},
}


def icon_highlight(path, select):
    """Mean of the brightest tenth of the icon's selected pixels."""
    pts = sorted(icon_pixels(path, select, 48), key=lum)
    top = pts[-max(1, len(pts) // 10):]
    return tuple(round(sum(p[i] for p in top) / len(top)) for i in range(3))


def icon_spec(root, gid):
    """Spec of armor or helm `gid` with its ramps (and each ramp colour's
    share of the icon, for histogram matching) sampled from its icon."""
    path = os.path.join(root, "game/assets/items", gid + ".png")
    if gid in ARMORS:
        spec = dict(ARMORS[gid])
        # Body ramp: the icon's main tones (k-means, its darkest folds play
        # the part of the sprite's own outline) topped by the icon's own
        # highlight, mapped by brightness rank: the sprite's lightest tones
        # land on the icon's highlights, so the armor reads at a glance as
        # its icon does (silver plate and mail, light beige cloth).
        sel = spec.get("select", not_belt)
        body = icon_ramp(path, 4, sel, dark=48)
        hi = icon_highlight(path, sel)
        # metal: the highlight pushed toward white by `shine` (the glint a
        # 16 px icon has no room for), so mail and plate read as steel
        s = spec.get("shine", 0.0)
        body.append(tuple(round(v + (255 - v) * s) for v in hi))
        trim, trim_w = icon_ramp_shares(path, 3, belt)
        spec.update(body=body, trim=trim, collar=body[1:4], strap=trim[1:])
        spec["shares"] = {"trim": trim_w}
        return spec
    spec = dict(HELMS[gid])
    if spec["style"] == "circlet":
        spec["gold"] = icon_ramp(path, 3, lambda x, y, c: not blue(x, y, c))
        spec["gem"] = icon_ramp(path, 1, blue)[0]
        return spec
    full, w = icon_ramp_shares(path, 5, spec.get("select"), dark=20)
    spec.update(ramp=full[1:], inside=full[0], brim=full[-1])
    spec["shares"] = {"ramp": [s / sum(w[1:]) for s in w[1:]]}
    if "horn_select" in spec:
        spec["horn"] = icon_ramp(path, 3, spec["horn_select"])
    return spec


def load(path):
    return Image.open(path).convert("RGBA")


def lum(c):
    return 0.3 * c[0] + 0.59 * c[1] + 0.11 * c[2]


def step(ramp, i, d):
    return ramp[max(0, min(len(ramp) - 1, i + d))]


def rank(ramps, c, src_group, spec, name):
    """Index on spec[name] of starter colour c: histogram matching of its
    group onto the icon's tones when the ramp has icon shares, else its
    brightness rank in the group."""
    ramp = spec[name]
    shares = spec.get("shares", {}).get(name)
    if shares:
        idx = spec.setdefault("_index", {})
        if name not in idx:
            idx[name] = quantile_index(ramps.counts[src_group], shares)
        if c[:3] in idx[name]:
            return idx[name][c[:3]]
    cols = ramps.groups[src_group]
    i = cols.index(c[:3]) if c[:3] in cols else min(range(len(cols)), key=lambda j: abs(lum(cols[j]) - lum(c)))
    t = i / max(1, len(cols) - 1)
    if name == "body":
        # most jacket pixels are its dark tones: `lift` < 1 spreads them up
        # the ramp, so a light icon (cloth, mail, plate) reads light
        t = t ** spec.get("lift", 1.0)
    return round(t * (len(ramp) - 1))


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
                px[(x, y)] = ("trim", rank(ramps, p, "khaki", spec, "trim"))
            elif k == "scarf":
                px[(x, y)] = ("collar", rank(ramps, p, "scarf", spec, "collar"))
            else:
                px[(x, y)] = ("body", rank(ramps, p, "leather", spec, "body"))
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
    if standing and spec.get("shoulders"):
        extra = shoulders(row, body, hair, outfit, px, y0, spec["body"], spec["shoulders"])
    if standing and legs and spec.get("skirt"):
        armor_skirt(row, body, outfit, keep, q, legs, spec, pattern)
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


def shoulders(row, body, hair, outfit, px, y0, ramp, kind):
    """Leather flaps (1 px past the shoulder, 2 rows) or shadow spikes
    (1 px past the shoulder and a point rising over it), outlined."""
    comp = Image.new("RGBA", (F, F), (0, 0, 0, 0))
    for im in (body, hair, outfit):
        comp.alpha_composite(im)
    a = comp.load()
    sides = [1] if row.endswith("side") else [-1, 1]
    out = {}
    for s in sides:
        top = [x for (x, yy) in px if yy == y0 + 1]
        if not top:
            continue
        for dy, shade in ((0, 3), (1, 2)):
            y = y0 + 1 + dy
            row_px = [x for (x, yy) in px if yy == y]
            if not row_px:
                continue
            x = max(row_px) if s > 0 else min(row_px)
            out[(x + s, y)] = ramp[shade]
        if kind == "spikes":
            x = (max(top) if s > 0 else min(top)) + s
            out[(x, y0)] = ramp[2]
            out[(x + s, y0 - 1)] = ramp[3]
    for (x, y) in list(out):
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = x + dx, y + dy
            if 0 <= nx < F and 0 <= ny < F and (nx, ny) not in out and (nx, ny) not in px \
                    and not (a[nx, ny][3] and not bc.is_outline(a[nx, ny])):
                out[(nx, ny)] = OUTLINE
    return {p: c for p, c in out.items() if 0 <= p[0] < F and 0 <= p[1] < F}


def armor_skirt(row, body, outfit, keep, q, legs, spec, pattern):
    """The armor's skirt below the belt (`skirt`: rows, flare, ragged hem):
    over the trousers at the hips' width, flaring toward the hem, with the
    armor's own pattern, a ragged hem for the shadow cloth, outlined. Arms,
    hands and blades stay in front."""
    rows, flare, ragged = spec["skirt"]
    ramp = spec["body"]
    o = outfit.load()
    b = body.load()
    waist = legs[0]
    hips = None
    for y in range(waist - 1, waist - 4, -1):
        xs = [x for x in range(F) if o[x, y][3] and (x, y) not in keep and bo.group(o[x, y], "outfit") == "leather"]
        if xs:
            hips = (min(xs), max(xs))
            break
    if hips is None:
        return
    face_side = row.endswith("side")
    drawn = set()
    hem = min(waist + rows - 1, GROUND_ROW - 1)
    for y in range(waist, hem + 1):
        t = (y - waist + 1) / rows
        fl = round(t * flare)
        x0 = hips[0] - fl
        x1 = hips[1] + (0 if face_side else fl)
        for x in range(max(1, x0), min(F - 1, x1 + 1)):
            p = o[x, y]
            g = p[3] and bo.group(p, "outfit")
            if (x, y) in keep or g in ("leather", "scarf") or (b[x, y][3] and bc.is_skin(b[x, y])):
                continue
            if ragged and y == hem and (x + y) % 2 == 0:
                continue
            i = 2
            if pattern == "chain":
                i = 3 if (x + y) % 2 == 0 else 1
            elif pattern == "scale":
                i = 1 if (y - waist) % 2 == 1 and (x + (y - waist) // 2) % 3 == 0 else 3
            elif pattern == "plate":
                i = 1 if y == hem else 3
            elif pattern == "quilt":
                i = 1 if (x - hips[0]) % 4 == 3 else 2
            if (x - 1, y) not in drawn and x == max(1, x0):
                i = min(len(ramp) - 1, i + 1)
            q[x, y] = ramp[i] + (255,)
            drawn.add((x, y))
    for x, y in list(drawn):
        for dx, dy in ((1, 0), (-1, 0), (0, 1)):
            nx, ny = x + dx, y + dy
            if not (0 <= nx < F and ny <= GROUND_ROW) or (nx, ny) in drawn or q[nx, ny][3]:
                continue
            p = o[nx, ny]
            g = p[3] and bo.group(p, "outfit")
            if (nx, ny) in keep or g in ("leather", "scarf") or (b[nx, ny][3] and bc.is_skin(b[nx, ny])):
                continue
            q[nx, ny] = OUTLINE


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


def helm_cell(row, body, hair, outfit, spec, ramps):
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
            q[x, y] = ramp[rank(ramps, c, "hood", spec, "ramp")] + (255,)
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
    if style == "hood" and standing:
        cowl(q, px, body, outfit, face_top, ramp)
    if style == "iron" and standing:
        brim_flare(q, px, brim, spec["brim"], row)
    return out


def outline_new(q, new, px):
    for x, y in list(new):
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = x + dx, y + dy
            if 0 <= nx < F and 0 <= ny < F and (nx, ny) not in new and (nx, ny) not in px and not q[nx, ny][3]:
                q[nx, ny] = OUTLINE


def cowl(q, px, body, outfit, face_top, ramp):
    """The travel hood is a deep cowl: 1 px bigger than the hood over the
    crown and down the sides (not below the hood's own bottom)."""
    hood = {p for p, (k, c) in px.items() if k == "hood"}
    if not hood:
        return
    y_low = max(y for x, y in hood) - 2
    b = body.load()
    o = outfit.load()
    new = set()
    for x, y in hood:
        for dx, dy in ((0, -1), (-1, 0), (1, 0)):
            nx, ny = x + dx, y + dy
            if not (0 <= nx < F and 0 <= ny < F) or ny > y_low or (nx, ny) in px or q[nx, ny][3]:
                continue
            if b[nx, ny][3] or o[nx, ny][3]:
                continue
            new.add((nx, ny))
    for x, y in new:
        q[x, y] = ramp[1] + (255,)
    # the old outline of the hood becomes cloth where the cowl covers it
    for (x, y), (k, c) in px.items():
        if k == "hood" and bc.is_outline(c) and not q[x, y][3]:
            q[x, y] = ramp[0] + (255,)
    outline_new(q, new, px)


def brim_flare(q, px, brim, colour, row):
    """The iron cap's brim sticks out 1 px past the dome on each visible
    side (the front one from the side)."""
    xs = sorted(x for (x, y) in px if y == brim)
    if not xs:
        return
    new = set()
    for s in ([1] if row.endswith("side") else [-1, 1]):
        x = (xs[-1] if s > 0 else xs[0]) + s
        if 0 <= x < F and not q[x, brim][3]:
            q[x, brim] = colour + (255,)
            new.add((x, brim))
    outline_new(q, new, px)


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
        shape = [(0, 0, 1), (0, -1, 0), (1, -1, 1), (1, -2, 2), (2, -2, 1), (2, -3, 2), (2, -4, 2)]
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


def build_sheet(names, body, hair, outfit, weapon, spec, ramps):
    out = Image.new("RGBA", outfit.size, (0, 0, 0, 0))
    for r, c, box in cells(outfit):
        cut = [im.crop(box) for im in (body, hair, outfit, weapon)]
        if not (cut[1].getbbox() or cut[2].getbbox()):
            continue
        if "pattern" in spec:
            cell = armor_cell(names[r], *cut, spec, ramps)
        else:
            cell = helm_cell(names[r], cut[0], cut[1], cut[2], spec, ramps)
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
    # pixel counts per starter colour group (for histogram matching)
    ramps.counts = {}
    for layer, img in sheets:
        for k, d in colour_counts([img], lambda p, layer=layer: bo.group(p, layer)).items():
            for c, n in d.items():
                ramps.counts.setdefault(k, {})[c] = ramps.counts.get(k, {}).get(c, 0) + n
    gdir = os.path.join(climber, "gear")
    os.makedirs(os.path.join(gdir, "attacks"), exist_ok=True)
    for gid in ids:
        spec = icon_spec(root, gid)
        sheet = build_sheet(ROWS, base["body"], base["hair"], base["outfit"], base["weapon"], spec, ramps)
        save_guarded(sheet, os.path.join(gdir, gid + ".png"), force)
        for t in kinds:
            a = attacks[t]
            wa = load(os.path.join(climber, "weapons", t + ".png")).crop((0, 6 * F, COLS * F, 9 * F))
            strip = build_sheet(ATTACK_ROWS, a["body"], a["hair"], a["outfit"], wa, spec, ramps)
            save_guarded(strip, os.path.join(gdir, "attacks", "%s_%s.png" % (t, gid)), force)


if __name__ == "__main__":
    main()
