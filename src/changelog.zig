const app_state = @import("app_state.zig");
const std = @import("std");
const APP_VERSION = @import("main.zig").APP_VERSION;
const WPARAM = @import("win32.zig").WPARAM;
const HANDLE = @import("win32.zig").HANDLE;
const SW_SHOW = @import("win32.zig").SW_SHOW;
const DT_SINGLELINE = @import("win32.zig").DT_SINGLELINE;
const DT_VCENTER = @import("win32.zig").DT_VCENTER;
const DT_RIGHT = @import("win32.zig").DT_RIGHT;
const DT_NOPREFIX = @import("win32.zig").DT_NOPREFIX;
const TRANSPARENT = @import("win32.zig").TRANSPARENT;
const TIMER_REFOCUS = @import("win32.zig").TIMER_REFOCUS;
const RECT = @import("win32.zig").RECT;
const GetClientRect = @import("win32.zig").GetClientRect;
const InvalidateRect = @import("win32.zig").InvalidateRect;
const FillRect = @import("win32.zig").FillRect;
const DrawTextW = @import("win32.zig").DrawTextW;
const CreateSolidBrush = @import("win32.zig").CreateSolidBrush;
const DeleteObject = @import("win32.zig").DeleteObject;
const SetBkMode = @import("win32.zig").SetBkMode;
const SetTextColor = @import("win32.zig").SetTextColor;
const SelectObject = @import("win32.zig").SelectObject;
const IntersectClipRect = @import("win32.zig").IntersectClipRect;
const SaveDC = @import("win32.zig").SaveDC;
const RestoreDC = @import("win32.zig").RestoreDC;
const ShellExecuteW = @import("win32.zig").ShellExecuteW;
const L = @import("startup.zig").L;
const RGB = @import("startup.zig").RGB;
const customColorOr = @import("themes.zig").customColorOr;
const clearSearchBackdrop = @import("rename.zig").clearSearchBackdrop;
const showActiveShellAfterOverlay = @import("rename.zig").showActiveShellAfterOverlay;
const drawAscii = @import("drawing.zig").drawAscii;
const drawModalShadow = @import("drawing.zig").drawModalShadow;
const ChangelogLayout = @import("app_state.zig").ChangelogLayout;
const ChangelogEntryRange = @import("app_state.zig").ChangelogEntryRange;
const ChangelogHit = @import("app_state.zig").ChangelogHit;
const uiScaled = @import("drawing.zig").uiScaled;
const SetTimer = @import("win32.zig").SetTimer;

const ChangelogBullet = struct { text: []const u8, ticket: []const u8 };
const ChangelogEntry = struct {
    ver: []const u8,
    summary: []const u8 = "",
    ticket: []const u8 = "",
    items: []const ChangelogBullet = &.{},
};
pub const CHANGELOG = blk: {
    var entries = SOURCE_CHANGELOG;
    if (@import("build_config").app_version != null and entries.len > 0) @field(entries[0], "ver") = APP_VERSION;
    break :blk entries;
};

const SOURCE_CHANGELOG = [_]ChangelogEntry{
    .{ .ver = "0.28.883", .items = &.{
        .{ .text = "IGSH-892 Desktop right-click menus: rounded Grok style to match the chat", .ticket = "IGSH-892" },
    } },
    .{ .ver = "0.28.882", .items = &.{
        .{ .text = "IGSH-893 Multiprompt verify: chat-dictation journey hangs with no output for 25 minutes and has never run green 17/30", .ticket = "IGSH-893" },
        .{ .text = "IGSH-900 Release gate: 3 launches on saved sessions must pass before every release", .ticket = "IGSH-900" },
    } },
    .{ .ver = "0.28.881", .items = &.{
        .{ .text = "IGSH-895 Chat View: pasting text adds an extra line break", .ticket = "IGSH-895" },
    } },
    .{ .ver = "0.28.880", .items = &.{
        .{ .text = "IGSH-894 Browser bridge broken in the standard Chrome profile: red icon, screenshots cannot be sent", .ticket = "IGSH-894" },
        .{ .text = "IGSH-900 Release gate: 3 launches on saved sessions must pass before every release", .ticket = "IGSH-900" },
        .{ .text = "IGSH-911 Multiprompt desktop Chat View: Ctrl+Enter sends the message", .ticket = "IGSH-911" },
    } },
    .{ .ver = "0.28.879", .items = &.{
        .{ .text = "IGSH-897 Multiprompt desktop: tiny dark gray Chat View scrollbar that shows only while scrolling, like Grok Bot", .ticket = "IGSH-897" },
    } },
    .{ .ver = "0.28.878", .items = &.{
        .{ .text = "IGSH-909 Multiprompt desktop Chat View composer: at most two buttons, send replaces stop while typing", .ticket = "IGSH-909" },
    } },
    .{ .ver = "0.28.877", .items = &.{
        .{ .text = "IGSH-837 CI: fast PR gate, journeys on master, auto-revert", .ticket = "IGSH-837" },
        .{ .text = "IGSH-853 Multiprompt: release newest green master commit every 30 min, never skip", .ticket = "IGSH-853" },
        .{ .text = "IGSH-856 Multiprompt: update downloaded but no Relaunch card, and Ctrl+K Relaunch does nothing", .ticket = "IGSH-856" },
        .{ .text = "IGSH-858 Multiprompt: the overlay that hides the minimize, maximize and close buttons overlaps weirdly", .ticket = "IGSH-858" },
        .{ .text = "IGSH-860 Multiprompt: remove the CX burn readout and the 44h figure from the usage display", .ticket = "IGSH-860" },
        .{ .text = "IGSH-865 Multiprompt desktop: remove the three big dictation buttons (Android only)", .ticket = "IGSH-865" },
        .{ .text = "IGSH-867 Chat sync audit: pane_missing drift", .ticket = "IGSH-867" },
        .{ .text = "IGSH-868 Multiprompt desktop: Chat View opens at the newest message", .ticket = "IGSH-868" },
        .{ .text = "IGSH-869 Multiprompt desktop: Chat View scroll-to-bottom button, thin scrollbar, faster scroll", .ticket = "IGSH-869" },
        .{ .text = "IGSH-869 Multiprompt desktop: Chat View scroll-to-bottom button, thin scrollbar, faster scroll", .ticket = "IGSH-869" },
        .{ .text = "IGSH-869 Multiprompt desktop: Chat View scroll-to-bottom button, thin scrollbar, faster scroll", .ticket = "IGSH-869" },
        .{ .text = "IGSH-869 Multiprompt desktop: Chat View scroll-to-bottom button, thin scrollbar, faster scroll", .ticket = "IGSH-869" },
        .{ .text = "IGSH-869 Multiprompt desktop: Chat View scroll-to-bottom button, thin scrollbar, faster scroll", .ticket = "IGSH-869" },
        .{ .text = "IGSH-870 Multiprompt: desktop chat view stops showing new replies on a long session", .ticket = "IGSH-870" },
        .{ .text = "IGSH-871 Multiprompt: new-message badge and a New line above unread replies in the desktop chat", .ticket = "IGSH-871" },
        .{ .text = "IGSH-871 Multiprompt: new-message badge and a New line above unread replies in the desktop chat", .ticket = "IGSH-871" },
        .{ .text = "IGSH-872 Multiprompt: show queued messages dimmed instead of the Queued in Claude caption", .ticket = "IGSH-872" },
        .{ .text = "IGSH-873 Multiprompt: centered chat column with a max width, bubbles stop short of the far edge, like Grok Bot", .ticket = "IGSH-873" },
        .{ .text = "IGSH-874 Desktop chat view makes Ctrl+Tab session switching very slow", .ticket = "IGSH-874" },
        .{ .text = "IGSH-883 Multiprompt desktop Chat View: remove the Read check marks under sent messages", .ticket = "IGSH-883" },
        .{ .text = "IGSH-884 Multiprompt desktop Chat View: all composer buttons round and on one bottom line", .ticket = "IGSH-884" },
        .{ .text = "IGSH-885 Multiprompt desktop Chat View: incoming replies interrupt dictation", .ticket = "IGSH-885" },
        .{ .text = "IGSH-886 Multiprompt desktop: gray, not blue, highlight on the selected session in the left bar", .ticket = "IGSH-886" },
        .{ .text = "IGSH-888 Chat View: remove the dictation status text and the model and context line from the header", .ticket = "IGSH-888" },
        .{ .text = "IGSH-889 Update card shows the same old notes on every release instead of what changed", .ticket = "IGSH-889" },
        .{ .text = "IGSH-890 Starred workspace sidebar lists sessions twice and keeps adding more", .ticket = "IGSH-890" },
        .{ .text = "IGSH-894 Browser bridge broken in the standard Chrome profile: red icon, screenshots cannot be sent", .ticket = "IGSH-894" },
        .{ .text = "IGSH-896 Update card: Restart button does nothing when pressed", .ticket = "IGSH-896" },
        .{ .text = "IGSH-896 Update card: Restart button does nothing when pressed", .ticket = "IGSH-896" },
        .{ .text = "IGSH-898 Chat View: messages use about 90% of a narrow chat column", .ticket = "IGSH-898" },
        .{ .text = "IGSH-901 Desktop: restart renames sidebar tabs to GitHub and loses their order (v0.28.893)", .ticket = "IGSH-901" },
        .{ .text = "IGSH-907 Multiprompt desktop Chat View: remove the UK AMBER capacity badge from the header", .ticket = "IGSH-907" },
        .{ .text = "IGSH-910 Multiprompt desktop Chat View: remove the ETA countdown text from the header", .ticket = "IGSH-910" },
        .{ .text = "IGSH-912 Chat sync audit: pane_missing drift", .ticket = "IGSH-912" },
    } },
    .{ .ver = "0.28.876", .items = &.{
        .{ .text = "IGSH-854 Multiprompt: the IGSH-816 CLEAN code tables pixel golden fails on some Windows runners", .ticket = "IGSH-854" },
    } },
    .{ .ver = "0.28.875", .items = &.{
        .{ .text = "IGSH-834 Fast lane: green merges and releases itself in both apps", .ticket = "IGSH-834" },
        .{ .text = "IGSH-847 Multiprompt CLI: agents can launch connected sidebar sessions", .ticket = "IGSH-847" },
        .{ .text = "IGSH-849 Multiprompt: Grok-style chat view and three big dictation buttons", .ticket = "IGSH-849" },
    } },
    .{ .ver = "0.28.874", .items = &.{
        .{ .text = "IGSH-845 Multiprompt: window buttons overlap and bleed into the black title bar", .ticket = "IGSH-845" },
    } },
    .{ .ver = "0.28.873", .items = &.{
        .{ .text = "IGSH-815 Multiprompt Chat View: show every message of a session", .ticket = "IGSH-815" },
        .{ .text = "IGSH-846 Multiprompt: Escape cancels a dictation and throws it away", .ticket = "IGSH-846" },
    } },
    .{ .ver = "0.28.872", .items = &.{
        .{ .text = "IGSH-814 Multiprompt: NEW divider above the first unread message", .ticket = "IGSH-814" },
    } },
    .{ .ver = "0.28.871", .items = &.{
        .{ .text = "IGSH-807 Multiprompt: remove the Alt+Q focus ring around chat, browser and shell panes", .ticket = "IGSH-807" },
        .{ .text = "IGSH-807 Multiprompt: remove the Alt+Q focus ring around chat, browser and shell panes", .ticket = "IGSH-807" },
        .{ .text = "IGSH-838 Fast lane in every app, starting with Wazig", .ticket = "IGSH-838" },
    } },
    .{ .ver = "0.28.870", .items = &.{
        .{ .text = "IGSH-815 Multiprompt Chat View: show every message of a session", .ticket = "IGSH-815" },
        .{ .text = "IGSH-836 Multiprompt: hover must not steal keyboard selection in Ctrl+K and the skill list", .ticket = "IGSH-836" },
    } },
    .{ .ver = "0.28.869", .items = &.{
        .{ .text = "IGSH-820 Multiprompt: one Pin to Top that also protects the tab, no icons", .ticket = "IGSH-820" },
        .{ .text = "IGSH-820 Multiprompt: one Pin to Top that also protects the tab, no icons", .ticket = "IGSH-820" },
        .{ .text = "IGSH-834 Fast lane: green merges and releases itself in both apps", .ticket = "IGSH-834" },
        .{ .text = "IGSH-835 Multiprompt: delivered message still shows as queued", .ticket = "IGSH-835" },
    } },
    .{ .ver = "0.28.868", .items = &.{
        .{ .text = "IGSH-812 Multiprompt: Ctrl+D dictation in the chat box, with a mic icon at the right end", .ticket = "IGSH-812" },
    } },
    .{ .ver = "0.28.867", .items = &.{
        .{ .text = "IGSH-830 Multiprompt: AMOLED telemetry badge, white numbers, no border", .ticket = "IGSH-830" },
        .{ .text = "IGSH-830 Multiprompt: AMOLED telemetry badge, white numbers, no border", .ticket = "IGSH-830" },
    } },
    .{ .ver = "0.28.866", .items = &.{
        .{ .text = "IGSH-810 Multiprompt plan A: the mask over Chrome's window buttons takes the browser chrome's own colour", .ticket = "IGSH-810" },
        .{ .text = "IGSH-813 Multiprompt: count of new messages waiting below the fold", .ticket = "IGSH-813" },
        .{ .text = "IGSH-816 Multiprompt Chat View: CLEAN chat option showing only messages", .ticket = "IGSH-816" },
        .{ .text = "IGSH-817 Multiprompt verify: chat-view-everywhere markdown painter step fails before launch on some runs 17/30", .ticket = "IGSH-817" },
    } },
    .{ .ver = "0.28.865", .items = &.{
        .{ .text = "IGSH-805 Multiprompt: a black line appeared in the bottom chat bar", .ticket = "IGSH-805" },
    } },
    .{ .ver = "0.28.864", .items = &.{
        .{ .text = "IGSH-789 Multiprompt remote-session help still tells agents to write plain lines to the notify relay 15/30", .ticket = "IGSH-789" },
    } },
    .{ .ver = "0.28.863", .items = &.{
        .{ .text = "IGSH-766 Multiprompt sidebar: groups become plain headlines, no fill, no left bar, no chevron", .ticket = "IGSH-766" },
    } },
    .{ .ver = "0.28.862", .items = &.{
        .{ .text = "IGSH-760 Multiprompt: the message box flickers while he types", .ticket = "IGSH-760" },
    } },
    .{ .ver = "0.28.861", .items = &.{
        .{ .text = "IGSH-738 Multiprompt: links in the browser pane cannot be clicked", .ticket = "IGSH-738" },
        .{ .text = "IGSH-759 Multiprompt Chat View: hide the green tick activity lines, show only the messages", .ticket = "IGSH-759" },
    } },
    .{ .ver = "0.28.860", .items = &.{
        .{ .text = "IGSH-731 Multiprompt: message box text has no edge smoothing", .ticket = "IGSH-731" },
    } },
    .{ .ver = "0.28.859", .items = &.{
        .{ .text = "IGSH-720 Multiprompt Chat View: typed text duplicates when messages arrive, and scrolling up jumps back down", .ticket = "IGSH-720" },
    } },
    .{ .ver = "0.28.858", .items = &.{
        .{ .text = "IGSH-724 Multiprompt: Alt+Q to the browser puts focus in the web page, not the browser toolbar", .ticket = "IGSH-724" },
        .{ .text = "IGSH-728 Multiprompt update card: short plain list of what changed in each update", .ticket = "IGSH-728" },
    } },
    .{ .ver = "0.28.857", .items = &.{
        .{ .text = "IGSH-726 Multiprompt: browser pane often does not show since the second browser profile", .ticket = "IGSH-726" },
        .{ .text = "IGSH-726 Multiprompt: browser pane often does not show since the second browser profile", .ticket = "IGSH-726" },
    } },
    .{ .ver = "0.28.856", .items = &.{
        .{ .text = "IGSH-725 Multiprompt: browser pane opens blurry", .ticket = "IGSH-725" },
    } },
    .{ .ver = "0.28.855", .items = &.{
        .{ .text = "IGSH-717 Multiprompt Chat View: select text in a message and press Enter to reply to that part", .ticket = "IGSH-717" },
    } },
    .{ .ver = "0.28.854", .items = &.{
        .{ .text = "IGSH-722 Multiprompt Chat View: messages from other sessions show as raw tags in my own bubble", .ticket = "IGSH-722" },
        .{ .text = "IGSH-722 Multiprompt Chat View: messages from other sessions show as raw tags in my own bubble", .ticket = "IGSH-722" },
    } },
    .{ .ver = "0.28.853", .items = &.{
        .{ .text = "IGSH-713 Multiprompt: Ctrl+Tab sometimes takes about 280 ms because the first focus fails and waits for the refocus timer", .ticket = "IGSH-713" },
    } },
    .{ .ver = "0.28.852", .items = &.{
        .{ .text = "IGSH-720 Multiprompt Chat View: typed text duplicates when messages arrive, and scrolling up jumps back down", .ticket = "IGSH-720" },
        .{ .text = "IGSH-720 Multiprompt Chat View: typed text duplicates when messages arrive, and scrolling up jumps back down", .ticket = "IGSH-720" },
    } },
    .{ .ver = "0.28.851", .items = &.{
        .{ .text = "IGSH-712 Multiprompt: Ctrl+Tab to a chat whose browser was asleep paints the browser 50-70 ms late", .ticket = "IGSH-712" },
        .{ .text = "IGSH-719 Multiprompt: starred HT Desktop session missing from the Favorites workspace", .ticket = "IGSH-719" },
    } },
    .{ .ver = "0.28.850", .items = &.{
        .{ .text = "IGSH-716 Multiprompt: after a restart the chat box sometimes has no focus and Alt+Q does nothing", .ticket = "IGSH-716" },
    } },
    .{ .ver = "0.28.849", .items = &.{
        .{ .text = "IGSH-718 Multiprompt Chat View: right-click menu with Reply and Copy icons; grey Stop and Send buttons", .ticket = "IGSH-718" },
        .{ .text = "IGSH-718 Multiprompt Chat View: right-click menu with Reply and Copy icons; grey Stop and Send buttons", .ticket = "IGSH-718" },
    } },
    .{ .ver = "0.28.848", .items = &.{
        .{ .text = "IGSH-606 Multiprompt: Ctrl+Tab between sessions is slow when the browser pane is showing", .ticket = "IGSH-606" },
    } },
    .{ .ver = "0.28.847", .items = &.{
        .{ .text = "IGSH-703 Telemetry card and token ladder dashboard: show reset time and pace per account; fix the stale dashboard link", .ticket = "IGSH-703" },
        .{ .text = "IGSH-706 Multiprompt: muted sessions still show in the Inbox; mute all runner sessions", .ticket = "IGSH-706" },
    } },
    .{ .ver = "0.28.846", .items = &.{
        .{ .text = "IGSH-702 Multiprompt: Ctrl+H Remind me, a session comes back at a chosen time (like Superhuman)", .ticket = "IGSH-702" },
        .{ .text = "IGSH-702 Multiprompt: Ctrl+H Remind me, a session comes back at a chosen time (like Superhuman)", .ticket = "IGSH-702" },
    } },
    .{ .ver = "0.28.845", .items = &.{
        .{ .text = "IGSH-675 Multiprompt Chat View: much smaller Stop button, icon only (wireframe first)", .ticket = "IGSH-675" },
    } },
    .{ .ver = "0.28.844", .items = &.{
        .{ .text = "IGSH-678 Chat View code blocks: Nordwand Mono SemiBold, smaller and smooth", .ticket = "IGSH-678" },
        .{ .text = "IGSH-678 Chat View code blocks: Nordwand Mono SemiBold, smaller and smooth", .ticket = "IGSH-678" },
    } },
    .{ .ver = "0.28.843", .items = &.{
        .{ .text = "IGSH-673 Multiprompt: pick a smaller AI telemetry card (Full, One line, Two bars, Dot)", .ticket = "IGSH-673" },
        .{ .text = "IGSH-682 Chat View and shell: same queued messages and same draft text, both ways", .ticket = "IGSH-682" },
        .{ .text = "IGSH-682 Chat View and shell: same queued messages and same draft text, both ways", .ticket = "IGSH-682" },
        .{ .text = "IGSH-682 Chat View and shell: same queued messages and same draft text, both ways", .ticket = "IGSH-682" },
        .{ .text = "IGSH-690 Multiprompt desktop Chat View: one corrupt transcript line stops history updates", .ticket = "IGSH-690" },
    } },
    .{ .ver = "0.28.842", .items = &.{
        .{ .text = "IGSH-672 Multiprompt: own browser profile for the Inne workspace only (others untouched)", .ticket = "IGSH-672" },
    } },
    .{ .ver = "0.28.841", .items = &.{
        .{ .text = "IGSH-608 Chat View: arrived message shows Delivery unconfirmed, and leftover box text gets joined in front", .ticket = "IGSH-608" },
    } },
    .{ .ver = "0.28.840", .items = &.{
        .{ .text = "IGSH-612 Ctrl+K deep clean: inventory every command with his real usage, explain zsb, regroup and re-sort (wireframe first)", .ticket = "IGSH-612" },
        .{ .text = "IGSH-612 Ctrl+K deep clean: inventory every command with his real usage, explain zsb, regroup and re-sort (wireframe first)", .ticket = "IGSH-612" },
        .{ .text = "IGSH-612 Ctrl+K deep clean: inventory every command with his real usage, explain zsb, regroup and re-sort (wireframe first)", .ticket = "IGSH-612" },
        .{ .text = "IGSH-612 Ctrl+K deep clean: inventory every command with his real usage, explain zsb, regroup and re-sort (wireframe first)", .ticket = "IGSH-612" },
    } },
    .{ .ver = "0.28.839", .items = &.{
        .{ .text = "IGSH-569 Multiprompt reopens on the session he was on", .ticket = "IGSH-569" },
    } },
    .{ .ver = "0.28.838", .items = &.{
        .{ .text = "IGSH-664 Multiprompt: harden screenshot notifications, CMD tab start and the browser tunnel listener (MP-11, MP-12, MP-5 rest) 17/30", .ticket = "IGSH-664" },
    } },
    .{ .ver = "0.28.837", .items = &.{
        .{ .text = "IGSH-654 Multiprompt: harden local listeners, remote lookups and service edge cases (MP-4 to MP-10) 18/30", .ticket = "IGSH-654" },
    } },
    .{ .ver = "0.28.836", .items = &.{
        .{ .text = "IGSH-606 Multiprompt: Ctrl+Tab between sessions is slow when the browser pane is showing", .ticket = "IGSH-606" },
        .{ .text = "IGSH-606 Multiprompt: Ctrl+Tab between sessions is slow when the browser pane is showing", .ticket = "IGSH-606" },
    } },
    .{ .ver = "0.28.835", .items = &.{
        .{ .text = "IGSH-636 Security audit: Multiprompt desktop repo (valentinyeo/multiprompt)", .ticket = "IGSH-636" },
        .{ .text = "IGSH-636 Security audit: Multiprompt desktop repo (valentinyeo/multiprompt)", .ticket = "IGSH-636" },
    } },
    .{ .ver = "0.28.834", .items = &.{
        .{ .text = "IGSH-631 Chat sync audit: pane_missing drift", .ticket = "IGSH-631" },
    } },
    .{ .ver = "0.28.833", .items = &.{
        .{ .text = "IGSH-611 Chat View on/off everywhere: one-time switch of all sessions, plus per-session Always Chat View / Always shell", .ticket = "IGSH-611" },
    } },
    .{ .ver = "0.28.832", .items = &.{
        .{ .text = "IGSH-618 Multiprompt: install-laptop1.sh stops when an old backup exe is locked, skip it instead", .ticket = "IGSH-618" },
        .{ .text = "IGSH-619 Multiprompt verify: flaky contract tests fail PRs on GitHub (python3 spawn timeout, ISSUE-559 cleanup race)", .ticket = "IGSH-619" },
    } },
    .{ .ver = "0.28.831", .items = &.{
        .{ .text = "IGSH-611 Chat View on/off everywhere: one-time switch of all sessions, plus per-session Always Chat View / Always shell", .ticket = "IGSH-611" },
        .{ .text = "IGSH-611 Chat View on/off everywhere: one-time switch of all sessions, plus per-session Always Chat View / Always shell", .ticket = "IGSH-611" },
    } },
    .{ .ver = "0.28.830", .items = &.{
        .{ .text = "IGSH-613 Multiprompt: every session browser keeps an ugly first tab data:text/html ZSPANE..., remove it", .ticket = "IGSH-613" },
    } },
    .{ .ver = "0.28.829", .items = &.{
        .{ .text = "IGSH-599 Multiprompt: Chat View message stays queued when a local Claude session shows a grey suggested reply", .ticket = "IGSH-599" },
        .{ .text = "IGSH-610 Chat View text still has jagged edges: draw it like Chrome does", .ticket = "IGSH-610" },
    } },
    .{ .ver = "0.28.828", .items = &.{
        .{ .text = "IGSH-591 Multiprompt sidebar: group line overlaps the selected session highlight", .ticket = "IGSH-591" },
        .{ .text = "IGSH-591 Multiprompt sidebar: group line overlaps the selected session highlight", .ticket = "IGSH-591" },
        .{ .text = "IGSH-608 Chat View: arrived message shows Delivery unconfirmed, and leftover box text gets joined in front", .ticket = "IGSH-608" },
        .{ .text = "IGSH-608 Chat View: arrived message shows Delivery unconfirmed, and leftover box text gets joined in front", .ticket = "IGSH-608" },
    } },
    .{ .ver = "0.28.827", .items = &.{
        .{ .text = "IGSH-569 Multiprompt reopens on the session he was on", .ticket = "IGSH-569" },
    } },
    .{ .ver = "0.28.826", .items = &.{
        .{ .text = "IGSH-600 Multiprompt: removing a server from the account sticks instead of coming back", .ticket = "IGSH-600" },
    } },
    .{ .ver = "0.28.825", .items = &.{
        .{ .text = "IGSH-601 Multiprompt: browser pane opens zoomed in after relaunch", .ticket = "IGSH-601" },
    } },
    .{ .ver = "0.28.824", .items = &.{
        .{ .text = "IGSH-576 Multiprompt: approve an offline device once, saved in the account, banner gone", .ticket = "IGSH-576" },
        .{ .text = "IGSH-595 Multiprompt: verify journey that proves Chat View messages reach a busy or idle agent and the steer chord works", .ticket = "IGSH-595" },
    } },
    .{ .ver = "0.28.823", .items = &.{
        .{ .text = "IGSH-597 Multiprompt: after renaming a tab with F2, typing does not reach the console", .ticket = "IGSH-597" },
    } },
    .{ .ver = "0.28.822", .items = &.{
        .{ .text = "IGSH-591 Multiprompt sidebar: group line overlaps the selected session highlight", .ticket = "IGSH-591" },
    } },
    .{ .ver = "0.28.821", .items = &.{
        .{ .text = "IGSH-587 Multiprompt: starts not maximized again, must always open full screen", .ticket = "IGSH-587" },
    } },
    .{ .ver = "0.28.820", .items = &.{
        .{ .text = "IGSH-564 Chat View: messages to a busy session stay on Waiting to send (IGSH-460 regression)", .ticket = "IGSH-564" },
    } },
    .{ .ver = "0.28.819", .items = &.{
        .{ .text = "IGSH-566 Browser pane: cannot be dragged or maximized", .ticket = "IGSH-566" },
    } },
    .{ .ver = "0.28.818", .items = &.{
        .{ .text = "IGSH-573 Multiprompt: links open in the desktop browser when the browser pane is off", .ticket = "IGSH-573" },
    } },
    .{ .ver = "0.28.817", .items = &.{
        .{ .text = "IGSH-574 Chat View: right-click a link, Copy link", .ticket = "IGSH-574" },
    } },
    .{ .ver = "0.28.816", .items = &.{
        .{ .text = "IGSH-567 Chat View: pending message bubbles cannot be selected and copied", .ticket = "IGSH-567" },
    } },
    .{ .ver = "0.28.815", .items = &.{
        .{ .text = "IGSH-564 Chat View: messages to a busy session stay on Waiting to send (IGSH-460 regression)", .ticket = "IGSH-564" },
        .{ .text = "IGSH-565 Browser pane: old signed-in profile went to another workspace (IGSH-224, 0.28.812)", .ticket = "IGSH-565" },
        .{ .text = "IGSH-571 Chat sync audit: skip Claude \"still running in background\" notices in pane_candidates", .ticket = "IGSH-571" },
    } },
    .{ .ver = "0.28.814", .items = &.{
        .{ .text = "IGSH-568 Multiprompt: usable right after launch while sessions reconnect", .ticket = "IGSH-568" },
    } },
    .{ .ver = "0.28.813", .items = &.{
        .{ .text = "IGSH-564 Chat View: messages to a busy session stay on Waiting to send (IGSH-460 regression)", .ticket = "IGSH-564" },
    } },
    .{ .ver = "0.28.812", .items = &.{
        .{ .text = "IGSH-224 Per-workspace isolated browser profiles and independent bookmarks", .ticket = "IGSH-224" },
        .{ .text = "IGSH-559 Verify journeys fail at setup or cleanup on GitHub, not on the checked feature", .ticket = "IGSH-559" },
    } },
    .{ .ver = "0.28.811", .items = &.{
        .{ .text = "IGSH-549 AI chat: message box sits outside the focus border (0.28.806)", .ticket = "IGSH-549" },
    } },
    .{ .ver = "0.28.810", .items = &.{
        .{ .text = "IGSH-556 Favorites workspace (Alt+1) gets its own session groups", .ticket = "IGSH-556" },
    } },
    .{ .ver = "0.28.809", .items = &.{
        .{ .text = "IGSH-224 Per-workspace isolated browser profiles and independent bookmarks", .ticket = "IGSH-224" },
    } },
    .{ .ver = "0.28.808", .items = &.{
        .{ .text = "IGSH-549 AI chat: message box sits outside the focus border (0.28.806)", .ticket = "IGSH-549" },
    } },
    .{ .ver = "0.28.807", .items = &.{
        .{ .text = "IGSH-224 Per-workspace isolated browser profiles and independent bookmarks", .ticket = "IGSH-224" },
    } },
    .{ .ver = "0.28.806", .items = &.{
        .{ .text = "IGSH-522 Desktop: switching workspaces loses keyboard focus and does not restore the last focus position (0.28.789)", .ticket = "IGSH-522" },
    } },
    .{ .ver = "0.28.805", .items = &.{
        .{ .text = "IGSH-496 Desktop design: equal spacing for every pane, gray groups with one continuous line, group menu in Ctrl+K, rounded browser", .ticket = "IGSH-496" },
        .{ .text = "IGSH-496 Desktop design: equal spacing for every pane, gray groups with one continuous line, group menu in Ctrl+K, rounded browser", .ticket = "IGSH-496" },
        .{ .text = "IGSH-496 Desktop design: equal spacing for every pane, gray groups with one continuous line, group menu in Ctrl+K, rounded browser", .ticket = "IGSH-496" },
        .{ .text = "IGSH-496 Desktop design: equal spacing for every pane, gray groups with one continuous line, group menu in Ctrl+K, rounded browser", .ticket = "IGSH-496" },
        .{ .text = "IGSH-496 Desktop design: equal spacing for every pane, gray groups with one continuous line, group menu in Ctrl+K, rounded browser", .ticket = "IGSH-496" },
        .{ .text = "IGSH-496 Desktop design: equal spacing for every pane, gray groups with one continuous line, group menu in Ctrl+K, rounded browser", .ticket = "IGSH-496" },
        .{ .text = "IGSH-519 Multiprompt GitHub checks under 3 minutes: cache Zig, split Windows tests", .ticket = "IGSH-519" },
    } },
    .{ .ver = "0.28.804", .items = &.{
        .{ .text = "IGSH-127 zsb: persistent device emulation (mobile viewport/UA) + browser-chrome keys unreachable", .ticket = "IGSH-127" },
    } },
    .{ .ver = "0.28.803", .items = &.{
        .{ .text = "IGSH-376 Chat View: format blue messages from other agents like normal output", .ticket = "IGSH-376" },
        .{ .text = "IGSH-511 Desktop: tabs drop and reconnect every 27 seconds after relaunch", .ticket = "IGSH-511" },
        .{ .text = "IGSH-511 Desktop: tabs drop and reconnect every 27 seconds after relaunch", .ticket = "IGSH-511" },
        .{ .text = "IGSH-511 Desktop: tabs drop and reconnect every 27 seconds after relaunch", .ticket = "IGSH-511" },
        .{ .text = "IGSH-511 Desktop: tabs drop and reconnect every 27 seconds after relaunch", .ticket = "IGSH-511" },
        .{ .text = "IGSH-519 Multiprompt GitHub checks under 3 minutes: cache Zig, split Windows tests", .ticket = "IGSH-519" },
        .{ .text = "IGSH-540 Multiprompt dictation: read the Deepgram key from the saved user variable, not the launcher's environment", .ticket = "IGSH-540" },
    } },
    .{ .ver = "0.28.802", .items = &.{
        .{ .text = "IGSH-246 Desktop auto-update: check for a new version on startup and while running, download, install, restart", .ticket = "IGSH-246" },
        .{ .text = "IGSH-252 Sync 5: desktop syncs hosts, workspaces and session state between laptops", .ticket = "IGSH-252" },
        .{ .text = "IGSH-380 Chat sync audit: pane_missing drift", .ticket = "IGSH-380" },
        .{ .text = "IGSH-412 Chat sync audit: transcript_missing drift", .ticket = "IGSH-412" },
        .{ .text = "IGSH-436 Chat View: cut table layout cost back near 0.3 ms per build", .ticket = "IGSH-436" },
        .{ .text = "IGSH-456 Desktop: shell view keeps reverting to the old console font instead of Nordwand Mono", .ticket = "IGSH-456" },
        .{ .text = "IGSH-519 Multiprompt GitHub checks under 3 minutes: cache Zig, split Windows tests", .ticket = "IGSH-519" },
        .{ .text = "IGSH-543 Multiprompt: window is unresponsive on launch until everything loads, and stray Chrome sessions show on the taskbar", .ticket = "IGSH-543" },
        .{ .text = "IGSH-543 Multiprompt: window is unresponsive on launch until everything loads, and stray Chrome sessions show on the taskbar", .ticket = "IGSH-543" },
    } },
    .{ .ver = "0.28.801", .items = &.{
        .{ .text = "IGSH-221 zsb: cdp cannot hold a session across calls, so Profiler/Tracing brackets around a reload are impossible", .ticket = "IGSH-221" },
    } },
    .{ .ver = "0.28.800", .items = &.{
        .{ .text = "IGSH-212 zsb: type sends multi-line text into chat composers (newlines fire as Enter)", .ticket = "IGSH-212" },
    } },
    .{ .ver = "0.28.799", .items = &.{
        .{ .text = "IGSH-154 zsb: app.slack.com never renders in pane, and bridge hangs permanently after a click", .ticket = "IGSH-154" },
        .{ .text = "IGSH-240 zsb: text/screenshot fail on edge:// pages", .ticket = "IGSH-240" },
        .{ .text = "IGSH-278 zsb: open/text hang with no reply (reply_timeout)", .ticket = "IGSH-278" },
        .{ .text = "IGSH-459 zsb: actions fail on GitHub 'token created' page (chrome-extension URL error)", .ticket = "IGSH-459" },
        .{ .text = "IGSH-513 Multiprompt desktop: v0.28.786 fails chat bench header/composer check on every third tab and doubles idle CPU", .ticket = "IGSH-513" },
        .{ .text = "IGSH-523 Browser pane: let me close and reopen it when it is stuck and the page never loads", .ticket = "IGSH-523" },
        .{ .text = "IGSH-543 Multiprompt: window is unresponsive on launch until everything loads, and stray Chrome sessions show on the taskbar", .ticket = "IGSH-543" },
        .{ .text = "IGSH-543 Multiprompt: window is unresponsive on launch until everything loads, and stray Chrome sessions show on the taskbar", .ticket = "IGSH-543" },
        .{ .text = "IGSH-543 Multiprompt: window is unresponsive on launch until everything loads, and stray Chrome sessions show on the taskbar", .ticket = "IGSH-543" },
        .{ .text = "IGSH-543 Multiprompt: window is unresponsive on launch until everything loads, and stray Chrome sessions show on the taskbar", .ticket = "IGSH-543" },
        .{ .text = "IGSH-544 Multiprompt GitHub queue: fewer jobs per PR push (Release builds on PRs, double gitleaks, cancel old runs)", .ticket = "IGSH-544" },
    } },
    .{ .ver = "0.28.798", .items = &.{
        .{ .text = "IGSH-305 zsb: click inside cross-origin app iframe reports clicked but UI does not react", .ticket = "IGSH-305" },
        .{ .text = "IGSH-437 Chat sync audit: raw_markup drift", .ticket = "IGSH-437" },
    } },
    .{ .ver = "0.28.797", .items = &.{
        .{ .text = "IGSH-228 zsb: type command ignores --tab flag, appends it to typed text", .ticket = "IGSH-228" },
        .{ .text = "IGSH-232 zsb: cdp help invokes a CDP method instead of showing usage", .ticket = "IGSH-232" },
        .{ .text = "IGSH-493 Chat View: a keyboard shortcut that inserts the URL of the browser tab I am looking at into the message box", .ticket = "IGSH-493" },
        .{ .text = "IGSH-519 Multiprompt GitHub checks under 3 minutes: cache Zig, split Windows tests", .ticket = "IGSH-519" },
        .{ .text = "IGSH-535 Multiprompt CLI: open a tmux session as a tab in a named workspace group", .ticket = "IGSH-535" },
        .{ .text = "IGSH-537 Chat View: links containing an underscore break and do not show or open correctly", .ticket = "IGSH-537" },
    } },
    .{ .ver = "0.28.796", .items = &.{
        .{ .text = "IGSH-406 Chat sync audit: user messages containing * or _ are wrongly reported as missing", .ticket = "IGSH-406" },
        .{ .text = "IGSH-513 Multiprompt desktop: v0.28.786 fails chat bench header/composer check on every third tab and doubles idle CPU", .ticket = "IGSH-513" },
        .{ .text = "IGSH-513 Multiprompt desktop: v0.28.786 fails chat bench header/composer check on every third tab and doubles idle CPU", .ticket = "IGSH-513" },
        .{ .text = "IGSH-521 Multiprompt 0.28.789: the window flickers heavily, find the cause and stop it", .ticket = "IGSH-521" },
    } },
    .{ .ver = "0.28.795", .items = &.{
        .{ .text = "IGSH-498 Chat View: drafts stay in their own session and the sidebar shows DRAFT", .ticket = "IGSH-498" },
        .{ .text = "IGSH-508 Desktop: shell view default width got wider, restore the old max width", .ticket = "IGSH-508" },
        .{ .text = "IGSH-514 Tab activity watcher uses 0.3 of a server core: rewrite as one process", .ticket = "IGSH-514" },
    } },
    .{ .ver = "0.28.794", .items = &.{
        .{ .text = "IGSH-394 Flaky Windows test: bridge profile pipes sometimes fails with PipeConnectFailed", .ticket = "IGSH-394" },
        .{ .text = "IGSH-405 Chat View: Windows paths inside code lose their backslashes", .ticket = "IGSH-405" },
        .{ .text = "IGSH-444 Desktop: smooth (anti-aliased) edges on the inbox icon, the Send button and every other rounded shape", .ticket = "IGSH-444" },
    } },
    .{ .ver = "0.28.793", .items = &.{
        .{ .text = "IGSH-509 Desktop Chat View: Ctrl+Shift+S screenshot opens the Windows system menu in the top left", .ticket = "IGSH-509" },
    } },
    .{ .ver = "0.28.792", .items = &.{
        .{ .text = "IGSH-460 Chat View: a message shown as queued never reaches the session (lost when two are queued)", .ticket = "IGSH-460" },
        .{ .text = "IGSH-460 Chat View: a message shown as queued never reaches the session (lost when two are queued)", .ticket = "IGSH-460" },
    } },
    .{ .ver = "0.28.791", .items = &.{
        .{ .text = "IGSH-407 Chat View: the Ctrl+F find box types 1 instead of ! and cannot take accented letters", .ticket = "IGSH-407" },
        .{ .text = "IGSH-513 Multiprompt desktop: v0.28.786 fails chat bench header/composer check on every third tab and doubles idle CPU", .ticket = "IGSH-513" },
        .{ .text = "IGSH-514 Tab activity watcher uses 0.3 of a server core: rewrite as one process", .ticket = "IGSH-514" },
    } },
    .{ .ver = "0.28.790", .items = &.{
        .{ .text = "IGSH-394 Flaky Windows test: bridge profile pipes sometimes fails with PipeConnectFailed", .ticket = "IGSH-394" },
        .{ .text = "IGSH-507 Chat bench A/B as a GitHub workflow job; check whether IGSH-453 slowed Chat View paint", .ticket = "IGSH-507" },
        .{ .text = "IGSH-512 Desktop: orange \"locked session disconnected\" flag keeps showing in the shell view", .ticket = "IGSH-512" },
        .{ .text = "IGSH-514 Tab activity watcher uses 0.3 of a server core: rewrite as one process", .ticket = "IGSH-514" },
    } },
    .{ .ver = "0.28.789", .items = &.{
        .{ .text = "IGSH-512 Desktop: orange \"locked session disconnected\" flag keeps showing in the shell view", .ticket = "IGSH-512" },
        .{ .text = "IGSH-402 Chat View: text the agent writes after a tool step shows up before that step", .ticket = "IGSH-402" },
        .{ .text = "IGSH-404 Chat View: copying a very long selection drops the end but still says Copied", .ticket = "IGSH-404" },
        .{ .text = "IGSH-457 Desktop: Starred workspace on Alt+1 that mirrors the inbox Starred split", .ticket = "IGSH-457" },
    } },
    .{ .ver = "0.28.788", .items = &.{
        .{ .text = "IGSH-403 Chat View: clicking a link with accented letters (Krakow with an accent) opens the wrong address", .ticket = "IGSH-403" },
        .{ .text = "IGSH-429 Android: send crash reports to the server so agents can read and fix them", .ticket = "IGSH-429" },
        .{ .text = "IGSH-501 Multiprompt: tabs lose their server link and never reconnect (blank shell view, chat stuck on Waiting for connection)", .ticket = "IGSH-501" },
        .{ .text = "IGSH-503 Ctrl+K: Close All Browser Panes in every session", .ticket = "IGSH-503" },
    } },
    .{ .ver = "0.28.787", .items = &.{
        .{ .text = "IGSH-502 Multiprompt opens instantly: show the last session from cache, load everything else after", .ticket = "IGSH-502" },
        .{ .text = "IGSH-502 Multiprompt opens instantly: show the last session from cache, load everything else after", .ticket = "IGSH-502" },
    } },
    .{ .ver = "0.28.786", .items = &.{
        .{ .text = "IGSH-458 Chat View: wide tables get a real horizontal scrollbar", .ticket = "IGSH-458" },
    } },
    .{ .ver = "0.28.785", .items = &.{
        .{ .text = "IGSH-501 Multiprompt: tabs lose their server link and never reconnect (blank shell view, chat stuck on Waiting for connection)", .ticket = "IGSH-501" },
    } },
    .{ .ver = "0.28.784", .items = &.{
        .{ .text = "IGSH-453 Desktop Chat View: body text too bold, bold words do not stand out", .ticket = "IGSH-453" },
    } },
    .{ .ver = "0.28.783", .items = &.{
        .{ .text = "IGSH-455 Chat View: a file sent to the server is sometimes cut off and its path never appears", .ticket = "IGSH-455" },
        .{ .text = "IGSH-456 Desktop: shell view keeps reverting to the old console font instead of Nordwand Mono", .ticket = "IGSH-456" },
    } },
    .{ .ver = "0.28.782", .items = &.{
        .{ .text = "IGSH-454 Release Multiprompt from GitHub Actions, stop compiling on laptop1", .ticket = "IGSH-454" },
        .{ .text = "IGSH-460 Chat View: a message shown as queued never reaches the session (lost when two are queued)", .ticket = "IGSH-460" },
    } },
    .{ .ver = "0.28.781", .items = &.{
        .{ .text = "IGSH-451 Desktop: focus keeps jumping away from the AI chat typing box again", .ticket = "IGSH-451" },
        .{ .text = "IGSH-451 Desktop: focus keeps jumping away from the AI chat typing box again", .ticket = "IGSH-451" },
    } },
    .{ .ver = "0.28.780", .items = &.{
        .{ .text = "IGSH-450 Desktop: the shell view is gone after the latest releases", .ticket = "IGSH-450" },
    } },
    .{ .ver = "0.28.779", .items = &.{
        .{ .text = "IGSH-401 Chat View: replies that start with words like Ready, Searching or Editing are hidden", .ticket = "IGSH-401" },
    } },
    .{ .ver = "0.28.778", .items = &.{
        .{ .text = "IGSH-448 Approve a new device with one tap: a new laptop or phone makes its own key and reaches every server", .ticket = "IGSH-448" },
    } },
    .{ .ver = "0.28.777", .items = &.{
        .{ .text = "IGSH-444 Desktop: smooth (anti-aliased) edges on the inbox icon, the Send button and every other rounded shape", .ticket = "IGSH-444" },
    } },
    .{ .ver = "0.28.776", .items = &.{
        .{ .text = "IGSH-443 Desktop: IBM Plex Sans is the only font for everything outside the shell, Nordwand Mono SemiBold in the shell", .ticket = "IGSH-443" },
    } },
    .{ .ver = "0.28.775", .items = &.{
        .{ .text = "IGSH-442 Desktop Chat View: a \"Delivery unconfirmed\" message must offer Send again and Remove, never just sit there", .ticket = "IGSH-442" },
        .{ .text = "IGSH-442 Desktop Chat View: a \"Delivery unconfirmed\" message must offer Send again and Remove, never just sit there", .ticket = "IGSH-442" },
        .{ .text = "IGSH-442 Desktop Chat View: a \"Delivery unconfirmed\" message must offer Send again and Remove, never just sit there", .ticket = "IGSH-442" },
    } },
    .{ .ver = "0.28.774", .items = &.{
        .{ .text = "IGSH-443 Desktop: IBM Plex Sans is the only font for everything outside the shell, Nordwand Mono SemiBold in the shell", .ticket = "IGSH-443" },
        .{ .text = "IGSH-445 Desktop Chat View: smoother, slightly bolder body text, and let Valentin pick the spacing", .ticket = "IGSH-445" },
        .{ .text = "IGSH-445 Desktop Chat View: smoother, slightly bolder body text, and let Valentin pick the spacing", .ticket = "IGSH-445" },
    } },
    .{ .ver = "0.28.773", .items = &.{
        .{ .text = "IGSH-393 Chat View: drop a non-image file (PDF, log, zip) and send it to the server over ssh", .ticket = "IGSH-393" },
    } },
    .{ .ver = "0.28.772", .items = &.{
        .{ .text = "IGSH-443 Desktop: IBM Plex Sans is the only font for everything outside the shell, Nordwand Mono SemiBold in the shell", .ticket = "IGSH-443" },
        .{ .text = "IGSH-443 Desktop: IBM Plex Sans is the only font for everything outside the shell, Nordwand Mono SemiBold in the shell", .ticket = "IGSH-443" },
    } },
    .{ .ver = "0.28.771", .items = &.{
        .{ .text = "IGSH-423 Android: full-screen Session list settings with split switches, synced with desktop", .ticket = "IGSH-423" },
    } },
    .{ .ver = "0.28.770", .items = &.{
        .{ .text = "IGSH-438 Desktop Chat View: selecting and copying text is broken, right-click Copy does nothing", .ticket = "IGSH-438" },
        .{ .text = "IGSH-438 Desktop Chat View: selecting and copying text is broken, right-click Copy does nothing", .ticket = "IGSH-438" },
        .{ .text = "IGSH-438 Desktop Chat View: selecting and copying text is broken, right-click Copy does nothing", .ticket = "IGSH-438" },
    } },
    .{ .ver = "0.28.769", .items = &.{
        .{ .text = "IGSH-422 Sign in first: sign-in is part of setup on desktop and Android, and the account carries all shared state", .ticket = "IGSH-422" },
    } },
    .{ .ver = "0.28.768", .items = &.{
        .{ .text = "IGSH-429 Android: send crash reports to the server so agents can read and fix them", .ticket = "IGSH-429" },
    } },
    .{ .ver = "0.28.767", .items = &.{
        .{ .text = "IGSH-439 Desktop: switching back to a workspace lands on the btop session instead of the session I was on", .ticket = "IGSH-439" },
    } },
    .{ .ver = "0.28.766", .items = &.{
        .{ .text = "IGSH-440 Desktop: a full-width session forces the shell view even when every session is set to Chat View", .ticket = "IGSH-440" },
        .{ .text = "IGSH-441 Desktop shell view: try the Nordwand Mono font", .ticket = "IGSH-441" },
    } },
    .{ .ver = "0.28.765", .items = &.{
    } },
    .{ .ver = "0.28.764", .items = &.{
    } },
    .{ .ver = "0.28.763", .items = &.{
    } },
    .{ .ver = "0.28.762", .items = &.{
    } },
    .{ .ver = "0.28.761", .items = &.{
    } },
    .{ .ver = "0.28.760", .items = &.{
    } },
    .{ .ver = "0.28.759", .items = &.{
    } },
    .{ .ver = "0.28.758", .items = &.{
    } },
    .{ .ver = "0.28.757", .items = &.{
    } },
    .{ .ver = "0.28.756", .items = &.{
    } },
    .{ .ver = "0.28.755", .items = &.{
    } },
    .{ .ver = "0.28.754", .items = &.{
    } },
    .{ .ver = "0.28.753", .items = &.{
    } },
    .{ .ver = "0.28.752", .items = &.{
    } },
    .{ .ver = "0.28.751", .items = &.{
    } },
    .{ .ver = "0.28.750", .items = &.{
    } },
    .{ .ver = "0.28.749", .items = &.{
    } },
    .{ .ver = "0.28.748", .items = &.{
    } },
    .{ .ver = "0.28.747", .items = &.{
    } },
    .{ .ver = "0.28.746", .items = &.{
    } },
    .{ .ver = "0.28.745", .items = &.{
    } },
    .{ .ver = "0.28.744", .items = &.{
    } },
    .{ .ver = "0.28.743", .items = &.{
    } },
    .{ .ver = "0.28.742", .items = &.{
    } },
    .{ .ver = "0.28.741", .items = &.{
    } },
    .{ .ver = "0.28.740", .items = &.{
    } },
    .{ .ver = "0.28.739", .items = &.{
    } },
    .{ .ver = "0.28.738", .items = &.{
    } },
    .{ .ver = "0.28.737", .items = &.{
    } },
    .{ .ver = "0.28.736", .items = &.{
    } },
    .{ .ver = "0.28.735", .items = &.{
    } },
    .{ .ver = "0.28.734", .items = &.{
    } },
    .{ .ver = "0.28.733", .items = &.{
    } },
    .{ .ver = "0.28.732", .items = &.{
    } },
    .{ .ver = "0.28.731", .items = &.{
    } },
    .{ .ver = "0.28.730", .items = &.{
    } },
    .{ .ver = "0.28.729", .items = &.{
    } },
    .{ .ver = "0.28.728", .items = &.{
    } },
    .{ .ver = "0.28.727", .items = &.{
    } },
    .{ .ver = "0.28.726", .items = &.{
    } },
    .{ .ver = "0.28.725", .items = &.{
    } },
    .{ .ver = "0.28.724", .items = &.{
    } },
    .{ .ver = "0.28.723", .items = &.{
    } },
    .{ .ver = "0.28.722", .items = &.{
    } },
    .{ .ver = "0.28.721", .items = &.{
    } },
    .{ .ver = "0.28.720", .items = &.{
    } },
    .{ .ver = "0.28.719", .items = &.{
    } },
    .{ .ver = "0.28.717", .items = &.{
    } },
    .{ .ver = "0.28.716", .items = &.{
    } },
    .{ .ver = "0.28.715", .items = &.{
    } },
    .{ .ver = "0.28.714", .items = &.{
    } },
    .{ .ver = "0.28.713", .items = &.{
    } },
    .{ .ver = "0.28.712", .items = &.{
    } },
    .{ .ver = "0.28.711", .items = &.{
    } },
    .{ .ver = "0.28.710", .items = &.{
    } },
    .{ .ver = "0.28.709", .items = &.{
    } },
    .{ .ver = "0.28.708", .items = &.{
    } },
    .{ .ver = "0.28.707", .summary = "Chat View is responsive again", .items = &.{
    } },
    .{ .ver = "0.28.706", .summary = "Chat View shows the whole conversation again", .items = &.{
    }, .ticket = "" },
    .{ .ver = "0.28.705", .summary = "Chat tabs switch before the browser", .items = &.{
    }, .ticket = "" },
    .{ .ver = "0.28.704", .summary = "Agents no longer steal your typing", .items = &.{
    } },
    .{ .ver = "0.28.703", .summary = "Square corners on the message box", .items = &.{
    } },
    .{ .ver = "0.28.702", .summary = "Pictures in Chat View", .items = &.{
    } },
    .{ .ver = "0.28.701", .summary = "Safer reminders and crash recovery", .items = &.{
    } },
    .{ .ver = "0.28.700", .summary = "One bubble per reply", .items = &.{
    } },
    .{ .ver = "0.28.699", .summary = "Chat View bubbles", .items = &.{
    } },
    .{ .ver = "0.28.698", .summary = "Focus border stays put", .items = &.{
    } },
    .{ .ver = "0.28.697", .summary = "Calmer focus ring", .items = &.{
    } },
    .{ .ver = "0.28.696", .summary = "Crash reports and auto-reopen", .items = &.{
    } },
    .{ .ver = "0.28.695", .summary = "Shell column width after a font change", .items = &.{
    } },
    .{ .ver = "0.28.694", .summary = "Font size changes are instant", .items = &.{
    } },
    .{ .ver = "0.28.693", .summary = "Alt+Tab back keeps the cursor", .items = &.{
    } },
    .{ .ver = "0.28.692", .summary = "5-hour window is back", .items = &.{
    } },
    .{ .ver = "0.28.691", .summary = "Chat View screenshot caret, instant tab switch, queued messages", .items = &.{
    } },
    .{ .ver = "0.28.690", .summary = "Snoozed workspaces always come back", .items = &.{
    } },
    .{ .ver = "0.28.689", .summary = "Agent pane requests stay in the background", .items = &.{
    } },
    .{ .ver = "0.28.688", .summary = "Synced tabs stay put", .items = &.{
    } },
    .{ .ver = "0.28.687", .summary = "Your typing stays yours, plus a Relaunch card", .items = &.{
    } },
    .{ .ver = "0.28.685", .summary = "Sign in once and every laptop shows the same tabs", .items = &.{
    } },
    .{ .ver = "0.28.684", .summary = "Sessions follow you between laptops; agents can test their pane", .items = &.{
    } },
    .{ .ver = "0.28.683", .summary = "Agents keep their own browser pane", .items = &.{
    } },
    .{ .ver = "0.28.682", .summary = "Chat View no longer claims a lost message was sent", .items = &.{
    } },
    .{ .ver = "0.28.681", .summary = "Shortcuts work again after unlocking the screen", .items = &.{
    } },
    .{ .ver = "0.28.680", .summary = "Chat View shows when the AI is working", .items = &.{
    } },
    .{ .ver = "0.28.679", .summary = "Chat View shows where Alt+Q put you", .items = &.{
    } },
    .{ .ver = "0.28.678", .summary = "Alt+Q into the browser stays there in Chat View", .items = &.{
    } },
    .{ .ver = "0.28.677", .summary = "Chat View sends each message once", .items = &.{
    } },
    .{ .ver = "0.28.676", .summary = "Agent page opens always show the page", .items = &.{
    } },
    .{ .ver = "0.28.675", .summary = "Agent page opens report correctly", .items = &.{
    } },
    .{ .ver = "0.28.674", .summary = "Browser pane stays connected", .items = &.{
    } },
    .{ .ver = "0.28.673", .summary = "Alt+Q works in Chat View", .items = &.{
    } },
    .{ .ver = "0.28.672", .summary = "Alt+Q switches once", .items = &.{
    } },
    .{ .ver = "0.28.671", .summary = "No more layout jumping on tabs with a browser", .items = &.{
    } },
    .{ .ver = "0.28.670", .summary = "Mouse and Alt+Q work in Chat View", .items = &.{
    } },
    .{ .ver = "0.28.669", .summary = "Browser panes stay behind overlays", .items = &.{
    } },
    .{ .ver = "0.28.668", .summary = "Hotfix: typing works again", .items = &.{
    } },
    .{ .ver = "0.28.667", .summary = "Chat View fixes: paste, focus, queued messages, battery", .items = &.{
    } },
    .{ .ver = "0.28.666", .summary = "Sent messages show up instantly with a status", .items = &.{
    } },
    .{ .ver = "0.28.665", .summary = "Chat View shows whole conversations again", .items = &.{
    } },
    .{ .ver = "0.28.664", .summary = "Focus stops jumping while you type", .items = &.{
    } },
    .{ .ver = "0.28.663", .summary = "Fixes for the 0.28.662 problems", .items = &.{
    } },
    .{ .ver = "0.28.662", .summary = "Chat View you can actually read on a train", .items = &.{
    } },
    .{ .ver = "0.28.661", .summary = "Chat View sends reliably", .items = &.{
    } },
    .{ .ver = "0.28.660", .summary = "A clearer, richer Chat View", .items = &.{
    } },
    .{ .ver = "0.28.659", .summary = "Command palette from the browser pane", .items = &.{
    } },
    .{ .ver = "0.28.658", .summary = "Links, blue dots and Inbox fixes", .items = &.{
    } },
    .{ .ver = "0.28.657", .summary = "Blue dots only when agents finish or need input", .items = &.{
    } },
    .{ .ver = "0.28.656", .summary = "Archived sessions only return with new content", .items = &.{
    } },
    .{ .ver = "0.28.655", .summary = "Inbox button in the workspace strip", .items = &.{
    } },
    .{ .ver = "0.28.654", .summary = "Crash fix, notifications on every laptop, voice and link fixes", .items = &.{
    } },
    .{ .ver = "0.28.652", .summary = "Sign-in fix", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.651", .summary = "Snooze a workspace", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.650", .summary = "Chat View command and skill suggestions", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.649", .summary = "Pick how fast Voice Mode talks", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.648", .summary = "Voice Mode works like a phone call", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.647", .summary = "Voice Mode starts faster and talks faster", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.646", .summary = "Chat View per tab, Enter always sends, Voice Mode skips links", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.645", .summary = "Time estimates per tab, Ctrl+K in Chat View", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.644", .summary = "Voice Mode reads finished replies, calmer Chat View", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.643", .summary = "Chat View: Ctrl+K and browser pane", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.642", .summary = "Voice Mode says what it is doing", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.641", .summary = "Deepgram voice always found", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.640", .summary = "Better voice, smoother Chat View, sync sign-in", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.639", .summary = "Voice Mode", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.638", .summary = "Shortcuts work in Chat View", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.637", .summary = "Chat View looks like a chat app", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.636", .summary = "Chat View reads like a chat app", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.635", .summary = "Battery saver: multiprompt uses far less power in the background", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.634", .summary = "Alt+S no longer blocks the extension screenshot shortcut", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.633", .summary = "Workspace search follows typed names and duplicate Other slots merge safely", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.632", .summary = "Alt+Q switches focus once per keypress", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.631", .summary = "Open every tmux session from one VPS", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.630", .summary = "Remote host 3 tmux sessions reconnect natively", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.629", .summary = "Skills belong in Ctrl+K", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.628", .summary = "Chat View skills and secure desktop login foundation", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.619", .summary = "Chat View reflows narrow console history", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.618", .summary = "Chat View respects the docked browser split", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.617", .summary = "Chat View uses the app surface and sends reliably to local agents", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.616", .summary = "Chat View puts a native conversation layer over any terminal", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.615", .summary = "workspace names and history survive window-mode changes", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.614", .summary = "keyboard shortcuts recover immediately after hibernation", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.613", .summary = "zsb tab control and difficult pages are reliable", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.612", .summary = "zsb interaction and diagnostics are reliable", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.611", .summary = "Cursor CLI has its own sidebar identity", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.610", .summary = "Move sessions to groups from Ctrl+K", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.606", .summary = "Workspace groups own sidebar organization", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.605", .summary = "Closing a workspace hibernates locked sessions", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.604", .summary = "Grok identity and neutral workspace terminals", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.603", .summary = "Ctrl+click and shortcuts recover after hibernation", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.602", .summary = "Saved VPS sessions reconnect through their SSH profiles", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.601", .summary = "Hax has its own terminal identity", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.600", .summary = "Claude telemetry reconnect skips live accounts", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.599", .summary = "Weekly AI usage shows its real reset", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.598", .summary = "Headless agents cannot borrow another session's browser", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.597", .summary = "Chrome panes no longer close themselves after binding", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.596", .summary = "A delayed second Alt+A cycle cannot close a fresh Chrome pane", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.595", .summary = "Alt+A cannot cancel the Chrome launch it just started", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.594", .summary = "Alt+A ignores a complete duplicate key cycle", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.593", .summary = "Dedicated Chrome panes finish docking instead of staying off-screen", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.592", .summary = "Alt+A opens Chrome once and leaves it open", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.591", .summary = "Every browser pane can globally switch between dedicated Edge and Chrome", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.590", .summary = "Shielded browser tabs never jump outside", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.589", .summary = "Repeat screenshots use one path and snippet typing lands", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.588", .summary = "Shell link clicks open in the foreground", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.587", .summary = "System theme self-corrects after missed Windows broadcasts", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.586", .summary = "System theme follows Windows across app and browser", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.585", .summary = "isolated Edge chrome follows the multiprompt theme", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.584", .summary = "Enter stops an active dictation recording", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.583", .summary = "dictation is delivered and verified inside SSH/tmux", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.582", .summary = "dragged bookmarks survive harmless redirect normalization", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.581", .summary = "isolated browser commands cannot cross into ordinary Edge", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.580", .summary = "browser panes are isolated from Windows and PWA launches", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.579", .summary = "Other is always available as the catch-all workspace", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.578", .summary = "Dictation uses the verified conhost paste gesture", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.577", .summary = "Waiting and Archived are separate destinations", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.576", .summary = "Inbox reduction search and reliable dictation paste", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.575", .summary = "Windows-level shortcuts pass through", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.574", .summary = "Locked sessions use a quiet outline icon", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.573", .summary = "Locked sessions cannot be closed accidentally", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.572", .summary = "Alt+Z undoes the last session archive", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.571", .summary = "Dictation pastes the complete transcript", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.570", .summary = "AI usage is native and cards-only", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.569", .summary = "Telemetry survives resume outages and provider cooldowns", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.568", .summary = "Claude telemetry self-refreshes and shows Fable", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.567", .summary = "Daily AI goals show overage above 100%", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.566", .summary = "VPS health explains percentages and Critical limits", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.565", .summary = "Hidden sessions self-heal after restart", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.564", .summary = "Ctrl+K repairs stale AI usage logins", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.563", .summary = "Finished sessions recover blue dots and Ctrl+K toggles back", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.562", .summary = "The usage backend no longer starts the tray companion", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.561", .summary = "The AI usage companion is optional", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.560", .summary = "Five-hour usage shows its live reset countdown", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.557", .summary = "AI cards show only today's progress and real quota windows", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.556", .summary = "AI cards show progress toward today's normalized goal", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.555", .summary = "The sticky card remembers its page and links every usage report", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.554", .summary = "AI detail lines are no longer clipped", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.553", .summary = "The sticky card always switches when clicked", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.552", .summary = "Workspaces no longer have a four-agent ceiling", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.551", .summary = "Claude accounts use their real email names", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.550", .summary = "Every AI account gets a readable slot", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.549", .summary = "AI Pace separates both Claude accounts", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.548", .summary = "Sticky sidebar carousel keeps capacity visible", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.547", .summary = "AI Usage Coach turns subscriptions into daily goals", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.546", .summary = "Usage popup opens at its tray icon and dismisses normally", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.545", .summary = "AI usage is one Ctrl+K away", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.544", .summary = "Dragged bookmarks stay in the docked browser", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.543", .summary = "Edge favorites stay in the docked browser", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.542", .summary = "Sidebar shows the active VPS at a glance", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.541", .summary = "All Sessions shows per-session and workspace RAM", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.540", .summary = "Monitor moves are one verified window transaction", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.539", .summary = "Other workspace Alt+T opens the projects tmux shell", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.538", .summary = "VPS capacity guardian prevents overload", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.537", .summary = "Docked browser text selection uses native mouse input", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.536", .summary = "Bookmarks wait for commit provenance; Edge menus keep focus", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.535", .summary = "Sessions can be dragged between Pinned and Recents", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.534", .summary = "Outside links require verified page provenance", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.533", .summary = "Ctrl+T belongs to the browser; Alt+T opens a shell", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.532", .summary = "Ctrl+K ranks intent before decaying usage", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.531", .summary = "Ctrl+T follows the workspace repo and Ctrl+K learns usage", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.530", .summary = "Outside links fail closed with a durable audit", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.529", .summary = "Searched pickers select their first match", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.528", .summary = "Notification clicks survive extension worker wake", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.527", .summary = "Restored shells redraw at their full height", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.526", .summary = "Edge's three-dot menu is clickable again", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.525", .summary = "Hidden, unattached, and killed sessions restore separately", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.524", .summary = "Workspace unarchive cannot resurrect dissolved sessions", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.523", .summary = "Remote blue dots keep their tunnel", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.522", .summary = "Browser focus, Alt+W, and notification clicks complete", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.521", .summary = "Web-notification clicks open their exact target", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.520", .summary = "Docked-browser clicks cannot regress into HTML downloads", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.519", .summary = "Agent navigation can never overwrite browser tabs", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.518", .summary = "Alt+W restores the URL picker", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.517", .summary = "Links obey browser boundaries; URL picker moves to Alt+O", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.516", .summary = "Large workspaces switch smoothly; page links stay docked", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.515", .summary = "Browser crashes cannot freeze or trap multiprompt", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.514", .summary = "Workspace unarchive restores purple dissolved sessions too", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.513", .summary = "Browser panes stay painted; large workspaces keep growing", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.512", .summary = "Native browser clicks cannot inherit a stale Alt key", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.511", .summary = "Protected browser panes neutralize stale Alt-click downloads", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.510", .summary = "Docked-browser clicks stop downloading HTML pages", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.509", .summary = "Returned archived sessions stay returned after interaction", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.508", .summary = "Alt+X keeps focus inside multiprompt; restore all filed sessions", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.507", .summary = "consecutive extension screenshots stay fast", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.506", .summary = "dissolved-session archive grows without a fixed limit", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.505", .summary = "per-monitor DPI follows the window; terminal zoom is independent", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.504", .summary = "native DPI zoom and restored console rows stay aligned", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.503", .summary = "embedded browser links preserve their own tabs", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.502", .summary = "typing and focus work inside the embedded WebView", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.501", .summary = "WebView2 and Edge are strictly exclusive; shell links stay in WebView2", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.500", .summary = "optional embedded WebView2 browser on Alt+S", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.499", .summary = "repair taskbar identity and stale browser overlays", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.490", .summary = "restore the original full pane focus border", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.488", .summary = "clearer active session emphasis", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.487", .summary = "clean native agent icons and better spacing", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.486", .summary = "clean full-height multiprompt separators", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.485", .summary = "multiprompt theme border and browser-cover polish", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.484", .summary = "multiprompt theme promoted to stable", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.483", .summary = "multiprompt identity and DEV visual preview", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.482", .summary = "ZigShell is now multiprompt", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.481", .summary = "Suppress Edge's zsb debugger infobar", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.480", .summary = "Ctrl+F reduces All Sessions live", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.479", .summary = "Ctrl+K tmux sessions stick immediately", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.478", .summary = "zsb background SPA and tab control fixes", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.477", .summary = "Screenshot links return focus to their shell", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.476", .summary = "All Sessions reactivates filed-away sessions", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.475", .summary = "one Alt+Tab explicitly leaves the whole ZigShell task", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.474", .summary = "reminders preserve the running tmux session", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.473", .summary = "Alt+H opens Remind Me", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.472", .summary = "one Alt+Tab leaves ZigShell from a browser pane", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.471", .summary = "zsb self-heals every configured missing pane", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.470", .summary = "Isolate ZigShell taskbar identity", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.469", .summary = "Window title follows Inbox and session workspace", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.468", .summary = "Inbox keeps bare and Alt triage keys", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.467", .summary = "Inbox returns to the same selected session", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.466", .summary = "Archived Inbox rows cannot return as spinners", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.465", .summary = "Undo Inbox archive and restore the last viewed session", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.464", .summary = "Browser frame masks stay inside ZigShell", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.463", .summary = "Inbox hide waits for a real blue dot", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.462", .summary = "Inbox names get more horizontal room", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.461", .summary = "Rename sessions directly in Inbox", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.460", .summary = "Saved snippets can be deleted", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.459", .summary = "Snippet forms no longer gray out browser panes", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.458", .summary = "Snippet form stays above docked browser panes", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.457", .summary = "Alt+U marks the active session unread", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.456", .summary = "Alt+X closes non-tmux sessions too", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.455", .summary = "Alt+W opens links from the shell", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.454", .summary = "Alt+A opens the browser pane", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.453", .summary = "Sessions can be pinned to the top of the workspace sidebar", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.452", .summary = "Alt+Q is the browser focus toggle", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.451", .summary = "Alt+J/K walks the Inbox thread you opened", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.450", .summary = "Browser edge masks do not leak onto shell-only tabs", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.449", .summary = "External links deflect to a visible Edge window", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.448", .summary = "Browser bookmarks stay docked again", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.447", .summary = "PWA external links leave zsb panes", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.446", .summary = "zsb new tabs stop stealing foreground", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.445", .summary = "Notification sound toggle in Ctrl+K", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.444", .summary = "External app links leave docked panes", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.443", .summary = "Docked browser panes stay out of Alt+Tab", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.442", .summary = "Browser screenshot links", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.441", .summary = "Quiet startup and regular browser foreground", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.440", .summary = "Docked browser shortcuts stay docked", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.439", .summary = "No browser/zsb foreground noise", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.438", .summary = "Browser shortcut legacy aliases removed", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.437", .summary = "Restore free browser split dragging", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.436", .summary = "HD browser split and shortcut badges", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.435", .summary = "Smaller Inbox split unread dots", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.434", .summary = "Inbox split dots only show unread splits", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.433", .summary = "Trial Alt+B / Alt+F browser shortcuts", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.432", .summary = "Alt+M browser focus toggle", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.431", .summary = "Alt+I is the Inbox toggle", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.430", .summary = "URL click hook arms after restore", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.429", .summary = "Wrapped shell URLs open completely", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.428", .summary = "Ctrl-click links stay in the docked browser", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.427", .summary = "Ctrl+` browser focus shortcut", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.426", .summary = "Browser panes stay alive for agents + dissolve/resurrect fixes", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.425", .summary = "Claude sessions no longer show the Codex icon", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.424", .summary = "Archive is now called Dissolve, with a Ctrl+Shift+X shortcut", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.423", .summary = "Remind Me presets: snooze a session with one pick", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.422", .summary = "Hidden tabs show up in the archived view", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.421", .summary = "Hidden tabs actually leave the sidebar now", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.420", .summary = "Browse your archived sessions in All Sessions", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.419", .summary = "Browser pane controls cover fixed on the laptop monitor", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.418", .summary = "Browser focus ring shows its bottom edge again", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.417", .summary = "External links now bring the outside browser window to the front", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.416", .summary = "Cross-monitor font fix now works on VPS/SSH tabs", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.415", .summary = "Console font stays the right size across monitors", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.414", .summary = "Filter All Sessions to unattached only", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.413", .summary = "Close a session straight from All Sessions", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.412", .summary = "All Sessions now loads every VPS session", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.411", .summary = "Jump between All Sessions and Inbox", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.410", .summary = "All Sessions splits by workspace", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.409", .summary = "Opening a session lands in the right workspace", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.408", .summary = "All Sessions shows every session", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.407", .summary = "Fix docked browser flicker", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.406", .summary = "Diagnostic build (browser tracing)", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.403", .summary = "Revert custom browser fallback", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.401", .summary = "Rollback browser focus churn", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.400", .summary = "Keep bridge versions visible", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.399", .summary = "Add All Sessions shortcut", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.398", .summary = "Stabilize browser pane and complete VPS sessions", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.397", .summary = "Inbox-style All Sessions view", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.396", .summary = "Prioritize Show All Sessions", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.395", .summary = "Repo session overview and zsb tab routing", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.394", .summary = "Make tmux recovery discoverable", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.393", .summary = "Keep browser masks stable", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.392", .summary = "Quiet browser chrome switching", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.391", .summary = "Restore browser pane after Alt-Tab", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.390", .summary = "Reassert docked browser on focus", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.389", .summary = "Stabilize docked browser foreground", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.388", .summary = "Safer hide-until-attention shortcut", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.387", .summary = "", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.385", .summary = "", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.384", .summary = "", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.383", .summary = "", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.382", .summary = "", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.303", .summary = "", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.302", .summary = "", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.301", .summary = "", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.300", .summary = "", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.299", .summary = "", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.298", .summary = "", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.297", .summary = "", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.296", .summary = "", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.295", .summary = "", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.294", .summary = "", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.293", .summary = "", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.292", .summary = "", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.291", .summary = "", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.290", .summary = "", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.289", .summary = "", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.288", .summary = "", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.287", .summary = "", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.286", .summary = "", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.285", .summary = "", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.284", .summary = "", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.283", .summary = "", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.282", .summary = "", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.281", .summary = "", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.280", .summary = "", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.279", .summary = "", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.278", .summary = "", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.277", .summary = "", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.276", .items = &.{
    } },
    .{ .ver = "0.28.275", .items = &.{
    } },
    .{ .ver = "0.28.274", .items = &.{
    } },
    .{ .ver = "0.28.273", .items = &.{
    } },
    .{ .ver = "0.28.272", .summary = "", .ticket = "", .items = &.{
    } },
    .{ .ver = "0.28.271", .items = &.{
    } },
    .{ .ver = "0.28.270", .items = &.{
    } },
    .{ .ver = "0.28.269", .items = &.{
    } },
    .{ .ver = "0.28.268", .items = &.{
    } },
    .{ .ver = "0.28.267", .items = &.{
    } },
    .{ .ver = "0.28.266", .items = &.{
    } },
    .{ .ver = "0.28.265", .items = &.{
    } },
    .{ .ver = "0.28.264", .items = &.{
    } },
};

comptime {
    @setEvalBranchQuota(10_000_000);
    if (CHANGELOG.len == 0 or !std.mem.eql(u8, CHANGELOG[0].ver, APP_VERSION)) {
        @compileError("CHANGELOG in src/changelog.zig must start with an entry for APP_VERSION " ++ APP_VERSION ++ "; add .{ .ver = \"" ++ APP_VERSION ++ "\", .items = &.{ ... } } at the top");
    }
    for (CHANGELOG, 0..) |entry, i| {
        for (CHANGELOG[0..i]) |previous| {
            if (std.mem.eql(u8, previous.ver, entry.ver)) {
                @compileError("CHANGELOG in src/changelog.zig has duplicate version " ++ entry.ver ++ "; correct the version or merge its bullets into one entry");
            }
        }
        const version = std.SemanticVersion.parse(entry.ver) catch
            @compileError("CHANGELOG entry " ++ entry.ver ++ " in src/changelog.zig has an invalid version; use dotted numeric major.minor.patch");
        if (i > 0) {
            const previous = std.SemanticVersion.parse(CHANGELOG[i - 1].ver) catch unreachable;
            if (previous.order(version) != .gt) {
                @compileError("CHANGELOG entry " ++ entry.ver ++ " in src/changelog.zig must follow " ++ CHANGELOG[i - 1].ver ++ " in strictly descending numeric version order; correct the version or move the entry");
            }
        }
    }
}

const words = @import("ui_words.zon");
const smooth = @import("smooth.zig");
const Selection = app_state.ChangelogSelection;
const max_change_bytes = blk: {
    @setEvalBranchQuota(10_000_000);
    var n: usize = 1;
    for (SOURCE_CHANGELOG) |entry| {
        n = @max(n, entry.summary.len);
        for (entry.items) |item| n = @max(n, item.text.len);
    }
    break :blk n;
};

fn changeFont(size: i32, weight: i32) HANDLE {
    return @import("fonts.zig").create(-uiScaled(size), 0, 0, 0, weight, 0, 0, 0, 0, 0, 0, 5, 0, null);
}

var changelog_body_font: HANDLE = null;
var changelog_body_owned = false;
var changelog_body_scale: i32 = 0;

fn bodyFont() HANDLE {
    const scale = uiScaled(100);
    if (changelog_body_font != null and changelog_body_scale == scale) return changelog_body_font;
    if (changelog_body_owned) _ = DeleteObject(changelog_body_font);
    changelog_body_font = changeFont(14, 400);
    changelog_body_owned = changelog_body_font != null;
    if (!changelog_body_owned) changelog_body_font = @import("win32.zig").GetStockObject(@import("win32.zig").DEFAULT_GUI_FONT);
    changelog_body_scale = scale;
    return changelog_body_font;
}

pub fn resetChangelogLayout() void {
    if (changelog_body_owned) _ = DeleteObject(changelog_body_font);
    changelog_body_font = null;
    changelog_body_owned = false;
    changelog_layout_width = -1;
}

fn changeText(hdc: HANDLE, text: []const u8, rc: *RECT, flags: u32) void {
    var wide: [max_change_bytes]u16 = undefined;
    const n = std.unicode.utf8ToUtf16Le(&wide, text) catch return;
    _ = DrawTextW(hdc, &wide, @intCast(n), rc, flags);
}

fn rowHeight() i32 {
    return @max(1, uiScaled(34));
}

fn noteCount(idx: usize) usize {
    const entry = CHANGELOG[idx];
    return entry.items.len;
}

fn noteSelection(idx: usize, item: usize) Selection {
    return .{ .entry = idx, .item = if (CHANGELOG[idx].items.len > 0) item else null };
}

const max_entry_items = blk: {
    @setEvalBranchQuota(10_000_000);
    var count: usize = 1;
    for (SOURCE_CHANGELOG) |entry| count = @max(count, entry.items.len);
    break :blk count;
};
var changelog_row_tops: [CHANGELOG.len + 1]i32 = .{0} ** (CHANGELOG.len + 1);
var changelog_ranges: [CHANGELOG.len][max_entry_items]ChangelogEntryRange = undefined;
var changelog_layout_width: i32 = -1;
var changelog_layout_scale: i32 = 0;
var changelog_layout_compact = false;

fn prepareChangelogLayout(width: i32, compact: bool) void {
    const scale = uiScaled(100);
    if (width == changelog_layout_width and scale == changelog_layout_scale and compact == changelog_layout_compact) return;
    changelog_layout_width = width;
    changelog_layout_scale = scale;
    changelog_layout_compact = compact;
    const row = rowHeight();
    const hdc = @import("win32.zig").GetDC(app_state.g_main_hwnd);
    if (hdc == null) changelog_layout_width = -1;
    defer {
        if (hdc != null) {
            _ = @import("win32.zig").ReleaseDC(app_state.g_main_hwnd, hdc);
        }
    }
    const usable = @max(1, width - uiScaled(if (compact) 32 else 152));
    const font = bodyFont();
    const old_font = if (hdc != null and font != null) SelectObject(hdc, font) else null;
    defer {
        if (old_font != null) {
            _ = SelectObject(hdc, old_font);
        }
    }
    changelog_row_tops[0] = 0;
    for (CHANGELOG, 0..) |entry, idx| {
        if (entry.items.len == 0) {
            changelog_row_tops[idx + 1] = changelog_row_tops[idx];
            continue;
        }
        var top = changelog_row_tops[idx] + row;
        for (entry.items, 0..) |item, i| {
            var measure = rect(0, 0, usable, 0);
            if (hdc != null) changeText(hdc, item.text, &measure, @import("win32.zig").DT_WORDBREAK | @import("win32.zig").DT_CALCRECT | DT_NOPREFIX);
            const height = @max(row, measure.bottom + uiScaled(12));
            changelog_ranges[idx][i] = .{ .top = top, .h = height };
            top += height;
        }
        changelog_row_tops[idx + 1] = top + if (idx + 1 < CHANGELOG.len) @max(0, uiScaled(8)) else 0;
    }
}

fn changelogIndexAtContentY(y: i32) ?usize {
    if (y < 0 or y >= changelog_row_tops[CHANGELOG.len]) return null;
    var lo: usize = 0;
    var hi: usize = CHANGELOG.len;
    while (lo < hi) {
        const mid = lo + (hi - lo) / 2;
        if (changelog_row_tops[mid + 1] <= y) lo = mid + 1 else hi = mid;
    }
    return lo;
}

fn selectionRange(selection: Selection) ChangelogEntryRange {
    return changelog_ranges[selection.entry][selection.item orelse 0];
}

pub fn firstChangelogSelection() ?Selection {
    for (CHANGELOG, 0..) |_, idx| if (noteCount(idx) > 0) return noteSelection(idx, 0);
    return null;
}

fn lastChangelogSelection() ?Selection {
    var idx: usize = CHANGELOG.len;
    while (idx > 0) {
        idx -= 1;
        const count = noteCount(idx);
        if (count > 0) return noteSelection(idx, count - 1);
    }
    return null;
}

fn nextSelection(sel: Selection, forward: bool) Selection {
    if (forward) {
        const item = sel.item orelse 0;
        if (item + 1 < noteCount(sel.entry)) return noteSelection(sel.entry, item + 1);
        var idx = sel.entry + 1;
        while (idx < CHANGELOG.len) : (idx += 1) if (noteCount(idx) > 0) return noteSelection(idx, 0);
        return firstChangelogSelection() orelse sel;
    }
    const item = sel.item orelse 0;
    if (item > 0) return noteSelection(sel.entry, item - 1);
    var idx = sel.entry;
    while (idx > 0) {
        idx -= 1;
        const count = noteCount(idx);
        if (count > 0) return noteSelection(idx, count - 1);
    }
    return lastChangelogSelection() orelse sel;
}

pub fn selectedChangelogTicket() []const u8 {
    const sel = app_state.g_changelog_sel orelse return "";
    if (sel.entry >= CHANGELOG.len) return "";
    const entry = CHANGELOG[sel.entry];
    if (sel.item) |i| return if (i < entry.items.len) entry.items[i].ticket else "";
    return if (entry.items.len == 0 and entry.summary.len > 0) entry.ticket else "";
}

fn rect(left: i32, top: i32, right: i32, bottom: i32) RECT {
    return .{ .left = left, .top = top, .right = @max(left, right), .bottom = @max(top, bottom) };
}

pub fn calcChangelogLayout() ChangelogLayout {
    var client: RECT = std.mem.zeroes(RECT);
    _ = GetClientRect(app_state.g_main_hwnd, &client);
    const win_w = @max(0, client.right - client.left);
    const win_h = @max(0, client.bottom - client.top);
    const pane = if (app_state.g_chat_active) @import("chat_composer.zig").chatViewLayout().pane else @import("window_layout.zig").activePaneRects(client).primary;
    const pane_left = std.math.clamp(pane.left, 0, win_w);
    const pane_right = std.math.clamp(pane.right, pane_left, win_w);
    const pane_width = pane_right - pane_left;
    const margin = @min(uiScaled(8), @divTrunc(pane_width, 2));
    const width = @min(uiScaled(640), @max(0, pane_width - 2 * margin));
    const x = pane_left + @divTrunc(pane_width - width, 2);
    const inset = @min(uiScaled(16), @divTrunc(width, 2));
    const left = x + inset;
    const right = x + width - inset;
    const gutter = @min(@max(0, right - left), uiScaled(8));
    const rows_right = right - gutter;
    const compact = rows_right - left < uiScaled(24 + 96 + 8 + 112 + 8);
    const foot_width = right - left;
    const padding = @min(uiScaled(8), @divTrunc(foot_width, 2));
    const usable = @max(0, foot_width - 2 * padding);
    const budgets = [_]i32{ uiScaled(76), uiScaled(122), uiScaled(76) };
    const key_widths = [_]i32{ uiScaled(32), uiScaled(42), uiScaled(32) };
    var key_rel: [3]RECT = undefined;
    var label_rel: [3]RECT = undefined;
    var fx: i32 = 0;
    var line_idx: i32 = 0;
    for (budgets, 0..) |budget, i| {
        if (fx > 0 and fx + budget > usable) {
            line_idx += 1;
            fx = 0;
        }
        const group_end = @min(usable, fx + budget);
        const key_end = @min(group_end, fx + key_widths[i]);
        const top = uiScaled(12) + line_idx * uiScaled(24);
        key_rel[i] = rect(fx, top, key_end, top + uiScaled(20));
        label_rel[i] = rect(@min(group_end, key_end + uiScaled(6)), top, group_end, top + uiScaled(20));
        fx = @min(usable, group_end + uiScaled(4));
    }
    const footer_desired = uiScaled(48) + line_idx * uiScaled(24);
    prepareChangelogLayout(rows_right - left, compact);
    const total = changelog_row_tops[CHANGELOG.len];
    const action_desired = if (compact and firstChangelogSelection() != null) rowHeight() else 0;
    const cap: i32 = @intCast(@divTrunc(@as(i64, win_h) * 4, 5));
    const header_desired = if (@as(i64, cap) < @as(i64, uiScaled(96)) + footer_desired + action_desired + @min(total, rowHeight())) uiScaled(64) else uiScaled(96);
    const desired: i64 = @as(i64, header_desired) + total + action_desired + footer_desired;
    const height: i32 = @intCast(@min(@as(i64, cap), desired));
    const y = @divTrunc(win_h - height, 2);
    const card = rect(x, y, x + width, y + height);
    const header_h = @min(height, header_desired);
    const footer_h = @min(height - header_h, footer_desired);
    const action_h = @min(height - header_h - footer_h, action_desired);
    const header = rect(x, y, x + width, y + header_h);
    const footer = rect(left, card.bottom - footer_h, right, card.bottom);
    const action = rect(@max(left, rows_right - uiScaled(112)), footer.top - action_h, rows_right, footer.top);
    const viewport = rect(left, header.bottom, right, action.top);
    const rows = rect(left, viewport.top, rows_right, viewport.bottom);
    const scrollbar = rect(rows_right, viewport.top, right, viewport.bottom);
    const close_size = @min(uiScaled(32), @min(width, header_h));
    const close_inset = @min(uiScaled(16), @max(0, width - close_size));
    const close_right = card.right - close_inset;
    const close_top = header.top + @min(uiScaled(16), @max(0, header_h - close_size));
    const close = rect(close_right - close_size, close_top, close_right, close_top + close_size);
    var keys: [3]RECT = undefined;
    var labels: [3]RECT = undefined;
    for (0..3) |i| {
        keys[i] = rect(left + padding + key_rel[i].left, @min(footer.bottom, footer.top + key_rel[i].top), left + padding + key_rel[i].right, @min(footer.bottom, footer.top + key_rel[i].bottom));
        labels[i] = rect(left + padding + label_rel[i].left, @min(footer.bottom, footer.top + label_rel[i].top), left + padding + label_rel[i].right, @min(footer.bottom, footer.top + label_rel[i].bottom));
    }
    const view_h = viewport.bottom - viewport.top;
    const max_scroll = @max(0, total - view_h);
    app_state.g_changelog_scroll = std.math.clamp(app_state.g_changelog_scroll, 0, max_scroll);
    return .{ .card = card, .header = header, .close = close, .viewport = viewport, .scrollbar = scrollbar, .rows = rows, .action = action, .footer = footer, .footer_keys = keys, .footer_labels = labels, .compact = compact, .view_h = view_h, .max_scroll = max_scroll };
}

fn contains(rc: RECT, x: i32, y: i32) bool {
    return x >= rc.left and x < rc.right and y >= rc.top and y < rc.bottom;
}

fn compactAction(layout: ChangelogLayout) ?Selection {
    if (!layout.compact or selectedChangelogTicket().len == 0 or layout.view_h <= 0) return null;
    const sel = app_state.g_changelog_sel orelse return null;
    const range = selectionRange(sel);
    if (range.top + range.h <= app_state.g_changelog_scroll or range.top >= app_state.g_changelog_scroll + layout.view_h) return null;
    if (layout.action.right <= layout.action.left or layout.action.bottom <= layout.action.top) return null;
    return sel;
}

pub fn changelogHitTest(mx: i32, my: i32) ChangelogHit {
    const layout = calcChangelogLayout();
    if (!contains(layout.card, mx, my)) return .outside;
    if (contains(layout.close, mx, my)) return .close;
    if (contains(layout.action, mx, my)) {
        if (compactAction(layout)) |sel| return .{ .row = sel };
        return .inside;
    }
    if (!contains(layout.rows, mx, my)) return .inside;
    const y = my - layout.viewport.top + app_state.g_changelog_scroll;
    const idx = changelogIndexAtContentY(y) orelse return .inside;
    for (0..noteCount(idx)) |item| {
        const range = changelog_ranges[idx][item];
        if (y >= range.top and y < range.top + range.h) return .{ .row = noteSelection(idx, item) };
    }
    return .inside;
}

fn selectionAtOrAfter(y: i32) ?Selection {
    const first = changelogIndexAtContentY(y) orelse return lastChangelogSelection();
    for (first..CHANGELOG.len) |idx| {
        const count = noteCount(idx);
        if (count == 0) continue;
        for (0..count) |item| {
            const range = changelog_ranges[idx][item];
            if (y < range.top + range.h) return noteSelection(idx, item);
        }
    }
    return lastChangelogSelection();
}

pub fn moveChangelogSelection(action: WPARAM) void {
    const layout = calcChangelogLayout();
    var sel = app_state.g_changelog_sel orelse firstChangelogSelection() orelse return;
    switch (action) {
        0 => sel = nextSelection(sel, false),
        1 => sel = nextSelection(sel, true),
        2, 3 => {
            if (layout.view_h <= 0) return;
            app_state.g_changelog_scroll = std.math.clamp(app_state.g_changelog_scroll + (if (action == 2) -layout.view_h else layout.view_h), 0, layout.max_scroll);
            app_state.g_changelog_sel = selectionAtOrAfter(app_state.g_changelog_scroll);
            return;
        },
        4 => {
            app_state.g_changelog_sel = firstChangelogSelection();
            app_state.g_changelog_scroll = 0;
            return;
        },
        5 => sel = lastChangelogSelection() orelse return,
        else => return,
    }
    app_state.g_changelog_sel = sel;
    if (layout.view_h <= 0) return;
    const range = selectionRange(sel);
    if (layout.view_h < range.h or range.top < app_state.g_changelog_scroll) {
        app_state.g_changelog_scroll = range.top;
    } else if (range.top + range.h > app_state.g_changelog_scroll + layout.view_h) {
        app_state.g_changelog_scroll = range.top + range.h - layout.view_h;
    }
    app_state.g_changelog_scroll = std.math.clamp(app_state.g_changelog_scroll, 0, layout.max_scroll);
}

fn changelogTicketUrl(ticket: []const u8, buf: []u8) []const u8 {
    const board = if (std.mem.startsWith(u8, ticket, "IGSH-")) "2060" else if (std.mem.startsWith(u8, ticket, "HYCI-")) "11514" else return ticket;
    if (ticket.len == 5) return ticket;
    for (ticket[5..]) |c| if (c < '0' or c > '9') return ticket;
    return std.fmt.bufPrint(buf, "https://app.hypertask.ai/detail/project-{s}/{s}", .{ board, ticket[5..] }) catch "";
}

test "changelog ticket IDs resolve without changing existing links" {
    var buf: [512]u8 = undefined;
    try std.testing.expectEqualStrings("https://app.hypertask.ai/detail/project-2060/1243", changelogTicketUrl("IGSH-1243", &buf));
    try std.testing.expectEqualStrings("https://example.com/ticket", changelogTicketUrl("https://example.com/ticket", &buf));
    try std.testing.expectEqualStrings("IGSH-x", changelogTicketUrl("IGSH-x", &buf));
}

pub fn openAsciiUrlInDefaultBrowser(ticket: []const u8) void {
    var buf: [512]u8 = undefined;
    const url = changelogTicketUrl(ticket, &buf);
    if (url.len == 0) return;
    var wbuf: [512]u16 = undefined;
    const n = @min(url.len, wbuf.len - 1);
    for (0..n) |i| wbuf[i] = @intCast(url[i]);
    wbuf[n] = 0;
    _ = ShellExecuteW(null, L("open"), @ptrCast(&wbuf), null, null, SW_SHOW);
}

const ChangeFont = struct {
    handle: HANDLE,
    owned: bool,

    fn init(size: i32, weight: i32) ChangeFont {
        const font = changeFont(size, weight);
        return .{ .handle = if (font != null) font else @import("win32.zig").GetStockObject(@import("win32.zig").DEFAULT_GUI_FONT), .owned = font != null };
    }

    fn release(self: ChangeFont) void {
        if (self.owned) _ = DeleteObject(self.handle);
    }
};

fn selectChangeFont(hdc: HANDLE, preferred: HANDLE) bool {
    if (preferred != null and SelectObject(hdc, preferred) != null) return true;
    const fallback = @import("win32.zig").GetStockObject(@import("win32.zig").DEFAULT_GUI_FONT);
    return fallback != null and SelectObject(hdc, fallback) != null;
}

fn clipChangeRegion(hdc: HANDLE, bounds: RECT) i32 {
    if (bounds.right <= bounds.left or bounds.bottom <= bounds.top) return 0;
    const saved = SaveDC(hdc);
    if (saved == 0) return 0;
    if (IntersectClipRect(hdc, bounds.left, bounds.top, bounds.right, bounds.bottom) == 0) {
        _ = RestoreDC(hdc, saved);
        return 0;
    }
    return saved;
}

fn drawChangeRow(hdc: HANDLE, layout: ChangelogLayout, sel: Selection, text: []const u8, ticket: []const u8, text_col: u32, dim_col: u32, selected_col: u32, body_font: HANDLE, action_font: HANDLE) void {
    const range = selectionRange(sel);
    const top = layout.viewport.top + range.top - app_state.g_changelog_scroll;
    const row = rect(layout.rows.left, top, layout.rows.right, top + range.h);
    const selected = if (app_state.g_changelog_sel) |current| current.entry == sel.entry and current.item == sel.item else false;
    if (selected) smooth.fillRoundRect(hdc, row, uiScaled(10), selected_col);
    const dot_size = @min(uiScaled(4), @min(row.right - row.left, row.bottom - row.top));
    const dot_left = @min(row.right - dot_size, row.left + uiScaled(8));
    const dot_top = top + @divTrunc(range.h - dot_size, 2);
    smooth.fillEllipse(hdc, rect(dot_left, dot_top, dot_left + dot_size, dot_top + dot_size), dim_col);
    const body_left = @min(row.right, row.left + uiScaled(24));
    const body_right = if (layout.compact) @max(body_left, row.right - uiScaled(8)) else @max(body_left, row.right - uiScaled(128));
    var body = rect(body_left, top + uiScaled(6), body_right, row.bottom - uiScaled(6));
    if (body.right > body.left and selectChangeFont(hdc, body_font)) {
        _ = SetTextColor(hdc, text_col);
        changeText(hdc, text, &body, @import("win32.zig").DT_WORDBREAK | DT_NOPREFIX);
    }
    if (!layout.compact and selected and ticket.len > 0 and selectChangeFont(hdc, action_font)) {
        _ = SetTextColor(hdc, dim_col);
        var action = rect(@min(row.right, body_right + uiScaled(8)), top, @max(body_right, row.right - uiScaled(8)), row.bottom);
        if (action.right > action.left) _ = DrawTextW(hdc, L(words.changelog_open_ticket), -1, &action, DT_SINGLELINE | DT_VCENTER | DT_RIGHT | @import("win32.zig").DT_END_ELLIPSIS | DT_NOPREFIX);
    }
}

pub fn paintChangelogOverlay(hdc: HANDLE) void {
    if (!app_state.g_changelog_active) return;
    const layout = calcChangelogLayout();
    const card = layout.card;
    const light = app_state.g_light_theme;
    const bg = customColorOr("overlay_bg", if (light) RGB(250, 250, 250) else RGB(24, 24, 24));
    const border = customColorOr("overlay_border", if (light) RGB(222, 222, 222) else RGB(46, 46, 46));
    const text = customColorOr("text", if (light) RGB(32, 32, 32) else RGB(242, 242, 242));
    const dim = customColorOr("tab_text_dim", if (light) RGB(96, 96, 96) else RGB(138, 138, 138));
    const selected = if (light) RGB(224, 224, 224) else RGB(53, 53, 53);
    const key_bg = if (light) RGB(245, 245, 245) else RGB(31, 31, 31);
    var client: RECT = std.mem.zeroes(RECT);
    _ = GetClientRect(app_state.g_main_hwnd, &client);
    @import("dialog.zig").dim(hdc, client.right, client.bottom);
    drawModalShadow(hdc, card.left, card.top, card.right - card.left, card.bottom - card.top, uiScaled(40));
    smooth.fillRoundRect(hdc, card, uiScaled(20), border);
    const line = @max(1, uiScaled(1));
    const inner = rect(@min(card.right, card.left + line), @min(card.bottom, card.top + line), card.right - line, card.bottom - line);
    smooth.fillRoundRect(hdc, inner, uiScaled(20), bg);
    const body_font = bodyFont();
    const saved = SaveDC(hdc);
    if (saved == 0) return;
    const title_font = ChangeFont.init(18, 600);
    const version_font = ChangeFont.init(13, 600);
    const subtitle_font = ChangeFont.init(13, 400);
    const action_font = ChangeFont.init(12, 400);
    const cap_font = ChangeFont.init(11, 400);
    defer {
        _ = RestoreDC(hdc, saved);
        title_font.release();
        version_font.release();
        subtitle_font.release();
        action_font.release();
        cap_font.release();
    }
    _ = SetBkMode(hdc, TRANSPARENT);
    const single = DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX | @import("win32.zig").DT_END_ELLIPSIS;
    const header_save = clipChangeRegion(hdc, layout.header);
    if (header_save != 0) {
        const title_left = @min(layout.close.left, card.left + uiScaled(24));
        const title_right = @max(title_left, layout.close.left - uiScaled(8));
        var title = rect(title_left, @min(layout.header.bottom, card.top + uiScaled(20)), title_right, @min(layout.header.bottom, card.top + uiScaled(44)));
        _ = SetTextColor(hdc, text);
        if (title.right > title.left and title.bottom > title.top and selectChangeFont(hdc, title_font.handle)) _ = DrawTextW(hdc, L(words.changelog_title), -1, &title, single);
        var subtitle_buf: [128]u8 = undefined;
        const subtitle = std.fmt.bufPrint(&subtitle_buf, "{s} v{s}", .{ words.changelog_current_version, APP_VERSION }) catch words.changelog_current_version;
        var subtitle_rc = rect(title_left, @min(layout.header.bottom, card.top + uiScaled(52)), @max(title_left, card.right - uiScaled(24)), @min(layout.header.bottom, card.top + uiScaled(72)));
        _ = SetTextColor(hdc, dim);
        if (subtitle_rc.right > subtitle_rc.left and subtitle_rc.bottom > subtitle_rc.top and selectChangeFont(hdc, subtitle_font.handle)) drawAscii(hdc, subtitle, &subtitle_rc, single);
        smooth.fillEllipse(hdc, layout.close, border);
        const close_inner = rect(@min(layout.close.right, layout.close.left + line), @min(layout.close.bottom, layout.close.top + line), layout.close.right - line, layout.close.bottom - line);
        if (close_inner.right > close_inner.left and close_inner.bottom > close_inner.top) smooth.fillEllipse(hdc, close_inner, key_bg);
        var close_text = layout.close;
        if (selectChangeFont(hdc, subtitle_font.handle)) _ = DrawTextW(hdc, L("×"), -1, &close_text, single | @import("win32.zig").DT_CENTER);
        _ = RestoreDC(hdc, header_save);
    }
    const rows_save = clipChangeRegion(hdc, layout.rows);
    if (rows_save != 0) {
        const first = changelogIndexAtContentY(app_state.g_changelog_scroll) orelse 0;
        for (first..CHANGELOG.len) |idx| {
            const entry = CHANGELOG[idx];
            if (entry.items.len == 0) continue;
            const top = layout.viewport.top + changelog_row_tops[idx] - app_state.g_changelog_scroll;
            if (top >= layout.viewport.bottom) break;
            _ = SetTextColor(hdc, text);
            var version_buf: [32]u8 = undefined;
            const version = std.fmt.bufPrint(&version_buf, "v{s}", .{entry.ver}) catch entry.ver;
            const ver_left = @min(layout.rows.right, layout.rows.left + uiScaled(8));
            const installed = std.mem.eql(u8, entry.ver, APP_VERSION);
            const version_available = @max(0, layout.rows.right - ver_left - if (installed) uiScaled(68) else 0);
            const has_version_font = selectChangeFont(hdc, version_font.handle);
            var measure = rect(0, 0, 0, 0);
            if (has_version_font) drawAscii(hdc, version, &measure, DT_SINGLELINE | @import("win32.zig").DT_CALCRECT | DT_NOPREFIX);
            const ver_right = ver_left + @min(version_available, @max(0, measure.right));
            var version_rc = rect(ver_left, top, ver_right, top + rowHeight());
            if (version_rc.right > version_rc.left and has_version_font) drawAscii(hdc, version, &version_rc, single);
            if (installed) {
                const pill_left = @min(layout.rows.right, ver_right + uiScaled(8));
                const pill = rect(pill_left, top + uiScaled(8), @min(layout.rows.right, pill_left + uiScaled(60)), @min(top + rowHeight(), top + uiScaled(26)));
                if (pill.right > pill.left and pill.bottom > pill.top) {
                    smooth.fillRoundRect(hdc, pill, uiScaled(10), selected);
                    var pill_text = pill;
                    if (selectChangeFont(hdc, cap_font.handle)) _ = DrawTextW(hdc, L(words.changelog_installed), -1, &pill_text, single | @import("win32.zig").DT_CENTER);
                }
            }
            if (entry.items.len > 0) {
                for (entry.items, 0..) |item, i| {
                    const sel = noteSelection(idx, i);
                    const range = selectionRange(sel);
                    if (range.top + range.h <= app_state.g_changelog_scroll) continue;
                    if (range.top >= app_state.g_changelog_scroll + layout.view_h) break;
                    drawChangeRow(hdc, layout, sel, item.text, item.ticket, text, dim, selected, body_font, action_font.handle);
                }
            }
        }
        _ = RestoreDC(hdc, rows_save);
    }
    if (layout.max_scroll > 0 and layout.view_h > 0) {
        const total = layout.view_h + layout.max_scroll;
        const thumb_h = @min(layout.view_h, @max(uiScaled(24), @divTrunc(layout.view_h * layout.view_h, total)));
        const thumb_top = layout.viewport.top + @divTrunc((layout.view_h - thumb_h) * app_state.g_changelog_scroll, layout.max_scroll);
        smooth.fillRoundRect(hdc, rect(@max(layout.scrollbar.left, layout.scrollbar.right - uiScaled(4)), thumb_top, layout.scrollbar.right, thumb_top + thumb_h), uiScaled(2), dim);
    }
    const action_save = clipChangeRegion(hdc, layout.action);
    if (action_save != 0) {
        if (compactAction(layout) != null and selectChangeFont(hdc, action_font.handle)) {
            _ = SetTextColor(hdc, dim);
            var action_rc = layout.action;
            _ = DrawTextW(hdc, L(words.changelog_open_ticket), -1, &action_rc, single | DT_RIGHT);
        }
        _ = RestoreDC(hdc, action_save);
    }
    const footer_save = clipChangeRegion(hdc, layout.footer);
    if (footer_save != 0) {
        var divider = rect(layout.footer.left, layout.footer.top, layout.footer.right, @min(layout.footer.bottom, layout.footer.top + line));
        const divider_brush = CreateSolidBrush(if (light) RGB(222, 222, 222) else RGB(42, 42, 42));
        _ = FillRect(hdc, &divider, divider_brush);
        _ = DeleteObject(divider_brush);
        const keys = [_][*:0]const u16{ L("↑↓"), L("Enter"), L("Esc") };
        const labels = [_][*:0]const u16{ L(words.changelog_move), L(words.changelog_open_ticket_footer), L(words.changelog_close) };
        for (keys, labels, 0..) |key, label, i| {
            var cap = layout.footer_keys[i];
            smooth.fillRoundRect(hdc, cap, uiScaled(6), border);
            const cap_inner = rect(@min(cap.right, cap.left + line), @min(cap.bottom, cap.top + line), cap.right - line, cap.bottom - line);
            smooth.fillRoundRect(hdc, cap_inner, uiScaled(6), key_bg);
            _ = SetTextColor(hdc, dim);
            if (cap.right > cap.left and cap.bottom > cap.top and selectChangeFont(hdc, cap_font.handle)) _ = DrawTextW(hdc, key, -1, &cap, single | @import("win32.zig").DT_CENTER);
            var caption = layout.footer_labels[i];
            if (caption.right > caption.left and caption.bottom > caption.top and selectChangeFont(hdc, cap_font.handle)) _ = DrawTextW(hdc, label, -1, &caption, single);
        }
        _ = RestoreDC(hdc, footer_save);
    }
}

pub fn closeChangelogOverlay(hwnd: HANDLE, refocus_shell: bool) void {
    if (!app_state.g_changelog_active) return;
    app_state.g_changelog_active = false;
    app_state.g_shell_focused = true;
    clearSearchBackdrop();
    showActiveShellAfterOverlay();
    _ = InvalidateRect(hwnd, null, 0);
    if (refocus_shell and app_state.shell_count > 0) {
        _ = SetTimer(hwnd, TIMER_REFOCUS, 100, null);
    }
}
