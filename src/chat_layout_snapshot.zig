const std = @import("std");
const app_state = @import("app_state.zig");
const chat_history = @import("chat_history.zig");
const RECT = @import("win32.zig").RECT;

const Entry = app_state.ChatHistoryEntry;
const Snapshot = app_state.ChatLayoutSnapshot;

pub fn reusablePrefix(snapshot: Snapshot, history: *const chat_history.History, generation: u64) usize {
    if (snapshot.generation != generation or snapshot.inode != history.inode or snapshot.start != history.start) return 0;
    const count = @min(snapshot.rects.len, history.blocks.items.len);
    if (history.revision == snapshot.revision) return if (history.text.items.len == snapshot.text_len) count else 0;
    if (history.revision == snapshot.revision +% 1) return @min(count, history.changed_from);
    return 0;
}

fn entryFor(shell_id: u32) ?*Entry {
    for (app_state.g_chat_histories.items) |entry| {
        if (!entry.retired and entry.key.shell_id == shell_id) return entry;
    }
    return null;
}

pub fn save() void {
    const shell_id = app_state.g_chat_cache_shell_id;
    if (shell_id == 0 or !app_state.g_chat_blocks_from_file) return;
    const entry = entryFor(shell_id) orelse return;
    const history = &entry.history;
    const keep = @min(app_state.g_chat_layout_reuse, app_state.g_chat_block_count);
    if (keep == 0 or app_state.g_chat_find_layout_open or entry.generation != app_state.g_chat_cache_generation or
        history.revision != app_state.g_chat_last_hash or history.blocks.items.len != app_state.g_chat_block_count or
        history.text.items.len != app_state.g_chat_last_len or
        !std.mem.eql(u8, std.mem.sliceAsBytes(history.blocks.items[0..keep]), std.mem.sliceAsBytes(app_state.g_chat_blocks[0..keep])))
    {
        entry.clearLayout();
        return;
    }
    const a = std.heap.page_allocator;
    var with_images: usize = 0;
    for (app_state.g_chat_img_count[0..keep]) |n| {
        if (n > 0) with_images += 1;
    }
    const rects = a.alloc(RECT, keep) catch return;
    const images = a.alloc(app_state.ChatLayoutImages, with_images) catch {
        a.free(rects);
        return;
    };
    @memcpy(rects, app_state.g_chat_layout_rects[0..keep]);
    var at: usize = 0;
    for (app_state.g_chat_img_count[0..keep], 0..) |n, index| {
        if (n == 0) continue;
        images[at] = .{ .index = index, .count = n, .items = app_state.g_chat_img_items[index] };
        at += 1;
    }
    entry.clearLayout();
    entry.layout = .{
        .revision = history.revision,
        .generation = entry.generation,
        .inode = history.inode,
        .start = history.start,
        .text_len = history.text.items.len,
        .width = app_state.g_chat_layout_width,
        .scale = app_state.g_chat_layout_scale,
        .font_pt = app_state.g_chat_layout_font_pt,
        .boundary = app_state.g_chat_read_boundary,
        .img_first_block = app_state.g_chat_img_first_block,
        .read_divider_y = app_state.g_chat_read_divider_y,
        .rects = rects,
        .images = images,
    };
}

pub fn restore(entry: ?*Entry) usize {
    const e = entry orelse return 0;
    const snapshot = e.layout orelse return 0;
    if (!app_state.g_chat_blocks_from_file or app_state.g_chat_cache_generation != e.generation) return 0;
    const keep = @min(reusablePrefix(snapshot, &e.history, e.generation), app_state.g_chat_block_count);
    if (keep == 0) {
        e.clearLayout();
        return 0;
    }
    @memcpy(app_state.g_chat_layout_rects[0..keep], snapshot.rects[0..keep]);
    @memset(app_state.g_chat_img_count[0..keep], 0);
    for (snapshot.images) |image| {
        if (image.index >= keep) break;
        app_state.g_chat_img_count[image.index] = image.count;
        app_state.g_chat_img_items[image.index] = image.items;
    }
    app_state.g_chat_layout_width = snapshot.width;
    app_state.g_chat_layout_scale = snapshot.scale;
    app_state.g_chat_layout_font_pt = snapshot.font_pt;
    app_state.g_chat_find_layout_open = false;
    app_state.g_chat_read_boundary = snapshot.boundary;
    app_state.g_chat_read_divider_y = snapshot.read_divider_y;
    app_state.g_chat_img_first_block = snapshot.img_first_block;
    app_state.g_chat_layout_reuse = keep;
    return keep;
}
