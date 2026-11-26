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

1. Seed `session.json` with five tmux tabs, four carrying `ai_agent` 1, 2, 3 and 8 plus a `csid`, and the names chosen to contradict the provider. Every tab carries palette colour 6 (teal), which is far from all four triangle colours, so the avatar body can never be mistaken for a mark.
2. Launch `--no-window-restore` with the verification boundary as the reader.
3. Require the restored list in `inbox-default.json` to publish all five shells in tab order, each carrying the seeded name and the expected `ag`. The badge reads `ag`, so `ag` is the provider-ready precondition; the message preview is loaded lazily for the open chat only and an ordinary terminal never carries one, so previews cannot stand in for provider identity.
4. Read the `[photo-proof]` avatar rectangles from `debug.log` and capture the flush triangle square in each avatar's top right corner. Its side is `round(10 * avatar side / 36)` and its corner radius is `round(22 * avatar side / 100)`.
5. Classify every pixel of that square against the accepted shape: the right triangle `y <= x` intersected with the avatar corner circle. A pixel wholly inside the shape must be the provider colour, a pixel wholly outside it must not be, and only the anti-aliased boundary may blend. Require a solid body, no near-white pixel anywhere in the square, and no provider colour just outside the avatar's top and right edges.
6. Hold Ctrl and require the four points of a ring around the jump circle centre, at `3/8` of its side from the centre, to be white on the top left corner; release and require that corner to match the pixels captured just before Ctrl again.
7. Hover the avatar of a recent row (index 2). Pinned tiles paint no preview line, so only a recent row repaints its second line with the provider name and the model and effort the chat reports.
8. Collapse the sidebar with Ctrl+Shift+B and repeat the shape sampling on the rail avatars.

`tools/verify-provider-badges/drive.ps1` runs these checks at 96 and 144 DPI. `.github/workflows/provider-badges.yml` owns the nightly proof. Before merge, `node tools/provider-badges-native.test.js` runs the same unit proof and both DPI drives on a branch through `test-repeat.yml`, because a new workflow cannot be dispatched until it exists on the default branch. The unit proof first swaps in `tools/fixtures/MUBO-568/provider-badge-before.zig`, the chat-name version, and `tools/fixtures/MUBO-568/provider-badge-round.zig`, the round badge with a white glyph, and requires the named provider test to fail at runtime, not merely to compile.

## Gotchas

- The triangle must never be painted from the chat name, the avatar palette colour, the robot colour or text on screen. Only the shell's resolved `ai_agent` counts.
- Model and effort come from the live chat settings the reader reports. Unknown values are omitted, never guessed.
- A pixel sample is only meaningful away from the anti-aliased boundary: the corner circle passes within one pixel of most of a 10px triangle, so a fixed body point such as `(2/3, 1/4)` lands on a blended edge. Classify the whole square instead.
- The triangle is solid, so any white pixel in its square means a glyph, and any provider colour in the corner cut means the avatar corner is not respected.
- A flush triangle is clipped by the rounded corner. Painting it over the bounding corner, or insetting it by a fixed 4px, both fail the native proof.
- Palette colour 4 is the same lilac as the Antigravity triangle and colour 0 is the same green as Pi, so a seeded avatar using either hides the shape proof. Colour 6 is used instead.
- Chat previews are not a restore signal: only the open chat refreshes its preview, and an ordinary terminal never carries one. Wait on `ag` and on the `[photo-proof]` rectangles instead.
- Pinned tiles carry the triangle and the jump digit but no preview line, so a hover check has to target a recent row.
- A test in a file reachable only through an `@import` inside a function body is invisible to `zig build test-provider-badges`: the filtered build never analyzes that function, so the file's tests are not in the binary and the step passes in 23ms with zero tests. `src/main.zig` carries an unnamed `test { _ = @import("provider_badge.zig"); }` bridge, which the test filter never drops, and a named guard that fails unless all five provider proofs are in `builtin.test_functions`. Keep both when adding a proof.
- Figma frame 313:23 was not readable by the building agent, so the Antigravity and Pi colours are the incumbent `bot_avatar.zig` palette entries, not sampled from Figma.
