# Group rail

## Sub-features

- Default groups retain a continuous gray rail beside their unselected sessions.
- Each rail starts at its header bar's left edge, below the header, and ends at its last member's bottom edge.
- Adjacent groups have separate rails; neither rail paints inside a header or another group's rows.
- The rail never crosses the active session highlight or its border.
- No rail extends into the ungrouped sessions below the last group.

## How to get to it (user POV)

- Ctrl+K `new cmd` creates another session.
- Ctrl+K `move to group`, then `new group`, creates a group for the active session.
- Select another session, use Move to Group and choose the saved group name.
- Ctrl+1 and Ctrl+2 select the first group's sessions without changing their membership.

## Driving it with control.ps1

Dispatch `gh workflow run verify.yml --ref <branch> -f feature=group-rail`. The pull-request matrix also runs this journey. Use `-f tag=v0.28.822` for the left-edge/header-crossing negative control, then omit tag to verify the branch build with the identical driver. The earlier `v0.28.819` release also provides the selected-highlight negative control.

1. Launch the isolated real Windows app, pass Doctor, choose Dark through Themes and select Tab Order: Manual through Ctrl+K `tab order`, Down, Enter before creating another session. This existing setting keeps session indices aligned with visible rows. Print `group-rail verified release tag=... version=...` and retain checksum/version provenance in build.json.
2. Rename the original CMD to Rail A through F2, create a second real CMD session through Ctrl+K and rename it Rail B. Create a group for it through Move to Group, keep its default name, select the original session with Ctrl+1 and move it into the same group through the palette. Create four more real CMD sessions named Rail C through Rail F. Create a second group for Rail C and move Rail D into it. Require exactly two groups with two members each and six sessions, with Rail E and Rail F ungrouped; never seed app data. Manual ordering places the two groups back to back, followed by the ungrouped rows.
3. Select each first-group session in turn with Ctrl+1 and Ctrl+2. Require the persisted active tab, then capture group-rail-selected-0.png and group-rail-selected-1.png, UIA and native focus evidence. Short synthetic names keep the highlight reference column free of text.
4. Obtain the owned main frame and client origin through Win32. Use the actual DPI and saved UI scale for sidebar and session-row geometry. Locate the first gray-tinted header fill independently of the rail, allowing either visible or hidden workspace pills; group headers retain their production fixed height of 28 pixels. Locate each header's leftmost fill column and each rail's leftmost gray column in an unselected member. Require their x coordinates to match. Require the original rail width and every gray pixel down all three unselected member rows, so an absent or shortened rail cannot pass.
5. Across the full vertical range of both headers, require zero rail-colored pixels distinct from the header's own fill and no mismatch against the unobstructed header fill at the right. At the boundary between groups, require the second header to remain clear, its last scanline to retain the header fill, and the second rail to begin on the next scanline, below the header. Require the final member's last scanline to contain the rail and the next scanline to be clear.
6. Keep the original highlight comparison at every pixel of the old inset rail band, from the active highlight's top border to its bottom border. Require a visibly blue reference highlight and zero mismatches against the unobstructed same-scanline highlight (RGB tolerance three). Additionally require zero gray rail pixels (tolerance two) across the entire left-edge search band for the whole active row, including the rounded corners.
7. Sample the entire left-edge search band below the second group's last member, through the ungrouped section header and both ungrouped rows. Require zero gray rail pixels, retaining at least the original full-row-height stray check. Save counts, both measured header/rail x coordinates, header positions, sample rectangles, highlight color, geometry, session state and version in matching JSON files.
8. After both selections, print exactly `group-rail left-edge PASS`, `group-rail header-clear PASS`, `group-rail groups-separate PASS`, `group-rail selected-clear PASS` and `group-rail stray-clear PASS` only if their respective assertions hold; print the corresponding FAIL marker otherwise and throw if any check fails. Inspect both screenshots, action.png, after.png, result.json, build.json and owned-job cleanup.

## Gotchas

- The sidebar currently draws no hovered-row highlight. This journey covers both positions of the active highlight; it does not invent a hover state or claim multi-selection coverage.
- The original highlight-color comparison stays at the inset band because the new rail x lies on the highlight's rounded left boundary. The new whole-row gray-pixel exclusion also covers that boundary without treating rounded corners as flat fill.
- The cyan horizontal ETA progress line is a separate session indicator, not a group rail. This journey has no ETA fixtures and does not change or suppress that indicator.
- The app supplies session/group state; the driver only reads it. The explicit offline-login boundary does not verify sign-in, SSH, live agents or remote synchronization.
- A v0.28.822 negative-control run must reach `group-rail left-edge FAIL`, `group-rail header-clear FAIL` and `group-rail groups-separate FAIL`; a launch, parser or geometry failure is not failing-first rendering proof.
- The pane-layout pixel proof also requires a left-aligned rail exactly one member-row high and samples the icon in that row, not in the header or the following ungrouped row.
