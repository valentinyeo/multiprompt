# Permission rows

Covers: palette:SEARCH_CHAT_ALLOW_OFFSET, palette:SEARCH_CHAT_ALWAYS_OFFSET, palette:SEARCH_CHAT_DENY_OFFSET
Covers: shortcut:palette-actions/1-or-alt-y-in-chat-view-ctrl-k-chat-view-allow, shortcut:palette-actions/2-or-alt-o-in-chat-view-ctrl-k-chat-view-always-allow, shortcut:palette-actions/3-or-alt-d-in-chat-view-ctrl-k-chat-view-deny

## Sub-features

A pending permission has three rows. The chosen row stays marked; the others fade. The answer appears in chat. Each mouse, number, Alt shortcut and global palette choice must send exactly one provider answer.

## How to get to it (user POV)

Open Chat View on a Claude session with a pending permission. Click a row, or press 1, 2 or 3 in an empty composer. Alt+Y allows, Alt+O always allows, and Alt+D denies without replacing the draft. Ctrl+K offers **Chat View: Allow**, **Always allow**, and **Deny**.

## Driving it with control.ps1

Use the automatic PR verifier's `permission-rows` Windows journey. It invokes `control.ps1 -Feature permission-rows` against the PR head. Do not dispatch a duplicate run. The existing tagged-release path captures old pending buttons only and does not claim the expanded matrix passes.

1. Start the synthetic Claude console through real terminal input. Require the owned PID and executable path, production Claude detection, and an owned transcript and composer.
2. Type `Keep this draft`. Click each of the three permission rows, rearming between choices. Require the exact draft and one receiving digit per choice.
3. Clear the draft through Ctrl+A and Backspace. Press 1, 2 and 3 in the empty composer. Require an empty composer after each choice.
4. Restore `Keep this draft`. Press Alt+Y, Alt+O and Alt+D. Then select each global permission entry through Ctrl+K, search, arrows and Enter. Require the exact draft after each choice.
5. After every answer, require its picked row and capture a screenshot. Click the chosen row again and require no extra receiving digit or keydown.
6. Require the exact raw suffix `124124124124` and twelve new keydowns. Displayed Deny row 3 maps to provider digit 4.

The driver runs `chat-control-coverage.test.cjs --permission-evidence <evidence>` against `stub-keys.txt`, `stub-events.txt` and `permission-inputs.json`. Inspect pending and twelve picked screenshots with `doctor.json`, actions and zero-process cleanup. The checker requires screenshots from the verified app, exact route order, counts and drafts.

## Gotchas

The fixture uses denial digit 4, but console permission digits are parsed dynamically and live approvals use protocol decisions.

Inspect the tick, fading, answer echo and surrounding chat in the screenshots. Receipt and rectangle checks do not certify these visuals. This local console replaces Claude and does not exercise the live `approval.request` provider protocol or a remote server. Tab-context permission entries are separate actions and are not claimed here. The ordinary question-card journey is `chat-options`; working dots are `chat-working`.
