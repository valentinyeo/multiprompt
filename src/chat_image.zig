const std = @import("std");

pub const MAX_BYTES: usize = 10 * 1024 * 1024;
pub const MAX_FETCHES: usize = 20;
pub const MAX_PER_BLOCK: usize = 4;
pub const THUMB_MAX_W: i32 = 320;
pub const THUMB_MAX_H: i32 = 480;
pub const URL_CAP: usize = 512;

pub const Range = struct { start: usize, end: usize };

fn lower(c: u16) u16 {
    return if (c >= 'A' and c <= 'Z') c + 32 else c;
}

fn startsWithAscii(text: []const u16, prefix: []const u8) bool {
    if (text.len < prefix.len) return false;
    for (prefix, 0..) |p, i| if (lower(text[i]) != p) return false;
    return true;
}

fn isUrlChar(c: u16) bool {
    if (c <= 0x20 or c == 0x7f or (c >= 0x2500 and c <= 0x259f)) return false;
    return switch (c) {
        '"', '\'', '<', '>', '`', '{', '}', '|', '\\', '^' => false,
        else => true,
    };
}

pub const IMAGE_EXTS = [_][]const u8{ "png", "jpg", "jpeg", "gif", "webp" };

pub fn hasImageExt(path: []const u8) bool {
    return imageExt(path) != null;
}

pub fn imageExt(path: []const u8) ?[]const u8 {
    var end = path.len;
    if (std.mem.indexOfAny(u8, path, "?#")) |q| end = q;
    const dot = std.mem.lastIndexOfScalar(u8, path[0..end], '.') orelse return null;
    const ext = path[dot + 1 .. end];
    for (IMAGE_EXTS) |known| {
        if (std.ascii.eqlIgnoreCase(ext, known)) return known;
    }
    return null;
}

fn wideHasImageExt(url: []const u16) bool {
    var buf: [URL_CAP]u8 = undefined;
    if (url.len > buf.len) return false;
    for (url, 0..) |c, i| {
        if (c >= 0x80) return false;
        buf[i] = @intCast(c);
    }
    return hasImageExt(buf[0..url.len]);
}

fn trimEnd(text: []const u16) usize {
    var end = text.len;
    while (end > 0) {
        const c = text[end - 1];
        if (c == '.' or c == ',' or c == ';' or c == ':' or c == '!') {
            end -= 1;
            continue;
        }
        if (c == ')' or c == ']') {
            const opening: u16 = if (c == ')') '(' else '[';
            if (std.mem.indexOfScalar(u16, text[0..end], opening) != null) break;
            end -= 1;
            continue;
        }
        break;
    }
    return end;
}

pub fn findImageUrls(text: []const u16, out: []Range) usize {
    var count: usize = 0;
    var i: usize = 0;
    while (i < text.len and count < out.len) : (i += 1) {
        const rest = text[i..];
        const is_scheme = startsWithAscii(rest, "https://");
        const is_bare = startsWithAscii(rest, "screencast2.com/");
        if (!is_scheme and !is_bare) continue;
        if (i > 0 and isUrlChar(text[i - 1]) and text[i - 1] != '(' and text[i - 1] != '[') continue;
        var end = i;
        while (end < text.len and isUrlChar(text[end])) : (end += 1) {}
        end = i + trimEnd(text[i..end]);
        if (end <= i or end - i >= URL_CAP) continue;
        const url = text[i..end];
        if (!wideHasImageExt(url)) {
            i = end -| 1;
            continue;
        }
        var duplicate = false;
        for (out[0..count]) |seen| {
            if (std.mem.eql(u16, text[seen.start..seen.end], url)) duplicate = true;
        }
        if (!duplicate) {
            out[count] = .{ .start = i, .end = end };
            count += 1;
        }
        i = end -| 1;
    }
    return count;
}

pub fn urlUtf8(url: []const u16, out: []u8) ?[]const u8 {
    var n: usize = 0;
    const bare = !startsWithAscii(url, "http");
    if (bare) {
        const prefix = "https://";
        if (out.len < prefix.len) return null;
        @memcpy(out[0..prefix.len], prefix);
        n = prefix.len;
    }
    for (url) |c| {
        if (c >= 0x80 or n >= out.len) return null;
        out[n] = @intCast(c);
        n += 1;
    }
    return out[0..n];
}

pub const UrlParts = struct { secure: bool, host: []const u8, port: u16, path: []const u8 };

pub fn splitUrl(url: []const u8) ?UrlParts {
    var secure = true;
    var rest: []const u8 = undefined;
    if (std.mem.startsWith(u8, url, "https://")) {
        rest = url[8..];
    } else if (std.mem.startsWith(u8, url, "http://")) {
        secure = false;
        rest = url[7..];
    } else return null;
    const host_end = std.mem.indexOfAny(u8, rest, "/?#") orelse rest.len;
    var host = rest[0..host_end];
    var port: u16 = if (secure) 443 else 80;
    if (std.mem.indexOfScalar(u8, host, ':')) |colon| {
        port = std.fmt.parseInt(u16, host[colon + 1 ..], 10) catch return null;
        host = host[0..colon];
    }
    if (host.len == 0 or std.mem.indexOfScalar(u8, host, '@') != null) return null;
    var path = rest[host_end..];
    if (std.mem.indexOfScalar(u8, path, '#')) |hash| path = path[0..hash];
    if (path.len == 0) path = "/";
    return .{ .secure = secure, .host = host, .port = port, .path = path };
}

pub fn thumbSize(w: i32, h: i32, max_w: i32, max_h: i32) struct { w: i32, h: i32 } {
    if (w <= 0 or h <= 0 or max_w <= 0 or max_h <= 0) return .{ .w = max_w, .h = @min(max_h, @divTrunc(max_w * 9, 16)) };
    var tw: i64 = w;
    var th: i64 = h;
    if (tw > max_w) {
        th = @divTrunc(th * max_w, tw);
        tw = max_w;
    }
    if (th > max_h) {
        tw = @divTrunc(tw * max_h, th);
        th = max_h;
    }
    return .{ .w = @intCast(@max(1, tw)), .h = @intCast(@max(1, th)) };
}

pub fn cacheKey(url: []const u8) u64 {
    var hash: u64 = 0xcbf29ce484222325;
    for (url) |b| {
        hash ^= b;
        hash *%= 0x100000001b3;
    }
    return hash;
}

pub fn cacheFileName(url: []const u8, out: []u8) ?[]const u8 {
    const ext = imageExt(url) orelse "img";
    return std.fmt.bufPrint(out, "{x:0>16}.{s}", .{ cacheKey(url), ext }) catch null;
}

pub const UploadConfig = struct {
    secret: [128]u8 = undefined,
    secret_len: usize = 0,
    base: [160]u8 = undefined,
    base_len: usize = 0,

    pub fn secretSlice(self: *const UploadConfig) []const u8 {
        return self.secret[0..self.secret_len];
    }
    pub fn baseSlice(self: *const UploadConfig) []const u8 {
        return self.base[0..self.base_len];
    }
};

fn quotedValue(line: []const u8, key: []const u8) ?[]const u8 {
    if (!std.mem.startsWith(u8, line, key)) return null;
    const rest = std.mem.trimStart(u8, line[key.len..], " \t");
    if (rest.len == 0 or rest[0] != '=') return null;
    const value = std.mem.trim(u8, rest[1..], " \t\r");
    if (value.len < 2 or value[0] != '"') return null;
    const close = std.mem.indexOfScalarPos(u8, value, 1, '"') orelse return null;
    return value[1..close];
}

pub fn parseUploadConfig(contents: []const u8) ?UploadConfig {
    var cfg = UploadConfig{};
    var lines = std.mem.splitScalar(u8, contents, '\n');
    while (lines.next()) |raw| {
        const line = std.mem.trim(u8, raw, " \t\r");
        if (quotedValue(line, "upload_secret")) |v| {
            if (v.len > cfg.secret.len) return null;
            @memcpy(cfg.secret[0..v.len], v);
            cfg.secret_len = v.len;
        } else if (quotedValue(line, "api_base_url")) |v| {
            const trimmed = std.mem.trimEnd(u8, v, "/");
            if (trimmed.len > cfg.base.len) return null;
            @memcpy(cfg.base[0..trimmed.len], trimmed);
            cfg.base_len = trimmed.len;
        }
    }
    if (cfg.secret_len == 0 or cfg.base_len == 0) return null;
    return cfg;
}

pub fn multipartPrefix(out: []u8, boundary: []const u8, id: []const u8, filename: []const u8, mime: []const u8) ?[]const u8 {
    return std.fmt.bufPrint(
        out,
        "--{s}\r\nContent-Disposition: form-data; name=\"id\"\r\n\r\n{s}\r\n--{s}\r\nContent-Disposition: form-data; name=\"screenshot\"; filename=\"{s}\"\r\nContent-Type: {s}\r\n\r\n",
        .{ boundary, id, boundary, filename, mime },
    ) catch null;
}

pub fn multipartSuffix(out: []u8, boundary: []const u8) ?[]const u8 {
    return std.fmt.bufPrint(out, "\r\n--{s}--\r\n", .{boundary}) catch null;
}

pub fn uploadId(seed: u64, out: *[5]u8) []const u8 {
    const alphabet = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
    var state = seed | 1;
    for (out) |*b| {
        state ^= state << 13;
        state ^= state >> 7;
        state ^= state << 17;
        b.* = alphabet[@intCast(state % alphabet.len)];
    }
    return out[0..];
}

pub fn parseUploadResponseUrl(json: []const u8, out: []u8) ?[]const u8 {
    const Response = struct { success: bool = false, url: ?[]const u8 = null };
    var parsed = std.json.parseFromSlice(Response, std.heap.page_allocator, json, .{ .ignore_unknown_fields = true }) catch return null;
    defer parsed.deinit();
    if (!parsed.value.success) return null;
    const url = parsed.value.url orelse return null;
    if (!std.mem.startsWith(u8, url, "http") or std.mem.indexOfScalar(u8, url, '\\') != null or url.len > out.len) return null;
    @memcpy(out[0..url.len], url);
    return out[0..url.len];
}

fn wide(comptime s: []const u8) []const u16 {
    return std.unicode.utf8ToUtf16LeStringLiteral(s);
}

test "findImageUrls finds screencast2, https image URLs and markdown images" {
    var out: [8]Range = undefined;
    const text = wide("see https://screencast2.com/Jdjhr.png and ![x](https://example.com/a/b.JPG?w=1), also https://example.com/page.html done");
    const n = findImageUrls(text, &out);
    try std.testing.expectEqual(@as(usize, 2), n);
    try std.testing.expect(std.mem.eql(u16, text[out[0].start..out[0].end], wide("https://screencast2.com/Jdjhr.png")));
    try std.testing.expect(std.mem.eql(u16, text[out[1].start..out[1].end], wide("https://example.com/a/b.JPG?w=1")));
}

test "findImageUrls handles bare screencast2 links, trailing punctuation and duplicates" {
    var out: [8]Range = undefined;
    const text = wide("look: screencast2.com/abc12.png. Again https://screencast2.com/abc12.png, and https://x.test/p.gif) plus http://x.test/plain.gif");
    const n = findImageUrls(text, &out);
    try std.testing.expectEqual(@as(usize, 3), n);
    try std.testing.expect(std.mem.eql(u16, text[out[0].start..out[0].end], wide("screencast2.com/abc12.png")));
    try std.testing.expect(std.mem.eql(u16, text[out[2].start..out[2].end], wide("https://x.test/p.gif")));
}

test "findImageUrls ignores non-images, webp is an image, glued text is not a token" {
    var out: [8]Range = undefined;
    try std.testing.expectEqual(@as(usize, 0), findImageUrls(wide("https://example.com/readme.md and https://example.com/x.pngx"), &out));
    try std.testing.expectEqual(@as(usize, 1), findImageUrls(wide("https://cdn.test/photo.webp"), &out));
    try std.testing.expectEqual(@as(usize, 0), findImageUrls(wide("nothttps://a.test/x.png"), &out));
    var one: [1]Range = undefined;
    try std.testing.expectEqual(@as(usize, 1), findImageUrls(wide("https://a.test/1.png https://a.test/2.png"), &one));
}

test "urlUtf8 adds https to bare links and rejects non-ascii" {
    var buf: [64]u8 = undefined;
    try std.testing.expectEqualStrings("https://screencast2.com/a.png", urlUtf8(wide("screencast2.com/a.png"), &buf).?);
    try std.testing.expectEqualStrings("https://x.test/a.png", urlUtf8(wide("https://x.test/a.png"), &buf).?);
    try std.testing.expect(urlUtf8(wide("https://x.test/\u{e9}.png"), &buf) == null);
}

test "imageExt is case-insensitive and ignores query and fragment" {
    try std.testing.expectEqualStrings("png", imageExt("a/b.PNG").?);
    try std.testing.expectEqualStrings("jpeg", imageExt("https://x.test/a.jpeg#top").?);
    try std.testing.expect(imageExt("https://x.test/a.txt") == null);
    try std.testing.expect(imageExt("noext") == null);
    try std.testing.expect(hasImageExt("C:\\pics\\cat.webp"));
}

test "thumbSize keeps aspect, never upscales, caps height" {
    const a = thumbSize(1920, 1080, 320, 480);
    try std.testing.expectEqual(@as(i32, 320), a.w);
    try std.testing.expectEqual(@as(i32, 180), a.h);
    const b = thumbSize(100, 50, 320, 480);
    try std.testing.expectEqual(@as(i32, 100), b.w);
    try std.testing.expectEqual(@as(i32, 50), b.h);
    const c = thumbSize(400, 4000, 320, 480);
    try std.testing.expectEqual(@as(i32, 48), c.w);
    try std.testing.expectEqual(@as(i32, 480), c.h);
    const p = thumbSize(0, 0, 320, 480);
    try std.testing.expectEqual(@as(i32, 320), p.w);
    try std.testing.expectEqual(@as(i32, 180), p.h);
}

test "cacheKey is stable and cacheFileName keeps the extension" {
    try std.testing.expectEqual(cacheKey("https://screencast2.com/a.png"), cacheKey("https://screencast2.com/a.png"));
    try std.testing.expect(cacheKey("https://screencast2.com/a.png") != cacheKey("https://screencast2.com/b.png"));
    var buf: [32]u8 = undefined;
    const name = cacheFileName("https://screencast2.com/a.png", &buf).?;
    try std.testing.expectEqual(@as(usize, 20), name.len);
    try std.testing.expect(std.mem.endsWith(u8, name, ".png"));
}

test "parseUploadConfig reads the screencast2 toml" {
    const toml = "[upload]\r\nupload_secret = \"s3cret\"\r\napi_base_url = \"https://screencast2.com/\"\r\n";
    const cfg = parseUploadConfig(toml).?;
    try std.testing.expectEqualStrings("s3cret", cfg.secretSlice());
    try std.testing.expectEqualStrings("https://screencast2.com", cfg.baseSlice());
    try std.testing.expect(parseUploadConfig("api_base_url = \"x\"") == null);
}

test "multipart body wraps the file with id and screenshot fields" {
    var a: [512]u8 = undefined;
    var b: [64]u8 = undefined;
    const prefix = multipartPrefix(&a, "BND", "abc12", "abc12.png", "image/png").?;
    const suffix = multipartSuffix(&b, "BND").?;
    try std.testing.expect(std.mem.indexOf(u8, prefix, "name=\"id\"\r\n\r\nabc12\r\n") != null);
    try std.testing.expect(std.mem.indexOf(u8, prefix, "name=\"screenshot\"; filename=\"abc12.png\"") != null);
    try std.testing.expect(std.mem.endsWith(u8, prefix, "Content-Type: image/png\r\n\r\n"));
    try std.testing.expectEqualStrings("\r\n--BND--\r\n", suffix);
}

test "parseUploadResponseUrl needs success and a url" {
    var out: [1024]u8 = undefined;
    try std.testing.expectEqualStrings("https://screencast2.com/a.png", parseUploadResponseUrl("{\"success\":true,\"url\":\"https://screencast2.com/a.png\",\"id\":\"a\"}", &out).?);
    try std.testing.expect(parseUploadResponseUrl("{\"error\":\"Unauthorized\"}", &out) == null);
    try std.testing.expect(parseUploadResponseUrl("{\"success\":true}", &out) == null);
}

test "splitUrl handles ports, queries and fragments" {
    const a = splitUrl("https://screencast2.com/abc.png").?;
    try std.testing.expect(a.secure and a.port == 443);
    try std.testing.expectEqualStrings("screencast2.com", a.host);
    try std.testing.expectEqualStrings("/abc.png", a.path);
    const b = splitUrl("http://localhost:8787/api/upload-screenshot?x=1#frag").?;
    try std.testing.expect(!b.secure and b.port == 8787);
    try std.testing.expectEqualStrings("/api/upload-screenshot?x=1", b.path);
    try std.testing.expectEqualStrings("/", splitUrl("https://example.com").?.path);
    try std.testing.expect(splitUrl("ftp://x.test/a.png") == null);
    try std.testing.expect(splitUrl("https://user@x.test/a.png") == null);
}

test "uploadId gives five alphanumerics" {
    var buf: [5]u8 = undefined;
    const id = uploadId(42, &buf);
    try std.testing.expectEqual(@as(usize, 5), id.len);
    for (id) |c| try std.testing.expect(std.ascii.isAlphanumeric(c));
}

test "upload response decodes escaped URLs and ignores nested success and URL decoys" {
    var out: [1024]u8 = undefined;
    try std.testing.expectEqualStrings("https://example.test/a?x=1&y=2", parseUploadResponseUrl("{\"extra\":{\"url\":\"https://wrong.test\"},\"url\":\"https:\\/\\/example.test\\/a?x=1\\u0026y=2\",\"success\":true}", &out).?);
    try std.testing.expect(parseUploadResponseUrl("{\"extra\":{\"success\":true},\"url\":\"https://wrong.test\"}", &out) == null);
}
