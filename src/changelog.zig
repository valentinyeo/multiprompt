const app_state = @import("app_state.zig");
const std = @import("std");
const APP_VERSION = @import("main.zig").APP_VERSION;
const WPARAM = @import("win32.zig").WPARAM;
const HANDLE = @import("win32.zig").HANDLE;
const SW_SHOW = @import("win32.zig").SW_SHOW;
const DT_SINGLELINE = @import("win32.zig").DT_SINGLELINE;
const DT_VCENTER = @import("win32.zig").DT_VCENTER;
const DT_RIGHT = @import("win32.zig").DT_RIGHT;
const DT_WORDBREAK = @import("win32.zig").DT_WORDBREAK;
const DT_NOPREFIX = @import("win32.zig").DT_NOPREFIX;
const DT_CALCRECT = @import("win32.zig").DT_CALCRECT;
const TRANSPARENT = @import("win32.zig").TRANSPARENT;
const TIMER_REFOCUS = @import("win32.zig").TIMER_REFOCUS;
const RECT = @import("win32.zig").RECT;
const GetClientRect = @import("win32.zig").GetClientRect;
const InvalidateRect = @import("win32.zig").InvalidateRect;
const GetDC = @import("win32.zig").GetDC;
const ReleaseDC = @import("win32.zig").ReleaseDC;
const FillRect = @import("win32.zig").FillRect;
const DrawTextW = @import("win32.zig").DrawTextW;
const CreateSolidBrush = @import("win32.zig").CreateSolidBrush;
const DeleteObject = @import("win32.zig").DeleteObject;
const SetBkMode = @import("win32.zig").SetBkMode;
const SetTextColor = @import("win32.zig").SetTextColor;
const SelectObject = @import("win32.zig").SelectObject;
const CreatePen = @import("win32.zig").CreatePen;
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
const drawAsciiLong = @import("drawing.zig").drawAsciiLong;
const drawModalShadow = @import("drawing.zig").drawModalShadow;
const ChangelogLayout = @import("app_state.zig").ChangelogLayout;
const ChangelogEntryRange = @import("app_state.zig").ChangelogEntryRange;
const ChangelogHit = @import("app_state.zig").ChangelogHit;
const uiScaled = @import("drawing.zig").uiScaled;
const uiFontTitle = @import("drawing.zig").uiFontTitle;
const uiFontSubtitle = @import("drawing.zig").uiFontSubtitle;
const SetTimer = @import("win32.zig").SetTimer;

const ChangelogBullet = struct { text: []const u8, ticket: []const u8 };
const ChangelogEntry = struct {
    ver: []const u8,
    summary: []const u8 = "",
    ticket: []const u8 = "",
    items: []const ChangelogBullet = &.{},
};
pub const CHANGELOG = [_]ChangelogEntry{
    .{ .ver = "0.28.776", .items = &.{
        .{ .text = "Shell borders and symbols now display correctly even when Nordwand Mono is already installed.", .ticket = "IGSH-443" },
    } },
    .{ .ver = "0.28.775", .items = &.{
        .{ .text = "Messages with unconfirmed delivery now have Send again and Remove buttons, also available by right-clicking the message.", .ticket = "IGSH-442" },
        .{ .text = "Send again checks whether the message already arrived or is waiting in the terminal before resending it.", .ticket = "IGSH-442" },
        .{ .text = "Busy sessions wait for delivery confirmation instead of showing an early failure.", .ticket = "IGSH-442" },
    } },
    .{ .ver = "0.28.774", .items = &.{
        .{ .text = "Shell box frames, charts, and arrow prompts now line up without gaps or solid rectangles.", .ticket = "IGSH-443" },
        .{ .text = "Chat text is a little bolder and uses smoother edges for easier reading on dark backgrounds.", .ticket = "IGSH-445" },
        .{ .text = "Line spacing stays the same.", .ticket = "IGSH-445" },
    } },
    .{ .ver = "0.28.773", .items = &.{
        .{ .text = "Drop or paste files into Chat View to send them to your server and insert their paths.", .ticket = "IGSH-393" },
    } },
    .{ .ver = "0.28.772", .items = &.{
        .{ .text = "IBM Plex Sans now appears throughout the desktop, with real bold and italic text.", .ticket = "IGSH-443" },
        .{ .text = "Shells and Chat View code use Nordwand Mono SemiBold at the same size as before.", .ticket = "IGSH-443" },
    } },
    .{ .ver = "0.28.771", .items = &.{
        .{ .text = "Hide the Frequent, Favorites or All split from Ctrl+K, or place Frequent after Favorites; your choices follow your account to your phone.", .ticket = "IGSH-423" },
    } },
    .{ .ver = "0.28.770", .items = &.{
        .{ .text = "Selecting chat text now follows the mouse smoothly across messages, tables, lists, and code.", .ticket = "IGSH-438" },
        .{ .text = "Double-click selects a word and triple-click selects the paragraph under the mouse.", .ticket = "IGSH-438" },
        .{ .text = "Copy keeps the selected text highlighted, and right-click Copy copies the message when no text is selected.", .ticket = "IGSH-438" },
    } },
    .{ .ver = "0.28.769", .items = &.{
        .{ .text = "Your servers follow your account to a new computer without replacing servers you already set up there.", .ticket = "IGSH-422" },
    } },
    .{ .ver = "0.28.768", .items = &.{
        .{ .text = "Android crash reports are stored per device so failures can be diagnosed without collecting device credentials.", .ticket = "IGSH-429" },
    } },
    .{ .ver = "0.28.767", .items = &.{
        .{ .text = "Switching back to a workspace opens the session you were last on.", .ticket = "IGSH-439" },
    } },
    .{ .ver = "0.28.766", .items = &.{
        .{ .text = "Full width keeps Chat View open and respects your choice to show a session’s terminal.", .ticket = "IGSH-440" },
        .{ .text = "The desktop shell now uses the bundled Nordwand Mono font at the same size as before.", .ticket = "IGSH-441" },
    } },
    .{ .ver = "0.28.765", .items = &.{
        .{ .text = "If an Allow or Deny answer fails to reach the agent, the buttons stay so you can click again.", .ticket = "" },
    } },
    .{ .ver = "0.28.764", .items = &.{
        .{ .text = "Chat View displays tables with clear rows, bold headers, and sideways scrolling for wide content.", .ticket = "" },
        .{ .text = "Nested lists keep their indentation in Chat View.", .ticket = "" },
    } },
    .{ .ver = "0.28.763", .items = &.{
        .{ .text = "Right-click a message in Chat View and pick Reply to answer that exact message; the agent gets it as a quote above your reply.", .ticket = "" },
    } },
    .{ .ver = "0.28.762", .items = &.{
        .{ .text = "When you Alt+Tab back into Multiprompt in Chat View, the cursor is back in the message box so you can keep typing.", .ticket = "" },
    } },
    .{ .ver = "0.28.761", .items = &.{
        .{ .text = "Frequent now comes first and shows the sessions you typed or spoke into in the last day, plus sessions you watched three times for ten seconds, with the newest at the bottom.", .ticket = "" },
    } },
    .{ .ver = "0.28.760", .items = &.{
        .{ .text = "Tabs to a server that was offline now reconnect on their own when it comes back.", .ticket = "" },
    } },
    .{ .ver = "0.28.759", .items = &.{
        .{ .text = "With Chat View set to everywhere, a session you switch to the shell view now stays in the shell view, also after a restart.", .ticket = "" },
        .{ .text = "Switching that session back to Chat View makes it follow everywhere again.", .ticket = "" },
    } },
    .{ .ver = "0.28.758", .items = &.{
        .{ .text = "The browser helper can now make a clean copy of a browser profile, the first step toward a separate browser per workspace.", .ticket = "" },
    } },
    .{ .ver = "0.28.757", .items = &.{
        .{ .text = "When a server goes offline, Multiprompt no longer keeps reopening its tabs and pulling the typing focus away.", .ticket = "" },
    } },
    .{ .ver = "0.28.756", .items = &.{
        .{ .text = "Double click on empty space to switch between Chat View and the shell view.", .ticket = "" },
    } },
    .{ .ver = "0.28.755", .items = &.{
        .{ .text = "Messages and drafts typed in Chat View now stay with their own tab when two tabs have the same name.", .ticket = "" },
    } },
    .{ .ver = "0.28.754", .items = &.{
        .{ .text = "A skill you pick in one tab now stays with that tab and is no longer sent with a message in another tab.", .ticket = "" },
    } },
    .{ .ver = "0.28.753", .items = &.{
        .{ .text = "Chat View shows file edits as a small red and green card with the lines that changed.", .ticket = "" },
    } },
    .{ .ver = "0.28.752", .items = &.{
        .{ .text = "Chat View shows the agent's model, context left and completed task count.", .ticket = "" },
        .{ .text = "Click the header or choose Toggle todo list from Ctrl+K to see the agent's tasks.", .ticket = "" },
    } },
    .{ .ver = "0.28.751", .items = &.{
        .{ .text = "The Frequent list now matches on your phone and your other laptop.", .ticket = "" },
    } },
    .{ .ver = "0.28.750", .items = &.{
        .{ .text = "- Answer agent permission prompts with Allow, Always allow, or Deny buttons above the Chat View composer.", .ticket = "" },
        .{ .text = "- Use Alt+Y to allow, Alt+O to always allow, or Alt+D to deny the current permission request.", .ticket = "" },
    } },
    .{ .ver = "0.28.749", .items = &.{
        .{ .text = "Press Ctrl+F in Chat View to search the whole conversation, including older messages.", .ticket = "" },
        .{ .text = "Use Enter or F3 to move between matches, and Esc to return to your message.", .ticket = "" },
    } },
    .{ .ver = "0.28.748", .items = &.{
        .{ .text = "Drop images into Chat View, or copy image files in Explorer and paste them with Ctrl+V, to attach up to 10 at once in order.", .ticket = "" },
    } },
    .{ .ver = "0.28.747", .items = &.{
        .{ .text = "The inbox has a new Frequent tab with the sessions you used in the last 48 hours, from every window.", .ticket = "" },
        .{ .text = "Only sessions you switched to, typed in or sent a message to count; agents working on their own do not.", .ticket = "" },
    } },
    .{ .ver = "0.28.746", .items = &.{
        .{ .text = "Chat View no longer stays empty after you pick a session in Ctrl+K; the chat and its browser show right away.", .ticket = "" },
    } },
    .{ .ver = "0.28.745", .items = &.{
        .{ .text = "Agents keep using the browser right after an update is installed, without waiting for the extension to be reloaded.", .ticket = "" },
    } },
    .{ .ver = "0.28.744", .items = &.{
        .{ .text = "Stars you set with Alt+S now sync through your Multiprompt account, so your other laptop sees them.", .ticket = "" },
    } },
    .{ .ver = "0.28.743", .items = &.{
        .{ .text = "Starred sessions now show a small yellow dot instead of a star, so titles get more room.", .ticket = "" },
    } },
    .{ .ver = "0.28.742", .items = &.{
        .{ .text = "Chat View shows each tool step on one line with a green, red or running status; click it to see what it did.", .ticket = "" },
        .{ .text = "Open or fold all tool steps from Ctrl+K.", .ticket = "" },
    } },
    .{ .ver = "0.28.741", .items = &.{
        .{ .text = "Chat View shows how long the agent has been working.", .ticket = "" },
        .{ .text = "A Stop button, Esc or Ctrl+K \"Chat View: Stop the agent\" stops the agent's current run.", .ticket = "" },
    } },
    .{ .ver = "0.28.740", .items = &.{
        .{ .text = "Browser commands now reach only the browser profile they were sent to.", .ticket = "" },
    } },
    .{ .ver = "0.28.739", .items = &.{
        .{ .text = "The browser helper now answers wrong arguments with a short, clear error instead of a page of help text.", .ticket = "" },
    } },
    .{ .ver = "0.28.738", .items = &.{
        .{ .text = "Chat View now opens with your latest question on screen, even when the agent read a very long file or skill after it.", .ticket = "" },
    } },
    .{ .ver = "0.28.737", .items = &.{
        .{ .text = "Every line in the debug log now starts with the date and time, so problems are easier to match to the moment they happened.", .ticket = "" },
        .{ .text = "The debug log no longer grows forever: above 20 MB it moves to debug.log.old and starts fresh.", .ticket = "" },
    } },
    .{ .ver = "0.28.736", .items = &.{
        .{ .text = "Version numbers are now given out once a change is merged, so fixes reach you sooner when several land at the same time.", .ticket = "" },
    } },
    .{ .ver = "0.28.735", .items = &.{
        .{ .text = "After you leave the chat view, the app stops pulling the keyboard back to the shell once the shell already has it.", .ticket = "" },
    } },
    .{ .ver = "0.28.734", .items = &.{
        .{ .text = "Chat View shows the full terminal screen, like btop, when a session's conversation can't be loaded.", .ticket = "" },
    } },
    .{ .ver = "0.28.733", .items = &.{
        .{ .text = "Switching a session from the chat view to the shell lets you type in the shell right away again.", .ticket = "" },
    } },
    .{ .ver = "0.28.732", .items = &.{
        .{ .text = "Two chat messages sent together into one turn both show as delivered.", .ticket = "" },
    } },
    .{ .ver = "0.28.731", .items = &.{
        .{ .text = "Starting multiprompt while it is already running brings the open copy back; a frozen or invisible copy is closed and a fresh one starts with your tabs.", .ticket = "" },
    } },
    .{ .ver = "0.28.730", .items = &.{
        .{ .text = "Chat View shows the terminal text instead of an empty pane when a session's conversation cannot be loaded.", .ticket = "" },
    } },
    .{ .ver = "0.28.729", .items = &.{
        .{ .text = "A chat message is never typed into the shell twice; if it was left unsent, it is sent once.", .ticket = "" },
    } },
    .{ .ver = "0.28.728", .items = &.{
        .{ .text = "After a session compacts, the chat view ends with the same last answer as the shell instead of the long summary.", .ticket = "" },
    } },
    .{ .ver = "0.28.727", .items = &.{
        .{ .text = "Messages that started with two commands, or were delivered before a session restarted, no longer show Delivery unconfirmed.", .ticket = "" },
    } },
    .{ .ver = "0.28.726", .items = &.{
        .{ .text = "Agents can type and click in their browser tab again while it stays in the background.", .ticket = "" },
    } },
    .{ .ver = "0.28.725", .items = &.{
        .{ .text = "Old messages that were delivered long ago no longer show Delivery unconfirmed.", .ticket = "" },
    } },
    .{ .ver = "0.28.724", .items = &.{
        .{ .text = "The tab you have open now gets a blue dot when its agent finishes while you are in another app or in the browser pane; it clears when you come back.", .ticket = "" },
    } },
    .{ .ver = "0.28.723", .items = &.{
        .{ .text = "The app no longer stalls for a moment when an agent opens a new browser window.", .ticket = "" },
    } },
    .{ .ver = "0.28.722", .items = &.{
        .{ .text = "Only the open session's browser shows; switching sessions or workspaces never leaves another browser on top.", .ticket = "" },
    } },
    .{ .ver = "0.28.721", .items = &.{
        .{ .text = "After pasting text, a link or a screenshot, you can keep typing in the same input without clicking back.", .ticket = "" },
    } },
    .{ .ver = "0.28.720", .items = &.{
        .{ .text = "Messages to a session in the background are now delivered even when its window is hidden.", .ticket = "" },
        .{ .text = "A message waiting for a busy session now says Queued, session is busy.", .ticket = "" },
        .{ .text = "Pasted text no longer shows raw tags in Chat View.", .ticket = "" },
        .{ .text = "A message can no longer stay on Sending… forever.", .ticket = "" },
    } },
    .{ .ver = "0.28.719", .items = &.{
        .{ .text = "A new session's chat no longer shows another session's old messages; it stays empty until its first message.", .ticket = "" },
    } },
    .{ .ver = "0.28.717", .items = &.{
        .{ .text = "Terminal tabs stay in the sidebar when their connection ends; reconnect them with Ctrl+Shift+R.", .ticket = "" },
        .{ .text = "The session history file no longer grows without limit.", .ticket = "" },
    } },
    .{ .ver = "0.28.716", .items = &.{
        .{ .text = "A session you made full width (Ctrl+Shift+F) now stays full width after switching workspaces or restarting the app.", .ticket = "" },
    } },
    .{ .ver = "0.28.715", .items = &.{
        .{ .text = "Agent browser links open even when the new-tab option comes before the link, and a mistyped browser command no longer asks you to restart.", .ticket = "" },
    } },
    .{ .ver = "0.28.714", .items = &.{
        .{ .text = "Long chats you have not opened for a while now show their newest messages right away; scroll up to load older ones.", .ticket = "" },
    } },
    .{ .ver = "0.28.713", .items = &.{
        .{ .text = "A chat message Claude refuses or drops now shows Not sent with a retry, instead of staying Queued forever.", .ticket = "" },
    } },
    .{ .ver = "0.28.712", .items = &.{
        .{ .text = "Behind the scenes: the app's code is split into smaller parts so future fixes are safer.", .ticket = "" },
    } },
    .{ .ver = "0.28.711", .items = &.{
        .{ .text = "The app uses about half as much CPU when idle.", .ticket = "" },
        .{ .text = "Tab names, the update card and other background checks react to changes instead of checking on a timer.", .ticket = "" },
        .{ .text = "Chats without a saved copy load in a fraction of a second instead of about one second.", .ticket = "" },
        .{ .text = "Tabs no longer lose their session when a name or folder contains unusual characters.", .ticket = "" },
    } },
    .{ .ver = "0.28.710", .items = &.{
        .{ .text = "After a screenshot from the browser extension, the cursor sits right after it with a space, in shell and chat mode.", .ticket = "" },
        .{ .text = "Ctrl+Shift+S takes a screenshot from the browser again.", .ticket = "" },
        .{ .text = "Agents reuse their own browser tab instead of opening a new one on every page.", .ticket = "" },
    } },
    .{ .ver = "0.28.709", .items = &.{
        .{ .text = "Press Alt+S to star a session; starred tabs show a gold star.", .ticket = "" },
        .{ .text = "The inbox has a Favorites tab with your starred sessions from every window.", .ticket = "" },
        .{ .text = "Chats from the secondary account load their history, including tabs that never saved a session id.", .ticket = "" },
        .{ .text = "Tabs with a browser show the chat title and message box inside the chat again.", .ticket = "" },
        .{ .text = "Saved chats appear right away when you switch tabs; an empty chat shows Loading conversation.", .ticket = "" },
    } },
    .{ .ver = "0.28.708", .items = &.{
        .{ .text = "Chats from the secondary account on Host 1 load again instead of retrying forever.", .ticket = "" },
        .{ .text = "When a chat can't be reached, it says why and retries once a minute.", .ticket = "" },
        .{ .text = "Without a browser, the chat sits in a centered reading column instead of stretching across the whole window.", .ticket = "" },
    } },
    .{ .ver = "0.28.707", .summary = "Chat View is responsive again", .items = &.{
        .{ .text = "Fixed the high CPU use that made 0.28.706 unusable.", .ticket = "" },
        .{ .text = "Conversations open at the latest messages. Scroll up to load older history.", .ticket = "" },
        .{ .text = "Chat updates, tables and saved history no longer repeat expensive work.", .ticket = "" },
        .{ .text = "Large chats no longer repeat link scans and text measurements while opening.", .ticket = "" },
        .{ .text = "Repeated prompts stay queued until actually sent, including after an update.", .ticket = "" },
        .{ .text = "The first tab now loads chat history, browser panes and screenshots correctly.", .ticket = "" },
        .{ .text = "Prompts starting with a blank line no longer block messages in other tabs.", .ticket = "" },
        .{ .text = "If delivery cannot be checked, your message stays visible as unconfirmed instead of disappearing.", .ticket = "" },
    } },
    .{ .ver = "0.28.706", .summary = "Chat View shows the whole conversation again", .items = &.{
        .{ .text = "Every chat shows its full history right away, even when the server is slow, and scrolling up works again.", .ticket = "" },
        .{ .text = "The chat fills the space instead of sitting in the middle with empty room around it.", .ticket = "" },
        .{ .text = "The terminal no longer shows on top of the chat.", .ticket = "" },
        .{ .text = "Messages from other agents show in a dark blue bubble with the sender's name, without the code tags.", .ticket = "" },
        .{ .text = "Each message you send shows once and is sent once; stuck Queued and Sent copies clear themselves.", .ticket = "" },
        .{ .text = "Ctrl+K \"Chat View: Reset this chat\" clears leftovers and reloads the conversation.", .ticket = "" },
        .{ .text = "Tables in Claude's replies now show in the chat.", .ticket = "" },
        .{ .text = "Ctrl+Shift+S screenshots work again, and the cursor waits right after the screenshot so you can type.", .ticket = "" },
        .{ .text = "Usage tracking now runs from the main app file, so updates copy one file less.", .ticket = "" },
    }, .ticket = "" },
    .{ .ver = "0.28.705", .summary = "Chat tabs switch before the browser", .items = &.{
        .{ .text = "Switching tabs in Chat View is instant again; the browser pane follows without slowing the chat down.", .ticket = "" },
        .{ .text = "Returning to a session shows its cached conversation immediately; only new transcript bytes are read.", .ticket = "" },
        .{ .text = "Rapid switches skip intermediate browser panes and keep typing in the chat composer.", .ticket = "" },
    }, .ticket = "" },
    .{ .ver = "0.28.704", .summary = "Agents no longer steal your typing", .items = &.{
        .{ .text = "When an agent opens a page, it lands in a background tab of its own pane and never pulls the keyboard away from what you are typing.", .ticket = "" },
        .{ .text = "Waking an agent's sleeping browser pane no longer freezes the app for a few seconds.", .ticket = "" },
        .{ .text = "Needs the browser extension reloaded once in chrome://extensions (version 1.0.61).", .ticket = "" },
    } },
    .{ .ver = "0.28.703", .summary = "Square corners on the message box", .items = &.{
        .{ .text = "The Chat View message box and its + button use the same small corners as the rest of the app instead of round ones.", .ticket = "" },
    } },
    .{ .ver = "0.28.702", .summary = "Pictures in Chat View", .items = &.{
        .{ .text = "Chat View has a round + at the left of the message box. Pick a picture and its link lands where you are typing.", .ticket = "" },
        .{ .text = "Ctrl+V with a picture on the clipboard does the same.", .ticket = "" },
        .{ .text = "Picture links in a conversation show as a small preview under the message. Click one to open it in the browser pane.", .ticket = "" },
    } },
    .{ .ver = "0.28.701", .summary = "Safer reminders and crash recovery", .items = &.{
        .{ .text = "Reminders and snoozes can no longer be wiped when the reminder file is busy.", .ticket = "" },
        .{ .text = "Crash recovery cannot get stuck reopening the app in a loop.", .ticket = "" },
    } },
    .{ .ver = "0.28.700", .summary = "One bubble per reply", .items = &.{
        .{ .text = "Chat View: each agent reply is now one rounded bubble, with the same corner roundness as the rest of the app.", .ticket = "" },
    } },
    .{ .ver = "0.28.699", .summary = "Chat View bubbles", .items = &.{
        .{ .text = "Chat View has rounded message bubbles: yours in light grey on the right, the agent's in dark grey on the left.", .ticket = "" },
    } },
    .{ .ver = "0.28.698", .summary = "Focus border stays put", .items = &.{
        .{ .text = "The focus border sits at the same height in the shell, Chat View and the browser, so it no longer jumps when you switch.", .ticket = "" },
    } },
    .{ .ver = "0.28.697", .summary = "Calmer focus ring", .items = &.{
        .{ .text = "The focus border is a subtle dark grey instead of bright white.", .ticket = "" },
        .{ .text = "In Chat View the focus border now includes the headline, like in the shell.", .ticket = "" },
    } },
    .{ .ver = "0.28.696", .summary = "Crash reports and auto-reopen", .items = &.{
        .{ .text = "If multiprompt ever crashes, it now saves a crash report and reopens itself with your tabs.", .ticket = "" },
        .{ .text = "Ctrl+K Crash Reports: Open Folder shows the saved reports.", .ticket = "" },
    } },
    .{ .ver = "0.28.695", .summary = "Shell column width after a font change", .items = &.{
        .{ .text = "After a font change, the shell you are on keeps its correct width while other tabs catch up.", .ticket = "" },
    } },
    .{ .ver = "0.28.694", .summary = "Font size changes are instant", .items = &.{
        .{ .text = "Changing the font size is instant again and no longer blanks Chat View.", .ticket = "" },
    } },
    .{ .ver = "0.28.693", .summary = "Alt+Tab back keeps the cursor", .items = &.{
        .{ .text = "Coming back to multiprompt with Alt+Tab puts the blinking cursor straight back where you were typing.", .ticket = "" },
    } },
    .{ .ver = "0.28.692", .summary = "5-hour window is back", .items = &.{
        .{ .text = "The usage panel shows the 5-hour window again, next to the weekly use.", .ticket = "" },
    } },
    .{ .ver = "0.28.691", .summary = "Chat View screenshot caret, instant tab switch, queued messages", .items = &.{
        .{ .text = "After a Ctrl+Shift+S screenshot link lands, you can keep typing right after it, even when the upload took a while.", .ticket = "" },
        .{ .text = "Switching tabs in Chat View shows the browser and layout at once; the conversation fills in a moment later.", .ticket = "" },
        .{ .text = "A message you sent while Claude was busy now leaves the pending bubble once Claude records it, and the bubble says Queued while Claude works.", .ticket = "" },
        .{ .text = "Ctrl+K now opens with your last 5 sessions, from every workspace, so you can hop between them with one keypress.", .ticket = "" },
    } },
    .{ .ver = "0.28.690", .summary = "Snoozed workspaces always come back", .items = &.{
        .{ .text = "Snoozed workspaces can always be woken from Ctrl+K.", .ticket = "" },
        .{ .text = "Ctrl+K Bring Back All Sessions reopens every session a workspace had.", .ticket = "" },
        .{ .text = "A snoozed workspace no longer disappears when your tabs sync from your account.", .ticket = "" },
    } },
    .{ .ver = "0.28.689", .summary = "Agent pane requests stay in the background", .items = &.{
        .{ .text = "Agents using the browser pane no longer switch you to their tab.", .ticket = "" },
        .{ .text = "Background tab checks no longer jump you to another session every 30 seconds.", .ticket = "" },
    } },
    .{ .ver = "0.28.688", .summary = "Synced tabs stay put", .items = &.{
        .{ .text = "Tabs you did not close on this computer can no longer disappear because another device synced, so agents in those tabs keep their browser pane.", .ticket = "" },
    } },
    .{ .ver = "0.28.687", .summary = "Your typing stays yours, plus a Relaunch card", .items = &.{
        .{ .text = "Nothing can pull your typing focus away anymore: agents and browser reconnects leave your typing in the shell or Chat View, and multiprompt no longer closes by itself after reopening your tabs.", .ticket = "" },
        .{ .text = "Text you type in Chat View is kept across restarts, per tab.", .ticket = "" },
        .{ .text = "A slash command you send shows once, as you typed it.", .ticket = "" },
        .{ .text = "F2 renames the tab from Chat View too.", .ticket = "" },
        .{ .text = "When a new version is installed, a small card in the bottom left offers Relaunch.", .ticket = "" },
        .{ .text = "Relaunch closes every window, saves your tabs and reopens multiprompt on the new version.", .ticket = "" },
        .{ .text = "Ctrl+K has \"Update: Relaunch\" and the x on the card hides it until the next version.", .ticket = "" },
        .{ .text = "The usage panel now lists exactly the AI plans the Token Ladder watches, with a line showing which plan to use up right now.", .ticket = "" },
        .{ .text = "Ctrl+K can switch it: Token Ladder: Auto, Burn Claude, Burn Codex, and Open Dashboard.", .ticket = "" },
        .{ .text = "Ctrl+K can turn Chat View on everywhere, per tab, or off everywhere.", .ticket = "" },
        .{ .text = "The browser pane's frame now matches your multiprompt theme, including AMOLED black (load the theme folder once).", .ticket = "" },
    } },
    .{ .ver = "0.28.685", .summary = "Sign in once and every laptop shows the same tabs", .items = &.{
        .{ .text = "multiprompt opens locked and shows your tabs only after you sign in with your email code.", .ticket = "" },
        .{ .text = "Your workspaces and tabs stay the same on every signed-in laptop.", .ticket = "" },
        .{ .text = "Ctrl+K has Account: Sign Out, Account: Devices and Sync: Pull Now.", .ticket = "" },
        .{ .text = "Agents drive the browser pane on the laptop you are using, not the one that connected last.", .ticket = "" },
        .{ .text = "A page an agent opens shows up next to your current tab and comes to the front.", .ticket = "" },
        .{ .text = "Agents can list their pane tabs again and run scripts on strict pages like Facebook Events Manager.", .ticket = "" },
    } },
    .{ .ver = "0.28.684", .summary = "Sessions follow you between laptops; agents can test their pane", .items = &.{
        .{ .text = "Ctrl+K \"Sync: Pull Layout From Server\" adds the tmux tabs you opened on your other laptop.", .ticket = "" },
        .{ .text = "Two tabs on the same tmux session no longer fight over one browser pane.", .ticket = "" },
        .{ .text = "Agents can run zsb selftest to check their browser pane works and is the one you see.", .ticket = "" },
    } },
    .{ .ver = "0.28.683", .summary = "Agents keep their own browser pane", .items = &.{
        .{ .text = "A login popup or another window no longer takes over an agent's browser pane.", .ticket = "" },
        .{ .text = "Agents can click and type on pages where another extension, like 1Password, adds its own frame.", .ticket = "" },
    } },
    .{ .ver = "0.28.682", .summary = "Chat View no longer claims a lost message was sent", .items = &.{
        .{ .text = "If a message from Chat View never reaches Claude, it now turns red with a Retry option instead of showing \"Sent\".", .ticket = "" },
    } },
    .{ .ver = "0.28.681", .summary = "Shortcuts work again after unlocking the screen", .items = &.{
        .{ .text = "Keyboard shortcuts no longer stop working after you lock the screen with Win+L.", .ticket = "" },
    } },
    .{ .ver = "0.28.680", .summary = "Chat View shows when the AI is working", .items = &.{
        .{ .text = "Chat View shows a small line above the message box while the AI is working, like \"Cogitating... 12s\".", .ticket = "" },
        .{ .text = "In long conversations, a message you send no longer shows twice in Chat View.", .ticket = "" },
    } },
    .{ .ver = "0.28.679", .summary = "Chat View shows where Alt+Q put you", .items = &.{
        .{ .text = "In Chat View, the focus ring now moves to the browser when Alt+Q switches there, and back to the chat when you return.", .ticket = "" },
    } },
    .{ .ver = "0.28.678", .summary = "Alt+Q into the browser stays there in Chat View", .items = &.{
        .{ .text = "In Chat View, Alt+Q into the browser no longer gets pulled back to the chat box a moment later.", .ticket = "" },
    } },
    .{ .ver = "0.28.677", .summary = "Chat View sends each message once", .items = &.{
        .{ .text = "Chat View no longer sends the same message to a session several times.", .ticket = "" },
        .{ .text = "If Chat View can't confirm a message arrived, it shows Not sent and you choose whether to resend it.", .ticket = "" },
    } },
    .{ .ver = "0.28.676", .summary = "Agent page opens always show the page", .items = &.{
        .{ .text = "When an agent opens a page and your pane already shows another one, the new page now opens in front instead of nothing happening.", .ticket = "" },
    } },
    .{ .ver = "0.28.675", .summary = "Agent page opens report correctly", .items = &.{
        .{ .text = "When an agent opens a page in your browser pane, it no longer reports a failure for a page that did open.", .ticket = "" },
    } },
    .{ .ver = "0.28.674", .summary = "Browser pane stays connected", .items = &.{
        .{ .text = "When an agent opens a page, it now shows up in your browser pane instead of a hidden tab behind the black placeholder.", .ticket = "" },
        .{ .text = "Agents no longer lose your browser pane mid-session, so you stop having to press Ctrl+Shift+O again; needs an extension reload.", .ticket = "" },
    } },
    .{ .ver = "0.28.673", .summary = "Alt+Q works in Chat View", .items = &.{
        .{ .text = "Alt+Q now switches between Chat View and the browser in both directions, like it does in the shell.", .ticket = "" },
    } },
    .{ .ver = "0.28.672", .summary = "Alt+Q switches once", .items = &.{
        .{ .text = "Alt+Q from Chat View into the browser no longer bounces focus back and forth several times.", .ticket = "" },
    } },
    .{ .ver = "0.28.671", .summary = "No more layout jumping on tabs with a browser", .items = &.{
        .{ .text = "Tabs with a browser open in their final layout right away; the shell and Chat View no longer jump sideways when the browser arrives.", .ticket = "" },
        .{ .text = "While the browser is still opening, its space shows a quiet \"Opening browser\u{2026}\" note instead of the layout shifting.", .ticket = "" },
    } },
    .{ .ver = "0.28.670", .summary = "Mouse and Alt+Q work in Chat View", .items = &.{
        .{ .text = "Clicking tabs, workspaces and the Inbox button in the sidebar works again while Chat View is open.", .ticket = "" },
        .{ .text = "Alt+Q from the browser back to Chat View now lands reliably, with the cursor blinking in the message box.", .ticket = "" },
    } },
    .{ .ver = "0.28.669", .summary = "Browser panes stay behind overlays", .items = &.{
        .{ .text = "A browser that finishes opening while the Inbox, Ctrl+K or F1 is open no longer covers it.", .ticket = "" },
        .{ .text = "A browser opening for a background tab stays hidden until you switch to that tab.", .ticket = "" },
    } },
    .{ .ver = "0.28.668", .summary = "Hotfix: typing works again", .items = &.{
        .{ .text = "Fixed keys acting as Alt shortcuts (jumping into Inbox) after Chat View took focus back.", .ticket = "" },
    } },
    .{ .ver = "0.28.667", .summary = "Chat View fixes: paste, focus, queued messages, battery", .items = &.{
        .{ .text = "The message box grows right away when you paste a block of text.", .ticket = "" },
        .{ .text = "Clicking or selecting text in the chat keeps the blinking cursor in the message box.", .ticket = "" },
        .{ .text = "Alt+Q switches between Chat View and the browser pane in both directions.", .ticket = "" },
        .{ .text = "A message Claude has queued while it works stays visible as \"Sent - queued in Claude\"; click it to send it now.", .ticket = "" },
        .{ .text = "Messages that reached the conversation show a double check.", .ticket = "" },
        .{ .text = "Battery saving no longer freezes or closes the browser of a session that is working or using it.", .ticket = "" },
        .{ .text = "Tabs no longer lose their session because Claude's status bar was mistaken for a tmux name.", .ticket = "" },
    } },
    .{ .ver = "0.28.666", .summary = "Sent messages show up instantly with a status", .items = &.{
        .{ .text = "A message you send in Chat View appears right away, marked Sending, Waiting for connection, or Sent.", .ticket = "" },
        .{ .text = "If a message doesn't go through it stays in the chat as Not sent; click it to retry.", .ticket = "" },
        .{ .text = "Ctrl+K has Retry Unsent Messages and Discard Unsent Messages.", .ticket = "" },
        .{ .text = "Links inside brackets are clickable.", .ticket = "" },
        .{ .text = "The Claude Code startup banner no longer shows up as a chat message.", .ticket = "" },
    } },
    .{ .ver = "0.28.665", .summary = "Chat View shows whole conversations again", .items = &.{
        .{ .text = "Sessions running as another user (like the secondary tabs) now show their full, scrollable conversation in Chat View.", .ticket = "" },
        .{ .text = "Chat View stays pinned to the newest message unless you scroll up yourself.", .ticket = "" },
        .{ .text = "The message box spans the full width of the chat.", .ticket = "" },
    } },
    .{ .ver = "0.28.664", .summary = "Focus stops jumping while you type", .items = &.{
        .{ .text = "Fixed the message box losing focus every few letters; automatic reconnect is switched off until it is fixed properly.", .ticket = "" },
    } },
    .{ .ver = "0.28.663", .summary = "Fixes for the 0.28.662 problems", .items = &.{
        .{ .text = "Focus no longer jumps between the browser pane and Chat View when a session reconnects.", .ticket = "" },
        .{ .text = "Sessions survive short connection drops again instead of disconnecting after 15 seconds.", .ticket = "" },
        .{ .text = "The Send button sits neatly inside the message box.", .ticket = "" },
    } },
    .{ .ver = "0.28.662", .summary = "Chat View you can actually read on a train", .items = &.{
        .{ .text = "Chat View finds each session's real conversation by itself, so you can scroll back through the whole chat.", .ticket = "" },
        .{ .text = "The chat stays put while the agent works instead of jumping around.", .ticket = "" },
        .{ .text = "Short chats sit at the bottom above the message box instead of leaving a gap.", .ticket = "" },
        .{ .text = "When the connection drops, the last messages stay on screen and you're told the connection is gone.", .ticket = "" },
        .{ .text = "Messages sent while offline are queued, shown above the message box, and sent once the connection is back.", .ticket = "" },
        .{ .text = "Dropped tmux sessions reconnect on their own.", .ticket = "" },
        .{ .text = "Drag to select any text in Chat View and copy it with Ctrl+C or right-click.", .ticket = "" },
        .{ .text = "Lists indent properly, the text has side padding, and the stray session-name line is gone.", .ticket = "" },
        .{ .text = "The message box starts one line high, grows as you type, and Ctrl+A selects everything in it.", .ticket = "" },
        .{ .text = "Ctrl+Shift+S puts the screenshot link into the Chat View message box when Chat View is open.", .ticket = "" },
        .{ .text = "Bold text is readable again in the shell on the light theme.", .ticket = "" },
        .{ .text = "Chat View only downloads the conversation again when it has changed, which saves data on slow connections.", .ticket = "" },
    } },
    .{ .ver = "0.28.661", .summary = "Chat View sends reliably", .items = &.{
        .{ .text = "Pressing Enter in Chat View now always sends, also on a slow connection.", .ticket = "" },
        .{ .text = "If a message still doesn't go through, Chat View tells you instead of failing silently.", .ticket = "" },
    } },
    .{ .ver = "0.28.660", .summary = "A clearer, richer Chat View", .items = &.{
        .{ .text = "Chat View reads the conversation directly and shows formatted replies, lists, tables and links.", .ticket = "" },
        .{ .text = "Your messages have tinted bubbles, while replies show an agent avatar and recorded time.", .ticket = "" },
        .{ .text = "Code blocks have readable colors and a Copy button, with Ctrl+Shift+D to copy the latest block.", .ticket = "" },
    } },
    .{ .ver = "0.28.659", .summary = "Command palette from the browser pane", .items = &.{
        .{ .text = "Ctrl+Shift+K opens the command palette from anywhere, also from the browser pane.", .ticket = "" },
        .{ .text = "The Inbox shows each session's time left as a short bar in its own column on the same line.", .ticket = "" },
        .{ .text = "Archiving a session in the Inbox with E hides it right away, without it flashing back.", .ticket = "" },
    } },
    .{ .ver = "0.28.658", .summary = "Links, blue dots and Inbox fixes", .items = &.{
        .{ .text = "Links that wrap onto the next line now open in full, also inside agent sessions.", .ticket = "" },
        .{ .text = "A session that finishes after picking its work back up by itself now gets its blue dot.", .ticket = "" },
        .{ .text = "A blue dot clears when an agent carries on working without a new message from you.", .ticket = "" },
        .{ .text = "Inbox rows now show the same countdown and progress bar as the sidebar.", .ticket = "" },
        .{ .text = "Ctrl+K 'Inbox: Never Show This Session' keeps a session out of the Inbox but in the sidebar.", .ticket = "" },
    } },
    .{ .ver = "0.28.657", .summary = "Blue dots only when agents finish or need input", .items = &.{
        .{ .text = "Blue dots no longer appear while an agent is still working; they mean the agent finished or needs you.", .ticket = "" },
    } },
    .{ .ver = "0.28.656", .summary = "Archived sessions only return with new content", .items = &.{
        .{ .text = "Archived sessions now only come back when the agent has written something new.", .ticket = "" },
        .{ .text = "Countdowns now keep showing while an agent's background work runs after it replies.", .ticket = "" },
    } },
    .{ .ver = "0.28.655", .summary = "Inbox button in the workspace strip", .items = &.{
        .{ .text = "The workspace name at the top left is now an inbox button; click it to open the Inbox.", .ticket = "" },
        .{ .text = "Alt+T can start Claude Code directly in a workspace's folder, set per workspace.", .ticket = "" },
        .{ .text = "Agent browser commands reopen a sleeping browser pane instead of failing.", .ticket = "" },
    } },
    .{ .ver = "0.28.654", .summary = "Crash fix, notifications on every laptop, voice and link fixes", .items = &.{
        .{ .text = "Ctrl+K no longer crashes the app when it shows the Voice: Stop Speaking row.", .ticket = "" },
        .{ .text = "Two laptops can now both get agent notifications from the same servers.", .ticket = "" },
        .{ .text = "Failed notification connections wait longer between retries instead of repeatedly opening SSH.", .ticket = "" },
        .{ .text = "Remote tabs now start even when the usual ssh program is missing or broken on this laptop.", .ticket = "" },
        .{ .text = "Voice Mode no longer reads Claude status lines, like update notices or token counts, aloud.", .ticket = "" },
        .{ .text = "Alt+[ and Alt+] read the previous or next agent reply aloud.", .ticket = "" },
        .{ .text = "Clicking a link that wraps onto the next line now opens the whole link.", .ticket = "" },
        .{ .text = "Links in Chat View can now be clicked.", .ticket = "" },
    } },
    .{ .ver = "0.28.652", .summary = "Sign-in fix", .ticket = "", .items = &.{
        .{ .text = "Sign in to multiprompt now opens your browser; before, nothing happened.", .ticket = "" },
    } },
    .{ .ver = "0.28.651", .summary = "Snooze a workspace", .ticket = "", .items = &.{
        .{ .text = "Snooze a workspace until a time you choose; local tabs return as they would after an app restart.", .ticket = "" },
        .{ .text = "Wake a workspace early from the command palette without waking sessions you snoozed separately.", .ticket = "" },
    } },
    .{ .ver = "0.28.650", .summary = "Chat View command and skill suggestions", .ticket = "", .items = &.{
        .{ .text = "Type / in Chat View to find Claude or Codex commands and skills.", .ticket = "" },
        .{ .text = "Type $ in a Codex chat to find its skills.", .ticket = "" },
        .{ .text = "Press Ctrl+/ to browse commands without typing.", .ticket = "" },
        .{ .text = "Press Enter to insert a suggestion, then Enter again to send it.", .ticket = "" },
        .{ .text = "Disabled and outdated skills no longer appear in the Skills menu.", .ticket = "" },
    } },
    .{ .ver = "0.28.649", .summary = "Pick how fast Voice Mode talks", .ticket = "", .items = &.{
        .{ .text = "Pick how fast Voice Mode talks in Ctrl+K: 1x, 1.25x, 1.4x or 1.5x.", .ticket = "" },
        .{ .text = "A speed change applies to the next reply, no restart needed.", .ticket = "" },
        .{ .text = "Ctrl+K and the other overlays keep Chat View on screen instead of switching to the terminal.", .ticket = "" },
        .{ .text = "Press Alt+R to hear the agent's last reply again, even with Voice Mode off.", .ticket = "" },
        .{ .text = "Voice Mode now also works in the normal terminal view, not only in Chat View.", .ticket = "" },
        .{ .text = "Deepgram no longer keeps your voice recordings for training.", .ticket = "" },
    } },
    .{ .ver = "0.28.648", .summary = "Voice Mode works like a phone call", .ticket = "", .items = &.{
        .{ .text = "While Voice Mode is on, the mic keeps listening, so you can talk over the agent at any time.", .ticket = "" },
        .{ .text = "When you start talking, the agent stops and your words are sent after a short pause.", .ticket = "" },
        .{ .text = "The agent's own voice from your speakers is ignored.", .ticket = "" },
        .{ .text = "Turn it off in Ctrl+K with \"Voice: Always Listening Off\" to go back to taking turns.", .ticket = "" },
        .{ .text = "Voice Mode turns itself off after 10 quiet minutes.", .ticket = "" },
    } },
    .{ .ver = "0.28.647", .summary = "Voice Mode starts faster and talks faster", .ticket = "", .items = &.{
        .{ .text = "Voice Mode starts speaking within a second instead of after the whole reply downloads.", .ticket = "" },
        .{ .text = "You can type while Voice Mode speaks; press Alt+V to stop it talking, and again to turn Voice Mode off.", .ticket = "" },
        .{ .text = "Voice Mode speaks 25 percent faster.", .ticket = "" },
        .{ .text = "Starting dictation stops Voice Mode talking right away.", .ticket = "" },
        .{ .text = "Chat View text now starts at size 14.", .ticket = "" },
    } },
    .{ .ver = "0.28.646", .summary = "Chat View per tab, Enter always sends, Voice Mode skips links", .ticket = "", .items = &.{
        .{ .text = "Each tab now remembers whether you had Chat View on, and new tabs start in the terminal.", .ticket = "" },
        .{ .text = "Pick how that works in Ctrl+K: \"Chat View: Remember Per Session\", \"Everywhere\" or \"Nowhere\".", .ticket = "" },
        .{ .text = "Enter in Chat View presses send again if your message is still sitting in the agent's typing box.", .ticket = "" },
        .{ .text = "Voice Mode no longer reads web links out loud.", .ticket = "" },
        .{ .text = "Voice Mode stays on when you switch tabs; only the tab on screen speaks.", .ticket = "" },
    } },
    .{ .ver = "0.28.645", .summary = "Time estimates per tab, Ctrl+K in Chat View", .ticket = "", .items = &.{
        .{ .text = "Tabs can show how long the agent expects to need: a countdown next to the lock, and a thin line under the tab that fills up.", .ticket = "" },
        .{ .text = "Turn each one on or off in Ctrl+K: \"ETA Countdown Numbers\" and \"ETA Progress Line\".", .ticket = "" },
        .{ .text = "Chat View shows the estimate at the top right, and the Inbox shows it next to the time.", .ticket = "" },
        .{ .text = "Ctrl+K \"Estimate Accuracy\" shows how far off each agent's estimates usually are.", .ticket = "" },
        .{ .text = "Ctrl+K now opens the command palette from the Chat View typing box.", .ticket = "" },
    } },
    .{ .ver = "0.28.644", .summary = "Voice Mode reads finished replies, calmer Chat View", .ticket = "", .items = &.{
        .{ .text = "Voice Mode now reads the reply as soon as the agent has finished on screen, instead of staying on \"waiting for agent\".", .ticket = "" },
        .{ .text = "Chat View hides more tool noise, like running commands and background agent lists, so the chat no longer flashes.", .ticket = "" },
        .{ .text = "The extra Voice Mode pop-up messages are gone; the label at the top right shows the state.", .ticket = "" },
    } },
    .{ .ver = "0.28.643", .summary = "Chat View: Ctrl+K and browser pane", .ticket = "", .items = &.{
        .{ .text = "Ctrl+K opens the command palette in Chat View, and pressing it again closes it.", .ticket = "" },
        .{ .text = "Switching tabs in Chat View keeps each tab's browser pane and the page inside it.", .ticket = "" },
    } },
    .{ .ver = "0.28.642", .summary = "Voice Mode says what it is doing", .ticket = "", .items = &.{
        .{ .text = "Alt+V now shows \"Voice Mode on\" or \"Voice Mode off\", and says when it is waiting for the agent to finish before reading.", .ticket = "" },
    } },
    .{ .ver = "0.28.641", .summary = "Deepgram voice always found", .ticket = "", .items = &.{
        .{ .text = "Voice Mode now always finds your Deepgram key, so replies use the Deepgram voice instead of falling back to the Windows voice.", .ticket = "" },
    } },
    .{ .ver = "0.28.640", .summary = "Better voice, smoother Chat View, sync sign-in", .ticket = "", .items = &.{
        .{ .text = "Voice Mode now reads replies in a natural Deepgram voice instead of the robotic Windows voice.", .ticket = "" },
        .{ .text = "In Chat View the blinking cursor stays in the typing box, and the white active frame is no longer broken.", .ticket = "" },
        .{ .text = "Ctrl+Plus, Ctrl+Minus and Ctrl+0 change the Chat View text size, like in the terminal.", .ticket = "" },
        .{ .text = "The typing box grows as you write, up to five lines, then scrolls; the send button is a larger right arrow.", .ticket = "" },
        .{ .text = "The hint text in the typing box disappears as soon as you type, and lines like \"Read 1 file\" no longer clutter the chat.", .ticket = "" },
        .{ .text = "Page Up and Page Down scroll the conversation while you type.", .ticket = "" },
        .{ .text = "New in Ctrl+K: \"Sign in to multiprompt sync\" (first step of syncing between your laptops and phone).", .ticket = "" },
    } },
    .{ .ver = "0.28.639", .summary = "Voice Mode", .ticket = "", .items = &.{
        .{ .text = "New Voice Mode (Alt+V, or Voice Mode in Ctrl+K): the agent's reply is read aloud, then multiprompt listens and sends your spoken answer.", .ticket = "" },
        .{ .text = "Press any key to stop the voice; leaving Chat View turns Voice Mode off.", .ticket = "" },
        .{ .text = "Dictation (Ctrl+Shift+Space) in Chat View now types into the chat box instead of the terminal.", .ticket = "" },
    } },
    .{ .ver = "0.28.638", .summary = "Shortcuts work in Chat View", .ticket = "", .items = &.{
        .{ .text = "Switching sessions and workspaces now works while Chat View is open (Ctrl+Tab, Ctrl+1-9, Alt+1-9, Ctrl+Shift+J/K).", .ticket = "" },
        .{ .text = "The other app shortcuts work in Chat View too, like Ctrl+T, Ctrl+W, Ctrl+Shift+I, F1 and F2.", .ticket = "" },
        .{ .text = "Copy, paste, undo and select-all still work in the Chat View typing box, and AltGr characters like the euro sign type normally.", .ticket = "" },
    } },
    .{ .ver = "0.28.637", .summary = "Chat View looks like a chat app", .ticket = "", .items = &.{
        .{ .text = "Your messages now sit in a bubble on the right; the agent's replies read as plain text.", .ticket = "" },
        .{ .text = "Tool calls, status lines and progress messages are hidden in Chat View.", .ticket = "" },
        .{ .text = "Code shows in a fixed-width font on a darker panel.", .ticket = "" },
        .{ .text = "Right-click any message to copy it.", .ticket = "" },
        .{ .text = "Alt+C switches Chat View on and off from anywhere; Esc no longer leaves it.", .ticket = "" },
    } },
    .{ .ver = "0.28.636", .summary = "Chat View reads like a chat app", .ticket = "", .items = &.{
        .{ .text = "Chat View now uses the IBM Plex Sans reading font instead of the terminal font.", .ticket = "" },
        .{ .text = "Chat View is now as wide as the terminal, and fits beside the browser pane when one is open.", .ticket = "" },
        .{ .text = "Ctrl+K, the Inbox and F1 now work from inside Chat View without switching back to the terminal.", .ticket = "" },
        .{ .text = "Dictation works again when you hold Ctrl+Shift+Space, and says why if it fails.", .ticket = "" },
        .{ .text = "Dictation uses Deepgram's European server, about twice as fast from Europe.", .ticket = "" },
    } },
    .{ .ver = "0.28.635", .summary = "Battery saver: multiprompt uses far less power in the background", .ticket = "", .items = &.{
        .{ .text = "On battery or Energy Saver, background checks run less often; pick Power Saver: Auto, Always or Off in Ctrl+K.", .ticket = "" },
        .{ .text = "When you step away or leave the app in the background for 5 minutes, it goes idle and stops almost all background work.", .ticket = "" },
        .{ .text = "Hidden browser panes freeze after 2 minutes and fully sleep after 15 (30 seconds and 5 minutes on battery or while idle).", .ticket = "" },
        .{ .text = "Alt+P keeps the current tab's browser pane awake; Ctrl+K \"Hibernate Browser Panes Now\" sleeps all hidden panes at once.", .ticket = "" },
        .{ .text = "VPS status checks reuse one connection per server and only one window polls for all of them.", .ticket = "" },
        .{ .text = "The title bar shows \"Saver\" or \"Idle\" when power saving is active.", .ticket = "" },
    } },
    .{ .ver = "0.28.634", .summary = "Alt+S no longer blocks the extension screenshot shortcut", .ticket = "", .items = &.{
        .{ .text = "Alt+S requires Shift to be released, so Alt+Shift+S reaches the browser extension instead of opening WebView2. Ctrl+Shift+S remains the native screenshot shortcut.", .ticket = "" },
    } },
    .{ .ver = "0.28.633", .summary = "Workspace search follows typed names and duplicate Other slots merge safely", .ticket = "", .items = &.{
        .{ .text = "Move to Workspace and Move to Group filter typed names. Searchable submenus put exact matches first and select the first result after Back.", .ticket = "" },
        .{ .text = "Duplicate Other workspaces merge into the catch-all without closing sessions or changing their locks, groups or browser settings.", .ticket = "" },
        .{ .text = "Reminder presets accept search, submenu results exclude unrelated root commands, and the workspace reorder menu no longer accepts unused search text.", .ticket = "" },
    } },
    .{ .ver = "0.28.632", .summary = "Alt+Q switches focus once per keypress", .ticket = "", .items = &.{
        .{ .text = "Alt+Q and its Alt+M compatibility alias now consume Windows key-repeat events until the physical key is released, so a repeat cannot cancel a pending browser hop or immediately switch back.", .ticket = "" },
        .{ .text = "The latch has no time-based debounce, so a separate rapid press still switches focus immediately.", .ticket = "" },
    } },
    .{ .ver = "0.28.631", .summary = "Open every tmux session from one VPS", .ticket = "", .items = &.{
        .{ .text = "Ctrl+K now has Open all VPS tmux sessions, followed by a Host 1, Host 2, or Remote host 3 host picker.", .ticket = "" },
        .{ .text = "Choosing a host opens every session from that VPS that is not already represented by a local tab, without duplicating existing tabs.", .ticket = "" },
    } },
    .{ .ver = "0.28.630", .summary = "Remote host 3 tmux sessions reconnect natively", .ticket = "", .items = &.{
        .{ .text = "The remote-3 SSH profile is now a native third tmux host, so its sessions keep their tmux identity, agent icon, live title, and saved host across restart.", .ticket = "" },
        .{ .text = "All Sessions discovers Remote host 3 sessions and labels them HOST3-TMX; transport drops use the existing SSH auto-respawn path instead of returning to a local CMD prompt.", .ticket = "" },
    } },
    .{ .ver = "0.28.629", .summary = "Skills belong in Ctrl+K", .ticket = "", .items = &.{
        .{ .text = "Ctrl+K now opens a searchable Skills submenu with multiprompt skills first and coding-harness skills second.", .ticket = "" },
        .{ .text = "The Chat View plus button is gone and the composer has its original full-width input layout again.", .ticket = "" },
    } },
    .{ .ver = "0.28.628", .summary = "Chat View skills and secure desktop login foundation", .ticket = "", .items = &.{
        .{ .text = "Chat View adds a plus menu with bundled multiprompt skills and live coding-harness SKILL.md discovery.", .ticket = "" },
        .{ .text = "Selected skills use the same marker and injected message envelope as Android, including skill-only sends.", .ticket = "" },
        .{ .text = "Ctrl+K starts a system-browser OIDC authorization-code flow with PKCE and stores pending and returned credentials under Windows DPAPI.", .ticket = "" },
    } },
    .{ .ver = "0.28.619", .summary = "Chat View reflows narrow console history", .ticket = "", .items = &.{
        .{ .text = "Console-wrapped conversational rows are joined into paragraphs so history uses the current Chat View width after a resize or maximize.", .ticket = "" },
        .{ .text = "Blank lines, prompts, lists, dividers, and fenced code retain their intentional structure; Claude timing rows using the teardrop-spoked marker are filtered with other tool activity.", .ticket = "" },
    } },
    .{ .ver = "0.28.618", .summary = "Chat View respects the docked browser split", .ticket = "", .items = &.{
        .{ .text = "The transcript and composer now use the browser splitter as their right boundary instead of extending beneath the docked browser window.", .ticket = "" },
        .{ .text = "Chat View keeps its existing centered width when no browser is open and reflows with the saved per-session split when a browser is docked.", .ticket = "" },
    } },
    .{ .ver = "0.28.617", .summary = "Chat View uses the app surface and sends reliably to local agents", .ticket = "", .items = &.{
        .{ .text = "The duplicate Conversation header, status line, transcript card, Stop button, and Terminal button are removed; the transcript now sits directly on the main pane background.", .ticket = "" },
        .{ .text = "The Hack reader font is smaller, the composer is the only boxed area, and its send button is a compact square with lightly rounded corners.", .ticket = "" },
        .{ .text = "Recognized local Claude, Codex, Hax, Grok, and Cursor sessions use direct console input for both prompt text and Enter. Ctrl+K works from the composer and offers Stop Agent plus Return to Terminal.", .ticket = "" },
    } },
    .{ .ver = "0.28.616", .summary = "Chat View puts a native conversation layer over any terminal", .ticket = "", .items = &.{
        .{ .text = "Alt+C switches the active session between its real console and a live monospaced transcript with a native prompt composer.", .ticket = "" },
        .{ .text = "Enter sends, Shift+Enter adds a line, Interrupt sends Ctrl+C, and Terminal returns to the unchanged underlying console.", .ticket = "" },
        .{ .text = "The transcript follows tab switches, reads console scrollback directly, and removes the coding agent's active composer so it is not duplicated on screen.", .ticket = "" },
    } },
    .{ .ver = "0.28.615", .summary = "workspace names and history survive window-mode changes", .ticket = "", .items = &.{
        .{ .text = "Turning off Single-Window Mode keeps the active workspace name on the current frame instead of falling back to Main.", .ticket = "" },
        .{ .text = "Every other open pill is atomically exported and remains available from Ctrl+K Workspaces as a standalone workspace.", .ticket = "" },
        .{ .text = "A failed export aborts the mode change before any shell is detached.", .ticket = "" },
        .{ .text = "Standalone workspace exports preserve custom groups, pins, locks, browser state, and attention state without forcing the reopened window back into Single-Window Mode.", .ticket = "" },
    } },
    .{ .ver = "0.28.614", .summary = "keyboard shortcuts recover immediately after hibernation", .ticket = "", .items = &.{
        .{ .text = "A dedicated input-thread sentinel detects the first physical key that bypasses multiprompt's main keyboard hook and force-cycles the stale hook.", .ticket = "" },
        .{ .text = "The same independent thread detects sleep-sized timer gaps and reinstalls both permanent input hooks without waiting for main-window activation.", .ticket = "" },
        .{ .text = "Alt+A recovers a saved browser pane whose enabled flag survived but whose Chromium window did not, instead of requiring an off/on double toggle.", .ticket = "" },
    } },
    .{ .ver = "0.28.613", .summary = "zsb tab control and difficult pages are reliable", .ticket = "", .items = &.{
        .{ .text = "Pending beforeunload dialogs are accepted before navigation, reload, history movement, and screenshots.", .ticket = "" },
        .{ .text = "Text, links, find, snapshots, clicks, and typing can traverse cross-origin frames.", .ticket = "" },
        .{ .text = "Tabs can be closed by numeric ID or an unambiguous title or URL match.", .ticket = "" },
        .{ .text = "Read, screenshot, and click commands accept --tab without activating the target tab.", .ticket = "" },
        .{ .text = "Agent-created tabs no longer inherit an opener, and every CDP operation has a 15-second timeout.", .ticket = "" },
        .{ .text = "zsb open preserves signed URLs up to 8 KiB instead of truncating the query string.", .ticket = "" },
        .{ .text = "Page scripting failures now return top-level ok:false for reliable shell error handling.", .ticket = "" },
        .{ .text = "Remote zsb requests accept 48 KiB decoded payloads within the Win32 command-line limit.", .ticket = "" },
        .{ .text = "Snapshots include visible menus, options, list rows, tab controls, and icon-only controls.", .ticket = "" },
    } },
    .{ .ver = "0.28.612", .summary = "zsb interaction and diagnostics are reliable", .ticket = "", .items = &.{
        .{ .text = "Click now sends trusted mouse movement, press, and release events; key-down and key-up share one serialized CDP session.", .ticket = "" },
        .{ .text = "Type accepts focused text or selector plus text, and uses trusted input instead of directly mutating DOM values.", .ticket = "" },
        .{ .text = "Screenshots use fresh serialized debugger sessions, validate PNG data, retry three times, and return the real capture error if all attempts fail.", .ticket = "" },
        .{ .text = "New zsb url command exposes the exact targeted page URL without inferring it from DOM content.", .ticket = "" },
        .{ .text = "New zsb console command returns recent Runtime and Log entries with level, timestamp, source, and page location.", .ticket = "" },
    } },
    .{ .ver = "0.28.611", .summary = "Cursor CLI has its own sidebar identity", .ticket = "", .items = &.{
        .{ .text = "Cursor CLI sessions use agent ID 7 across process, title, tmux inventory, notification, diagnostic, Inbox, and All Sessions paths.", .ticket = "" },
        .{ .text = "Live Cursor evidence replaces stale Claude resume metadata when a remote tmux session is reused.", .ticket = "" },
        .{ .text = "The sidebar draws Cursor's native monochrome nested-diamond mark in every agent icon lane.", .ticket = "" },
    } },
    .{ .ver = "0.28.610", .summary = "Move sessions to groups from Ctrl+K", .ticket = "", .items = &.{
        .{ .text = "Move to Group opens a keyboard submenu for existing groups, New group, and No group.", .ticket = "" },
        .{ .text = "The active session is captured by stable ID, and Ctrl-selected sessions move together.", .ticket = "" },
    } },
    .{ .ver = "0.28.606", .summary = "Workspace groups own sidebar organization", .ticket = "", .items = &.{
        .{ .text = "Custom groups are stable top-level blocks inside each workspace; creating one immediately opens its name editor.", .ticket = "" },
        .{ .text = "Pinned tabs sort first inside their group, while locked tabs stay in place with an inline padlock and retain every close guard.", .ticket = "" },
        .{ .text = "Empty workspaces close through a valid atomic zero-tab export, reopen empty when named, and no longer remove unrelated empty pills.", .ticket = "" },
    } },
    .{ .ver = "0.28.605", .summary = "Closing a workspace hibernates locked sessions", .ticket = "", .items = &.{
        .{ .text = "Close Workspace now exports and detaches locked tabs instead of demanding that every session be unlocked first.", .ticket = "" },
        .{ .text = "Remote tmux sessions keep running, and each saved lock bit returns when Open Workspace restores the workspace.", .ticket = "" },
        .{ .text = "Workspace hibernation leaves all tabs open if its atomic export fails; destructive workspace deletion and individual close actions still reject locked sessions.", .ticket = "" },
    } },
    .{ .ver = "0.28.604", .summary = "Grok identity and neutral workspace terminals", .ticket = "", .items = &.{
        .{ .text = "Grok CLI sessions now keep agent ID 6 across tmux command detection, local process and title detection, notifications, diagnostics, capacity accounting, and persistence.", .ticket = "" },
        .{ .text = "The sidebar draws Grok as a native G with a blue orbital slash instead of falling through to another agent's icon.", .ticket = "" },
        .{ .text = "Alt+T now creates a plain term-* tmux shell in the active workspace's configured or inferred remote folder; it never starts a configured Claude command or reserves agent capacity.", .ticket = "" },
        .{ .text = "Claude telemetry reconnect detects a freshly copied browser code and submits it through the console input buffer, bypassing terminal paste bindings entirely.", .ticket = "" },
    } },
    .{ .ver = "0.28.603", .summary = "Ctrl+click and shortcuts recover after hibernation", .ticket = "", .items = &.{
        .{ .text = "Physical shell Ctrl+click now has an always-ready fallback on the dedicated mouse-hook thread, removing the race where a quick click arrived before the temporary UI-thread hook was installed.", .ticket = "" },
        .{ .text = "The hook watchdog now acts on a post-sleep timer gap before checking foreground ownership, so a lock screen or another foreground app cannot consume the only evidence that Windows detached the shortcut hook.", .ticket = "" },
        .{ .text = "Ctrl+K now offers separate forced reconnect actions for the Primary and Secondary Claude telemetry profiles; each opens its own visible terminal and cannot skip the selected account because another profile still has a reusable token.", .ticket = "" },
    } },
    .{ .ver = "0.28.602", .summary = "Saved VPS sessions reconnect through their SSH profiles", .ticket = "", .items = &.{
        .{ .text = "Every interactive shell, tunnel keeper, tmux action, favicon lookup, and telemetry probe now uses the configured vps or remote-2 SSH profile instead of bypassing its identity file with a raw IP target.", .ticket = "" },
        .{ .text = "A stable restart can reattach saved remote tabs even when the matching private key is not already loaded into the Windows SSH agent.", .ticket = "" },
    } },
    .{ .ver = "0.28.601", .summary = "Hax has its own terminal identity", .ticket = "", .items = &.{
        .{ .text = "Hax sessions now keep a distinct agent ID across tmux pane detection, local process and title detection, watcher notifications, diagnostics, and capacity admission.", .ticket = "" },
        .{ .text = "The sidebar uses Hax's official orange terminal chevron and cyan cursor mark instead of falling through to the Claude icon.", .ticket = "" },
    } },
    .{ .ver = "0.28.600", .summary = "Claude telemetry reconnect skips live accounts", .ticket = "", .items = &.{
        .{ .text = "Reconnect now accepts a usable refresh token and exact live or retrying telemetry state instead of reopening OAuth for generic provider errors or an expired access token.", .ticket = "" },
        .{ .text = "Each queued Claude profile is checked again before login, missing first-run rows are safe, and the visible wizard prefers Windows Terminal with Ctrl+Shift+V for OAuth-code paste.", .ticket = "" },
    } },
    .{ .ver = "0.28.599", .summary = "Weekly AI usage shows its real reset", .ticket = "", .items = &.{
        .{ .text = "Claude and Codex rows now pair the selected weekly percentage with that exact quota's provider reset timestamp, including Codex accounts that expose more than one weekly bucket.", .ticket = "" },
        .{ .text = "The weekly limit and reset lead each row. Five-hour usage, its reset, and Claude Fable usage remain on a secondary line when the configured row count leaves room.", .ticket = "" },
    } },
    .{ .ver = "0.28.598", .summary = "Headless agents cannot borrow another session's browser", .ticket = "", .items = &.{
        .{ .text = "A headless HT Bug Fixer had neither TMUX nor ZSB_SESSION, but the VPS wrapper asked tmux for an unscoped current session and received the visible HT Agent Manager session.", .ticket = "" },
        .{ .text = "Outside tmux, browser commands now require an explicit ZSB_SESSION and fail closed when it is absent. Inside tmux, only the live tmux name is sent.", .ticket = "" },
        .{ .text = "The Windows resolver also treats the first session token as authoritative, so a stale zss fallback cannot select a pane after shell IDs are reassigned on restart.", .ticket = "" },
        .{ .text = "Today's AI now renders the account labels and row count from the live telemetry snapshot, so removed Kimi and Project subscriptions disappear and the new Secondary Claude account is shown.", .ticket = "" },
    } },
    .{ .ver = "0.28.597", .summary = "Chrome panes no longer close themselves after binding", .ticket = "", .items = &.{
        .{ .text = "The live DEV trace proved the Chrome HWND disappeared without another Alt+A event and was relaunched exactly 1.5 seconds later by browser health recovery.", .ticket = "" },
        .{ .text = "Root cause: every successful bind ran the Edge theme mismatch command; Chrome omitted the command-line unpacked theme from management results, so the extension deliberately removed the new window on every cycle.", .ticket = "" },
        .{ .text = "Browser launch already loads the selected theme package. Binding now only protects and records the window; actual app or Windows theme changes retain the deliberate isolated-profile restart path.", .ticket = "" },
    } },
    .{ .ver = "0.28.596", .summary = "A delayed second Alt+A cycle cannot close a fresh Chrome pane", .ticket = "", .items = &.{
        .{ .text = "The v0.28.595 physical DEV trace recorded two complete kernel-timestamped Alt+A cycles 3.344 seconds apart: the first opened and docked Chrome, and the second legitimately reached the toggle handler and closed it.", .ticket = "" },
        .{ .text = "A physical shortcut open now owns a ten-second close guard for that exact shell, so delayed keyboard/input-stack cycles cannot undo the launch after the ordinary debounce window.", .ticket = "" },
        .{ .text = "Ctrl+K and tab-context browser actions remain immediate close paths, and Alt+A resumes normal close behavior after the guard expires.", .ticket = "" },
    } },
    .{ .ver = "0.28.595", .summary = "Alt+A cannot cancel the Chrome launch it just started", .ticket = "", .items = &.{
        .{ .text = "Live v0.28.594 still received a second browser-toggle command and destroyed Chrome's real top-level window, proving hook callback-time debounce was not the final boundary.", .ticket = "" },
        .{ .text = "The hook and WndProc now deduplicate by KBDLLHOOKSTRUCT.time, the kernel timestamp from the original key event, so Chrome launch stalls cannot age a 650 ms duplicate into a seemingly intentional close.", .ticket = "" },
        .{ .text = "Physical Alt+A/Alt+B close requests are also ignored while that pane's launch is pending; Ctrl+K and context-menu browser actions remain immediate.", .ticket = "" },
        .{ .text = "Native settle positioning remains idempotent, preventing Chrome compositor flashes from repeated no-op SetWindowPos calls.", .ticket = "" },
    } },
    .{ .ver = "0.28.594", .summary = "Alt+A ignores a complete duplicate key cycle", .ticket = "", .items = &.{
        .{ .text = "Live v0.28.593 evidence showed Chrome's real top-level window being destroyed immediately after launch while its dedicated worker remained alive: browser state had toggled back off.", .ticket = "" },
        .{ .text = "The earlier latch blocked only repeated keydowns before key-up. Alt+A and Alt+B now also reject a second complete key-up/key-down cycle within 1.5 seconds, while later intentional closes still work.", .ticket = "" },
        .{ .text = "Live DEV then exposed steady HWND geometry with visible Chrome compositor flashing. Native settle passes now skip SetWindowPos when Chrome already occupies the exact dock rectangle and move it only after a real bounds change.", .ticket = "" },
        .{ .text = "The debounce applies only to the physical Alt shortcut; Ctrl+K and tab-context browser actions remain immediate.", .ticket = "" },
    } },
    .{ .ver = "0.28.593", .summary = "Dedicated Chrome panes finish docking instead of staying off-screen", .ticket = "", .items = &.{
        .{ .text = "Live v0.28.592 evidence showed the Chrome HWND alive, owned, visible and bridge-bound but permanently parked at -32000,-32000 after Alt+A.", .ticket = "" },
        .{ .text = "Chrome may temporarily foreground its nonce beacon; adoption now carries the original multiprompt foreground authority through that exact beacon and reclaims the app frame after hiding it.", .ticket = "" },
        .{ .text = "Background agent launches remain unable to raise a pane, while the Alt+A repeat-key latch from v0.28.592 remains as defense in depth.", .ticket = "" },
    } },
    .{ .ver = "0.28.592", .summary = "Alt+A opens Chrome once and leaves it open", .ticket = "", .items = &.{
        .{ .text = "Alt+A and its Alt+B compatibility alias now post one browser-pane toggle per physical key press instead of toggling again for Windows key-repeat events.", .ticket = "" },
        .{ .text = "The latch releases on the real A/B key-up and resets whenever the global hook is reinstalled, so a slow first Chrome launch cannot become an immediate close and no stale press survives hibernation recovery.", .ticket = "" },
        .{ .text = "Dedicated Chrome remains signed into its separate profile; ordinary Edge and dedicated Chrome keep their deliberately separate extension identities and native-command pipes.", .ticket = "" },
    } },
    .{ .ver = "0.28.591", .summary = "Every browser pane can globally switch between dedicated Edge and Chrome", .ticket = "", .items = &.{
        .{ .text = "Ctrl+K now switches the global browser engine between an isolated Edge profile and an equally isolated Chrome profile.", .ticket = "" },
        .{ .text = "The switch closes every old-engine pane, preserves each tab's URL and enabled state, then relaunches the active pane through the selected browser's bridge; inactive panes follow when opened.", .ticket = "" },
        .{ .text = "Chrome receives its own native-messaging registration, bridge focus/navigation/screenshot commands, bundled theme, and %LOCALAPPDATA%\\ZigShell\\ChromeUserData cookies and logins.", .ticket = "" },
    } },
    .{ .ver = "0.28.590", .summary = "Shielded browser tabs never jump outside", .ticket = "", .items = &.{
        .{ .text = "The dedicated Edge profile is now the complete containment boundary: every tab created in a protected pane stays in that exact profile window without provenance quarantine, muting, or ejection.", .ticket = "" },
        .{ .text = "Ordinary links, target=_blank popups, bookmarks, Vercel deployment redirects, and legacy same-origin notification targets all remain inside; Windows, PWA, and normal Edge launches stay isolated by the separate user-data process.", .ticket = "" },
    } },
    .{ .ver = "0.28.589", .summary = "Repeat screenshots use one path and snippet typing lands", .ticket = "", .items = &.{
        .{ .text = "Every browser screenshot now captures the current viewport through Page.captureScreenshot, regardless of browser or shell focus; moving or scrolling the page and pressing the action again takes the next viewport through the same path.", .ticket = "" },
        .{ .text = "Create Snippet now cancels stale shell refocus, transfers the foreground input queue to its native name editor, and bypasses app-wide shortcut capture while either editor owns typing.", .ticket = "" },
    } },
    .{ .ver = "0.28.588", .summary = "Shell link clicks open in the foreground", .ticket = "", .items = &.{
        .{ .text = "A physical Ctrl+click on a Bash or console URL now creates and activates the fresh tab in that session's docked browser pane.", .ticket = "" },
        .{ .text = "Keyboard focus follows the explicit click into native Edge or WebView2, matching the existing Alt+W user-navigation behavior.", .ticket = "" },
        .{ .text = "Agent-driven multiprompt-browser and zsb navigation remains append-only and background-safe.", .ticket = "" },
    } },
    .{ .ver = "0.28.587", .summary = "System theme self-corrects after missed Windows broadcasts", .ticket = "", .items = &.{
        .{ .text = "System mode now polls AppsUseLightTheme once per second, repairing missed Windows appearance broadcasts without user action.", .ticket = "" },
        .{ .text = "WM_SETTINGCHANGE and WM_THEMECHANGED remain the immediate path; the fallback does no registry work for fixed themes.", .ticket = "" },
        .{ .text = "A detected change still reskins the app, consoles, masks, and isolated Edge profile as one operation.", .ticket = "" },
    } },
    .{ .ver = "0.28.586", .summary = "System theme follows Windows across app and browser", .ticket = "", .items = &.{
        .{ .text = "Ctrl+K Themes now includes System, which persists as an automatic preference instead of collapsing to a fixed Light or Dark selection.", .ticket = "" },
        .{ .text = "Windows appearance notifications immediately reskin multiprompt, every live console, title bar, masks, and the isolated Edge profile to the matching Light or Dark palette.", .ticket = "" },
        .{ .text = "Fixed theme choices remain unchanged, and normal Edge plus website content stay outside multiprompt theme control.", .ticket = "" },
    } },
    .{ .ver = "0.28.585", .summary = "isolated Edge chrome follows the multiprompt theme", .ticket = "", .items = &.{
        .{ .text = "Every multiprompt theme now has a bundled Edge-chrome palette loaded only in the dedicated pane profile; changing themes restarts that profile and the pane self-heals with the selected palette.", .ticket = "" },
        .{ .text = "The Light browser surround now inherits the neutral app background instead of the old hard-coded peach-orange mask.", .ticket = "" },
        .{ .text = "Website content remains site-controlled; theme synchronization changes Edge tabs, toolbar, bookmarks, and new-tab chrome without touching normal Edge.", .ticket = "" },
    } },
    .{ .ver = "0.28.584", .summary = "Enter stops an active dictation recording", .ticket = "", .items = &.{
        .{ .text = "Ctrl+Shift+Space remains the only way to start dictation; while recording, bare Enter is now a stop-only alias and is consumed before it can submit shell input.", .ticket = "" },
        .{ .text = "Repeated Enter keydown events collapse into one stop request, while Enter behaves normally whenever dictation is not recording.", .ticket = "" },
    } },
    .{ .ver = "0.28.583", .summary = "dictation is delivered and verified inside SSH/tmux", .ticket = "", .items = &.{
        .{ .text = "Shell dictation now targets the owning console with VK_PACKET Unicode key records instead of emitting a Ctrl+V gesture that OpenSSH/tmux could ignore.", .ticket = "" },
        .{ .text = "Multiprompt reports success only after the transcript newly appears in the console's in-memory viewport; an unconfirmed result remains on the clipboard and is reported honestly.", .ticket = "" },
        .{ .text = "OpenWiki now records every dictation intervention and the representative environment each attempt did or did not prove.", .ticket = "" },
    } },
    .{ .ver = "0.28.582", .summary = "dragged bookmarks survive harmless redirect normalization", .ticket = "", .items = &.{
        .{ .text = "A bookmark dragged into a multiprompt browser now stays docked when the site redirects only by adding or removing its trailing slash.", .ticket = "" },
        .{ .text = "The exception still requires the exact pane's physical drag token and a matching saved bookmark; redirects without both continue to leave the protected pane.", .ticket = "" },
    } },
    .{ .ver = "0.28.581", .summary = "isolated browser commands cannot cross into ordinary Edge", .ticket = "", .items = &.{
        .{ .text = "Multiprompt's dedicated Edge profile now loads its own extension identity and uses a private native command channel.", .ticket = "" },
        .{ .text = "Ordinary Edge keeps a separate compatibility channel, so it cannot consume pane protection, navigation, or inspection commands.", .ticket = "" },
    } },
    .{ .ver = "0.28.580", .summary = "browser panes are isolated from Windows and PWA launches", .ticket = "", .items = &.{
        .{ .text = "Native Edge panes now run in a dedicated multiprompt user-data directory, so normal Edge and PWA notification service workers cannot enumerate or focus protected pane clients.", .ticket = "" },
        .{ .text = "The isolated browser remains full Edge with tabs, omnibox, DevTools, and installable extensions; the multiprompt bridge extension is loaded automatically and WebView2 remains a separate on-demand mode.", .ticket = "" },
        .{ .text = "Residual outside-link and notification fallbacks reuse one explicitly tracked regular window instead of creating a new Edge window for every link.", .ticket = "" },
    } },
    .{ .ver = "0.28.579", .summary = "Other is always available as the catch-all workspace", .ticket = "", .items = &.{
        .{ .text = "The Other workspace now survives restarts even when it has no open tabs.", .ticket = "" },
        .{ .text = "Older sessions that lost Other are repaired automatically, and a new single-window setup starts with Other as its first workspace.", .ticket = "" },
    } },
    .{ .ver = "0.28.578", .summary = "Dictation uses the verified conhost paste gesture", .ticket = "", .items = &.{
        .{ .text = "Live diagnosis proved Deepgram returned a non-empty transcript and the clipboard retained it; v0.28.577 failed specifically because Shift+Insert entered nothing in the embedded classic console.", .ticket = "" },
        .{ .text = "Shell dictation now sends native Ctrl+V through the existing one-shot hook bypass after focus and modifier verification; an isolated real ConsoleWindowClass test executed the pasted command successfully.", .ticket = "" },
        .{ .text = "A content-free dictation audit records audio length, transcript length, target, and paste stage so future failures identify the exact boundary without exposing spoken text or credentials.", .ticket = "" },
    } },
    .{ .ver = "0.28.577", .summary = "Waiting and Archived are separate destinations", .ticket = "", .items = &.{
        .{ .text = "All Sessions now has permanent Waiting and Archived tabs: Waiting contains live Alt+E sessions, while Archived contains stopped, individually restorable records.", .ticket = "" },
        .{ .text = "Alt+X is now named Archive Session throughout the current UI; the old dissolve search terms remain accepted for compatibility.", .ticket = "" },
        .{ .text = "Inside All Sessions, w opens Waiting and a opens Archived; both destinations remain visible even when empty.", .ticket = "" },
    } },
    .{ .ver = "0.28.576", .summary = "Inbox reduction search and reliable dictation paste", .ticket = "", .items = &.{
        .{ .text = "Ctrl+F or / now opens a live reduction search inside Inbox across session names, workspaces, paths, agents, and preview text; Esc clears the query before closing Inbox.", .ticket = "" },
        .{ .text = "Dictation now waits for the stop chord to release, verifies shell focus, and invokes the console-native Shift+Insert paste path instead of reinjecting Ctrl+V through multiprompt's keyboard hook.", .ticket = "" },
    } },
    .{ .ver = "0.28.575", .summary = "Windows-level shortcuts pass through", .ticket = "", .items = &.{
        .{ .text = "Ctrl+Shift+A now passes through untouched instead of opening All Sessions; use Ctrl+K and choose Show All Sessions when needed.", .ticket = "" },
        .{ .text = "Ctrl+Shift+Alt+1/2/3 now pass through before overlays and can no longer be mistaken for multiprompt's Ctrl+Shift+1/2/3 spawn shortcuts.", .ticket = "" },
    } },
    .{ .ver = "0.28.574", .summary = "Locked sessions use a quiet outline icon", .ticket = "", .items = &.{
        .{ .text = "The sidebar lock is now a compact one-pixel outline with a distinct shackle and keyhole instead of the oversized solid-blue shape that resembled a shopping bag.", .ticket = "" },
        .{ .text = "Inactive locks use the sidebar's muted tone while the selected row uses its title color, keeping the protection visible without overpowering session names.", .ticket = "" },
    } },
    .{ .ver = "0.28.573", .summary = "Locked sessions cannot be closed accidentally", .ticket = "", .items = &.{
        .{ .text = "Ctrl+K and tab right-click now lock or unlock a session. Locked rows show a padlock and reject Ctrl+W, close, dissolve, end-tmux, group-close, workspace-close, and All Sessions teardown.", .ticket = "" },
        .{ .text = "LOCKED, PINNED, and RECENTS are separate persistent sections whose headings collapse on click; dragging a session between them changes its tier.", .ticket = "" },
        .{ .text = "Locked rows never reshuffle for activity, attention, or recency and remain manually reorderable by drag while automatic sorting continues elsewhere.", .ticket = "" },
    } },
    .{ .ver = "0.28.572", .summary = "Alt+Z undoes the last session archive", .ticket = "", .items = &.{
        .{ .text = "Alt+Z now restores the exact session most recently hidden with Alt+E or Inbox e, including its prior blue-dot state, from shell, Inbox, or docked-browser focus.", .ticket = "" },
        .{ .text = "Inbox bare z remains an alias, and the one-level undo slot is replaced only by a later successful archive.", .ticket = "" },
        .{ .text = "Destructive Alt+X dissolve and close actions remain deliberately outside undo.", .ticket = "" },
    } },
    .{ .ver = "0.28.571", .summary = "Dictation pastes the complete transcript", .ticket = "", .items = &.{
        .{ .text = "Dictation into SSH and tmux shells now uses the console's native paste path instead of synthetic zero-keycode input records that could leave only a blank.", .ticket = "" },
        .{ .text = "Provider-added whitespace is trimmed from the transcript edges while spaces inside spoken text remain unchanged.", .ticket = "" },
        .{ .text = "An all-whitespace transcription is reported as empty instead of being pasted as an invisible result.", .ticket = "" },
        .{ .text = "A newly refreshed Claude login now replaces the stale single-instance telemetry collector once, so the native card becomes live immediately.", .ticket = "" },
    } },
    .{ .ver = "0.28.570", .summary = "AI usage is native and cards-only", .ticket = "", .items = &.{
        .{ .text = "The Node.js localhost dashboard, browser report, account deep links, and tray companion are removed.", .ticket = "" },
        .{ .text = "One headless ReleaseSmall Zig collector writes a sanitized snapshot file that the native Combined and Today's AI cards read directly.", .ticket = "" },
        .{ .text = "Cached RETRY counters, daily goals, Claude token rotation and cooldowns, five-hour resets, Fable, and the visible reconnect flow remain intact.", .ticket = "" },
        .{ .text = "No usage process listens on localhost, and clicking any part of the sticky card only cycles the three native telemetry pages.", .ticket = "" },
    } },
    .{ .ver = "0.28.569", .summary = "Telemetry survives resume outages and provider cooldowns", .ticket = "", .items = &.{
        .{ .text = "Temporary DNS, network, and provider failures preserve the last good counters as RETRY instead of mislabeling every account STALE.", .ticket = "" },
        .{ .text = "A token-free provider cache survives dashboard and laptop restarts, so counters remain visible while connectivity recovers.", .ticket = "" },
        .{ .text = "Claude OAuth refreshes are serialized, honor Retry-After, and back off for at least fifteen minutes after HTTP 429 instead of hammering both profiles.", .ticket = "" },
        .{ .text = "STALE is now reserved for credentials that genuinely need the visible reconnect wizard.", .ticket = "" },
    } },
    .{ .ver = "0.28.568", .summary = "Claude telemetry self-refreshes and shows Fable", .ticket = "", .items = &.{
        .{ .text = "Claude usage accounts silently renew their isolated OAuth credentials before the eight-hour access token expires, including after hibernate or an overnight restart.", .ticket = "" },
        .{ .text = "Each Claude row now shows TOTAL, 5H, and FABLE usage from the provider's scoped quota data while retaining its reset countdown.", .ticket = "" },
        .{ .text = "Remote kimi-code panes are recognized as Kimi even when stale Claude resume metadata remains attached to the shell.", .ticket = "" },
        .{ .text = "Hibernate recovery restores global shortcuts, and the native rename dialog synchronizes one name across multiprompt, tmux, and the coding agent.", .ticket = "" },
    } },
    .{ .ver = "0.28.567", .summary = "Daily AI goals show overage above 100%", .ticket = "", .items = &.{
        .{ .text = "Today's percentage keeps counting after the assigned daily goal is complete, so using 1.25 times the target displays 125% instead of stopping at 100%.", .ticket = "" },
        .{ .text = "The rule is provider-independent and covers both Claude accounts, OpenAI, and Kimi from the same daily-goal calculation.", .ticket = "" },
        .{ .text = "The numeric label remains uncapped while the physical fill stops at the end of its track, preventing overage from drawing outside the account row.", .ticket = "" },
        .{ .text = "Ctrl+Shift+G cycles the sticky telemetry card through Combined, VPS, and Today's AI without using the Alt shortcut namespace.", .ticket = "" },
    } },
    .{ .ver = "0.28.566", .summary = "VPS health explains percentages and Critical limits", .ticket = "", .items = &.{
        .{ .text = "The VPS card replaces raw load-versus-core notation such as 26 / 18 with a normalized CPU load percentage such as 145%.", .ticket = "" },
        .{ .text = "Critical now names its live cause, including CPU load, CPU/RAM/disk wait, or low free RAM, beside the exact triggering limit.", .ticket = "" },
        .{ .text = "The card states that Critical starts at load 150%, wait 50%, or RAM free 8%, and clears after four checks below every Critical limit.", .ticket = "" },
    } },
    .{ .ver = "0.28.565", .summary = "Hidden sessions self-heal after restart", .ticket = "", .items = &.{
        .{ .text = "Alt+E filing is now durable completion provenance: a recognized hidden agent that is visibly idle for two consecutive polls returns with a blue dot even when restart erased its ACTIVE event.", .ticket = "" },
        .{ .text = "Working, muted, disconnected, foreground, unrecognized, and already-attention sessions are excluded; real DONE hooks and exact-ACTIVE idle recovery remain the faster paths.", .ticket = "" },
        .{ .text = "Diagnostics identify the recovery as DONE hidden-idle watchdog and expose its debounce streak for live verification.", .ticket = "" },
    } },
    .{ .ver = "0.28.564", .summary = "Ctrl+K repairs stale AI usage logins", .ticket = "", .items = &.{
        .{ .text = "Reconnect AI Usage Accounts checks the configured Claude identities and opens an interactive login only for accounts with expired credentials or authentication errors.", .ticket = "" },
        .{ .text = "Each email retains its own CLAUDE_CONFIG_DIR; logins run sequentially, verify the new credential expiry, and never display access or refresh tokens.", .ticket = "" },
        .{ .text = "After login, the routine refreshes the localhost telemetry report and labels each repaired identity LIVE or WAIT instead of requiring manual command-line setup.", .ticket = "" },
    } },
    .{ .ver = "0.28.563", .summary = "Finished sessions recover blue dots and Ctrl+K toggles back", .ticket = "", .items = &.{
        .{ .text = "A visible idle agent prompt after an exact-session ACTIVE now recovers a missing DONE; background sessions receive a durable blue dot instead of remaining hidden.", .ticket = "" },
        .{ .text = "F2, double-click, Inbox F2, and Rename Session synchronize one display name across multiprompt, the tmux window, and the coding agent without changing stable IDs.", .ticket = "" },
        .{ .text = "After switching sessions, empty Ctrl+K places the session just left first, so Ctrl+K then Enter toggles back while typed searches keep intent-first ranking.", .ticket = "" },
    } },
    .{ .ver = "0.28.562", .summary = "The usage backend no longer starts the tray companion", .ticket = "", .items = &.{
        .{ .text = "Multiprompt startup now launches only the localhost usage-data backend; it no longer reaches that backend through the companion's ordinary Start Menu action.", .ticket = "" },
        .{ .text = "The installed companion stays stopped until Ctrl+K, the Start Menu, or an explicit StartNow request launches it.", .ticket = "" },
        .{ .text = "Windows Startup remains disabled by default, while the five-hour reset countdowns from v0.28.560 remain active.", .ticket = "" },
    } },
    .{ .ver = "0.28.561", .summary = "The AI usage companion is optional", .ticket = "", .items = &.{
        .{ .text = "Installing the tray companion now keeps it available from Ctrl+K and the Start Menu without launching it or enabling Windows Startup.", .ticket = "" },
        .{ .text = "Explicit StartNow and EnableStartup installer switches retain both opt-in behaviors for later use.", .ticket = "" },
        .{ .text = "The sticky AI card also shows the live provider-reported reset countdown for every genuine five-hour quota.", .ticket = "" },
    } },
    .{ .ver = "0.28.560", .summary = "Five-hour usage shows its live reset countdown", .ticket = "", .items = &.{
        .{ .text = "Every real 300-minute provider quota now shows how long remains until its reported reset beside the five-hour usage percentage.", .ticket = "" },
        .{ .text = "Both Claude subscriptions and Kimi expose this today; OpenAI will use the same display automatically whenever it publishes a five-hour window.", .ticket = "" },
        .{ .text = "Accounts without a provider-reported five-hour reset keep the dash instead of receiving an inferred deadline.", .ticket = "" },
    } },
    .{ .ver = "0.28.557", .summary = "AI cards show only today's progress and real quota windows", .ticket = "", .items = &.{
        .{ .text = "Every account row now contains one normalized progress bar for today's assigned usage, followed only by total and five-hour quota usage.", .ticket = "" },
        .{ .text = "Kimi's real five-hour quota is detected from its 300-minute window; providers that do not publish one show a dash instead of an invented value.", .ticket = "" },
        .{ .text = "Point counts, remaining-goal copy, reset details, and redundant card summaries are removed from the sticky AI view.", .ticket = "" },
    } },
    .{ .ver = "0.28.556", .summary = "AI cards show progress toward today's normalized goal", .ticket = "", .items = &.{
        .{ .text = "Each account now has a daily quota slice that equals 100%; the card shows completion of that slice and the exact quota points still needed by midnight.", .ticket = "" },
        .{ .text = "The local tracker saves a sanitized per-account day baseline and divides remaining quota by remaining calendar days, so missed usage automatically increases tomorrow's goal.", .ticket = "" },
        .{ .text = "Cumulative utilization and long-window pacing remain available in the localhost report, while the always-visible sidebar answers only what to finish today.", .ticket = "" },
    } },
    .{ .ver = "0.28.555", .summary = "The sticky card remembers its page and links every usage report", .ticket = "", .items = &.{
        .{ .text = "Combined, VPS Load, and AI Pace now persist as global UI state; restarting multiprompt restores the page that was visible before shutdown.", .ticket = "" },
        .{ .text = "The preference is loaded before the first window is created, so restart does not flash or reset to Overview.", .ticket = "" },
        .{ .text = "Every AI account row has a native report icon that opens the matching account in the localhost usage dashboard inside the active browser pane.", .ticket = "" },
    } },
    .{ .ver = "0.28.554", .summary = "AI detail lines are no longer clipped", .ticket = "", .items = &.{
        .{ .text = "Live rendering exposed an eight-pixel detail box beneath each pace bar; the compact font still lost its lower edge there.", .ticket = "" },
        .{ .text = "Email, state, bar, and detail geometry is tightened to give the final line thirteen pixels of vertical room.", .ticket = "" },
        .{ .text = "Daily copy is shortened to percent used and percent today so every account row remains legible at the normal sidebar width.", .ticket = "" },
    } },
    .{ .ver = "0.28.553", .summary = "The sticky card always switches when clicked", .ticket = "", .items = &.{
        .{ .text = "A normal click anywhere on Combined, VPS, or AI Pace now advances to the next page; AI no longer hides a large open-coach click target.", .ticket = "" },
        .{ .text = "The card uses a dedicated font one logical pixel smaller than ordinary sidebar subtitles so emails, states, and daily targets fit cleanly.", .ticket = "" },
        .{ .text = "The full AI Usage Coach remains available from Ctrl+K without overloading the carousel's click behavior.", .ticket = "" },
    } },
    .{ .ver = "0.28.552", .summary = "Workspaces no longer have a four-agent ceiling", .ticket = "", .items = &.{
        .{ .text = "Removed the fixed four-busy-agent admission limit from every workspace.", .ticket = "" },
        .{ .text = "Workspace activity remains diagnostic only and can no longer paint an otherwise healthy workspace Red or block a new agent.", .ticket = "" },
        .{ .text = "Host-wide protection based on normalized load, available RAM, and Linux PSI remains active; swap remains visible telemetry.", .ticket = "" },
    } },
    .{ .ver = "0.28.551", .summary = "Claude accounts use their real email names", .ticket = "", .items = &.{
        .{ .text = "The tracker now identifies the primary subscription as owner@example.com and the expiring subscription as secondary@example.com.", .ticket = "" },
        .{ .text = "Email addresses receive their own line above pace state, bar, and target so account identity never collides with status text.", .ticket = "" },
        .{ .text = "The shared sticky carousel grows to 222 logical pixels while Combined and VPS retain the same fixed viewport boundary.", .ticket = "" },
    } },
    .{ .ver = "0.28.550", .summary = "Every AI account gets a readable slot", .ticket = "", .items = &.{
        .{ .text = "The equal-height sticky carousel grows from 116 to 176 logical pixels so four AI accounts no longer compete for cramped rows.", .ticket = "" },
        .{ .text = "Each account now owns a separated slot with a colored accent, bold label, right-aligned pace state, full-width bar, and dedicated detail line.", .ticket = "" },
        .{ .text = "Healthy rows show current usage and today's remaining use-up target; stale rows give a direct sign-in instruction.", .ticket = "" },
    } },
    .{ .ver = "0.28.549", .summary = "AI Pace separates both Claude accounts", .ticket = "", .items = &.{
        .{ .text = "The sticky AI page now shows Claude 1, Claude 2, OpenAI, and Kimi as four independent rows without growing the card.", .ticket = "" },
        .{ .text = "A stale account stays visible as Stale / reauthenticate instead of disappearing inside a pooled provider total.", .ticket = "" },
        .{ .text = "The full coach keeps the combined equal-weight Claude planning goal while the always-visible sidebar exposes each account's real state.", .ticket = "" },
    } },
    .{ .ver = "0.28.548", .summary = "Sticky sidebar carousel keeps capacity visible", .ticket = "", .items = &.{
        .{ .text = "One fixed-height card stays pinned to the bottom of the sidebar while sessions and New Tab scroll underneath it.", .ticket = "" },
        .{ .text = "The mouse wheel over the card switches between Combined, VPS Load, and AI Pace pages; every page has the same height.", .ticket = "" },
        .{ .text = "Combined reports one overall Good, Push, Watch, or Critical state from VPS pressure and AI use-up pace.", .ticket = "" },
        .{ .text = "AI Pace compares actual long-window use with the expected marker for Anthropic, OpenAI, and Kimi and keeps each provider's use-today target visible.", .ticket = "" },
    } },
    .{ .ver = "0.28.547", .summary = "AI Usage Coach turns subscriptions into daily goals", .ticket = "", .items = &.{
        .{ .text = "Ctrl+K AI Usage Coach opens a goal-focused localhost view inside the active multiprompt browser pane, with combined Claude, GPT/Codex, and Kimi targets.", .ticket = "" },
        .{ .text = "Both Claude subscriptions form one equal-weight capacity pool; the coach still says which Claude account should be used next.", .ticket = "" },
        .{ .text = "The Project Claude subscription has a hard 8 August use-by date, so its target accelerates whenever cancellation arrives before the next quota reset.", .ticket = "" },
        .{ .text = "The coach and tray report quota percentages because consumer subscriptions do not expose a trustworthy token-count allowance.", .ticket = "" },
    } },
    .{ .ver = "0.28.546", .summary = "Usage popup opens at its tray icon and dismisses normally", .ticket = "", .items = &.{
        .{ .text = "Programmatic Ctrl+K opens now anchor the usage menu to the real notification-area icon instead of wherever the mouse happened to be.", .ticket = "" },
        .{ .text = "Foreground permission is handed to the existing companion instance before it opens the native menu, restoring normal outside-click and Escape dismissal.", .ticket = "" },
        .{ .text = "Bottom, top, left, and right taskbar layouts select the matching popup edge; multiprompt does not run a shell-refocus timer while the menu is open.", .ticket = "" },
    } },
    .{ .ver = "0.28.545", .summary = "AI usage is one Ctrl+K away", .ticket = "", .items = &.{
        .{ .text = "Ctrl+K now includes AI Usage Companion, which opens the lightweight tray popup for both Claude accounts, Codex, and Kimi.", .ticket = "" },
        .{ .text = "The companion accepts an explicit show request, so the same action starts it and opens the popup even when the tray process was not already running.", .ticket = "" },
        .{ .text = "One low-footprint Zig tray process replaces the three separate usage-monitor icons while the local dashboard remains available for detail.", .ticket = "" },
    } },
    .{ .ver = "0.28.544", .summary = "Dragged bookmarks stay in the docked browser", .ticket = "", .items = &.{
        .{ .text = "A physical drag ending over a docked Edge pane now creates a short-lived native routing token for that exact browser window.", .ticket = "" },
        .{ .text = "The token authorizes only an exact saved-bookmark URL with Edge's unqualified link commit, so ordinary outside launches remain fail-closed.", .ticket = "" },
        .{ .text = "The routing audit distinguishes native bookmark drops from ordinary bookmark clicks; native bridge and Edge extension are 1.0.35.", .ticket = "" },
    } },
    .{ .ver = "0.28.543", .summary = "Edge favorites stay in the docked browser", .ticket = "", .items = &.{
        .{ .text = "Edge favorites reported as plain link commits now stay docked when the exact URL is saved and the protected pane was already steadily focused before tab creation.", .ticket = "" },
        .{ .text = "Bookmark membership or focus alone remains insufficient, so outside and PWA launches continue to move into regular Edge.", .ticket = "" },
        .{ .text = "Routing audits now preserve bookmark-match and pre-create focus evidence; native bridge and Edge extension are 1.0.34.", .ticket = "" },
    } },
    .{ .ver = "0.28.542", .summary = "Sidebar shows the active VPS at a glance", .ticket = "", .items = &.{
        .{ .text = "A VPS status card above New Tab follows the active remote host, or the workspace's dominant host when a local shell is selected.", .ticket = "" },
        .{ .text = "The card shows Green/Amber/Red state, load versus cores, used versus total RAM, resident and working agents, and Claude/Codex/Other session counts.", .ticket = "" },
        .{ .text = "Counts come from the existing 15-second tmux inventory; Other includes Pi and Kimi, while plain shells are excluded.", .ticket = "" },
    } },
    .{ .ver = "0.28.541", .summary = "All Sessions shows per-session and workspace RAM", .ticket = "", .items = &.{
        .{ .text = "Every All Sessions row now has a dedicated right-aligned RAM value while open, hidden, reminder, unattached, and dissolved status labels keep their original meaning.", .ticket = "" },
        .{ .text = "Each workspace split shows the deduplicated RAM total of its live tmux sessions; the All split totals both VPS inventories.", .ticket = "" },
        .{ .text = "RAM reuses the existing 15-second tmux inventory, so the overview adds no remote polling or process-walk overhead.", .ticket = "" },
    } },
    .{ .ver = "0.28.540", .summary = "Monitor moves are one verified window transaction", .ticket = "", .items = &.{
        .{ .text = "Display selection now follows actual spatial geometry, including negative coordinates, gaps, vertical stacks, mixed sizes, portrait screens, and more than two monitors.", .ticket = "" },
        .{ .text = "Dragging, Win+Shift+Arrow, snap hops, DPI changes, and dock/undock events share one frame/console/Edge transition instead of racing independent move timers.", .ticket = "" },
        .{ .text = "The browser pane and masks stay parked until frame and child read-back succeeds; every attempt is recorded in monitor-move-audit.tsv.", .ticket = "" },
    } },
    .{ .ver = "0.28.539", .summary = "Other workspace Alt+T opens the projects tmux shell", .ticket = "", .items = &.{
        .{ .text = "A workspace-scoped default now outranks repository inference, so mixed or historical sessions cannot redirect Alt+T into an unrelated project.", .ticket = "" },
        .{ .text = "The Other workspace default attaches or creates Host 2's projects tmux session in ~/projects without launching Claude.", .ticket = "" },
        .{ .text = "Plain tmux shell defaults remain available under VPS capacity pressure because they do not create a new agent workload.", .ticket = "" },
    } },
    .{ .ver = "0.28.538", .summary = "VPS capacity guardian prevents overload", .ticket = "", .items = &.{
        .{ .text = "Host 1 and Host 2 now publish normalized load, available memory, swap, Linux CPU/memory/I/O pressure, resident agents, and remote RAM every 15 seconds.", .ticket = "" },
        .{ .text = "New Claude, Codex, custom-agent, and dissolved-session resurrection paths share one host-first admission gate; Red/Critical pressure and host/workspace busy-agent limits block new work while existing tmux attach, inspect, and cleanup remain available.", .ticket = "" },
        .{ .text = "Remote thread headers show persistent host capacity, workspace pills gain Amber/Red pressure dots, diagnostics expose both hosts, and decisions are appended to capacity-audit.tsv.", .ticket = "" },
        .{ .text = "All Sessions marks detached recognized agents idle for at least 72 hours as advisory stale? candidates with RAM; multiprompt never kills them automatically.", .ticket = "" },
    } },
    .{ .ver = "0.28.537", .summary = "Docked browser text selection uses native mouse input", .ticket = "", .items = &.{
        .{ .text = "Clicks inside the docked Edge pane are no longer swallowed and replayed continuously, so placing a caret, dragging a selection, and double-clicking follow native Edge behavior.", .ticket = "" },
        .{ .text = "The stale-Alt download safeguard is now a one-shot repair armed only by an Alt transition involving the pane; it still protects the next click without rewriting unrelated input.", .ticket = "" },
    } },
    .{ .ver = "0.28.536", .summary = "Bookmarks wait for commit provenance; Edge menus keep focus", .ticket = "", .items = &.{
        .{ .text = "Bookmark-bar, typed, keyword, and address-bar navigations now wait for Edge's committed transition before quarantine can eject them.", .ticket = "" },
        .{ .text = "Unknown outside launches remain muted and fail closed at the overall timeout, with transition qualifiers and finalization reasons preserved in the routing audit.", .ticket = "" },
        .{ .text = "Verified extension and three-dot dropdowns now own pane focus without browser masks rising over them; native bridge and Edge extension are 1.0.33.", .ticket = "" },
    } },
    .{ .ver = "0.28.535", .summary = "Sessions can be dragged between Pinned and Recents", .ticket = "", .items = &.{
        .{ .text = "Drag a session onto the PINNED heading, any pinned session, or a pinned group header to pin it with the mouse.", .ticket = "" },
        .{ .text = "Drag a pinned session onto the RECENTS heading, any recent session, or a recent group header to unpin it.", .ticket = "" },
        .{ .text = "Inbox auto-sorting stays active when crossing sections, while Manual order still supports ordinary row and group placement.", .ticket = "" },
    } },
    .{ .ver = "0.28.534", .summary = "Outside links require verified page provenance", .ticket = "", .items = &.{
        .{ .text = "Outside links can no longer stay in a multiprompt browser merely because Edge attached an opener tab from that pane.", .ticket = "" },
        .{ .text = "Real links opened by a page still stay docked through Edge's verified source-to-target navigation event.", .ticket = "" },
        .{ .text = "The routing audit now records opener-tab evidence, and the new repository wiki documents every containment attempt; reload Edge extension 1.0.32 to activate the fix.", .ticket = "" },
    } },
    .{ .ver = "0.28.533", .summary = "Ctrl+T belongs to the browser; Alt+T opens a shell", .ticket = "", .items = &.{
        .{ .text = "Ctrl+T now reaches a focused docked browser normally, so it opens a new browser tab instead of starting another multiprompt shell.", .ticket = "" },
        .{ .text = "Alt+T is the universal new-Claude-session shortcut from shells, Inbox, All Sessions, and browser focus, preserving workspace VPS/repository inference.", .ticket = "" },
        .{ .text = "Ctrl+Shift+T still reopens the last closed multiprompt tab, and Ctrl+Alt remains untouched for AltGr.", .ticket = "" },
    } },
    .{ .ver = "0.28.532", .summary = "Ctrl+K ranks intent before decaying usage", .ticket = "", .items = &.{
        .{ .text = "Typed Ctrl+K searches now rank exact labels, label prefixes, and word prefixes before learned usage, so an old favorite cannot outrank what you explicitly searched for.", .ticket = "" },
        .{ .text = "Workspace-scoped custom commands win relevant ties, while destructive actions stay below ordinary commands when Ctrl+K opens with an empty query.", .ticket = "" },
        .{ .text = "Usage is now frecency: recent actions get bounded time buckets and lifetime frequency is logarithmic and capped, preventing old high counts from permanently locking the list.", .ticket = "" },
    } },
    .{ .ver = "0.28.531", .summary = "Ctrl+T follows the workspace repo and Ctrl+K learns usage", .ticket = "", .items = &.{
        .{ .text = "Ctrl+T now infers the active workspace's VPS and repository from its live sessions, then starts Claude there with tnn; renaming a workspace no longer breaks the shortcut.", .ticket = "" },
        .{ .text = "Ctrl+T has the same new-session meaning from shells, Inbox, All Sessions, and docked-browser focus, while commands.json remains the fallback for workspaces with no inferred remote repo.", .ticket = "" },
        .{ .text = "Ctrl+K persists command-use counts, sorts frequent actions first with recency as the tie-break, and uses normalized spawn names without decorative plus prefixes.", .ticket = "" },
    } },
    .{ .ver = "0.28.530", .summary = "Outside links fail closed with a durable audit", .ticket = "", .items = &.{
        .{ .text = "Concurrent browser-pane registrations now share one merge-safe registry load, so restoring many sessions cannot erase a live protected Edge window.", .ticket = "" },
        .{ .text = "Every unattributed tab stays muted while its origin is checked; a failed outside-window move remains muted instead of playing invisibly in a hidden session.", .ticket = "" },
        .{ .text = "The bridge records protection, authorization, ejection, focus, URL, window, tab, and shell details in a persistent routing audit available through multiprompt-browser routing-audit.", .ticket = "" },
    } },
    .{ .ver = "0.28.529", .summary = "Searched pickers select their first match", .ticket = "", .items = &.{
        .{ .text = "Typing in snippets, themes, reminders, session overview, tab actions, or workspaces now selects the first filtered action instead of Back.", .ticket = "" },
        .{ .text = "Enter immediately activates the best visible match; Back remains selected only when the search has no matching action.", .ticket = "" },
        .{ .text = "Fixed-order pickers keep their explicit selection, and All Sessions search still selects its direct first result.", .ticket = "" },
    } },
    .{ .ver = "0.28.528", .summary = "Notification clicks survive extension worker wake", .ticket = "", .items = &.{
        .{ .text = "A Windows notification click is no longer discarded while Edge is still resolving whether the selected browser client belongs to a protected multiprompt pane.", .ticket = "" },
        .{ .text = "The validated same-origin target waits for that answer and opens in regular Edge as soon as the pane is confirmed.", .ticket = "" },
        .{ .text = "Already-open tabs replace the previous guard after extension reload. Native bridge and Edge extension are 1.0.30.", .ticket = "" },
    } },
    .{ .ver = "0.28.527", .summary = "Restored shells redraw at their full height", .ticket = "", .items = &.{
        .{ .text = "Growing a restored bottom-aligned console now asks the foreground tmux TUI to repaint after the new PTY rows settle.", .ticket = "" },
        .{ .text = "Claude no longer keeps its old approximately 40-row render at the top of a new approximately 60-row pane with a blank lower half.", .ticket = "" },
        .{ .text = "Shrink operations and consoles deliberately scrolled away from the bottom never trigger the redraw path.", .ticket = "" },
    } },
    .{ .ver = "0.28.526", .summary = "Edge's three-dot menu is clickable again", .ticket = "", .items = &.{
        .{ .text = "The invisible native-caption hit shield no longer extends left across Edge's Settings and more button.", .ticket = "" },
        .{ .text = "The shield still covers the full minimize, maximize, and close hit area, including its taller lower edge.", .ticket = "" },
    } },
    .{ .ver = "0.28.525", .summary = "Hidden, unattached, and killed sessions restore separately", .ticket = "", .items = &.{
        .{ .text = "Ctrl+K now has three explicit actions: Unarchive Hidden (Alt+E), Unarchive Unattached (Ctrl+W), and Unarchive Killed (Alt+X).", .ticket = "" },
        .{ .text = "Hidden restore only reveals live tabs in the active workspace; unattached restore only reconnects existing remote tmux sessions and paces them one at a time.", .ticket = "" },
        .{ .text = "Killed restore opens a killed-only workspace view and still requires choosing one archive record, so Alt+X sessions can never bulk-launch.", .ticket = "" },
        .{ .text = "The incident recovery writer now preserves archive.json as an array; the 72 recovered killed records were shape-repaired and verified after restart.", .ticket = "" },
    } },
    .{ .ver = "0.28.524", .summary = "Workspace unarchive cannot resurrect dissolved sessions", .ticket = "", .items = &.{
        .{ .text = "Ctrl+K Unarchive Workspace Sessions now only clears the Inbox e / Alt+E filed-away flag on existing live tabs.", .ticket = "" },
        .{ .text = "Alt+X dissolved archive.json records remain purple and individually restorable; bulk unarchive can never create tmux sessions or launch Claude.", .ticket = "" },
        .{ .text = "The accidental v0.28.514-v0.28.523 bulk restore was reversed from persisted state and its generated remote tmux sessions were removed after the archive records were rebuilt.", .ticket = "" },
    } },
    .{ .ver = "0.28.523", .summary = "Remote blue dots keep their tunnel", .ticket = "", .items = &.{
        .{ .text = "Each VPS now has one dedicated reverse-SSH tunnel keeper instead of making every restored shell race for the same remote port.", .ticket = "" },
        .{ .text = "The keeper runs in its own kill-on-close job, retries automatically after disconnects, and cannot survive a graceful shell-detach restart as a stale port owner.", .ticket = "" },
        .{ .text = "Interactive SSH sessions no longer carry competing -R requests, so closing the accidental tunnel-owning tab cannot silently disable every later ACTIVE and DONE event.", .ticket = "" },
        .{ .text = "Shell diagnostics now report the local notify port, tunnel inbound port, and both keeper states for direct verification.", .ticket = "" },
    } },
    .{ .ver = "0.28.522", .summary = "Browser focus, Alt+W, and notification clicks complete", .ticket = "", .items = &.{
        .{ .text = "Alt+Q now waits for physical Alt release, performs a bounded cross-process foreground handoff, and retries until the native Edge pane actually owns foreground instead of assuming one SetForegroundWindow call succeeded.", .ticket = "" },
        .{ .text = "Alt+W selections create and activate a fresh pane tab, then transfer keyboard focus into that browser; agent navigation remains append-only and background-safe.", .ticket = "" },
        .{ .text = "Firebase notification clicks now cross the page-world boundary through a same-origin MAIN-world relay before the protected extension opens the exact target in regular Edge.", .ticket = "" },
        .{ .text = "Native bridge and Edge extension advance together to 1.0.29.", .ticket = "" },
    } },
    .{ .ver = "0.28.521", .summary = "Web-notification clicks open their exact target", .ticket = "", .items = &.{
        .{ .text = "Firebase's built-in notification handler focused the first same-origin browser client and posted a message instead of navigating; when that client was a protected multiprompt pane, clicking the toast only highlighted Edge.", .ticket = "" },
        .{ .text = "Protected panes now recognize the Firebase notification-click message and open its exact same-origin target in a visible regular Edge window, preserving the rule that OS/outside launches stay outside multiprompt.", .ticket = "" },
        .{ .text = "Existing tabs receive the updated idempotent content guard after an extension reload; native bridge and Edge extension advance together to 1.0.28.", .ticket = "" },
    } },
    .{ .ver = "0.28.520", .summary = "Docked-browser clicks cannot regress into HTML downloads", .ticket = "", .items = &.{
        .{ .text = "The v0.28.516 responsiveness cleanup accidentally deleted v0.28.512's native stale-Alt click guard while leaving its changelog claim in place; normal links could again arrive in Edge as Alt+click and download .htm files.", .ticket = "" },
        .{ .text = "The guard now lives on a dedicated low-level mouse-hook thread, identifies panes through their ZigShellPaneOwner property, preserves intentional physical Alt+click, and cannot stall the system pointer when multiprompt's UI thread is busy.", .ticket = "" },
    } },
    .{ .ver = "0.28.519", .summary = "Agent navigation can never overwrite browser tabs", .ticket = "", .items = &.{
        .{ .text = "Every multiprompt-browser and zsb navigate request now creates a fresh tab in that session's bound browser pane, even when the caller omits --new-tab or explicitly sends newTab=false.", .ticket = "" },
        .{ .text = "The policy is enforced centrally by the extension instead of depending on Claude.md, AGENTS.md, or agent compliance.", .ticket = "" },
        .{ .text = "Back, Forward, Reload, and normal in-page browsing retain their existing behavior; native bridge and Edge extension advance together to 1.0.27.", .ticket = "" },
    } },
    .{ .ver = "0.28.518", .summary = "Alt+W restores the URL picker", .ticket = "", .items = &.{
        .{ .text = "Alt+W once again opens and closes the URL picker from shell or docked-browser focus.", .ticket = "" },
        .{ .text = "Alt+O and Ctrl+O remain completely unbound by multiprompt.", .ticket = "" },
        .{ .text = "The v0.28.517 browser-boundary routing fix remains unchanged.", .ticket = "" },
    } },
    .{ .ver = "0.28.517", .summary = "Links obey browser boundaries; URL picker moves to Alt+O", .ticket = "", .items = &.{
        .{ .text = "External-browser and OS link launches can no longer enter a protected multiprompt pane merely because that pane had focus; only explicit page-target, same-pane opener, or multiprompt-issued provenance is trusted.", .ticket = "" },
        .{ .text = "Links opened by a page inside a multiprompt browser remain in that same protected browser window as a new tab, including target=_blank and rel=noopener targets.", .ticket = "" },
        .{ .text = "Alt+O is now the sole URL-picker shortcut from shell or docked-browser focus; the old Alt+W and Ctrl+O aliases are removed.", .ticket = "" },
        .{ .text = "Native bridge and Edge extension advance together to 1.0.26.", .ticket = "" },
    } },
    .{ .ver = "0.28.516", .summary = "Large workspaces switch smoothly; page links stay docked", .ticket = "", .items = &.{
        .{ .text = "Session switching no longer scans every inactive Edge pane or performs cross-process browser geometry reads; browser foreground events are coalesced and cannot re-enter the visibility layout pass.", .ticket = "" },
        .{ .text = "The system-wide mouse hook now exists only while Ctrl is held for terminal Ctrl-click URL routing, so a busy multiprompt UI cannot stutter the mouse across Windows.", .ticket = "" },
        .{ .text = "Links created by a page with target=_blank or window.open are identified through Chromium's explicit source-to-target navigation event and remain in that multiprompt pane, independent of focus timing or extension-worker restarts.", .ticket = "" },
        .{ .text = "Native bridge and Edge extension advance together to 1.0.25.", .ticket = "" },
    } },
    .{ .ver = "0.28.515", .summary = "Browser crashes cannot freeze or trap multiprompt", .ticket = "", .items = &.{
        .{ .text = "All Edge pane visibility and geometry changes are now queued asynchronously, so force-ending or crashing Edge cannot block multiprompt's UI thread or its close path.", .ticket = "" },
        .{ .text = "A one-second health pass drops dead or repeatedly hung pane handles, immediately gives the console its full width back, clears stale zsb routing, and relaunches the active pane after a short teardown backoff.", .ticket = "" },
        .{ .text = "Termination-pending multiprompt windows no longer count as live workspace owners, allowing a clean relaunch without a Windows sign-out if an old process object lingers.", .ticket = "" },
    } },
    .{ .ver = "0.28.514", .summary = "Workspace unarchive restores purple dissolved sessions too", .ticket = "", .items = &.{
        .{ .text = "Ctrl+K Unarchive Workspace Sessions still restores every filed live tab, and now also resurrects the purple archive.json records assigned to the workspace where the command runs.", .ticket = "" },
        .{ .text = "Old dissolved records route by tmux family before CWD, so Secondary sessions with missing or helper-repo paths return to Secondary without launching the other 68 globally archived sessions.", .ticket = "" },
    } },
    .{ .ver = "0.28.513", .summary = "Browser panes stay painted; large workspaces keep growing", .ticket = "", .items = &.{
        .{ .text = "Session switches, overlays, and Alt+A now park established native Edge panes off-screen instead of cycling SW_HIDE/SW_SHOW, preserving Chromium's compositor and preventing the blank grey browser column.", .ticket = "" },
        .{ .text = "The practical shell ceiling rises from 64 to 256, Inbox/session serialization grows with it, and repeated browser visibility work no longer rewrites unchanged Edge styles or enumerates every desktop window on each geometry message.", .ticket = "" },
    } },
    .{ .ver = "0.28.512", .summary = "Native browser clicks cannot inherit a stale Alt key", .ticket = "", .items = &.{
        .{ .text = "Immediately before Edge receives a physical left click, multiprompt now emits an Alt release and replays only that mouse-down when Windows confirms no physical Alt key is held.", .ticket = "" },
        .{ .text = "This runs in the native mouse hook, so it protects browser chrome and every page without depending on the extension, a content script, page navigation lifecycle, or an extension reload. Intentional physical Alt-click remains unchanged.", .ticket = "" },
    } },
    .{ .ver = "0.28.511", .summary = "Protected browser panes neutralize stale Alt-click downloads", .ticket = "", .items = &.{
        .{ .text = "Normal same-tab links in multiprompt-owned browser panes now navigate even if Edge reports a stale Alt modifier, instead of downloading the destination as an HTML file.", .ticket = "" },
        .{ .text = "Real download links and links that explicitly open another target are unchanged. Native bridge and Edge extension advance together to 1.0.24.", .ticket = "" },
    } },
    .{ .ver = "0.28.510", .summary = "Docked-browser clicks stop downloading HTML pages", .ticket = "", .items = &.{
        .{ .text = "Native Edge focus from Alt+Q/Alt+M now waits until physical Alt is released before attaching Edge's input queue, preventing ordinary link clicks from being misread as native Alt+click downloads.", .ticket = "" },
        .{ .text = "The deferred focus is bound to the originating shell and cancels if the session or foreground changes, so a late timer cannot focus the wrong pane or steal focus from another app.", .ticket = "" },
    } },
    .{ .ver = "0.28.509", .summary = "Returned archived sessions stay returned after interaction", .ticket = "", .items = &.{
        .{ .text = "Selecting a filed-away live tab directly from Ctrl+K now clears its persisted archive state, matching the existing All Sessions activation path, so it remains in the workspace sidebar after switching away.", .ticket = "" },
        .{ .text = "The first real keystroke or paste sent to any temporarily-open archived console also commits the return by shell identity, covering every restore route without letting spinner-only agent activity resurface filed sessions.", .ticket = "" },
    } },
    .{ .ver = "0.28.508", .summary = "Alt+X keeps focus inside multiprompt; restore all filed sessions", .ticket = "", .items = &.{
        .{ .text = "Alt+X now parks Windows foreground on the durable multiprompt frame before killing an active tmux/conhost, then hands focus to the logical replacement session instead of letting a foreign app surface.", .ticket = "" },
        .{ .text = "Ctrl+K now includes Unarchive All Sessions, restoring every live session hidden with Inbox e or Alt+E across all open same-build windows without touching tmux, agents, browser panes, or unread state.", .ticket = "" },
    } },
    .{ .ver = "0.28.507", .summary = "consecutive extension screenshots stay fast", .ticket = "", .items = &.{
        .{ .text = "Rapid screenshots now reuse one short-lived CDP attachment after Edge's captureVisibleTab rate limit is reached, avoiding repeated multi-second attach/detach stalls.", .ticket = "" },
        .{ .text = "Shell-focused captures bypass captureVisibleTab immediately because Edge can leave that API hanging when the docked browser window is not focused.", .ticket = "" },
    } },
    .{ .ver = "0.28.506", .summary = "dissolved-session archive grows without a fixed limit", .ticket = "", .items = &.{
        .{ .text = "Alt+X no longer stops at 64 dissolved sessions: archive records, archive.json reads/writes, and the All Sessions recovery list now grow dynamically.", .ticket = "" },
        .{ .text = "The durable-before-kill safety rule remains unchanged, so a tmux session is still killed only after its resurrection record is saved atomically.", .ticket = "" },
    } },
    .{ .ver = "0.28.505", .summary = "per-monitor DPI follows the window; terminal zoom is independent", .ticket = "", .items = &.{
        .{ .text = "App chrome now tracks an explicit current-monitor DPI, updated immediately by Windows DPI messages and rechecked throughout move, resize, dock, undock, and display settle passes.", .ticket = "" },
        .{ .text = "Ctrl+Plus, Ctrl+Minus, and Ctrl+0 once again change only the native console font; Ctrl+K UI Size remains the independent app-only adjustment.", .ticket = "" },
        .{ .text = "A manifest declares Per-Monitor V2 awareness before startup, and the v0.28.504 coupled zoom state is migrated back to the native terminal baseline once.", .ticket = "" },
        .{ .text = "The restored-console full-height viewport repair from v0.28.504 remains active across every monitor transition.", .ticket = "" },
    } },
    .{ .ver = "0.28.504", .summary = "native DPI zoom and restored console rows stay aligned", .ticket = "", .items = &.{
        .{ .text = "Windows monitor DPI now scales the custom-drawn app UI; Ctrl+Plus, Ctrl+Minus, and Ctrl+0 zoom the console and app chrome together.", .ticket = "" },
        .{ .text = "Restored conhosts now repair their internal visible-row viewport in place, eliminating the black half-height pane without reconnecting or replacing tmux.", .ticket = "" },
        .{ .text = "Startup, tab switches, DPI transitions, and dock/undock events repeat the non-destructive geometry settle until the surviving monitor and console agree.", .ticket = "" },
        .{ .text = "Pinned sessions that exit unexpectedly remain visible as disconnected placeholders until the user explicitly closes or reconnects them.", .ticket = "" },
    } },
    .{ .ver = "0.28.503", .summary = "embedded browser links preserve their own tabs", .ticket = "", .items = &.{
        .{ .text = "Shell Ctrl+click, Alt+W, and multiprompt-browser opens now create a new internal WebView2 tab instead of replacing the page already open in the pane.", .ticket = "" },
        .{ .text = "Website target=_blank and window.open requests stay inside multiprompt as new internal tabs, so they do not create another taskbar window.", .ticket = "" },
        .{ .text = "Ctrl+Tab and Ctrl+Shift+Tab cycle WebView tabs; Ctrl+W closes the current tab; Ctrl+T opens a blank tab. Closing Alt+S still destroys the entire on-demand WebView runtime.", .ticket = "" },
    } },
    .{ .ver = "0.28.502", .summary = "typing and focus work inside the embedded WebView", .ticket = "", .items = &.{
        .{ .text = "WebView2 now reports focus gained/lost to multiprompt, and its host/renderer are recognized as the typing owner instead of being mistaken for the console child.", .ticket = "" },
        .{ .text = "A bounded post-controller focus handoff waits for physical Alt release, attaches to conhost's input queue, and uses the established foreground unlock before focusing WebView2.", .ticket = "" },
        .{ .text = "Normal typing and browser shortcuts pass through while WebView2 is focused; Alt+Q and Ctrl+backtick switch between the shell and either browser backend.", .ticket = "" },
    } },
    .{ .ver = "0.28.501", .summary = "WebView2 and Edge are strictly exclusive; shell links stay in WebView2", .ticket = "", .items = &.{
        .{ .text = "Opening WebView2 now synchronously hides and closes the regular Edge pane, URL bar, masks, and any in-flight Edge launch before the embedded surface appears.", .ticket = "" },
        .{ .text = "Every Edge launch, adoption, positioning, visibility, and settle path now refuses to show Edge while WebView2 owns the active split, so the two browser surfaces cannot stack.", .ticket = "" },
        .{ .text = "Ctrl+click links in the shell and Alt+W URL-picker selections now navigate the active WebView2 pane in place; multiprompt-browser open/navigate also recognizes the WebView2-backed session.", .ticket = "" },
    } },
    .{ .ver = "0.28.500", .summary = "optional embedded WebView2 browser on Alt+S", .ticket = "", .items = &.{
        .{ .text = "Alt+S creates an embedded WebView2 child inside multiprompt; Alt+S again fully destroys its Chromium process group and returns the memory.", .ticket = "" },
        .{ .text = "Alt+A remains the regular native-Edge pane toggle, with Alt+B retained as its legacy alias; opening either browser mode closes the other cleanly.", .ticket = "" },
        .{ .text = "WebView2 adds no independent taskbar window, but its six-process runtime starts around 150 MB private and reached about 246 MB on Google in the stable candidate, so it remains explicitly on-demand.", .ticket = "" },
    } },
    .{ .ver = "0.28.499", .summary = "repair taskbar identity and stale browser overlays", .ticket = "", .items = &.{
        .{ .text = "Restored the permanent ValentinYeo.ZigShell AppUserModelID across the process, main HWND, jump list, and installed Start Menu shortcut so Explorer and Start11 cannot merge multiprompt with unrelated Edge PWAs or desktop apps.", .ticket = "" },
        .{ .text = "The per-window identity write now initializes COM before opening the HWND property store; previous builds could silently leave the window AppUserModelID blank.", .ticket = "" },
        .{ .text = "Switching from a browser session to a non-browser session now hard-hides every inactive native Edge pane before the foreground gate, preventing a stale grey half-pane from covering the centered console.", .ticket = "" },
    } },
    .{ .ver = "0.28.490", .summary = "restore the original full pane focus border", .ticket = "", .items = &.{
        .{ .text = "Fully reverted v0.28.489: restored the original pane inset, full rounded violet focus border, and browser-edge-mask geometry.", .ticket = "" },
        .{ .text = "The reported exposed element is Edge's own native padded frame overlapping the cover, not multiprompt's focus gutter; this rollback avoids changing unrelated focus behavior.", .ticket = "" },
    } },
    .{ .ver = "0.28.488", .summary = "clearer active session emphasis", .ticket = "", .items = &.{
        .{ .text = "The active sidebar session in the multiprompt theme now uses a slightly brighter graphite background, improving focus without adding a new accent or changing inactive rows.", .ticket = "" },
    } },
    .{ .ver = "0.28.487", .summary = "clean native agent icons and better spacing", .ticket = "", .items = &.{
        .{ .text = "Replaced font-fallback agent glyphs with crisp native-drawn Claude and Codex icons; the Pi glyph remains unchanged.", .ticket = "" },
        .{ .text = "Codex uses a static alpha-smoothed multiprompt blue dot embedded as an icon resource; the newly approved spinner colour is unchanged.", .ticket = "" },
        .{ .text = "Added deliberate spacing between agent icons and shell names in the sidebar, header, Inbox, and inline Inbox rename geometry; browser and sticky indicators were removed to keep the lane quiet.", .ticket = "" },
        .{ .text = "The sidebar now labels pinned sessions under PINNED and all remaining sessions under RECENTS instead of repeating a pin glyph on every row.", .ticket = "" },
    } },
    .{ .ver = "0.28.486", .summary = "clean full-height multiprompt separators", .ticket = "", .items = &.{
        .{ .text = "Removed the horizontal rule between the shell title and shell content.", .ticket = "" },
        .{ .text = "The tab-list/content divider and shell/browser divider now run continuously from the top to the bottom of the client area.", .ticket = "" },
        .{ .text = "The multiprompt native Edge cover is now true pitch black as requested.", .ticket = "" },
    } },
    .{ .ver = "0.28.485", .summary = "multiprompt theme border and browser-cover polish", .ticket = "", .items = &.{
        .{ .text = "The multiprompt focus ring is now a restrained violet instead of the legacy near-white outline, and all app separators use one consistent graphite rule.", .ticket = "" },
        .{ .text = "Native Edge control covers now match the multiprompt title-bar surface instead of borrowing the sidebar colour.", .ticket = "" },
        .{ .text = "Sidebar session names now sit at the midpoint requested after testing: one pixel smaller than the original Inter size rather than two.", .ticket = "" },
    } },
    .{ .ver = "0.28.484", .summary = "multiprompt theme promoted to stable", .ticket = "", .items = &.{
        .{ .text = "The multiprompt.dev visual theme is now available in stable under Ctrl+K, Themes, multiprompt; selecting it persists globally across workspaces and restarts.", .ticket = "" },
        .{ .text = "The promoted theme includes the smaller verified sidebar session-name typography while leaving terminal text, Inbox, Ctrl+K, layout, and native Edge chrome unchanged.", .ticket = "" },
    } },
    .{ .ver = "0.28.483", .summary = "multiprompt identity and DEV visual preview", .ticket = "", .items = &.{
        .{ .text = "DEV adds a multiprompt theme based on the multiprompt.dev palette: near-black layered surfaces, cool grey typography, violet selection, blue attention, and green live status while preserving the existing layout.", .ticket = "" },
        .{ .text = "This release initially kept the multiprompt theme in DEV for verification; its pending-attention dots use a restrained violet-blue shimmer.", .ticket = "" },
        .{ .text = "The lowercase multiprompt executable, website favicon, and Windows app now share the three ascending prompt-bar mark.", .ticket = "" },
    } },
    .{ .ver = "0.28.482", .summary = "ZigShell is now multiprompt", .ticket = "", .items = &.{
        .{ .text = "The product is now branded multiprompt in lowercase across the app title, executable, taskbar identity, commands, diagnostics, documentation, and browser extension.", .ticket = "" },
        .{ .text = "The browser CLI is now multiprompt-browser; zsb remains a compatibility alias so existing local hooks, VPS sessions, and pane bindings keep working.", .ticket = "" },
        .{ .text = "Existing runtime state remains under the legacy APPDATA ZigShell folder and existing ZIGSHELL/ZSB protocol identifiers remain unchanged to preserve every saved session and browser binding.", .ticket = "" },
    } },
    .{ .ver = "0.28.481", .summary = "Suppress Edge's zsb debugger infobar", .ticket = "", .items = &.{
        .{ .text = "ZigShell-launched Edge panes now use Chromium's targeted silent-debugger-extension-api switch, removing the ZigShell Bridge started debugging this browser bar after Edge's next full restart.", .ticket = "" },
        .{ .text = "The switch affects only the extension debugger infobar; normal page errors, permission prompts, and ZigShell notices remain visible.", .ticket = "" },
    } },
    .{ .ver = "0.28.480", .summary = "Ctrl+F reduces All Sessions live", .ticket = "", .items = &.{
        .{ .text = "Press Ctrl+F in All Sessions to show only rows matching the typed session name, tmux name, workspace, context, host, or status.", .ticket = "" },
        .{ .text = "The reduced list keeps normal Up/Down and Enter behavior; Backspace edits the query and Esc clears search without closing All Sessions.", .ticket = "" },
    } },
    .{ .ver = "0.28.479", .summary = "Ctrl+K tmux sessions stick immediately", .ticket = "", .items = &.{
        .{ .text = "Opening an inactive tmux session from Ctrl+K now records its known session identity before the first save, so it stays in the current workspace without requiring any typing.", .ticket = "" },
        .{ .text = "A single-session Ctrl+K open deliberately targets the current workspace; use Open Workspace when the whole saved workspace should return.", .ticket = "" },
    } },
    .{ .ver = "0.28.478", .summary = "zsb background SPA and tab control fixes", .ticket = "", .items = &.{
        .{ .text = "zsb automatically enables focus emulation when it drives a background tab, allowing SPAs that otherwise stay on Loading to render.", .ticket = "" },
        .{ .text = "zsb navigate now reuses the driven tab by default; --new-tab is the explicit opt-in for creating another tab.", .ticket = "" },
        .{ .text = "New zsb activate <tabId> command activates a tab only when it belongs to the session's bound browser pane.", .ticket = "" },
    } },
    .{ .ver = "0.28.477", .summary = "Screenshot links return focus to their shell", .ticket = "", .items = &.{
        .{ .text = "After a browser screenshot URL is pasted, ZigShell activates and focuses the exact shell that owns that browser pane so annotations can be typed immediately.", .ticket = "" },
        .{ .text = "The focus handoff runs only after a successful paste and preserves browser-window-to-shell isolation while uploads are in flight.", .ticket = "" },
    } },
    .{ .ver = "0.28.476", .summary = "All Sessions reactivates filed-away sessions", .ticket = "", .items = &.{
        .{ .text = "Opening a session archived with E or Alt+E from Ctrl+Shift+A now permanently revokes its filed-away state.", .ticket = "" },
        .{ .text = "The reactivated session remains visible in the Inbox and workspace sidebar after switching away; reminder rows keep their separate restore behavior.", .ticket = "" },
    } },
    .{ .ver = "0.28.475", .summary = "one Alt+Tab explicitly leaves the whole ZigShell task", .ticket = "", .items = &.{
        .{ .text = "Alt+Tab now skips every ZigShell frame, shell, browser pane, URL bar, and mask and activates the next foreign Windows task directly.", .ticket = "" },
        .{ .text = "The direct switch applies from shell or browser focus; Shift+Alt+Tab uses the reverse task order.", .ticket = "" },
    } },
    .{ .ver = "0.28.474", .summary = "reminders preserve the running tmux session", .ticket = "", .items = &.{
        .{ .text = "Remind Me now closes only the local ZigShell tab; the same remote tmux session and its running agent stay alive until ZigShell reattaches at the reminder time.", .ticket = "" },
        .{ .text = "Blue-dot and spinner activity cannot reveal a snoozed session early. Ctrl+K Reminders can still reattach it manually.", .ticket = "" },
        .{ .text = "Existing reminders remain readable, and the four current reminders were migrated to live persistent tmux sessions without changing their due dates.", .ticket = "" },
    } },
    .{ .ver = "0.28.473", .summary = "Alt+H opens Remind Me", .ticket = "", .items = &.{
        .{ .text = "Alt+H opens the Remind Me preset picker for the active session, the docked-browser session, or the selected Inbox row.", .ticket = "" },
        .{ .text = "Ctrl+Shift+H remains available as a legacy alias.", .ticket = "" },
    } },
    .{ .ver = "0.28.472", .summary = "one Alt+Tab leaves ZigShell from a browser pane", .ticket = "", .items = &.{
        .{ .text = "Alt+Tab from a focused docked Edge page or address bar now switches away from ZigShell in one step instead of stopping on the ZigShell owner first.", .ticket = "" },
        .{ .text = "The browser-pane ownership and Alt+Tab invariants are now documented together so future changes do not mistake separate taskbar, mask, and focus fixes for the same behavior.", .ticket = "" },
    } },
    .{ .ver = "0.28.471", .summary = "zsb self-heals every configured missing pane", .ticket = "", .items = &.{
        .{ .text = "Alt+E itself still only hides the docked browser; it does not close or suspend zsb. Normal browser auto-suspend may still close inactive panes after 20 minutes.", .ticket = "" },
        .{ .text = "A zsb request now relaunches any configured pane whose HWND is missing, including inactive panes closed by a ZigShell restart, not only panes explicitly marked auto-suspended.", .ticket = "" },
        .{ .text = "zsb status and doctor now wait for asynchronous Edge adoption after requesting a relaunch, instead of immediately reporting the recovering pane as closed.", .ticket = "" },
        .{ .text = "Native bridge and Edge extension versions advance together to 1.0.19; reload the extension once after installation.", .ticket = "" },
    } },
    .{ .ver = "0.28.470", .summary = "Isolate ZigShell taskbar identity", .ticket = "", .items = &.{
        .{ .text = "ZigShell now declares the stable explicit Windows AppUserModelID ValentinYeo.ZigShell before creating any window and stamps it directly on the HWND, instead of relying on Explorer's inferred executable identity.", .ticket = "" },
        .{ .text = "The taskbar jump list uses the same explicit AppUserModelID, preventing repeated ZigShell rebuild/restart cycles from contaminating Edge PWA and desktop-app icon groups.", .ticket = "" },
    } },
    .{ .ver = "0.28.469", .summary = "Window title follows Inbox and session workspace", .ticket = "", .items = &.{
        .{ .text = "Opening Inbox now changes the Windows title/taskbar label to Inbox instead of leaving the last workspace name frozen there.", .ticket = "" },
        .{ .text = "Every runtime shell switch now derives the active workspace and title from the target session, so Inbox Enter, Alt+J/K, and Alt+E update the label when they cross workspaces.", .ticket = "" },
        .{ .text = "Alt+E now advances to the exact next row captured when the current session was opened from Inbox. If that target vanished, it stops instead of falling back to an unrelated sidebar session.", .ticket = "" },
        .{ .text = "Inbox identity bookmarks now accept shell ID 0 as valid, fixing selection and next-row tracking for the first session.", .ticket = "" },
        .{ .text = "Opening a session from Inbox now holds shell focus through the docked browser settle window, so the browser pane cannot take keyboard focus on arrival.", .ticket = "" },
    } },
    .{ .ver = "0.28.468", .summary = "Inbox keeps bare and Alt triage keys", .ticket = "", .items = &.{
        .{ .text = "Inside Inbox, bare j/k and e work again alongside Alt+J/K and Alt+E. The Alt versions remain universal across Inbox, shell, and docked-browser focus.", .ticket = "" },
        .{ .text = "Session-view Alt+E still hides until a blue dot and advances to the next row in the same Inbox split; workspace cycling remains Alt+Left/Right.", .ticket = "" },
    } },
    .{ .ver = "0.28.467", .summary = "Inbox returns to the same selected session", .ticket = "", .items = &.{
        .{ .text = "Closing and reopening Inbox restores selection by owning window and shell ID, so resorting cannot replace the session under the cursor with whichever row moved into its old position.", .ticket = "" },
        .{ .text = "Opening a row or stepping directly between Inbox sessions updates the same identity bookmark. If that row is no longer visible in the selected split, Inbox falls back to the active local session, then the first row.", .ticket = "" },
        .{ .text = "Alt+E is the only hide-until-blue-dot shortcut in both views. From a session opened through Inbox it hides that session and opens the next row in the same split.", .ticket = "" },
        .{ .text = "Alt+J and Alt+K are the universal next/previous Inbox controls in the overlay, shell, and docked browser. Bare j/k and Ctrl+Shift+J/K are no longer aliases; workspace cycling remains on Alt+Left/Right.", .ticket = "" },
    } },
    .{ .ver = "0.28.466", .summary = "Archived Inbox rows cannot return as spinners", .ticket = "", .items = &.{
        .{ .text = "A DONE event can publish a filed row with its blue dot, but no longer clears the persisted archived flag immediately.", .ticket = "" },
        .{ .text = "If ACTIVE follows before the row is opened, the blue dot clears and the row hides again instead of remaining visible with a spinner. Opening the row while its blue dot is present commits the unarchive.", .ticket = "" },
    } },
    .{ .ver = "0.28.465", .summary = "Undo Inbox archive and restore the last viewed session", .ticket = "", .items = &.{
        .{ .text = "After archiving an Inbox row with e, press z to restore that exact session and its previous read/unread state. One archive action is remembered at a time.", .ticket = "" },
        .{ .text = "ZigShell now persists the active saved-tab index and maps it back to the successfully restored shell, reopening on the session and workspace that were visible at shutdown when that session still exists.", .ticket = "" },
    } },
    .{ .ver = "0.28.464", .summary = "Browser frame masks stay inside ZigShell", .ticket = "", .items = &.{
        .{ .text = "The native Edge pane may remain owner-docked on ordinary focus loss, but its separate frame/control mask popups now hide immediately and cannot overlay the app reached through Alt+Tab.", .ticket = "" },
        .{ .text = "Alt+Q now recognizes Edge's titleless omnibox popup as part of the active docked pane, so the focus switch returns to the shell even while the browser address bar is focused.", .ticket = "" },
        .{ .text = "Opening a filed-away session from All Sessions no longer permanently unhides it; after switching away it stays hidden until a real blue dot or manual mark-unread.", .ticket = "" },
    } },
    .{ .ver = "0.28.463", .summary = "Inbox hide waits for a real blue dot", .ticket = "", .items = &.{
        .{ .text = "Sessions filed with e now persist their hidden-until-blue-dot state across ZigShell restarts, workspace transfer, and SSH/tmux in-place respawns.", .ticket = "" },
        .{ .text = "Spinner/ACTIVE events leave the hidden flag untouched; only a real background DONE event that creates a blue dot, or a manual mark-unread action, resurfaces the session.", .ticket = "" },
    } },
    .{ .ver = "0.28.462", .summary = "Inbox names get more horizontal room", .ticket = "", .items = &.{
        .{ .text = "Inbox rows are compact again; the session-name column now receives about 40% of the available width, capped at 560 pixels, so longer names are not cut off as early.", .ticket = "" },
        .{ .text = "The inline F2 rename field uses the same wider name-column geometry.", .ticket = "" },
    } },
    .{ .ver = "0.28.461", .summary = "Rename sessions directly in Inbox", .ticket = "", .items = &.{
        .{ .text = "F2 now opens an inline rename field over the selected local Inbox session. Enter saves, Esc cancels, and the Inbox stays open.", .ticket = "" },
        .{ .text = "The initial build made Inbox rows taller; v0.28.462 restores the compact height and gives session names horizontal room instead.", .ticket = "" },
    } },
    .{ .ver = "0.28.460", .summary = "Saved snippets can be deleted", .ticket = "", .items = &.{
        .{ .text = "In the snippet picker, select a saved snippet and press Delete twice to remove it. The row shows the pending confirmation, and moving, typing, or leaving cancels it.", .ticket = "" },
    } },
    .{ .ver = "0.28.459", .summary = "Snippet forms no longer gray out browser panes", .ticket = "", .items = &.{
        .{ .text = "Create Snippet now stays inside the shell column when a docked browser is open, so the native Edge window remains visible instead of going through an unstable hide/show cycle.", .ticket = "" },
        .{ .text = "Narrow shell splits still hide the pane when the form cannot fit, while normal splits constrain and center the complete form inside the available shell area.", .ticket = "" },
        .{ .text = "Switching to a session with an existing browser pane now rearms the visibility settle pass after the old session's stale settle state is cancelled.", .ticket = "" },
    } },
    .{ .ver = "0.28.458", .summary = "Snippet form stays above docked browser panes", .ticket = "", .items = &.{
        .{ .text = "Create Snippet now hides the active docked browser before showing the form, so Edge cannot cover the form's right side.", .ticket = "" },
        .{ .text = "Browser visibility refreshes keep the pane hidden while the form is active and restore it after save or cancel.", .ticket = "" },
        .{ .text = "Alt+; now opens the saved-snippet picker directly from shell or docked-browser focus; Ctrl+; remains as a legacy alias.", .ticket = "" },
    } },
    .{ .ver = "0.28.457", .summary = "Alt+U marks the active session unread", .ticket = "", .items = &.{
        .{ .text = "Alt+U now restores the active session's blue dot on demand from shell focus or docked-browser focus.", .ticket = "" },
        .{ .text = "Manual mark-unread clears the filed-away Inbox state, refreshes the sidebar and Inbox publication, and removes stale sticky sort keys so the session behaves like a fresh unread item.", .ticket = "" },
        .{ .text = "F1 and docs-site keyboard-shortcuts now include the new Mark Unread shortcut.", .ticket = "" },
    } },
    .{ .ver = "0.28.456", .summary = "Alt+X closes non-tmux sessions too", .ticket = "", .items = &.{
        .{ .text = "Alt+X still double-press dissolves tmux-backed sessions, but non-tmux VPS/cmd/pwsh tabs now use the same double-press flow to close the local tab.", .ticket = "" },
        .{ .text = "Ctrl+K and tab right-click actions now show Close Session on non-tmux tabs instead of silently offering a tmux-only dissolve path.", .ticket = "" },
        .{ .text = "F1, Inbox footer help, and keyboard-shortcuts docs now describe the tmux dissolve versus non-tmux close behavior.", .ticket = "" },
    } },
    .{ .ver = "0.28.455", .summary = "Alt+W opens links from the shell", .ticket = "", .items = &.{
        .{ .text = "Alt+W is now the primary one-handed shortcut for opening the URL picker from the visible shell buffer.", .ticket = "" },
        .{ .text = "Ctrl+O remains as a legacy URL-picker alias; Alt+O stays unbound because Claude Code uses it.", .ticket = "" },
        .{ .text = "F1, Ctrl+K, docs, and URL-picker comments now show Alt+W as the primary open-links shortcut.", .ticket = "" },
    } },
    .{ .ver = "0.28.454", .summary = "Alt+A opens the browser pane", .ticket = "", .items = &.{
        .{ .text = "Alt+A is now the primary one-handed shortcut for toggling the active tab's docked browser pane.", .ticket = "" },
        .{ .text = "Alt+B remains as a legacy browser-pane toggle while the shortcut layout moves toward the left-hand Alt+A/W/S/E/Q cluster.", .ticket = "" },
        .{ .text = "F1, Ctrl+K, tab right-click shortcut badges, docs, and zsb instructions now show Alt+A for opening the browser pane.", .ticket = "" },
    } },
    .{ .ver = "0.28.453", .summary = "Sessions can be pinned to the top of the workspace sidebar", .ticket = "", .items = &.{
        .{ .text = "Tabs now have a persisted Pin to Top flag that keeps them in the top sidebar tier ahead of unread, active, and normal sessions.", .ticket = "" },
        .{ .text = "Pinning is available from Ctrl+K for the active tab and from the tab right-click actions palette for any sidebar session.", .ticket = "" },
        .{ .text = "Pinned sessions show a small top marker in the sidebar and remain pinned through restart, reconnect, and workspace absorption.", .ticket = "" },
    } },
    .{ .ver = "0.28.452", .summary = "Alt+Q is the browser focus toggle", .ticket = "", .items = &.{
        .{ .text = "The shell/browser focus toggle moved from Alt+F to Alt+Q because Edge owns Alt+F for its menu.", .ticket = "" },
        .{ .text = "Alt+F is no longer intercepted by ZigShell; Alt+M remains as the legacy browser focus alias.", .ticket = "" },
    } },
    .{ .ver = "0.28.451", .summary = "Alt+J/K walks the Inbox thread you opened", .ticket = "", .items = &.{
        .{ .text = "After opening a row from Inbox, Alt+J and Alt+K now jump to the next or previous row in that same Inbox split, even if focus is in the shell or docked browser pane.", .ticket = "" },
        .{ .text = "Alt+J/K still cycles workspaces when there is no active Inbox-step context; manually switching sessions clears that context.", .ticket = "" },
        .{ .text = "Bare q now closes Inbox and All Sessions, matching the existing Esc close path for those captured overlays.", .ticket = "" },
    } },
    .{ .ver = "0.28.450", .summary = "Browser edge masks do not leak onto shell-only tabs", .ticket = "", .items = &.{
        .{ .text = "Switching from a zsb/browser tab to a shell-only tab now force-hides the Edge mask popups and cancels stale browser settle ticks, so the old split boundary cannot remain as a black strip over console text.", .ticket = "" },
        .{ .text = "Mask refresh and raise paths now require the current active tab to own a live native browser pane before any mask can be shown again.", .ticket = "" },
    } },
    .{ .ver = "0.28.449", .summary = "External links deflect to a visible Edge window", .ticket = "", .items = &.{
        .{ .text = "External/PWA launches that are deflected out of a protected zsb pane now open in a fresh focused Edge window instead of being moved into an arbitrary existing Edge/PWA window.", .ticket = "" },
        .{ .text = "The settled-focus bookmark/favorites behavior from 0.28.448 is preserved, so focused pane bookmarks stay docked.", .ticket = "" },
        .{ .text = "Requires Edge extension reload; version should show 1.0.18.", .ticket = "" },
    } },
    .{ .ver = "0.28.448", .summary = "Browser bookmarks stay docked again", .ticket = "", .items = &.{
        .{ .text = "Protected-pane external-tab filtering now uses settled focus, so Edge bookmarks/favorites opened while the pane is already focused stay inside the docked browser.", .ticket = "" },
        .{ .text = "External/PWA launches that only focus the pane as part of opening a link are still treated as suspicious and moved back out to regular Edge.", .ticket = "" },
        .{ .text = "Requires Edge extension reload; version should show 1.0.17.", .ticket = "" },
    } },
    .{ .ver = "0.28.447", .summary = "PWA external links leave zsb panes", .ticket = "", .items = &.{
        .{ .text = "The Edge extension now treats focused blank placeholder tabs in protected panes as suspicious until webNavigation proves they came from a user typed/bookmark action.", .ticket = "" },
        .{ .text = "External links clicked in Edge PWAs that Edge tries to place into a zsb pane are deferred briefly, then moved back to a regular Edge window instead of staying docked.", .ticket = "" },
        .{ .text = "Requires Edge extension reload; version should show 1.0.16.", .ticket = "" },
    } },
    .{ .ver = "0.28.446", .summary = "zsb new tabs stop stealing foreground", .ticket = "", .items = &.{
        .{ .text = "zsb navigate/new-tab now creates background tabs when the owning protected pane is not already focused, so agent-driven browser opens do not pull ZigShell/Edge to the front.", .ticket = "" },
        .{ .text = "The extension remembers the last zsb target tab per protected pane, so follow-up zsb text/screenshot/actions keep targeting the newly opened background tab.", .ticket = "" },
        .{ .text = "Requires Edge extension reload; version should show 1.0.15.", .ticket = "" },
    } },
    .{ .ver = "0.28.445", .summary = "Notification sound toggle in Ctrl+K", .ticket = "", .items = &.{
        .{ .text = "The Ctrl+K sound row is now labeled Notification Sounds: On/Off so it is clear that it controls blue-dot notification audio.", .ticket = "" },
        .{ .text = "Searching Ctrl+K for notification, notifications, notify, sound, sounds, audio, alert, beep, silent, or quiet finds the same toggle.", .ticket = "" },
    } },
    .{ .ver = "0.28.444", .summary = "External app links leave docked panes", .ticket = "", .items = &.{
        .{ .text = "The Edge extension no longer trusts focused protected pane windows by themselves, because external launches from apps like Zoom can focus the pane before the tab event arrives.", .ticket = "" },
        .{ .text = "ZigShell-created tabs, blank in-pane new tabs, and opener-linked in-pane tabs remain docked; unrecognized http/file launches in protected pane windows are moved back to a regular Edge window.", .ticket = "" },
        .{ .text = "Requires Edge extension reload; version should show 1.0.14.", .ticket = "" },
    } },
    .{ .ver = "0.28.443", .summary = "Docked browser panes stay out of Alt+Tab", .ticket = "", .items = &.{
        .{ .text = "Docked Edge pane windows are normalized as tool windows and have AppWindow cleared, so internal panes stop appearing as separate Alt+Tab targets.", .ticket = "" },
        .{ .text = "Normal Edge/PWA windows are no longer treated as ZigShell foreground just because they share msedge.exe process/geometry with a docked pane.", .ticket = "" },
        .{ .text = "Alt+Tab to Superhuman, Project, or another Edge PWA should now stay in that app instead of refocusing ZigShell or resizing a pane.", .ticket = "" },
    } },
    .{ .ver = "0.28.442", .summary = "Browser screenshot links", .ticket = "", .items = &.{
        .{ .text = "Take a screenshot of the browser pane's active tab and its screencast2 share link is typed into the shell.", .ticket = "" },
        .{ .text = "Use Ctrl+Shift+S, Ctrl+K, the bridge CLI shoturl command, or right-click the ZigShell Bridge icon.", .ticket = "" },
        .{ .text = "Requires Edge extension reload; version should show 1.0.13.", .ticket = "" },
    } },
    .{ .ver = "0.28.441", .summary = "Quiet startup and regular browser foreground", .ticket = "", .items = &.{
        .{ .text = "The changelog no longer opens automatically on startup after a version update; it remains available on demand from Ctrl+K.", .ticket = "" },
        .{ .text = "Regular Edge windows are focused again when the extension deflects an external launch out of a protected ZigShell browser pane.", .ticket = "" },
        .{ .text = "The regular-browser focus path no longer uses the native fgUnlock loop, so it should not reintroduce ZigShell taskbar flashing.", .ticket = "" },
        .{ .text = "Requires Edge extension reload; version should show 1.0.11.", .ticket = "" },
    } },
    .{ .ver = "0.28.440", .summary = "Docked browser shortcuts stay docked", .ticket = "", .items = &.{
        .{ .text = "Clicking favorites/bookmark-bar shortcuts inside a protected ZigShell browser pane no longer gets misclassified as an external launch and moved to the regular browser.", .ticket = "" },
        .{ .text = "The external-tab guard now leaves new tabs alone when the protected Edge pane itself is focused; background external launches into protected panes are still deflected out.", .ticket = "" },
        .{ .text = "Requires Edge extension reload; version should show 1.0.10.", .ticket = "" },
    } },
    .{ .ver = "0.28.439", .summary = "No browser/zsb foreground noise", .ticket = "", .items = &.{
        .{ .text = "Background refocus retries no longer reclaim foreground or trigger taskbar flashing when another app owns focus.", .ticket = "" },
        .{ .text = "zsb browser binding no longer focuses the docked Edge pane just to resolve a windowId while ZigShell is in the background.", .ticket = "" },
        .{ .text = "zsb key/insert automation no longer focuses the Edge window or activates its tab before sending CDP input.", .ticket = "" },
        .{ .text = "External-tab deflection no longer calls the foreground unlock path or focuses the regular browser window; it only moves the tab out of the protected ZigShell pane.", .ticket = "" },
        .{ .text = "Non-blue-dot header notices no longer beep; the only audible notification path is the configured blue-dot DONE sound.", .ticket = "" },
        .{ .text = "Requires Edge extension reload; version should show 1.0.9.", .ticket = "" },
    } },
    .{ .ver = "0.28.438", .summary = "Browser shortcut legacy aliases removed", .ticket = "", .items = &.{
        .{ .text = "Ctrl+Shift+O no longer toggles the docked browser pane; use Alt+B.", .ticket = "" },
        .{ .text = "Ctrl+Shift+M no longer jumps between shell and browser focus; use Alt+Q.", .ticket = "" },
        .{ .text = "Archive/hide-until-blue-dot now uses Alt+E in the shell and Inbox; Ctrl+Shift+E is no longer intercepted.", .ticket = "" },
        .{ .text = "Dissolve Session now uses Alt+X in the shell and Inbox; Ctrl+Shift+X is no longer intercepted.", .ticket = "" },
        .{ .text = "The keyboard-shortcuts view and browser-control instructions now show only the Alt-based browser shortcuts.", .ticket = "" },
    } },
    .{ .ver = "0.28.437", .summary = "Restore free browser split dragging", .ticket = "", .items = &.{
        .{ .text = "The HD-width docked-browser split floor from 0.28.436 is reverted; the browser splitter can again make the shell column much smaller when that is the desired layout.", .ticket = "" },
        .{ .text = "The cross-monitor settle pass remains, so moving/resizing still rechecks the active console font and repositions the docked browser without changing the user's chosen split.", .ticket = "" },
    } },
    .{ .ver = "0.28.436", .summary = "HD browser split and shortcut badges", .ticket = "", .items = &.{
        .{ .text = "Docked browser layouts now enforce a wider shell column on HD-width screens, so a split saved on a larger monitor cannot squeeze the terminal after dragging back.", .ticket = "" },
        .{ .text = "Move, resize, and DPI changes now schedule a short console/browser settle pass that rechecks the active conhost font and repositions the docked browser after Windows finishes the monitor transition.", .ticket = "" },
        .{ .text = "Ctrl+K and the tab right-click command palette now show direct keyboard shortcuts for Reconnect, Remind Me, Dissolve Session, End tmux session, and Browser Pane actions.", .ticket = "" },
    } },
    .{ .ver = "0.28.435", .summary = "Smaller Inbox split unread dots", .ticket = "", .items = &.{
        .{ .text = "Inbox split-tab unread markers are now smaller, so the blue dot reads as a subtle status cue instead of a chunky leading bullet.", .ticket = "" },
        .{ .text = "All Sessions split markers keep their previous size; this change is scoped to the Inbox split bar.", .ticket = "" },
    } },
    .{ .ver = "0.28.434", .summary = "Inbox split dots only show unread splits", .ticket = "", .items = &.{
        .{ .text = "Inbox split tabs no longer show a gray placeholder dot; the leading dot is drawn only when that split contains a blue-dot/unread item.", .ticket = "" },
        .{ .text = "The ALL split keeps the same rule: it gets a blue dot only when at least one inbox row needs attention.", .ticket = "" },
    } },
    .{ .ver = "0.28.433", .summary = "Trial Alt+B / Alt+F browser shortcuts", .ticket = "", .items = &.{
        .{ .text = "Alt+B is now the primary shortcut for toggling the active tab's docked browser pane; Ctrl+Shift+O remains as a legacy alias during the trial.", .ticket = "" },
        .{ .text = "Alt+F is now the primary shortcut for moving focus between shell and browser; Alt+M, Ctrl+`, and Ctrl+Shift+M remain as legacy aliases during the trial.", .ticket = "" },
        .{ .text = "Alt+O is deliberately left alone because Claude Code uses it.", .ticket = "" },
        .{ .text = "Alt+I opens the Inbox from outside it; inside the Inbox it jumps back to the ALL split, leaving Esc as the close shortcut.", .ticket = "" },
    } },
    .{ .ver = "0.28.432", .summary = "Alt+M browser focus toggle", .ticket = "", .items = &.{
        .{ .text = "Alt+M is now the primary shortcut for jumping between the shell and its docked browser pane, avoiding 60% keyboard Fn-layer backtick chords.", .ticket = "" },
        .{ .text = "The existing Ctrl+` and Ctrl+Shift+M focus toggles remain available as legacy aliases.", .ticket = "" },
        .{ .text = "The keyboard-shortcuts view and Ctrl+K browser-jump hint now show Alt+M as the primary shortcut.", .ticket = "" },
    } },
    .{ .ver = "0.28.431", .summary = "Alt+I is the Inbox toggle", .ticket = "", .items = &.{
        .{ .text = "Alt+I is now the primary Inbox shortcut everywhere: shell, browser focus, command palette, shortcuts overlay, All Sessions, and the Inbox itself.", .ticket = "" },
        .{ .text = "Pressing Alt+I while the Inbox is open closes it, so the same chord toggles back and forth.", .ticket = "" },
        .{ .text = "The retired inbox chord is no longer intercepted by ZigShell, avoiding Edge/Chrome DevTools conflicts and retraining the shortcut to Alt+I only.", .ticket = "" },
    } },
    .{ .ver = "0.28.430", .summary = "URL click hook arms after restore", .ticket = "", .items = &.{
        .{ .text = "Ctrl-click URL routing no longer depends on a transient foreground-window check when arming the mouse hook, so restored browser-enabled tabs keep shell links inside the docked pane.", .ticket = "" },
        .{ .text = "Startup and deferred shell-focus paths now explicitly resync the mouse hook after browser panes are restored.", .ticket = "" },
        .{ .text = "The hook uninstall timer now uses the shared foreground ownership helper, covering hosted console/browser child windows consistently.", .ticket = "" },
    } },
    .{ .ver = "0.28.429", .summary = "Wrapped shell URLs open completely", .ticket = "", .items = &.{
        .{ .text = "Ctrl-clicking the first line of a URL that wraps across multiple terminal rows now includes the continuation rows instead of opening only the first fragment.", .ticket = "" },
        .{ .text = "Ctrl+O's URL picker uses the same wrapped-URL continuation logic, so long Google Docs/Sheets links are captured consistently.", .ticket = "" },
    } },
    .{ .ver = "0.28.428", .summary = "Ctrl-click links stay in the docked browser", .ticket = "", .items = &.{
        .{ .text = "Ctrl-clicking a URL in the shell is less likely to leak to the system default browser: the mouse hook now stays armed while the active tab has a docked browser pane.", .ticket = "" },
        .{ .text = "Normal terminal clicks are still passed through; only Ctrl-click URL handling is intercepted.", .ticket = "" },
        .{ .text = "Ctrl+` remains the new browser focus shortcut, with Ctrl+Shift+M still available as the legacy alias.", .ticket = "" },
    } },
    .{ .ver = "0.28.427", .summary = "Ctrl+` browser focus shortcut", .ticket = "", .items = &.{
        .{ .text = "Ctrl+` now jumps between the shell and its docked browser pane without using Edge's Ctrl+Shift+M profile shortcut.", .ticket = "" },
        .{ .text = "Ctrl+Shift+M still works as a legacy alias while the new shortcut is tested in stable.", .ticket = "" },
        .{ .text = "The keyboard-shortcuts view and Ctrl+K browser-jump hint now show Ctrl+` as the primary shortcut.", .ticket = "" },
    } },
    .{ .ver = "0.28.426", .summary = "Browser panes stay alive for agents + dissolve/resurrect fixes", .ticket = "", .items = &.{
        .{ .text = "Browser panes an agent is actively driving (zsb) are no longer auto-suspended after 20 minutes - agent traffic now counts as activity.", .ticket = "" },
        .{ .text = "If a pane WAS suspended, the next zsb command relaunches it automatically instead of failing with 'no pane'.", .ticket = "" },
        .{ .text = "Screenshots over zsb no longer time out on hidden panes (capture falls back to an offscreen method) and large captures no longer stall the bridge.", .ticket = "" },
        .{ .text = "Resurrecting a dissolved session can no longer drop you into an unrelated live session that reused the same tmux name - it always creates a fresh uniquely-named session.", .ticket = "" },
        .{ .text = "Dissolved sessions no longer vanish from the All Sessions 'e' view when a new live session reuses their tmux name.", .ticket = "" },
        .{ .text = "New zsb commands: reload (refresh the page in place) and insert (type text at the cursor, works in Google Docs); text/snapshot/links accept --full; --help no longer crashes.", .ticket = "" },
        .{ .text = "Needs an Edge extension reload (edge://extensions - version should show 1.0.8).", .ticket = "" },
    } },
    .{ .ver = "0.28.425", .summary = "Claude sessions no longer show the Codex icon", .ticket = "", .items = &.{
        .{ .text = "Claude tabs that merely talked about Codex (e.g. running a delegated Codex build) were flipping to the green Codex icon - the on-screen text detector no longer counts the word 'codex' in conversation as evidence.", .ticket = "" },
        .{ .text = "Real Codex tabs are unaffected - they are identified by what actually runs in the session, not by screen text.", .ticket = "" },
    } },
    .{ .ver = "0.28.424", .summary = "Archive is now called Dissolve, with a Ctrl+Shift+X shortcut", .ticket = "", .items = &.{
        .{ .text = "The action that kills a session's tmux but keeps it resurrectable is now called 'Dissolve Session' everywhere (Ctrl+K, right-click menu, All Sessions shows 'dissolved') - searching 'archive' still finds it.", .ticket = "" },
        .{ .text = "Ctrl+Shift+X dissolves the active tab - press it twice within 2.5s to confirm, since it kills the running tmux.", .ticket = "" },
        .{ .text = "Ctrl+Shift+X also works on the selected row inside the inbox, same double-press confirm.", .ticket = "" },
    } },
    .{ .ver = "0.28.423", .summary = "Remind Me presets: snooze a session with one pick", .ticket = "", .items = &.{
        .{ .text = "Ctrl+Shift+H (or Ctrl+K -> Remind Me) opens a quick-pick snooze list - This evening, Tomorrow morning, In 3 days, This weekend, Next week, Someday - each showing the exact time it resolves to, so you rarely have to type.", .ticket = "" },
        .{ .text = "The list adapts to the time of day (This evening only shows before 4 PM); Custom... still lets you type any time.", .ticket = "" },
        .{ .text = "Both triage keys now work inside the inbox too: Ctrl+Shift+H snoozes the selected row, Ctrl+Shift+E hides it (same as e).", .ticket = "" },
        .{ .text = "A snoozed session is dissolved (its tmux is killed to free VPS memory) and comes back automatically with the Claude conversation resumed when the reminder is due.", .ticket = "" },
    } },
    .{ .ver = "0.28.422", .summary = "Hidden tabs show up in the archived view", .ticket = "", .items = &.{
        .{ .text = "The e filter in All Sessions now shows hidden tabs alongside archived sessions - everything you filed away in one place, with the kind column telling them apart ('hidden' vs 'arch').", .ticket = "" },
    } },
    .{ .ver = "0.28.421", .summary = "Hidden tabs actually leave the sidebar now", .ticket = "", .items = &.{
        .{ .text = "Ctrl+Shift+E (hide tab until it gets a blue dot) now really removes the tab from the sidebar - it was only leaving the inbox before, which made hiding look broken.", .ticket = "" },
        .{ .text = "If you navigate back to a hidden tab it shows while you're on it and disappears again when you switch away; pressing Ctrl+Shift+E on it again also switches you away instead of doing nothing.", .ticket = "" },
        .{ .text = "In All Sessions, hidden tabs are now labeled 'hidden' instead of 'archived' - that label was clashing with real archived sessions ('arch').", .ticket = "" },
    } },
    .{ .ver = "0.28.420", .summary = "Browse your archived sessions in All Sessions", .ticket = "", .items = &.{
        .{ .text = "Archived sessions now show up in the All Sessions view (Ctrl+Shift+A), tagged 'arch' and sorted into their workspace splits like everything else.", .ticket = "" },
        .{ .text = "Press e in All Sessions to see only archived sessions (press e again to show all) - just like u filters to unattached.", .ticket = "" },
        .{ .text = "Enter on an archived session brings it back: a fresh tmux session is created and the old Claude conversation resumes where it left off.", .ticket = "" },
        .{ .text = "Ctrl+K -> 'Archived Sessions' jumps straight to the archived-only view; in the row action menu, k deletes an archive entry you no longer need.", .ticket = "" },
    } },
    .{ .ver = "0.28.419", .summary = "Browser pane controls cover fixed on the laptop monitor", .ticket = "", .items = &.{
        .{ .text = "On the laptop monitor, the strip that hides the browser pane's own minimize/maximize/close buttons drifted way down the screen, leaving the buttons exposed and a stray dark bar floating over the page - it now sits exactly over the buttons on every monitor.", .ticket = "" },
        .{ .text = "That cover strip also scales with the monitor's display scaling now, so it fully covers the buttons on a 125% screen.", .ticket = "" },
    } },
    .{ .ver = "0.28.418", .summary = "Browser focus ring shows its bottom edge again", .ticket = "", .items = &.{
        .{ .text = "The focus ring around the docked browser pane now draws its bottom line too - it was hidden behind the pane's bottom edge, so only the top and sides showed.", .ticket = "" },
    } },
    .{ .ver = "0.28.417", .summary = "External links now bring the outside browser window to the front", .ticket = "", .items = &.{
        .{ .text = "Clicking a link in another app (e.g. Beeper) now brings the outside Edge window to the front showing that link, instead of opening it silently in the background behind ZigShell. Needs an Edge extension reload (should show 1.0.7).", .ticket = "" },
        .{ .text = "Deflecting a link no longer resizes your existing Edge window - a maximized window stays maximized.", .ticket = "" },
    } },
    .{ .ver = "0.28.416", .summary = "Cross-monitor font fix now works on VPS/SSH tabs", .ticket = "", .items = &.{
        .{ .text = "VPS and SSH tabs were silently ignoring every font correction - monitor moves and Ctrl+Plus/Minus/0 did nothing on them. They now pick up their font automatically and resize correctly.", .ticket = "" },
    } },
    .{ .ver = "0.28.415", .summary = "Console font stays the right size across monitors", .ticket = "", .items = &.{
        .{ .text = "Console text keeps the same visual size when you move the window between monitors with different scaling - no more giant text on the lower-res screen.", .ticket = "" },
        .{ .text = "Ctrl+Plus / Ctrl+Minus / Ctrl+0 font zoom now flashes the chosen size at the top of the window.", .ticket = "" },
    } },
    .{ .ver = "0.28.414", .summary = "Filter All Sessions to unattached only", .ticket = "", .items = &.{
        .{ .text = "All Sessions: press u to show only unattached sessions (sessions running on a VPS without an open tab); press u again to show all.", .ticket = "" },
        .{ .text = "While filtered, workspace tab counts show unattached counts and a badge in the footer reminds you the filter is on.", .ticket = "" },
    } },
    .{ .ver = "0.28.413", .summary = "Close a session straight from All Sessions", .ticket = "", .items = &.{
        .{ .text = "In the All Sessions view (Ctrl+Shift+A), press Ctrl+K on any session for a quick action menu: Enter/a to attach, k to kill its remote tmux session, Esc to cancel.", .ticket = "" },
        .{ .text = "Lets you clean up stale detached sessions right from the list without attaching them first; the row disappears immediately once killed.", .ticket = "" },
    } },
    .{ .ver = "0.28.412", .summary = "All Sessions now loads every VPS session", .ticket = "", .items = &.{
        .{ .text = "Fixed the Host 2 (UK) sessions never showing in All Sessions — the session list was too big for the fetch buffer and silently stalled, so only the smaller Host 1 list loaded.", .ticket = "" },
        .{ .text = "All your detached sessions on both servers now appear under their workspace tabs.", .ticket = "" },
    } },
    .{ .ver = "0.28.411", .summary = "Jump between All Sessions and Inbox", .ticket = "", .items = &.{
        .{ .text = "Ctrl+Shift+I now jumps straight from the All Sessions view to the Inbox (and Ctrl+Shift+A goes back), so you can hop between the two without closing one first.", .ticket = "" },
    } },
    .{ .ver = "0.28.410", .summary = "All Sessions splits by workspace", .ticket = "", .items = &.{
        .{ .text = "Ctrl+Shift+A now has one tab per workspace (plus All and Other) instead of tabs by session type, so you can see a workspace's sessions together at a glance.", .ticket = "" },
        .{ .text = "Each session still shows its type in its row, so within a workspace tab you can immediately spot which ones are unattached.", .ticket = "" },
        .{ .text = "Sessions that don't match any workspace's repo folder collect under the \"Other\" tab.", .ticket = "" },
    } },
    .{ .ver = "0.28.409", .summary = "Opening a session lands in the right workspace", .ticket = "", .items = &.{
        .{ .text = "Opening an unattached session from Ctrl+Shift+A now drops it into the workspace that already runs that repo folder — e.g. a project session joins your Project workspace.", .ticket = "" },
        .{ .text = "Sessions that don't match any workspace's repo now land in a permanent \"Other\" workspace instead of the workspace you happened to be in.", .ticket = "" },
        .{ .text = "The \"Other\" workspace is created the first time it's needed and then sticks around like any other pill.", .ticket = "" },
    } },
    .{ .ver = "0.28.408", .summary = "All Sessions shows every session", .ticket = "", .items = &.{
        .{ .text = "Ctrl+Shift+A now lists every session across both VPS, not just the current workspace's repo — the Unattached tab finally shows all your detached sessions.", .ticket = "" },
        .{ .text = "Each row shows its host (host1/host2) and repo folder so sessions from different projects stay easy to tell apart.", .ticket = "" },
        .{ .text = "Fixed the server list script so sessions with spaces in their name (like \"SEO Loop Agent\") show once with the right details instead of splitting into broken rows.", .ticket = "" },
    } },
    .{ .ver = "0.28.407", .summary = "Fix docked browser flicker", .ticket = "", .items = &.{
        .{ .text = "The docked browser pane no longer flickers when you switch shells, click links, or Alt+Tab back in — Edge and its edge masks stop fighting over which sits on top.", .ticket = "" },
        .{ .text = "Edge's own close/minimize/maximize buttons no longer flash in and out.", .ticket = "" },
        .{ .text = "All browser features are unchanged — pane, masks, and page clicks work exactly as before, minus the repaint churn.", .ticket = "" },
    } },
    .{ .ver = "0.28.406", .summary = "Diagnostic build (browser tracing)", .ticket = "", .items = &.{
        .{ .text = "Reverted the v0.28.404/405 browser changes back to the v0.28.403 behavior — those attempts made the flicker worse and blocked clicks.", .ticket = "" },
        .{ .text = "Added internal browser choreography logging (ZIGSHELL_DEBUG only) to pin down the flicker before changing anything.", .ticket = "" },
    } },
    .{ .ver = "0.28.403", .summary = "Revert custom browser fallback", .ticket = "", .items = &.{
        .{ .text = "Reverted v0.28.402: docked browser panes must remain native Edge chrome; custom --app window mode is not an acceptable fallback.", .ticket = "" },
        .{ .text = "Future browser stability work must fix native Edge pane ownership/focus directly instead of replacing it with the custom URL-strip app-window mode.", .ticket = "" },
    } },
    .{ .ver = "0.28.401", .summary = "Rollback browser focus churn", .ticket = "", .items = &.{
        .{ .text = "Tab switching no longer foregrounds Edge just to refresh pane routing; zsb binding files are refreshed without touching OS focus.", .ticket = "" },
        .{ .text = "Browser edge masks remain visual-only but are now mouse-transparent, so they cannot steal clicks from the docked page.", .ticket = "" },
        .{ .text = "Browser foreground detection now recognizes Chromium child/transient windows as the pane, preventing accidental shell refocus while clicking inside Edge.", .ticket = "" },
        .{ .text = "Native Edge pane launch starts at the target dock rectangle when possible, reducing the visible outside-window jump before adoption.", .ticket = "" },
    } },
    .{ .ver = "0.28.400", .summary = "Keep bridge versions visible", .ticket = "", .items = &.{
        .{ .text = "Bridge and extension changes now ship with a visible bridge version bump: native zigshell-bridge and the Edge extension manifest move to 1.0.6.", .ticket = "" },
        .{ .text = "The local agent rules now require bridge/extension version bumps whenever bridge JavaScript, native bridge code, or browser protocol behavior changes.", .ticket = "" },
    } },
    .{ .ver = "0.28.399", .summary = "Add All Sessions shortcut", .ticket = "", .items = &.{
        .{ .text = "Ctrl+Shift+A now opens the Inbox-style All Sessions view directly from shells, overlays, and the docked browser pane.", .ticket = "" },
        .{ .text = "The shortcut is intercepted before browser Ctrl-key passthrough, so it remains a ZigShell session-navigation command even when Edge has focus.", .ticket = "" },
        .{ .text = "All Sessions is now a hard overlay state: shell windows and every docked browser pane stay hidden while the view is active, even during browser settle or external foreground changes.", .ticket = "" },
        .{ .text = "The Edge bridge no longer lets opener-tagged external tabs stay inside protected ZigShell pane windows unless ZigShell explicitly created the tab.", .ticket = "" },
    } },
    .{ .ver = "0.28.398", .summary = "Stabilize browser pane and complete VPS sessions", .ticket = "", .items = &.{
        .{ .text = "ZigShell no longer hides the actual docked Edge pane from WM_ACTIVATEAPP deactivation, preventing grey browser holes when focus moves through another app or helper window.", .ticket = "" },
        .{ .text = "Minimize and overlay paths still hide browser panes intentionally; normal foreground loss leaves the pane stable in the ZigShell layout.", .ticket = "" },
        .{ .text = "Show All Sessions now scans the raw tmux cache for Unattached rows and raises the combined VPS cache cap from 128 to 512 sessions.", .ticket = "" },
    } },
    .{ .ver = "0.28.397", .summary = "Inbox-style All Sessions view", .ticket = "", .items = &.{
        .{ .text = "Show All Sessions now opens a full-window Inbox-style repo session view instead of listing sessions inside Ctrl+K.", .ticket = "" },
        .{ .text = "The view uses cluster splits for All, Open, Reminders, Archived, and Unattached sessions, with j/k, h/l, Tab, number keys, Enter, and Esc navigation.", .ticket = "" },
    } },
    .{ .ver = "0.28.396", .summary = "Prioritize Show All Sessions", .ticket = "", .items = &.{
        .{ .text = "Typing show all sessions, repo sessions, or workspace sessions in Ctrl+K now puts the repo session overview at the top of the palette instead of burying it behind other actions.", .ticket = "" },
        .{ .text = "The older recover-only command no longer claims the generic repo/session search terms that belong to the complete session overview.", .ticket = "" },
    } },
    .{ .ver = "0.28.395", .summary = "Repo session overview and zsb tab routing", .ticket = "", .items = &.{
        .{ .text = "Ctrl+K can now open Show Repo Sessions, a repo-scoped list of open, hidden, reminder, and VPS-only tmux sessions; Enter focuses, restores, or attaches the selected session.", .ticket = "" },
        .{ .text = "Ctrl+Shift+E is intercepted even when the docked browser pane has foreground focus, so the active workspace tab can hide until the next blue-dot event.", .ticket = "" },
        .{ .text = "zsb-created new tabs are explicitly tied back to the docked Edge window so the external-tab guard does not move them into a normal Edge window.", .ticket = "" },
    } },
    .{ .ver = "0.28.394", .summary = "Make tmux recovery discoverable", .ticket = "", .items = &.{
        .{ .text = "Typing recover in Ctrl+K now always exposes Recover workspace tmux sessions, and Enter explains when no workspace repo or missing tmux sessions are detected.", .ticket = "" },
    } },
    .{ .ver = "0.28.393", .summary = "Keep browser masks stable", .ticket = "", .items = &.{
        .{ .text = "Alt+Tab, shell switching, and link navigation no longer hide and rebuild the browser URL bar or Edge gutter masks, preventing native close/min/max buttons and pane flicker from resurfacing.", .ticket = "" },
    } },
    .{ .ver = "0.28.392", .summary = "Quiet browser chrome switching", .ticket = "", .items = &.{
        .{ .text = "Foreground loss now hides only ZigShell's floating browser URL bar and edge masks while leaving the owned Edge pane alive, reducing Alt+Tab and shell-switch grey-pane flicker.", .ticket = "" },
        .{ .text = "Ctrl+Shift+E is intercepted from explicit browser-focus mode too, so the active workspace tab can hide until its next real blue-dot attention event.", .ticket = "" },
    } },
    .{ .ver = "0.28.391", .summary = "Restore browser pane after Alt-Tab", .ticket = "", .items = &.{
        .{ .text = "Alt+Tab away and back now keeps retrying the docked Edge visibility settle path instead of cancelling it on a transient foreign foreground, so the pane returns without a manual resize.", .ticket = "" },
    } },
    .{ .ver = "0.28.390", .summary = "Reassert docked browser on focus", .ticket = "", .items = &.{
        .{ .text = "Returning focus to ZigShell now re-shows, repositions, and raises the docked Edge pane, so a live browser no longer stays hidden as a grey area until the window is resized.", .ticket = "" },
    } },
    .{ .ver = "0.28.389", .summary = "Stabilize docked browser foreground", .ticket = "", .items = &.{
        .{ .text = "Docked Edge panes now treat transient Chromium foreground windows from link clicks and navigation as part of the pane, preventing the browser from flickering or disappearing into a grey area.", .ticket = "" },
    } },
    .{ .ver = "0.28.388", .summary = "Safer hide-until-attention shortcut", .ticket = "", .items = &.{
        .{ .text = "Ctrl+Shift+E now hides the active tab from the sidebar and Inbox until a real blue-dot attention event returns it; destructive tmux archiving remains an explicit Ctrl+K action.", .ticket = "" },
    } },
    .{ .ver = "0.28.387", .summary = "", .ticket = "", .items = &.{
        .{ .text = "Process polling now reuses one cached process table for Claude/Codex detection and RAM accounting instead of repeatedly walking Toolhelp snapshots per tab.", .ticket = "" },
        .{ .text = "The Windows taskbar right-click jump list now has New Window, launching ZigShell with a fresh blank workspace instead of restoring saved workspaces.", .ticket = "" },
        .{ .text = "Ctrl+O, Changelog, and Inbox lists now wrap from the last row to the first and back again instead of getting stuck at the edge.", .ticket = "" },
        .{ .text = "Ctrl+K and the tab context menu now include End tmux session, which kills the remote tmux target, removes the zsb binding, and closes the local tab without adding reopen history.", .ticket = "" },
        .{ .text = "Ctrl+Shift+W now performs the same destructive End tmux session action for the active tab.", .ticket = "" },
        .{ .text = "Ctrl+K can use or create saved snippets, and Ctrl+; opens the snippet picker directly.", .ticket = "" },
        .{ .text = "System Alt+Tab now starts a short suppression window that cancels stale shell refocus retries after ZigShell loses foreground, preventing focus from being pulled back.", .ticket = "" },
        .{ .text = "Ctrl+K Remind Me snoozes the active tmux/Claude session until a due time, kills the remote tmux session immediately, then recreates it with Claude resume when the reminder is due.", .ticket = "" },
        .{ .text = "Ctrl+K Reminders lists snoozed sessions so they can be restored early.", .ticket = "" },
        .{ .text = "Codex tabs are detected more precisely from explicit Codex evidence, so incidental Claude text in a Codex transcript no longer flips the agent icon.", .ticket = "" },
        .{ .text = "Archived Inbox threads now stay hidden during spinner-only activity and return only when a new blue needs-input dot is raised.", .ticket = "" },
        .{ .text = "Inbox previews now skip generic tmux status rows and AI prompt chrome, so Codex sessions can surface the last useful conversation line instead of repo/session stats.", .ticket = "" },
        .{ .text = "Docked browser panes and Edge mask popups now hide immediately when foreground leaves from the pane directly to another Windows app.", .ticket = "" },
        .{ .text = "Edge mask popups now self-hide on stale hit-tests and timer sweeps when ZigShell is not foreground, so they cannot block another app after Alt+Tab.", .ticket = "" },
        .{ .text = "Codex and OpenAI Codex rename titles now update ZigShell tab names like Claude, and the VPS tmux title helpers filter generic Codex titles.", .ticket = "" },
        .{ .text = "Ctrl+K can launch a new Codex tmux session from the active remote tab's current folder, using the same VPS host and project path.", .ticket = "" },
        .{ .text = "Archive/unarchive is hardened: archive records are saved before remote tmux sessions are killed, reloads no longer drop in-memory state on failed reads, restore commands are shell-quoted and ZSB-tagged, and archive entries are kept unless restore command construction and tab spawn succeed.", .ticket = "" },
    } },
    .{ .ver = "0.28.385", .summary = "", .ticket = "", .items = &.{
        .{ .text = "Ctrl+K Sync Tab/Tmux/Agent Name now also sends the coding agent's /rename command, so Codex/Claude session names match the ZigShell tab and tmux window title.", .ticket = "" },
        .{ .text = "External links opened from other apps are kept out of docked Edge panes even when Edge first creates a blank tab and fills the URL a moment later.", .ticket = "" },
    } },
    .{ .ver = "0.28.384", .summary = "", .ticket = "", .items = &.{
        .{ .text = "The Inbox overlay now reliably hides docked browser panes, including panes that are adopted or repositioned while Inbox is already open.", .ticket = "" },
    } },
    .{ .ver = "0.28.383", .summary = "", .ticket = "", .items = &.{
        .{ .text = "Alt+Tab now explicitly cancels pending shell refocus before Windows switches apps, so ZigShell should stop pulling focus back and requiring a second Alt+Tab.", .ticket = "" },
    } },
    .{ .ver = "0.28.382", .summary = "", .ticket = "", .items = &.{
        .{ .text = "Ctrl+O now stays owned by ZigShell even when the docked Edge pane has focus, so URL-picker links open in the session browser pane instead of leaking into a normal Edge action.", .ticket = "" },
    } },
    .{ .ver = "0.28.303", .summary = "", .ticket = "", .items = &.{
        .{ .text = "When the docked browser pane is focused, keyboard shortcuts now go to the browser instead of ZigShell -- Ctrl+W closes the browser tab (not your ZigShell session), Ctrl+T opens a browser tab, Ctrl+C/L/R/F all work as browser shortcuts. Ctrl+Tab still cycles ZigShell tabs so you can leave the pane by keyboard.", .ticket = "" },
    } },
    .{ .ver = "0.28.302", .summary = "", .ticket = "", .items = &.{
        .{ .text = "Removed the grey border Windows drew around the docked browser pane -- the Edge window's default rounded corners and grey 1px frame are gone, so on AMOLED the browser sits flush in pure black with no grey edge.", .ticket = "" },
    } },
    .{ .ver = "0.28.301", .summary = "", .ticket = "", .items = &.{
        .{ .text = "Ctrl+C while the browser pane is focused now copies in the browser instead of hitting the shell (it used to copy the console selection / interrupt the shell). Matches how Ctrl+V already worked.", .ticket = "" },
    } },
    .{ .ver = "0.28.300", .summary = "", .ticket = "", .items = &.{
        .{ .text = "An empty browser pane is now black instead of grey -- the blank placeholder page was hardcoded to grey (#222); now it matches the dark/AMOLED theme.", .ticket = "" },
    } },
    .{ .ver = "0.28.299", .summary = "", .ticket = "", .items = &.{
        .{ .text = "While the browser pane is focused, Alt+I jumps to the Inbox, Alt+1-9 switch workspace, and Alt+J/K cycle workspaces -- all in one press (no need to leave the browser first).", .ticket = "" },
        .{ .text = "Focus ring polish: thinner (1px), rounded, muted blue, floating with padding instead of hugging the edge; the splitter between panes is now a 1px hairline matching the sidebar divider.", .ticket = "" },
    } },
    .{ .ver = "0.28.298", .summary = "", .ticket = "", .items = &.{
        .{ .text = "When auto-sort is on, Ctrl+Tab / Ctrl+Shift+Tab / Ctrl+1-9 no longer reshuffle the sidebar under you -- tabs stay put while you cycle through them, so the selection just walks down the list.", .ticket = "" },
    } },
    .{ .ver = "0.28.297", .summary = "", .ticket = "", .items = &.{
        .{ .text = "Every changelog entry is now a short bullet point in plain language (the newest ones had slipped back into paragraphs).", .ticket = "" },
    } },
    .{ .ver = "0.28.296", .summary = "", .ticket = "", .items = &.{
        .{ .text = "A bright ring shows which pane has keyboard focus when the browser is docked, so you can tell whether your typing goes to the shell or the browser.", .ticket = "" },
    } },
    .{ .ver = "0.28.295", .summary = "", .ticket = "", .items = &.{
        .{ .text = "Changelog entries rewritten to be readable: short bullet points instead of dense paragraphs.", .ticket = "" },
    } },
    .{ .ver = "0.28.294", .summary = "", .ticket = "", .items = &.{
        .{ .text = "Ctrl+K -> Restart ZigShell: saves your session and relaunches the app in one step.", .ticket = "" },
        .{ .text = "A background session can no longer open a link into your active window -- each session only ever touches its own browser pane (needs an Edge extension reload to take effect).", .ticket = "" },
    } },
    .{ .ver = "0.28.293", .summary = "", .ticket = "", .items = &.{
        .{ .text = "Switching workspace (Alt+1/2/3) no longer leaks keystrokes into the browser. The browser only captures keys after you jump into it with Ctrl+Shift+M.", .ticket = "" },
        .{ .text = "Opening a link now opens a NEW tab instead of replacing the current page.", .ticket = "" },
        .{ .text = "The \"ZigShell is debugging this browser\" bar no longer lingers -- it only flashes briefly during a screenshot.", .ticket = "" },
    } },
    .{ .ver = "0.28.292", .summary = "", .ticket = "", .items = &.{
        .{ .text = "The inbox (Ctrl+Shift+I) is now mouse-clickable: click a row to open it, click a workspace header to switch, scroll to move the selection.", .ticket = "" },
        .{ .text = "The window border and browser splitter now follow the AMOLED black theme instead of staying grey.", .ticket = "" },
    } },
    .{ .ver = "0.28.291", .summary = "", .ticket = "", .items = &.{
        .{ .text = "The browser pane can switch between native Edge (real tabs + address bar) and a slim custom URL bar -- toggle it from Ctrl+K.", .ticket = "" },
        .{ .text = "Ctrl+Shift+M jumps you fully into the browser (every key goes to Edge); press it again to return to the shell.", .ticket = "" },
        .{ .text = "Each shell now strictly drives only its own browser pane, never another session's windows.", .ticket = "" },
    } },
    .{ .ver = "0.28.290", .summary = "", .ticket = "", .items = &.{
        .{ .text = "Clicking away from the address bar now exits edit mode (it used to stay stuck in the white edit box).", .ticket = "" },
        .{ .text = "The address bar no longer floats over other apps when ZigShell is minimized or in the background.", .ticket = "" },
    } },
    .{ .ver = "0.28.289", .summary = "", .ticket = "", .items = &.{
        .{ .text = "Leftover floating Edge windows from a crash or restart are cleaned up automatically, without touching your real Edge windows.", .ticket = "" },
    } },
    .{ .ver = "0.28.288", .summary = "", .ticket = "", .items = &.{
        .{ .text = "Keep-alive tabs show their pin marker again (it was being drawn in the wrong place).", .ticket = "" },
    } },
    .{ .ver = "0.28.287", .summary = "", .ticket = "", .items = &.{
        .{ .text = "Keep-alive tabs show a pin marker so you can tell which tabs survive when you exit ZigShell.", .ticket = "" },
    } },
    .{ .ver = "0.28.286", .summary = "", .ticket = "", .items = &.{
        .{ .text = "Alt+Left / Alt+Right go browser back / forward only while the browser pane is focused; with the shell focused they cycle workspaces.", .ticket = "" },
    } },
    .{ .ver = "0.28.285", .summary = "", .ticket = "", .items = &.{
        .{ .text = "Typing a bare address like \"google.com\" in the URL bar now auto-adds https:// so it loads.", .ticket = "" },
    } },
    .{ .ver = "0.28.284", .summary = "", .ticket = "", .items = &.{
        .{ .text = "The browser address bar is now always visible above the page.", .ticket = "" },
    } },
    .{ .ver = "0.28.283", .summary = "", .ticket = "", .items = &.{
        .{ .text = "Clicking the browser address bar opens a focused edit box instead of vanishing.", .ticket = "" },
    } },
    .{ .ver = "0.28.282", .summary = "", .ticket = "", .items = &.{
        .{ .text = "This changelog now opens automatically the first time you launch a new stable version, so you see what changed and what to test.", .ticket = "" },
        .{ .text = "Versions with several fixes now show bullet points, each linking its own ticket (like this one).", .ticket = "" },
        .{ .text = "The browser pane's URL bar is now clearly visible: outlined address box, brighter URL text, slightly taller.", .ticket = "" },
    } },
    .{ .ver = "0.28.281", .summary = "", .ticket = "", .items = &.{
        .{ .text = "Sidebar auto-sort: a focused tab holds its exact position until you leave it -- clicking a blue-dot tab no longer makes it jump below the other unread tabs.", .ticket = "" },
        .{ .text = "Ctrl+K Changelog wraps the full entry text per version instead of truncating each line with an ellipsis.", .ticket = "" },
    } },
    .{ .ver = "0.28.280", .summary = "", .ticket = "", .items = &.{
        .{ .text = "zsb sidebar: reveal the sidebar from a shell (strict session isolation).", .ticket = "" },
        .{ .text = "Ctrl+V paste into the Ctrl+K palette search.", .ticket = "" },
        .{ .text = "zsb eval returns the value (MAIN world, awaits promises).", .ticket = "" },
    } },
    .{ .ver = "0.28.279", .summary = "", .ticket = "", .items = &.{
        .{ .text = "Browser back/forward: URL-bar buttons + Alt+Left/Right + Ctrl+K.", .ticket = "" },
        .{ .text = "Ctrl+V / Ctrl+K pass through to the page when the browser pane is focused.", .ticket = "" },
        .{ .text = "Ctrl+W picks the adjacent tab in the same workspace.", .ticket = "" },
    } },
    .{ .ver = "0.28.278", .summary = "", .ticket = "", .items = &.{
        .{ .text = "Live URL bar shows the current page URL.", .ticket = "" },
        .{ .text = "Sort recency = last_active only; switching a tab never re-ranks it.", .ticket = "" },
        .{ .text = "Muted tabs sink to the bottom of the inbox.", .ticket = "" },
        .{ .text = "Clean tab names (no stray numeric prefixes).", .ticket = "" },
        .{ .text = "zsb panewin binding re-asserted so a shell finds its own pane.", .ticket = "" },
        .{ .text = "Blue-dot notifications verified end to end.", .ticket = "" },
    } },
    .{ .ver = "0.28.277", .summary = "", .ticket = "", .items = &.{
        .{ .text = "Strict zsb session isolation: a shell only ever drives its OWN docked pane.", .ticket = "" },
        .{ .text = "Ctrl+K Changelog overlay added.", .ticket = "" },
    } },
    .{ .ver = "0.28.276", .items = &.{
        .{ .text = "Sidebar auto-sort is the permanent default for all sidebars (no longer reverts to manual)", .ticket = "" },
    } },
    .{ .ver = "0.28.275", .items = &.{
        .{ .text = "Shell pane left padding restored when the browser pane is open", .ticket = "" },
    } },
    .{ .ver = "0.28.274", .items = &.{
        .{ .text = "Fixed white strip remnant after closing a browser pane", .ticket = "" },
    } },
    .{ .ver = "0.28.273", .items = &.{
        .{ .text = "Browser globe recolored gold; Ctrl+O URL picker no longer hidden behind the pane", .ticket = "" },
    } },
    .{ .ver = "0.28.272", .summary = "", .ticket = "", .items = &.{
        .{ .text = "zsb \"pane not open\" fixed: pane-session binding + auto-relaunch after restart.", .ticket = "" },
        .{ .text = "Single-pane fallback + stale panewin cleanup on startup.", .ticket = "" },
    } },
    .{ .ver = "0.28.271", .items = &.{
        .{ .text = "ZigBrowser: address bar (Ctrl+Shift+L), Ctrl+Shift+M jump shell-pane, idle auto-suspend, globe", .ticket = "" },
    } },
    .{ .ver = "0.28.270", .items = &.{
        .{ .text = "zsb open [url] opens the docked pane from a shell; pane survives restart", .ticket = "" },
    } },
    .{ .ver = "0.28.269", .items = &.{
        .{ .text = "Collapsed sidebar icons show agent kind + locality (Claude/Codex/Pi, local/VPS)", .ticket = "" },
    } },
    .{ .ver = "0.28.268", .items = &.{
        .{ .text = "Console gets a left/right gutter when the sidebar is hidden", .ticket = "" },
    } },
    .{ .ver = "0.28.267", .items = &.{
        .{ .text = "Ctrl+K palette keeps the browser pane visible; padding on the docked console", .ticket = "" },
    } },
    .{ .ver = "0.28.266", .items = &.{
        .{ .text = "Ctrl+K palette stays beside the browser pane instead of hiding it", .ticket = "" },
    } },
    .{ .ver = "0.28.265", .items = &.{
        .{ .text = "VPS-to-local browser steering (zsb over the tunnel) + sidebar sort stickiness fix", .ticket = "" },
    } },
    .{ .ver = "0.28.264", .items = &.{
        .{ .text = "Per-session docked Edge browser pane promoted to stable (Ctrl+Shift+O)", .ticket = "" },
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
        if (entry.items.len == 0) {
            @compileError("CHANGELOG entry " ++ entry.ver ++ " in src/changelog.zig is empty; use .items bullets, never a bare .summary");
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

fn changelogEntryTopPad() i32 {
    return uiScaled(6);
}

fn changelogEntryBottomPad() i32 {
    return uiScaled(6);
}

fn changelogMinRowH() i32 {
    return uiScaled(30);
}

fn changelogSummaryWidth(overlay_w: i32) i32 {
    return @max(1, overlay_w - 142 - 120);
}

fn changelogSummaryRight(ox: i32, overlay_w: i32, has_ticket: bool) i32 {
    return if (has_ticket) ox + overlay_w - 142 else ox + overlay_w - 18;
}

fn changelogBulletIndent() i32 {
    return uiScaled(16);
}

fn changelogBulletGap() i32 {
    return uiScaled(4);
}

fn changelogBulletRightPad(has_ticket: bool) i32 {
    return if (has_ticket) uiScaled(42) else uiScaled(18);
}

fn changelogBulletTextWidth(summary_w: i32, has_ticket: bool) i32 {
    const overlay_w = summary_w + 142 + 120;
    const left_offset = 120 + changelogBulletIndent();
    return @max(1, overlay_w - left_offset - changelogBulletRightPad(has_ticket));
}

fn appendChangelogBulletText(buf: []u16, text: []const u8) i32 {
    var n: usize = 0;
    if (n < buf.len) {
        buf[n] = '-';
        n += 1;
    }
    if (n < buf.len) {
        buf[n] = ' ';
        n += 1;
    }
    for (text) |c| {
        if (n >= buf.len) break;
        buf[n] = @intCast(c);
        n += 1;
    }
    return @intCast(n);
}

fn changelogBulletHeightWithHdc(hdc: HANDLE, text: []const u8, text_w: i32) i32 {
    if (text_w <= 0 or hdc == null) return uiScaled(22);
    var buf: [1024]u16 = undefined;
    const n = appendChangelogBulletText(&buf, text);
    var rc = RECT{ .left = 0, .top = 0, .right = text_w, .bottom = 0 };
    _ = DrawTextW(hdc, @ptrCast(&buf), n, &rc, DT_CALCRECT | DT_WORDBREAK | DT_NOPREFIX);
    return @max(uiScaled(18), rc.bottom - rc.top);
}

fn drawAsciiBulletLong(hdc: HANDLE, text: []const u8, rc: *RECT, flags: u32) void {
    var buf: [1024]u16 = undefined;
    const n = appendChangelogBulletText(&buf, text);
    _ = DrawTextW(hdc, @ptrCast(&buf), n, rc, flags);
}

fn changelogEntryHeightWithHdc(hdc: HANDLE, idx: usize, summary_w: i32) i32 {
    const min_row_h = changelogMinRowH();
    if (idx >= CHANGELOG.len or summary_w <= 0 or hdc == null) return min_row_h;

    const old_font = SelectObject(hdc, uiFontSubtitle());
    defer _ = SelectObject(hdc, old_font);

    const entry = CHANGELOG[idx];
    if (entry.items.len > 0) {
        var total_h = changelogEntryTopPad() + uiScaled(22);
        for (entry.items) |item| {
            const bullet_w = changelogBulletTextWidth(summary_w, item.ticket.len > 0);
            total_h += changelogBulletGap() + changelogBulletHeightWithHdc(hdc, item.text, bullet_w);
        }
        total_h += changelogEntryBottomPad();
        return @max(min_row_h, total_h);
    }

    var buf: [1024]u16 = undefined;
    var n: usize = 0;
    for (entry.summary) |c| {
        if (n >= buf.len) break;
        buf[n] = @intCast(c);
        n += 1;
    }

    var rc = RECT{ .left = 0, .top = 0, .right = summary_w, .bottom = 0 };
    _ = DrawTextW(hdc, @ptrCast(&buf), @intCast(n), &rc, DT_CALCRECT | DT_WORDBREAK | DT_NOPREFIX);
    const wrapped_h = @max(0, rc.bottom - rc.top);
    return @max(min_row_h, changelogEntryTopPad() + wrapped_h + changelogEntryBottomPad());
}

fn changelogEntryHeight(idx: usize, summary_w: i32) i32 {
    const hdc = GetDC(app_state.g_main_hwnd);
    if (hdc == null) return changelogMinRowH();
    defer _ = ReleaseDC(app_state.g_main_hwnd, hdc);
    return changelogEntryHeightWithHdc(hdc, idx, summary_w);
}

fn changelogEntryYRange(idx: usize, summary_w: i32) ChangelogEntryRange {
    var top: i32 = 0;
    var i: usize = 0;
    while (i < idx and i < CHANGELOG.len) : (i += 1) {
        top += changelogEntryHeight(i, summary_w);
    }
    const h = if (idx < CHANGELOG.len) changelogEntryHeight(idx, summary_w) else 0;
    return .{ .top = top, .h = h };
}

fn changelogIndexAtContentY(content_y: i32, summary_w: i32) ?i32 {
    if (content_y < 0) return null;
    var cy: i32 = 0;
    for (0..CHANGELOG.len) |idx| {
        const h = changelogEntryHeight(idx, summary_w);
        if (content_y >= cy and content_y < cy + h) return @intCast(idx);
        cy += h;
    }
    return null;
}

fn changelogTotalContentHeightWithHdc(hdc: HANDLE, summary_w: i32) i32 {
    var total: i32 = 0;
    for (0..CHANGELOG.len) |idx| {
        total += changelogEntryHeightWithHdc(hdc, idx, summary_w);
    }
    return total;
}

fn changelogTotalContentHeight(summary_w: i32) i32 {
    const hdc = GetDC(app_state.g_main_hwnd);
    if (hdc == null) return changelogMinRowH() * @as(i32, @intCast(CHANGELOG.len));
    defer _ = ReleaseDC(app_state.g_main_hwnd, hdc);
    return changelogTotalContentHeightWithHdc(hdc, summary_w);
}

fn clampChangelogState(view_h: i32, max_scroll: i32, summary_w: i32) void {
    const total_rows: i32 = @intCast(CHANGELOG.len);
    if (total_rows <= 0) {
        app_state.g_changelog_scroll = 0;
        app_state.g_changelog_sel = 0;
        return;
    }

    if (app_state.g_changelog_sel < 0) app_state.g_changelog_sel = 0;
    if (app_state.g_changelog_sel >= total_rows) app_state.g_changelog_sel = total_rows - 1;

    const sel_range = changelogEntryYRange(@intCast(app_state.g_changelog_sel), summary_w);
    const sel_top = sel_range.top;
    const sel_bottom = sel_range.top + sel_range.h;

    if (sel_top < app_state.g_changelog_scroll) {
        app_state.g_changelog_scroll = sel_top;
    } else if (sel_bottom > app_state.g_changelog_scroll + view_h) {
        app_state.g_changelog_scroll = sel_bottom - view_h;
    }

    if (app_state.g_changelog_scroll < 0) app_state.g_changelog_scroll = 0;
    if (app_state.g_changelog_scroll > max_scroll) app_state.g_changelog_scroll = max_scroll;
}

pub fn calcChangelogLayout() ChangelogLayout {
    var win_rc: RECT = std.mem.zeroes(RECT);
    _ = GetClientRect(app_state.g_main_hwnd, &win_rc);
    const win_w = win_rc.right - win_rc.left;
    const win_h = win_rc.bottom - win_rc.top;

    var overlay_w: i32 = 760;
    if (win_w < overlay_w + 32) overlay_w = @max(360, win_w - 32);
    const title_h: i32 = 46;
    const bottom_pad: i32 = 12;
    const summary_w = changelogSummaryWidth(overlay_w);
    const total_content_h = changelogTotalContentHeight(summary_w);
    var available_h: i32 = win_h - 80 - title_h - bottom_pad;
    const min_view_h = uiScaled(120);
    if (available_h < min_view_h) available_h = min_view_h;
    const view_h: i32 = @min(total_content_h, available_h);
    const max_scroll: i32 = @max(0, total_content_h - view_h);
    clampChangelogState(view_h, max_scroll, summary_w);

    const overlay_h: i32 = title_h + view_h + bottom_pad;
    return .{
        .ox = @divFloor(win_w - overlay_w, 2),
        .oy = @divFloor(win_h - overlay_h, 2),
        .overlay_w = overlay_w,
        .overlay_h = overlay_h,
        .title_h = title_h,
        .bottom_pad = bottom_pad,
        .view_h = view_h,
        .max_scroll = max_scroll,
    };
}

pub fn changelogContainsPoint(mx: i32, my: i32) bool {
    const layout = calcChangelogLayout();
    return mx >= layout.ox and mx < layout.ox + layout.overlay_w and
        my >= layout.oy and my < layout.oy + layout.overlay_h;
}

pub fn changelogHitTest(mx: i32, my: i32) ?ChangelogHit {
    const layout = calcChangelogLayout();
    if (mx < layout.ox or mx >= layout.ox + layout.overlay_w) return null;
    const rows_top = layout.oy + layout.title_h;
    const rows_bottom = rows_top + layout.view_h;
    if (my < rows_top or my >= rows_bottom) return null;
    const content_y = my - rows_top + app_state.g_changelog_scroll;
    const summary_w = changelogSummaryWidth(layout.overlay_w);
    const idx = changelogIndexAtContentY(content_y, summary_w) orelse return null;
    const uidx: usize = @intCast(idx);
    const entry = CHANGELOG[uidx];
    if (entry.items.len == 0) return .{ .idx = idx, .ticket = entry.ticket };

    const range = changelogEntryYRange(uidx, summary_w);
    const local_y = content_y - range.top;
    const hdc = GetDC(app_state.g_main_hwnd);
    if (hdc == null) return .{ .idx = idx, .ticket = "" };
    defer _ = ReleaseDC(app_state.g_main_hwnd, hdc);
    const old_font = SelectObject(hdc, uiFontSubtitle());
    defer _ = SelectObject(hdc, old_font);

    var bullet_y = changelogEntryTopPad() + uiScaled(22) + changelogBulletGap();
    const bullet_left = layout.ox + 120 + changelogBulletIndent();
    const bullet_right = layout.ox + layout.overlay_w - 18;
    for (entry.items) |item| {
        const bullet_w = changelogBulletTextWidth(summary_w, item.ticket.len > 0);
        const bullet_h = changelogBulletHeightWithHdc(hdc, item.text, bullet_w);
        if (local_y >= bullet_y and local_y < bullet_y + bullet_h) {
            const ticket = if (mx >= bullet_left and mx < bullet_right) item.ticket else "";
            return .{ .idx = idx, .ticket = ticket };
        }
        bullet_y += bullet_h + changelogBulletGap();
    }
    return .{ .idx = idx, .ticket = "" };
}

pub fn moveChangelogSelection(action: WPARAM) void {
    const layout = calcChangelogLayout();
    const summary_w = changelogSummaryWidth(layout.overlay_w);
    switch (action) {
        0 => app_state.g_changelog_sel = if (app_state.g_changelog_sel <= 0) @as(i32, @intCast(CHANGELOG.len)) - 1 else app_state.g_changelog_sel - 1,
        1 => app_state.g_changelog_sel = if (app_state.g_changelog_sel >= @as(i32, @intCast(CHANGELOG.len)) - 1) 0 else app_state.g_changelog_sel + 1,
        2 => {
            var target_scroll = app_state.g_changelog_scroll - layout.view_h;
            if (target_scroll < 0) target_scroll = 0;
            app_state.g_changelog_scroll = target_scroll;
            app_state.g_changelog_sel = changelogIndexAtContentY(target_scroll, summary_w) orelse 0;
        },
        3 => {
            var target_scroll = app_state.g_changelog_scroll + layout.view_h;
            if (target_scroll > layout.max_scroll) target_scroll = layout.max_scroll;
            app_state.g_changelog_scroll = target_scroll;
            app_state.g_changelog_sel = changelogIndexAtContentY(target_scroll, summary_w) orelse (@as(i32, @intCast(CHANGELOG.len)) - 1);
        },
        4 => app_state.g_changelog_sel = 0,
        5 => app_state.g_changelog_sel = @as(i32, @intCast(CHANGELOG.len)) - 1,
        else => {},
    }
    clampChangelogState(layout.view_h, layout.max_scroll, summary_w);
}

pub fn openAsciiUrlInDefaultBrowser(url: []const u8) void {
    if (url.len == 0) return;
    var wbuf: [512]u16 = undefined;
    const n = @min(url.len, wbuf.len - 1);
    for (0..n) |i| wbuf[i] = @intCast(url[i]);
    wbuf[n] = 0;
    _ = ShellExecuteW(null, L("open"), @ptrCast(&wbuf), null, null, SW_SHOW);
}

pub fn changelogDefaultTicket(uidx: usize) []const u8 {
    if (uidx >= CHANGELOG.len) return "";
    const entry = CHANGELOG[uidx];
    if (entry.items.len > 0) {
        for (entry.items) |item| {
            if (item.ticket.len > 0) return item.ticket;
        }
        return "";
    }
    return entry.ticket;
}

pub fn openChangelogTicket(idx: i32) void {
    if (idx < 0) return;
    const uidx: usize = @intCast(idx);
    const ticket = changelogDefaultTicket(uidx);
    if (ticket.len == 0) return;
    openAsciiUrlInDefaultBrowser(ticket);
}

pub fn paintChangelogOverlay(hdc: HANDLE) void {
    if (!app_state.g_changelog_active) return;
    const layout = calcChangelogLayout();
    const overlay_radius: i32 = 14;
    const font_title = uiFontTitle();
    const font_subtitle = uiFontSubtitle();
    const old_font = SelectObject(hdc, font_title);
    defer _ = SelectObject(hdc, old_font);

    drawModalShadow(hdc, layout.ox, layout.oy, layout.overlay_w, layout.overlay_h, overlay_radius);

    const border_col = customColorOr("overlay_border", if (app_state.g_light_theme) RGB(200, 200, 200) else if (app_state.g_edge_gray_theme) RGB(86, 86, 86) else if (app_state.g_mid_theme) RGB(110, 110, 110) else RGB(80, 80, 80));
    const border_br = CreateSolidBrush(border_col);
    const border_pen = CreatePen(0, 1, border_col);
    const old_border_br = SelectObject(hdc, border_br);
    const old_border_pen = SelectObject(hdc, border_pen);
    _ = @import("smooth.zig").drawRoundRect(hdc, layout.ox - 1, layout.oy - 1, layout.ox + layout.overlay_w + 1, layout.oy + layout.overlay_h + 1, overlay_radius, overlay_radius);
    _ = SelectObject(hdc, old_border_br);
    _ = SelectObject(hdc, old_border_pen);
    _ = DeleteObject(border_br);
    _ = DeleteObject(border_pen);

    const bg_col = customColorOr("overlay_bg", if (app_state.g_light_theme) RGB(249, 249, 249) else if (app_state.g_edge_gray_theme) RGB(51, 51, 51) else if (app_state.g_mid_theme) RGB(68, 68, 68) else RGB(40, 40, 40));
    const bg_br = CreateSolidBrush(bg_col);
    const bg_pen = CreatePen(0, 1, bg_col);
    const old_bg_br = SelectObject(hdc, bg_br);
    const old_bg_pen = SelectObject(hdc, bg_pen);
    _ = @import("smooth.zig").drawRoundRect(hdc, layout.ox, layout.oy, layout.ox + layout.overlay_w, layout.oy + layout.overlay_h, overlay_radius, overlay_radius);
    _ = SelectObject(hdc, old_bg_br);
    _ = SelectObject(hdc, old_bg_pen);
    _ = DeleteObject(bg_br);
    _ = DeleteObject(bg_pen);

    _ = SetBkMode(hdc, TRANSPARENT);

    _ = SelectObject(hdc, font_title);
    _ = SetTextColor(hdc, if (app_state.g_light_theme) RGB(25, 25, 25) else RGB(245, 245, 245));
    var title_rc = RECT{ .left = layout.ox + 18, .top = layout.oy + 8, .right = layout.ox + layout.overlay_w - 170, .bottom = layout.oy + layout.title_h - 6 };
    drawAscii(hdc, "Changelog", &title_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX);
    _ = SelectObject(hdc, font_subtitle);
    _ = SetTextColor(hdc, if (app_state.g_light_theme) RGB(120, 120, 120) else RGB(140, 140, 150));
    var hint_rc = RECT{ .left = layout.ox + layout.overlay_w - 170, .top = layout.oy + 8, .right = layout.ox + layout.overlay_w - 16, .bottom = layout.oy + layout.title_h - 6 };
    drawAscii(hdc, "Enter opens ticket", &hint_rc, DT_SINGLELINE | DT_VCENTER | DT_RIGHT | DT_NOPREFIX);

    var div_rc = RECT{ .left = layout.ox + 1, .top = layout.oy + layout.title_h - 1, .right = layout.ox + layout.overlay_w - 1, .bottom = layout.oy + layout.title_h };
    const div_br = CreateSolidBrush(if (app_state.g_light_theme) RGB(228, 228, 228) else RGB(60, 60, 60));
    _ = FillRect(hdc, &div_rc, div_br);
    _ = DeleteObject(div_br);

    const text_col = customColorOr("text", if (app_state.g_light_theme) RGB(40, 40, 40) else RGB(225, 225, 225));
    const dim_col = customColorOr("tab_text_dim", if (app_state.g_light_theme) RGB(110, 110, 110) else RGB(150, 150, 155));
    const link_col = customColorOr("accent", RGB(79, 168, 255));
    const rows_top = layout.oy + layout.title_h;
    const rows_bottom = rows_top + layout.view_h;
    const summary_w = changelogSummaryWidth(layout.overlay_w);
    const total_content_h = changelogTotalContentHeightWithHdc(hdc, summary_w);
    const top_pad = changelogEntryTopPad();
    const bottom_pad = changelogEntryBottomPad();
    const line_h = uiScaled(22);
    const saved_rows_dc = SaveDC(hdc);
    if (saved_rows_dc != 0) {
        _ = IntersectClipRect(hdc, layout.ox + 1, rows_top, layout.ox + layout.overlay_w - 1, rows_bottom);
    }
    var cy: i32 = 0;
    for (0..CHANGELOG.len) |idx| {
        const entry = CHANGELOG[idx];
        const h = changelogEntryHeightWithHdc(hdc, idx, summary_w);
        const ry = rows_top + cy - app_state.g_changelog_scroll;

        if (ry + h <= rows_top or ry >= rows_bottom) {
            cy += h;
            continue;
        }

        const idx_i: i32 = @intCast(idx);
        const selected = idx_i == app_state.g_changelog_sel;

        if (selected) {
            var sel_rc = RECT{ .left = layout.ox + 1, .top = ry, .right = layout.ox + layout.overlay_w - 1, .bottom = ry + h };
            const sel_br = CreateSolidBrush(customColorOr("selected_bg", RGB(0, 122, 204)));
            _ = FillRect(hdc, &sel_rc, sel_br);
            _ = DeleteObject(sel_br);
        }

        var ver_buf: [16]u8 = undefined;
        const ver_txt = std.fmt.bufPrint(&ver_buf, "v{s}", .{entry.ver}) catch entry.ver;
        _ = SelectObject(hdc, font_title);
        _ = SetTextColor(hdc, if (selected) RGB(255, 255, 255) else text_col);
        var ver_rc = RECT{ .left = layout.ox + 22, .top = ry + top_pad, .right = layout.ox + 112, .bottom = ry + top_pad + line_h };
        drawAscii(hdc, ver_txt, &ver_rc, DT_SINGLELINE | DT_NOPREFIX);

        _ = SelectObject(hdc, font_subtitle);
        _ = SetTextColor(hdc, if (selected) RGB(230, 238, 248) else dim_col);
        if (entry.items.len == 0) {
            const summary_right = changelogSummaryRight(layout.ox, layout.overlay_w, entry.ticket.len > 0);
            var summary_rc = RECT{ .left = layout.ox + 120, .top = ry + top_pad, .right = summary_right, .bottom = ry + h - bottom_pad };
            drawAsciiLong(hdc, entry.summary, &summary_rc, DT_WORDBREAK | DT_NOPREFIX);

            if (entry.ticket.len > 0) {
                _ = SetTextColor(hdc, if (selected) RGB(255, 255, 255) else link_col);
                var link_rc = RECT{ .left = layout.ox + layout.overlay_w - 138, .top = ry + top_pad, .right = layout.ox + layout.overlay_w - 18, .bottom = ry + top_pad + line_h };
                drawAscii(hdc, "open ticket ->", &link_rc, DT_SINGLELINE | DT_RIGHT | DT_NOPREFIX);
            }
        } else {
            var bullet_y = ry + top_pad + line_h + changelogBulletGap();
            const bullet_left = layout.ox + 120 + changelogBulletIndent();
            for (entry.items) |item| {
                const has_ticket = item.ticket.len > 0;
                const bullet_w = changelogBulletTextWidth(summary_w, has_ticket);
                const bullet_h = changelogBulletHeightWithHdc(hdc, item.text, bullet_w);
                _ = SetTextColor(hdc, if (selected) RGB(230, 238, 248) else dim_col);
                var bullet_rc = RECT{ .left = bullet_left, .top = bullet_y, .right = bullet_left + bullet_w, .bottom = bullet_y + bullet_h };
                drawAsciiBulletLong(hdc, item.text, &bullet_rc, DT_WORDBREAK | DT_NOPREFIX);

                if (has_ticket) {
                    _ = SetTextColor(hdc, if (selected) RGB(255, 255, 255) else link_col);
                    var arrow_rc = RECT{ .left = layout.ox + layout.overlay_w - 42, .top = bullet_y, .right = layout.ox + layout.overlay_w - 18, .bottom = bullet_y + line_h };
                    drawAscii(hdc, "->", &arrow_rc, DT_SINGLELINE | DT_RIGHT | DT_NOPREFIX);
                }

                bullet_y += bullet_h + changelogBulletGap();
            }
        }

        cy += h;
    }
    if (saved_rows_dc != 0) _ = RestoreDC(hdc, saved_rows_dc);

    if (total_content_h > layout.view_h) {
        const track_top = layout.oy + layout.title_h + 4;
        const track_bottom = layout.oy + layout.overlay_h - 6;
        const track_h = track_bottom - track_top;
        if (track_h > 0) {
            const thumb_h = @max(24, @divTrunc(track_h * layout.view_h, total_content_h));
            const scroll_space = track_h - thumb_h;
            const thumb_top = track_top + if (layout.max_scroll == 0) 0 else @divTrunc(scroll_space * app_state.g_changelog_scroll, layout.max_scroll);
            var thumb_rc = RECT{ .left = layout.ox + layout.overlay_w - 7, .top = thumb_top, .right = layout.ox + layout.overlay_w - 3, .bottom = thumb_top + thumb_h };
            const thumb_br = CreateSolidBrush(customColorOr("scrollbar_thumb", RGB(145, 145, 145)));
            _ = FillRect(hdc, &thumb_rc, thumb_br);
            _ = DeleteObject(thumb_br);
        }
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
