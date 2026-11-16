"""Icon vs sprite: one column per equippable item, the icon on top, then the
hero wearing it (idle down, up and side, one attack, one roll and one death
frame), composited the way
LayeredSprite stacks the layers. The rest of the kit is the starter (sword,
small backpack, no armor or helm).

python3 -I art-src/preview_equip.py <repo_root> <out.png> [id ...]
"""
import os
import sys

from PIL import Image

F = 32
K = 4
BG = (38, 34, 40, 255)
ITEMS = [
    "armor_cloth", "armor_leather", "armor_chain", "armor_scale", "armor_plate", "armor_shadow",
    "helm_hood", "helm_iron", "helm_horned", "helm_circlet",
    "sword_iron", "sword_knight", "longsword_steel", "longsword_ember", "axe_woodcutter", "axe_war",
    "spear_hunter", "spear_dragoon", "dagger_rogue", "dagger_twin_fang", "bow_short", "bow_elven",
    "backpack_small", "backpack_medium", "backpack_large",
]
# (row, frame) cells shown under the icon: idle down, idle up, idle side,
# attack side, roll side, death
CELLS = [(0, 0), (1, 0), (2, 0), (8, 2), (11, 0), (12, 5)]
LAYERS = ["body", "hair", "outfit", "armor", "backpack", "helm", "weapon"]


def load(path):
    return Image.open(path).convert("RGBA") if os.path.exists(path) else None


def kit(item):
    k = {"weapon": "sword_iron", "armor": "", "helm": "", "backpack": "backpack_small"}
    k[item.split("_")[0] if item.split("_")[0] in ("armor", "helm", "backpack") else "weapon"] = item
    return k


def cell(root, k, row, col):
    c = os.path.join(root, "game/assets/characters/climber")
    wtype = k["weapon"].split("_")[0]
    out = Image.new("RGBA", (F, F), (0, 0, 0, 0))
    for layer in LAYERS:
        attack = 6 <= row <= 8
        sheet, r = None, row
        if layer == "weapon":
            sheet = load(os.path.join(c, "weapons", k["weapon"] + ".png")) or load(
                os.path.join(c, "weapons", wtype + ".png"))
        elif layer in ("armor", "helm", "backpack"):
            if not k[layer]:
                continue
            if attack:
                sheet = load(os.path.join(c, "gear", "attacks", "%s_%s.png" % (wtype, k[layer])))
                r = row - 6
            if sheet is None:
                sheet, r = load(os.path.join(c, "gear", k[layer] + ".png")), row
        else:
            if attack:
                sheet = load(os.path.join(c, "attacks", "%s_%s.png" % (wtype, layer)))
                r = row - 6
            if sheet is None:
                sheet, r = load(os.path.join(c, layer + ".png")), row
        if sheet is not None:
            out.alpha_composite(sheet.crop((col * F, r * F, col * F + F, r * F + F)))
    return out


def main():
    root, out = sys.argv[1], sys.argv[2]
    items = sys.argv[3:] or ITEMS
    sheet = Image.new("RGBA", (len(items) * (F + 4) + 4, (len(CELLS) + 1) * (F + 4) + 4), BG)
    for i, item in enumerate(items):
        x = 4 + i * (F + 4)
        icon = load(os.path.join(root, "game/assets/items", item + ".png"))
        sheet.alpha_composite(icon.resize((F, F), Image.NEAREST), (x, 4))
        for j, (row, col) in enumerate(CELLS):
            sheet.alpha_composite(cell(root, kit(item), row, col), (x, 4 + (j + 1) * (F + 4)))
    sheet.resize((sheet.width * K, sheet.height * K), Image.NEAREST).save(out)


if __name__ == "__main__":
    main()
