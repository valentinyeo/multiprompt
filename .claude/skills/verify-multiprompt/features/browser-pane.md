# Browser pane

Open a session browser beside chat or shell, navigate, type, switch focus, and close the pane.

Journeys: browser-pane-locked, browser-typing, browser-own-profile
Release paths: src/browser*.zig, src/bridge*.zig, extension/*, src/main.zig, build.zig

## Sub-features
- `open-navigate` opens the session’s browser and changes its page or address.
- `focus-layout` restores typing and preserves docking and divider geometry.
- `profile-recovery` separates private browser state and retries failed connections.

## How to get to it (user POV)
- Alt+A toggles the pane; Alt+Q or Alt+M changes focus; Ctrl+Shift+L selects its address; browser Back/Forward and Ctrl+K browser actions navigate; drag the pane divider.

## Driving it with drive.ps1
Preconditions: fresh hosted Windows desktop, matching executable/hash/version, isolated app data, and the selected legacy recipe’s prerequisites.
- Migration pending for this feature. Run `gh workflow run verify.yml --ref <branch> -f feature=browser-pane-locked`. [Locked pane](browser-pane-locked.md), [typing](browser-typing.md), and [own profile](browser-own-profile.md) document exact native inputs and ownership checks.
- Require owned browser HWND, dock rectangle, page/address text, screenshots, and saved pane state. Only the selected journey is covered. Download `verify-browser-pane-locked` after cleanup. This legacy workflow route does not yet use the video driver; see [inventory](../inventory.md).

## Gotchas
- A Chrome extension journey does not prove the embedded pane. Profile and external-page prerequisites differ per recipe; never drive a personal browser.
