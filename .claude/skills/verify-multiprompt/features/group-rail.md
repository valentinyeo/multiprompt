# Group headlines

## Sub-features

- Each expanded-sidebar group has a small, muted, left-aligned headline in the subtitle font, with no fill, colored rail or chevron.
- The sidebar background remains visible across both edges of each headline row.
- Sessions retain their existing indentation, icons, highlights and row heights beneath the headline; adjacent groups and ungrouped sessions remain separate.
- Clicking the headline uses the existing group collapse action: members disappear and return, and the same collapsed memory is saved.
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
3. Select each first-group member with Ctrl+1 and Ctrl+2, require the saved active tab and capture group-rail-selected-0.png and group-rail-selected-1.png with UIA and native focus evidence.
4. Derive geometry from the owned frame/client origin, actual DPI, saved UI scale and workspace-pill visibility, never from a header fill or rail. Group headers and workspace pills retain their production fixed heights of 28 and 34 pixels; member rows scale from 38 pixels. Compare both headers' full top and bottom scanlines with the unobstructed sidebar background, excluding only the divider column. Require zero fill mismatches at RGB tolerance three.
5. Inspect the entire left-edge band beside every member of both groups, including the active row. Require zero default group-colored pixels (RGB 145,149,157, tolerance two). Both selections keep the former selected-rail regression covered by absence rather than by expecting a rail elsewhere.
6. Measure each headline's leftmost muted text pixel and each first member's white name-text pixel. The headline must start at the session content inset within three scaled pixels, have no separate chevron-sized prefix gap and contain no bright old-style header text. Record the literal row-text x and its existing 16-pixel CMD icon plus 8-pixel gap separately: normalize that optional icon reservation before comparing the text origins, without changing session indentation.
7. After Doctor, click the first headline with real ownership-checked mouse input. Require its persisted collapsed flag, capture group-rail-collapsed.png and matching JSON, then click the same position again and require expanded memory. Capture group-rail-restored.png and matching JSON. Compare the original members' white text cores and dark non-text pixels, tolerating antialiased edges that change with selection, as text masks against every possible row position in the collapsed sidebar: neither may remain. Both original text masks must return at their original positions after expansion. Require unchanged six-session identities, membership, order and two-group count. Keep saved-state, geometry, pixel counts, UIA, focus, version/tag and click evidence in JSON.
8. Print `sidebar-headline no-fill PASS|FAIL`, `sidebar-headline no-rail PASS|FAIL`, `sidebar-headline flush-left PASS|FAIL` and `sidebar-headline click-toggle PASS|FAIL` from their respective assertions; throw if any fails. Inspect both selection screenshots, collapsed/restored screenshots, action.png, after.png, result.json, build.json and owned-job cleanup.

## Gotchas

- The old release v0.28.861 has filled headers, a rail and a chevron: the identical journey must reach `sidebar-headline no-fill FAIL`, `sidebar-headline no-rail FAIL` and `sidebar-headline flush-left FAIL`. A launch, parser or geometry failure is not negative-control rendering proof. Any build retaining one of those decorations must fail its corresponding appearance assertion.
- The CMD icon is not name text or a chevron. Literal session-name pixels sit after its reserved width; the headline uses the existing session content origin, not a new indentation. The evidence explicitly records this normalization rather than claiming the raw text x coordinates are identical.
- Default group names and default gray colors are deliberate: this journey measures known muted headline and group-rail colors in Dark mode, not arbitrary custom palettes.
- The scanline checks cover the full sidebar interior, including the margins outside the old header fill. The single right divider is not a header background.
- The pane-layout journey also derives the grouped member row from the unchanged geometry, requires no rail, and retains its visible CMD icon and content-inset assertions.
- The cyan ETA progress line is a separate session indicator, not a group rail; no ETA fixtures are created.
- Real saved collapse state and disappearing/returning member text are both required. Merely changing JSON or capturing screenshots without inspecting pixels cannot pass the click gate.
- Right-click, rename, keyboard collapse, drag and drop, relaunch persistence and collapsed-sidebar appearance are unchanged code paths, not additional live coverage claimed by this journey.
- The app creates all session/group state; the driver only reads it. Offline mode does not prove sign-in, SSH, live agents or remote synchronization. GitHub Windows runs provide the live results; source-only VPS checks do not.
