# Provider badges

Each chat avatar in the sidebar carries a small solid triangle inside its top right corner that shows which AI the chat currently runs. The triangle reads the chat's resolved provider, never its name, avatar colour or message text.

## Sub-features

- Claude, `#D97757`.
- Codex, `#3C78DC`.
- Antigravity, `#A77FE0`.
- Pi, `#8FCB6B`.
- The triangle is a right triangle whose right angle sits in the avatar's top right corner. Its legs run `10px` on the ordinary 36px avatar and scale with the avatar: `16px` on the 56px pinned tile, `8px` on the 28px collapsed rail. It is clipped to the avatar's rounded corner, so it fills that corner without painting outside the avatar. A photo avatar is a circle, so its triangle sits tangent inside the circle instead. There is no ring, border, letter or other glyph in it.
- Jump digits keep the top left corner, the robot marker keeps the bottom right corner, and the pin and collapsed layouts carry the same triangle.
- Hovering a chat row replaces the message preview with the provider name plus the model and effort the chat reports about itself.

## User entry points

- The sidebar list, pinned rows and collapsed rail.
- Hover any chat row.
- Switch AI from the tab menu or Ctrl+K: the triangle follows the chat to its new provider.

## Driving it

1. Seed `session.json` with five tmux tabs, four carrying `ai_agent` 1, 2, 3 and 8 plus a `csid`, and the names chosen to contradict the provider.
2. Launch `--no-window-restore` with the verification boundary as the reader.
3. Read the `[photo-proof]` avatar rectangles from `debug.log` and capture the flush triangle square in each avatar's top right corner. Its side is `round(10 * avatar side / 36)`.
4. Require the provider colour in the triangle body, the row background at the square's bottom left and at the rounded top right corner, no near-white pixel anywhere in it, no provider colour just outside the avatar's top and right edges, and none near the top left or bottom right corners.
5. Hold Ctrl and sample the jump digit on the top left corner; release and confirm it is gone.
6. Hover the second row and confirm the row's second line repaints.
7. Collapse the sidebar with Ctrl+Shift+B and repeat the triangle sampling on the rail avatars.

`tools/verify-provider-badges/drive.ps1` runs these checks at 96 and 144 DPI. `.github/workflows/provider-badges.yml` owns the nightly proof. Before merge, `node tools/provider-badges-native.test.js` runs the same unit proof and both DPI drives on a branch through `test-repeat.yml`, because a new workflow cannot be dispatched until it exists on the default branch. The unit proof first swaps in `tools/fixtures/MUBO-568/provider-badge-before.zig`, the chat-name version, and `tools/fixtures/MUBO-568/provider-badge-round.zig`, the round badge with a white glyph, and requires a named test to fail for each.

## Gotchas

- The triangle must never be painted from the chat name, the avatar palette colour, the robot colour or text on screen. Only the shell's resolved `ai_agent` counts.
- Model and effort come from the live chat settings the reader reports. Unknown values are omitted, never guessed.
- The triangle is solid, so any white pixel in its square means a glyph and any provider colour at the square's bottom left means a round badge.
- A flush triangle is clipped by the rounded corner. Painting it over the bounding corner, or insetting it by a fixed 4px, both fail the native proof.
- Palette colour 4 is the same lilac as the Antigravity triangle, so a workspace using it hides the absent-badge assertion.
- Figma frame 313:23 was not readable by the building agent, so the Antigravity and Pi colours are the incumbent `bot_avatar.zig` palette entries, not sampled from Figma.
