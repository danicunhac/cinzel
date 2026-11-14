"""Build the stairs-down prop shown in the first room of each floor.

python3 -I art-src/build_stairs.py <repo_root> [--force]

Input (see docs/assets.md): art-src/gen/r2/stairs-down-1.png
on magenta. Output: game/assets/rooms/stairs_down.png, 28x32, transparent,
<= 32 colours, binary alpha.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from PIL import Image  # noqa: E402

from artlib import count_colors, key_magenta, parse_args, save_guarded  # noqa: E402

SRC = "art-src/gen/r2/stairs-down-1.png"
OUT = "game/assets/rooms/stairs_down.png"
SIZE = (28, 32)
COLORS = 32


def main(argv):
    root, force = parse_args(argv)
    src = key_magenta(Image.open(os.path.join(root, SRC)))
    src = src.crop(src.getbbox())
    small = src.resize(SIZE, Image.BOX)
    alpha = small.getchannel("A").point(lambda v: 255 if v >= 110 else 0)
    q = small.convert("RGB").quantize(colors=COLORS, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
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
