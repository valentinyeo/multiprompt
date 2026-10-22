const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const source = require('./app-source').readAppSource();

test("URL scanning retains long OAuth links across narrow console wraps", () => {
  assert.match(source, /while \(hops < 16 and next_ri < rows_to_read and n < raw\.len\)/);
  assert.match(source, /Browser didn't open\?/);
  assert.match(source, /Paste code here if prompted/);
});

test("Claude bare-c copy falls back to the Windows clipboard", () => {
  assert.match(source, /WM_APP_COPY_CLAUDE_LOGIN_URL/);
  assert.match(source, /fn copyClaudeLoginUrlFromActiveShell\(\) bool/);
  assert.match(source, /setUnicodeClipboardTextWithRetry\(url\)/);
  assert.match(source, /shells\[active_shell\]\.ai_agent == 1/);
});

test("explicit console copy can recover the login URL without a selection", () => {
  const handlerStart = source.indexOf("WM_APP_COPY =>");
  const handlerEnd = source.indexOf("WM_APP_DICTATION_TOGGLE =>", handlerStart);
  assert.ok(handlerStart >= 0 && handlerEnd > handlerStart);
  const handler = source.slice(handlerStart, handlerEnd);
  assert.match(handler, /result == \.no_selection/);
  assert.match(handler, /copyClaudeLoginUrlFromActiveShell\(\)/);
});

test("a physical shell-link click activates and focuses its fresh browser tab", () => {
  const start = source.indexOf("fn openUrlAtScreenPoint(");
  const end = source.indexOf("const URL_PICKER_MAX: u32 = 32;", start);
  assert.ok(start >= 0 && end > start);
  const handler = source.slice(start, end);
  assert.match(handler, /link_detect\.at\(row_slices\[0\.\.count\]/);
  assert.match(handler, /openClickedLink\(final_buf\[0\.\.m\]\);/);
  const shared = source.slice(source.indexOf("fn openClickedLink("), start);
  assert.match(shared, /if \(!openSessionLink\(active_shell, bytes\[0\.\.n\]\)\) return;/);
  assert.match(shared, /requestWebView2Focus\(\).*requestNativeBrowserFocus\(\)/);
});

test("Chat View paints, hovers, and opens links through the shell-link route", () => {
  const start = source.indexOf("fn chatTranscriptWndProc(");
  const end = source.indexOf("fn ensureChatTranscriptClassRegistered(", start);
  const handler = source.slice(start, end);
  assert.match(handler, /WM_MOUSEMOVE => \{[\s\S]*chatTranscriptLinkAt\(hwnd, GET_X\(lp\), GET_Y\(lp\)\)/);
  assert.match(handler, /WM_LBUTTONDOWN => \{[\s\S]*if \(chatTranscriptLinkAt[\s\S]*openClickedLink\(g_chat_capture\[link.start\.\.link.end\]\)/);
  assert.match(source, /chatFlowBlock\(hdc, text, block, text_rc, true/);
  assert.match(source, /return chatFlowText\(hdc, text, area, block.role == \.code/);
  assert.match(source, /customColorOr\("link"/);
  assert.match(source, /g_chat_hover_link\.\?\.start == offset \+ link\.\?\.start/);
});

test("the dedicated mouse thread catches Ctrl+click before the temporary hook is ready", () => {
  const start = source.indexOf("fn staleAltMouseHookProc(");
  const end = source.indexOf("fn staleAltMouseHookThread(", start);
  assert.ok(start >= 0 && end > start);
  const hook = source.slice(start, end);
  assert.match(hook, /physical_ctrl_down/);
  assert.match(hook, /ctrlClickOverActiveShell\(ms\.pt\)/);
  assert.match(hook, /routeCtrlClickUrl\(ms\.pt\)/);
  assert.match(hook, /g_ctrl_click_down_swallowed\.swap\(false, \.acq_rel\)/,
    "the matching mouse-up must be swallowed even if Ctrl is released first");
  assert.doesNotMatch(hook, /ai_agent/,
    "physical link routing must not depend on which agent printed the URL");
});

test("agent browser navigation remains background-safe", () => {
  assert.match(source, /fn navigateBrowserPane\(idx: u32, raw_url: \[\]const u8\) void \{\s+navigateBrowserPaneWithActivation\(idx, raw_url, false\);/);
});
