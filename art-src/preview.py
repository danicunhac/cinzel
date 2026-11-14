"""4x previews of the shipped sheets: one PNG per sheet (on the dark floor
colour) and one animated GIF per animation row.

python3 -I art-src/preview.py <repo_root> <out_dir> [prefix]
"""
import os
import sys

from PIL import Image

K = 4
FLOOR = (38, 34, 40, 255)
CLIMBER_ROWS = [
    ("idle_down", 4, 6), ("idle_up", 4, 6), ("idle_side", 4, 6),
    ("walk_down", 8, 12), ("walk_up", 8, 12), ("walk_side", 8, 12),
    ("attack_down", 6, 16), ("attack_up", 6, 16), ("attack_side", 6, 16),
    ("roll_down", 6, 14), ("roll_up", 6, 14), ("roll_side", 6, 14),
    ("death", 6, 8),
]
ENEMY_ROWS = [("idle", 6, 8), ("move", 6, 10), ("attack", 6, 10), ("death", 6, 8)]


def on_floor(img):
    bg = Image.new("RGBA", img.size, FLOOR)
    bg.alpha_composite(img)
    return bg.resize((img.width * K, img.height * K), Image.NEAREST)


def gif(cells, fps, path):
    frames = [on_floor(c).convert("P", palette=Image.Palette.ADAPTIVE, colors=255) for c in cells]
    frames[0].save(path, save_all=True, append_images=frames[1:], duration=round(1000 / fps), loop=0, disposal=2)


def sheet_rows(sheet, cell, rows):
    for r, (name, n, fps) in enumerate(rows):
        yield name, [sheet.crop((i * cell, r * cell, i * cell + cell, r * cell + cell)) for i in range(n)], fps


def main():
    root, out = sys.argv[1], sys.argv[2]
    prefix = sys.argv[3] if len(sys.argv) > 3 else "taskR2"
    os.makedirs(out, exist_ok=True)
    climber = os.path.join(root, "art-src/climber-reference.png")
    sheet = Image.open(climber).convert("RGBA")
    on_floor(sheet).save(os.path.join(out, "%s-climber-sheet.png" % prefix))
    for name, cells, fps in sheet_rows(sheet, 32, CLIMBER_ROWS):
        gif(cells, fps, os.path.join(out, "%s-climber-%s.gif" % (prefix, name)))
    enemies = Image.new("RGBA", (144 * 3 + 288 + 30, 192), (0, 0, 0, 0))
    x = 0
    for name, cell in (("crawler", 24), ("shooter", 24), ("charger", 24), ("boss_final", 48)):
        sheet = Image.open(os.path.join(root, "game/assets/enemies", name + ".png")).convert("RGBA")
        enemies.alpha_composite(sheet, (x, 0))
        x += sheet.width + 10
        for row, cells, fps in sheet_rows(sheet, cell, ENEMY_ROWS):
            gif(cells, fps, os.path.join(out, "%s-%s-%s.gif" % (prefix, name, row)))
    on_floor(enemies).save(os.path.join(out, "%s-enemies-sheet.png" % prefix))


if __name__ == "__main__":
    main()
