# Computer in the chat menu

## Sub-features

- Chat headers have no standalone Computer button.
- The existing three-dots menu contains Computer.
- Choosing Computer selects that chat's existing pane.
- Returning preserves the selected chat and draft.

## How to get to it (user POV)

Open a remote session in Chat View. Open its three dots and choose Computer.
Ctrl+K, `more menu`, Enter opens the same menu.
The existing Computer palette and session-context actions remain available.
Local CMD sessions have no remote computer; their menu row is disabled.

## Driving it with control.ps1

Dispatch `gh workflow run verify.yml --ref <branch> -f feature=computer-menu`.
Add `-f tag=v0.28.1487` for the published pre-fix control.

The journey starts an empty offline profile and creates a group through real palette input.
The app's own session-open command creates one synthetic remote identity, `verify-computer`.
No saved session, Computer choice or draft is written by the harness.
Select the chat, enable Chat View, and type a draft through real keyboard input.
Capture `before.png` to review the plain header.
Open `Chat View: More Menu` through Ctrl+K and capture the actual native menu in `action.png`.
Read the app's diagnostic Computer row rectangle and click its center through real mouse input.
The UI Automation child must belong to the owned main window.
Require the app-written `session.json.computer` to contain exactly one selected identity.
The selected chat and Chat View must remain unchanged.
Return through the existing Computer palette action and require the saved selection to clear.
The native composer must still contain the exact draft.
Inspect before/action/pane/after screenshots, command receipts, saved sessions, choice receipt and `result.json`.
The published pre-fix menu has no Computer row. Require `Three-dots menu has no Computer row` and inspect the actual missing-row screenshot, not a setup or launch failure.
The initial keyboard-only baseline [41968849113](https://github.com/valentinyeo/multiprompt/actions/runs/41968849113) reached the real menu without Computer, then failed to select the pane. Its screenshots were inspected; keyboard navigation itself was inconclusive, so the final driver clicks the app-published row rectangle.

## Gotchas

This proves desktop menu routing, pane selection, and draft preservation, not remote desktop pixels.
There are no SSH credentials, VNC service, real agent, account sign-in or live chat delivery.
The synthetic remote tab can report a disconnected transport; that is not the menu assertion.
Android uses the same three-dots placement. Desktop additionally retains Ctrl+K and native session context actions.
