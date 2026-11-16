"""Draw the colour layout guide used to generate the town ground.

python3 -I art-src/town_ground_guide.py <repo_root>
Writes art-src/gen/town-ground-guide.png (1920x1080, 4x the 480x270 screen).
Grey = cobblestone plaza, light ring = carved stone ring around the crystal,
brown = dirt path, green = grass. The guide went to edit_image together with
the town key art (see docs/assets.md).
"""
import os
import sys

from PIL import Image, ImageDraw

S = 4
COBBLE = (150, 150, 150)
RING = (200, 195, 180)
DIRT = (170, 130, 80)
GRASS = (70, 140, 60)
GRASS_LIGHT = (90, 170, 70)


def main(root):
    im = Image.new("RGB", (480 * S, 270 * S), GRASS)
    d = ImageDraw.Draw(im)

    def rect(box, c, rad=0):
        x0, y0, x1, y1 = [v * S for v in box]
        if rad:
            d.rounded_rectangle((x0, y0, x1, y1), rad * S, fill=c)
        else:
            d.rectangle((x0, y0, x1, y1), fill=c)

    def ellipse(cx, cy, rx, ry, c):
        d.ellipse(((cx - rx) * S, (cy - ry) * S, (cx + rx) * S, (cy + ry) * S), fill=c)

    rect((6, 78, 474, 240), COBBLE, 26)
    rect((218, 0, 262, 90), COBBLE)
    rect((220, 232, 260, 270), DIRT)
    rect((8, 70, 120, 116), COBBLE)
    rect((360, 70, 472, 116), COBBLE)
    ellipse(240, 156, 46, 26, RING)
    ellipse(240, 156, 30, 17, COBBLE)
    for x, y in [(30, 252), (450, 252), (150, 20), (330, 20), (18, 150)]:
        ellipse(x, y, 10, 6, GRASS_LIGHT)
    out = os.path.join(root, "art-src", "gen", "town-ground-guide.png")
    im.save(out)
    print("wrote %s" % out)


if __name__ == "__main__":
    main(sys.argv[1])
