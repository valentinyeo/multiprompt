const std = @import("std");
const w = @import("win32.zig");
const L = std.unicode.utf8ToUtf16LeStringLiteral;
const HRESULT = i32;
const Slot = *const anyopaque;
const DWRITE_MEASURING_MODE_GDI_CLASSIC = 1;
const DWRITE_RENDERING_MODE_NATURAL_SYMMETRIC = 5;

const Factory = extern struct {
    v: *const extern struct {
        unknown: [3]Slot,
        font_collection_and_files: [7]Slot,
        createRenderingParams: *const fn (*Factory, *?*RenderingParams) callconv(w.WINAPI) HRESULT,
        monitorRenderingParams: Slot,
        createCustomRenderingParams: *const fn (*Factory, f32, f32, f32, u32, u32, *?*RenderingParams) callconv(w.WINAPI) HRESULT,
        font_loaders_and_text: [4]Slot,
        getGdiInterop: *const fn (*Factory, *?*GdiInterop) callconv(w.WINAPI) HRESULT,
    },
};
const RenderingParams = extern struct {
    v: *const extern struct {
        unknown: [2]Slot,
        release: *const fn (*RenderingParams) callconv(w.WINAPI) u32,
        getGamma: *const fn (*RenderingParams) callconv(w.WINAPI) f32,
        getEnhancedContrast: *const fn (*RenderingParams) callconv(w.WINAPI) f32,
        remaining: [3]Slot,
    },
};
const GdiInterop = extern struct {
    v: *const extern struct {
        unknown: [3]Slot,
        logfont_conversions: [3]Slot,
        createFontFaceFromHdc: *const fn (*GdiInterop, w.HANDLE, *?*FontFace) callconv(w.WINAPI) HRESULT,
        createBitmapRenderTarget: *const fn (*GdiInterop, w.HANDLE, u32, u32, *?*BitmapRenderTarget) callconv(w.WINAPI) HRESULT,
    },
};
const FontFace = extern struct {
    v: *const extern struct {
        unknown: [2]Slot,
        release: *const fn (*FontFace) callconv(w.WINAPI) u32,
        font_properties_and_metrics: [8]Slot,
        getGlyphIndices: *const fn (*FontFace, [*]const u32, u32, [*]u16) callconv(w.WINAPI) HRESULT,
    },
};
const BitmapRenderTarget = extern struct {
    v: *const extern struct {
        unknown: [3]Slot,
        drawGlyphRun: *const fn (*BitmapRenderTarget, f32, f32, u32, *const GlyphRun, *RenderingParams, u32, ?*w.RECT) callconv(w.WINAPI) HRESULT,
        getMemoryDC: *const fn (*BitmapRenderTarget) callconv(w.WINAPI) w.HANDLE,
        getPixelsPerDip: Slot,
        setPixelsPerDip: *const fn (*BitmapRenderTarget, f32) callconv(w.WINAPI) HRESULT,
        transforms_and_size: [3]Slot,
        resize: *const fn (*BitmapRenderTarget, u32, u32) callconv(w.WINAPI) HRESULT,
    },
};
const GlyphRun = extern struct {
    face: *FontFace,
    em_size: f32,
    count: u32,
    indices: [*]const u16,
    advances: [*]const f32,
    offsets: ?*const anyopaque = null,
    sideways: w.BOOL = 0,
    bidi_level: u32 = 0,
};
const TextMetric = extern struct {
    height: i32,
    ascent: i32,
    descent: i32,
    internal_leading: i32,
    external_leading: i32,
    average_width: i32,
    maximum_width: i32,
    weight: i32,
    overhang: i32,
    digitized_aspect_x: i32,
    digitized_aspect_y: i32,
    first: u16,
    last: u16,
    default: u16,
    break_char: u16,
    italic: u8,
    underlined: u8,
    struck_out: u8,
    pitch: u8,
    charset: u8,
};
const LogFont = extern struct {
    height: i32,
    width: i32,
    escapement: i32,
    orientation: i32,
    weight: i32,
    attributes: [8]u8,
    name: [32]u16,
};
extern "dwrite" fn DWriteCreateFactory(u32, *const w.GUID, *?*Factory) callconv(w.WINAPI) HRESULT;
extern "gdi32" fn GetTextMetricsW(w.HANDLE, *TextMetric) callconv(w.WINAPI) w.BOOL;
extern "gdi32" fn GetBkMode(w.HANDLE) callconv(w.WINAPI) i32;
extern "gdi32" fn GetBkColor(w.HANDLE) callconv(w.WINAPI) u32;
extern "gdi32" fn GetMapMode(w.HANDLE) callconv(w.WINAPI) i32;
extern "gdi32" fn GdiFlush() callconv(w.WINAPI) w.BOOL;

const CachedFace = struct {
    font: w.HANDLE = null,
    face: ?*FontFace = null,
};
threadlocal var factory: ?*Factory = null;
threadlocal var interop: ?*GdiInterop = null;
threadlocal var params: ?*RenderingParams = null;
threadlocal var target: ?*BitmapRenderTarget = null;
threadlocal var target_width: u32 = 0;
threadlocal var target_height: u32 = 0;
threadlocal var faces: [32]CachedFace = @splat(.{});
pub threadlocal var painted_runs: u64 = 0;
pub threadlocal var fallback_runs: u64 = 0;
pub const IGSH_610 = true;

pub fn enabled() bool {
    var value: [8]u16 = undefined;
    return IGSH_610 and !(w.GetEnvironmentVariableW(L("IGSH_610"), &value, value.len) == 1 and value[0] == '0');
}

pub fn resetFonts() void {
    for (&faces) |*entry| {
        if (entry.face) |face| _ = face.v.release(face);
        entry.* = .{};
    }
}

fn initialize() bool {
    if (factory == null) {
        const iid = w.GUID{ .Data1 = 0xb859ee5a, .Data2 = 0xd838, .Data3 = 0x4b5b, .Data4 = .{ 0xa2, 0xe8, 0x1a, 0xdc, 0x7d, 0x93, 0xdb, 0x48 } };
        if (DWriteCreateFactory(0, &iid, &factory) < 0) return false;
    }
    const f = factory orelse return false;
    if (interop == null and f.v.getGdiInterop(f, &interop) < 0) return false;
    if (params == null) {
        var defaults: ?*RenderingParams = null;
        if (f.v.createRenderingParams(f, &defaults) < 0) return false;
        const p = defaults orelse return false;
        defer _ = p.v.release(p);
        if (f.v.createCustomRenderingParams(f, p.v.getGamma(p), p.v.getEnhancedContrast(p), 0, 0, DWRITE_RENDERING_MODE_NATURAL_SYMMETRIC, &params) < 0) return false;
    }
    return interop != null and params != null;
}

fn fontFace(hdc: w.HANDLE) ?*FontFace {
    const font = w.GetCurrentObject(hdc, 6) orelse return null;
    for (&faces) |*entry| if (entry.font == font) return entry.face;
    for (&faces) |*entry| {
        if (entry.font != null) continue;
        var face: ?*FontFace = null;
        if (interop.?.v.createFontFaceFromHdc(interop.?, hdc, &face) < 0) return null;
        entry.* = .{ .font = font, .face = face };
        return face;
    }
    return null;
}

const max_units = 4096;
const Segment = struct {
    codepoints: [max_units]u32 = undefined,
    ends: [max_units]usize = undefined,
    indices: [max_units]u16 = undefined,
    advances: [max_units]f32 = undefined,
    count: usize = 0,
    width: i32 = 0,
};

fn decode(text: []const u16, segment: *Segment) bool {
    if (text.len > max_units) return false;
    var i: usize = 0;
    segment.count = 0;
    while (i < text.len) {
        var cp: u32 = text[i];
        i += 1;
        if (cp >= 0xd800 and cp <= 0xdbff) {
            if (i == text.len or text[i] < 0xdc00 or text[i] > 0xdfff) return false;
            cp = 0x10000 + ((cp - 0xd800) << 10) + (text[i] - 0xdc00);
            i += 1;
        } else if (cp >= 0xdc00 and cp <= 0xdfff) return false;
        if (cp < 0x20 or cp == 0x7f or (cp >= 0x300 and cp <= 0x36f) or (cp >= 0x590 and cp <= 0x109f) or (cp >= 0x1780 and cp <= 0x18af) or (cp >= 0x200b and cp <= 0x200f) or (cp >= 0x202a and cp <= 0x202e) or (cp >= 0x2060 and cp <= 0x206f) or (cp >= 0xfe00 and cp <= 0xfe0f) or (cp >= 0xe0100 and cp <= 0xe01ef)) return false;
        segment.codepoints[segment.count] = cp;
        segment.ends[segment.count] = i;
        segment.count += 1;
    }
    return true;
}

fn prepare(hdc: w.HANDLE, face: *FontFace, text: []const u16, segment: *Segment) bool {
    if (!decode(text, segment)) return false;
    if (face.v.getGlyphIndices(face, &segment.codepoints, @intCast(segment.count), &segment.indices) < 0) return false;
    for (segment.indices[0..segment.count]) |glyph| if (glyph == 0) return false;
    var extents: [max_units]i32 = undefined;
    var fit: i32 = 0;
    var size: w.SIZE = undefined;
    if (w.GetTextExtentExPointW(hdc, text.ptr, @intCast(text.len), std.math.maxInt(i32), &fit, &extents, &size) == 0) return false;
    var previous: i32 = 0;
    for (segment.ends[0..segment.count], 0..) |end, n| {
        const next = extents[end - 1];
        segment.advances[n] = @floatFromInt(next - previous);
        previous = next;
    }
    segment.width = size.cx;
    return previous == size.cx;
}

fn ellipsize(hdc: w.HANDLE, face: *FontFace, width: i32, segment: *Segment) ?usize {
    const dot = [1]u32{'.'};
    var glyph: [1]u16 = undefined;
    if (face.v.getGlyphIndices(face, &dot, 1, &glyph) < 0 or glyph[0] == 0) return null;
    var dot_size: w.SIZE = undefined;
    if (w.GetTextExtentPoint32W(hdc, L("."), 1, &dot_size) == 0) return null;
    const dots = 3;
    var kept: usize = 0;
    var used: i32 = 0;
    while (kept < segment.count) : (kept += 1) {
        const next = used + @as(i32, @intFromFloat(segment.advances[kept]));
        if (next + dots * dot_size.cx > width) break;
        used = next;
    }
    if (kept + dots > max_units) return null;
    @memset(segment.indices[kept..][0..dots], glyph[0]);
    @memset(segment.advances[kept..][0..dots], @floatFromInt(dot_size.cx));
    segment.count = kept + dots;
    segment.width = used + dots * dot_size.cx;
    return kept;
}

pub fn emHeight(hdc: w.HANDLE) ?i32 {
    var metric: TextMetric = undefined;
    if (GetTextMetricsW(hdc, &metric) == 0) return null;
    return metric.height - metric.internal_leading;
}

fn ensureTarget(hdc: w.HANDLE, width: u32, height: u32) bool {
    if (target == null) {
        if (interop.?.v.createBitmapRenderTarget(interop.?, hdc, width, height, &target) < 0) return false;
    } else if (width > target_width or height > target_height) {
        if (target.?.v.resize(target.?, @max(width, target_width), @max(height, target_height)) < 0) return false;
    }
    target_width = @max(width, target_width);
    target_height = @max(height, target_height);
    return target != null and target.?.v.setPixelsPerDip(target.?, 1) >= 0;
}

fn paint(hdc: w.HANDLE, text: []const u16, rect: w.RECT, flags: u32) ?i32 {
    const supported = w.DT_SINGLELINE | w.DT_NOPREFIX | w.DT_VCENTER | w.DT_CENTER | w.DT_RIGHT | w.DT_END_ELLIPSIS;
    if ((flags & ~supported) != 0 or (flags & w.DT_SINGLELINE) == 0 or (flags & w.DT_NOPREFIX) == 0 or GetMapMode(hdc) != 1) return null;
    var metric: TextMetric = undefined;
    var lf: LogFont = undefined;
    if (GetTextMetricsW(hdc, &metric) == 0 or w.GetObjectW(w.GetCurrentObject(hdc, 6), @sizeOf(LogFont), &lf) == 0) return null;
    if (lf.escapement != 0 or lf.orientation != 0 or metric.struck_out != 0) return null;
    if (!initialize()) return null;
    const face = fontFace(hdc) orelse return null;
    var segment: Segment = .{};
    if (!prepare(hdc, face, text, &segment)) return null;
    const width = rect.right - rect.left;
    const height = rect.bottom - rect.top;
    if (width <= 0 or height <= 0) return 0;
    if ((flags & w.DT_END_ELLIPSIS) != 0 and segment.width > width and ellipsize(hdc, face, width, &segment) == null) return null;
    if (!ensureTarget(hdc, @intCast(width), @intCast(height))) return null;
    const t = target.?;
    const memory = t.v.getMemoryDC(t);
    if (memory == null or w.BitBlt(memory, 0, 0, width, height, hdc, rect.left, rect.top, w.GDI_SRCCOPY) == 0) return null;
    const x = if ((flags & w.DT_RIGHT) != 0) width - segment.width else if ((flags & w.DT_CENTER) != 0) @divTrunc(width - segment.width, 2) else 0;
    const y = if ((flags & w.DT_VCENTER) != 0) @divTrunc(height - metric.height, 2) else 0;
    const color = w.GetTextColor(hdc);
    if (GetBkMode(hdc) == 2) {
        const brush = w.CreateSolidBrush(GetBkColor(hdc)) orelse return null;
        defer _ = w.DeleteObject(brush);
        const background = w.RECT{ .left = x, .top = y, .right = x + segment.width, .bottom = y + metric.height };
        if (w.FillRect(memory, &background, brush) == 0) return null;
    }
    const em = metric.height - metric.internal_leading;
    if (em <= 0) return null;
    const run = GlyphRun{ .face = face, .em_size = @floatFromInt(em), .count = @intCast(segment.count), .indices = &segment.indices, .advances = &segment.advances };
    if (t.v.drawGlyphRun(t, @floatFromInt(x), @floatFromInt(y + metric.ascent), DWRITE_MEASURING_MODE_GDI_CLASSIC, &run, params.?, color, null) < 0) return null;
    if (metric.underlined != 0) {
        var post: [12]u8 = undefined;
        var head: [20]u8 = undefined;
        if (w.GetFontData(hdc, 0x74736f70, 0, &post, post.len) != post.len or w.GetFontData(hdc, 0x64616568, 0, &head, head.len) != head.len) return null;
        const units = std.mem.readInt(u16, head[18..20], .big);
        if (units == 0) return null;
        const position = @divTrunc(@as(i32, std.mem.readInt(i16, post[8..10], .big)) * em, units);
        const thickness = @max(1, @divTrunc(@as(i32, std.mem.readInt(i16, post[10..12], .big)) * em, units));
        const underline = w.RECT{ .left = x, .top = y + metric.ascent - position, .right = x + segment.width, .bottom = y + metric.ascent - position + thickness };
        const brush = w.CreateSolidBrush(color) orelse return null;
        defer _ = w.DeleteObject(brush);
        if (w.FillRect(memory, &underline, brush) == 0) return null;
    }
    if (w.BitBlt(hdc, rect.left, rect.top, width, height, memory, 0, 0, w.GDI_SRCCOPY) == 0) return null;
    painted_runs += 1;
    return metric.height;
}

pub fn draw(hdc: w.HANDLE, text: [*]const u16, count: i32, rect: *w.RECT, flags: u32) i32 {
    if (enabled() and count != 0) {
        const len: usize = if (count < 0) std.mem.len(@as([*:0]const u16, @ptrCast(text))) else @intCast(count);
        if (len > 0) if (paint(hdc, text[0..len], rect.*, flags)) |height| return height;
    }
    fallback_runs += 1;
    return w.DrawTextW(hdc, text, count, rect, flags);
}

test "IGSH-610 switch defaults on and only zero restores GDI" {
    var previous: [32768]u16 = undefined;
    const length = w.GetEnvironmentVariableW(L("IGSH_610"), &previous, previous.len);
    defer _ = w.SetEnvironmentVariableW(L("IGSH_610"), if (length > 0 and length < previous.len) @ptrCast(&previous) else null);
    try std.testing.expect(w.SetEnvironmentVariableW(L("IGSH_610"), null) != 0);
    try std.testing.expect(enabled());
    try std.testing.expect(w.SetEnvironmentVariableW(L("IGSH_610"), L("0")) != 0);
    try std.testing.expect(!enabled());
    try std.testing.expect(w.SetEnvironmentVariableW(L("IGSH_610"), L("1")) != 0);
    try std.testing.expect(enabled());
}

test "IGSH-610 surrogate decoding preserves scalar and UTF-16 advance boundaries" {
    var segment: Segment = .{};
    try std.testing.expect(decode(L("A\u{1f600}B"), &segment));
    try std.testing.expectEqualSlices(u32, &.{ 'A', 0x1f600, 'B' }, segment.codepoints[0..segment.count]);
    try std.testing.expectEqualSlices(usize, &.{ 1, 3, 4 }, segment.ends[0..segment.count]);
    try std.testing.expect(!decode(&.{0xd800}, &segment));
    try std.testing.expect(!decode(&.{0xdc00}, &segment));
}

test "IGSH-610 real glyph runs match GDI advances and missing glyphs use pixel-identical fallback" {
    const fonts = @import("fonts.zig");
    try std.testing.expect(fonts.register());
    defer fonts.unregister();
    const dc = w.CreateCompatibleDC(null) orelse return error.TestUnexpectedResult;
    defer _ = w.DeleteDC(dc);
    const info = w.BITMAPINFO{ .header = .{ .width = 400, .height = -60 } };
    var bits: ?*anyopaque = null;
    const bitmap = w.CreateDIBSection(dc, &info, 0, &bits, null, 0) orelse return error.TestUnexpectedResult;
    defer _ = w.DeleteObject(bitmap);
    const old_bitmap = w.SelectObject(dc, bitmap);
    defer _ = w.SelectObject(dc, old_bitmap);
    const font = fonts.chat(-18, false, false, false, .{}) orelse return error.TestUnexpectedResult;
    defer _ = w.DeleteObject(font);
    defer resetFonts();
    const old_font = w.SelectObject(dc, font);
    defer _ = w.SelectObject(dc, old_font);
    try std.testing.expect(initialize());
    const face = fontFace(dc) orelse return error.TestUnexpectedResult;
    const sample = L("AV To office widths 0123");
    var segment: Segment = .{};
    try std.testing.expect(prepare(dc, face, sample, &segment));
    var sum: f32 = 0;
    for (segment.advances[0..segment.count], segment.ends[0..segment.count]) |advance, end| {
        sum += advance;
        var size: w.SIZE = undefined;
        try std.testing.expect(w.GetTextExtentPoint32W(dc, sample, @intCast(end), &size) != 0);
        try std.testing.expectEqual(@as(f32, @floatFromInt(size.cx)), sum);
    }
    try std.testing.expectEqual(@as(f32, @floatFromInt(segment.width)), sum);
    var rc = w.RECT{ .left = 0, .top = 0, .right = 400, .bottom = 60 };
    _ = w.SetBkMode(dc, w.TRANSPARENT);
    _ = w.SetTextColor(dc, 0xffffff);
    const pixels = @as([*]u8, @ptrCast(bits.?))[0 .. 400 * 60 * 4];
    @memset(pixels, 0);
    const before_painted = painted_runs;
    const before_fallback = fallback_runs;
    _ = draw(dc, sample, @intCast(sample.len), &rc, w.DT_SINGLELINE | w.DT_NOPREFIX);
    if (enabled()) {
        try std.testing.expectEqual(before_painted + 1, painted_runs);
        try std.testing.expectEqual(before_fallback, fallback_runs);
    } else {
        try std.testing.expectEqual(before_painted, painted_runs);
        try std.testing.expectEqual(before_fallback + 1, fallback_runs);
    }
    _ = GdiFlush();
    @memset(pixels, 0);
    try std.testing.expect(paint(dc, sample, rc, w.DT_SINGLELINE | w.DT_NOPREFIX) != null);
    _ = GdiFlush();
    var smoothed = false;
    var inked = false;
    var pixel: usize = 0;
    while (pixel < pixels.len) : (pixel += 4) {
        try std.testing.expectEqual(pixels[pixel], pixels[pixel + 1]);
        try std.testing.expectEqual(pixels[pixel], pixels[pixel + 2]);
        inked = inked or pixels[pixel] != 0;
        smoothed = smoothed or (pixels[pixel] > 0 and pixels[pixel] < 255);
    }
    try std.testing.expect(inked and smoothed);
    const first_target = target;
    try std.testing.expect(paint(dc, sample, rc, w.DT_SINGLELINE | w.DT_NOPREFIX) != null);
    try std.testing.expectEqual(first_target, target);
    _ = GdiFlush();
    const missing = L("missing \u{10ffff}");
    try std.testing.expect(!prepare(dc, face, missing, &segment));
    @memset(pixels, 0);
    try std.testing.expect(paint(dc, missing, rc, w.DT_SINGLELINE | w.DT_NOPREFIX) == null);
    const before = fallback_runs;
    _ = draw(dc, missing, @intCast(missing.len), &rc, w.DT_SINGLELINE | w.DT_NOPREFIX);
    try std.testing.expectEqual(before + 1, fallback_runs);
    _ = GdiFlush();
    const actual = try std.testing.allocator.dupe(u8, pixels);
    defer std.testing.allocator.free(actual);
    @memset(pixels, 0);
    _ = w.DrawTextW(dc, missing, @intCast(missing.len), &rc, w.DT_SINGLELINE | w.DT_NOPREFIX);
    _ = GdiFlush();
    try std.testing.expectEqualSlices(u8, actual, pixels);
    resetFonts();
    for (faces) |entry| try std.testing.expect(entry.face == null and entry.font == null);
}

test "IGSH-678 overflowing end-ellipsis code rows keep GDI truncation and draw through DirectWrite" {
    const fonts = @import("fonts.zig");
    try std.testing.expect(fonts.register());
    defer fonts.unregister();
    const dc = w.CreateCompatibleDC(null) orelse return error.TestUnexpectedResult;
    defer _ = w.DeleteDC(dc);
    const width = 200;
    const height = 24;
    const info = w.BITMAPINFO{ .header = .{ .width = width, .height = -height } };
    var bits: ?*anyopaque = null;
    const bitmap = w.CreateDIBSection(dc, &info, 0, &bits, null, 0) orelse return error.TestUnexpectedResult;
    defer _ = w.DeleteObject(bitmap);
    const old_bitmap = w.SelectObject(dc, bitmap);
    defer _ = w.SelectObject(dc, old_bitmap);
    const font = fonts.create(-11, 0, 0, 0, 600, 0, 0, 0, 0, 0, 0, fonts.CHAT_QUALITY, 0, L(fonts.MONO_FACE)) orelse return error.TestUnexpectedResult;
    defer _ = w.DeleteObject(font);
    defer resetFonts();
    const old_font = w.SelectObject(dc, font);
    defer _ = w.SelectObject(dc, old_font);
    try std.testing.expect(initialize());
    const face = fontFace(dc) orelse return error.TestUnexpectedResult;
    const line = L("+<p>Decision, reviewer 2026-10-23 answering the question about the smaller views");
    var segment: Segment = .{};
    try std.testing.expect(prepare(dc, face, line, &segment));
    try std.testing.expect(segment.width > width);
    const kept = ellipsize(dc, face, width, &segment) orelse return error.TestUnexpectedResult;
    try std.testing.expect(kept > 0 and segment.width <= width);
    var gdi: [line.len + 8]u16 = @splat(0);
    @memcpy(gdi[0..line.len], line);
    var gdi_rc = w.RECT{ .left = 0, .top = 0, .right = width, .bottom = height };
    _ = w.DrawTextW(dc, &gdi, @intCast(line.len), &gdi_rc, w.DT_SINGLELINE | w.DT_NOPREFIX | w.DT_END_ELLIPSIS | 0x10000);
    const dots = std.mem.indexOf(u16, &gdi, L("...")) orelse return error.TestUnexpectedResult;
    try std.testing.expectEqualSlices(u16, line[0..segment.ends[kept - 1]], gdi[0..dots]);
    const pixels = @as([*]u8, @ptrCast(bits.?))[0 .. width * height * 4];
    @memset(pixels, 0);
    _ = w.SetBkMode(dc, w.TRANSPARENT);
    _ = w.SetTextColor(dc, 0xffffff);
    var rc = w.RECT{ .left = 0, .top = 0, .right = width, .bottom = height };
    const before_painted = painted_runs;
    const before_fallback = fallback_runs;
    _ = draw(dc, line, @intCast(line.len), &rc, w.DT_SINGLELINE | w.DT_END_ELLIPSIS | w.DT_NOPREFIX | w.DT_VCENTER);
    _ = GdiFlush();
    if (!enabled()) {
        try std.testing.expectEqual(before_fallback + 1, fallback_runs);
        return;
    }
    try std.testing.expectEqual(before_painted + 1, painted_runs);
    try std.testing.expectEqual(before_fallback, fallback_runs);
    var smoothed = false;
    var last_inked: usize = 0;
    var pixel: usize = 0;
    while (pixel < pixels.len) : (pixel += 4) {
        if (pixels[pixel] == 0) continue;
        last_inked = @max(last_inked, (pixel / 4) % width);
        smoothed = smoothed or pixels[pixel] < 255;
    }
    try std.testing.expect(smoothed and last_inked > 0 and @as(i32, @intCast(last_inked)) < segment.width);
}
