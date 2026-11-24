# Group headlines

Source files: src/workspaces.zig, src/workspace*, src/session.zig, src/sidebar.zig, src/main.zig, build.zig, build.zig.zon, src/command_palette.zig, src/shortcuts.zig, .claude/skills/verify-multiprompt/control-feature-group-rail.ps1, tools/fixtures/IGSH-1150/*

Verify on: push

## Sub-features

- Each expanded-sidebar group has a small, muted, left-aligned headline in the preview font. It preserves its name case, with no fill, colored rail or chevron.
- The sidebar background remains visible across both edges of each headline row.
- Sessions retain their existing indentation, icons, highlights and row heights beneath the headline; adjacent groups and ungrouped sessions remain separate.
- Clicking the headline uses the existing group collapse action: members disappear and return, and the same collapsed memory is saved.
- The built-in Recents label uses the same label style as a group headline: same font height, #8A8A8A color and left edge, with no arrow in front of it.
- The new-tab plus no longer appears below sessions.
- Group color choices, right-click palette, rename, drag and drop, Ctrl+G and collapsed-sidebar mode are unchanged.

## How to get to it (user POV)

- Ctrl+K `new cmd` creates another session.
- Ctrl+K `move to group`, then `new group`, creates a group for the active session.
- Select another session, use Move to Group and choose the saved group name.
- Click the group headline once to hide its sessions, then again to show them.

## Driving it with control.ps1

Dispatch `gh workflow run verify.yml --ref <branch> -f feature=group-rail`. The journey name and pull-request matrix entry stay unchanged. Run the identical branch driver with `-f tag=v0.28.861` as the negative control, then omit the tag for the branch build.

1. Launch the isolated real Windows app, pass Doctor, choose Dark through Themes and select Tab Order: Manual through Ctrl+K `tab order`, Down, Enter before creating another session. Print `group-rail verified release tag=... version=...` and retain checksum/version provenance in build.json.
2. Keep the existing real-session setup: rename the original CMD to Rail A, create Rail B, group them through Move to Group, then create Rail C through Rail F. Put Rail C and Rail D in a second group, leaving Rail E and Rail F ungrouped. Require exactly two groups, two members each and six saved sessions. Keep action.png from group creation.
3. Select Rail A and Rail B by their saved names through Ctrl+K. Require the saved active tab and capture group-rail-selected-0.png and group-rail-selected-1.png with UIA and native focus evidence.
4. Derive geometry from the owned frame/client origin, actual DPI, saved UI scale and workspace-pill visibility, never from a header fill or rail. Expanded group headers scale from 42 pixels and member rows scale from 58 pixels. Workspace pills retain their 34-pixel height. Compare both headers' full top and bottom scanlines with the unobstructed sidebar background, excluding only the divider column. Require zero fill mismatches at RGB tolerance three.
5. Inspect the entire left-edge band beside every member of both groups, including the active row. Require zero default group-colored pixels (RGB 145,149,157, tolerance two). Both selections keep the former selected-rail regression covered by absence rather than by expecting a rail elsewhere.
6. Measure each headline's leftmost #8A8A8A text pixel and each first member's white name-text pixel. The headline must start at the session content inset within three scaled pixels, have no separate chevron-sized prefix gap and contain no bright old-style header text. Record the literal row-text x and its existing 16-pixel CMD icon plus 8-pixel gap separately: normalize that optional icon reservation before comparing the text origins, without changing session indentation.
7. After Doctor, click the first headline with real ownership-checked mouse input. Require its persisted collapsed flag, capture group-rail-collapsed.png and matching JSON, then wait 700 ms and click the same headline 24 pixels further along, away from the double-click that opens the group rename, and require expanded memory. Capture group-rail-restored.png and matching JSON. Compare each original member's bright text pixels with per-channel tolerance 48 and at most four changed pixels at its original position and at every possible row position in the collapsed sidebar: neither row may remain. Both member rows must return unchanged at their original positions after expansion. Require unchanged six-session identities, membership, order and two-group count. Keep saved-state, geometry, pixel counts, UIA, focus, version/tag and click evidence in JSON.
8. Inspect group-rail-selected-1.png and group-rail-labels.json. Check Recents below the second group. Align Recents ink with the first headline. Allow three scaled pixels. Require #8A8A8A text and no arrow prefix. Compare the initial capitals in Recents and Group 1. Require their measured ink heights to match within two scaled pixels, without counting lowercase descenders. Check the former button region below Rail F. Require zero ink above background tolerance 30. Record bounds, ink box, and pixel count. Print `sidebar-label same-style PASS|FAIL`, `sidebar-label no-arrow PASS|FAIL` and `sidebar-former-button empty PASS|FAIL`.
9. Print `sidebar-headline no-fill PASS|FAIL`, `sidebar-headline no-rail PASS|FAIL`, `sidebar-headline flush-left PASS|FAIL` and `sidebar-headline click-toggle PASS|FAIL` from their respective assertions; throw if any fails, including the three label lines. Inspect both selection screenshots, collapsed/restored screenshots, action.png, after.png, result.json, build.json and owned-job cleanup.

## Gotchas

The driver uses the current 42-pixel expanded header geometry and 58-pixel member rows. Selected-row backgrounds may change during collapse. The member-text comparison excludes background-only pixels, while membership and visibility checks remain required.


- Mixed case is not a negative control. Current source preserves group names and draws Recents literally. Require matching letter heights, muted ink and alignment instead.
- Before IGSH-932, RECENTS had a leading arrow. The new-tab row also included text. Those builds must fail `sidebar-label no-arrow`. They must also fail `sidebar-former-button empty`. The former `sidebar-newtab plus-only` check rejected that text. Letter height alone does not pass the style check. Unread-only shares the former button region. This empty-region check requires unread-only mode off.

- The old release v0.28.861 has filled headers, a rail and a chevron: the identical journey must reach `sidebar-headline no-fill FAIL`, `sidebar-headline no-rail FAIL` and `sidebar-headline flush-left FAIL`. A launch, parser or geometry failure is not negative-control rendering proof. Any build retaining one of those decorations must fail its corresponding appearance assertion.
- The CMD icon is not name text or a chevron. Literal session-name pixels sit after its reserved width; the headline uses the existing session content origin, not a new indentation. The evidence explicitly records this normalization rather than claiming the raw text x coordinates are identical.
- Default group names and default gray colors are deliberate: this journey measures known muted headline and group-rail colors in Dark mode, not arbitrary custom palettes.
- The scanline checks cover the full sidebar interior, including the margins outside the old header fill. The single right divider is not a header background.
- The pane-layout journey also derives the grouped member row from the unchanged geometry, requires no rail, and retains its visible CMD icon and content-inset assertions.
- The cyan ETA progress line is a separate session indicator, not a group rail; no ETA fixtures are created.
- Real saved collapse state and disappearing/returning member text are both required. Merely changing JSON or capturing screenshots without inspecting pixels cannot pass the click gate.
- Two clicks at the same spot inside the double-click time open the group rename editor instead of toggling. On 2026-10-25 a run failed exactly that way: the second click was a WM_LBUTTONDBLCLK and failure.uia.json showed an Edit element. The restore click therefore waits 700 ms and moves 24 pixels along the same headline.
- Row comparison checks bright text pixels with per-channel tolerance 48 and at most four changed pixels. Ignore background-only selection changes. Another group's text sliding into the freed space must not match.
- Right-click, rename, keyboard collapse, drag and drop, relaunch persistence and collapsed-sidebar appearance are unchanged code paths, not additional live coverage claimed by this journey.
- The app creates all session/group state; the driver only reads it. Offline mode does not prove sign-in, SSH, live agents or remote synchronization. GitHub Windows runs provide the live results; source-only VPS checks do not.
