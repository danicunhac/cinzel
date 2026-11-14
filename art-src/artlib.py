"""Shared helpers for the art pipeline (Pillow). Run scripts with python3 -I."""
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


def count_colors(img):
    return len({c for c in img.getdata() if c[3]})


def upscale(img, k):
    return img.resize((img.width * k, img.height * k), Image.NEAREST)
