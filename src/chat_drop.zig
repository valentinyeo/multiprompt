const std = @import("std");
const chat_image = @import("chat_image.zig");

pub const MAX_ATTACHMENTS = 10;

pub const Selection = struct {
    attached: [MAX_ATTACHMENTS][]const u16 = undefined,
    count: usize = 0,
    refused: usize = 0,
    refused_too_many: usize = 0,
    first_refused: ?[]const u16 = null,
};

pub fn select(paths: []const []const u16) Selection {
    var result: Selection = .{};
    for (paths) |path| {
        if (!hasImageExt(path)) {
            result.refused += 1;
            if (result.first_refused == null) result.first_refused = path;
        } else if (result.count == MAX_ATTACHMENTS) {
            result.refused_too_many += 1;
        } else {
            result.attached[result.count] = path;
            result.count += 1;
        }
    }
    return result;
}

pub fn hasImageExt(path: []const u16) bool {
    const start = if (std.mem.lastIndexOfAny(u16, path, &.{ '/', '\\' })) |i| i + 1 else 0;
    const name = path[start..];
    const dot = std.mem.lastIndexOfScalar(u16, name, '.') orelse return false;
    const ext = name[dot..];
    var ascii: [5]u8 = undefined;
    if (ext.len > ascii.len) return false;
    for (ext, 0..) |c, i| {
        if (c > 127) return false;
        ascii[i] = @intCast(c);
    }
    const known = chat_image.imageExt(ascii[0..ext.len]) orelse return false;
    return ext.len == known.len + 1;
}

const w = std.unicode.utf8ToUtf16LeStringLiteral;

test "mixed files retain image order and count refused files" {
    const paths = [_][]const u16{ w("C:\\shots\\first.png"), w("report.pdf"), w("second.jpg"), w("notes.txt"), w("third.webp") };
    const result = select(&paths);
    try std.testing.expectEqual(@as(usize, 3), result.count);
    try std.testing.expectEqual(@as(usize, 2), result.refused);
    try std.testing.expectEqual(@as(usize, 0), result.refused_too_many);
    try std.testing.expectEqualSlices(u16, paths[1], result.first_refused.?);
    for ([_]usize{ 0, 2, 4 }, 0..) |index, i| try std.testing.expectEqualSlices(u16, paths[index], result.attached[i]);
}

test "all supported extensions are case insensitive including Unicode paths" {
    for ([_][]const u16{ w("a.PNG"), w("b.JpG"), w("c.JPEG"), w("d.GIF"), w("C:\\画像\\🖼.WeBp"), w("C:\\folder#1\\photo#2.png") }) |path| try std.testing.expect(hasImageExt(path));
}

test "missing extensions and dotted folders do not make images" {
    for ([_][]const u16{ w(""), w("photo"), w("photo."), w("C:\\folder.png\\photo"), w("/folder.jpg/photo"), w("C:\\folder.webp\\"), w("photo.png.exe"), w("photo.png?x"), w("photo.png#x"), w("photo.png#"), w("photo.png?"), w("photo.ＰＮＧ") }) |path| try std.testing.expect(!hasImageExt(path));
    try std.testing.expect(hasImageExt(w("C:\\folder.pdf\\photo.png")));
}

test "cap counts only images and keeps the first ten in order" {
    const paths = [_][]const u16{ w("0.png"), w("1.jpg"), w("report.pdf"), w("2.jpeg"), w("3.gif"), w("4.webp"), w("5.png"), w("6.jpg"), w("7.jpeg"), w("8.gif"), w("9.webp"), w("10.png"), w("notes"), w("11.jpg") };
    const result = select(&paths);
    try std.testing.expectEqual(@as(usize, MAX_ATTACHMENTS), result.count);
    try std.testing.expectEqual(@as(usize, 2), result.refused);
    try std.testing.expectEqual(@as(usize, 2), result.refused_too_many);
    for ([_]usize{ 0, 1, 3, 4, 5, 6, 7, 8, 9, 10 }, 0..) |index, i| try std.testing.expectEqualSlices(u16, paths[index], result.attached[i]);
    const exact = select(result.attached[0..result.count]);
    try std.testing.expectEqual(@as(usize, 0), exact.refused_too_many);
}

test "empty and wholly refused lists have no attachments" {
    const empty = select(&.{});
    try std.testing.expectEqual(@as(usize, 0), empty.count);
    try std.testing.expect(empty.first_refused == null);
    const result = select(&.{ w("report.pdf"), w("README") });
    try std.testing.expectEqual(@as(usize, 0), result.count);
    try std.testing.expectEqual(@as(usize, 2), result.refused);
    try std.testing.expectEqual(@as(usize, 0), result.refused_too_many);
}
