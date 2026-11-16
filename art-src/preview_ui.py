"""Contact sheet of the build_ui.py outputs at 8x, for review.

python3 -I art-src/preview_ui.py <repo_root> <out.png>
"""
import os
import sys

from PIL import Image

K = 8


def main():
    root, out = sys.argv[1], sys.argv[2]
    a = os.path.join(root, "game", "assets")
    files = sorted(os.path.join(a, "items", f) for f in os.listdir(os.path.join(a, "items")) if f.endswith(".png"))
    files += [os.path.join(a, "characters", f) for f in ("npc_shopkeeper.png", "npc_blacksmith.png")]
    files += [os.path.join(a, "ui", f) for f in ("panel.png", "slot.png", "heart.png", "coin.png")]
    imgs = [Image.open(f).convert("RGBA") for f in files]
    w = sum(i.width * K + 8 for i in imgs[:8])
    sheet = Image.new("RGBA", (max(w, 600), 600), (60, 50, 70, 255))
    x, y = 4, 4
    for n, i in enumerate(imgs):
        if n in (8, 10):
            x, y = 4, y + 8 + max(j.height for j in imgs[(0 if n == 8 else 8):n]) * K
        big = i.resize((i.width * K, i.height * K), Image.NEAREST)
        sheet.alpha_composite(big, (x, y))
        x += big.width + 8
    sheet.save(out)


if __name__ == "__main__":
    main()
