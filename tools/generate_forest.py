"""
Generate `forest_edge.tscn` + `forest_edge_grid.json`.

The forest is the second scene of the demo. Single 15x9 screen with:
  - bandit camp clearing at the top (rows 0-3)
  - thin forest path running south from the camp to the village exit
  - encounter sprites (wolf, bandit pair) placed adjacent to the path
  - Iskar's cage at the heart of the camp; Drust paces beside it

Player enters from the south, walks north up the path, fights encounters,
clears the camp, frees Iskar, then heads back south to return to the village.

Phase 7 Increment 1: emits the visual + grid only. Combat will come in
Increment 2; the bonding scripted beat in Increment 3.
"""

import json
from pathlib import Path

ROOT     = Path(__file__).resolve().parents[1]
GAME     = ROOT / 'game'
SCENES   = GAME / 'scenes'
DATA_DIR = GAME / 'data' / 'scenes'
SCENES.mkdir(parents=True, exist_ok=True)
DATA_DIR.mkdir(parents=True, exist_ok=True)

TILE = 64
COLS = 15
ROWS = 9

# Tile chars:
#   F = forest_floor
#   P = forest_path
#   D = camp_dirt
LAYOUT = [
    "FFFFFFFFFFFFFFF",
    "FFDDDDDDDDDFFFF",
    "FFDDDDDDDDDFFFF",
    "FFDDDDDDDDDFFFF",
    "FFFFFFPFFFFFFFF",
    "FFFFFFPFFFFFFFF",
    "FFFFFFPFFFFFFFF",
    "FFFFFFPFFFFFFFF",
    "FFFFFFPFFFFFFFF",
]
assert all(len(r) == COLS for r in LAYOUT), [len(r) for r in LAYOUT]


def tile_for(ch: str, _row: int) -> str:
    if ch == 'F':  return 'forest_floor'
    if ch == 'P':  return 'forest_path'
    if ch == 'D':  return 'camp_dirt'
    raise ValueError(f"unknown layout char: {ch!r}")


# Decoration props placed on the map. The cage is the dramatic centrepiece.
PROPS = [
    # trees framing the forest borders
    (0,  4, 'tree'),
    (14, 4, 'tree'),
    (0,  6, 'tree'),
    (14, 6, 'tree'),
    (3,  4, 'tree'),
    (11, 4, 'tree'),
    # camp dressing
    (4,  2, 'fire_pit'),
    (8,  2, 'cage_iskar'),
    (3,  3, 'barrel'),
]


# Encounters: enemies on the map, sitting directly on the path so the
# player must defeat them to progress. After Phase 7 Increment 2 wires
# combat, defeating one removes the sprite + tile-blocking.
#
# Tuple: (col, row, sprite_offset_x, sprite_offset_y, sprite, combatant,
#         display_name, encounter_id). Drust shares the bandit sprite on the
# overworld but resolves to his own combatant block in combat.
CHARACTERS = [
    (6,  7, 4, 0, 'bandit', 'bandit', 'Bandit1', 'bandit_path_b'),
    (6,  5, 4, 0, 'wolf',   'wolf',   'Wolf1',   'wolf_path_a'),
    (6,  2, 4, 0, 'bandit', 'drust',  'Drust',   'drust_camp'),
]

# World objects player can interact with on the map.
OBJECTS = [
    # Cage interaction (Phase 7 Increment 3 will wire the bonding beat).
    (8, 2, 'cage', 'iskar_cage', "Iskar's cage"),
]

# Exits. Walking off the south edge returns to the village.
EXITS = [
    (6, 8, 'south', 'village_square'),
]

# Player arrives at the bottom of the forest path when coming from the
# village; named entry point so SceneRouter can pick the right tile.
ENTRY_POINTS = {
    # facing "north": arriving from the village edge, Kael is looking
    # into the forest. Defaults to "south" if unset.
    "default":          {"col": 6, "row": 8, "facing": "north"},
    "from_village":     {"col": 6, "row": 8, "facing": "north"},
}
PLAYER_START = (6, 8)


def emit_scene() -> None:
    resources: dict[str, str] = {}
    next_id = [1]
    def res(name: str) -> str:
        if name not in resources:
            resources[name] = f"{next_id[0]}_{name}"
            next_id[0] += 1
        return resources[name]

    for r, line in enumerate(LAYOUT):
        for c, ch in enumerate(line):
            res(tile_for(ch, r))
    for _c, _r, prop in PROPS:
        res(prop)
    for _c, _r, _ox, _oy, sprite, _cb, _n, _id in CHARACTERS:
        res(sprite)

    PACKED = {
        'player_scene':            'res://scenes/world/PlayerCharacter.tscn',
        'iskar_follower':          'res://scenes/world/IskarFollower.tscn',
        'interaction_prompt':      'res://scenes/ui/InteractionPrompt.tscn',
        'quest_toast':             'res://scenes/ui/QuestToast.tscn',
        'cage_overlay':            'res://scenes/ui/CageOverlay.tscn',
    }

    lines: list[str] = []
    load_steps = len(resources) + len(PACKED) + 1
    lines.append(f"[gd_scene load_steps={load_steps} format=3]")
    lines.append("")

    sprite_names = {'kael', 'mara', 'orren', 'toma', 'halden', 'edda',
                    'iskar', 'wolf', 'bandit'}
    for name, rid in resources.items():
        subdir = 'sprites' if name in sprite_names else 'tiles'
        lines.append(
            f'[ext_resource type="Texture2D" path="res://assets/{subdir}/{name}.png" id="{rid}"]'
        )
    for key, path in PACKED.items():
        lines.append(f'[ext_resource type="PackedScene" path="{path}" id="{key}"]')
    lines.append("")

    lines.append('[node name="ForestEdge" type="Node2D"]')
    lines.append("")

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

    lines.append('[node name="Props" type="Node2D" parent="."]')
    lines.append("")
    for col, row, prop in PROPS:
        rid = resources[prop]
        lines.append(f'[node name="P_{col:02d}_{row:02d}_{prop}" type="Sprite2D" parent="Props"]')
        lines.append(f'texture = ExtResource("{rid}")')
        lines.append('centered = false')
        lines.append(f'position = Vector2({col * TILE}, {row * TILE})')
        lines.append("")

    lines.append('[node name="Encounters" type="Node2D" parent="."]')
    lines.append("")
    for col, row, ox, oy, sprite, combatant, name, eid in CHARACTERS:
        rid = resources[sprite]
        lines.append(f'[node name="{name}" type="Sprite2D" parent="Encounters"]')
        lines.append(f'texture = ExtResource("{rid}")')
        lines.append('centered = false')
        lines.append(f'position = Vector2({col * TILE + ox}, {row * TILE + oy})')
        lines.append(f'metadata/encounter_id = "{eid}"')
        lines.append(f'metadata/combatant_id = "{combatant}"')
        lines.append("")

    px = PLAYER_START[0] * TILE + 4
    py = PLAYER_START[1] * TILE
    lines.append('[node name="Player" parent="." instance=ExtResource("player_scene")]')
    lines.append(f'position = Vector2({px}, {py})')
    lines.append("")

    lines.append('[node name="IskarFollower" parent="." instance=ExtResource("iskar_follower")]')
    lines.append("")
    lines.append('[node name="InteractionPrompt" parent="." instance=ExtResource("interaction_prompt")]')
    lines.append("")
    lines.append('[node name="QuestToast" parent="." instance=ExtResource("quest_toast")]')
    lines.append("")
    lines.append('[node name="CageOverlay" parent="." instance=ExtResource("cage_overlay")]')
    lines.append("")

    out = SCENES / 'forest_edge.tscn'
    out.write_text("\n".join(lines))
    print(f"Wrote {out}")


def emit_grid() -> None:
    tiles = []
    for r, line in enumerate(LAYOUT):
        for c, ch in enumerate(line):
            tiles.append({"col": c, "row": r, "tile": tile_for(ch, r)})
    props      = [{"col": c, "row": r, "prop": p} for c, r, p in PROPS]
    encounters = [{"id": eid, "sprite": sp, "combatant": cb, "col": c, "row": r}
                  for c, r, _ox, _oy, sp, cb, _n, eid in CHARACTERS]
    objects    = [{"id": i, "type": t, "col": c, "row": r, "label": lbl}
                  for c, r, t, i, lbl in OBJECTS]
    exits      = [{"col": c, "row": r, "direction": d, "target": t}
                  for c, r, d, t in EXITS]
    grid = {
        "size":           {"cols": COLS, "rows": ROWS},
        "tile_size":      TILE,
        "player_start":   {"col": PLAYER_START[0], "row": PLAYER_START[1]},
        "entry_points":   ENTRY_POINTS,
        "tiles":          tiles,
        "props":          props,
        "encounters":     encounters,
        "objects":        objects,
        "exits":          exits,
        # `npcs` is empty here -- forest encounters are different from
        # dialogue NPCs. WorldState still treats encounters as solid.
        "npcs":           [],
    }
    out = DATA_DIR / 'forest_edge_grid.json'
    out.write_text(json.dumps(grid, indent=2))
    print(f"Wrote {out}")


def main():
    emit_scene()
    emit_grid()


if __name__ == '__main__':
    main()
