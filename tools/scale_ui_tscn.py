"""
One-shot: double pixel-valued layout literals in game/scenes/ui/*.tscn for
the 480x270 -> 960x540 viewport bump. Run once; do not commit a re-run.

Doubles:
  offset_left/right/top/bottom = <float>
  position = Vector2(x, y) / Vector2i(x, y)
  custom_minimum_size = Vector2(x, y)
  size = Vector2(x, y)            (NOT size_flags_*)
  theme_override_font_sizes/<key> = <int>
  theme_override_constants/<key>  = <int>     (margins/separation/etc.)
  content_margin_<edge> = <float>             (StyleBoxFlat padding)
  border_width_<edge>   = <int>                (StyleBoxFlat border, pixel)

Skips:
  anchor_*  (0..1 normalized)
  size_flags_*  (bitflag enum)
  layer, z_index, layout_mode  (enums)
  Color(...), bg_color, border_color  (RGB floats)
"""
from __future__ import annotations
import re
from pathlib import Path

SCALE = 2
ROOT  = Path(__file__).resolve().parents[1]
UIDIR = ROOT / 'game' / 'scenes' / 'ui'

# Properties whose RHS is a single number (int or float) we double.
NUMERIC_PROPS = re.compile(
    r'^(\s*)(offset_(?:left|right|top|bottom)|'
    r'content_margin_(?:left|right|top|bottom)|'
    r'border_width_(?:left|right|top|bottom)|'
    r'theme_override_font_sizes/[A-Za-z0-9_]+|'
    r'theme_override_constants/[A-Za-z0-9_]+)'
    r'\s*=\s*(-?\d+(?:\.\d+)?)\s*$'
)

# Vector2/Vector2i RHS for properties we double.
VECTOR_PROPS = re.compile(
    r'^(\s*)(position|custom_minimum_size|size)\s*=\s*'
    r'(Vector2i?)\(\s*(-?\d+(?:\.\d+)?)\s*,\s*(-?\d+(?:\.\d+)?)\s*\)\s*$'
)


def scale_number(match: re.Match) -> str:
    indent, prop, val = match.group(1), match.group(2), match.group(3)
    n = float(val)
    n2 = n * SCALE
    rendered = f'{n2:g}' if '.' in val else str(int(n2))
    return f'{indent}{prop} = {rendered}'


def scale_vector(match: re.Match) -> str:
    indent, prop, ctor, x, y = match.groups()
    def fmt(s: str) -> str:
        n = float(s) * SCALE
        return f'{n:g}' if '.' in s else str(int(n))
    return f'{indent}{prop} = {ctor}({fmt(x)}, {fmt(y)})'


def process(path: Path) -> int:
    text = path.read_text()
    new_lines = []
    changes = 0
    for line in text.splitlines():
        m = NUMERIC_PROPS.match(line)
        if m:
            new_lines.append(scale_number(m))
            changes += 1
            continue
        m = VECTOR_PROPS.match(line)
        if m:
            new_lines.append(scale_vector(m))
            changes += 1
            continue
        new_lines.append(line)
    if changes:
        path.write_text('\n'.join(new_lines) + ('\n' if text.endswith('\n') else ''))
    return changes


def main() -> None:
    total = 0
    for tscn in sorted(UIDIR.glob('*.tscn')):
        n = process(tscn)
        print(f'  {tscn.name}: {n} line(s) scaled')
        total += n
    print(f'Done. {total} lines scaled across {len(list(UIDIR.glob("*.tscn")))} files.')


if __name__ == '__main__':
    main()
