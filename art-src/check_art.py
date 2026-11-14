"""Check the shipped sheets: size, transparency, colour count, unused climber
cells empty, villager cells filled per row, no orphan pixels in the climber
layers, nothing below the ground row the game expects (climber, NPCs and
villagers 30, enemies 22, boss 44). Also checks every weapon, attack override,
outfit, armor and helm layer, item icon and rarity frame on disk.

python3 -I art-src/check_art.py <repo_root>
"""
import os
import sys

from PIL import Image

SHEETS = {
    "game/assets/characters/climber/body.png": (256, 416, 32),
    "game/assets/characters/climber/hair.png": (256, 416, 32),
    "game/assets/characters/climber/outfit.png": (256, 416, 32),
    "game/assets/characters/climber/weapon.png": (256, 416, 32),
    "game/assets/enemies/crawler.png": (144, 96, 24),
    "game/assets/enemies/shooter.png": (144, 96, 24),
    "game/assets/enemies/charger.png": (144, 96, 24),
    "game/assets/enemies/boss_final.png": (288, 192, 48),
    "game/assets/tiles/floor1.png": (128, 32, 16),
    "game/assets/tiles/floor2.png": (128, 32, 16),
    "game/assets/tiles/floor3.png": (128, 32, 16),
    "game/assets/characters/npc_shopkeeper.png": (64, 32, 32),
    "game/assets/characters/npc_blacksmith.png": (64, 32, 32),
    **{"game/assets/characters/villagers/%s.png" % n: (128, 192, 32) for n in (
        "oldwoman", "child", "guard", "farmer", "archer", "merchant")},
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
    "game/assets/ui/title_bg.png": (480, 270, 30),
    "game/assets/ui/hud/hp_frame.png": (48, 12, 12),
    "game/assets/ui/hud/boss_frame.png": (64, 16, 16),
    "game/assets/ui/hud/slot.png": (22, 22, 22),
    "game/assets/ui/hud/plaque.png": (30, 16, 2),
    "game/assets/ui/hud/button.png": (42, 24, 6),
    "game/assets/ui/hud/button_hot.png": (42, 24, 6),
    "game/assets/ui/hud/button_down.png": (42, 24, 6),
    "game/assets/ui/hud/button_off.png": (42, 24, 6),
    "game/assets/ui/hud/button_focus.png": (42, 24, 6),
    "game/assets/ui/hud/panel.png": (72, 70, 2),
    "game/assets/ui/hud/heart.png": (52, 12, 1),
    "game/assets/ui/hud/coin.png": (54, 9, 9),
    "game/assets/ui/hud/hourglass.png": (6, 9, 1),
    "game/assets/ui/hud/ring.png": (24, 24, 24),
    "game/assets/ui/hud/fill_hp.png": (1, 6, 1),
    "game/assets/ui/hud/fill_boss.png": (1, 8, 1),
    "game/assets/ui/hud/fill_exit.png": (1, 6, 1),
    "game/assets/ui/hud/fill_tip.png": (3, 8, 1),
}
# Villager sheets: frames per row (idle down/up/side, walk down/up/side).
VILLAGER_COUNTS = [2, 2, 2, 4, 4, 4]
# Cells that must stay empty in the climber sheets (frame counts per row).
CLIMBER_COUNTS = [4, 4, 4, 8, 8, 8, 6, 6, 6, 6, 6, 6, 6]
# Attack overrides (climber/attacks/, climber/outfits/<id>/attacks/): only
# the 3 attack rows.
ATTACK_COUNTS = [6, 6, 6]


def extra_sheets(root):
    """Weapon, attack override, outfit, armor/helm and item files found on disk."""
    out = {}
    climber = "game/assets/characters/climber"
    for sub in ("weapons", "attacks"):
        d = os.path.join(root, climber, sub)
        for f in sorted(os.listdir(d)) if os.path.isdir(d) else []:
            if f.endswith(".png"):
                out["%s/%s/%s" % (climber, sub, f)] = (256, 416 if sub == "weapons" else 96, 32)
    gd = os.path.join(root, climber, "gear")
    for f in sorted(os.listdir(gd)) if os.path.isdir(gd) else []:
        if f.endswith(".png"):
            out["%s/gear/%s" % (climber, f)] = (256, 416, 32)
    for f in sorted(os.listdir(os.path.join(gd, "attacks"))) if os.path.isdir(os.path.join(gd, "attacks")) else []:
        if f.endswith(".png"):
            out["%s/gear/attacks/%s" % (climber, f)] = (256, 96, 32)
    od = os.path.join(root, climber, "outfits")
    for oid in sorted(os.listdir(od)) if os.path.isdir(od) else []:
        for f in ("hair.png", "outfit.png"):
            if os.path.exists(os.path.join(od, oid, f)):
                out["%s/outfits/%s/%s" % (climber, oid, f)] = (256, 416, 32)
        ad = os.path.join(od, oid, "attacks")
        for f in sorted(os.listdir(ad)) if os.path.isdir(ad) else []:
            if f.endswith(".png"):
                out["%s/outfits/%s/attacks/%s" % (climber, oid, f)] = (256, 96, 32)
    items = os.path.join(root, "game/assets/items")
    for f in sorted(os.listdir(items)):
        if f.endswith(".png"):
            out["game/assets/items/" + f] = (16, 16, 16)
    frames = os.path.join(items, "frames")
    for f in sorted(os.listdir(frames)) if os.path.isdir(frames) else []:
        if f.endswith(".png"):
            out["game/assets/items/frames/" + f] = (18, 18, 18)
    return out
CLIMBER_COLS = 8
# Lowest opaque row allowed in each cell (the feet / ground line the game
# uses). First matching key wins.
GROUND = [("climber", 30), ("npc_", 30), ("villagers/", 30), ("enemies/boss_final", 44), ("enemies/", 22)]


def orphans(img):
    """Opaque pixels with no opaque 8-neighbour in the same sheet."""
    a = img.getchannel("A").load()
    w, h = img.size
    n = 0
    for y in range(h):
        for x in range(w):
            if a[x, y] and not any(
                    0 <= x + dx < w and 0 <= y + dy < h and a[x + dx, y + dy]
                    for dx in (-1, 0, 1) for dy in (-1, 0, 1) if dx or dy):
                n += 1
    return n


def lowest_row(img, cell):
    """Lowest opaque row inside any cell, in cell coordinates."""
    a = img.getchannel("A").load()
    low = -1
    for y in range(img.height):
        if any(a[x, y] for x in range(img.width)):
            low = max(low, y % cell)
    return low


def main():
    root = sys.argv[1] if len(sys.argv) > 1 else "."
    ok = True
    sheets = dict(SHEETS)
    sheets.update(extra_sheets(root))
    for rel, (w, h, cell) in sheets.items():
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
            counts = ATTACK_COUNTS if "/attacks/" in rel else CLIMBER_COUNTS
            for r, n in enumerate(counts):
                for c in range(n, CLIMBER_COLS):
                    box = (c * cell, r * cell, c * cell + cell, r * cell + cell)
                    if img.crop(box).getbbox():
                        problems.append("unused cell %d,%d not empty" % (c, r))
            n = orphans(img)
            if n:
                problems.append("%d orphan pixels" % n)
        if "villagers/" in rel:
            for r, n in enumerate(VILLAGER_COUNTS):
                for c in range(4):
                    box = (c * cell, r * cell, c * cell + cell, r * cell + cell)
                    if bool(img.crop(box).getbbox()) != (c < n):
                        problems.append("cell %d,%d %s" % (c, r, "empty" if c < n else "not empty"))
        ground = next((g for k, g in GROUND if k in rel), None)
        if ground is not None and lowest_row(img, cell) > ground:
            problems.append("pixels below ground row %d" % ground)
        ok = ok and not problems
        print("%-70s %dx%d colours=%2d transparent=%5.1f%% %s" % (
            rel, img.width, img.height, colors, 100 * transparent / len(data),
            "OK" if not problems else "FAIL " + ", ".join(problems)))
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
