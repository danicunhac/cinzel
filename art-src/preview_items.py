"""4x contact sheet of the item icons: one row per icon group, each icon in
the common frame, plus one column of the rare and epic frames.

python3 -I art-src/preview_items.py <repo_root> <out.png>
"""
import os
import sys

from PIL import Image

K = 4
BG = (38, 34, 40, 255)
GROUPS = [
    ["sword_iron", "sword_knight", "longsword_steel", "longsword_ember", "axe_woodcutter", "axe_war",
     "spear_hunter", "spear_dragoon", "dagger_rogue", "dagger_twin_fang", "bow_short", "bow_elven"],
    ["armor_cloth", "armor_leather", "armor_chain", "armor_scale", "armor_plate", "armor_shadow",
     "helm_hood", "helm_iron", "helm_horned", "helm_circlet", "backpack_small", "backpack_medium", "backpack_large"],
    ["mat_iron_ore", "mat_old_leather", "mat_ash_wood", "mat_chitin", "mat_beetle_horn",
     "mat_silver_ore", "mat_coal", "mat_obsidian", "mat_specter_cloth", "mat_tower_crystal"],
    ["outfit_starter", "outfit_casaco_longo", "outfit_cavaleiro_leve", "outfit_tunica_ferreiro", "outfit_manto_mago",
     "heavy_blade", "light_boots", "stone_heart", "fang", "wind_cape", "cracked_hourglass", "spark", "glass_shield"],
]
RARITY = ["common", "rare", "epic"]


def main():
    root, out = sys.argv[1], sys.argv[2]
    items = os.path.join(root, "game/assets/items")
    cols = max(len(g) for g in GROUPS)
    sheet = Image.new("RGBA", (cols * 20 + 4, (len(GROUPS) + 1) * 20 + 4), BG)
    for r, group in enumerate(GROUPS):
        for c, name in enumerate(group):
            path = os.path.join(items, name + ".png")
            if not os.path.exists(path):
                continue
            frame = Image.open(os.path.join(items, "frames", RARITY[c % 3] + ".png")).convert("RGBA")
            x, y = 2 + c * 20, 2 + r * 20
            sheet.alpha_composite(frame, (x, y))
            sheet.alpha_composite(Image.open(path).convert("RGBA"), (x + 1, y + 1))
    sheet.resize((sheet.width * K, sheet.height * K), Image.NEAREST).save(out)


if __name__ == "__main__":
    main()
