# Computer pane

Journeys: computer-menu

## Sub-features

The recipes below name the user actions, expected result and exact boundary.

## How to get to it (user POV)

Use the entry paths in the action table below on a disposable owned profile.

## Driving it with drive.ps1

Preconditions: a healthy GitHub Windows instance and the selected journey prerequisites.

Use `verify.yml` with the named executable journey, not this map stem. A journey is a recipe, not a claim of a live pass.

The recipes distinguish existing focused journeys from unreachable complete paths. UNREACHABLE names the missing data, endpoint, build mode or driver action; it never means the product passed.

### computer: Computer viewing and control

Open Computer from the existing three-dot menu or Ctrl+K. Use Ctrl+Shift+F to toggle full width; the old Computer width palette ID is not generated. Take control, give back and force a lost connection before Retry. Return to Browser or chat and compare the unsent draft.

Observable proof: The selected chat owns the remote view and input session. Take control sends input only to that target, Give back stops it, Retry reconnects the same identity, and draft text remains exact.

Journey: computer-menu covers menu selection/draft only. UNREACHABLE for real viewing/control until WebView2, a disposable non-root SSH user with discovery-compatible x11vnc.service and novnc-desktop.service, permission to control it and a driver reading remote input receipts are available. Do not use a personal desktop.

| Palette row or dynamic family | User reaches it |
| --- | --- |
| `SEARCH_COMPUTER_CONTROL_OFFSET` | Ctrl+K, type **take control**, then select the matching action with Up/Down and Enter. Follow `computer` above. |
| `SEARCH_COMPUTER_RETRY_OFFSET` | Ctrl+K, type **computer retry**, then select the matching action with Up/Down and Enter. Follow `computer` above. |
| `SEARCH_COMPUTER_TOGGLE_OFFSET` | Ctrl+K, type **computer**, then select the matching action with Up/Down and Enter. Follow `computer` above. |
| `SEARCH_COMPUTER_WIDTH_OFFSET` | UNREACHABLE as a distinct palette row: source retains a label/handler but no current result-generation path in `src/command_palette.zig`. Use the recipe above only through its documented alternative entry, not this ID. |
| `SEARCH_TABCTX_COMPUTER` | Right-click the intended tab, then choose **Computer: Show or hide**. Follow `computer` above. |

## Gotchas

Never treat an offline, synthetic or diagnostic check as authenticated end-to-end proof.
