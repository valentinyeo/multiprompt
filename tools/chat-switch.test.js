const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const source = require('./app-source').readAppSource();
function body(name, text = source) {
  const start = text.indexOf(`fn ${name}(`);
  assert.notEqual(start, -1, name);
  const end = text.indexOf('\nfn ', start + 1);
  return text.slice(start, end < 0 ? text.length : end);
}
function paintFirst(text) {
  const switching = body('switchToShell', text);
  const chat = switching.slice(switching.indexOf('} else if (g_chat_active) {'), switching.indexOf('} else if (shells[idx].hwnd'));
  assert.match(chat, /chatDeferTranscriptLoad\(\);[\s\S]*layoutChatControls\(\);/);
  assert.doesNotMatch(chat, /positionActiveBrowser|parkInactiveBrowserPanes|updateBrowserVisibility|refreshChatTranscript/);
  for (const fn of ['positionActiveBrowser', 'updateBrowserVisibility', 'adoptBrowserTick', 'browserHealthTick', 'refreshChatTranscript', 'chatFileOnReady']) {
    assert.match(body(fn, text), /if \(g_chat_browser_swap\.shell_id != 0\) return;/);
  }
  const paint = body('chatTranscriptWndProc', text);
  assert.match(paint, /EndPaint\(hwnd, &ps\);\s*if \(painted\) chatSwitchDidPaint\(\);/);
  assert.match(paint, /painted = BitBlt\([^]*\) != 0;/);
  assert.match(body('chatSwitchDidPaint', text), /\.didPaint\(shells\[active_shell\]\.shell_id\)[\s\S]*SetTimer\(g_main_hwnd, TIMER_CHAT_BROWSER_SWAP, 0, null\)/);
  assert.match(body('chatSwitchBrowserTick', text), /\.take\(shells\[active_shell\]\.shell_id\)[\s\S]*updateBrowserVisibility\(\)/);
}

test('chat paints before the coalesced browser exchange, including stale refresh/adoption callbacks', () => {
  paintFirst(source);
  const baseline = `fn switchToShell(idx: u32) void {
    if (want_chat != g_chat_active) {
        if (want_chat) openChatView() else closeChatView();
    } else if (g_chat_active) {
        if (browserSlotReserved()) {
            parkInactiveBrowserPanes();
            if (webView2OwnsActiveShell()) positionWebView2() else positionActiveBrowser();
        } else {
            hideAllBrowserChrome();
        }
        updateBrowserVisibility();
        if (browserPaneActive()) armBrowserVisibilitySettle(12);
        chatDraftBindToActive();
        layoutChatControls();
        chatDeferTranscriptLoad();
    } else if (shells[idx].hwnd != null) {}
}`;
  assert.throws(() => paintFirst(baseline), assert.AssertionError);
});

test('switch restores the unified parsed cache and defers disk/remote IO', () => {
  const restore = body('chatDeferTranscriptLoad');
  assert.match(restore, /chatHistoryEntry\(chatCacheIdentity\(\)\)/);
  assert.match(restore, /history.text.items/);
  assert.doesNotMatch(source, /g_chat_tab_cache|g_chat_file_token/);
  assert.doesNotMatch(restore, /chat_transcript\.parse|captureChatTranscript|readFile|fetchAcPersistent/);
  assert.match(body('chatFileFetchThread'), /history.apply/);
  assert.match(body('chatFileFetchThread'), /chatHistoryRead[\s\S]*History.decode/);
  assert.doesNotMatch(body('chatHistoryEntry'), /chatHistoryRead|History.decode/);
  assert.doesNotMatch(body('chatFileOnReady'), /chat_transcript\.parse|fetchAcPersistent|Sleep\(/);
  assert.match(body('refreshChatBlockCache'), /chatStoreTabCache\(from_file\)/);
});

test('foreign HWND mutations and bridge/OS launches never wait on the UI thread', () => {
  assert.match(body('setBrowserWindowPosAsync'), /SWP_ASYNCWINDOWPOS \| SWP_NOACTIVATE/);
  assert.match(body('positionActiveBrowser'), /SWP_NOZORDER \| SWP_NOACTIVATE \| SWP_SHOWWINDOW/);
  assert.match(body('layoutChatControls'), /BeginDeferWindowPos\(2\)[\s\S]*EndDeferWindowPos/);
  assert.match(body('dockBrowserWindow'), /std\.Thread\.spawn\([^]*browserDockWorker/);
  assert.doesNotMatch(body('dockBrowserWindow'), /SetWindowLongPtrW|SetParent|DwmSetWindowAttribute/);
  assert.match(body('browserDockWorker'), /SetWindowLongPtrW[\s\S]*WM_APP_BROWSER_DOCKED/);
  assert.match(body('finishBrowserDock'), /findShellById\(job.shell_id\)/);
  assert.match(body('spawnBrowserCliHidden'), /std\.Thread\.spawn\([^]*spawnBrowserCliWorker/);
  assert.match(body('shellExecuteEdgeUrl'), /std\.Thread\.spawn\([^]*browserLaunchWorker/);
  assert.doesNotMatch(body('shellExecuteEdgeUrl'), /ShellExecuteW\(/);
  assert.doesNotMatch(body('chatSwitchBrowserTick'), /Sleep\(|WaitFor|SendMessage|SetFocus|SetForegroundWindow/);
});

test('pane follows without requesting browser focus and debug timings sample actual placement', () => {
  assert.match(body('switchToShell'), /cancelPendingNativeBrowserFocus\(\)/);
  assert.match(body('switchToShell'), /if \(!defer_browser and idx < shell_count and shells\[idx\]\.hwnd == null/);
  assert.doesNotMatch(body('openChatView'), /shells\[active_shell\]\.hwnd == null/);
  assert.match(body('updateBrowserVisibility'), /if \(g_chat_active\) launchBrowserForShellFromRequest/);
  assert.doesNotMatch(body('chatSwitchBrowserTick'), /requestNativeBrowserFocus|focusActiveBrowserPane/);
  const log = body('chatSwitchLogBrowserShown');
  assert.match(log, /verboseLoggingEnabled\(\)/);
  assert.match(log, /GetWindowRect[\s\S]*std\.meta\.eql\(actual, expected\)/);
  assert.match(log, /\[switch\] chat painted in \{d\} ms, browser shown in \{d\} ms/);
});
