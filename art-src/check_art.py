"""Check the shipped sheets: size, transparency, colour count.

python3 -I art-src/check_art.py <repo_root>
"""
import os
import sys

from PIL import Image

SHEETS = {
    "game/assets/characters/climber/body.png": (96, 312, 24),
    "game/assets/characters/climber/hair.png": (96, 312, 24),
    "game/assets/characters/climber/outfit.png": (96, 312, 24),
    "game/assets/characters/climber/weapon.png": (96, 312, 24),
    "game/assets/enemies/crawler.png": (64, 64, 16),
    "game/assets/enemies/shooter.png": (64, 64, 16),
    "game/assets/enemies/charger.png": (64, 64, 16),
    "game/assets/enemies/boss_final.png": (128, 128, 32),
    "game/assets/tiles/floor1.png": (128, 32, 16),
    "game/assets/tiles/floor2.png": (128, 32, 16),
    "game/assets/tiles/floor3.png": (128, 32, 16),
    "game/assets/tiles/town.png": (128, 32, 16),
    "game/assets/characters/npc_shopkeeper.png": (48, 24, 24),
    "game/assets/characters/npc_blacksmith.png": (48, 24, 24),
    "game/assets/items/heavy_blade.png": (16, 16, 16),
    "game/assets/items/light_boots.png": (16, 16, 16),
    "game/assets/items/stone_heart.png": (16, 16, 16),
    "game/assets/items/fang.png": (16, 16, 16),
    "game/assets/items/wind_cape.png": (16, 16, 16),
    "game/assets/items/cracked_hourglass.png": (16, 16, 16),
    "game/assets/items/spark.png": (16, 16, 16),
    "game/assets/items/glass_shield.png": (16, 16, 16),
    "game/assets/ui/panel.png": (64, 40, 8),
    "game/assets/ui/slot.png": (20, 20, 4),
    "game/assets/ui/heart.png": (9, 8, 1),
    "game/assets/ui/coin.png": (8, 8, 8),
    "game/assets/ui/title_bg.png": (320, 180, 20),
}
# Cells that must stay empty in the climber sheets (frame counts per row).
CLIMBER_COUNTS = [2, 2, 2, 4, 4, 4, 3, 3, 3, 4, 4, 4, 4]


def main():
    root = sys.argv[1]
    ok = True
    for rel, (w, h, cell) in SHEETS.items():
        img = Image.open(os.path.join(root, rel)).convert("RGBA")
        data = img.get_flattened_data()
        colors = len({p for p in data if p[3]})
        alphas = {p[3] for p in data}
        transparent = sum(1 for p in data if p[3] == 0)
        problems = []
        if img.size != (w, h) or w % cell or h % cell:
            problems.append("size %s" % (img.size,))
        if colors > 32:
            problems.append("%d colours" % colors)
        if not alphas <= {0, 255}:
            problems.append("partial alpha")
        if "characters" in rel or "enemies" in rel:
            if img.getpixel((0, 0))[3]:
                problems.append("corner not transparent")
        if "climber" in rel:
            for r, n in enumerate(CLIMBER_COUNTS):
                for c in range(n, 4):
                    box = (c * 24, r * 24, c * 24 + 24, r * 24 + 24)
                    if img.crop(box).getbbox():
                        problems.append("unused cell %d,%d not empty" % (c, r))
        ok = ok and not problems
        print("%-45s %dx%d colours=%2d transparent=%5.1f%% %s" % (
            rel, img.width, img.height, colors, 100 * transparent / len(data),
            "OK" if not problems else "FAIL " + ", ".join(problems)))
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
