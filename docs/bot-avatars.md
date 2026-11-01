# Robot faces and workspace colors

## Face identity

Both apps hash the raw tmux session name. Editable titles and hosts never affect the face. Hash exact UTF-8 bytes using unsigned FNV-1a. Start at `2166136261`, XOR each byte, then multiply by `16777619`, wrapping at 32 bits. Face index is `hash % 20`.

Reference faces: `agent-one` → 15; `agent-two` → 13; `机器人` → 9. Local desktop consoles use their names.

Manual choices retain stable IDs 0 through 19. Auto keeps the face field absent. Window transfers use sentinel 20 for Auto. It is not a manual face ID. Resetting Auto remains an explicit user choice.

Twelve drawings represent the twenty IDs:

| IDs | Head and eyes |
|---|---|
| 0, 12 | Circle, dots |
| 1, 13 | Square, squares |
| 2, 14 | Squircle, happy |
| 3, 15 | Wide, dashes |
| 4, 16 | Tall, one eye |
| 5, 17 | Circle, wink |
| 6, 18 | Square, dots |
| 7, 19 | Squircle, dashes |
| 8 | Wide, happy |
| 9 | Tall, dots |
| 10 | Circle, squares |
| 11 | Wide, one eye |

Choices keep their exact stored IDs. Repeated drawings do not share checkmarks. Automatic faces still use `hash % 20`. Android's matching update uses this same mapping. Old clients keep displaying their old drawings. New clients display the new drawings. Both keep exchanging the same IDs.

## Workspace colors

The shared account workspace order assigns default colors. Index is workspace position modulo seven. Local filters and session ordering never affect colors. Every session within one workspace shares its color. Colors repeat only after exhausting the palette.

Palette order:

| Index | Color | Hex |
|---|---|---|
| 0 | Sage | `#95DE69` |
| 1 | Clay | `#FF6F28` |
| 2 | Sand | `#FFC455` |
| 3 | Mist | `#5A9AE9` |
| 4 | Lilac | `#9F6CFC` |
| 5 | Rose | `#FF667B` |
| 6 | Mint | `#5EFED1` |

White and grey are never palette choices. Heads have dark visors and light eyes.

## Change a color

Open Settings and find the workspace. Choose one of its seven palette dots. Auto restores its position-based default. Picks recolor its faces immediately. Account sync carries picks between desktop and phone. Offline edits persist until account sync succeeds.

Workspace JSON carries an optional `color` integer, from zero through six. An absent field means automatic color. Clients advertise `workspace_color` through `X-Layout-Features`. The service hides colors from legacy clients. Legacy writes preserve previously stored overrides. Three-way merging retains unrelated remote color changes. Local picks and explicit resets win conflicts.

## Visual evidence

The visual workflows use Cedar, Orbit, and Lagoon. They capture three default colors and Settings pickers. Picker interactions also verify recoloring. Desktop proof checks persisted color metadata. Android proof checks inbox and reader colors. Both workflows accept `ceo/IGSH-1172-generic` pushes.
