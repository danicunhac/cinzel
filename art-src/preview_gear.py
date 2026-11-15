"""4x previews of the climber with each weapon and each outfit, composited the
way the game stacks the layers (body, hair, outfit, weapon), with the attack
rows swapped for a weapon's attack override when it has one.

python3 -I art-src/preview_gear.py <repo_root> <out_dir> [prefix]

Writes <prefix>-weapon-<type>.png and .gif per row, <prefix>-outfit-<id>.png
(with the sword) and .gif per row, and <prefix>-outfit-<id>-<type>-attacks.png
(the 3 attack rows of every outfit x override weapon).
"""
import os
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from preview import CLIMBER_ROWS, gif, on_floor, sheet_rows  # noqa: E402

F = 32
TYPES = ["sword", "longsword", "axe", "spear", "dagger", "bow"]
OUTFITS = ["starter", "casaco_longo", "cavaleiro_leve", "tunica_ferreiro", "manto_mago", "sobretudo_noite", "traje_sombra"]
ATTACK_ROW0 = 6


def load(path):
    return Image.open(path).convert("RGBA") if os.path.exists(path) else None


def swap_attacks(sheet, override):
    if override is None:
        return sheet
    out = sheet.copy()
    out.paste(Image.new("RGBA", (sheet.width, 3 * F), (0, 0, 0, 0)), (0, ATTACK_ROW0 * F))
    out.paste(override, (0, ATTACK_ROW0 * F))
    return out


def compose(root, weapon, outfit=None):
    """Full 8x13 composite, or None when a needed file is missing."""
    c = os.path.join(root, "game/assets/characters/climber")
    wsheet = load(os.path.join(c, "weapons", weapon + ".png"))
    if wsheet is None:
        return None
    body = swap_attacks(load(os.path.join(c, "body.png")), load(os.path.join(c, "attacks", weapon + "_body.png")))
    layers = [body]
    for k in ("hair", "outfit"):
        if outfit is None:
            base = load(os.path.join(c, k + ".png"))
            att = load(os.path.join(c, "attacks", "%s_%s.png" % (weapon, k)))
        else:
            base = load(os.path.join(c, "outfits", outfit, k + ".png"))
            if base is None:
                return None
            att = load(os.path.join(c, "outfits", outfit, "attacks", "%s_%s.png" % (weapon, k)))
        layers.append(swap_attacks(base, att))
    layers.append(wsheet)
    comp = Image.new("RGBA", body.size, (0, 0, 0, 0))
    for layer in layers:
        comp.alpha_composite(layer)
    return comp


def rows_gifs(sheet, out, stem):
    for name, cells, fps in sheet_rows(sheet, F, CLIMBER_ROWS):
        gif(cells, fps, os.path.join(out, "%s-%s.gif" % (stem, name)))


def main():
    root, out = sys.argv[1], sys.argv[2]
    prefix = sys.argv[3] if len(sys.argv) > 3 else "taskE3"
    os.makedirs(out, exist_ok=True)
    for t in TYPES:
        sheet = compose(root, t)
        if sheet is None:
            continue
        stem = "%s-weapon-%s" % (prefix, t)
        on_floor(sheet).save(os.path.join(out, stem + ".png"))
        rows_gifs(sheet, out, stem)
    for o in OUTFITS:
        sheet = compose(root, "sword", o)
        if sheet is None:
            continue
        stem = "%s-outfit-%s" % (prefix, o)
        on_floor(sheet).save(os.path.join(out, stem + ".png"))
        rows_gifs(sheet, out, stem)
        strips = []
        for t in TYPES:
            full = compose(root, t, o)
            if full is not None and t != "sword":
                strips.append(full.crop((0, ATTACK_ROW0 * F, 6 * F, (ATTACK_ROW0 + 3) * F)))
        if strips:
            grid = Image.new("RGBA", (6 * F * len(strips) + 8 * (len(strips) - 1), 3 * F), (0, 0, 0, 0))
            for i, s in enumerate(strips):
                grid.alpha_composite(s, (i * (6 * F + 8), 0))
            on_floor(grid).save(os.path.join(out, "%s-outfit-%s-attacks.png" % (prefix, o)))


if __name__ == "__main__":
    main()
