const std = @import("std");
const chat_image = @import("chat_image.zig");

pub const MAX_ATTACHMENTS = 10;

pub const Selection = struct {
    attached: [MAX_ATTACHMENTS][]const u16 = undefined,
    count: usize = 0,
    files: [MAX_ATTACHMENTS][]const u16 = undefined,
    file_count: usize = 0,
    refused_too_many: usize = 0,
};

pub fn select(paths: []const []const u16) Selection {
    var result: Selection = .{};
    for (paths) |path| {
        if (!hasImageExt(path)) {
            if (result.file_count == MAX_ATTACHMENTS) {
                result.refused_too_many += 1;
            } else {
                result.files[result.file_count] = path;
                result.file_count += 1;
            }
        } else if (result.count == MAX_ATTACHMENTS) {
            result.refused_too_many += 1;
        } else {
            result.attached[result.count] = path;
            result.count += 1;
        }
    }
    return result;
}

fn safeChar(c: u21) u8 {
    return if ((c >= 'A' and c <= 'Z') or (c >= 'a' and c <= 'z') or (c >= '0' and c <= '9') or c == '.' or c == '_' or c == '-') @intCast(c) else '_';
}

pub fn remoteName(path: []const u16, out: []u8) []const u8 {
    const start = if (std.mem.lastIndexOfAny(u16, path, &.{ '/', '\\' })) |i| i + 1 else 0;
    const name = path[start..];
    const cap = @min(out.len, 80);
    const dot = std.mem.lastIndexOfScalar(u16, name, '.');
    const ext_start = if (dot) |i| if (i > 0 and name.len - i < cap) i else name.len else name.len;
    const stem_cap = cap - (name.len - ext_start);
    var len: usize = 0;
    var i: usize = 0;
    var leading = true;
    while (i < name.len) : (i += 1) {
        if (i < ext_start and len >= stem_cap) continue;
        if (len == cap) break;
        var c = safeChar(name[i]);
        if (leading and c == '.') c = '_';
        if (name[i] != '.') leading = false;
        out[len] = c;
        len += 1;
        if (std.unicode.utf16IsHighSurrogate(name[i]) and i + 1 < name.len and std.unicode.utf16IsLowSurrogate(name[i + 1])) i += 1;
    }
    if (len == 0) {
        const fallback = "file"[0..@min(out.len, 4)];
        @memcpy(out[0..fallback.len], fallback);
        return out[0..fallback.len];
    }
    return out[0..len];
}

pub fn remoteSessionDir(session: []const u8, out: []u8) []const u8 {
    var len: usize = 0;
    var i: usize = 0;
    var leading = true;
    while (i < session.len and len < out.len) {
        const n = std.unicode.utf8ByteSequenceLength(session[i]) catch 1;
        const c = if (n == 1) safeChar(session[i]) else '_';
        out[len] = if (leading and c == '.') '_' else c;
        if (session[i] != '.') leading = false;
        len += 1;
        i += @min(n, session.len - i);
    }
    if (len == 0) {
        const fallback = "session"[0..@min(out.len, 7)];
        @memcpy(out[0..fallback.len], fallback);
        return out[0..fallback.len];
    }
    return out[0..len];
}

pub fn uploadCommand(session_dir: []const u8, name: []const u8, expected_size: u64, out: []u8) []const u8 {
    var dir_buf: [80]u8 = undefined;
    var name_buf: [80]u8 = undefined;
    const dir = remoteSessionDir(session_dir, &dir_buf);
    const file = remoteSessionDir(name, &name_buf);
    return std.fmt.bufPrint(out, "sh -c 'set -ef; IFS=; umask 077; d=$HOME/.multiprompt/uploads/{s}; mkdir -p $d; find $d -maxdepth 1 -type d -name .staging.* -mmin +1440 -exec rm -rf -- {{}} +; t=$(mktemp -d $d/.staging.XXXXXXXXXX); p=; trap '\\''[ -z $p ] || kill $p 2>/dev/null || :; rm -rf -- $t'\\'' 0; trap '\\''exit 1'\\'' HUP INT TERM; exec 3<&0; if dd if=/dev/null of=/dev/null status=progress 2>/dev/null; then dd bs=65536 status=progress <&3 > $t/data & else cat <&3 > $t/data & fi; p=$!; exec 3<&-; wait $p; p=; [ $(wc -c < $t/data) -eq {d} ] || exit 1; f=$d/{s}; n=0; until ln -T -- $t/data $f 2>/dev/null; do [ -e $f ] || [ -L $f ] || exit 1; n=$((n+1)); f=$d/$n-{s}; done; rm -rf -- $t; trap - 0 HUP INT TERM; printf %s\\\\n $f'", .{ dir, expected_size, file, file }) catch "";
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

test "mixed files retain image order and retain non-images" {
    const paths = [_][]const u16{ w("C:\\shots\\first.png"), w("report.pdf"), w("second.jpg"), w("notes.txt"), w("third.webp") };
    const result = select(&paths);
    try std.testing.expectEqual(@as(usize, 3), result.count);
    try std.testing.expectEqual(@as(usize, 2), result.file_count);
    try std.testing.expectEqual(@as(usize, 0), result.refused_too_many);
    try std.testing.expectEqualSlices(u16, paths[1], result.files[0]);
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
    try std.testing.expectEqual(@as(usize, 2), result.file_count);
    try std.testing.expectEqual(@as(usize, 2), result.refused_too_many);
    for ([_]usize{ 0, 1, 3, 4, 5, 6, 7, 8, 9, 10 }, 0..) |index, i| try std.testing.expectEqualSlices(u16, paths[index], result.attached[i]);
    const exact = select(result.attached[0..result.count]);
    try std.testing.expectEqual(@as(usize, 0), exact.refused_too_many);
}

test "empty and non-image lists have no images" {
    const empty = select(&.{});
    try std.testing.expectEqual(@as(usize, 0), empty.count);
    try std.testing.expect(empty.file_count == 0);
    const result = select(&.{ w("report.pdf"), w("README") });
    try std.testing.expectEqual(@as(usize, 0), result.count);
    try std.testing.expectEqual(@as(usize, 2), result.file_count);
    try std.testing.expectEqual(@as(usize, 0), result.refused_too_many);
}

test "remote names sanitize hostile code points and preserve capped extensions" {
    var out: [100]u8 = undefined;
    try std.testing.expectEqualStrings("__touch_pwn___a_b.pdf", remoteName(w("C:\\x\\$(touch pwn); a b.pdf"), &out));
    try std.testing.expectEqualStrings("___quoted___x_.zip", remoteName(w("/x/..'quoted' `x`.zip"), &out));
    try std.testing.expectEqualStrings("__.log", remoteName(w("画🖼.log"), &out));
    try std.testing.expectEqualStrings("file", remoteName(w("C:\\x\\"), &out));
    var long: [300]u16 = @splat('a');
    @memcpy(long[296..], w(".pdf"));
    const name = remoteName(&long, &out);
    try std.testing.expectEqual(@as(usize, 80), name.len);
    try std.testing.expect(std.mem.endsWith(u8, name, ".pdf"));
}

test "session directories sanitize shell syntax and Unicode" {
    var out: [80]u8 = undefined;
    try std.testing.expectEqualStrings("session", remoteSessionDir("", &out));
    try std.testing.expectEqualStrings("___a_____touch_x_____", remoteSessionDir("..'a' \"$(touch x)`画;🖼", &out));
    const long: [200]u8 = @splat('z');
    try std.testing.expectEqual(@as(usize, out.len), remoteSessionDir(&long, &out).len);
}

test "upload commands contain sanitized names and no Windows double quotes" {
    var out: [2048]u8 = undefined;
    const command = uploadCommand("..'$(whoami); 画", "a`b \".zip", 12345, &out);
    try std.testing.expect(std.mem.indexOfScalar(u8, command, '"') == null);
    try std.testing.expect(std.mem.startsWith(u8, command, "sh -c '"));
    try std.testing.expect(std.mem.indexOf(u8, command, "/uploads/_____whoami____") != null);
    try std.testing.expect(std.mem.indexOf(u8, command, "/a_b__.zip") != null);
    try std.testing.expect(std.mem.indexOf(u8, command, "whoami)") == null);
    try std.testing.expect(std.mem.indexOf(u8, command, "ln -T -- $t/data $f") != null);
    try std.testing.expect(std.mem.indexOf(u8, command, "mktemp -d $d/.staging.") != null);
    try std.testing.expect(std.mem.indexOf(u8, command, "[ $(wc -c < $t/data) -eq 12345 ]") != null);
    try std.testing.expect(std.mem.indexOf(u8, command, "HUP INT TERM") != null);
    try std.testing.expect(std.mem.indexOf(u8, command, "-mmin +1440") != null);
    try std.testing.expect(std.mem.indexOf(u8, command, "printf %s\\\\n $f") != null);
    try std.testing.expect(std.mem.indexOf(u8, command, ".lock") == null);
}

test "non-image cap is independent of the image cap" {
    const paths = [_][]const u16{w("x.zip")} ** 12 ++ [_][]const u16{w("x.png")} ** 12;
    const result = select(&paths);
    try std.testing.expectEqual(@as(usize, 10), result.count);
    try std.testing.expectEqual(@as(usize, 10), result.file_count);
    try std.testing.expectEqual(@as(usize, 4), result.refused_too_many);
}
