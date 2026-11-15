"""Shared helpers for the art pipeline (Pillow). Run scripts with python3 -I."""
import os

from PIL import Image

OUTLINE = (24, 16, 20, 255)


def magenta_level(r, g, b):
    return min(r, b) - g


def key_magenta(img):
    """Flat magenta background -> transparent. Fringe pixels (outline blended
    with magenta) become the outline colour so edges stay dark."""
    img = img.convert("RGBA")
    px = img.load()
    w, h = img.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            m = magenta_level(r, g, b)
            if m > 110:
                px[x, y] = (0, 0, 0, 0)
            elif m > 45 and r > 70 and b > 70:
                px[x, y] = OUTLINE
    return img


def bands(counts, min_gap, min_len=8):
    """Runs of non-zero counts, merging gaps shorter than min_gap."""
    runs = []
    start = None
    gap = 0
    for i, c in enumerate(counts):
        if c:
            if start is None:
                start = i
            gap = 0
            end = i
        elif start is not None:
            gap += 1
            if gap >= min_gap:
                runs.append((start, end))
                start = None
    if start is not None:
        runs.append((start, end))
    return [r for r in runs if r[1] - r[0] >= min_len]


def frames(img, min_gap=24):
    """Split a keyed sheet into rows of frame boxes (x0, y0, x1, y1)."""
    w, h = img.size
    a = img.getchannel("A").load()
    rows = bands([sum(1 for x in range(w) if a[x, y]) for y in range(h)], min_gap)
    out = []
    for y0, y1 in rows:
        cols = bands([sum(1 for y in range(y0, y1 + 1) if a[x, y]) for x in range(w)], min_gap)
        boxes = []
        for x0, x1 in cols:
            ys = [y for y in range(y0, y1 + 1) if any(a[x, y] for x in range(x0, x1 + 1))]
            boxes.append((x0, ys[0], x1 + 1, ys[-1] + 1))
        out.append(boxes)
    return out


def is_green(c):
    r, g, b = c[:3]
    return g >= r - 3 and g > b + 10 and g > 30


def is_steel(c):
    r, g, b = c[:3]
    spread = max(r, g, b) - min(r, g, b)
    avg = (r + g + b) / 3
    return (spread < 28 and avg > 120) or (spread < 52 and avg > 175)


def parse_args(argv):
    """<repo_root> [--force] -> (root, force)."""
    force = "--force" in argv
    rest = [a for a in argv[1:] if a != "--force"]
    return rest[0], force


def save_guarded(img, path, force):
    """Never replace an existing file (it may be hand-drawn art) without
    --force."""
    if os.path.exists(path) and not force:
        print("skip %s (exists, may be hand-drawn; pass --force to overwrite)" % path)
        return False
    img.save(path)
    print("wrote %s" % path)
    return True


def count_colors(img):
    return len({c for c in img.getdata() if c[3]})


def upscale(img, k):
    return img.resize((img.width * k, img.height * k), Image.NEAREST)


def lum(c):
    return 0.3 * c[0] + 0.59 * c[1] + 0.11 * c[2]


def icon_pixels(path, select=None, dark=36):
    """Opaque colours of an item icon (16x16), skipping the outline (lum
    below `dark`). `select(x, y, c)` keeps only part of the icon."""
    img = Image.open(path).convert("RGBA")
    px = img.load()
    out = []
    for y in range(img.height):
        for x in range(img.width):
            c = px[x, y]
            if c[3] and lum(c) >= dark and (select is None or select(x, y, c[:3])):
                out.append(c[:3])
    return out


def kmeans(pixels, k, iters=30):
    """[(colour, share of the pixels)] of k clusters (k-means on RGB, seeded
    at brightness quantiles, so the result is deterministic), dark -> light."""
    pts = sorted(pixels, key=lum)
    k = max(1, min(k, len(set(pts))))
    cent = [pts[min(len(pts) - 1, int((i + 0.5) * len(pts) / k))] for i in range(k)]
    cent = [tuple(float(v) for v in c) for c in cent]
    groups = []
    for _ in range(iters):
        groups = [[] for _ in cent]
        for p in pts:
            j = min(range(len(cent)), key=lambda i: sum((p[t] - cent[i][t]) ** 2 for t in range(3)))
            groups[j].append(p)
        new = [tuple(sum(p[t] for p in g) / len(g) for t in range(3)) if g else cent[i]
               for i, g in enumerate(groups)]
        if new == cent:
            break
        cent = new
    out = [(tuple(round(v) for v in c), len(g) / len(pts)) for c, g in zip(cent, groups) if g]
    return sorted(out, key=lambda e: lum(e[0]))


def kmeans_ramp(pixels, k):
    return [c for c, _ in kmeans(pixels, k)]


def icon_ramp(path, k, select=None, dark=36):
    """Ramp dark -> light sampled from an item icon (see kmeans)."""
    return kmeans_ramp(icon_pixels(path, select, dark), k)


def icon_ramp_shares(path, k, select=None, dark=36):
    """(ramp, share of the icon's pixels per ramp colour)."""
    km = kmeans(icon_pixels(path, select, dark), k)
    return [c for c, _ in km], [s for _, s in km]


def quantile_index(counts, shares):
    """{colour: ramp index}: histogram matching. The source colours (pixel
    counts) sorted by brightness take the ramp entry found at the same
    pixel quantile of the target (`shares` per ramp entry), so a sprite
    keeps the icon's mix of dark, mid and light tones."""
    cols = sorted(counts, key=lum)
    total = sum(counts.values()) or 1
    out = {}
    acc = 0
    for c in cols:
        q = (acc + counts[c] / 2) / total
        acc += counts[c]
        cum = 0.0
        j = len(shares) - 1
        for i, s in enumerate(shares):
            cum += s
            if q <= cum:
                j = i
                break
        out[c] = j
    return out


def colour_counts(imgs, key=None):
    """{group: {colour: pixel count}} over the opaque pixels of `imgs`;
    key(colour) -> group name or None (skipped). key=None: one group ""."""
    out = {}
    for img in imgs:
        for p in img.get_flattened_data():
            if p[3]:
                k = key(p) if key else ""
                if k:
                    d = out.setdefault(k, {})
                    d[p[:3]] = d.get(p[:3], 0) + 1
                elif key is None:
                    d = out.setdefault("", {})
                    d[p[:3]] = d.get(p[:3], 0) + 1
    return out