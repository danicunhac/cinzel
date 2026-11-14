"""Helpers for generated animation strips (one row of N poses on magenta).

Used by build_climber.py, build_enemies.py and build_boss.py.
"""
from PIL import Image

from artlib import OUTLINE, magenta_level

ARC = (239, 225, 205, 255)


def key(img):
    """Magenta -> transparent. Fringe pixels become the outline colour, except
    light pink ones (a fading slash arc blended with magenta), which become
    the arc colour."""
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
                px[x, y] = ARC if g > 110 else OUTLINE
    return img


def runs(counts):
    out = []
    start = None
    for i, c in enumerate(counts):
        if c and start is None:
            start = i
        elif not c and start is not None:
            out.append([start, i])
            start = None
    if start is not None:
        out.append([start, len(counts)])
    return out


def split(img, n, min_px=12):
    """Cut a keyed strip into exactly n boxes (x0, y0, x1, y1): column runs of
    opaque pixels, specks dropped, then the closest neighbours merged until n
    remain (a detached slash arc or a dropped sword joins its pose)."""
    w, h = img.size
    a = img.getchannel("A").load()
    cols = [sum(1 for y in range(h) if a[x, y]) for x in range(w)]
    rs = [r for r in runs(cols) if sum(cols[r[0]:r[1]]) >= min_px]
    while len(rs) > n:
        gaps = [rs[i + 1][0] - rs[i][1] for i in range(len(rs) - 1)]
        i = gaps.index(min(gaps))
        rs[i] = [rs[i][0], rs[i + 1][1]]
        del rs[i + 1]
    assert len(rs) == n, "found %d poses, want %d" % (len(rs), n)
    boxes = []
    for x0, x1 in rs:
        ys = [y for y in range(h) if any(a[x, y] for x in range(x0, x1))]
        boxes.append((x0, ys[0], x1, ys[-1] + 1))
    return boxes


def load_strip(path, n):
    img = key(Image.open(path))
    return img, split(img, n)


def threshold(img, cut=110):
    img.putalpha(img.getchannel("A").point(lambda v: 255 if v >= cut else 0))
    return img


def shrink(crop, s, keep_thin=None):
    """Box-downscale by s and threshold alpha. keep_thin(rgb) marks thin
    light strokes (the slash arc) kept from a lower alpha so they do not
    break up."""
    w, h = max(1, round(crop.width * s)), max(1, round(crop.height * s))
    small = crop.resize((w, h), Image.BOX)  # Pillow resizes RGBA premultiplied
    if keep_thin is None:
        return threshold(small)
    px = small.load()
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if 40 <= a < 110 and keep_thin((r, g, b)):
                px[x, y] = (r, g, b, 255)
    return threshold(small)


def palette_of(colors, n):
    sample = Image.new("RGB", (len(colors), 1))
    sample.putdata(colors)
    q = sample.quantize(colors=n, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
    pal = q.getpalette()[: n * 3]
    return [tuple(pal[i:i + 3]) for i in range(0, len(pal), 3)]


def nearest(palette, p):
    return min(palette, key=lambda k: sum((k[i] - p[i]) ** 2 for i in range(3)))


def outline(cell, keep=lambda c: False):
    """Repaint silhouette edge pixels with the outline colour (box
    downscaling washes the 1 px outline out). keep(c) protects a pixel."""
    w, h = cell.size
    out = cell.copy()
    a = cell.getchannel("A").load()
    dst = out.load()
    for y in range(h):
        for x in range(w):
            if not a[x, y] or keep(dst[x, y]):
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if not (0 <= nx < w and 0 <= ny < h) or not a[nx, ny]:
                    dst[x, y] = OUTLINE
                    break
    return out


def drop_orphans(cell, min_n=1):
    """Clear opaque pixels with fewer than min_n opaque 4-neighbours."""
    w, h = cell.size
    a = cell.getchannel("A").load()
    out = cell.copy()
    px = out.load()
    for y in range(h):
        for x in range(w):
            if a[x, y]:
                n = sum(1 for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))
                        if 0 <= x + dx < w and 0 <= y + dy < h and a[x + dx, y + dy])
                if n < min_n:
                    px[x, y] = (0, 0, 0, 0)
    return out
