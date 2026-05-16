# UI Context

## Theme

Grim-fairy-tale pixel art. Warm late-medieval village
palette: stone-grey cobble, weathered timber, lantern
amber, mossy grass. Sprites are blocky and chunky —
character figures are ~24 pixels tall on a 64 px tile
grid. The viewport is a fixed 960×540 internal
resolution scaled to 1920×1080 (2×) window — every UI
decision is sized at the 960×540 layer first. The aesthetic
is *believable old, slightly tired*, not pretty fantasy.
No dark-mode/light-mode switch: the game is what it is.

UI panels overlay the world; the world keeps rendering
behind them. Panels are opaque, wood-toned, with a
2 px brown-black border. Text is rendered in Godot's
bundled default sans (see Typography below).

## Colors

All colors are sampled from the existing pixel-art tile
set and the current dialogue/combat overlays. Hex
values below are approximations of the on-screen palette
— treat them as the authoritative tokens.

| Role                | Token                  | Value      | Where it appears                       |
| ------------------- | ---------------------- | ---------- | -------------------------------------- |
| Grass / outside     | `--world-grass`        | `#3F5230`  | Outdoor tile fill                      |
| Cobble / square     | `--world-cobble`       | `#6E6E6E`  | Village square paving                  |
| Path / dirt         | `--world-path`         | `#7A5A35`  | Forest paths, doorways                 |
| Building wood       | `--world-wood`         | `#8B5A2B`  | Houses, smithy, chapel timber          |
| Building stone      | `--world-stone`        | `#9A8E78`  | Foundations, well                      |
| Water               | `--world-water`        | `#2F6F8F`  | Well surface                           |
| UI panel background | `--ui-panel-bg`        | `#2E1F12`  | Dialogue box, combat menu, journal     |
| UI panel border     | `--ui-panel-border`    | `#1A0F08`  | 1 px outer border of every panel       |
| UI inset highlight  | `--ui-panel-inset`     | `#5C3F22`  | Inner trim on dialogue / combat panel  |
| Primary text        | `--text-primary`       | `#E8DCC0`  | Dialogue, NPC names, menu options      |
| Muted text          | `--text-muted`         | `#A08A6A`  | Bottom-bar hints, item counts          |
| Selected option     | `--accent-selected`    | `#C57A2E`  | Highlighted dialogue option row        |
| Selected text       | `--accent-selected-fg` | `#FFFFFF`  | Text on the selected option row        |
| HP bar (good)       | `--bar-hp`             | `#C57A2E`  | Kael / Iskar HP fill                   |
| HP bar (enemy)      | `--bar-hp-enemy`       | `#9A3A2E`  | Wolf / bandit / Drust HP fill          |
| Bar track           | `--bar-track`          | `#3A2A1A`  | Empty section of every HP bar          |
| Lantern / fire      | `--accent-fire`        | `#E8B040`  | Lantern, Ember-Spark flash, burn tick  |
| Iskar (drake)       | `--accent-drake`       | `#3C2A2A`  | Iskar follower sprite                  |
| Warning             | `--state-warning`      | `#C57A2E`  | Quest toast, low HP flash              |
| Danger              | `--state-danger`       | `#9A3A2E`  | Hostile NPC line tone, death prompt    |

The palette is small on purpose. Do not add a new color
without retiring one — every UI element should map to a
token in this list.

## Typography

Godot's bundled default sans (no custom theme file).
At the 960×540 layer, font sizes 16–20 px render
crisp without the chunkiness that a bitmap pixel
font produces at this scale. A Pixelify Sans TTF was
trialled at this same scale on 2026-05-16 and
rejected — the bundled sans read cleaner and held
weight better at small dialogue sizes. If a custom
font is added later, do it via
`gui/theme/custom` in `project.godot` (not per-Label
overrides) so the swap is one line.

| Role               | Size  | Notes                              |
| ------------------ | ----- | ---------------------------------- |
| Body / dialogue    | 18 px | NPC line, journal entries          |
| Option rows        | 18 px | Numbered options + Offer / LineEdit|
| NPC name (heading) | 20 px | Uppercased, no bold                |
| Tone / muted hints | 16 px | "-- neutral", bottom-bar hints     |
| Debug overlay      | 16 px | Backtick-toggled key=value column  |

Sizes were doubled when the viewport bumped from
480×270 to 960×540 (was 9 / 10 / 8). Larger headings
remain rendered at the same family — no second font.

## Border Radius

Pixel art does not have rounded corners. Every panel is a
rectangle with a 1 px outer border. Do not introduce
rounded corners or anti-aliased edges; they break the
aesthetic.

| Context           | Treatment                          |
| ----------------- | ---------------------------------- |
| Dialogue box      | Sharp rectangle, 1 px dark border, 1 px inset trim |
| Combat menu       | Sharp rectangle, 1 px dark border  |
| Toast / quest pop | Sharp rectangle, no inset trim     |
| NPC portrait box  | Sharp rectangle, framed in panel border color |

## Component Library

No third-party UI kit. UI is built from Godot Control
nodes inside scenes under `game/scenes/ui/`. The reusable
patterns are:

- **DialogueBox** (`scripts/ui/DialogueBox.gd`,
  `scenes/ui/DialogueBox.tscn`) — portrait + name +
  tone tag + body + numbered option list with a
  free-text row. Anchored bottom-center, fills the
  lower third of the viewport.
- **CombatOverlay** (`scripts/ui/CombatOverlay.gd`) —
  Kael/Iskar HP bars on the left, action menu in the
  center, stance picker on the right when Iskar is
  bonded, narration strip across the top.
- **JournalPanel** (`scripts/ui/JournalPanel.gd`) —
  category tabs (people / places / events / items)
  with a free-text query row at the bottom.
- **InteractionPrompt** (`scripts/ui/InteractionPrompt.gd`) —
  `[E] Talk to Mara` floating label above an NPC.
- **ItemPicker** (`scripts/ui/ItemPicker.gd`) — modal
  for the "Offer item" verb.
- **QuestToast** (`scripts/ui/QuestToast.gd`) — short
  upper-right banner on quest state change.
- **DebugOverlay** (`scripts/ui/DebugOverlay.gd`,
  `scenes/ui/DebugOverlay.tscn`) — autoloaded;
  toggled by the backtick key. Shows topic detection,
  capability gate result, retrieved briefings, raw
  model JSON, validation outcome, memory delta.
- **TitleCard** (`scripts/ui/TitleCard.gd`,
  `scenes/ui/TitleCard.tscn`) — autoloaded; covers
  the whole viewport for opening/closing beats.

When you need a new UI element, extend one of these
scenes — do not invent a new visual idiom.

## Layout Patterns

- **World scene** — full-viewport tile map, no chrome.
  Camera is fixed for the village (which fits the
  viewport); the forest scene scrolls as Kael moves.
- **Dialogue box** — anchored bottom, ~340 px tall in
  the 960×540 layer (the lower ~63%), full width. The world dims
  slightly behind it; movement input is suppressed
  while it's open.
- **Combat overlay** — anchored bottom, slightly
  taller than the dialogue box. HP bars left, menu
  center, stance right. The encounter sprites
  remain visible above.
- **Journal** — covers most of the viewport; world is
  paused behind it.
- **Quest toast** — anchored upper-right; auto-dismisses.
- **Title card** — full-viewport black background with
  centered text.
- **Debug overlay** — anchored left edge, vertical
  column of key=value lines. Always on top.

Every overlay obeys one rule: while it is visible,
player movement is suppressed and `SaveBlocker` refuses
to save mid-turn.

## Icons

No iconography library. The handful of glyphs in the UI
(quest icon, stance indicators, action icons) are
hand-drawn at 8–12 px and live alongside the tile
art under `game/assets/`. Stance indicators currently
use plain text labels (`AGGR.`, `DEF.`, `SUPP.`) — when
art is added, replace the labels in place rather than
creating a separate icon component.
