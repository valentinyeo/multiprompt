# Browser pane power management

Inactive panes progressively reduce resource use. The active pane is never frozen or hibernated.

## Tier 1: background

A parked pane moves off-screen with `SW_SHOWNOACTIVATE`, rather than cycling `SW_HIDE`/`SW_SHOW`, to avoid Chromium's grey compositor surface on return. Native occlusion may reduce rendering work; exact behavior depends on the browser version.

## Tier 2: frozen

After 120 seconds parked on AC, or 30 seconds on battery/Energy Saver, the app sends CDP `Page.setWebLifecycleState` with `state:"frozen"`. It sends `state:"active"` before revealing the pane. Commands targeting frozen panes wake them before executing. Worker-side freeze markers avoid reading UI-owned shell state off-thread.

## Tier 3: hibernated

After 15 idle minutes on AC or five in power-saving mode, the native browser window can close while its enabled state and URL remain saved. Switching to the tab relaunches the pane. Recent browser commands impose an additional quiet period, so a regularly driven pane can remain awake longer.

## Exemptions and persistence

`keep_awake` (Alt+P or Ctrl+K `Keep Tab Awake: On/Off`) exempts a pane from freezing and hibernation. Working sessions and recent browser commands also delay those tiers. Audible-tab detection is not implemented; keep media tabs awake manually.

The URL and keep-awake setting persist. Frozen state and parked timestamps are runtime-only. `Ctrl+K` offers `Hibernate Browser Panes Now` for hidden eligible panes.

Run `node --test tools/browser-pane-hibernation.test.js` for portable regressions. On Windows, verify wake, saved URLs, media exemptions, and absence of grey surfaces across actual tab switches.
