import fs from 'node:fs';
import path from 'node:path';
const root = process.argv[2];
if (!root) throw new Error('usage: everyday-performance-profile.mjs ROOT');
const targets = {
  'main.zig': ['wndProc'],
  'diagnostics.zig': ['debugLog'],
  'console.zig': ['switchToShell'],
  'chat_session.zig': ['chatFileOnReady', 'refreshChatBlockCache', 'refreshChatTranscript'],
  'chat_render.zig': ['chatRelayout', 'chatPaintTranscriptContent'],
  'chat_composer.zig': ['layoutChatControls', 'chatComposerSubclassProc'],
  'session.zig': ['saveSession'],
  'chat_capture.zig': ['captureChatTranscript'],
  'dwrite_text.zig': ['draw', 'prepare'],
};
for (const [file, functions] of Object.entries(targets)) {
  const filename = path.join(root, 'src', file);
  let source = fs.readFileSync(filename, 'utf8');
  for (const name of functions) {
    const signature = new RegExp(`(fn ${name}\\([^\\n]+\\{)`);
    if (!signature.test(source)) throw new Error(`Unknown profile boundary ${file}:${name}`);
    source = source.replace(signature, `$1\n    const everyday_span = @import("everyday_profile.zig").start();\n    defer @import("everyday_profile.zig").end("${file}:${name}", everyday_span);`);
  }
  fs.writeFileSync(filename, source);
}
fs.writeFileSync(path.join(root, 'src/everyday_profile.zig'), `const std = @import("std");
const win = @import("win32.zig");
extern "kernel32" fn GetCurrentThreadId() callconv(win.WINAPI) u32;
threadlocal var emitting: bool = false;
pub fn start() i64 {
    var tick: i64 = 0;
    _ = win.QueryPerformanceCounter(&tick);
    return tick;
}
pub fn end(comptime name: []const u8, before: i64) void {
    if (emitting) return;
    emitting = true;
    defer emitting = false;
    const after = start();
    var frequency: i64 = 1;
    _ = win.QueryPerformanceFrequency(&frequency);
    const us = @divTrunc((after -| before) * 1_000_000, @max(1, frequency));
    if (us < 1000) return;
    var buf: [256]u8 = undefined;
    @import("diagnostics.zig").debugLog(std.fmt.bufPrint(&buf, "PERFSPAN name={s} start={d} end={d} us={d} tid={d}", .{ name, before, after, us, GetCurrentThreadId() }) catch return);
}
`);
