"""
Generate `village_square.tscn` + `village_square_grid.json` for Godot 4.

The scene is a flat grid of 32x32 tile sprites + prop sprites + NPC sprites,
with a Player scene instance and two UI overlays (interaction prompt,
notice-board overlay) wired in. The grid JSON is the gameplay-side logical
map; WorldState autoload reads it at runtime.

Layout (15 cols x 9 rows):

  Row 0:  G  T  T  T  T  T  G  S  S  S  S  S  G  G  G
  Row 1:  G  T  V  T  V  T  G  S  V  S  V  S  G  G  G
  Row 2:  G  T  T  D  T  T  G  S  S  D  S  S  G  G  G
  Row 3:  G  C  C  C  C  C  C  C  C  C  C  C  C  C  G
  Row 4:  G  C  C  C  C  C  C  Ws C  C  C  C  C  C  G
  Row 5:  G  C  C  C  C  C  C  Ww C  C  C  C  C  C  G
  Row 6:  G  C  C  C  N  C  C  C  C  C  C  C  C  C  G
  Row 7:  G  C  C  C  C  C  C  P  C  C  C  C  C  C  G
  Row 8:  G  G  G  G  G  G  G  P  G  G  G  G  G  G  G
"""

import json
from pathlib import Path

ROOT       = Path(__file__).resolve().parents[1]
GAME       = ROOT / 'game'
SCENES     = GAME / 'scenes'
DATA_DIR   = GAME / 'data' / 'scenes'
SCENES.mkdir(parents=True, exist_ok=True)
DATA_DIR.mkdir(parents=True, exist_ok=True)

TILE = 32
COLS = 15
ROWS = 9

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
assert all(len(r) == COLS for r in LAYOUT), [len(r) for r in LAYOUT]


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
    raise ValueError(f"unknown layout char: {c!r} at row {row}")


PROPS = [
    # trees in grass corners
    (0,  1, 'tree'),
    (14, 1, 'tree'),
    (0,  6, 'tree'),
    (14, 6, 'tree'),
    # tavern dressing
    (3,  1, 'tavern_sign'),
    (5,  3, 'lantern'),
    # smithy dressing
    (8,  0, 'chimney'),
    (10, 3, 'anvil'),
    (12, 3, 'barrel'),
    # ground details
    (1,  4, 'flower_patch'),
    (13, 7, 'flower_patch'),
]


# Static NPC sprites (Kael is the player and is *not* in this list).
# x_offset = horizontal pixel offset inside the tile so a 24-wide sprite
# centres in a 32-wide tile. y_offset lets a character sit slightly higher
# (e.g. Toma "perches" on the well rim).
CHARACTERS = [
    # (col, row, ox, oy, sprite, name, id, facing)
    (6,  4, 4,  0, 'toma',   'Toma',   'toma_child',      'south'),  # next to the well
    (9,  3, 4,  0, 'mara',   'Mara',   'mara_blacksmith', 'south'),  # outside smithy door
    (4,  3, 4,  0, 'orren',  'Orren',  'orren_drunk',     'south'),  # outside tavern door
    (11, 7, 4,  0, 'halden', 'Halden', 'halden_reeve',    'west'),   # in the square, facing the path
    (3,  7, 4,  0, 'edda',   'Edda',   'edda_priest',     'east'),   # walking near south path
]

# World objects the player can interact with (tile, kind, id, label).
OBJECTS = [
    (4, 6, 'notice_board', 'notice_board', 'the notice'),
]

# Map exits. South tile leads to the forest_edge scene (Phase 7).
EXITS = [
    (7, 8, 'south', 'forest_edge'),
]

PLAYER_START = (7, 6)


def emit_scene() -> None:
    """Emit the .tscn (visual + scene composition)."""
    resources: dict[str, str] = {}
    next_id = [1]

    def res(name: str) -> str:
        if name not in resources:
            resources[name] = f"{next_id[0]}_{name}"
            next_id[0] += 1
        return resources[name]

    # First pass: register textures.
    for r, line in enumerate(LAYOUT):
        for c, ch in enumerate(line):
            res(tile_for(ch, r))
    for _col, _row, prop in PROPS:
        res(prop)
    for _col, _row, _ox, _oy, sprite, _name, _id, _facing in CHARACTERS:
        res(sprite)

    # Sub-scenes that are instanced into the world.
    PACKED = {
        'player_scene':            'res://scenes/world/PlayerCharacter.tscn',
        'iskar_follower':          'res://scenes/world/IskarFollower.tscn',
        'interaction_prompt':      'res://scenes/ui/InteractionPrompt.tscn',
        'notice_board_overlay':    'res://scenes/ui/NoticeBoardOverlay.tscn',
        'quest_toast':             'res://scenes/ui/QuestToast.tscn',
    }

    lines: list[str] = []
    load_steps = len(resources) + len(PACKED) + 1
    lines.append(f"[gd_scene load_steps={load_steps} format=3]")
    lines.append("")

    sprite_names = {'kael', 'mara', 'orren', 'toma', 'halden', 'edda', 'iskar'}
    for name, rid in resources.items():
        subdir = 'sprites' if name in sprite_names else 'tiles'
        lines.append(
            f'[ext_resource type="Texture2D" path="res://assets/{subdir}/{name}.png" id="{rid}"]'
        )
    for key, path in PACKED.items():
        lines.append(f'[ext_resource type="PackedScene" path="{path}" id="{key}"]')
    lines.append("")

    # Root
    lines.append('[node name="VillageSquare" type="Node2D"]')
    lines.append("")

    # Tiles
    lines.append('[node name="Tiles" type="Node2D" parent="."]')
    lines.append("")
    for r, row_str in enumerate(LAYOUT):
        for c, ch in enumerate(row_str):
            tex = tile_for(ch, r)
            rid = resources[tex]
            lines.append(f'[node name="T_{c:02d}_{r:02d}_{tex}" type="Sprite2D" parent="Tiles"]')
            lines.append(f'texture = ExtResource("{rid}")')
            lines.append('centered = false')
            lines.append(f'position = Vector2({c * TILE}, {r * TILE})')
            lines.append("")

    # Props
    lines.append('[node name="Props" type="Node2D" parent="."]')
    lines.append("")
    for col, row, prop in PROPS:
        rid = resources[prop]
        lines.append(f'[node name="P_{col:02d}_{row:02d}_{prop}" type="Sprite2D" parent="Props"]')
        lines.append(f'texture = ExtResource("{rid}")')
        lines.append('centered = false')
        lines.append(f'position = Vector2({col * TILE}, {row * TILE})')
        lines.append("")

    # Static NPCs (Kael is the player, handled separately).
    lines.append('[node name="Characters" type="Node2D" parent="."]')
    lines.append("")
    for col, row, ox, oy, sprite, name, _id, _facing in CHARACTERS:
        rid = resources[sprite]
        lines.append(f'[node name="{name}" type="Sprite2D" parent="Characters"]')
        lines.append(f'texture = ExtResource("{rid}")')
        lines.append('centered = false')
        lines.append(f'position = Vector2({col * TILE + ox}, {row * TILE + oy})')
        lines.append("")

    # Player instance
    px = PLAYER_START[0] * TILE + 4
    py = PLAYER_START[1] * TILE
    lines.append('[node name="Player" parent="." instance=ExtResource("player_scene")]')
    lines.append(f'position = Vector2({px}, {py})')
    lines.append("")

    lines.append('[node name="IskarFollower" parent="." instance=ExtResource("iskar_follower")]')
    lines.append("")

    # UI overlays
    lines.append('[node name="InteractionPrompt" parent="." instance=ExtResource("interaction_prompt")]')
    lines.append("")
    lines.append('[node name="NoticeBoardOverlay" parent="." instance=ExtResource("notice_board_overlay")]')
    lines.append("")
    lines.append('[node name="QuestToast" parent="." instance=ExtResource("quest_toast")]')
    lines.append("")

    out = SCENES / 'village_square.tscn'
    out.write_text("\n".join(lines))
    print(f"Wrote {out}")


def emit_grid() -> None:
    """Emit the logical grid JSON consumed by WorldState."""
    tiles = []
    for r, line in enumerate(LAYOUT):
        for c, ch in enumerate(line):
            tiles.append({"col": c, "row": r, "tile": tile_for(ch, r)})
    props = [{"col": c, "row": r, "prop": p} for c, r, p in PROPS]
    npcs  = [{"id": i, "col": c, "row": r, "facing": f} for c, r, _ox, _oy, _sp, _n, i, f in CHARACTERS]
    objects = [{"id": i, "type": t, "col": c, "row": r, "label": lbl} for c, r, t, i, lbl in OBJECTS]
    exits = [{"col": c, "row": r, "direction": d, "target": t} for c, r, d, t in EXITS]
    grid = {
        "size":          {"cols": COLS, "rows": ROWS},
        "tile_size":     TILE,
        "player_start":  {"col": PLAYER_START[0], "row": PLAYER_START[1]},
        "tiles":         tiles,
        "props":         props,
        "npcs":          npcs,
        "objects":       objects,
        "exits":         exits,
    }
    out = DATA_DIR / 'village_square_grid.json'
    out.write_text(json.dumps(grid, indent=2))
    print(f"Wrote {out}")


def main():
    emit_scene()
    emit_grid()


if __name__ == '__main__':
    main()
