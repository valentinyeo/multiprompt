const std = @import("std");
const app_state = @import("app_state.zig");
const chat_history = @import("chat_history.zig");
const RECT = @import("win32.zig").RECT;

const Entry = app_state.ChatHistoryEntry;
const Snapshot = app_state.ChatLayoutSnapshot;

fn contentHash(history: *const chat_history.History, text: usize, blocks: usize) u64 {
    var hasher = std.hash.Wyhash.init(0);
    hasher.update(std.mem.sliceAsBytes(history.text.items[0..text]));
    hasher.update(std.mem.sliceAsBytes(history.blocks.items[0..blocks]));
    return hasher.final();
}

pub fn reusablePrefix(snapshot: Snapshot, history: *const chat_history.History) usize {
    if (snapshot.stable_text > history.text.items.len or snapshot.stable_blocks > history.blocks.items.len) return 0;
    if (contentHash(history, snapshot.stable_text, snapshot.stable_blocks) != snapshot.content_hash) return 0;
    return @min(snapshot.stable_blocks, snapshot.rects.len, snapshot.first_image) -| 1;
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
        history.blocks.items.len != app_state.g_chat_block_count or history.text.items.len != app_state.g_chat_last_len or
        !std.mem.eql(u8, std.mem.sliceAsBytes(history.blocks.items[0..keep]), std.mem.sliceAsBytes(app_state.g_chat_blocks[0..keep])))
    {
        entry.clearLayout();
        return;
    }
    var first_image = keep;
    for (app_state.g_chat_img_count[0..keep], 0..) |n, index| {
        if (n > 0 or (index >= app_state.g_chat_img_first_block and app_state.g_chat_blocks[index].image_count > 0)) {
            first_image = index;
            break;
        }
    }
    const stable_blocks = if (history.last_block > 0 and history.last_block <= history.blocks.items.len) history.last_block else history.blocks.items.len;
    const stable_text = if (history.last_block > 0 and history.last_text <= history.text.items.len) history.last_text else history.text.items.len;
    const rects = std.heap.page_allocator.alloc(RECT, keep) catch return;
    @memcpy(rects, app_state.g_chat_layout_rects[0..keep]);
    const content_hash = contentHash(history, stable_text, stable_blocks);
    entry.clearLayout();
    entry.layout = .{
        .content_hash = content_hash,
        .stable_text = stable_text,
        .stable_blocks = stable_blocks,
        .width = app_state.g_chat_layout_width,
        .scale = app_state.g_chat_layout_scale,
        .font_pt = app_state.g_chat_layout_font_pt,
        .clean = app_state.clean_chat,
        .boundary = app_state.g_chat_read_boundary,
        .img_first_block = app_state.g_chat_img_first_block,
        .first_image = first_image,
        .read_divider_y = app_state.g_chat_read_divider_y,
        .rects = rects,
    };
}

pub fn restore(entry: ?*Entry) usize {
    const e = entry orelse return 0;
    const snapshot = e.layout orelse return 0;
    if (!app_state.g_chat_blocks_from_file or app_state.g_chat_cache_generation != e.generation) return 0;
    const keep = if (snapshot.clean == app_state.clean_chat) @min(reusablePrefix(snapshot, &e.history), app_state.g_chat_block_count) else 0;
    if (keep == 0) {
        e.clearLayout();
        return 0;
    }
    @memcpy(app_state.g_chat_layout_rects[0..keep], snapshot.rects[0..keep]);
    @memset(app_state.g_chat_img_count[0..keep], 0);
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
