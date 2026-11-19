import pathlib
import subprocess
import tempfile


def replay(root, witnesses, function, preserved=False):
    history = (root / "src/chat_history.zig").read_text()
    session = (root / "src/chat_session.zig").read_text()
    render = (root / "src/chat_render.zig").read_text()
    source = '''const std = @import("std");
const RECT = struct { left: i32 = 0, top: i32 = 0, right: i32 = 800, bottom: i32 = 600 };
const md = struct {
    const Block = struct { start: usize = 0, role: enum { prose, tool } = .prose, first: bool = true, message_id: u64 = 0, source_offset: u64 = 0 };
};
const chat_history = struct {
    pub const ReadBoundary = struct { index: ?usize = null, unknown: bool = false };
'''
    source += next(line for line in history.splitlines() if line.startswith("pub const ReadAnchor = struct")) + "\n"
    for name in ("scrollAnchor", "readAnchor", "readAnchorTop", "followBottom", "scrollAfterLayout", "openScroll"):
        source += function(history, name) + "\n"
    source += '''pub const Anchor = struct { index: usize, offset: i32 };
};
const app_state = struct {
    var g_chat_browser_swap = struct { shell_id: u32 = 0 }{};
    var g_chat_active = true;
    var g_chat_transcript_hwnd: ?usize = 1;
    var active_shell: usize = 0;
    var shell_count: usize = 1;
    var g_chat_scroll_y: i32 = 0;
    var g_chat_content_h: i32 = 0;
    var g_chat_layout_top_pad: i32 = 0;
    var g_chat_top_pad: i32 = 0;
    var g_chat_read_open_pending = false;
    var g_chat_read_open_ready = false;
    var g_chat_scroll_bottom_pending = false;
    var g_chat_scrolled_up = false;
    var g_chat_read_hold = true;
    var g_chat_new_messages = struct { fn count(_: @This()) usize { return 0; } }{};
    var g_chat_read_anchor: ?chat_history.ReadAnchor = null;
    var g_chat_prepend_pending = false;
    var g_chat_block_count: usize = 2;
    var g_chat_blocks = [_]md.Block{ .{ .message_id = 1 }, .{ .message_id = 2 }, .{ .message_id = 3 } };
    var g_chat_layout_rects = [_]RECT{.{}, .{}, .{}};
    var g_chat_layout_reuse: usize = 0;
    var g_chat_layout_dirty = false;
    var g_chat_echo_layout: [0]RECT = .{};
    var g_chat_echo_layout_count: usize = 0;
    var g_chat_batch_boundary: chat_history.ReadBoundary = .{};
    var g_chat_batch_divider_y: i32 = 0;
    var g_chat_read_boundary: chat_history.ReadBoundary = .{};
    var g_chat_read_divider_y: i32 = 0;
};
var viewport: i32 = 600;
var next_top: i32 = 0;
var next_height: i32 = 0;
var next_newest: i32 = 0;
var next_append: ?i32 = null;
var next_boundary: chat_history.ReadBoundary = .{};
fn chatViewClientRect(rc: *RECT) void { rc.* = .{ .bottom = viewport }; }
fn chatMinScroll() i32 { return @min(0, app_state.g_chat_content_h - viewport); }
fn chatMaxScroll() i32 { return @max(0, app_state.g_chat_content_h - viewport); }
fn refreshChatBlockCache(_: bool) bool { return true; }
fn chatEchoMatchActive() void {}
fn verboseLoggingEnabled() bool { return false; }
fn chatNewMessagesChanged(_: bool) void {}
fn chatReadBoundary() chat_history.ReadBoundary { return next_boundary; }
fn chatScrollStateChanged(_: i32) void {}
fn InvalidateRect(_: ?usize, _: ?*const RECT, _: i32) i32 { return 1; }
fn chatRelayout(_: i32) void {
    app_state.g_chat_layout_rects[0] = .{ .top = next_top, .bottom = next_newest };
    app_state.g_chat_layout_rects[1] = .{ .top = next_newest, .bottom = next_append orelse next_height };
    if (next_append) |top| {
        app_state.g_chat_layout_rects[2] = .{ .top = top, .bottom = next_height };
        app_state.g_chat_block_count = 3;
    }
    app_state.g_chat_content_h = next_height;
    app_state.g_chat_layout_top_pad = app_state.g_chat_top_pad;
    app_state.g_chat_read_boundary = next_boundary;
}
'''
    for name in ("refreshChatTranscript", "chatRelayoutPreservingScroll"):
        source += function(session, name).replace('@import("chat_render.zig").chatViewClientRect', 'chatViewClientRect') + "\n"
    source += function(render, "chatSetTopPad") + "\n"
    for index, w in enumerate(witnesses):
        before = "null" if w["previous_boundary"] < 0 else str(w["previous_boundary"])
        after = "null" if w["next_boundary"] < 0 else str(w["next_boundary"])
        call = "refreshChatTranscript(false)" if w["property"].startswith("refreshChatTranscript/") else "chatRelayoutPreservingScroll(800, viewport)"
        source += f'''test "counterexample {index}" {{
    viewport = {w['viewport']};
    app_state.g_chat_read_anchor = null;
    app_state.g_chat_block_count = 2;
    next_append = null;
    app_state.g_chat_scroll_y = {w['old_scroll']};
    app_state.g_chat_content_h = {w['old_h']};
    app_state.g_chat_layout_top_pad = {w['pad']};
    app_state.g_chat_top_pad = {w['pad'] + w['delta']};
    app_state.g_chat_layout_rects[0] = .{{ .top = {w['old_top']}, .bottom = {w['old_newest']} }};
    app_state.g_chat_layout_rects[1] = .{{ .top = {w['old_newest']}, .bottom = {w['old_h']} }};
    app_state.g_chat_read_boundary = .{{ .index = {before} }};
    app_state.g_chat_read_divider_y = {w['divider']};
    next_boundary = .{{ .index = {after} }};
    next_top = {w['new_top']};
    next_height = {w['new_h']};
    next_newest = {w['new_newest']};
    {call};
    const actual = app_state.g_chat_layout_rects[1].top - app_state.g_chat_scroll_y;
    try std.testing.expectEqual(@as(i32, {w['before_y'] if preserved else w['after_y']}), actual);
    try std.testing.expect(actual {'==' if preserved else '!='} {w['before_y']});
}}
'''
    if preserved:
        source += '''test "cached layout top padding moves scroll with the held message" {
    viewport = 100;
    app_state.g_chat_block_count = 2;
    app_state.g_chat_layout_reuse = 2;
    app_state.g_chat_scroll_y = 0;
    app_state.g_chat_content_h = 200;
    app_state.g_chat_layout_top_pad = 0;
    app_state.g_chat_top_pad = 0;
    app_state.g_chat_read_boundary = .{};
    app_state.g_chat_layout_rects[0] = .{ .top = 0, .bottom = 20 };
    app_state.g_chat_layout_rects[1] = .{ .top = 20, .bottom = 200 };
    chatSetTopPad(10);
    try std.testing.expectEqual(@as(i32, 20), app_state.g_chat_layout_rects[1].top - app_state.g_chat_scroll_y);
}
'''
        for call in ("refreshChatTranscript(false)", "chatRelayoutPreservingScroll(800, viewport)"):
            source += f'''test "hold the initial message through append and remeasurement via {call}" {{
    viewport = 100;
    app_state.g_chat_read_anchor = null;
    app_state.g_chat_block_count = 2;
    app_state.g_chat_scroll_y = 0;
    app_state.g_chat_content_h = 200;
    app_state.g_chat_read_boundary = .{{}};
    app_state.g_chat_layout_rects[0] = .{{ .top = 0, .bottom = 20 }};
    app_state.g_chat_layout_rects[1] = .{{ .top = 20, .bottom = 200 }};
    next_top = 0;
    next_newest = 20;
    next_height = 220;
    next_append = 40;
    next_boundary = .{{}};
    {call};
    try std.testing.expectEqual(@as(u64, 2), app_state.g_chat_read_anchor.?.message_id);
    next_newest = 30;
    next_append = 60;
    {call};
    try std.testing.expectEqual(@as(i32, 20), app_state.g_chat_layout_rects[1].top - app_state.g_chat_scroll_y);
    try std.testing.expectEqual(@as(u64, 2), app_state.g_chat_read_anchor.?.message_id);
}}
'''
    with tempfile.TemporaryDirectory(prefix="chat-still-replay-") as directory:
        path = pathlib.Path(directory)
        (path / "replay.zig").write_text(source)
        result = subprocess.run(["zig", "test", "-j1", "replay.zig"], cwd=directory, capture_output=True, text=True, timeout=90)
        if result.returncode:
            raise ValueError("Counterexample did not replay against the production functions (exit " + str(result.returncode) + "):\n" + result.stdout + result.stderr)
        print("REPLAY", result.stderr.strip())
