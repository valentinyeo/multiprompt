const std = @import("std");
const w = @import("win32.zig");
const fonts = @import("fonts.zig");
const smooth = @import("smooth.zig");
const avatar = @import("bot_avatar.zig");
extern "user32" fn SetFocus(w.HANDLE) callconv(w.WINAPI) w.HANDLE;
extern "user32" fn ShowWindow(w.HANDLE, i32) callconv(w.WINAPI) w.BOOL;
extern "user32" fn RemovePropW(w.HANDLE, w.LPCWSTR) callconv(w.WINAPI) w.HANDLE;
const L = std.unicode.utf8ToUtf16LeStringLiteral;

pub const Presence = enum { unknown, offline, online };
pub const ActionResult = enum { accepted, pending, unsupported, failed };
pub const Member = struct {
    id: []const u8,
    alias: []const u16,
    name: []const u16,
    appearance: avatar.Appearance,
    name_color: u32,
    presence: Presence,
};
pub const Author = struct {
    name: []const u16,
    appearance: avatar.Appearance,
    name_color: u32,
};
pub const Message = struct {
    text: []const u16,
    author: ?Author,
    time: []const u16,
};
pub const ViewModel = struct {
    room_id: []const u8,
    name: []const u16,
    revision: u64,
    members: []const Member,
    candidates: []const Member,
    messages: []const Message,
};
pub const ActionKind = enum { create, edit, submit, restart };
pub const ActionToken = struct { generation: u64, serial: u64, kind: ActionKind };
pub const Callbacks = struct {
    context: *anyopaque,
    create: *const fn (*anyopaque, ActionToken, []const u16, []const []const u8) ActionResult,
    edit: *const fn (*anyopaque, ActionToken, []const u8, u64, []const u16, []const []const u8) ActionResult,
    submit: *const fn (*anyopaque, ActionToken, []const u8, u64, []const u16) ActionResult,
    restart: *const fn (*anyopaque, ActionToken, []const u8, []const u8) ActionResult,
};

const StoredId = struct {
    bytes: [128]u8 = undefined,
    len: usize = 0,
    fn slice(self: *const StoredId) []const u8 { return self.bytes[0..self.len]; }
};

const Mode = enum { room, create, edit };
const empty_rect = w.RECT{ .left = 0, .top = 0, .right = 0, .bottom = 0 };
var registered = false;

fn sameRoom(left: *const ViewModel, right: *const ViewModel) bool {
    return std.mem.eql(u8, left.room_id, right.room_id);
}

fn validModel(model: *const ViewModel) bool {
    if (model.members.len > 64 or model.candidates.len > 768 or model.name.len > 256 or model.room_id.len > 128) return false;
    for (model.members) |member| if (member.id.len == 0 or member.id.len > 128) return false;
    for (model.candidates) |member| if (member.id.len == 0 or member.id.len > 128) return false;
    return true;
}

pub fn minimumSize(dpi: u32) w.SIZE {
    const scale: i32 = @intCast(@min(@max(dpi, 48), 768));
    return .{ .cx = @divTrunc(544 * scale, 96), .cy = @divTrunc(536 * scale, 96) };
}

pub const View = struct {
    hwnd: w.HANDLE = null,
    composer: w.HANDLE = null,
    name_edit: w.HANDLE = null,
    search_edit: w.HANDLE = null,
    old_composer: isize = 0,
    old_name: isize = 0,
    old_search: isize = 0,
    edit_font: w.HANDLE = null,
    composer_brush: w.HANDLE = null,
    dialog_brush: w.HANDLE = null,
    model: *const ViewModel,
    callbacks: Callbacks,
    dpi: i32 = 96,
    mode: Mode = .room,
    scroll: i32 = 0,
    max_scroll: i32 = 0,
    list_scroll: usize = 0,
    selected: [64]StoredId = @splat(.{}),
    selected_count: usize = 0,
    picker: bool = false,
    picker_index: usize = 0,
    picker_base: usize = 0,
    dialog_index: usize = 0,
    generation: u64 = 1,
    serial: u64 = 0,
    pending: ?ActionToken = null,
    edit_revision: u64 = 0,
    presented_revision: u64 = 0,
    focus_target: usize = 0,
    too_small: bool = false,
    result: ?ActionResult = null,
    title_hit: w.RECT = empty_rect,
    send_hit: w.RECT = empty_rect,
    restart_hit: w.RECT = empty_rect,
    restart_member: ?[]const u8 = null,
    cancel_hit: w.RECT = empty_rect,
    confirm_hit: w.RECT = empty_rect,
    picker_hits: [64]w.RECT = @splat(empty_rect),
    picker_members: [64]usize = @splat(0),
    picker_count: usize = 0,
    dialog_hits: [64]w.RECT = @splat(empty_rect),
    dialog_members: [64]usize = @splat(0),
    dialog_count: usize = 0,

    pub fn create(self: *View, parent: w.HANDLE, model: *const ViewModel, callbacks: Callbacks) bool {
        if (!validModel(model)) return false;
        self.* = .{ .model = model, .callbacks = callbacks };
        if (!registered) {
            const cls = w.WNDCLASSEXW{ .cbSize = @sizeOf(w.WNDCLASSEXW), .style = 0, .lpfnWndProc = windowProc, .cbClsExtra = 0, .cbWndExtra = 0, .hInstance = w.GetModuleHandleW(null), .hIcon = null, .hCursor = w.LoadCursorW(null, @ptrFromInt(32512)), .hbrBackground = null, .lpszMenuName = null, .lpszClassName = L("MultiPromptRoomView"), .hIconSm = null };
            if (w.RegisterClassExW(&cls) == 0) return false;
            registered = true;
        }
        self.hwnd = w.CreateWindowExW(0, L("MultiPromptRoomView"), L("Room"), w.WS_CHILD | w.WS_TABSTOP | w.WS_CLIPCHILDREN | w.WS_CLIPSIBLINGS, 0, 0, 1, 1, parent, null, w.GetModuleHandleW(null), null) orelse return false;
        _ = w.SetWindowLongPtrW(self.hwnd, -21, @bitCast(@intFromPtr(self)));
        const dpi = w.GetDpiForWindow(self.hwnd);
        self.dpi = if (dpi == 0) 96 else @intCast(dpi);
        self.edit_font = fonts.create(-self.px(14), 0, 0, 0, 400, 0, 0, 0, 0, 0, 0, 5, 0, null);
        self.composer_brush = w.CreateSolidBrush(rgb(0x1e1e1e));
        self.dialog_brush = w.CreateSolidBrush(rgb(0x181818));
        self.composer = self.makeEdit(true);
        self.name_edit = self.makeEdit(false);
        self.search_edit = self.makeEdit(false);
        if (self.composer == null or self.name_edit == null or self.search_edit == null or self.edit_font == null or self.composer_brush == null or self.dialog_brush == null) {
            self.destroy();
            return false;
        }
        self.old_composer = subclass(self.composer, self);
        self.old_name = subclass(self.name_edit, self);
        self.old_search = subclass(self.search_edit, self);
        if (self.old_composer == 0 or self.old_name == 0 or self.old_search == 0) {
            self.destroy();
            return false;
        }
        _ = w.SendMessageW(self.search_edit, 0x00c5, 256, 0);
        _ = w.SendMessageW(self.search_edit, 0x1501, 1, @bitCast(@intFromPtr(L("Search agents"))));
        self.layout();
        return true;
    }

    fn makeEdit(self: *View, multi: bool) w.HANDLE {
        const style: u32 = w.WS_CHILD | w.WS_TABSTOP | (if (multi) w.ES_MULTILINE | w.ES_AUTOVSCROLL | w.ES_WANTRETURN else w.ES_AUTOHSCROLL);
        const edit = w.CreateWindowExW(0, L("EDIT"), L(""), style, 0, 0, 1, 1, self.hwnd, null, w.GetModuleHandleW(null), null);
        if (edit != null and self.edit_font != null) _ = w.SendMessageW(edit, 0x0030, @intFromPtr(self.edit_font.?), 1);
        return edit;
    }

    pub fn destroy(self: *View) void {
        if (self.hwnd != null) _ = w.DestroyWindow(self.hwnd);
        self.hwnd = null;
        self.composer = null;
        self.name_edit = null;
        self.search_edit = null;
        self.releaseResources();
    }

    fn releaseResources(self: *View) void {
        if (self.edit_font != null) _ = w.DeleteObject(self.edit_font);
        if (self.composer_brush != null) _ = w.DeleteObject(self.composer_brush);
        if (self.dialog_brush != null) _ = w.DeleteObject(self.dialog_brush);
        self.edit_font = null;
        self.composer_brush = null;
        self.dialog_brush = null;
    }

    pub fn show(self: *View, visible: bool) void {
        _ = ShowWindow(self.hwnd, if (visible) w.SW_SHOWNOACTIVATE else w.SW_HIDE);
        if (visible) self.layout();
    }

    pub fn focus(self: *View) void {
        self.setFocus(if (self.too_small) self.hwnd else if (self.mode == .room) self.composer else self.name_edit);
    }

    pub fn showUnavailable(self: *View) void {
        self.result = .unsupported;
        self.invalidate();
    }

    pub fn setDpi(self: *View, dpi: u32) bool {
        if (dpi < 48 or dpi > 768) return false;
        const old_dpi = self.dpi;
        self.dpi = @intCast(dpi);
        const new_font = fonts.create(-self.px(14), 0, 0, 0, 400, 0, 0, 0, 0, 0, 0, 5, 0, null);
        if (new_font == null) {
            self.dpi = old_dpi;
            return false;
        }
        for ([_]w.HANDLE{ self.composer, self.name_edit, self.search_edit }) |edit| _ = w.SendMessageW(edit, 0x0030, @intFromPtr(new_font.?), 1);
        if (self.edit_font != null) _ = w.DeleteObject(self.edit_font);
        self.edit_font = new_font;
        self.layout();
        return true;
    }

    pub fn setBounds(self: *View, bounds: w.RECT) void {
        _ = w.MoveWindow(self.hwnd, bounds.left, bounds.top, @max(1, bounds.right - bounds.left), @max(1, bounds.bottom - bounds.top), 1);
        self.layout();
    }

    pub fn setModel(self: *View, model: *const ViewModel) bool {
        if (!validModel(model)) return false;
        const same = sameRoom(self.model, model);
        self.clearHits();
        if (!same) {
            self.retire();
            self.selected_count = 0;
            self.mode = .room;
            self.scroll = 0;
            self.presented_revision = 0;
            self.picker = false;
        }
        self.model = model;
        self.layout();
        return true;
    }

    pub fn completeAction(self: *View, token_value: ActionToken, result: ActionResult) void {
        const pending = self.pending orelse return;
        if (!std.meta.eql(pending, token_value)) return;
        self.result = result;
        if (result != .pending) self.pending = null;
        if (result == .accepted and (token_value.kind == .create or token_value.kind == .edit)) {
            self.mode = .room;
            self.layout();
            self.setFocus(self.composer);
        }
        self.invalidate();
    }

    pub fn setDraft(self: *View, value: [:0]const u16) bool {
        if (value.len > 65536) return false;
        var bytes: [196608]u8 = undefined;
        const len = std.unicode.utf16LeToUtf8(&bytes, value) catch return false;
        if (len > 65536 or std.mem.indexOfScalar(u16, value, 0) != null) return false;
        _ = w.SetWindowTextW(self.composer, value.ptr);
        self.clearHits();
        self.invalidate();
        return true;
    }

    pub fn draft(self: *View, buffer: []u16) ?[]const u16 {
        const len = w.GetWindowTextLengthW(self.composer);
        if (len < 0 or @as(usize, @intCast(len)) >= buffer.len) return null;
        const count = w.GetWindowTextW(self.composer, buffer.ptr, @intCast(buffer.len));
        if (count != len) return null;
        return buffer[0..@intCast(count)];
    }

    pub fn openCreate(self: *View) void {
        self.openDialog(.create);
    }

    pub fn openEdit(self: *View) void {
        self.openDialog(.edit);
    }

    fn closeDialog(self: *View) void {
        self.retire();
        self.mode = .room;
        self.layout();
        self.setFocus(self.composer);
    }

    fn openDialog(self: *View, mode: Mode) void {
        if (self.too_small) return;
        self.retire();
        self.mode = mode;
        self.edit_revision = self.model.revision;
        self.selected_count = 0;
        self.list_scroll = 0;
        self.dialog_index = 0;
        self.picker = false;
        if (mode == .edit) for (self.model.members) |member| self.toggle(member.id);
        var name: [257:0]u16 = @splat(0);
        if (mode == .edit) {
            @memcpy(name[0..self.model.name.len], self.model.name);
        }
        _ = w.SetWindowTextW(self.name_edit, &name);
        _ = w.SetWindowTextW(self.search_edit, L(""));
        self.layout();
        self.setFocus(self.name_edit);
        self.invalidate();
    }

    pub fn layout(self: *View) void {
        if (self.hwnd == null) return;
        var bounds: w.RECT = undefined;
        _ = w.GetClientRect(self.hwnd, &bounds);
        const width = @max(1, bounds.right);
        const height = @max(1, bounds.bottom);
        const minimum = minimumSize(@intCast(self.dpi));
        self.too_small = width < minimum.cx or height < minimum.cy;
        self.clearHits();
        if (self.too_small) {
            _ = ShowWindow(self.composer, w.SW_HIDE);
            _ = ShowWindow(self.name_edit, w.SW_HIDE);
            _ = ShowWindow(self.search_edit, w.SW_HIDE);
            self.invalidate();
            return;
        }
        const composer_w = @min(self.px(760), @max(self.px(100), width - self.px(32)));
        const x = @divTrunc(width - composer_w, 2);
        _ = w.MoveWindow(self.composer, x + self.px(16), height - self.px(57), @max(1, composer_w - self.px(64)), self.px(35), 1);
        const card_w = @min(self.px(520), @max(1, width - self.px(24)));
        const card_x = @divTrunc(width - card_w, 2);
        const card_top = @max(self.px(8), @divTrunc(height - self.px(520), 2));
        _ = w.MoveWindow(self.name_edit, card_x + self.px(24), card_top + self.px(68), @max(1, card_w - self.px(48)), self.px(32), 1);
        _ = w.MoveWindow(self.search_edit, card_x + self.px(24), card_top + self.px(116), @max(1, card_w - self.px(48)), self.px(32), 1);
        _ = ShowWindow(self.composer, if (self.mode == .room) w.SW_SHOWNOACTIVATE else w.SW_HIDE);
        _ = ShowWindow(self.name_edit, if (self.mode == .room) w.SW_HIDE else w.SW_SHOWNOACTIVATE);
        _ = ShowWindow(self.search_edit, if (self.mode == .room) w.SW_HIDE else w.SW_SHOWNOACTIVATE);
        self.invalidate();
    }

    fn px(self: *const View, value: i32) i32 {
        return @divTrunc(value * self.dpi, 96);
    }

    fn setFocus(self: *View, target: w.HANDLE) void {
        if (self.hwnd == null or target == null or (target != self.hwnd and w.IsChild(self.hwnd, target) == 0)) return;
        const foreground = w.GetForegroundWindow();
        if (foreground == null) return;
        const root = w.GetAncestor(self.hwnd, 2);
        if (root == null or w.GetAncestor(foreground, 2) != root) return;
        _ = SetFocus(target);
    }

    fn clearHits(self: *View) void {
        self.title_hit = empty_rect;
        self.send_hit = empty_rect;
        self.restart_hit = empty_rect;
        self.restart_member = null;
        self.cancel_hit = empty_rect;
        self.confirm_hit = empty_rect;
        self.picker_count = 0;
        self.dialog_count = 0;
    }

    fn retire(self: *View) void {
        self.generation +%= 1;
        self.pending = null;
        self.result = null;
        self.clearHits();
    }

    fn token(self: *View, kind: ActionKind) ActionToken {
        self.serial +%= 1;
        return .{ .generation = self.generation, .serial = self.serial, .kind = kind };
    }

    fn invalidate(self: *View) void {
        _ = w.InvalidateRect(self.hwnd, null, 0);
    }

    fn selectedIndex(self: *const View, id: []const u8) ?usize {
        for (self.selected[0..self.selected_count], 0..) |*item, i| if (std.mem.eql(u8, item.slice(), id)) return i;
        return null;
    }

    fn toggle(self: *View, id: []const u8) void {
        if (self.selectedIndex(id)) |i| {
            self.selected_count -= 1;
            self.selected[i] = self.selected[self.selected_count];
        } else if (self.selected_count < self.selected.len and id.len > 0 and id.len <= 128) {
            const selected = &self.selected[self.selected_count];
            @memcpy(selected.bytes[0..id.len], id);
            selected.len = id.len;
            self.selected_count += 1;
        }
        self.invalidate();
    }

    fn confirm(self: *View) void {
        if (self.pending != null or self.too_small or self.mode == .room) return;
        var name: [257]u16 = undefined;
        const size = w.GetWindowTextLengthW(self.name_edit);
        if (size <= 0 or size >= name.len or self.selected_count == 0) {
            self.result = .failed;
            self.invalidate();
            return;
        }
        const len: usize = @intCast(size);
        if (w.GetWindowTextW(self.name_edit, &name, name.len) != size) return;
        var utf8: [768]u8 = undefined;
        const bytes = std.unicode.utf16LeToUtf8(&utf8, name[0..len]) catch 0;
        if (bytes == 0 or bytes > 256) {
            self.result = .failed;
            self.invalidate();
            return;
        }
        var ids: [64][]const u8 = undefined;
        for (self.selected[0..self.selected_count], 0..) |*id, i| {
            ids[i] = id.slice();
            var found = false;
            for (self.model.candidates) |member| if (std.mem.eql(u8, member.id, ids[i])) { found = true; break; };
            for (self.model.members) |member| if (std.mem.eql(u8, member.id, ids[i])) { found = true; break; };
            if (!found) { self.result = .failed; self.invalidate(); return; }
        }
        const action = self.token(if (self.mode == .create) .create else .edit);
        self.pending = action;
        const result = if (self.mode == .create)
            self.callbacks.create(self.callbacks.context, action, name[0..len], ids[0..self.selected_count])
        else
            self.callbacks.edit(self.callbacks.context, action, self.model.room_id, self.edit_revision, name[0..len], ids[0..self.selected_count]);
        self.completeAction(action, result);
    }

    fn restart(self: *View) void {
        refreshHits(self);
        if (self.pending != null or self.too_small) return;
        const id = self.restart_member orelse return;
        const action = self.token(.restart);
        self.pending = action;
        const result = self.callbacks.restart(self.callbacks.context, action, self.model.room_id, id);
        self.completeAction(action, result);
    }

    fn submit(self: *View) void {
        if (self.pending != null or self.too_small or self.presented_revision == 0) return;
        var buffer: [65537]u16 = undefined;
        const value = self.draft(&buffer) orelse { self.result = .failed; self.invalidate(); return; };
        if (value.len == 0) return;
        var utf8: [196608]u8 = undefined;
        const bytes = std.unicode.utf16LeToUtf8(&utf8, value) catch 0;
        if (bytes == 0 or bytes > 65536) { self.result = .failed; self.invalidate(); return; }
        const action = self.token(.submit);
        self.pending = action;
        const result = self.callbacks.submit(self.callbacks.context, action, self.model.room_id, self.presented_revision, value);
        self.completeAction(action, result);
    }
};

fn subclass(hwnd: w.HANDLE, view: *View) isize {
    const original = w.GetWindowLongPtrW(hwnd, -4);
    if (original == 0) return 0;
    if (w.SetPropW(hwnd, L("MultiPromptRoomViewProc"), @ptrFromInt(@as(usize, @bitCast(original)))) == 0) return 0;
    if (w.SetPropW(hwnd, L("MultiPromptRoomViewIdentity"), view) == 0) {
        _ = RemovePropW(hwnd, L("MultiPromptRoomViewProc"));
        return 0;
    }
    if (w.SetPropW(hwnd, L("MultiPromptRoomView"), view) == 0) {
        _ = RemovePropW(hwnd, L("MultiPromptRoomViewIdentity"));
        _ = RemovePropW(hwnd, L("MultiPromptRoomViewProc"));
        return 0;
    }
    const previous = w.SetWindowLongPtrW(hwnd, -4, @bitCast(@intFromPtr(&editProc)));
    if (previous == 0) {
        _ = RemovePropW(hwnd, L("MultiPromptRoomView"));
        _ = RemovePropW(hwnd, L("MultiPromptRoomViewIdentity"));
        _ = RemovePropW(hwnd, L("MultiPromptRoomViewProc"));
    }
    return previous;
}

fn rgb(hex: u32) u32 {
    return ((hex >> 16) & 255) | (hex & 0xff00) | ((hex & 255) << 16);
}

fn drawMember(dc: w.HANDLE, rect: w.RECT, member: Member) void {
    if (member.presence != .offline) {
        avatar.draw(dc, rect, member.appearance);
        return;
    }
    const width = rect.right - rect.left;
    const height = rect.bottom - rect.top;
    if (width <= 0 or height <= 0) return;
    const memory = w.CreateCompatibleDC(dc) orelse return;
    defer _ = w.DeleteDC(memory);
    const info = w.BITMAPINFO{ .header = .{ .width = width, .height = -height } };
    var raw: ?*anyopaque = null;
    const bitmap = w.CreateDIBSection(dc, &info, 0, &raw, null, 0) orelse return;
    defer _ = w.DeleteObject(bitmap);
    const old = w.SelectObject(memory, bitmap);
    defer _ = w.SelectObject(memory, old);
    _ = w.BitBlt(memory, 0, 0, width, height, dc, rect.left, rect.top, 0x00cc0020);
    avatar.draw(memory, .{ .left = 0, .top = 0, .right = width, .bottom = height }, member.appearance);
    _ = w.GdiFlush();
    const pixels = @as([*]u32, @ptrCast(@alignCast(raw orelse return)))[0..@as(usize, @intCast(width * height))];
    for (pixels) |*pixel| {
        const c = pixel.*;
        const gray = (((c >> 16) & 255) * 30 + ((c >> 8) & 255) * 59 + (c & 255) * 11) / 100;
        pixel.* = (c & 0xff000000) | (gray << 16) | (gray << 8) | gray;
    }
    _ = w.BitBlt(dc, rect.left, rect.top, width, height, memory, 0, 0, 0x00cc0020);
}

fn inside(rect: w.RECT, x: i32, y: i32) bool {
    return x >= rect.left and x < rect.right and y >= rect.top and y < rect.bottom;
}

fn text(dc: w.HANDLE, value: []const u16, rect: w.RECT, color: u32, flags: u32) void {
    var box = rect;
    _ = w.SetTextColor(dc, rgb(color));
    _ = w.DrawTextW(dc, value.ptr, @intCast(value.len), &box, flags | w.DT_NOPREFIX);
}

fn draw(view: *View, dc: w.HANDLE, bounds: w.RECT) void {
    const black = w.CreateSolidBrush(rgb(0x000000));
    _ = w.FillRect(dc, &bounds, black);
    _ = w.DeleteObject(black);
    _ = w.SetBkMode(dc, w.TRANSPARENT);
    const body = fonts.create(-view.px(14), 0, 0, 0, 400, 0, 0, 0, 0, 0, 0, 5, 0, null);
    const heading = fonts.create(-view.px(17), 0, 0, 0, 600, 0, 0, 0, 0, 0, 0, 5, 0, null);
    const small = fonts.create(-view.px(12), 0, 0, 0, 400, 0, 0, 0, 0, 0, 0, 5, 0, null);
    const author_font = fonts.create(-view.px(13), 0, 0, 0, 600, 0, 0, 0, 0, 0, 0, 5, 0, null);
    const old = w.SelectObject(dc, body);
    defer {
        _ = w.SelectObject(dc, old);
        _ = w.DeleteObject(body);
        _ = w.DeleteObject(heading);
        _ = w.DeleteObject(small);
        _ = w.DeleteObject(author_font);
    }
    const p = view.px(1);
    const width = bounds.right;
    const height = bounds.bottom;
    if (view.too_small) {
        view.clearHits();
        text(dc, L("Make this window larger"), bounds, 0x8a8a8a, w.DT_SINGLELINE | w.DT_CENTER | w.DT_VCENTER);
        return;
    }
    if (view.mode != .room) {
        drawDialog(view, dc, bounds, body, heading, small);
        return;
    }
    view.presented_revision = view.model.revision;
    const center = @divTrunc(width, 2);
    view.title_hit = .{ .left = center - view.px(110), .top = view.px(14), .right = center + view.px(110), .bottom = view.px(56) };
    smooth.fillRoundRect(dc, view.title_hit, view.px(21), rgb(if (w.GetFocus() == view.hwnd and view.focus_target == 0) 0x8a8a8a else 0x1e1e1e));
    if (w.GetFocus() == view.hwnd and view.focus_target == 0) smooth.fillRoundRect(dc, .{ .left = view.title_hit.left + p, .top = view.title_hit.top + p, .right = view.title_hit.right - p, .bottom = view.title_hit.bottom - p }, view.px(20), rgb(0x1e1e1e));
    for (view.model.members[0..@min(2, view.model.members.len)], 0..) |member, i| {
        const x = view.title_hit.left + view.px(8 + @as(i32, @intCast(i)) * 12);
        const y = view.title_hit.top + view.px(5 + @as(i32, @intCast(i)) * 8);
        drawMember(dc, .{ .left = x, .top = y, .right = x + view.px(24), .bottom = y + view.px(24) }, member);
    }
    _ = w.SelectObject(dc, heading);
    text(dc, view.model.name, .{ .left = view.title_hit.left + view.px(46), .top = view.title_hit.top, .right = view.title_hit.right - view.px(27), .bottom = view.title_hit.bottom }, 0xf2f2f2, w.DT_SINGLELINE | w.DT_VCENTER | w.DT_END_ELLIPSIS);
    var count_buf: [16]u8 = undefined;
    const count = std.fmt.bufPrint(&count_buf, "· {d}", .{view.model.members.len + 1}) catch "";
    var count_w: [16]u16 = undefined;
    const count_len = std.unicode.utf8ToUtf16Le(&count_w, count) catch 0;
    _ = w.SelectObject(dc, small);
    text(dc, count_w[0..count_len], .{ .left = view.title_hit.right - view.px(26), .top = view.title_hit.top, .right = view.title_hit.right - view.px(4), .bottom = view.title_hit.bottom }, 0x8a8a8a, w.DT_SINGLELINE | w.DT_VCENTER);
    view.restart_hit = empty_rect;
    view.restart_member = null;
    for (view.model.members) |member| if (member.presence == .offline) {
        const bar = w.RECT{ .left = @max(view.px(16), center - view.px(380)), .top = height - view.px(122), .right = @min(width - view.px(16), center + view.px(380)), .bottom = height - view.px(78) };
        smooth.fillRoundRect(dc, bar, view.px(8), rgb(0x5a4a1e));
        var inner = bar;
        inner.left += p; inner.top += p; inner.right -= p; inner.bottom -= p;
        smooth.fillRoundRect(dc, inner, view.px(7), rgb(0x2a2210));
        _ = w.SelectObject(dc, body);
        text(dc, member.name, .{ .left = bar.left + view.px(12), .top = bar.top, .right = bar.right - view.px(96), .bottom = bar.bottom }, 0xf5c26b, w.DT_SINGLELINE | w.DT_VCENTER | w.DT_END_ELLIPSIS);
        view.restart_hit = .{ .left = bar.right - view.px(90), .top = bar.top + view.px(4), .right = bar.right - view.px(8), .bottom = bar.bottom - view.px(4) };
        view.restart_member = member.id;
        smooth.fillRoundRect(dc, view.restart_hit, view.px(18), rgb(if (w.GetFocus() == view.hwnd and view.focus_target == 1) 0xb0b0b0 else 0xf2f2f2));
        text(dc, L("Restart"), view.restart_hit, 0x181818, w.DT_SINGLELINE | w.DT_VCENTER | w.DT_CENTER);
        break;
    };
    const top = view.px(78);
    const bottom = @max(top, height - view.px(if (view.restart_member == null) 90 else 130));
    const left = @max(view.px(20), center - view.px(380));
    const right = @min(width - view.px(20), center + view.px(380));
    const clip = w.CreateRectRgn(left, top, right, bottom);
    _ = w.SelectClipRgn(dc, clip);
    var y = top - view.scroll;
    _ = w.SelectObject(dc, body);
    if (view.model.messages.len == 0) {
        const mid = @divTrunc(top + bottom, 2);
        for (view.model.members[0..@min(2, view.model.members.len)], 0..) |member, i| {
            const x = center - view.px(32) + @as(i32, @intCast(i)) * view.px(24);
            const ay = mid - view.px(70) + @as(i32, @intCast(i)) * view.px(12);
            drawMember(dc, .{ .left = x, .top = ay, .right = x + view.px(40), .bottom = ay + view.px(40) }, member);
        }
        _ = w.SelectObject(dc, heading);
        text(dc, view.model.name, .{ .left = left, .top = mid - view.px(12), .right = right, .bottom = mid + view.px(18) }, 0xf2f2f2, w.DT_SINGLELINE | w.DT_CENTER | w.DT_END_ELLIPSIS);
        _ = w.SelectObject(dc, body);
        text(dc, L("Start the conversation"), .{ .left = left, .top = mid + view.px(22), .right = right, .bottom = mid + view.px(52) }, 0x8a8a8a, w.DT_SINGLELINE | w.DT_CENTER);
    }
    for (view.model.messages) |message| {
        const member = message.author;
        const own = member == null;
        const max_width = @max(view.px(60), @min(view.px(520), right - left - view.px(52)));
        var measured = w.RECT{ .left = 0, .top = 0, .right = max_width - view.px(28), .bottom = 0 };
        _ = w.DrawTextW(dc, message.text.ptr, @intCast(message.text.len), &measured, w.DT_CALCRECT | w.DT_WORDBREAK | w.DT_NOPREFIX);
        const bubble_w = @min(max_width, @max(view.px(48), measured.right + view.px(28)));
        const bubble_h = @max(view.px(38), measured.bottom + view.px(20));
        if (!own) {
            if (member) |m| {
                avatar.draw(dc, .{ .left = left, .top = y, .right = left + view.px(28), .bottom = y + view.px(28) }, m.appearance);
                _ = w.SelectObject(dc, author_font);
                text(dc, m.name, .{ .left = left + view.px(40), .top = y, .right = right - view.px(100), .bottom = y + view.px(20) }, m.name_color, w.DT_SINGLELINE | w.DT_END_ELLIPSIS);
            }
            _ = w.SelectObject(dc, small);
            text(dc, message.time, .{ .left = right - view.px(90), .top = y, .right = right, .bottom = y + view.px(20) }, 0x6a6a6a, w.DT_SINGLELINE | w.DT_RIGHT);
            _ = w.SelectObject(dc, body);
            y += view.px(22);
        }
        const bx = if (own) right - bubble_w else left + view.px(40);
        const bubble = w.RECT{ .left = bx, .top = y, .right = bx + bubble_w, .bottom = y + bubble_h };
        smooth.fillRoundRect(dc, bubble, view.px(16), rgb(if (own) 0x2e2e2e else 0x1e1e1e));
        text(dc, message.text, .{ .left = bx + view.px(14), .top = y + view.px(10), .right = bx + bubble_w - view.px(14), .bottom = y + bubble_h - view.px(8) }, 0xf2f2f2, w.DT_WORDBREAK);
        y += bubble_h + view.px(18);
    }
    view.max_scroll = @max(0, y + view.scroll - bottom);
    if (view.scroll > view.max_scroll) {
        view.scroll = view.max_scroll;
        view.invalidate();
    }
    _ = w.SelectClipRgn(dc, null);
    _ = w.DeleteObject(clip);
    const composer_w = @min(view.px(760), @max(view.px(100), width - view.px(32)));
    const composer_x = @divTrunc(width - composer_w, 2);
    const composer = w.RECT{ .left = composer_x, .top = height - view.px(74), .right = composer_x + composer_w, .bottom = height - view.px(20) };
    smooth.fillRoundRect(dc, composer, view.px(27), rgb(0x1e1e1e));
    view.send_hit = .{ .left = composer.right - view.px(45), .top = composer.top + view.px(8), .right = composer.right - view.px(8), .bottom = composer.bottom - view.px(8) };
    smooth.fillRoundRect(dc, view.send_hit, view.px(18), rgb(0xf2f2f2));
    text(dc, L("↑"), view.send_hit, 0x111111, w.DT_SINGLELINE | w.DT_CENTER | w.DT_VCENTER);
    if (view.picker) drawPicker(view, dc, composer, body);
    if (view.result == .failed or view.result == .unsupported) text(dc, if (view.result == .unsupported) L("Action unavailable") else L("Action failed"), .{ .left = left, .top = height - view.px(94), .right = right, .bottom = height - view.px(76) }, 0xf5c26b, w.DT_SINGLELINE);
}

fn matchSearch(value: []const u16, query: []const u16) bool {
    if (query.len == 0) return true;
    if (query.len > value.len) return false;
    for (0..value.len - query.len + 1) |start| {
        var equal = true;
        for (query, 0..) |c, i| {
            const a = value[start + i];
            const lower_a = if (a >= 'A' and a <= 'Z') a + 32 else a;
            const lower_c = if (c >= 'A' and c <= 'Z') c + 32 else c;
            if (lower_a != lower_c) {
                equal = false;
                break;
            }
        }
        if (equal) return true;
    }
    return false;
}

fn filteredCount(candidates: []const Member, query: []const u16) usize {
    var total: usize = 0;
    for (candidates) |member| if (matchSearch(member.name, query) or matchSearch(member.alias, query)) {
        total += 1;
    };
    return total;
}

fn filteredIndex(candidates: []const Member, query: []const u16, target: usize) ?usize {
    var found: usize = 0;
    for (candidates, 0..) |member, i| if (matchSearch(member.name, query) or matchSearch(member.alias, query)) {
        if (found == target) return i;
        found += 1;
    };
    return null;
}

fn boundedScroll(offset: usize, count: usize, visible: usize) usize {
    return @min(offset, count -| visible);
}

fn drawDialog(view: *View, dc: w.HANDLE, bounds: w.RECT, body: w.HANDLE, heading: w.HANDLE, small: w.HANDLE) void {
    const width = @min(view.px(520), @max(1, bounds.right - view.px(24)));
    const left = @divTrunc(bounds.right - width, 2);
    const top = @max(view.px(8), @divTrunc(bounds.bottom - view.px(520), 2));
    const bottom = @min(bounds.bottom - view.px(8), top + view.px(520));
    const card = w.RECT{ .left = left, .top = top, .right = left + width, .bottom = bottom };
    smooth.fillRoundRect(dc, card, view.px(20), rgb(0x2e2e2e));
    const inset = @max(1, view.px(1));
    smooth.fillRoundRect(dc, .{ .left = left + inset, .top = top + inset, .right = left + width - inset, .bottom = bottom - inset }, view.px(19), rgb(0x181818));
    _ = w.SelectObject(dc, heading);
    text(dc, if (view.mode == .create) L("New room") else L("Edit room"), .{ .left = left + view.px(24), .top = top + view.px(20), .right = left + width - view.px(24), .bottom = top + view.px(48) }, 0xf2f2f2, w.DT_SINGLELINE);
    const list_top = top + view.px(160);
    const list_bottom = @max(list_top, bottom - view.px(84));
    const clip = w.CreateRectRgn(left + view.px(16), list_top, left + width - view.px(16), list_bottom);
    _ = w.SelectClipRgn(dc, clip);
    var search: [257]u16 = undefined;
    const search_len: usize = @intCast(@max(0, w.GetWindowTextW(view.search_edit, &search, search.len)));
    var matched: usize = 0;
    view.dialog_count = 0;
    var y = list_top;
    _ = w.SelectObject(dc, body);
    for (view.model.candidates, 0..) |member, index| {
        if (!matchSearch(member.name, search[0..search_len]) and !matchSearch(member.alias, search[0..search_len])) continue;
        defer matched += 1;
        if (matched < view.list_scroll) continue;
        if (y + view.px(48) > list_bottom or view.dialog_count >= view.dialog_hits.len) break;
        const row = w.RECT{ .left = left + view.px(20), .top = y, .right = left + width - view.px(20), .bottom = y + view.px(48) };
        view.dialog_hits[view.dialog_count] = row;
        view.dialog_members[view.dialog_count] = index;
        view.dialog_count += 1;
        if (view.dialog_count - 1 == view.dialog_index and w.GetFocus() == view.search_edit) smooth.fillRoundRect(dc, row, view.px(8), rgb(0x333333));
        drawMember(dc, .{ .left = row.left + view.px(4), .top = y + view.px(6), .right = row.left + view.px(40), .bottom = y + view.px(42) }, member);
        text(dc, member.name, .{ .left = row.left + view.px(52), .top = y, .right = row.right - view.px(42), .bottom = row.bottom }, 0xf2f2f2, w.DT_SINGLELINE | w.DT_VCENTER | w.DT_END_ELLIPSIS);
        const check = w.RECT{ .left = row.right - view.px(28), .top = y + view.px(14), .right = row.right - view.px(8), .bottom = y + view.px(34) };
        smooth.fillRoundRect(dc, check, view.px(4), rgb(if (view.selectedIndex(member.id) != null) 0xf2f2f2 else 0x555555));
        if (view.selectedIndex(member.id) != null) text(dc, L("✓"), check, 0x181818, w.DT_SINGLELINE | w.DT_CENTER | w.DT_VCENTER);
        y += view.px(48);
    }
    _ = w.SelectClipRgn(dc, null);
    _ = w.DeleteObject(clip);
    view.cancel_hit = .{ .left = left + width - view.px(236), .top = bottom - view.px(60), .right = left + width - view.px(142), .bottom = bottom - view.px(20) };
    view.confirm_hit = .{ .left = left + width - view.px(132), .top = bottom - view.px(60), .right = left + width - view.px(20), .bottom = bottom - view.px(20) };
    smooth.fillRoundRect(dc, view.cancel_hit, view.px(20), rgb(if (w.GetFocus() == view.hwnd and view.focus_target == 0) 0x777777 else 0x333333));
    smooth.fillRoundRect(dc, view.confirm_hit, view.px(20), rgb(if (w.GetFocus() == view.hwnd and view.focus_target == 1) 0xb0b0b0 else 0xf2f2f2));
    text(dc, L("Cancel"), view.cancel_hit, 0xf2f2f2, w.DT_SINGLELINE | w.DT_CENTER | w.DT_VCENTER);
    var count_buf: [48]u8 = undefined;
    const count = if (view.mode == .create) (std.fmt.bufPrint(&count_buf, "Create · {d}", .{view.selected_count}) catch "") else (std.fmt.bufPrint(&count_buf, "Save · {d}", .{view.selected_count}) catch "");
    var count_w: [48]u16 = undefined;
    const count_len = std.unicode.utf8ToUtf16Le(&count_w, count) catch 0;
    text(dc, count_w[0..count_len], view.confirm_hit, 0x181818, w.DT_SINGLELINE | w.DT_CENTER | w.DT_VCENTER);
    _ = w.SelectObject(dc, small);
    if (view.result == .failed or view.result == .unsupported) text(dc, if (view.result == .unsupported) L("Action unavailable") else L("Check name and members, then try again"), .{ .left = left + view.px(24), .top = bottom - view.px(82), .right = left + width - view.px(24), .bottom = bottom - view.px(62) }, 0xf5c26b, w.DT_SINGLELINE | w.DT_END_ELLIPSIS);
}

fn drawPicker(view: *View, dc: w.HANDLE, composer: w.RECT, body: w.HANDLE) void {
    var draft_buf: [65537]u16 = undefined;
    const draft = view.draft(&draft_buf) orelse return;
    const start = mentionStart(draft) orelse {
        view.picker_count = 0;
        return;
    };
    const query = draft[start + 1 ..];
    var indices: [64]usize = undefined;
    var count: usize = 0;
    for (view.model.members, 0..) |member, i| {
        if (count == indices.len) break;
        if (matchSearch(member.alias, query)) {
            indices[count] = i;
            count += 1;
        }
    }
    view.picker_count = count;
    if (count == 0) return;
    view.picker_index = @min(view.picker_index, count - 1);
    const visible = @min(count, 6);
    const first = if (view.picker_index >= visible) view.picker_index - visible + 1 else 0;
    view.picker_base = first;
    const panel = w.RECT{ .left = composer.left, .top = composer.top - @as(i32, @intCast(visible)) * view.px(42) - view.px(8), .right = @min(composer.right, composer.left + view.px(320)), .bottom = composer.top - view.px(4) };
    smooth.fillRoundRect(dc, panel, view.px(12), rgb(0x292929));
    _ = w.SelectObject(dc, body);
    for (0..visible) |row_index| {
        const index = first + row_index;
        const member = view.model.members[indices[index]];
        const top = panel.top + view.px(4) + @as(i32, @intCast(row_index)) * view.px(42);
        const row = w.RECT{ .left = panel.left + view.px(4), .top = top, .right = panel.right - view.px(4), .bottom = top + view.px(40) };
        view.picker_hits[row_index] = row;
        view.picker_members[row_index] = indices[index];
        if (index == view.picker_index) smooth.fillRoundRect(dc, row, view.px(8), rgb(0x3a3a3a));
        drawMember(dc, .{ .left = row.left + view.px(4), .top = top + view.px(5), .right = row.left + view.px(34), .bottom = top + view.px(35) }, member);
        text(dc, member.name, .{ .left = row.left + view.px(44), .top = top, .right = row.right - view.px(4), .bottom = row.bottom }, 0xf2f2f2, w.DT_SINGLELINE | w.DT_VCENTER | w.DT_END_ELLIPSIS);
    }
    view.picker_count = visible;
}

fn refreshHits(view: *View) void {
    view.clearHits();
    if (view.too_small or view.hwnd == null) return;
    var bounds: w.RECT = undefined;
    _ = w.GetClientRect(view.hwnd, &bounds);
    const width = bounds.right;
    const height = bounds.bottom;
    const center = @divTrunc(width, 2);
    if (view.mode != .room) {
        const card_width = view.px(520);
        const left = @divTrunc(width - card_width, 2);
        const top = @divTrunc(height - view.px(520), 2);
        const bottom = top + view.px(520);
        view.cancel_hit = .{ .left = left + card_width - view.px(236), .top = bottom - view.px(60), .right = left + card_width - view.px(142), .bottom = bottom - view.px(20) };
        view.confirm_hit = .{ .left = left + card_width - view.px(132), .top = bottom - view.px(60), .right = left + card_width - view.px(20), .bottom = bottom - view.px(20) };
        var search: [257]u16 = undefined;
        const len: usize = @intCast(@max(0, w.GetWindowTextW(view.search_edit, &search, search.len)));
        const query = search[0..len];
        const total = filteredCount(view.model.candidates, query);
        const visible: usize = @intCast(@divTrunc((bottom - view.px(84)) - (top + view.px(160)), view.px(48)));
        view.list_scroll = boundedScroll(view.list_scroll, total, visible);
        view.dialog_count = @min(visible, total - view.list_scroll);
        if (view.dialog_count == 0) view.dialog_index = 0 else view.dialog_index = @min(view.dialog_index, view.dialog_count - 1);
        for (0..view.dialog_count) |i| {
            const y = top + view.px(160) + @as(i32, @intCast(i)) * view.px(48);
            view.dialog_hits[i] = .{ .left = left + view.px(20), .top = y, .right = left + card_width - view.px(20), .bottom = y + view.px(48) };
            view.dialog_members[i] = filteredIndex(view.model.candidates, query, view.list_scroll + i) orelse return;
        }
        return;
    }
    view.title_hit = .{ .left = center - view.px(110), .top = view.px(14), .right = center + view.px(110), .bottom = view.px(56) };
    const composer_width = @min(view.px(760), width - view.px(32));
    const x = @divTrunc(width - composer_width, 2);
    const composer = w.RECT{ .left = x, .top = height - view.px(74), .right = x + composer_width, .bottom = height - view.px(20) };
    view.send_hit = .{ .left = composer.right - view.px(45), .top = composer.top + view.px(8), .right = composer.right - view.px(8), .bottom = composer.bottom - view.px(8) };
    for (view.model.members) |member| if (member.presence == .offline) {
        view.restart_member = member.id;
        view.restart_hit = .{ .left = composer.right - view.px(90), .top = composer.top - view.px(44), .right = composer.right - view.px(8), .bottom = composer.top - view.px(8) };
        break;
    };
    if (!view.picker) return;
    var buffer: [65537]u16 = undefined;
    const value = view.draft(&buffer) orelse return;
    const start = mentionStart(value) orelse return;
    var indices: [64]usize = undefined;
    var count: usize = 0;
    for (view.model.members, 0..) |member, i| if (matchSearch(member.alias, value[start + 1 ..])) {
        indices[count] = i;
        count += 1;
    };
    if (count == 0) return;
    view.picker_index = @min(view.picker_index, count - 1);
    view.picker_count = @min(count, 6);
    view.picker_base = if (view.picker_index >= view.picker_count) view.picker_index - view.picker_count + 1 else 0;
    const top = composer.top - @as(i32, @intCast(view.picker_count)) * view.px(42) - view.px(8);
    for (0..view.picker_count) |i| {
        const y = top + view.px(4) + @as(i32, @intCast(i)) * view.px(42);
        view.picker_hits[i] = .{ .left = composer.left + view.px(4), .top = y, .right = @min(composer.right, composer.left + view.px(320)) - view.px(4), .bottom = y + view.px(40) };
        view.picker_members[i] = indices[view.picker_base + i];
    }
}

fn mentionStart(value: []const u16) ?usize {
    var pos = value.len;
    while (pos > 0) {
        pos -= 1;
        const c = value[pos];
        if (c == '@') {
            if (pos > 0 and value[pos - 1] != ' ' and value[pos - 1] != '\n' and value[pos - 1] != '\r') return null;
            return pos;
        }
        if (!((c >= 'a' and c <= 'z') or (c >= '0' and c <= '9') or c == '_' or c == '-')) return null;
    }
    return null;
}

fn chooseMention(view: *View, index: usize) void {
    if (index >= view.model.members.len) return;
    var draft_buf: [65537]u16 = undefined;
    const draft = view.draft(&draft_buf) orelse return;
    const start = mentionStart(draft) orelse return;
    var replacement: [66:0]u16 = @splat(0);
    const alias = view.model.members[index].alias;
    if (alias.len + 2 >= replacement.len) return;
    replacement[0] = '@';
    @memcpy(replacement[1 .. 1 + alias.len], alias);
    replacement[alias.len + 1] = ' ';
    _ = w.SendMessageW(view.composer, 0x00b1, start, @intCast(draft.len));
    _ = w.SendMessageW(view.composer, 0x00c2, 1, @bitCast(@intFromPtr(&replacement)));
    view.picker = false;
    view.invalidate();
    view.setFocus(view.composer);
}

fn editProc(hwnd: w.HANDLE, msg: w.UINT, wp: w.WPARAM, lp: w.LPARAM) callconv(w.WINAPI) w.LRESULT {
    const proc = w.GetPropW(hwnd, L("MultiPromptRoomViewProc")) orelse return w.DefWindowProcW(hwnd, msg, wp, lp);
    const original: isize = @bitCast(@intFromPtr(proc));
    if (msg == 0x0082) {
        const identity = w.GetPropW(hwnd, L("MultiPromptRoomViewIdentity"));
        if (identity != null and w.GetPropW(hwnd, L("MultiPromptRoomView")) == identity) _ = RemovePropW(hwnd, L("MultiPromptRoomView"));
        _ = RemovePropW(hwnd, L("MultiPromptRoomViewIdentity"));
        _ = RemovePropW(hwnd, L("MultiPromptRoomViewProc"));
        return w.CallWindowProcW(original, hwnd, msg, wp, lp);
    }
    const ptr = w.GetPropW(hwnd, L("MultiPromptRoomView")) orelse return w.CallWindowProcW(original, hwnd, msg, wp, lp);
    if (w.GetPropW(hwnd, L("MultiPromptRoomViewIdentity")) != ptr) return w.CallWindowProcW(original, hwnd, msg, wp, lp);
    const view: *View = @ptrCast(@alignCast(ptr));
    if (msg == w.WM_PAINT and hwnd == view.composer) {
        const result = w.CallWindowProcW(original, hwnd, msg, wp, lp);
        if (w.GetWindowTextLengthW(hwnd) == 0) {
            const dc = w.GetDC(hwnd);
            if (dc != null) {
                defer _ = w.ReleaseDC(hwnd, dc);
                const old = w.SelectObject(dc, view.edit_font);
                defer _ = w.SelectObject(dc, old);
                _ = w.SetBkMode(dc, w.TRANSPARENT);
                var box: w.RECT = undefined;
                _ = w.GetClientRect(hwnd, &box);
                var hint: [320]u16 = undefined;
                const prefix = L("Message ");
                const suffix = L(" · type @ to ask one agent");
                const len = @min(view.model.name.len, hint.len - prefix.len - suffix.len);
                @memcpy(hint[0..prefix.len], prefix);
                @memcpy(hint[prefix.len .. prefix.len + len], view.model.name[0..len]);
                @memcpy(hint[prefix.len + len .. prefix.len + len + suffix.len], suffix);
                text(dc, hint[0 .. prefix.len + len + suffix.len], box, 0x6a6a6a, w.DT_SINGLELINE | w.DT_VCENTER | w.DT_END_ELLIPSIS);
            }
        }
        return result;
    }
    if (msg == w.WM_KEYDOWN) {
        refreshHits(view);
        if (view.too_small) return 0;
        if (wp == 0x1b) {
            if (view.mode != .room) {
                view.closeDialog();
            } else {
                view.picker = false;
                view.invalidate();
            }
            return 0;
        }
        if (hwnd == view.composer and view.picker and (wp == 0x26 or wp == 0x28)) {
            if (wp == 0x26) view.picker_index -|= 1 else view.picker_index += 1;
            view.invalidate();
            return 0;
        }
        if (hwnd == view.search_edit and (wp == 0x26 or wp == 0x28)) {
            if (wp == 0x26) {
                if (view.dialog_index > 0) view.dialog_index -= 1 else view.list_scroll -|= 1;
            } else if (view.dialog_index + 1 < view.dialog_count) {
                view.dialog_index += 1;
            } else if (view.dialog_count > 0) view.list_scroll += 1;
            refreshHits(view);
            view.invalidate();
            return 0;
        }
        if (wp == 0x0d) {
            if (hwnd == view.composer and w.GetKeyState(0x10) < 0) return w.CallWindowProcW(original, hwnd, msg, wp, lp);
            if (hwnd == view.search_edit and w.GetKeyState(0x11) >= 0 and view.dialog_count > 0) {
                view.toggle(view.model.candidates[view.dialog_members[@min(view.dialog_index, view.dialog_count - 1)]].id);
            } else if (hwnd == view.composer) {
                if (view.picker and view.picker_count > 0) {
                    const row = @min(view.picker_index -| view.picker_base, view.picker_count - 1);
                    chooseMention(view, view.picker_members[row]);
                } else if (w.GetKeyState(0x10) >= 0) view.submit() else return w.CallWindowProcW(original, hwnd, msg, wp, lp);
            } else view.confirm();
            return 0;
        }
        if (wp == 0x09) {
            const reverse = w.GetKeyState(0x10) < 0;
            if (view.mode != .room) {
                if (hwnd == view.name_edit) {
                    if (reverse) { view.focus_target = 1; view.setFocus(view.hwnd); } else view.setFocus(view.search_edit);
                } else if (reverse) view.setFocus(view.name_edit) else { view.focus_target = 0; view.setFocus(view.hwnd); }
            } else {
                view.focus_target = if (reverse and view.restart_member != null) 1 else 0;
                view.setFocus(view.hwnd);
            }
            view.invalidate();
            return 0;
        }
    }
    if (msg == 0x0102 and (wp == 0x09 or wp == 0x1b or (wp == 0x0d and (hwnd != view.composer or w.GetKeyState(0x10) >= 0)))) return 0;
    return w.CallWindowProcW(original, hwnd, msg, wp, lp);
}

fn windowProc(hwnd: w.HANDLE, msg: w.UINT, wp: w.WPARAM, lp: w.LPARAM) callconv(w.WINAPI) w.LRESULT {
    const data = w.GetWindowLongPtrW(hwnd, -21);
    const view: *View = if (data == 0) return w.DefWindowProcW(hwnd, msg, wp, lp) else @ptrFromInt(@as(usize, @bitCast(data)));
    switch (msg) {
        w.WM_PAINT => {
            var ps: w.PAINTSTRUCT = undefined;
            const dc = w.BeginPaint(hwnd, &ps);
            defer _ = w.EndPaint(hwnd, &ps);
            var bounds: w.RECT = undefined;
            _ = w.GetClientRect(hwnd, &bounds);
            refreshHits(view);
            draw(view, dc, bounds);
            return 0;
        },
        w.WM_SIZE => {
            view.layout();
            return 0;
        },
        w.WM_COMMAND => {
            const source: w.HANDLE = if (lp == 0) null else @ptrFromInt(@as(usize, @bitCast(lp)));
            if (source == view.composer and ((wp >> 16) & 0xffff) == 0x0300) {
                var buffer: [65537]u16 = undefined;
                view.picker = if (view.draft(&buffer)) |value| mentionStart(value) != null else false;
                view.clearHits();
                view.picker_index = 0;
            }
            if (source == view.search_edit and ((wp >> 16) & 0xffff) == 0x0300) {
                view.list_scroll = 0;
                view.dialog_index = 0;
                view.clearHits();
            }
            view.invalidate();
            return 0;
        },
        w.WM_KEYDOWN => {
            refreshHits(view);
            if (view.too_small) return 0;
            const reverse = w.GetKeyState(0x10) < 0;
            if (view.mode != .room) {
                if (wp == 0x1b) view.closeDialog() else if (wp == 0x0d or wp == 0x20) {
                    if (view.focus_target == 0) view.closeDialog() else view.confirm();
                } else if (wp == 0x09) {
                    if (reverse) {
                        if (view.focus_target == 1) view.focus_target = 0 else view.setFocus(view.search_edit);
                    } else {
                        if (view.focus_target == 0) view.focus_target = 1 else view.setFocus(view.name_edit);
                    }
                }
            } else if (wp == 0x0d or wp == 0x20) {
                if (view.focus_target == 0) view.openEdit() else view.restart();
            } else if (wp == 0x09) {
                if (reverse) {
                    if (view.focus_target == 1) view.focus_target = 0 else view.setFocus(view.composer);
                } else {
                    if (view.focus_target == 0 and view.restart_member != null) view.focus_target = 1 else view.setFocus(view.composer);
                }
            }
            view.invalidate();
            return 0;
        },
        0x0102 => return 0,
        w.WM_LBUTTONUP => {
            refreshHits(view);
            if (view.too_small) return 0;
            const bits: usize = @bitCast(lp);
            const x: i32 = @as(i16, @bitCast(@as(u16, @truncate(bits))));
            const y: i32 = @as(i16, @bitCast(@as(u16, @truncate(bits >> 16))));
            if (view.mode != .room) {
                if (inside(view.cancel_hit, x, y)) {
                    view.closeDialog();
                } else if (inside(view.confirm_hit, x, y)) view.confirm() else {
                    for (view.dialog_hits[0..view.dialog_count], 0..) |hit, i| if (inside(hit, x, y)) {
                        view.toggle(view.model.candidates[view.dialog_members[i]].id);
                        break;
                    };
                }
            } else if (view.picker) {
                for (view.picker_hits[0..view.picker_count], 0..) |hit, i| if (inside(hit, x, y)) {
                    chooseMention(view, view.picker_members[i]);
                    return 0;
                };
                view.picker = false;
                view.invalidate();
            } else if (inside(view.title_hit, x, y)) view.openEdit() else if (inside(view.send_hit, x, y)) view.submit() else if (inside(view.restart_hit, x, y)) {
                view.restart();
            }
            return 0;
        },
        w.WM_MOUSEWHEEL => {
            refreshHits(view);
            if (view.too_small) return 0;
            const delta: i16 = @bitCast(@as(u16, @truncate(wp >> 16)));
            if (view.mode == .room) {
                view.scroll = std.math.clamp(view.scroll - @divTrunc(@as(i32, delta) * view.px(48), 120), 0, view.max_scroll);
            } else if (delta > 0) {
                view.list_scroll -|= 1;
            } else if (view.dialog_count > 0) {
                view.list_scroll += 1;
            }
            refreshHits(view);
            view.invalidate();
            return 0;
        },
        w.WM_CTLCOLOREDIT => {
            const dc: w.HANDLE = if (wp == 0) null else @ptrFromInt(wp);
            _ = w.SetTextColor(dc, rgb(0xf2f2f2));
            _ = w.SetBkColor(dc, rgb(if (view.mode == .room) 0x1e1e1e else 0x181818));
            const brush = if (view.mode == .room) view.composer_brush else view.dialog_brush;
            return if (brush) |handle| @bitCast(@intFromPtr(handle)) else 0;
        },
        w.WM_DESTROY => {
            view.retire();
            for ([_]w.HANDLE{ view.composer, view.name_edit, view.search_edit }) |child| {
                if (child != null and w.GetPropW(child, L("MultiPromptRoomView")) == @as(w.HANDLE, view)) _ = RemovePropW(child, L("MultiPromptRoomView"));
            }
            view.hwnd = null;
            view.composer = null;
            view.name_edit = null;
            view.search_edit = null;
            view.releaseResources();
            return 0;
        },
        else => {},
    }
    return w.DefWindowProcW(hwnd, msg, wp, lp);
}

test "room mention picker recognizes only standalone aliases" {
    try std.testing.expectEqual(@as(?usize, 3), mentionStart(L("hi @alpha")));
    try std.testing.expectEqual(@as(?usize, null), mentionStart(L("user@example")));
    try std.testing.expectEqual(@as(?usize, null), mentionStart(L("\\@alpha")));
    try std.testing.expect(matchSearch(L("Alpha Agent"), L("agent")));
    try std.testing.expect(!matchSearch(L("Alpha"), L("beta")));
}

test "room token and model validation preserve identity" {
    const a = ActionToken{ .generation = 2, .serial = 3, .kind = .edit };
    const b = ActionToken{ .generation = 2, .serial = 4, .kind = .edit };
    const model = ViewModel{ .room_id = "room", .name = L("Room"), .revision = 1, .members = &.{}, .candidates = &.{}, .messages = &.{} };
    var pending_view = View{ .model = &model, .callbacks = undefined, .mode = .edit, .pending = b, .result = .pending };
    pending_view.completeAction(a, .accepted);
    try std.testing.expectEqual(b, pending_view.pending.?);
    try std.testing.expectEqual(Mode.edit, pending_view.mode);
    try std.testing.expectEqual(@as(?ActionResult, .pending), pending_view.result);
    try std.testing.expect(validModel(&model));
    var refreshed = model;
    refreshed.revision = 2;
    try std.testing.expect(sameRoom(&model, &refreshed));
    refreshed.room_id = "another";
    try std.testing.expect(!sameRoom(&model, &refreshed));
    var view = View{ .model = &model, .callbacks = undefined };
    view.selected[0].bytes[0] = 'x';
    view.selected[0].len = 1;
    view.selected_count = 1;
    try std.testing.expectEqual(@as(?usize, 0), view.selectedIndex("x"));
    try std.testing.expectEqual(@as(?usize, null), view.selectedIndex("y"));
    try std.testing.expectEqual(@as(i32, 544), minimumSize(96).cx);
    try std.testing.expectEqual(@as(i32, 804), minimumSize(144).cy);
}

test "candidate paging reaches past membership limit" {
    var candidates: [80]Member = undefined;
    for (&candidates, 0..) |*member, i| {
        member.* = .{ .id = "session", .alias = L("agent"), .name = if (i == 79) L("Needle") else L("Agent"), .appearance = .{ .face = 0, .color = 0 }, .name_color = 0, .presence = .unknown };
    }
    try std.testing.expectEqual(@as(usize, 80), filteredCount(&candidates, L("")));
    try std.testing.expectEqual(@as(?usize, 79), filteredIndex(&candidates, L("needle"), 0));
    try std.testing.expectEqual(@as(?usize, 79), filteredIndex(&candidates, L(""), 79));
    try std.testing.expectEqual(@as(usize, 74), boundedScroll(100, 80, 6));
    try std.testing.expectEqual(@as(?usize, 73), filteredIndex(&candidates, L(""), boundedScroll(73, 80, 6)));
    try std.testing.expectEqual(@as(usize, 0), boundedScroll(73, 1, 6));
}
