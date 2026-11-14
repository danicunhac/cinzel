"""Build the room decor strip placed by game/tools/build_rooms.gd.

python3 -I art-src/build_decor.py <repo_root> [--force]

Input (see docs/assets.md): art-src/gen/decor-sheet.png, 4x3
props on magenta. Output: game/assets/rooms/decor.png, 12 frames of 32x32 in
one row (order = NAMES), each prop bottom-centred on the frame's last row,
transparent, <= 64 colours for the whole strip, binary alpha.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from PIL import Image  # noqa: E402

from artlib import count_colors, key_magenta, parse_args, save_guarded  # noqa: E402

SRC = "art-src/gen/decor-sheet.png"
OUT = "game/assets/rooms/decor.png"
CELL = 32
COLORS = 64
# Sheet order (4 columns x 3 rows) and the size each prop is reduced to
# (largest side fits this box, aspect kept).
NAMES = [
    ("barrel", (18, 22)), ("crate", (20, 25)), ("bones", (21, 14)), ("skulls", (19, 13)),
    ("pot", (18, 15)), ("candles", (15, 18)), ("chains", (15, 25)), ("rubble", (23, 17)),
    ("moss", (21, 14)), ("banner", (16, 28)), ("rack", (23, 26)), ("cobweb", (24, 28)),
]


def main(argv):
    root, force = parse_args(argv)
    src = key_magenta(Image.open(os.path.join(root, SRC)))
    cw, ch = src.width // 4, src.height // 3
    strip = Image.new("RGBA", (CELL * len(NAMES), CELL), (0, 0, 0, 0))
    for i, (name, box) in enumerate(NAMES):
        cell = src.crop(((i % 4) * cw, (i // 4) * ch, (i % 4 + 1) * cw, (i // 4 + 1) * ch))
        cell = cell.crop(cell.getbbox())
        k = min(box[0] / cell.width, box[1] / cell.height)
        size = (max(1, round(cell.width * k)), max(1, round(cell.height * k)))
        small = cell.resize(size, Image.BOX)
        strip.paste(small, (i * CELL + (CELL - size[0]) // 2, CELL - size[1]), small)
        print("%-8s %s" % (name, size))
    alpha = strip.getchannel("A").point(lambda v: 255 if v >= 110 else 0)
    q = strip.quantize(colors=COLORS, method=Image.Quantize.FASTOCTREE, kmeans=4, dither=Image.Dither.NONE)
    out = q.convert("RGBA")
    out.putalpha(alpha)
    px = out.load()
    for y in range(out.height):
        for x in range(out.width):
            if px[x, y][3] == 0:
                px[x, y] = (0, 0, 0, 0)
    print("colours:", count_colors(out))
    save_guarded(out, os.path.join(root, OUT), force)


if __name__ == "__main__":
    main(sys.argv)
