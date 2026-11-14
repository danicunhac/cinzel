"""Painted dungeon rooms: blockouts for the AI paint pass, then the 480x270
backgrounds the game shows (game/assets/rooms/<room id>.png).

python3 -I art-src/build_rooms_art.py <repo_root> blockout
python3 -I art-src/build_rooms_art.py <repo_root> score <room_id> <painted.png> [...]
python3 -I art-src/build_rooms_art.py <repo_root> overlay <room_id> <painted.png> <out.png>
python3 -I art-src/build_rooms_art.py <repo_root> final [--force] [room_id ...]
python3 -I art-src/build_rooms_art.py <repo_root> doors [--force]
Needs Pillow and numpy.

Inputs:
  art-src/gen/rooms/layouts.json  dumped by game/tools/build_rooms.gd (run it
    first): rows (30 x 16 cells of 16 px), floor, torch cells, sign rect.
  art-src/gen/rooms/<room_id>.png  chosen painting (AI generator edit of the
    blockout + tower key art, see docs/assets.md).
  art-src/gen/rooms/doors-sheet.png  door props on magenta, 3 columns (shut,
    locked, open) x 2 rows (front, side).
Outputs:
  art-src/gen/rooms/blockout/<room_id>.png (480x270) and <room_id>@4x.png
    (1920x1080, the one uploaded as the edit source).
  art-src/gen/rooms/align/<room_id>.png  painting x2 with the collision cells
    outlined, for eyeballing; scores in art-src/gen/rooms/align/scores.json.
  game/assets/rooms/<room_id>.png  480x270, 1 art pixel = 1 game pixel,
    at most 48 colours, no dithering.
  game/assets/rooms/doors.png  3x2 frames of 24x32.

Alignment score: each pixel of the painting is classed as "blocking" or
"floor" by its nearest class mean (colour + local contrast, means taken from
the layout); mismatch = share of pixels in the room area (y < 256) whose class
disagrees with the layout. The best shift (-8..8 px) tells how far the walls
drifted; `final` moves the painting by the shared part of the floor edges'
drift (see edge_shift), which is steadier than that best shift.
drift = worst gap (px) between the painted floor's top / bottom / left / right
edge and the layout's; obstacles = share of pillar, crate and inner wall cells
(lower half) that read as solid. Tall 3/4 pillars and wall faces drawn above
their cells raise the mismatch without being wrong, so pick on drift first.
"""
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import numpy as np  # noqa: E402
from PIL import Image, ImageDraw, ImageFilter  # noqa: E402

from artlib import key_magenta, save_guarded  # noqa: E402

W, H, T = 30, 16, 16
OUT_W, OUT_H = 480, 270
ROOM_H = H * T
COLORS = 48
MAX_SHIFT = 8

FLOOR_RGB = {1: (150, 126, 96), 2: (112, 124, 140), 3: (66, 54, 60)}
CRACK = (0.82, 0.82, 0.82)
MOSS = (88, 118, 64)
WALL_TOP = (26, 22, 32)
WALL_FACE = (92, 80, 76)
PILLAR = (196, 186, 166)
PILLAR_EDGE = (60, 52, 50)
CRATE = (150, 88, 38)
CRATE_EDGE = (70, 40, 20)
DOOR_ENTRY = (40, 70, 160)
DOOR_EXIT = (190, 40, 40)
TORCH = (255, 176, 40)
SIGN = (72, 46, 30)

DOOR_FRAME = (24, 32)


def load_layouts(root):
    with open(os.path.join(root, "art-src/gen/rooms/layouts.json")) as f:
        return json.load(f)


def cell(rows, x, y):
    if x < 0 or y < 0 or x >= W or y >= H:
        return "#"
    return rows[y][x]


def blocking_mask(room):
    """True where collision blocks (walls, pillars, crates, doors), 480x270."""
    m = np.zeros((OUT_H, OUT_W), dtype=bool)
    rows = room["rows"]
    for y in range(H):
        for x in range(W):
            if rows[y][x] in "#oxEX":
                m[y * T:(y + 1) * T, x * T:(x + 1) * T] = True
    m[ROOM_H:, :] = True
    return m


def blockout(room):
    rows = room["rows"]
    floor = FLOOR_RGB[room["floor"]]
    img = Image.new("RGB", (OUT_W, OUT_H), WALL_TOP)
    d = ImageDraw.Draw(img)
    for y in range(H):
        for x in range(W):
            ch = rows[y][x]
            x0, y0 = x * T, y * T
            box = (x0, y0, x0 + T - 1, y0 + T - 1)
            if ch == "#":
                below_open = y + 1 < H and cell(rows, x, y + 1) not in "#EX"
                d.rectangle(box, fill=WALL_FACE if below_open else WALL_TOP)
                continue
            if ch == "E":
                d.rectangle(box, fill=DOOR_ENTRY)
                continue
            if ch == "X":
                d.rectangle(box, fill=DOOR_EXIT)
                continue
            col = floor
            if ch == ",":
                col = tuple(int(c * k) for c, k in zip(floor, CRACK))
            elif ch == "~":
                col = MOSS
            d.rectangle(box, fill=col)
            if ch == "o":
                d.ellipse((x0 + 1, y0 + 1, x0 + 14, y0 + 14), fill=PILLAR, outline=PILLAR_EDGE)
            elif ch == "x":
                d.rectangle((x0 + 1, y0 + 1, x0 + 14, y0 + 14), fill=CRATE, outline=CRATE_EDGE)
    for tx, ty in room["torches"]:
        x0, y0 = tx * T, ty * T
        d.rectangle((x0 + 5, y0 + 3, x0 + 10, y0 + 12), fill=TORCH)
    if room.get("sign"):
        sx, sy, sw, sh = room["sign"]
        d.rectangle((sx, sy, sx + sw - 1, sy + sh - 1), fill=SIGN)
    return img


def features(img):
    """Per-pixel colour (blurred) + local luminance contrast, float array."""
    rgb = img.convert("RGB")
    blur = np.asarray(rgb.filter(ImageFilter.BoxBlur(2)), dtype=np.float32)
    lum = np.asarray(rgb.convert("L"), dtype=np.float32)
    lum_img = Image.fromarray(lum.astype(np.uint8))
    mean = np.asarray(lum_img.filter(ImageFilter.BoxBlur(3)), dtype=np.float32)
    sq = Image.fromarray(np.clip(lum * lum / 255.0, 0, 255).astype(np.uint8))
    mean_sq = np.asarray(sq.filter(ImageFilter.BoxBlur(3)), dtype=np.float32) * 255.0
    std = np.sqrt(np.clip(mean_sq - mean * mean, 0, None))
    return np.concatenate([blur, std[..., None] * 1.5], axis=2)


def erode(m, k):
    out = m.copy()
    for dy in range(-k, k + 1):
        for dx in range(-k, k + 1):
            out &= np.roll(np.roll(m, dy, 0), dx, 1)
    return out


def classify(img, mask):
    """Predicted blocking map from class means learnt on the layout."""
    f = features(img)
    room = np.zeros_like(mask)
    room[:ROOM_H, :] = True
    core_b = erode(mask, 3) & room
    core_f = erode(~mask, 3) & room
    mb = f[core_b].mean(axis=0)
    mf = f[core_f].mean(axis=0)
    db = ((f - mb) ** 2).sum(axis=2)
    df = ((f - mf) ** 2).sum(axis=2)
    return db < df


def mismatch(pred, mask, dx=0, dy=0):
    """Disagreement in the room area when the painting is moved by (dx, dy)."""
    shifted = np.roll(np.roll(pred, dy, 0), dx, 1)
    m = MAX_SHIFT
    a = shifted[m:ROOM_H - m, m:OUT_W - m]
    b = mask[m:ROOM_H - m, m:OUT_W - m]
    return float((a != b).mean())


def floor_edges(blocking):
    """Top, bottom, left, right edge of the open floor: first/last row and
    column whose middle stretch is mostly floor."""
    free = ~blocking
    rows = free[:ROOM_H, 3 * T:OUT_W - 3 * T].mean(axis=1)
    cols = free[3 * T:ROOM_H - 3 * T, :].mean(axis=0)
    ys = np.nonzero(rows > 0.5)[0]
    xs = np.nonzero(cols > 0.5)[0]
    return [int(ys[0]), int(ys[-1]) + 1, int(xs[0]), int(xs[-1]) + 1]


def obstacle_cover(pred, room):
    """Share of interior obstacle cells (pillars, crates, inner walls) whose
    lower half reads as blocking in the painting."""
    rows = room["rows"]
    hit = total = 0
    for y in range(1, H - 1):
        for x in range(1, W - 1):
            if rows[y][x] in "#ox":
                part = pred[y * T + T // 2:(y + 1) * T, x * T + 2:(x + 1) * T - 2]
                hit += part.mean()
                total += 1
    return round(hit / total, 3) if total else 1.0


def score(img, room):
    mask = blocking_mask(room)
    pred = classify(img, mask)
    base = mismatch(pred, mask)
    best = (base, 0, 0)
    for dy in range(-MAX_SHIFT, MAX_SHIFT + 1):
        for dx in range(-MAX_SHIFT, MAX_SHIFT + 1):
            v = mismatch(pred, mask, dx, dy)
            if v < best[0] - 1e-9:
                best = (v, dx, dy)
    want = floor_edges(mask)
    got = floor_edges(pred)
    return {"mismatch": round(base, 4), "best": round(best[0], 4), "shift": [best[1], best[2]],
            "edges": got, "edges_want": want,
            "drift": max(abs(a - b) for a, b in zip(got, want)),
            "obstacles": obstacle_cover(pred, room)}


def edge_shift(got, want):
    """Translation that brings the painted floor rectangle onto the layout's:
    per axis, only when both edges moved the same way, by the smaller move."""
    out = []
    for a, b in ((0, 1), (2, 3)):
        da, db = want[a] - got[a], want[b] - got[b]
        if da * db > 0:
            m = min(abs(da), abs(db), MAX_SHIFT)
            out.append(m if da > 0 else -m)
        else:
            out.append(0)
    return out[1], out[0]


def to_grid(src):
    """Crop to 16:9 and area-downscale to 480x270."""
    src = src.convert("RGB")
    w, h = src.size
    want = w * OUT_H / OUT_W
    if abs(h - want) > 1:
        if h > want:
            top = int((h - want) / 2)
            src = src.crop((0, top, w, top + int(want)))
        else:
            nw = int(h * OUT_W / OUT_H)
            left = (w - nw) // 2
            src = src.crop((left, 0, left + nw, h))
    return src.resize((OUT_W, OUT_H), Image.BOX)


def shift_img(img, dx, dy):
    a = np.asarray(img)
    a = np.roll(np.roll(a, dy, 0), dx, 1)
    # Clamp the wrapped edge to the nearest real row / column.
    if dy > 0:
        a[:dy] = a[dy]
    elif dy < 0:
        a[dy:] = a[dy - 1]
    if dx > 0:
        a[:, :dx] = a[:, dx:dx + 1]
    elif dx < 0:
        a[:, dx:] = a[:, dx - 1:dx]
    return Image.fromarray(a)


def quantize(img, colors=COLORS):
    return img.quantize(colors=colors, method=Image.Quantize.MEDIANCUT,
                        dither=Image.Dither.NONE).convert("RGB")


def overlay(img, room):
    big = img.resize((OUT_W * 2, OUT_H * 2), Image.NEAREST).convert("RGBA")
    layer = Image.new("RGBA", big.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    rows = room["rows"]
    for y in range(H):
        for x in range(W):
            ch = rows[y][x]
            if ch not in "#oxEX":
                continue
            # Outline only the blocking cells that touch open floor.
            near_floor = any(cell(rows, x + dx, y + dy) not in "#oxEX"
                             for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))
            if ch == "#" and not near_floor:
                continue
            colour = {"o": (0, 255, 255, 230), "x": (255, 0, 255, 230),
                      "E": (60, 120, 255, 230), "X": (255, 60, 60, 230)}.get(ch, (0, 255, 0, 160))
            d.rectangle((x * 32, y * 32, x * 32 + 31, y * 32 + 31), outline=colour)
    return Image.alpha_composite(big, layer)


def cmd_blockout(root, rooms):
    out = os.path.join(root, "art-src/gen/rooms/blockout")
    os.makedirs(out, exist_ok=True)
    for rid, room in rooms.items():
        img = blockout(room)
        img.save(os.path.join(out, rid + ".png"))
        img.resize((OUT_W * 4, OUT_H * 4), Image.NEAREST).save(os.path.join(out, rid + "@4x.png"))
        print("blockout", rid)


def cmd_score(root, rooms, rid, paths):
    for p in paths:
        img = to_grid(Image.open(p))
        print(rid, os.path.basename(p), json.dumps(score(img, rooms[rid])))


def cmd_final(root, rooms, ids, force):
    src_dir = os.path.join(root, "art-src/gen/rooms")
    align_dir = os.path.join(src_dir, "align")
    out_dir = os.path.join(root, "game/assets/rooms")
    os.makedirs(align_dir, exist_ok=True)
    os.makedirs(out_dir, exist_ok=True)
    scores_path = os.path.join(align_dir, "scores.json")
    scores = {}
    if os.path.exists(scores_path):
        with open(scores_path) as f:
            scores = json.load(f)
    for rid in ids or sorted(rooms):
        src = os.path.join(src_dir, rid + ".png")
        if not os.path.exists(src):
            print("no painting for", rid)
            continue
        room = rooms[rid]
        img = to_grid(Image.open(src))
        s = score(img, room)
        dx, dy = edge_shift(s["edges"], s["edges_want"])
        # Move the painting back when both opposite floor edges drifted the
        # same way (a translation, not walls drawn thicker).
        if dx or dy:
            img = shift_img(img, dx, dy)
            s["applied_shift"] = [dx, dy]
            s["edges_after"] = score(img, room)["edges"]
        img = quantize(img)
        s["after"] = score(img, room)["mismatch"]
        s["colors"] = len(img.getcolors(1 << 16))
        scores[rid] = s
        print(rid, json.dumps(s))
        overlay(img, room).save(os.path.join(align_dir, rid + ".png"))
        save_guarded(img, os.path.join(out_dir, rid + ".png"), force)
    with open(scores_path, "w") as f:
        json.dump(scores, f, indent=1, sort_keys=True)


def content_box(img):
    a = np.asarray(img.getchannel("A")) > 0
    ys, xs = np.nonzero(a)
    return xs.min(), ys.min(), xs.max() + 1, ys.max() + 1


def cmd_doors(root, force):
    src = Image.open(os.path.join(root, "art-src/gen/rooms/doors-sheet.png"))
    keyed = key_magenta(src)
    w, h = keyed.size
    fw, fh = DOOR_FRAME
    sheet = Image.new("RGBA", (fw * 3, fh * 2), (0, 0, 0, 0))
    for row in range(2):
        for col in range(3):
            cell_img = keyed.crop((col * w // 3, row * h // 2, (col + 1) * w // 3, (row + 1) * h // 2))
            box = content_box(cell_img)
            part = cell_img.crop(box)
            # Fit the frame keeping the aspect, bottom-centred.
            k = min(fw / part.width, fh / part.height)
            nw, nh = max(1, round(part.width * k)), max(1, round(part.height * k))
            part = part.resize((nw, nh), Image.BOX)
            alpha = part.getchannel("A").point(lambda v: 255 if v >= 128 else 0)
            rgb = quantize(part.convert("RGB"), 16)
            part = rgb.convert("RGBA")
            part.putalpha(alpha)
            sheet.paste(part, (col * fw + (fw - nw) // 2, row * fh + fh - nh), part)
    out_dir = os.path.join(root, "game/assets/rooms")
    os.makedirs(out_dir, exist_ok=True)
    save_guarded(sheet, os.path.join(out_dir, "doors.png"), force)


def main():
    argv = sys.argv[1:]
    force = "--force" in argv
    argv = [a for a in argv if a != "--force"]
    root, cmd, rest = argv[0], argv[1], argv[2:]
    rooms = load_layouts(root)
    if cmd == "blockout":
        cmd_blockout(root, rooms)
    elif cmd == "score":
        cmd_score(root, rooms, rest[0], rest[1:])
    elif cmd == "overlay":
        overlay(quantize(to_grid(Image.open(rest[1]))), rooms[rest[0]]).save(rest[2])
    elif cmd == "final":
        cmd_final(root, rooms, rest, force)
    elif cmd == "doors":
        cmd_doors(root, force)
    else:
        sys.exit("unknown command " + cmd)


if __name__ == "__main__":
    main()
