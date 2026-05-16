"""
Composite a dialogue UI preview. Shows a tavern interior strip up top, then a
full-width dialogue panel: Orren's portrait, name, his evasive line, and the
authored options + "Say something else..." free-text option.

Run from the repo root: python3 tools/generate_dialogue_preview.py
"""

from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT    = Path(__file__).resolve().parents[1]
ASSETS  = ROOT / 'game' / 'assets'
PREVIEW = ROOT / 'game' / 'dialogue_preview.png'

TILE = 32
W    = 480
H    = 270

# layout: top 80 = world strip, bottom 190 = dialogue panel

P = {
    'cream':    (224, 214, 188),
    'dark':     (28, 26, 30),
    'bark':     (54, 38, 30),
    'leather':  (132, 92, 60),
    'gold':     (164, 132, 60),
    'ember':    (240, 168, 72),
    'gray_d':   (54, 48, 52),
    'gray_l':   (164, 156, 152),
}


def main():
    canvas = Image.new('RGBA', (W, H), (0, 0, 0, 255))

    # --- world strip (top 80px) - tavern interior peek ---
    floor = Image.open(ASSETS / 'tiles' / 'wooden_floor.png').convert('RGBA')
    wall  = Image.open(ASSETS / 'tiles' / 'wood_wall.png').convert('RGBA')

    # Top row of wall, then 1.5 rows of floor visible
    for c in range(15):
        canvas.paste(wall, (c * TILE, 0), wall)
    for r in range(1, 3):
        for c in range(15):
            canvas.paste(floor, (c * TILE, r * TILE), floor)

    # Kael standing on the floor, Orren slumped to his right
    kael  = Image.open(ASSETS / 'sprites' / 'kael.png').convert('RGBA')
    orren = Image.open(ASSETS / 'sprites' / 'orren.png').convert('RGBA')
    canvas.paste(kael,  (5 * TILE + 4, 1 * TILE + 12), kael)
    canvas.paste(orren, (8 * TILE + 4, 1 * TILE + 14), orren)

    # Dim the world strip slightly to push focus to the dialogue panel
    dim = Image.new('RGBA', (W, 80), (0, 0, 0, 70))
    canvas.alpha_composite(dim)

    # --- dialogue panel (bottom 190px) ---
    panel_y = 80
    panel_h = H - panel_y    # 190

    # parchment fill
    draw = ImageDraw.Draw(canvas)
    draw.rectangle((0, panel_y, W, H), fill=P['cream'])
    # double-frame
    draw.rectangle((0, panel_y, W - 1, H - 1), outline=P['bark'])
    draw.rectangle((2, panel_y + 2, W - 3, H - 3), outline=P['bark'])
    draw.rectangle((4, panel_y + 4, W - 5, H - 5), outline=P['leather'])
    # corner studs
    for cx, cy in [(7, 87), (W - 8, 87), (7, H - 8), (W - 8, H - 8)]:
        draw.point((cx, cy), fill=P['gold'])
        draw.point((cx + 1, cy), fill=P['gold'])

    # --- portrait area (left side) ---
    px, py = 12, panel_y + 16
    pf = Image.open(ASSETS / 'ui' / 'portrait_frame.png').convert('RGBA')
    canvas.paste(pf, (px, py), pf)
    # paste an enlarged Orren head into the portrait
    orren_head = orren.crop((4, 2, 20, 13)).resize((56, 56), Image.NEAREST)
    canvas.paste(orren_head, (px + 4, py + 4), orren_head)

    # --- name + dialogue text ---
    font = ImageFont.load_default()
    tx = px + 64 + 16    # 92
    draw.text((tx, panel_y + 14), 'ORREN', fill=P['dark'], font=font)
    # subtitle
    draw.text((tx + 56, panel_y + 14), '-- drunk, slumped, evasive', fill=P['gray_d'], font=font)

    # NPC line wrapped to fit
    npc_lines = [
        "Tower? Don't know about no tower.",
        "Look, friend... [hic]... best to leave",
        "that alone. Buy me another, eh?",
    ]
    for i, line in enumerate(npc_lines):
        draw.text((tx, panel_y + 30 + i * 14), line, fill=P['dark'], font=font)

    # --- options (right side) ---
    options = [
        ('1', 'You saw something, didn\'t you?',  False),
        ('2', 'You\'re afraid of the wings.',     True),    # currently highlighted
        ('3', 'Have another drink.',              False),
        ('-', 'Say something else...',            False),
    ]
    ox = tx
    oy = panel_y + 90
    for i, (key, label, sel) in enumerate(options):
        row_y = oy + i * 20
        # row background subtle
        if sel:
            draw.rectangle((ox - 6, row_y - 3, W - 12, row_y + 14), fill=P['leather'])
        # leading marker
        col = P['ember'] if sel else P['gray_d']
        draw.text((ox - 4, row_y), '>' if sel else key, fill=col, font=font)
        text_col = P['cream'] if sel else P['dark']
        draw.text((ox + 12, row_y), label, fill=text_col, font=font)

    # --- footer hint ---
    draw.text((12, H - 14), '[Press/Free] universal: pick or speak', fill=P['gray_d'], font=font)
    draw.text((W - 100, H - 14), 'J  journal', fill=P['gray_d'], font=font)

    canvas.save(PREVIEW)
    canvas.resize((W * 3, H * 3), Image.NEAREST).save(ROOT / 'game' / 'dialogue_preview_3x.png')
    print(f"Wrote {PREVIEW} and dialogue_preview_3x.png")


if __name__ == '__main__':
    main()
