const std = @import("std");
const app_state = @import("app_state.zig");
const chat_composer = @import("chat_composer.zig");
const chat_queue = @import("chat_queue.zig");
const chat_send = @import("chat_send.zig");
const chat_session = @import("chat_session.zig");
const chat_transcript = @import("chat_transcript.zig");

const win32 = @import("win32.zig");
const HANDLE = win32.HANDLE;
const RECT = win32.RECT;
const POINT = win32.POINT;
const TRANSPARENT = win32.TRANSPARENT;
const DT_SINGLELINE = win32.DT_SINGLELINE;
const DT_VCENTER = win32.DT_VCENTER;
const DT_CENTER = win32.DT_CENTER;
const DT_NOPREFIX = win32.DT_NOPREFIX;
const DT_END_ELLIPSIS = win32.DT_END_ELLIPSIS;
const SetBkMode = win32.SetBkMode;
const SetTextColor = win32.SetTextColor;
const SelectObject = win32.SelectObject;
const DeleteObject = win32.DeleteObject;
const InvalidateRect = win32.InvalidateRect;

const uiScaled = @import("drawing.zig").uiScaled;
const RGB = @import("startup.zig").RGB;
const chatDrawText = @import("dwrite_text.zig").draw;
const customColorOr = @import("themes.zig").customColorOr;
const themeConsoleFg = @import("themes.zig").themeConsoleFg;
const fillRoundRectAA = @import("smooth.zig").fillRoundRect;
const chatSurfaceBorderW = @import("window_layout.zig").chatSurfaceBorderW;
const chatSurfaceBorderColor = @import("window_layout.zig").chatSurfaceBorderColor;
const chatSurfaceRadius = @import("window_layout.zig").chatSurfaceRadius;
const chatRelayoutPreservingScroll = @import("chat_session.zig").chatRelayoutPreservingScroll;
const showHeaderNoticeAscii = @import("console.zig").showHeaderNoticeAscii;

pub const ICON_SEND_NOW: u16 = 0xE724;
pub const ICON_EDIT: u16 = 0xE70F;
pub const ICON_DELETE: u16 = 0xE74D;

var queue: chat_queue.Queue = .{};

fn metrics() chat_queue.Metrics {
    return .{ .pad = uiScaled(10), .header = uiScaled(30), .row = uiScaled(24), .button = uiScaled(18), .gap = uiScaled(6) };
}

fn sync() void {
    var next = chat_queue.Queue{ .collapsed = queue.collapsed };
    if (app_state.g_chat_active and app_state.active_shell < app_state.shell_count) {
        const shell = &app_state.shells[app_state.active_shell];
        var key_buf: [app_state.CHAT_OUTBOX_KEY_CAP]u8 = undefined;
        const named = shell.tmux_session_len > 0 or shell.chat_id != 0;
        const key = if (named) chat_send.chatOutboxKeyForShell(app_state.active_shell, &key_buf) else key_buf[0..0];
        if (key.len > 0) {
            for (app_state.g_chat_outbox.items) |entry| {
                if (entry.state != .queued) continue;
                if (!std.mem.eql(u8, entry.key[0..@as(usize, entry.key_len)], key)) continue;
                next.add(entry.id, entry.text);
            }
        }
    }
    if (next.count == 0) next.collapsed = false;
    if (queue.collapsed == next.collapsed and queue.sameAs(&next)) return;
    queue = next;
}

pub fn refresh() void {
    sync();
}

pub fn isVisible() bool {
    sync();
    return queue.visible();
}

pub fn rowCount() usize {
    sync();
    return queue.rows();
}

fn reservedFor(rows: usize) i32 {
    return chat_queue.cardHeight(rows, metrics()) + uiScaled(6);
}

pub fn reservedHeight() i32 {
    sync();
    if (!queue.visible()) return 0;
    return reservedFor(queue.rows());
}

fn toRect(box: chat_queue.Box) RECT {
    return .{ .left = box.left, .top = box.top, .right = box.right, .bottom = box.bottom };
}

fn insetRect(rc: RECT, edge: i32) RECT {
    return .{ .left = rc.left + edge, .top = rc.top + edge, .right = rc.right - edge, .bottom = rc.bottom - edge };
}

fn trayCard(layout: app_state.ChatViewLayout) ?chat_queue.Box {
    const card = layout.composer_card;
    const origin = layout.transcript_window;
    const height = chat_queue.cardHeight(queue.rows(), metrics());
    if (height <= 0) return null;
    const bottom = card.top - origin.top - uiScaled(6);
    const top = bottom - height;
    if (bottom <= 0 or top < 0) return null;
    return .{ .left = card.left - origin.left, .top = top, .right = card.right - origin.left, .bottom = bottom };
}

fn titleFont() HANDLE {
    if (app_state.g_chat_rich_fonts[12] == null) app_state.g_chat_rich_fonts[12] = @import("fonts.zig").chat(-uiScaled(@max(9, app_state.g_chat_font_pt)), true, false, false, .{});
    return app_state.g_chat_rich_fonts[12];
}

fn metadataFont() HANDLE {
    if (app_state.g_chat_rich_fonts[13] == null) app_state.g_chat_rich_fonts[13] = @import("fonts.zig").chat(-uiScaled(@max(8, app_state.g_chat_font_pt - 3)), false, false, false, .{});
    return app_state.g_chat_rich_fonts[13];
}

fn subtitleColor() u32 {
    return customColorOr("subtitle", if (app_state.g_light_theme) RGB(85, 98, 115) else RGB(167, 180, 198));
}

fn inkColor() u32 {
    return customColorOr("text", themeConsoleFg());
}

fn countPill(hdc: HANDLE, box: chat_queue.Box) void {
    var label: [8]u8 = undefined;
    const text = chat_queue.countLabel(queue.total(), &label);
    if (text.len == 0) return;
    const radius = @max(1, @divTrunc(box.bottom - box.top, 2));
    fillRoundRectAA(hdc, toRect(box), radius, chatSurfaceBorderColor());
    const old_font = SelectObject(hdc, metadataFont());
    defer _ = SelectObject(hdc, old_font);
    _ = SetTextColor(hdc, inkColor());
    var wide: [8]u16 = undefined;
    const len = std.unicode.utf8ToUtf16Le(&wide, text) catch 0;
    var text_rc = toRect(box);
    _ = chatDrawText(hdc, &wide, @intCast(len), &text_rc, DT_SINGLELINE | DT_VCENTER | DT_CENTER | DT_NOPREFIX);
}

fn chevron(hdc: HANDLE, box: chat_queue.Box) void {
    var canvas = @import("smooth.zig").Canvas.init(hdc);
    defer canvas.deinit();
    const cx = @divTrunc(box.left + box.right, 2);
    const cy = @divTrunc(box.top + box.bottom, 2);
    const arm = uiScaled(4);
    const lift = uiScaled(2);
    const down = [_]POINT{
        .{ .x = cx - arm, .y = cy - lift },
        .{ .x = cx, .y = cy + lift },
        .{ .x = cx + arm, .y = cy - lift },
    };
    const up = [_]POINT{
        .{ .x = cx - arm, .y = cy + lift },
        .{ .x = cx, .y = cy - lift },
        .{ .x = cx + arm, .y = cy + lift },
    };
    canvas.strokePolyline(if (queue.collapsed) &down else &up, subtitleColor(), @floatFromInt(@max(1, uiScaled(1))));
}

fn button(hdc: HANDLE, font: HANDLE, box: chat_queue.Box, glyph: u16) void {
    const old_font = SelectObject(hdc, font);
    defer _ = SelectObject(hdc, old_font);
    _ = SetTextColor(hdc, subtitleColor());
    const wide = [_]u16{glyph};
    var rc = toRect(box);
    _ = chatDrawText(hdc, &wide, 1, &rc, DT_SINGLELINE | DT_VCENTER | DT_CENTER | DT_NOPREFIX);
}

pub fn paint(hdc: HANDLE) void {
    sync();
    if (!queue.visible()) return;
    const card = trayCard(chat_composer.chatViewLayout()) orelse return;
    const found = chat_queue.layout(card, queue.rows(), metrics());
    const edge = chatSurfaceBorderW();
    const radius = chatSurfaceRadius();
    fillRoundRectAA(hdc, toRect(found.card), radius, chatSurfaceBorderColor());
    fillRoundRectAA(hdc, insetRect(toRect(found.card), edge), @max(0, radius - edge), app_state.g_chat_input_color);
    _ = SetBkMode(hdc, TRANSPARENT);
    const old_font = SelectObject(hdc, titleFont());
    defer _ = SelectObject(hdc, old_font);
    _ = SetTextColor(hdc, inkColor());
    var wide: [96]u16 = undefined;
    const title = std.unicode.utf8ToUtf16LeStringLiteral("Queued Messages");
    @memcpy(wide[0..title.len], title);
    var title_rc = toRect(found.title);
    _ = chatDrawText(hdc, &wide, @intCast(title.len), &title_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX | DT_END_ELLIPSIS);
    countPill(hdc, found.badge);
    _ = SelectObject(hdc, metadataFont());
    _ = SetTextColor(hdc, subtitleColor());
    const subtitle = std.unicode.utf8ToUtf16LeStringLiteral("Sends after agent finishes working");
    @memcpy(wide[0..subtitle.len], subtitle);
    var subtitle_rc = toRect(found.subtitle);
    _ = chatDrawText(hdc, &wide, @intCast(subtitle.len), &subtitle_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX | DT_END_ELLIPSIS);
    chevron(hdc, found.chevron);
    const icons = @import("fonts.zig").messageMenuIconFont();
    defer _ = DeleteObject(icons);
    for (0..found.row_count) |index| {
        const entry = queue.entries[index];
        _ = SelectObject(hdc, metadataFont());
        _ = SetTextColor(hdc, inkColor());
        var row_rc = toRect(found.rows[index]);
        row_rc.right = found.actions[index][0].left - uiScaled(6);
        const text = entry.textSlice();
        _ = chatDrawText(hdc, text.ptr, @intCast(text.len), &row_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX | DT_END_ELLIPSIS);
        button(hdc, icons, found.actions[index][0], ICON_SEND_NOW);
        button(hdc, icons, found.actions[index][1], ICON_EDIT);
        button(hdc, icons, found.actions[index][2], ICON_DELETE);
    }
}

fn relayoutNow() void {
    chat_composer.layoutChatControls();
    if (app_state.g_chat_transcript_hwnd != null) _ = InvalidateRect(app_state.g_chat_transcript_hwnd, null, 0);
    if (app_state.g_main_hwnd != null) _ = InvalidateRect(app_state.g_main_hwnd, null, 0);
}

fn entryAt(index: usize) ?app_state.ChatOutboxEntry {
    const id = queue.idAt(index) orelse return null;
    const at = chat_send.chatOutboxIndexById(id) orelse return null;
    return app_state.g_chat_outbox.items[at];
}

const QueueOp = enum { send_now, edit_cancel };

const QueueJob = struct {
    key: chat_transcript.Identity,
    message: [81]u8,
    op: [20]u8,
};

fn opName(op: QueueOp) []const u8 {
    return if (op == .send_now) "message_send_now" else "message_edit";
}

fn startQueueOp(entry: app_state.ChatOutboxEntry, op: QueueOp) bool {
    if (!entry.message_v1 or entry.message_wire_id[0] == 0) return false;
    const idx = chat_send.chatOutboxShellForKey(entry.key[0..@as(usize, entry.key_len)]) orelse return false;
    const key = chat_session.chatFileIdentityForShell(idx);
    if (key.sid[0] == 0 or key.tmux[0] == 0) return false;
    const job = std.heap.page_allocator.create(QueueJob) catch return false;
    job.* = .{ .key = key, .message = entry.message_wire_id, .op = @splat(0) };
    const name = opName(op);
    @memcpy(job.op[0..name.len], name);
    const thread = std.Thread.spawn(.{}, queueOpThread, .{job}) catch {
        std.heap.page_allocator.destroy(job);
        return false;
    };
    thread.detach();
    return true;
}

fn queueOpThread(job: *QueueJob) void {
    const a = std.heap.page_allocator;
    defer a.destroy(job);
    const query = std.json.Stringify.valueAlloc(a, .{
        .op = std.mem.sliceTo(&job.op, 0),
        .message_protocol = 1,
        .id = job.key.shell_id,
        .tmux = std.mem.sliceTo(&job.key.tmux, 0),
        .provider = job.key.provider(),
        .sid = std.mem.sliceTo(&job.key.sid, 0),
        .message_id = std.mem.sliceTo(&job.message, 0),
    }, .{}) catch return;
    defer a.free(query);
    var wire: std.ArrayList(u8) = .empty;
    defer wire.deinit(a);
    _ = chat_session.chatHistoryPersistent(job.key.checked() orelse return, query, 4096, &wire, null);
}

fn sendNow(index: usize) void {
    const entry = entryAt(index) orelse return;
    if (!startQueueOp(entry, .send_now)) {
        if (entry.message_v1) {
            showHeaderNoticeAscii("Could not ask this chat to take the queued message now", 4000, true);
            return;
        }
        chat_send.chatEchoPushQueuedNowForId(entry.id);
    }
    relayoutNow();
}

fn edit(index: usize) void {
    const entry = entryAt(index) orelse return;
    if (entry.text.len == 0) return;
    if (!chat_composer.chatComposerTakeQueuedText(entry.text)) return;
    if (startQueueOp(entry, .edit_cancel)) {
        chat_send.chatEchoDropLocal(entry.id);
    } else {
        chat_send.chatEchoRemove(entry.id);
    }
    relayoutNow();
    showHeaderNoticeAscii("Editing a queued message", 2500, false);
}

fn remove(index: usize) void {
    const entry = entryAt(index) orelse return;
    chat_send.chatEchoRemove(entry.id);
    relayoutNow();
}

pub fn click(x: i32, y: i32) bool {
    sync();
    if (!queue.visible()) return false;
    const card = trayCard(chat_composer.chatViewLayout()) orelse return false;
    const found = chat_queue.layout(card, queue.rows(), metrics());
    const hit = chat_queue.hitAt(found, x, y) orelse return false;
    switch (hit.action) {
        .chevron => {
            queue.toggle();
            relayoutNow();
        },
        .send_now => sendNow(hit.row),
        .edit => edit(hit.row),
        .delete => remove(hit.row),
    }
    return true;
}

pub fn reset() void {
    queue = .{};
}

test "MUBO-594 an empty queue takes no room above the message box" {
    const old_active = app_state.g_chat_active;
    const old_shell = app_state.active_shell;
    const old_count = app_state.shell_count;
    defer {
        app_state.g_chat_active = old_active;
        app_state.active_shell = old_shell;
        app_state.shell_count = old_count;
        reset();
    }
    reset();
    app_state.g_chat_active = true;
    app_state.active_shell = 0;
    app_state.shell_count = 0;
    try std.testing.expectEqual(@as(i32, 0), reservedHeight());
    try std.testing.expect(!isVisible());
    try std.testing.expectEqual(@as(usize, 0), rowCount());
}

test "MUBO-594 the tray grows with its rows and shrinks to its header when collapsed" {
    const open = reservedFor(3);
    const shut = reservedFor(0);
    try std.testing.expect(open > shut);
    try std.testing.expect(shut > 0);
    try std.testing.expectEqual(open - shut, @as(i32, 3) * uiScaled(24));
}
