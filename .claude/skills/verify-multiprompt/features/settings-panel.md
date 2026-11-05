# Settings panel

Verify on: push

## Sub-features

- Open the centred panel with Ctrl+, or Ctrl+K `Settings`.
- Look: current theme with all existing choices, Small/Normal/Large chat font presets, and the existing Chat/Terminal view choice labelled Terminal details.
- Keys: Set rows opening separate masked dialogs, backed by the existing dictation registry value and Screencast2 upload configuration, not new secret stores.
- About: existing release notes and the actual app version.
- Round close, Escape, native Tab/Shift+Tab and focus restoration. Narrow layouts stack controls and scroll instead of clipping settings.

## How to get to it (user POV)

Press Ctrl+, from the workspace, chat or terminal. Alternatively open Ctrl+K and choose Settings. Existing palette settings remain available. Theme and view controls apply immediately. Key dialogs use Save/Cancel; Escape discards unsaved edits. Escape or the round close returns to the previous input.

## Driving it with control.ps1

Dispatch the existing `verify.yml` workflow on the branch with `feature=settings-panel`. The Windows runner builds and drives the actual app in isolated profiles. Never run this driver on the user's live app.

Run the same journey against the published pre-fix release. It must fail the wrapped-key normalization assertion, not launch or setup. The earlier pre-panel baseline failed because Ctrl+, could not open Settings: https://github.com/valentinyeo/multiprompt/actions/runs/40419748331 .

The journey captures the chat before opening and the actual panel afterward. Pixel checks require the dark panel fill, centred un-clipped content-area bounds, rounded corners, dimmed chat and an unchanged sidebar. It finds real accessible native controls, chooses all seven existing theme options, changes and resets chat font size while the terminal is selected, and toggles the existing view choice back.

Before opening Chat View, the journey cancels an unset key, pastes a wrapped synthetic key and requires its normalized registry value. It exercises malformed input, 401/403 rejection with distinct persisted corrections, 429/503/offline saving, a 512-character key, and delayed cancellation followed by reopening. Save is disabled during the delayed request; the late completion must not overwrite the newer key. Button Cancel and Alt+F4 each reopen an idle sheet before the old response; the registry and reloaded field must remain unchanged. The saved session remains in terminal view. It retains `settings-key-unset.png` and `settings-key-replaced-terminal.png`.

Both separate key dialogs must use password controls. Cancelling must preserve both stores. Harmless fixture values exercise the real registry/TOML stores; unrelated upload configuration must survive. Reopening and appending to each masked field proves saved values were reloaded without exporting password contents through a UI readback API. The original CI registry value is restored in `finally`. Before app startup, a GitHub Windows offline-only loopback HTTP server replaces the key-check HTTP boundary. It validates the empty POST and records only counts, key length and redirect authorization presence. A 302 response must produce zero requests to the loopback redirect target. No paid provider or upload request occurs.

All nine native controls must accept Tab focus in order; Shift+Tab must move backward. Before each subsequent click, bounded Tab navigation focuses the target so the production focus handler scrolls it into view; an unreachable target fails instead of clicking an offscreen coordinate. The round close and Escape must dismiss Settings and restore the chat composer. The palette entry must reopen it. Release notes must close Settings and invoke the existing notes view. `settings-panel-proof.json`, `settings-panel-pixels.json`, the saved profile, screenshots and the common cleanup result record the proof. The full master/manual matrix retains this journey; ordinary PRs keep their existing appearance-only matrix.

The final side-by-side reference is approved Figma frame49-596: https://www.figma.com/design/8Yzu3N21UlCL7lA3YXm45D?node-id=49-596 . The whole-file thumbnail is not a substitute for that frame.

## Gotchas

- The two keys are existing desktop configuration. Never print real keys or use the laptop's stores as fixtures.
- Terminal details reuses the existing Chat/Terminal choice. It is not a new preference or a new terminal renderer.
- Owned native browser surfaces must remain behind the modal; opening Settings must not close or restart a browser session.
- Existing palette entries remain available alongside the Theme row.
- This isolated journey does not prove normal in-app updater delivery. Release proof remains separate, after explicit merge approval.
