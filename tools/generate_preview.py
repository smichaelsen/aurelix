"""
Composite the village square layout into a single PNG so you can preview the
visual style without opening Godot. Outputs game/preview.png.

Run from the repo root: python3 tools/generate_preview.py
"""

from pathlib import Path
from PIL import Image

ROOT    = Path(__file__).resolve().parents[1]
ASSETS  = ROOT / 'game' / 'assets'
PREVIEW = ROOT / 'game' / 'preview.png'

TILE    = 64
COLS    = 15
ROWS    = 9
W       = COLS * TILE      # 960
H       = ROWS * TILE      # 576 (one row taller than 540 viewport; ok for preview)

LAYOUT = [
    "GTTTTTGSSSSSGGG",
    "GTVTVTGSVSVSGGG",
    "GTTDTTGSSDSSGGG",
    "GCCCCCCCCCCCCCG",
    "GCCCCCCWCCCCCCG",
    "GCCCCCCwCCCCCCG",
    "GCCCNCCCCCCCCCG",
    "GCCCCCCPCCCCCCG",
    "GGGGGGGPGGGGGGG",
]


def tile_for(c, row):
    if c == 'G':  return 'grass'
    if c == 'C':  return 'cobble'
    if c == 'D':  return 'door'
    if c == 'W':  return 'well_stone'
    if c == 'w':  return 'well_water'
    if c == 'N':  return 'notice_board'
    if c == 'P':  return 'path'
    if c == 'V':  return 'window'
    if c == 'T':  return 'thatched_roof' if row == 0 else 'wood_wall'
    if c == 'S':  return 'thatched_roof' if row == 0 else 'wood_wall'
    raise ValueError(c)


PROPS = [
    (0,  1, 'tree'),
    (14, 1, 'tree'),
    (0,  6, 'tree'),
    (14, 6, 'tree'),
    (3,  1, 'tavern_sign'),
    (5,  3, 'lantern'),
    (8,  0, 'chimney'),
    (10, 3, 'anvil'),
    (12, 3, 'barrel'),
    (1,  4, 'flower_patch'),
    (13, 7, 'flower_patch'),
]


CHARACTERS = [
    (7,  6, 4,  0, 'kael'),
    (7,  4, 4, -8, 'toma'),
    (9,  3, 4,  0, 'mara'),
    (4,  3, 4,  0, 'orren'),
    (11, 7, 4,  0, 'halden'),
    (3,  7, 4,  0, 'edda'),
]


def main():
    canvas = Image.new('RGBA', (W, H), (0, 0, 0, 255))

    # Tiles
    for r, line in enumerate(LAYOUT):
        for c, ch in enumerate(line):
            tex = tile_for(ch, r)
            img = Image.open(ASSETS / 'tiles' / f'{tex}.png').convert('RGBA')
            canvas.paste(img, (c * TILE, r * TILE), img)

    # Props (above tiles, below characters)
    for col, row, prop in PROPS:
        img = Image.open(ASSETS / 'tiles' / f'{prop}.png').convert('RGBA')
        canvas.paste(img, (col * TILE, row * TILE), img)

    # Characters (above everything else on the floor)
    for col, row, ox, oy, sprite in CHARACTERS:
        img = Image.open(ASSETS / 'sprites' / f'{sprite}.png').convert('RGBA')
        canvas.paste(img, (col * TILE + ox, row * TILE + oy), img)

    # Save at 1x (480 wide). Also save a 3x scale for retina viewing.
    canvas.save(PREVIEW)
    big = canvas.resize((W * 3, H * 3), Image.NEAREST)
    big.save(ROOT / 'game' / 'preview_3x.png')
    print(f"Wrote {PREVIEW} ({W}x{H}) and preview_3x.png ({W*3}x{H*3})")


if __name__ == '__main__':
    main()
