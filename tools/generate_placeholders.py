"""
Generate placeholder pixel art for the Aurelix demo's first visual pass.

Programmer art only. The goal is to nail layout, scale, framing, and palette
before commissioning or hand-pixeling real assets.

Outputs go to game/assets/tiles, game/assets/sprites, game/assets/ui.
Run from the repo root: python3 tools/generate_placeholders.py
"""

from pathlib import Path
from PIL import Image
import random

# ---------------------------------------------------------------------------
# Palette  --  32 colours, grim fairy-tale
# ---------------------------------------------------------------------------

P = {
    # grays
    'gray_darkest':       (28,  26,  30),
    'gray_dark':          (54,  48,  52),
    'gray_mid':           (98,  90,  92),
    'gray_light':         (164, 156, 152),
    # browns
    'brown_bark':         (54,  38,  30),
    'brown_dirt':         (96,  70,  50),
    'brown_leather':      (132, 92,  60),
    'brown_wheat':        (188, 148, 92),
    # greens
    'green_forest_dark':  (28,  50,  40),
    'green_forest_mid':   (54,  84,  62),
    'green_moss':         (92,  110, 70),
    'green_grass':        (124, 142, 88),
    # stones
    'stone_cold':         (94,  100, 108),
    'stone_warm':         (140, 124, 102),
    'stone_dark':         (60,  60,  68),
    'stone_weathered':    (172, 162, 142),
    # reds
    'red_blood':          (94,  30,  30),
    'red_rust':           (140, 70,  44),
    'red_terra':          (170, 110, 80),
    'red_ember':          (224, 124, 60),
    # blues
    'blue_night':         (24,  30,  54),
    'blue_dusk':          (54,  70,  110),
    'blue_water':         (62,  92,  124),
    'blue_sky':           (122, 148, 174),
    # flesh tones
    'flesh_pale':         (216, 178, 154),
    'flesh_mid':          (190, 144, 116),
    'flesh_ruddy':        (152, 102, 84),
    'flesh_dark':         (102, 66,  56),
    # special accents
    'bone_white':         (224, 214, 188),
    'gold_dull':          (164, 132, 60),
    'iskar_dark':         (38,  32,  42),
    'ember_orange':       (240, 168, 72),
}

TRANSPARENT = (0, 0, 0, 0)


# ---------------------------------------------------------------------------
# Output paths
# ---------------------------------------------------------------------------

ROOT     = Path(__file__).resolve().parents[1]
ASSETS   = ROOT / 'game' / 'assets'
TILES    = ASSETS / 'tiles'
SPRITES  = ASSETS / 'sprites'
UI       = ASSETS / 'ui'

for d in (TILES, SPRITES, UI):
    d.mkdir(parents=True, exist_ok=True)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def new_tile(w=32, h=32):
    return Image.new('RGBA', (w, h), TRANSPARENT)


def fill(img, color):
    """Fill the whole image with a single colour."""
    for x in range(img.width):
        for y in range(img.height):
            img.putpixel((x, y), color)


def speckle(img, color, density=0.08, rng=None):
    """Sprinkle pixels of color across the image."""
    rng = rng or random
    for x in range(img.width):
        for y in range(img.height):
            if rng.random() < density:
                img.putpixel((x, y), color)


def hline(img, y, color, x0=0, x1=None):
    x1 = x1 if x1 is not None else img.width
    for x in range(x0, x1):
        img.putpixel((x, y), color)


def vline(img, x, color, y0=0, y1=None):
    y1 = y1 if y1 is not None else img.height
    for y in range(y0, y1):
        img.putpixel((x, y), color)


def rect(img, x0, y0, x1, y1, color):
    for x in range(x0, x1):
        for y in range(y0, y1):
            img.putpixel((x, y), color)


def outline(img, x0, y0, x1, y1, color):
    hline(img, y0,     color, x0, x1)
    hline(img, y1 - 1, color, x0, x1)
    vline(img, x0,     color, y0, y1)
    vline(img, x1 - 1, color, y0, y1)


# ---------------------------------------------------------------------------
# Tiles
# ---------------------------------------------------------------------------

def tile_grass():
    img = new_tile()
    rng = random.Random(1)
    fill(img, P['green_moss'])
    speckle(img, P['green_forest_mid'], 0.18, rng)
    speckle(img, P['green_forest_dark'], 0.08, rng)
    speckle(img, P['green_grass'],       0.06, rng)
    # rare flower
    for _ in range(2):
        x, y = rng.randint(2, 28), rng.randint(2, 28)
        img.putpixel((x, y), P['bone_white'])
    img.save(TILES / 'grass.png')


def tile_path():
    img = new_tile()
    rng = random.Random(2)
    fill(img, P['brown_dirt'])
    speckle(img, P['brown_bark'],    0.10, rng)
    speckle(img, P['brown_leather'], 0.06, rng)
    speckle(img, P['stone_warm'],    0.04, rng)
    img.save(TILES / 'path.png')


def tile_cobble():
    img = new_tile()
    fill(img, P['stone_cold'])
    # 4 cobblestones in a 2x2 grid, each 15x15 with 1px gap
    for cx in (0, 16):
        for cy in (0, 16):
            outline(img, cx, cy, cx + 15, cy + 15, P['stone_dark'])
            # subtle inner highlight
            img.putpixel((cx + 3, cy + 3),  P['stone_weathered'])
            img.putpixel((cx + 11, cy + 4), P['stone_weathered'])
    img.save(TILES / 'cobble.png')


def tile_well_water():
    img = new_tile()
    rng = random.Random(3)
    fill(img, P['blue_water'])
    speckle(img, P['blue_dusk'],  0.20, rng)
    speckle(img, P['blue_night'], 0.05, rng)
    speckle(img, P['blue_sky'],   0.04, rng)
    img.save(TILES / 'well_water.png')


def tile_well_stone():
    img = new_tile()
    fill(img, P['stone_warm'])
    # subtle bricks: horizontal grout lines
    hline(img, 10, P['stone_dark'])
    hline(img, 21, P['stone_dark'])
    # staggered vertical lines
    vline(img, 10, P['stone_dark'], 0,  11)
    vline(img, 22, P['stone_dark'], 0,  11)
    vline(img, 4,  P['stone_dark'], 11, 22)
    vline(img, 16, P['stone_dark'], 11, 22)
    vline(img, 28, P['stone_dark'], 11, 22)
    vline(img, 10, P['stone_dark'], 22, 32)
    vline(img, 22, P['stone_dark'], 22, 32)
    img.save(TILES / 'well_stone.png')


def tile_wood_wall():
    img = new_tile()
    fill(img, P['brown_leather'])
    # vertical plank lines
    for x in (5, 12, 19, 26):
        vline(img, x, P['brown_bark'])
    # plank grain noise
    rng = random.Random(4)
    speckle(img, P['brown_bark'], 0.04, rng)
    img.save(TILES / 'wood_wall.png')


def tile_thatched_roof():
    img = new_tile()
    fill(img, P['brown_wheat'])
    # horizontal thatch bundles
    for y in range(0, 32, 4):
        hline(img, y, P['brown_leather'])
    rng = random.Random(5)
    speckle(img, P['brown_bark'], 0.06, rng)
    img.save(TILES / 'thatched_roof.png')


def tile_chapel_stone():
    img = new_tile()
    fill(img, P['stone_warm'])
    # ashlar block pattern (rectangular blocks)
    for y in (0, 11, 22):
        hline(img, y, P['stone_dark'])
    # vertical, staggered
    offset = 0
    for y_start, y_end in [(0, 11), (11, 22), (22, 32)]:
        x = 8 + offset
        while x < 32:
            vline(img, x, P['stone_dark'], y_start, y_end)
            x += 16
        offset = (offset + 8) % 16
    img.save(TILES / 'chapel_stone.png')


def tile_door():
    img = new_tile()
    fill(img, P['brown_bark'])
    rect(img, 4, 4, 28, 30, P['brown_leather'])
    # planks
    for x in (10, 16, 22):
        vline(img, x, P['brown_bark'], 4, 30)
    # handle
    img.putpixel((24, 17), P['gold_dull'])
    img.putpixel((24, 18), P['gold_dull'])
    img.save(TILES / 'door.png')


def tile_notice_board():
    img = new_tile()
    fill(img, (0, 0, 0, 0))
    # post
    rect(img, 14, 16, 18, 32, P['brown_bark'])
    # board frame
    rect(img, 2, 4, 30, 22, P['brown_bark'])
    rect(img, 4, 6, 28, 20, P['bone_white'])
    # squiggle "text"
    for y in (9, 12, 15):
        hline(img, y, P['gray_dark'], 6, 26)
    img.save(TILES / 'notice_board.png')


def tile_window():
    """A wood-wall tile with a small inset window."""
    img = new_tile()
    fill(img, P['brown_leather'])
    # planks
    for x in (5, 12, 19, 26):
        vline(img, x, P['brown_bark'])
    rng = random.Random(7)
    speckle(img, P['brown_bark'], 0.04, rng)
    # window cutout: dark interior + crossbars + sill
    rect(img, 9, 8, 23, 22, P['blue_night'])
    # glimmer hint of candle in some windows (1 in 2)
    img.putpixel((15, 14), P['ember_orange'])
    img.putpixel((16, 14), P['ember_orange'])
    # crossbars
    vline(img, 16, P['brown_bark'], 8, 22)
    hline(img, 14, P['brown_bark'], 9, 23)
    # sill
    hline(img, 22, P['brown_bark'], 8, 24)
    hline(img, 23, P['brown_bark'], 8, 24)
    img.save(TILES / 'window.png')


# ---------------------------------------------------------------------------
# Props  --  decoration sprites placed on top of base tiles
# ---------------------------------------------------------------------------

def prop_tree():
    img = new_tile()
    rng = random.Random(8)
    # trunk
    rect(img, 14, 18, 18, 31, P['brown_bark'])
    # foliage cluster -- rough circle
    cluster = [
        (16, 4), (14, 5), (18, 5), (12, 7), (20, 7),
        (10, 10), (22, 10), (9, 13), (23, 13),
        (10, 16), (22, 16), (12, 18), (20, 18),
        (13, 20), (19, 20),
    ]
    for cx, cy in cluster:
        for dx in range(-2, 3):
            for dy in range(-2, 3):
                if abs(dx) + abs(dy) <= 3:
                    px, py = cx + dx, cy + dy
                    if 0 <= px < 32 and 0 <= py < 32:
                        # mix two greens for variation
                        color = P['green_forest_dark'] if rng.random() < 0.4 else P['green_forest_mid']
                        img.putpixel((px, py), color)
    # darker outline pixels at base of foliage
    for x in range(9, 24):
        img.putpixel((x, 21), P['green_forest_dark'])
    img.save(TILES / 'tree.png')


def prop_lantern():
    img = new_tile()
    # pole
    rect(img, 15, 8, 17, 30, P['brown_bark'])
    # lamp housing
    rect(img, 11, 6, 21, 14, P['gray_dark'])
    outline(img, 11, 6, 21, 14, P['brown_bark'])
    # light interior
    rect(img, 13, 8, 19, 12, P['ember_orange'])
    img.putpixel((16, 10), P['bone_white'])
    # ground glow hint
    for x in range(11, 21):
        img.putpixel((x, 31), P['ember_orange'])
    img.save(TILES / 'lantern.png')


def prop_barrel():
    img = new_tile()
    # body
    rect(img, 8, 12, 24, 30, P['brown_leather'])
    # bands
    hline(img, 16, P['brown_bark'], 8, 24)
    hline(img, 25, P['brown_bark'], 8, 24)
    # top rim (ellipse-ish)
    rect(img, 9, 11, 23, 13, P['brown_bark'])
    rect(img, 10, 12, 22, 14, P['brown_dirt'])
    # bottom shadow
    hline(img, 30, P['gray_darkest'], 8, 24)
    img.save(TILES / 'barrel.png')


def prop_flower_patch():
    img = new_tile()
    rng = random.Random(9)
    # subtle grass-toned background that blends with the base tile
    speckle(img, P['green_grass'], 0.15, rng)
    speckle(img, P['green_forest_mid'], 0.08, rng)
    # flowers
    flowers = [
        (8, 22, P['bone_white']),
        (12, 18, P['red_terra']),
        (16, 20, P['bone_white']),
        (20, 24, P['gold_dull']),
        (24, 19, P['red_terra']),
        (10, 26, P['bone_white']),
    ]
    for fx, fy, col in flowers:
        img.putpixel((fx, fy), col)
        img.putpixel((fx, fy - 1), P['green_forest_dark'])  # stem hint
    img.save(TILES / 'flower_patch.png')


def prop_tavern_sign():
    """A hanging tavern signboard placed over the wood-wall above the door.

    Transparent everywhere except for the bracket + chain + board, so the wall
    underneath shows through where the sign isn't drawn.
    """
    img = new_tile()
    # bracket coming out from wall (top edge)
    hline(img, 2, P['brown_bark'], 12, 22)
    img.putpixel((22, 3), P['brown_bark'])
    img.putpixel((22, 4), P['brown_bark'])
    # chain from bracket down to board
    img.putpixel((11, 5), P['gray_mid'])
    img.putpixel((11, 6), P['gray_mid'])
    img.putpixel((22, 5), P['gray_mid'])
    img.putpixel((22, 6), P['gray_mid'])
    # board frame
    rect(img, 6, 7, 27, 23, P['brown_bark'])
    rect(img, 8, 9, 25, 21, P['brown_leather'])
    # mug glyph (gold)
    rect(img, 13, 12, 19, 19, P['gold_dull'])
    img.putpixel((19, 14), P['gold_dull'])
    img.putpixel((20, 14), P['gold_dull'])
    img.putpixel((19, 15), P['gold_dull'])
    img.putpixel((20, 16), P['gold_dull'])
    # mug interior darker (foam outline)
    img.putpixel((14, 13), P['bone_white'])
    img.putpixel((15, 13), P['bone_white'])
    img.putpixel((16, 13), P['bone_white'])
    img.putpixel((17, 13), P['bone_white'])
    img.save(TILES / 'tavern_sign.png')


def prop_chimney():
    """Brick chimney rising from a building roof, with smoke."""
    img = new_tile()
    # chimney column
    rect(img, 12, 4, 22, 26, P['red_rust'])
    # brick courses
    for y in (7, 12, 17, 22):
        hline(img, y, P['brown_bark'], 12, 22)
    # cap
    rect(img, 11, 4, 23, 7, P['stone_dark'])
    # smoke puffs
    img.putpixel((15, 2), P['gray_light'])
    img.putpixel((16, 2), P['gray_light'])
    img.putpixel((14, 1), P['gray_mid'])
    img.putpixel((18, 1), P['gray_mid'])
    img.putpixel((13, 0), P['gray_light'])
    img.putpixel((17, 0), P['gray_light'])
    img.save(TILES / 'chimney.png')


def prop_cage_iskar():
    """A wooden cage with Iskar inside, used in the bandit camp."""
    img = new_tile()
    # base / floor
    rect(img, 4, 26, 28, 30, P['brown_bark'])
    # top frame
    rect(img, 4, 4, 28, 8, P['brown_bark'])
    # vertical bars
    for x in (6, 11, 16, 21, 26):
        rect(img, x, 8, x + 1, 26, P['brown_bark'])
    # interior darkness
    rect(img, 7, 9, 26, 25, P['gray_darkest'])
    # bars overlay (re-paint after interior)
    for x in (6, 11, 16, 21, 26):
        rect(img, x, 8, x + 1, 26, P['brown_bark'])
    # Iskar silhouette inside
    rect(img, 12, 16, 22, 22, P['iskar_dark'])
    # head
    rect(img, 7, 16, 12, 21, P['iskar_dark'])
    # eye (ember dot)
    img.putpixel((9, 18), P['ember_orange'])
    # wing nub on back
    rect(img, 14, 13, 19, 16, P['iskar_dark'])
    # tail to the right
    rect(img, 22, 18, 25, 21, P['iskar_dark'])
    img.save(TILES / 'cage_iskar.png')


def prop_cage_empty():
    """Same cage, after Iskar is freed."""
    img = new_tile()
    rect(img, 4, 26, 28, 30, P['brown_bark'])
    rect(img, 4, 4, 28, 8, P['brown_bark'])
    for x in (6, 11, 16, 21, 26):
        rect(img, x, 8, x + 1, 26, P['brown_bark'])
    rect(img, 7, 9, 26, 25, P['gray_darkest'])
    for x in (6, 11, 16, 21, 26):
        rect(img, x, 8, x + 1, 26, P['brown_bark'])
    # broken door hint on one side: missing bar at x=21
    rect(img, 21, 8, 22, 26, (0, 0, 0, 0))
    img.save(TILES / 'cage_empty.png')


def tile_camp_dirt():
    """Trampled camp floor: warm dirt with embers / scorch hints."""
    img = new_tile()
    rng = random.Random(14)
    fill(img, P['brown_dirt'])
    speckle(img, P['brown_bark'],   0.18, rng)
    speckle(img, P['red_rust'],     0.05, rng)
    speckle(img, P['gray_dark'],    0.05, rng)
    img.save(TILES / 'camp_dirt.png')


def prop_fire_pit():
    """Stones around a low fire."""
    img = new_tile()
    rng = random.Random(15)
    # stones in a ring
    for x, y in [(10, 12), (15, 11), (20, 12), (22, 16), (20, 21),
                 (15, 22), (10, 21), (8, 16)]:
        for dx in range(-2, 3):
            for dy in range(-1, 2):
                px, py = x + dx, y + dy
                if 0 <= px < 32 and 0 <= py < 32:
                    img.putpixel((px, py), P['stone_warm'] if (dx + dy) % 2 == 0 else P['stone_dark'])
    # ember in middle
    rect(img, 13, 14, 19, 20, P['red_rust'])
    img.putpixel((15, 16), P['ember_orange'])
    img.putpixel((16, 17), P['ember_orange'])
    img.putpixel((17, 16), P['ember_orange'])
    img.save(TILES / 'fire_pit.png')


def prop_anvil():
    """A dark anvil on a wooden stump, for outside the smithy."""
    img = new_tile()
    # stump
    rect(img, 12, 20, 22, 30, P['brown_bark'])
    hline(img, 21, P['brown_leather'], 12, 22)
    hline(img, 26, P['brown_dirt'], 12, 22)
    # anvil body
    rect(img, 9, 14, 24, 20, P['gray_darkest'])
    # anvil horn (tapered right)
    rect(img, 24, 15, 27, 18, P['gray_darkest'])
    img.putpixel((27, 16), P['gray_darkest'])
    # anvil top (slightly lighter slab)
    hline(img, 14, P['gray_dark'], 9, 24)
    img.save(TILES / 'anvil.png')


# ---------------------------------------------------------------------------
# Forest tiles
# ---------------------------------------------------------------------------

def tile_forest_floor():
    """Darker, more mossy ground for the wilderness."""
    img = new_tile()
    rng = random.Random(11)
    fill(img, P['green_forest_mid'])
    speckle(img, P['green_forest_dark'], 0.25, rng)
    speckle(img, P['green_moss'],        0.10, rng)
    speckle(img, P['brown_bark'],        0.04, rng)
    # occasional root or twig
    for _ in range(2):
        x, y = rng.randint(2, 28), rng.randint(2, 28)
        img.putpixel((x, y), P['brown_dirt'])
    img.save(TILES / 'forest_floor.png')


def tile_wooden_floor():
    """Plank floor for tavern interior."""
    img = new_tile()
    rng = random.Random(13)
    fill(img, P['brown_leather'])
    # plank seams: long horizontal planks 32 wide x ~7 tall
    for y in (7, 15, 23):
        hline(img, y, P['brown_bark'])
    speckle(img, P['brown_bark'], 0.04, rng)
    speckle(img, P['brown_dirt'], 0.03, rng)
    img.save(TILES / 'wooden_floor.png')


def tile_forest_path():
    """Narrow worn path through the forest."""
    img = new_tile()
    rng = random.Random(12)
    fill(img, P['brown_dirt'])
    # earthier than the village path
    speckle(img, P['brown_bark'],   0.16, rng)
    speckle(img, P['green_moss'],   0.08, rng)
    speckle(img, P['brown_leather'], 0.04, rng)
    # one or two stones
    img.putpixel((9, 13), P['stone_warm'])
    img.putpixel((20, 24), P['stone_warm'])
    img.save(TILES / 'forest_path.png')


# ---------------------------------------------------------------------------
# Enemy sprites
# ---------------------------------------------------------------------------

def sprite_wolf():
    """A wolf seen from 3/4 view, quadruped silhouette. 48x36 for clarity."""
    img = new_tile(48, 36)
    # body
    rect(img, 12, 14, 36, 26, P['gray_mid'])
    # back hump
    rect(img, 16, 12, 28, 14, P['gray_mid'])
    # head (front-left)
    rect(img, 4, 16, 16, 24, P['gray_mid'])
    # ears - two pointy ears
    rect(img, 6, 12, 9, 16, P['gray_dark'])
    rect(img, 11, 12, 14, 16, P['gray_dark'])
    img.putpixel((7, 13), P['gray_mid'])
    img.putpixel((12, 13), P['gray_mid'])
    # snout
    rect(img, 0, 18, 6, 22, P['gray_dark'])
    img.putpixel((0, 19), P['gray_darkest'])
    img.putpixel((0, 20), P['gray_darkest'])
    # eyes (yellow, predator) -- both visible
    img.putpixel((10, 18), P['gold_dull'])
    img.putpixel((13, 18), P['gold_dull'])
    # teeth hint
    img.putpixel((2, 21), P['bone_white'])
    img.putpixel((4, 21), P['bone_white'])
    # legs (4, with paws)
    for leg_x in (14, 19, 28, 33):
        rect(img, leg_x, 26, leg_x + 3, 34, P['gray_dark'])
        rect(img, leg_x, 33, leg_x + 4, 35, P['gray_darkest'])
    # tail (curved up and back)
    rect(img, 36, 14, 42, 18, P['gray_mid'])
    rect(img, 40, 12, 44, 16, P['gray_mid'])
    img.putpixel((43, 13), P['gray_dark'])
    # belly shadow
    hline(img, 25, P['gray_dark'], 12, 36)
    hline(img, 26, P['gray_dark'], 14, 34)
    # back highlights (lighter top)
    hline(img, 14, P['gray_light'], 16, 26)
    img.save(SPRITES / 'wolf.png')


def sprite_bandit():
    """A generic bandit -- like Drust but plainer."""
    img = base_human(
        hair=P['brown_bark'],
        skin=P['flesh_ruddy'],
        shirt=P['gray_dark'],
        pants=P['brown_dirt'],
    )
    # hood
    rect(img, 7, 2, 17, 6, P['gray_darkest'])
    img.putpixel((10, 8), P['gold_dull'])    # cruel eye
    img.putpixel((13, 8), P['gold_dull'])
    # knife glint at hip
    img.putpixel((18, 19), P['gray_light'])
    img.putpixel((18, 20), P['gray_light'])
    img.save(SPRITES / 'bandit.png')


# ---------------------------------------------------------------------------
# Battle UI panel
# ---------------------------------------------------------------------------

def ui_battle_panel():
    """The bottom-of-screen battle UI panel (480 wide x 90 tall)."""
    img = Image.new('RGBA', (480, 90), TRANSPARENT)
    # dark wood fill
    rect(img, 0, 0, 480, 90, P['gray_darkest'])
    # double frame
    outline(img, 0, 0, 480, 90, P['brown_bark'])
    outline(img, 2, 2, 478, 88, P['brown_bark'])
    outline(img, 4, 4, 476, 86, P['brown_leather'])
    # corner studs
    for cx, cy in [(7, 7), (472, 7), (7, 82), (472, 82)]:
        img.putpixel((cx, cy), P['gold_dull'])
        img.putpixel((cx + 1, cy), P['gold_dull'])
        img.putpixel((cx, cy + 1), P['gold_dull'])
    # vertical divider between HP block and action menu
    vline(img, 200, P['brown_leather'], 8, 82)
    vline(img, 201, P['brown_bark'],    8, 82)
    # second divider between actions and stance
    vline(img, 360, P['brown_leather'], 8, 82)
    vline(img, 361, P['brown_bark'],    8, 82)
    img.save(UI / 'battle_panel.png')


def ui_hp_bar(name='hp_bar', fill_pct=1.0, max_w=160, h=10, color=P['red_terra']):
    """A horizontal HP bar at the given fill percentage."""
    img = Image.new('RGBA', (max_w + 4, h + 4), TRANSPARENT)
    # frame
    outline(img, 0, 0, max_w + 4, h + 4, P['brown_bark'])
    # background
    rect(img, 2, 2, max_w + 2, h + 2, P['gray_dark'])
    # fill
    fw = int(max_w * fill_pct)
    if fw > 0:
        rect(img, 2, 2, 2 + fw, h + 2, color)
    img.save(UI / f'{name}.png')


def ui_action_button(name, label_color=P['bone_white']):
    """A small button-styled label background for action menu items."""
    img = Image.new('RGBA', (140, 22), TRANSPARENT)
    rect(img, 0, 0, 140, 22, P['gray_dark'])
    outline(img, 0, 0, 140, 22, P['brown_bark'])
    img.save(UI / f'btn_{name}.png')


# ---------------------------------------------------------------------------
# Action and stance icons (16x16)
# ---------------------------------------------------------------------------

def icon_sword():
    img = Image.new('RGBA', (16, 16), TRANSPARENT)
    # diagonal blade
    for i in range(10):
        img.putpixel((3 + i, 12 - i), P['gray_light'])
        img.putpixel((3 + i, 11 - i), P['gray_light'])
    # crossguard
    img.putpixel((1, 13), P['gold_dull'])
    img.putpixel((2, 13), P['gold_dull'])
    img.putpixel((3, 13), P['gold_dull'])
    img.putpixel((4, 13), P['gold_dull'])
    # hilt
    img.putpixel((1, 14), P['brown_bark'])
    img.putpixel((2, 14), P['brown_bark'])
    img.putpixel((1, 15), P['brown_bark'])
    img.save(UI / 'icon_sword.png')


def icon_bottle():
    img = Image.new('RGBA', (16, 16), TRANSPARENT)
    # neck
    rect(img, 7, 2, 10, 5, P['brown_bark'])
    # cork
    rect(img, 7, 1, 10, 2, P['bone_white'])
    # body
    rect(img, 5, 5, 12, 14, P['red_terra'])
    rect(img, 4, 6, 13, 13, P['red_terra'])
    # highlight
    img.putpixel((6, 7), P['red_ember'])
    img.putpixel((6, 8), P['red_ember'])
    img.save(UI / 'icon_bottle.png')


def icon_shield():
    img = Image.new('RGBA', (16, 16), TRANSPARENT)
    # shield outline (rounded triangle)
    pts = [
        (5, 2), (6, 2), (7, 2), (8, 2), (9, 2), (10, 2),
        (4, 3), (11, 3),
        (3, 4), (12, 4),
        (3, 5), (12, 5),
        (3, 6), (12, 6),
        (3, 7), (12, 7),
        (3, 8), (12, 8),
        (4, 9), (11, 9),
        (5, 10), (10, 10),
        (6, 11), (9, 11),
        (7, 12), (8, 12),
    ]
    for x, y in pts:
        img.putpixel((x, y), P['gray_dark'])
    # fill interior
    for y in range(3, 12):
        for x in range(4, 12):
            if img.getpixel((x, y))[3] == 0:
                img.putpixel((x, y), P['gray_mid'])
    # boss
    img.putpixel((7, 6), P['gold_dull'])
    img.putpixel((8, 6), P['gold_dull'])
    img.putpixel((7, 7), P['gold_dull'])
    img.putpixel((8, 7), P['gold_dull'])
    img.save(UI / 'icon_shield.png')


def icon_arrow_run():
    img = Image.new('RGBA', (16, 16), TRANSPARENT)
    # arrow shaft
    hline(img, 8,  P['bone_white'], 1, 12)
    hline(img, 9,  P['bone_white'], 1, 12)
    # arrow head
    for i in range(5):
        img.putpixel((11 + i, 8 - (4 - i)), P['bone_white'])
        img.putpixel((11 + i, 8 + (4 - i)), P['bone_white'])
    # speed lines
    hline(img, 5,  P['gray_light'], 2, 6)
    hline(img, 11, P['gray_light'], 2, 6)
    img.save(UI / 'icon_arrow.png')


def icon_fist():
    """Aggressive stance icon."""
    img = Image.new('RGBA', (16, 16), TRANSPARENT)
    rect(img, 4, 5, 12, 12, P['flesh_mid'])
    # knuckles
    img.putpixel((5, 5), P['flesh_ruddy'])
    img.putpixel((7, 5), P['flesh_ruddy'])
    img.putpixel((9, 5), P['flesh_ruddy'])
    img.putpixel((11, 5), P['flesh_ruddy'])
    # thumb
    rect(img, 12, 7, 14, 10, P['flesh_mid'])
    # wrist
    rect(img, 4, 12, 12, 14, P['brown_leather'])
    img.save(UI / 'icon_fist.png')


def icon_plus():
    """Support stance icon: a green plus / leaf."""
    img = Image.new('RGBA', (16, 16), TRANSPARENT)
    rect(img, 7, 3, 9, 13, P['green_grass'])
    rect(img, 3, 7, 13, 9, P['green_grass'])
    # darker outline
    img.putpixel((7, 2), P['green_forest_dark'])
    img.putpixel((8, 2), P['green_forest_dark'])
    img.putpixel((7, 13), P['green_forest_dark'])
    img.putpixel((8, 13), P['green_forest_dark'])
    img.putpixel((2, 7), P['green_forest_dark'])
    img.putpixel((2, 8), P['green_forest_dark'])
    img.putpixel((13, 7), P['green_forest_dark'])
    img.putpixel((13, 8), P['green_forest_dark'])
    img.save(UI / 'icon_plus.png')


# ---------------------------------------------------------------------------
# Character sprites (24w x 32h, front-facing rest pose)
# ---------------------------------------------------------------------------

def base_human(hair, skin, shirt, pants, eye=P['gray_darkest']):
    """A 24x32 silhouette of a human character.

    Anatomy zones (y ranges):
      0-1   transparent margin
      2-3   hair top
      4-11  head
      12-13 neck/shoulder seam
      14-22 torso
      23-29 legs
      30-31 feet
    """
    img = new_tile(24, 32)
    # head
    rect(img, 8, 4, 16, 12, skin)
    # hair top + sides
    rect(img, 7, 2, 17, 5, hair)
    rect(img, 7, 5, 9,  9, hair)
    rect(img, 15, 5, 17, 9, hair)
    # eyes
    img.putpixel((10, 8), eye)
    img.putpixel((13, 8), eye)
    # neck
    rect(img, 10, 12, 14, 14, skin)
    # torso (shirt)
    rect(img, 6, 13, 18, 23, shirt)
    # arm shadows
    vline(img, 6,  P['gray_darkest'], 13, 23)
    vline(img, 17, P['gray_darkest'], 13, 23)
    # legs (pants)
    rect(img, 8,  23, 12, 30, pants)
    rect(img, 13, 23, 16, 30, pants)
    # gap between legs
    vline(img, 12, P['gray_darkest'], 23, 30)
    # feet
    rect(img, 8,  30, 12, 32, P['gray_darkest'])
    rect(img, 13, 30, 16, 32, P['gray_darkest'])
    return img


def sprite_kael():
    img = base_human(
        hair=P['gray_dark'],
        skin=P['flesh_mid'],
        shirt=P['brown_leather'],
        pants=P['gray_dark'],
    )
    # cloak draped over shoulders
    rect(img, 5,  13, 7,  24, P['gray_mid'])
    rect(img, 17, 13, 19, 24, P['gray_mid'])
    # hood hint
    rect(img, 7, 2, 17, 4, P['gray_mid'])
    img.save(SPRITES / 'kael.png')
    img.save(SPRITES / 'kael_south.png')


def base_human_north(hair, skin, shirt, pants):
    """Back view: same silhouette as base_human, no face. Hair covers the
    head where the face would be."""
    img = new_tile(24, 32)
    # head silhouette (back of head visible as hair)
    rect(img, 8, 4, 16, 12, hair)
    # crown highlight (slightly darker patch up top)
    rect(img, 7, 2, 17, 5, hair)
    # neck
    rect(img, 10, 12, 14, 14, skin)
    # torso (back of shirt)
    rect(img, 6, 13, 18, 23, shirt)
    # arm shadows
    vline(img, 6,  P['gray_darkest'], 13, 23)
    vline(img, 17, P['gray_darkest'], 13, 23)
    # legs
    rect(img, 8,  23, 12, 30, pants)
    rect(img, 13, 23, 16, 30, pants)
    vline(img, 12, P['gray_darkest'], 23, 30)
    # feet
    rect(img, 8,  30, 12, 32, P['gray_darkest'])
    rect(img, 13, 30, 16, 32, P['gray_darkest'])
    return img


def base_human_west(hair, skin, shirt, pants, eye=P['gray_darkest']):
    """Profile view facing left. One eye visible on the left side of the
    head; one arm dropped in front of the torso to break the silhouette."""
    img = new_tile(24, 32)
    # head: same 8x8 cell, hair offset to the right (back-of-head side)
    rect(img, 8, 4, 16, 12, skin)
    # hair: top + heavy on the right (back of skull when facing left)
    rect(img, 8, 2, 16, 5, hair)
    rect(img, 13, 5, 16, 11, hair)
    # one eye on the left
    img.putpixel((10, 8), eye)
    # neck
    rect(img, 10, 12, 14, 14, skin)
    # torso (slightly narrower silhouette in profile)
    rect(img, 7, 13, 17, 23, shirt)
    # arm draped in front (darker stripe down torso, left side)
    rect(img, 9, 14, 11, 22, P['gray_darkest'])
    # legs together in profile
    rect(img, 8,  23, 12, 30, pants)
    rect(img, 12, 23, 15, 30, pants)
    vline(img, 12, P['gray_darkest'], 23, 30)
    # feet: only one foot leads (left), the other trails behind
    rect(img, 7,  30, 12, 32, P['gray_darkest'])
    rect(img, 13, 30, 15, 32, P['gray_darkest'])
    return img


def sprite_kael_directional():
    """Emit kael_north.png, kael_east.png, kael_west.png.

    South already lives at kael.png + kael_south.png from sprite_kael()."""
    # North (back view)
    img_n = base_human_north(
        hair=P['gray_dark'],
        skin=P['flesh_mid'],
        shirt=P['brown_leather'],
        pants=P['gray_dark'],
    )
    # cloak on both shoulders, slightly wider from behind
    rect(img_n, 5,  13, 7,  24, P['gray_mid'])
    rect(img_n, 17, 13, 19, 24, P['gray_mid'])
    # hood drape over the top of the head
    rect(img_n, 7, 2, 17, 4, P['gray_mid'])
    img_n.save(SPRITES / 'kael_north.png')

    # West (profile, facing left)
    img_w = base_human_west(
        hair=P['gray_dark'],
        skin=P['flesh_mid'],
        shirt=P['brown_leather'],
        pants=P['gray_dark'],
    )
    # cloak: one panel down the back side (right side of image)
    rect(img_w, 16, 13, 18, 24, P['gray_mid'])
    # hood ridge along the top of the head
    rect(img_w, 8, 2, 16, 4, P['gray_mid'])
    img_w.save(SPRITES / 'kael_west.png')

    # East = west mirrored. Placeholder symmetry is fine; bespoke art can
    # replace this file later without touching the generator.
    img_e = img_w.transpose(Image.FLIP_LEFT_RIGHT)
    img_e.save(SPRITES / 'kael_east.png')


def sprite_mara():
    img = base_human(
        hair=P['brown_bark'],
        skin=P['flesh_pale'],
        shirt=P['red_rust'],
        pants=P['brown_bark'],
    )
    # leather apron
    rect(img, 7, 16, 17, 26, P['brown_leather'])
    # apron strap
    img.putpixel((10, 14), P['brown_bark'])
    img.putpixel((14, 14), P['brown_bark'])
    img.save(SPRITES / 'mara.png')


def sprite_orren():
    img = base_human(
        hair=P['gray_mid'],
        skin=P['flesh_ruddy'],
        shirt=P['brown_dirt'],
        pants=P['gray_dark'],
    )
    # stubble
    img.putpixel((10, 10), P['gray_dark'])
    img.putpixel((13, 10), P['gray_dark'])
    img.putpixel((11, 11), P['gray_dark'])
    img.putpixel((12, 11), P['gray_dark'])
    # slumped shoulders: shift torso down by 1 row at edges
    img.putpixel((6, 13), TRANSPARENT)
    img.putpixel((17, 13), TRANSPARENT)
    img.save(SPRITES / 'orren.png')


def sprite_toma():
    img = new_tile(24, 32)
    # smaller child silhouette: head 4-10, body 11-22, legs 23-29
    skin  = P['flesh_pale']
    hair  = P['brown_leather']
    shirt = P['green_grass']
    pants = P['brown_dirt']
    # head
    rect(img, 9, 6, 15, 12, skin)
    rect(img, 8, 4, 16, 7,  hair)
    rect(img, 8, 7, 10, 10, hair)
    rect(img, 14, 7, 16, 10, hair)
    img.putpixel((10, 9), P['gray_darkest'])
    img.putpixel((13, 9), P['gray_darkest'])
    # neck
    rect(img, 10, 12, 14, 14, skin)
    # body (shirt)
    rect(img, 7, 14, 17, 22, shirt)
    # arms
    vline(img, 7,  P['gray_darkest'], 14, 22)
    vline(img, 16, P['gray_darkest'], 14, 22)
    # legs
    rect(img, 9,  22, 12, 28, pants)
    rect(img, 13, 22, 16, 28, pants)
    vline(img, 12, P['gray_darkest'], 22, 28)
    # feet
    rect(img, 9,  28, 12, 30, P['gray_darkest'])
    rect(img, 13, 28, 16, 30, P['gray_darkest'])
    # stick "sword" in his right hand
    vline(img, 4, P['brown_bark'], 14, 22)
    img.save(SPRITES / 'toma.png')


def sprite_halden():
    img = base_human(
        hair=P['gray_light'],
        skin=P['flesh_mid'],
        shirt=P['brown_bark'],
        pants=P['gray_darkest'],
    )
    # rank chain on chest
    img.putpixel((11, 17), P['gold_dull'])
    img.putpixel((12, 17), P['gold_dull'])
    img.putpixel((13, 17), P['gold_dull'])
    img.putpixel((12, 18), P['gold_dull'])
    img.save(SPRITES / 'halden.png')


def sprite_edda():
    img = base_human(
        hair=P['gray_light'],
        skin=P['flesh_pale'],
        shirt=P['gray_dark'],
        pants=P['gray_dark'],
    )
    # robe: shirt extends fully down (no separate legs)
    rect(img, 6, 13, 18, 30, P['gray_dark'])
    # white collar
    rect(img, 9, 13, 15, 15, P['bone_white'])
    # feet under robe
    rect(img, 8, 30, 12, 32, P['gray_darkest'])
    rect(img, 13, 30, 16, 32, P['gray_darkest'])
    img.save(SPRITES / 'edda.png')


def sprite_iskar():
    """Baby drake. Reptilian silhouette with folded wings, horn nub,
    back-spine ridges, and a spiked tail. Facing left, 3/4 view, 32x24."""
    img = new_tile(32, 24)

    # body (lizardy oval)
    rect(img, 9, 11, 22, 19, P['iskar_dark'])

    # head (slightly raised above body line)
    rect(img, 4, 11, 11, 16, P['iskar_dark'])
    # snout taper
    rect(img, 2, 13, 5, 16, P['iskar_dark'])
    img.putpixel((1, 14), P['iskar_dark'])
    img.putpixel((1, 15), P['iskar_dark'])
    # jaw underline
    img.putpixel((2, 17), P['iskar_dark'])
    img.putpixel((3, 17), P['iskar_dark'])
    img.putpixel((4, 17), P['iskar_dark'])

    # horn nub (top of head)
    img.putpixel((7, 9), P['iskar_dark'])
    img.putpixel((8, 9), P['iskar_dark'])
    img.putpixel((7, 10), P['iskar_dark'])
    img.putpixel((8, 10), P['iskar_dark'])

    # back-spine ridges (three triangle bumps along the body)
    for sx in (13, 16, 19):
        img.putpixel((sx, 9),  P['iskar_dark'])
        img.putpixel((sx, 10), P['iskar_dark'])
        img.putpixel((sx - 1, 10), P['iskar_dark'])
        img.putpixel((sx + 1, 10), P['iskar_dark'])

    # folded wing (sticks up clearly above the shoulder)
    # leading edge
    rect(img, 11, 6, 13, 11, P['iskar_dark'])
    # membrane back to body
    pts = [
        (13, 6), (14, 7), (15, 7), (16, 8), (17, 8),
        (12, 7), (13, 8), (14, 8), (15, 9), (16, 9), (17, 9), (18, 10),
        (13, 9), (14, 9), (15, 10), (16, 10), (17, 10),
    ]
    for x, y in pts:
        img.putpixel((x, y), P['iskar_dark'])
    # membrane interior shadow (slightly lighter)
    img.putpixel((14, 9), P['gray_darkest'])
    img.putpixel((15, 9), P['gray_darkest'])

    # tail (thicker at base, tapering with a spike at the end)
    rect(img, 22, 13, 27, 16, P['iskar_dark'])
    rect(img, 26, 14, 29, 16, P['iskar_dark'])
    # spike tip (arrowhead)
    img.putpixel((29, 13), P['iskar_dark'])
    img.putpixel((30, 14), P['iskar_dark'])
    img.putpixel((30, 15), P['iskar_dark'])
    img.putpixel((29, 16), P['iskar_dark'])
    img.putpixel((31, 15), P['iskar_dark'])

    # legs (4, splayed out from body sides)
    # front legs
    rect(img, 10, 19, 12, 22, P['iskar_dark'])
    rect(img, 14, 19, 16, 22, P['iskar_dark'])
    # back legs
    rect(img, 18, 19, 20, 22, P['iskar_dark'])
    rect(img, 21, 19, 23, 22, P['iskar_dark'])

    # claws (small white pixels at foot tips)
    for cx in (10, 12, 14, 16, 18, 20, 21, 23):
        img.putpixel((cx, 22), P['bone_white'])
        img.putpixel((cx, 23), P['iskar_dark'])

    # eye (ember-orange, slightly bigger)
    img.putpixel((6, 13), P['ember_orange'])
    img.putpixel((7, 13), P['ember_orange'])
    img.putpixel((7, 12), P['ember_orange'])

    # teeth
    img.putpixel((2, 16), P['bone_white'])
    img.putpixel((4, 16), P['bone_white'])

    # belly highlight (slightly warmer)
    hline(img, 18, P['gray_dark'], 9, 22)

    img.save(SPRITES / 'iskar.png')


def sprite_iskar_directional():
    """Iskar in all four facings, all at a uniform 32x32. West and east
    keep the existing side-profile artwork (mirrored). North and south
    are bespoke top-down 3/4 views — drake walking toward / away from
    the camera — drawn directly so the snout/back-of-skull reads at a
    glance instead of a rotated profile."""
    base = Image.open(SPRITES / 'iskar.png').convert('RGBA')

    def framed(src):
        frame = Image.new('RGBA', (32, 32), TRANSPARENT)
        ox = (32 - src.width) // 2
        oy = (32 - src.height) // 2
        frame.paste(src, (ox, oy), src)
        return frame

    framed(base).save(SPRITES / 'iskar_west.png')
    framed(base.transpose(Image.FLIP_LEFT_RIGHT)).save(SPRITES / 'iskar_east.png')
    _iskar_south().save(SPRITES / 'iskar_south.png')
    _iskar_north().save(SPRITES / 'iskar_north.png')


def _iskar_south():
    """Top-down 3/4 view, drake facing south (toward the camera). Tail
    at top; head + snout + ember eyes at the bottom edge."""
    img = Image.new('RGBA', (32, 32), TRANSPARENT)
    # Tail spike at top
    rect(img, 14, 5, 18, 10, P['iskar_dark'])      # tail base
    rect(img, 15, 2,  17, 6,  P['iskar_dark'])     # spike pointing up
    # Rear legs (near tail)
    rect(img, 7,  9,  10, 13, P['iskar_dark'])
    rect(img, 22, 9,  25, 13, P['iskar_dark'])
    # Folded wings along the upper torso
    rect(img, 7,  12, 12, 19, P['iskar_dark'])
    rect(img, 20, 12, 25, 19, P['iskar_dark'])
    # Main body oval
    rect(img, 11, 10, 21, 24, P['iskar_dark'])
    # Spine ridges down the middle (slightly darker)
    img.putpixel((15, 12), P['gray_darkest'])
    img.putpixel((16, 12), P['gray_darkest'])
    img.putpixel((15, 16), P['gray_darkest'])
    img.putpixel((16, 16), P['gray_darkest'])
    img.putpixel((15, 20), P['gray_darkest'])
    img.putpixel((16, 20), P['gray_darkest'])
    # Front legs (near head)
    rect(img, 8,  20, 11, 24, P['iskar_dark'])
    rect(img, 21, 20, 24, 24, P['iskar_dark'])
    # Head bulge protruding south
    rect(img, 12, 23, 20, 28, P['iskar_dark'])
    # Snout tapering toward the camera
    rect(img, 13, 27, 19, 30, P['iskar_dark'])
    rect(img, 14, 29, 18, 31, P['iskar_dark'])
    # Horn nubs where the head meets the body
    img.putpixel((13, 23), P['iskar_dark'])
    img.putpixel((19, 23), P['iskar_dark'])
    # Ember eyes
    img.putpixel((14, 25), P['ember_orange'])
    img.putpixel((17, 25), P['ember_orange'])
    img.putpixel((14, 26), P['ember_orange'])
    img.putpixel((17, 26), P['ember_orange'])
    # Teeth at the snout tip
    img.putpixel((15, 30), P['bone_white'])
    img.putpixel((16, 30), P['bone_white'])
    return img


def _iskar_north():
    """Top-down 3/4 view, drake facing north (away from camera). Head
    at the top — back of skull, no face — and tail at the bottom."""
    img = Image.new('RGBA', (32, 32), TRANSPARENT)
    # Back of head / skull at top (no eyes, no snout)
    rect(img, 12, 4,  20, 9,  P['iskar_dark'])
    # Horn nubs sticking up
    img.putpixel((13, 2), P['iskar_dark'])
    img.putpixel((14, 3), P['iskar_dark'])
    img.putpixel((18, 3), P['iskar_dark'])
    img.putpixel((19, 2), P['iskar_dark'])
    # Front legs (near head)
    rect(img, 8,  8,  11, 12, P['iskar_dark'])
    rect(img, 21, 8,  24, 12, P['iskar_dark'])
    # Folded wings along the mid-torso
    rect(img, 7,  13, 12, 20, P['iskar_dark'])
    rect(img, 20, 13, 25, 20, P['iskar_dark'])
    # Main body oval
    rect(img, 11, 8,  21, 23, P['iskar_dark'])
    # Spine ridges (visible from behind)
    img.putpixel((15, 11), P['gray_darkest'])
    img.putpixel((16, 11), P['gray_darkest'])
    img.putpixel((15, 15), P['gray_darkest'])
    img.putpixel((16, 15), P['gray_darkest'])
    img.putpixel((15, 19), P['gray_darkest'])
    img.putpixel((16, 19), P['gray_darkest'])
    # Rear legs (near tail)
    rect(img, 7,  19, 10, 23, P['iskar_dark'])
    rect(img, 22, 19, 25, 23, P['iskar_dark'])
    # Tail base + spike pointing south
    rect(img, 14, 22, 18, 27, P['iskar_dark'])
    rect(img, 15, 26, 17, 30, P['iskar_dark'])
    return img


# ---------------------------------------------------------------------------
# UI placeholders
# ---------------------------------------------------------------------------

def ui_dialogue_box():
    img = Image.new('RGBA', (480, 96), TRANSPARENT)
    # parchment fill
    rect(img, 0, 0, 480, 96, P['bone_white'])
    # double frame
    outline(img, 0, 0, 480, 96, P['brown_bark'])
    outline(img, 2, 2, 478, 94, P['brown_bark'])
    outline(img, 4, 4, 476, 92, P['brown_leather'])
    # corner nails
    for cx, cy in [(6, 6), (473, 6), (6, 89), (473, 89)]:
        img.putpixel((cx, cy), P['gold_dull'])
    img.save(UI / 'dialogue_box.png')


def ui_option_button():
    img = Image.new('RGBA', (220, 28), TRANSPARENT)
    rect(img, 0, 0, 220, 28, P['gray_dark'])
    outline(img, 0, 0, 220, 28, P['brown_bark'])
    img.save(UI / 'option_button.png')


def ui_portrait_frame():
    img = Image.new('RGBA', (64, 64), TRANSPARENT)
    rect(img, 0, 0, 64, 64, P['gray_darkest'])
    outline(img, 0, 0, 64, 64, P['brown_bark'])
    outline(img, 2, 2, 62, 62, P['brown_leather'])
    img.save(UI / 'portrait_frame.png')


# ---------------------------------------------------------------------------
# Run
# ---------------------------------------------------------------------------

def main():
    print('Generating tiles...')
    tile_grass()
    tile_path()
    tile_cobble()
    tile_well_water()
    tile_well_stone()
    tile_wood_wall()
    tile_thatched_roof()
    tile_chapel_stone()
    tile_door()
    tile_notice_board()
    tile_window()

    print('Generating props...')
    prop_tree()
    prop_lantern()
    prop_barrel()
    prop_flower_patch()
    prop_tavern_sign()
    prop_chimney()
    prop_anvil()
    prop_cage_iskar()
    prop_cage_empty()
    prop_fire_pit()

    print('Generating forest/camp tiles...')
    tile_camp_dirt()

    print('Generating forest tiles...')
    tile_forest_floor()
    tile_forest_path()

    print('Generating interior tiles...')
    tile_wooden_floor()

    print('Generating sprites...')
    sprite_kael()
    sprite_kael_directional()
    sprite_mara()
    sprite_orren()
    sprite_toma()
    sprite_halden()
    sprite_edda()
    sprite_iskar()
    sprite_iskar_directional()
    sprite_wolf()
    sprite_bandit()

    print('Generating UI elements...')
    ui_dialogue_box()
    ui_option_button()
    ui_portrait_frame()
    ui_battle_panel()
    ui_hp_bar('hp_bar_kael',  0.85, color=P['red_terra'])
    ui_hp_bar('hp_bar_iskar', 0.60, color=P['ember_orange'])
    ui_hp_bar('hp_bar_wolf',  0.35, color=P['red_rust'])
    ui_action_button('attack')
    ui_action_button('item')
    ui_action_button('defend')
    ui_action_button('flee')

    print('Generating icons...')
    icon_sword()
    icon_bottle()
    icon_shield()
    icon_arrow_run()
    icon_fist()
    icon_plus()

    print('Done. See game/assets/')


if __name__ == '__main__':
    main()
