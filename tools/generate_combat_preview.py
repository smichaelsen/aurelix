"""
Composite a combat scene preview: world tiles (forest) + Kael/Iskar + a wolf
enemy + the bottom UI panel with HP bars, action menu (icons), stance picker
(icons), and a narration strip.

Run from the repo root: python3 tools/generate_combat_preview.py
"""

from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT    = Path(__file__).resolve().parents[1]
ASSETS  = ROOT / 'game' / 'assets'
PREVIEW = ROOT / 'game' / 'combat_preview.png'

TILE = 32
W    = 480
H    = 270

PAL = {
    'cream':    (240, 240, 224),
    'ember':    (240, 168, 72),
    'gold':     (164, 132, 60),
    'gray_d':   (54, 48, 52),
    'gray_l':   (164, 156, 152),
    'red':      (170, 110, 80),
}


def main():
    canvas = Image.new('RGBA', (W, H), (0, 0, 0, 255))
    draw = ImageDraw.Draw(canvas)
    font = ImageFont.load_default()

    # --- World ---
    forest = Image.open(ASSETS / 'tiles' / 'forest_floor.png').convert('RGBA')
    fpath  = Image.open(ASSETS / 'tiles' / 'forest_path.png').convert('RGBA')
    cols, rows = 15, 6
    for r in range(rows):
        for c in range(cols):
            tile = fpath if c == 7 else forest
            canvas.paste(tile, (c * TILE, r * TILE), tile)

    # --- Wolf at top of path ---
    wolf = Image.open(ASSETS / 'sprites' / 'wolf.png').convert('RGBA')   # now 48x36
    wolf_x = 6 * TILE + 4
    wolf_y = 1 * TILE
    canvas.paste(wolf, (wolf_x, wolf_y), wolf)

    # Wolf name + HP bar centered above wolf
    wolf_label_y = wolf_y - 20
    draw.text((wolf_x + 4, wolf_label_y), 'WOLF', fill=PAL['cream'], font=font)
    draw.text((wolf_x + 36, wolf_label_y), '7/20', fill=PAL['gray_l'], font=font)
    wolf_hp = Image.open(ASSETS / 'ui' / 'hp_bar_wolf.png').convert('RGBA')
    canvas.paste(wolf_hp, (wolf_x - 4, wolf_label_y + 10), wolf_hp)

    # --- Kael + Iskar at bottom of path ---
    kael  = Image.open(ASSETS / 'sprites' / 'kael.png').convert('RGBA')
    iskar = Image.open(ASSETS / 'sprites' / 'iskar.png').convert('RGBA')
    canvas.paste(kael,  (6 * TILE + 4, 4 * TILE + 0), kael)
    canvas.paste(iskar, (8 * TILE + 0, 4 * TILE + 12), iskar)

    # --- Battle panel ---
    panel = Image.open(ASSETS / 'ui' / 'battle_panel.png').convert('RGBA')
    panel_y = H - 90
    canvas.paste(panel, (0, panel_y), panel)

    # === Inside panel ===

    # Top narration strip (above HP section)
    draw.text((14, panel_y + 8), '> Iskar bared his teeth. The wolf hesitated.',
              fill=PAL['cream'], font=font)

    # Section 1: HP bars (left, x 0..200)
    # Kael
    draw.text((14, panel_y + 24), 'KAEL',  fill=PAL['cream'], font=font)
    draw.text((144, panel_y + 24), '34/40', fill=PAL['gray_l'], font=font)
    hp_k = Image.open(ASSETS / 'ui' / 'hp_bar_kael.png').convert('RGBA')
    canvas.paste(hp_k, (14, panel_y + 38), hp_k)
    # Iskar
    draw.text((14, panel_y + 56), 'ISKAR', fill=PAL['cream'], font=font)
    draw.text((144, panel_y + 56), '12/20', fill=PAL['gray_l'], font=font)
    hp_i = Image.open(ASSETS / 'ui' / 'hp_bar_iskar.png').convert('RGBA')
    canvas.paste(hp_i, (14, panel_y + 70), hp_i)

    # Section 2: Action menu (middle, x 200..360)
    actions = [
        ('Attack', 'icon_sword',     True),
        ('Item',   'icon_bottle',    False),
        ('Defend', 'icon_shield',    False),
        ('Flee',   'icon_arrow',     False),
    ]
    ax = 212
    ay = panel_y + 14
    for i, (label, icon, sel) in enumerate(actions):
        row_y = ay + i * 17
        # row background for selected
        if sel:
            draw.rectangle((ax - 4, row_y - 2, 354, row_y + 14), fill=PAL['gold'])
        # icon
        ic = Image.open(ASSETS / 'ui' / f'{icon}.png').convert('RGBA')
        canvas.paste(ic, (ax, row_y - 2), ic)
        # label
        col = PAL['cream'] if sel else PAL['cream']
        draw.text((ax + 22, row_y), label.upper(), fill=col, font=font)

    # Section 3: Stance picker (right, x 360..480)
    draw.text((372, panel_y + 8), 'STANCE', fill=PAL['gray_l'], font=font)
    stances = [
        ('AGGR.', 'icon_fist',   False),
        ('DEF.',  'icon_shield', True),
        ('SUPP.', 'icon_plus',   False),
    ]
    sx = 372
    sy = panel_y + 22
    for i, (label, icon, sel) in enumerate(stances):
        row_y = sy + i * 20
        if sel:
            draw.rectangle((sx - 4, row_y - 2, 472, row_y + 16), fill=PAL['gold'])
        ic = Image.open(ASSETS / 'ui' / f'{icon}.png').convert('RGBA')
        canvas.paste(ic, (sx, row_y - 2), ic)
        col = PAL['cream']
        draw.text((sx + 22, row_y), label, fill=col, font=font)

    canvas.save(PREVIEW)
    canvas.resize((W * 3, H * 3), Image.NEAREST).save(ROOT / 'game' / 'combat_preview_3x.png')
    print(f"Wrote {PREVIEW} and combat_preview_3x.png")


if __name__ == '__main__':
    main()
