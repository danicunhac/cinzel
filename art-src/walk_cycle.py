"""Hand-made walk cycle built from the clean idle frames (used by
build_climber.py). Deterministic pixel edits, no generation.

Each frame is a dict (x, y) -> (rgba, layer), so every moved pixel keeps the
layer it had in the idle frame (boots in body, trousers/vest/backpack in
outfit, hood in hair, sword in weapon).

Frames: 1 contact (left foot forward, right arm forward), 2 passing (body up
1 px, legs together), 3 contact mirrored, 4 passing.
- down/up: the forward leg reaches 1 px further toward the viewer (down) and
  the back leg lifts 1 px, so the feet differ by 2 px; arms swing 1 px
  opposite to the legs, the sword moves with its arm.
- side (facing right): the legs split into a near leg and a darker far leg,
  3 px apart (front +1, back -2); the sword arm swings 1 px against the near
  leg; on passing frames the backpack and scarf trail 1 px behind.
"""

F = 24


def frame_of(cell, lab):
    px = cell.load()
    return {p: (px[p], k) for p, k in lab.items()}


def bounds(fr, pred=lambda p, v: True):
    pts = [p for p, v in fr.items() if pred(p, v)]
    xs = [x for x, _ in pts]
    ys = [y for _, y in pts]
    return min(xs), min(ys), max(xs), max(ys)


def move(fr, sel, dx, dy, stretch=False, under=False):
    """Move the selected pixels. stretch keeps the originals too (the part
    gets 1 px longer instead of leaving a gap); under draws the moved
    pixels below the rest."""
    moved = {(x + dx, y + dy): fr[(x, y)] for (x, y) in sel}
    base = dict(fr) if stretch else {p: v for p, v in fr.items() if p not in sel}
    if under:
        out = dict(moved)
        out.update(base)
    else:
        out = base
        out.update(moved)
    return {p: v for p, v in out.items() if 0 <= p[0] < F and 0 <= p[1] < F}


def regions(fr):
    x0, top, x1, bottom = bounds(fr, lambda p, v: v[1] != "weapon")
    h = bottom - top + 1
    leg_top = bottom - 5
    feet = [x for (x, y), v in fr.items() if y >= bottom - 1 and v[1] == "body"]
    lx0, lx1 = min(feet) - 1, max(feet) + 1
    cx = (lx0 + lx1) // 2
    head = top + round(h * 0.42)
    legs = {p for p, v in fr.items() if p[1] >= leg_top and lx0 <= p[0] <= lx1 and v[1] != "weapon"}
    upper = {p for p in fr if p[1] < leg_top and p not in legs}
    return {"top": top, "bottom": bottom, "leg_top": leg_top, "cx": cx, "head": head,
            "legs": legs, "upper": upper, "x0": x0, "x1": x1}


def arms(fr, r):
    """Pixels of the outer 3 columns of the torso band, per side, plus the
    sword with the arm on its side."""
    band = [p for p in fr if r["head"] <= p[1] < r["leg_top"] + 2 and fr[p][1] != "weapon"]
    xs = [x for x, _ in band]
    lo, hi = min(xs), max(xs)
    left = {p for p in band if p[0] <= lo + 2}
    right = {p for p in band if p[0] >= hi - 2}
    sword = {p for p, v in fr.items() if v[1] == "weapon"}
    sx = sum(x for x, _ in sword) / len(sword) if sword else F
    if sx < r["cx"]:
        left |= sword
    else:
        right |= sword
    return left, right


def lift_body(fr, r):
    """Passing pose: everything above the legs up 1 px, stretched so the
    waist does not open a gap."""
    sel = {p for p in fr if p[1] < r["leg_top"] + 1}
    return move(fr, sel, 0, -1, stretch=True)


def front_back(fr):
    r = regions(fr)
    cx = r["cx"]
    left_leg = {p for p in r["legs"] if p[0] < cx}
    right_leg = {p for p in r["legs"] if p[0] >= cx}
    left_arm, right_arm = arms(fr, r)

    def contact(fwd_leg, back_leg, fwd_arm, back_arm):
        f = move(fr, fwd_leg, 0, 1, stretch=True)
        f = move(f, back_leg, 0, -1, under=True)
        f = move(f, fwd_arm & set(f), 0, 1, stretch=True)
        f = move(f, back_arm & set(f), 0, -1)
        return f

    passing = lift_body(fr, r)
    return [
        contact(left_leg, right_leg, right_arm, left_arm),
        passing,
        contact(right_leg, left_leg, left_arm, right_arm),
        passing,
    ]


def side(fr, darker):
    r = regions(fr)
    legs = r["legs"]
    hip = {p for p in legs if p[1] == r["leg_top"]}
    lower = legs - hip
    sword = {p for p, v in fr.items() if v[1] == "weapon"}
    # The sword hand: skin pixels touching the sword.
    hand = {p for p, v in fr.items() if v[1] == "body" and p[1] < r["leg_top"]
            and any((p[0] + dx, p[1] + dy) in sword for dx in (-1, 0, 1) for dy in (-1, 0, 1))}
    arm = sword | hand

    def split(near_dx, far_dx, near_on_top):
        base = {p: v for p, v in fr.items() if p not in lower}
        near = {(x + near_dx, y): fr[(x, y)] for (x, y) in lower}
        far = {(x + far_dx, y): (darker(fr[(x, y)][0]), fr[(x, y)][1]) for (x, y) in lower}
        out = dict(base)
        first, second = (far, near) if near_on_top else (near, far)
        for layer in (first, second):
            for p, v in layer.items():
                if 0 <= p[0] < F and p not in base:
                    out[p] = v
        return out

    # Contact A: near leg forward, sword arm back. Contact B: far leg
    # forward, sword arm forward.
    a = move(split(1, -2, True), arm, -1, 0)
    b = move(split(-2, 1, True), arm, 1, 0)
    passing = lift_body(fr, r)
    pack = {p for p, v in passing.items() if v[1] in ("outfit", "hair") and p[0] < r["cx"] - 3
            and r["head"] - 1 <= p[1] < r["leg_top"]}
    passing = move(passing, pack, -1, 1, stretch=True, under=True)
    return [a, passing, b, passing]


def to_cell(fr, Image):
    img = Image.new("RGBA", (F, F), (0, 0, 0, 0))
    for p, (c, _) in fr.items():
        img.putpixel(p, c)
    return img, {p: k for p, (_, k) in fr.items()}
