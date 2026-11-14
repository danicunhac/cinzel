"""Build the enemy and boss sheets from generated 6x4 animation sheets.

python3 -I art-src/build_enemies.py <repo_root> [--force] [name ...]
Existing output files are kept unless --force is passed. With names, only
those sheets are built (crawler, shooter, charger, boss_final).

Inputs (magenta background, AI generator, see docs/assets.md), each a 6x4
grid of poses, rows idle, move, attack, death:
  art-src/gen/r2/enemy24-crawler-anim-1.png   slime (edit of the old crawler)
  art-src/gen/r2/enemy24-shooter-sheet-1.png  floating stone-eye sentinel
  art-src/gen/r2/enemy24-charger-anim-1.png   beetle-boar (edit of the old charger)
  art-src/gen/r2/boss48-final-sheet-2.png     spectral hooded knight
Outputs in game/assets/enemies/: crawler, shooter, charger (6 cols x 4 rows
of 24x24, lowest pixel of each row's ground on row 22) and boss_final (6x4
of 48x48, ground on row 44).

Method: key out magenta, split the content box into an even 6x4 grid and
give each connected blob to the slot holding its centre (so a fired bolt or
falling rubble stays with its pose), scale the whole sheet by one factor,
keep every pose where it sits relative to its slot centre and its row's
ground line (hops and lunges survive), box-downscale, repaint the outline,
add a light rim on top edges so the sprite reads on the dark floor, and
quantize to one palette per sheet.
"""
import os
import statistics
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from PIL import Image, ImageEnhance  # noqa: E402

from artlib import OUTLINE, parse_args, save_guarded  # noqa: E402
from strips import drop_orphans, key, nearest, palette_of, shrink  # noqa: E402

COLS, ROWS = 6, 4

# name -> source, cell, ground row, size target (px) and what it measures on
# the idle row ("w" width or "h" height), colours, rim strength, mask boxes
# (stray figures to erase in source pixels), brightness, contrast, and
# cool_greens (olive pixels -> cold grey-violet, so the boss's hood does not
# read as the hero's).
JOBS = {
    "crawler": dict(src="enemy24-crawler-anim-1.png", cell=24, ground=22, size=(18, "w"),
                    colors=20, rim=55, mask=(), bright=1.0, contrast=1.0),
    "shooter": dict(src="enemy24-shooter-sheet-1.png", cell=24, ground=22, size=(21, "w"),
                    colors=24, rim=50, mask=((940, 190, 1088, 440),), bright=1.15, contrast=1.1),
    "charger": dict(src="enemy24-charger-anim-1.png", cell=24, ground=22, size=(22, "w"),
                    colors=22, rim=45, mask=(), bright=1.1, contrast=1.1),
    "boss_final": dict(src="boss48-final-sheet-2.png", cell=48, ground=44, size=(40, "h"),
                       colors=30, rim=40, mask=(), bright=1.2, contrast=1.15,
                       cool_greens=True),
}


def cool(img):
    px = img.load()
    for y in range(img.height):
        for x in range(img.width):
            r, g, b, a = px[x, y]
            if a and g >= r and g > b:
                v = (r + g + b) // 3
                px[x, y] = (v, max(0, v - 6), min(255, v + 14), a)
    return img


def blobs(img):
    """Connected components (8-way) of opaque pixels: list of pixel lists."""
    w, h = img.size
    a = img.getchannel("A").load()
    seen = bytearray(w * h)
    out = []
    for y0 in range(h):
        for x0 in range(w):
            if not a[x0, y0] or seen[y0 * w + x0]:
                continue
            stack = [(x0, y0)]
            seen[y0 * w + x0] = 1
            pts = []
            while stack:
                x, y = stack.pop()
                pts.append((x, y))
                for dx in (-1, 0, 1):
                    for dy in (-1, 0, 1):
                        nx, ny = x + dx, y + dy
                        if 0 <= nx < w and 0 <= ny < h and a[nx, ny] and not seen[ny * w + nx]:
                            seen[ny * w + nx] = 1
                            stack.append((nx, ny))
            out.append(pts)
    return out


def slots(img):
    """{(col, row): RGBA image of that slot's pose, same size as img} plus
    slot centres."""
    comps = [c for c in blobs(img) if len(c) >= 6]
    xs = [x for c in comps for x, _ in c]
    ys = [y for c in comps for _, y in c]
    x0, x1, y0, y1 = min(xs), max(xs) + 1, min(ys), max(ys) + 1
    sw, sh = (x1 - x0) / COLS, (y1 - y0) / ROWS
    src = img.load()
    poses = {}
    for c in comps:
        cx = sum(x for x, _ in c) / len(c)
        cy = sum(y for _, y in c) / len(c)
        k = (min(COLS - 1, int((cx - x0) / sw)), min(ROWS - 1, int((cy - y0) / sh)))
        if k not in poses:
            poses[k] = Image.new("RGBA", img.size, (0, 0, 0, 0))
        dst = poses[k].load()
        for p in c:
            dst[p] = src[p]
    centres = {k: x0 + sw * (k[0] + 0.5) for k in poses}
    return poses, centres


def finish(cell, rim):
    """1 px dark outline on the silhouette, light rim on edges open upward."""
    n = cell.width
    a = cell.getchannel("A").load()
    out = cell.copy()
    px = out.load()
    src = cell.load()
    for y in range(n):
        for x in range(n):
            if not a[x, y]:
                continue
            open_up = y == 0 or not a[x, y - 1]
            edge = any(not (0 <= x + dx < n and 0 <= y + dy < n) or not a[x + dx, y + dy]
                       for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))
            if edge and not open_up:
                px[x, y] = OUTLINE
            elif edge and open_up:
                r, g, b, _ = src[x, y]
                px[x, y] = (min(255, r + rim), min(255, g + rim), min(255, b + rim + 10), 255)
    return out


def quantize(cells, n):
    colors = [p[:3] for c in cells for p in c.get_flattened_data() if p[3] and p[:3] != OUTLINE[:3]]
    pal = palette_of(colors, n - 1) + [OUTLINE[:3]]
    cache = {}
    out = []
    for c in cells:
        c = c.copy()
        px = c.load()
        for y in range(c.height):
            for x in range(c.width):
                p = px[x, y]
                if p[3]:
                    if p[:3] not in cache:
                        cache[p[:3]] = nearest(pal, p[:3])
                    px[x, y] = cache[p[:3]] + (255,)
        out.append(drop_orphans(c))
    return out


def build(root, job):
    img = key(Image.open(os.path.join(root, "art-src/gen/r2", job["src"])))
    for box in job["mask"]:
        img.paste((0, 0, 0, 0), box)
    if job["bright"] != 1.0 or job["contrast"] != 1.0:
        alpha = img.getchannel("A")
        img = ImageEnhance.Contrast(ImageEnhance.Brightness(img).enhance(job["bright"])).enhance(job["contrast"])
        img.putalpha(alpha)
    if job.get("cool_greens"):
        img = cool(img)
    poses, centres = slots(img)
    target, axis = job["size"]
    idle = [poses[(c, 0)].getbbox() for c in range(COLS) if (c, 0) in poses]
    measure = statistics.median((b[2] - b[0]) if axis == "w" else (b[3] - b[1]) for b in idle)
    s = target / measure
    n, ground = job["cell"], job["ground"]
    cells = []
    for r in range(ROWS):
        row_ground = max(poses[(c, r)].getbbox()[3] for c in range(COLS) if (c, r) in poses)
        for c in range(COLS):
            cell = Image.new("RGBA", (n, n), (0, 0, 0, 0))
            if (c, r) in poses:
                bx0, by0, bx1, by1 = poses[(c, r)].getbbox()
                small = shrink(poses[(c, r)].crop((bx0, by0, bx1, by1)), s)
                ox = round(n / 2 + (bx0 - centres[(c, r)]) * s)
                oy = round(ground + 1 - (row_ground - by0) * s)
                cell.alpha_composite(small, (max(ox, 0), max(oy, 0)), (max(-ox, 0), max(-oy, 0)))
            cells.append(finish(cell, job["rim"]))
    return quantize(cells, job["colors"])


def main():
    root, force = parse_args([a for a in sys.argv if a in sys.argv[:2] or a == "--force"])
    names = [a for a in sys.argv[2:] if a != "--force"] or list(JOBS)
    for name in names:
        job = JOBS[name]
        n = job["cell"]
        cells = build(root, job)
        sheet = Image.new("RGBA", (n * COLS, n * ROWS), (0, 0, 0, 0))
        for k, c in enumerate(cells):
            sheet.alpha_composite(c, ((k % COLS) * n, (k // COLS) * n))
        save_guarded(sheet, os.path.join(root, "game/assets/enemies", name + ".png"), force)


if __name__ == "__main__":
    main()
