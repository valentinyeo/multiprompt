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
- The shared wrapper accepts these Journeys; automatic workflow migration remains partial. Run `gh workflow run verify.yml --ref <branch> -f feature=browser-pane-locked`. [Locked pane](browser-pane-locked.md), [typing](browser-typing.md), and [own profile](browser-own-profile.md) document exact native inputs and ownership checks.
- Require owned browser HWND, dock rectangle, page/address text, screenshots, and saved pane state. Only the selected journey is covered. Download `verify-browser-pane-locked` after cleanup. This legacy workflow route does not yet use the video driver; see [inventory](../inventory.md).

The recipes distinguish existing focused journeys from unreachable complete paths. UNREACHABLE names the missing data, endpoint, build mode or driver action; it never means the product passed.

### browser-nav: Browser navigation and focus

Alt+A opens the owned pane. Use address bar, Back/Forward, Ctrl+L and Alt+Q; type in a local page and the chat separately. Open a URL with Alt+W, paste the current URL at the chat caret, and toggle native browser versus app chrome. Repeat URL clicks with pane on/off and external-link preference changed.

Observable proof: Owned HWND, dock rectangle, page title/request log and exact draft/address text agree. Link insertion changes only the caret text and never sends. Typing returns to the right surface without stuck modifier keys.

Journey: browser-typing, browser-pane-locked, chat-browser-shortcut, link-picker. UNREACHABLE for browser-URL insertion and external-link policy until the real extension is bound and the driver asserts exact clipboard/draft/request destinations for those inputs.

| Palette row or dynamic family | User reaches it |
| --- | --- |
| `SEARCH_BROWSER_BACK_OFFSET` | Ctrl+K, type **browser back**, then select the matching action with Up/Down and Enter. Follow `browser-nav` above. |
| `SEARCH_BROWSER_FOCUS_TOGGLE_OFFSET` | Ctrl+K, type **switch focus**, then select the matching action with Up/Down and Enter. Follow `browser-nav` above. |
| `SEARCH_BROWSER_FOCUS_URL_OFFSET` | Ctrl+K, type **focus address bar**, then select the matching action with Up/Down and Enter. Follow `browser-nav` above. |
| `SEARCH_BROWSER_FORWARD_OFFSET` | Ctrl+K, type **browser forward**, then select the matching action with Up/Down and Enter. Follow `browser-nav` above. |
| `SEARCH_BROWSER_MODE_OFFSET` | Ctrl+K, type **browser address bar**, then select the matching action with Up/Down and Enter. Follow `browser-nav` above. |
| `SEARCH_BROWSER_SHOTURL_OFFSET` | Ctrl+K, type **screenshot browser tab**, then select the matching action with Up/Down and Enter. Follow `browser-nav` above. |
| `SEARCH_BROWSER_TOGGLE_OFFSET` | Ctrl+K, type **browser pane**, then select the matching action with Up/Down and Enter. Follow `browser-nav` above. |
| `SEARCH_BROWSER_URL_OFFSET` | Ctrl+K, type **browser open url**, then select the matching action with Up/Down and Enter. Follow `browser-nav` above. |
| `SEARCH_CHAT_TAB_URL_OFFSET` | Ctrl+K, type **insert browser tab url**, then select the matching action with Up/Down and Enter. Follow `browser-nav` above. |
| `SEARCH_EXTERNAL_BROWSER_LINKS_OFFSET` | Ctrl+K, search for **external browser links when pane off**. Follow `browser-nav` above. |
| `SEARCH_TABCTX_BROWSER` | Right-click the intended tab, then choose **Open / close browser pane**. Follow `browser-nav` above. |
| `SEARCH_TABCTX_CHAT_TAB_URL` | Right-click the intended tab, then choose **chat view insert browser tab url link ctrl shift x**. Follow `browser-nav` above. |
| `SEARCH_URLPICK_OFFSET` | UNREACHABLE as a distinct palette row: source retains a label/handler but no current result-generation path in `src/command_palette.zig`. Use the recipe above only through its documented alternative entry, not this ID. |

### browser-profile: Browser profiles and pinned pages

Open two chats with distinct pages. Pin a page through the chat menu, navigate away, return through the URL bar pin, unpin and verify no return target. Open an own-profile workspace and a shared one. Use Sign in to Google in this profile only with a disposable account.

Observable proof: Pinned URL stays with its chat through switches and restart. Own and shared profiles keep distinct cookie/storage state and browser ownership. Google sign-in requires the actual accepted account session, not a local cookie stand-in.

Journey: browser-own-profile proves profile separation only. UNREACHABLE for pin/unpin/return until native menu and saved-URL assertions are added; real Google proof additionally needs a disposable authenticated account and interactive challenge completion.

| Palette row or dynamic family | User reaches it |
| --- | --- |
| `SEARCH_TABCTX_GOOGLE_SIGNIN` | Right-click the intended tab, then choose **Sign in to Google in this profile**. Follow `browser-profile` above. |
| `SEARCH_TABCTX_PIN_PAGE` | Right-click the intended tab, then choose **Pin this page to this chat**. Follow `browser-profile` above. |
| `SEARCH_TABCTX_UNPIN_PAGE` | Right-click the intended tab, then choose **Unpin from this chat**. Follow `browser-profile` above. |

### browser-life: Browser lifecycle and agent bridge

Open panes on two tabs, keep one awake, allow the other to suspend, then wake it. Close all panes and reopen with their saved URLs. Force a connection failure, use Retry, repair the agent connection and insert agent instructions into the selected shell. Run real zsb viewport emulation in the isolated browser.

Observable proof: Only eligible idle panes suspend; input wakes the correct one. Close All leaves no owned browser descendants but retains saved addresses. Retry reaches ready or a bounded visible failure. Agent commands reach only their own pane; emulation changes viewport/UA/touch then restores them.

Journey: browser-pane-stuck, browser-switch-speed, live-chat-pane, browser-emulation. UNREACHABLE for the complete keep-awake/Close All/repair sequence until the driver asserts every owned pane/process and binding. Part B is needed for real server-to-pane agent commands.

| Palette row or dynamic family | User reaches it |
| --- | --- |
| `SEARCH_BROWSER_AUTOSUSPEND_OFFSET` | Ctrl+K, type **auto-suspend**, then select the matching action with Up/Down and Enter. Follow `browser-life` above. |
| `SEARCH_BROWSER_ENGINE_OFFSET` | UNREACHABLE as a distinct palette row: source retains a label/handler but no current result-generation path in `src/command_palette.zig`. Use the recipe above only through its documented alternative entry, not this ID. |
| `SEARCH_BROWSER_INSTRUCT_OFFSET` | Ctrl+K, type **insert agent instructions**, then select the matching action with Up/Down and Enter. Follow `browser-life` above. |
| `SEARCH_CLOSE_ALL_BROWSER_PANES_OFFSET` | Ctrl+K, search for **close all browser panes**. Follow `browser-life` above. |
| `SEARCH_HIBERNATE_NOW_OFFSET` | UNREACHABLE as a distinct palette row: source retains a label/handler but no current result-generation path in `src/command_palette.zig`. Use the recipe above only through its documented alternative entry, not this ID. |
| `SEARCH_KEEPAWAKE_OFFSET` | UNREACHABLE as a distinct palette row: source retains a label/handler but no current result-generation path in `src/command_palette.zig`. Use the recipe above only through its documented alternative entry, not this ID. |
| `SEARCH_TABCTX_KEEPAWAKE` | UNREACHABLE as a distinct palette row: source retains a label/handler but no current result-generation path in `src/command_palette.zig`. Use the recipe above only through its documented alternative entry, not this ID. |
| `SEARCH_ZSB_REBIND_OFFSET` | Ctrl+K, type **repair agent connection**, then select the matching action with Up/Down and Enter. Follow `browser-life` above. |

## Gotchas
- A Chrome extension journey does not prove the embedded pane. Profile and external-page prerequisites differ per recipe; never drive a personal browser.
