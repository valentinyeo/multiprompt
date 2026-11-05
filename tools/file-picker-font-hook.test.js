const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');

const root = path.resolve(__dirname, '..');
const source = fs.readFileSync(path.join(root, 'src/fonts.zig'), 'utf8');
const begin = source.indexOf('fn fileDialogFontHook(');
const end = source.indexOf('\npub fn openFileName(', begin);

const fixture = `const std = @import("std");
var dialog_hook: ?*anyopaque = @ptrFromInt(1);
var unhooks: usize = 0;
var fonts: usize = 0;
var forwarded: usize = 0;
const w = struct {
    const HANDLE = ?*anyopaque;
    const WPARAM = usize;
    const LPARAM = isize;
    const LRESULT = isize;
    const WINAPI: std.builtin.CallingConvention = .c;
    fn UnhookWindowsHookEx(hook: HANDLE) i32 {
        std.debug.assert(hook == @as(HANDLE, @ptrFromInt(1)));
        std.debug.assert(dialog_hook == null);
        unhooks += 1;
        return 1;
    }
    fn EnumChildWindows(hwnd: HANDLE, callback: *const fn (HANDLE, LPARAM) callconv(WINAPI) i32, lp: LPARAM) i32 {
        return callback(hwnd, lp);
    }
    fn CallNextHookEx(_: HANDLE, _: i32, _: WPARAM, _: LPARAM) LRESULT {
        forwarded += 1;
        return 123;
    }
};
fn setControlFont(_: w.HANDLE) void {
    std.debug.assert(dialog_hook == null);
    std.debug.assert(unhooks == 1);
    fonts += 1;
}
fn setDialogChildFont(hwnd: w.HANDLE, _: w.LPARAM) callconv(w.WINAPI) i32 {
    setControlFont(hwnd);
    return 1;
}
test "file picker keeps its initial font and never intercepts reactivation" {
    try std.testing.expectEqual(@as(isize, 123), fileDialogFontHook(-1, 2, 0));
    try std.testing.expectEqual(@as(usize, 0), fonts);
    try std.testing.expectEqual(@as(usize, 0), unhooks);
    try std.testing.expectEqual(@as(isize, 123), fileDialogFontHook(5, 2, 0));
    try std.testing.expectEqual(@as(usize, 2), fonts);
    try std.testing.expectEqual(@as(usize, 1), unhooks);
    try std.testing.expectEqual(@as(isize, 123), fileDialogFontHook(5, 2, 0));
    try std.testing.expectEqual(@as(usize, 2), fonts);
    try std.testing.expectEqual(@as(usize, 1), unhooks);
    try std.testing.expectEqual(@as(usize, 3), forwarded);
}
`;

test('executed production picker hook detaches before styling and preserves hook chaining', () => {
  assert.ok(begin >= 0 && end > begin, 'the file picker needs a one-shot activation hook');
  const picker = source.slice(end, source.indexOf('\npub fn editMessage(', end));
  assert.match(picker, /SetWindowsHookExW\(5, &fileDialogFontHook/);
  const production = source.slice(begin, end);
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'picker-font-hook-'));
  try {
    const file = path.join(dir, 'test.zig');
    fs.writeFileSync(file, fixture + production);
    const result = spawnSync(process.env.ZIG || 'zig', ['test', file], { encoding: 'utf8', timeout: 120000 });
    assert.equal(result.status, 0, result.stdout + result.stderr);
    assert.match(result.stderr, /All 1 tests passed/);
    const detach = '        dialog_hook = null;\n        _ = w.UnhookWindowsHookEx(hook);\n';
    assert.ok(production.includes(detach));
    fs.writeFileSync(file, fixture + production.replace(detach, ''));
    const negative = spawnSync(process.env.ZIG || 'zig', ['test', file], { encoding: 'utf8', timeout: 120000 });
    assert.notEqual(negative.status, 0, 'retaining the activation hook must fail');
    assert.match(negative.stderr, /AssertionFailure|panic|FAIL/);
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
});
