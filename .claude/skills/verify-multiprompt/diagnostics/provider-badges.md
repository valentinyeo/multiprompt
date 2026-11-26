# Provider badges

Each chat avatar in the sidebar carries a small solid triangle tucked into its top right corner that shows which AI the chat currently runs. The triangle reads the chat's resolved provider, never its name, avatar colour or message text.

## Sub-features

- Claude, `#D97757`.
- Codex, `#10A37F`.
- Antigravity, `#3C78DC`.
- Pi, `#8E95A2`.
- The triangle is a sharp right triangle whose right angle sits in the avatar's top right bounding corner, Version A of Figma frame 313:23. Its legs run `10px` on the ordinary 36px avatar and scale with the avatar: `16px` on the 56px pinned tile, `8px` on the 28px collapsed rail, `15px` at 144 DPI. A dark `#000000` separator border frames it at `1px` on the 36px avatar and `2px` from the 54px avatar up, drawn as a slightly larger black right triangle behind the coloured one. The pair stays inside the avatar bounding box: it covers the rounded corner cut instead of being clipped by it, so the mark reads as a corner flag and never as a crescent sliver. A photo avatar is a circle, so the same sharp triangle sits at the circle's bounding corner. There is no ring, letter or other glyph in it.
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
4. Read the `[photo-proof]` avatar rectangles from `debug.log` and capture the triangle square in each avatar's top right corner. Its side is `max(6, floor((avatar side * 10 + 18) / 36))` and its separator border is `max(1, floor((avatar side + 18) / 36))`.
5. Classify every pixel of that square against two nested right triangles: the outer one at the bounding corner and the inner one inset by the border. A pixel wholly inside the inner triangle and a pixel clear of every fill edge must be the provider colour, a pixel wholly between the two triangles must be dark separator, a pixel wholly outside the outer triangle must not be the provider colour, and only the anti-aliased boundaries may blend. Require a solid body, a present separator whenever the border is `2px`, no near-white pixel anywhere in the square, and no provider colour in the one-pixel bands just right of and above the avatar.
6. Hold Ctrl and require the four points of a ring around the jump circle centre, at `3/8` of its side from the centre, to be white on the top left corner; release and require that corner to match the pixels captured just before Ctrl again.
7. Hover the avatar of a recent row (index 2). Pinned tiles paint no preview line, so only a recent row repaints its second line with the provider name and the model and effort the chat reports.
8. Collapse the sidebar with Ctrl+Shift+B and repeat the pixel sampling on the rail avatars.

`tools/verify-provider-badges/drive.ps1` runs these checks at 96 and 144 DPI. `.github/workflows/provider-badges.yml` owns the nightly proof. Before merge, `node tools/provider-badges-native.test.js` runs the same unit proof and both DPI drives on a branch through `test-repeat.yml`, because a new workflow cannot be dispatched until it exists on the default branch. The unit proof first swaps in `tools/fixtures/MUBO-568/provider-badge-before.zig`, the chat-name version, and `tools/fixtures/MUBO-568/provider-badge-round.zig`, the round badge with a white glyph, and requires the named provider test to fail at runtime, not merely to compile.

## Gotchas

- The triangle must never be painted from the chat name, the avatar palette colour, the robot colour or text on screen. Only the shell's resolved `ai_agent` counts.
- Model and effort come from the live chat settings the reader reports. Unknown values are omitted, never guessed.
- Pi's `#8E95A2` sits within 26 levels of the robot's `#9A9A9A` antenna and body detail, so the drive matches it with a `9` per-channel tolerance: at `10` or more a neutral grey can satisfy every channel at once, which counts robot pixels as badge pixels and fails a clean avatar as if a badge had leaked.
- The separator is drawn as a black right triangle behind the coloured one, not as a stroke: a stroke straddles the bounding edge and paints a half-covered colour pixel outside the avatar.
- The triangle is solid, so any white pixel in its square means a glyph. A `2px` border must still own at least four wholly bordered pixels; otherwise the separator vanished.
- The sharp corner is the point of Version A. A crescent clipped to the rounded corner, an inset triangle, or a triangle that stops short of the bounding corner all fail the native proof.
- The oracle classifies a pixel as fill only when all four of its corners sit inside the inner triangle a whole pixel clear of every edge, separator only when all four sit between the two triangles, and outside only when all four are outside the outer triangle, leaving every boundary unchecked. The one-pixel clearance absorbs the half-pixel phase GDI+ gives a polygon edge, which would otherwise land a half-black pixel in the fill class. That is what lets the drawn edge stay anti-aliased without the proof demanding the flat provider colour on an edge pixel.
- Chat previews are not a restore signal: only the open chat refreshes its preview, and an ordinary terminal never carries one. Wait on `ag` and on the `[photo-proof]` rectangles instead.
- Pinned tiles carry the triangle and the jump digit but no preview line, so a hover check has to target a recent row.
- A test in a file reachable only through an `@import` inside a function body is invisible to `zig build test-provider-badges`: the filtered build never analyzes that function, so the file's tests are not in the binary and the step passes in 23ms with zero tests. `src/main.zig` carries an unnamed `test { _ = @import("provider_badge.zig"); }` bridge, which the test filter never drops, and a named guard that fails unless all six provider proofs are in `builtin.test_functions`. Keep both when adding a proof.
- Figma frame 313:23 is the source for both the colours and the sharp corner. `poWCM.png` reports the orange fill as `D97757`, the separator as pure black, and a coloured leg of `17px` inside a `22px` outer leg on a `72px` tile, which is the `10px` and `1px` pair at the 36px avatar.
