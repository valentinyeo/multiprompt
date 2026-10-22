# Group rail

## Sub-features

- Default groups retain a continuous gray rail through their header and unselected sessions.
- The rail never crosses the active session highlight or its border.
- No rail extends into the space below the last grouped row.

## How to get to it (user POV)

- Ctrl+K `new cmd` creates another session.
- Ctrl+K `move to group`, then `new group`, creates a group for the active session.
- Select another session, use Move to Group and choose the saved group name.
- Ctrl+1 and Ctrl+2 select the grouped sessions without changing their membership.

## Driving it with control.ps1

Dispatch `gh workflow run verify.yml --ref <branch> -f feature=group-rail`. The pull-request matrix also runs this journey. Use `-f tag=v0.28.819` for the broken-release negative control, then omit tag to verify the branch build with the identical driver.

1. Launch the isolated real Windows app, pass Doctor and choose Dark through Themes. Print `group-rail verified release tag=... version=...` and retain checksum/version provenance in build.json.
2. Rename the original CMD to Rail A through F2, create a second real CMD session through Ctrl+K and rename it Rail B. Short synthetic names keep the highlight reference column free of text. Create a group for it through Move to Group, keep its default name, select the original session with Ctrl+2 (the grouped session is first in sidebar order) and move it into the same group through the palette. Require both saved memberships and exactly two sessions; never seed app data.
3. Select each grouped session in turn with Ctrl+1 and Ctrl+2. Require the persisted active tab, then capture group-rail-selected-0.png and group-rail-selected-1.png, UIA and native focus evidence.
4. Obtain the owned main frame and client origin through Win32. Use the actual DPI and saved UI scale for sidebar and row geometry; the workspace strip and group header retain their production fixed heights. Require every pixel of the expected gray header rail and every pixel along the unselected row rail. This positive control prevents an absent rail or wrong sample position from passing.
5. At every rail-column pixel within the active highlight rectangle, compare the screenshot color with the same scanline of the unobstructed highlight farther right. Require a visibly blue reference highlight, zero mismatches (RGB tolerance three) and zero gray rail pixels (tolerance two), including the highlight's top and bottom border scanlines.
6. Sample all rail-column pixels for a full row height immediately below the last grouped row. Require zero gray rail pixels. Save counts, sample rectangles, highlight color, geometry, session state and version in matching JSON files.
7. After both selections, print exactly `group-rail selected-clear PASS` and `group-rail stray-clear PASS` only if their assertions hold; print the corresponding FAIL marker otherwise and fail the journey. Inspect both screenshots, action.png, after.png, result.json, build.json and owned-job cleanup.

## Gotchas

- The sidebar currently draws no hovered-row highlight. This journey covers both positions of the active highlight; it does not invent a hover state or claim multi-selection coverage.
- The cyan horizontal ETA progress line is a separate session indicator, not a group rail. This journey has no ETA fixtures and does not change or suppress that indicator.
- The app supplies session/group state; the driver only reads it. The explicit offline-login boundary does not verify sign-in, SSH, live agents or remote synchronization.
- A broken-release run must reach `group-rail selected-clear FAIL`; a launch, parser or geometry failure is not failing-first rendering proof.
