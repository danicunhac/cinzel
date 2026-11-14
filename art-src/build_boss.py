"""Build the final boss sheet (6 cols x 4 rows of 48x48).

python3 -I art-src/build_boss.py <repo_root> [--force]

Same recipe as build_enemies.py (job "boss_final"): input
art-src/gen/r2/boss48-final-sheet-2.png, output
game/assets/enemies/boss_final.png, ground on row 44. The floor 1 and 2
bosses reuse crawler.png and charger.png at x2.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import build_enemies  # noqa: E402

if __name__ == "__main__":
    sys.argv = sys.argv[:2] + [a for a in sys.argv[2:] if a == "--force"] + ["boss_final"]
    build_enemies.main()
