"""
Convert /data/ (YAML + Markdown-with-frontmatter) to /game/data/ (JSON).

Godot has no native YAML parser. Converting at build time keeps the engine
side simple and dependency-free: every game-data file ends up as JSON, which
Godot reads natively.

Output:
  /game/data/_index.json           manifest of everything
  /game/data/topics.json           topic taxonomy
  /game/data/facts.json            fact registry
  /game/data/npc/<id>.json         NPC profile + dossier
  /game/data/briefings/<type>/<id>.<tier>.json   briefings (full schema + body)

Briefings keep their `tier` distinction in the filename and in their record,
so (id, tier) is the lookup key — matching the data/briefings/ layout.

Run from the repo root: python3 tools/yaml_to_json.py
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path
from typing import Any

import yaml


ROOT     = Path(__file__).resolve().parents[1]
SRC      = ROOT / 'data'
DST      = ROOT / 'game' / 'data'


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

FRONTMATTER_RE = re.compile(
    r"\A---\s*\n(.*?)\n---\s*\n(.*)\Z",
    re.DOTALL,
)


def parse_markdown_briefing(text: str, src_path: Path) -> dict[str, Any]:
    """Parse a markdown briefing with YAML frontmatter into a dict.

    Body is included under the `body` key.
    """
    match = FRONTMATTER_RE.match(text)
    if not match:
        raise ValueError(f"{src_path}: no YAML frontmatter")
    front_raw, body = match.group(1), match.group(2).strip()
    front = yaml.safe_load(front_raw) or {}
    if not isinstance(front, dict):
        raise ValueError(f"{src_path}: frontmatter must be a mapping, got {type(front).__name__}")
    front['body'] = body
    return front


def write_json(path: Path, data: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n")


# ---------------------------------------------------------------------------
# Conversions
# ---------------------------------------------------------------------------

def convert_topics() -> dict[str, Any]:
    src = SRC / 'topics.yaml'
    data = yaml.safe_load(src.read_text())
    write_json(DST / 'topics.json', data)
    return data


def convert_facts() -> dict[str, Any]:
    src = SRC / 'facts.yaml'
    data = yaml.safe_load(src.read_text())
    write_json(DST / 'facts.json', data)
    return data


def convert_tile_collision() -> dict[str, Any]:
    src = SRC / 'tile_collision.yaml'
    if not src.exists():
        return {}
    data = yaml.safe_load(src.read_text())
    write_json(DST / 'tile_collision.json', data)
    return data


def convert_items() -> dict[str, Any]:
    src = SRC / 'items.yaml'
    if not src.exists():
        return {}
    data = yaml.safe_load(src.read_text())
    write_json(DST / 'items.json', data)
    return data


def convert_combatants() -> dict[str, Any]:
    src = SRC / 'combatants.yaml'
    if not src.exists():
        return {}
    data = yaml.safe_load(src.read_text())
    write_json(DST / 'combatants.json', data)
    return data


def convert_npcs() -> list[dict[str, Any]]:
    """Convert every .yaml under data/npc/. Returns the list of npc records."""
    records: list[dict[str, Any]] = []
    for src in sorted((SRC / 'npc').glob('*.yaml')):
        data = yaml.safe_load(src.read_text())
        if not isinstance(data, dict) or 'id' not in data:
            raise ValueError(f"{src}: missing `id`")
        out = DST / 'npc' / f"{data['id']}.json"
        write_json(out, data)
        records.append({'id': data['id'], 'file': out.relative_to(DST).as_posix()})
    return records


def convert_fallback_lines() -> list[dict[str, Any]]:
    """Convert every .yaml under data/fallback_lines/. One file per NPC,
    plus _archetype.yaml for archetype-keyed last-resort lines."""
    records: list[dict[str, Any]] = []
    fb_dir = SRC / 'fallback_lines'
    if not fb_dir.exists():
        return records
    for src in sorted(fb_dir.glob('*.yaml')):
        data = yaml.safe_load(src.read_text())
        if not isinstance(data, dict):
            raise ValueError(f"{src}: top level must be a mapping")
        npc_id = src.stem
        out = DST / 'fallback_lines' / f'{npc_id}.json'
        write_json(out, data)
        records.append({'npc_id': npc_id, 'file': out.relative_to(DST).as_posix()})
    return records


def convert_options() -> list[dict[str, Any]]:
    """Convert every .yaml under data/options/. One file per NPC."""
    records: list[dict[str, Any]] = []
    opt_dir = SRC / 'options'
    if not opt_dir.exists():
        return records
    for src in sorted(opt_dir.glob('*.yaml')):
        data = yaml.safe_load(src.read_text())
        if not isinstance(data, dict):
            raise ValueError(f"{src}: top level must be a mapping")
        npc_id = src.stem
        out = DST / 'options' / f'{npc_id}.json'
        write_json(out, data)
        records.append({'npc_id': npc_id, 'file': out.relative_to(DST).as_posix()})
    return records


def convert_briefings() -> list[dict[str, Any]]:
    """Convert every briefing markdown under data/briefings/.

    Filename convention `id.tier.md` is honored: events have `tower_smoke.witness.md`
    and `tower_smoke.rumor.md`; non-events have a single `id.md`. We use the
    frontmatter `id` and `tier` as the canonical keys; the filename is just
    routing.
    """
    records: list[dict[str, Any]] = []
    for src in sorted((SRC / 'briefings').rglob('*.md')):
        text = src.read_text()
        rec = parse_markdown_briefing(text, src)
        for required in ('id', 'tier', 'type', 'title', 'topic_tags'):
            if required not in rec:
                raise ValueError(f"{src}: missing required field `{required}`")
        # Output path mirrors the source subdir to keep the layout debuggable.
        rel_subdir = src.parent.relative_to(SRC / 'briefings')
        out_name = src.stem  # e.g. "tower_smoke.witness"
        out = DST / 'briefings' / rel_subdir / f"{out_name}.json"
        write_json(out, rec)
        records.append({
            'id':    rec['id'],
            'tier':  rec['tier'],
            'type':  rec['type'],
            'file':  out.relative_to(DST).as_posix(),
            'topic_tags': rec.get('topic_tags', []),
        })
    return records


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def copy_shared_assets() -> None:
    """Copy files that the proxy and the game both consume."""
    proxy_data = ROOT / 'proxy' / 'data'
    pairs = [
        (proxy_data / 'mock_responses.json',         DST / 'mock_responses.json'),
        (proxy_data / 'mock_classify_rules.json',    DST / 'mock_classify_rules.json'),
        (proxy_data / 'mock_player_suggestions.json', DST / 'mock_player_suggestions.json'),
    ]
    for src, dst in pairs:
        if not src.exists():
            continue
        dst.parent.mkdir(parents=True, exist_ok=True)
        dst.write_text(src.read_text())
        print(f"  copied {src.relative_to(ROOT)} -> {dst.relative_to(ROOT)}")


def main() -> int:
    if not SRC.exists():
        print(f"ERROR: source not found: {SRC}", file=sys.stderr)
        return 1

    print(f"Converting {SRC} -> {DST}")

    # Wipe only the subdirs and files this script owns. Anything emitted by
    # other tools (e.g. /game/data/scenes/ from generate_scene.py) is left
    # alone.
    OWNED_SUBDIRS  = ['npc', 'briefings', 'options', 'fallback_lines']
    OWNED_TOPLEVEL = ['topics.json', 'facts.json', 'tile_collision.json',
                      'items.json', 'combatants.json', 'mock_responses.json',
                      'mock_classify_rules.json', 'mock_player_suggestions.json',
                      '_index.json']
    for sub in OWNED_SUBDIRS:
        d = DST / sub
        if d.exists():
            for p in d.rglob('*'):
                if p.is_file():
                    p.unlink()
    for name in OWNED_TOPLEVEL:
        f = DST / name
        if f.exists():
            f.unlink()
    DST.mkdir(parents=True, exist_ok=True)

    topics      = convert_topics()
    facts       = convert_facts()
    _collision  = convert_tile_collision()
    _items      = convert_items()
    _combatants = convert_combatants()
    npcs        = convert_npcs()
    briefings   = convert_briefings()
    options     = convert_options()
    fallback    = convert_fallback_lines()

    n_topics    = len(topics.get('topics', {}))
    n_facts     = len(facts.get('facts', {}))
    n_npcs      = len(npcs)
    n_briefings = len(briefings)
    n_options   = len(options)

    index = {
        'counts': {
            'topics':    n_topics,
            'facts':     n_facts,
            'npcs':      n_npcs,
            'briefings': n_briefings,
            'options':   n_options,
        },
        'topics_file': 'topics.json',
        'facts_file':  'facts.json',
        'npcs':        npcs,
        'briefings':   briefings,
        'options':     options,
        'fallback':    fallback,
    }
    write_json(DST / '_index.json', index)

    print(f"  {n_topics:>3} topics")
    print(f"  {n_facts:>3} facts")
    print(f"  {n_npcs:>3} npcs")
    print(f"  {n_briefings:>3} briefings")
    print(f"  {n_options:>3} option banks")
    print(f"  {len(fallback):>3} fallback banks")
    print(f"Wrote {DST}/_index.json")
    copy_shared_assets()
    return 0


if __name__ == '__main__':
    sys.exit(main())
