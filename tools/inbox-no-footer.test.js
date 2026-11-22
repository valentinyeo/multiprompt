const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const source = (name) => fs.readFileSync(path.join(__dirname, '..', 'src', name), 'utf8');

test('Inbox footer draws only unexpired transient feedback in every state', () => {
    const inbox = source('inbox.zig');
    const painter = inbox.split('pub fn paintInbox(hdc: HANDLE) void {')[1]?.split('\npub fn openInbox(')[0];
    assert.ok(painter, 'production Inbox painter must exist');
    const footer = painter.split('    var footer = RECT')[1];
    assert.ok(footer, 'production footer must exist');
    assert.match(footer, /^\{[^\n]+\};\s*if \(app_state\.g_cap_msg_len > 0 and app_state\.g_cap_msg_until > GetTickCount64\(\)\) \{\s*_ = DrawTextW\(hdc, &app_state\.g_cap_msg_text, @intCast\(app_state\.g_cap_msg_len\), &footer, DT_SINGLELINE \| DT_VCENTER \| DT_NOPREFIX \| DT_END_ELLIPSIS \| @import\("win32\.zig"\)\.DT_CENTER\);\s*\}\s*\}\s*$/);
});

test('Inbox keyboard routes remain available', () => {
    const shortcuts = source('shortcuts.zig');
    const section = shortcuts.split('if (app_state.g_inbox_active and !app_state.g_search_active and app_state.g_edit_hwnd == null) {')[1]?.split('if (kb.vkCode >= 0x31')[0];
    assert.ok(section, 'Inbox keyboard routing must exist');
    for (const [key, action] of [['0x0D', 4], ['0x26', 0], ['0x28', 1], ['0x1B', 5], ['0x71', 28]]) {
        assert.match(section, new RegExp(`kb\\.vkCode == ${key}[^\\n]*\\n\\s*_ = PostMessageW\\(app_state\\.g_main_hwnd, WM_APP_INBOX_KEY, ${action}, 0\\)`));
    }
    assert.match(section, /kb\.vkCode == 0x46[^\n]*\n\s*_ = PostMessageW\(app_state\.g_main_hwnd, WM_APP_INBOX_FILTER_OPEN, 0, 0\)/);
    assert.match(section, /kb\.vkCode == 0x1B[^\n]*\n\s*_ = PostMessageW\(app_state\.g_main_hwnd, WM_APP_INBOX_FILTER_CLOSE, 0, 0\)/);
    for (const [key, action] of [['0x55', 23], ['0x55', 25], ['0x45', 24]]) {
        assert.match(shortcuts, new RegExp(`kb\\.vkCode == ${key}[^\\n]*\\n\\s*_ = PostMessageW\\(app_state\\.g_main_hwnd, WM_APP_INBOX_KEY, ${action}, 0\\)`));
    }
});
