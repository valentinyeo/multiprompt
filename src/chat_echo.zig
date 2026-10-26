const std = @import("std");

pub const MIN_PARTIAL: usize = 12;
const BLOCK_NORM_CAP: usize = 32768;

fn isSpace(c: u16) bool {
    return c == ' ' or c == '\t' or c == '\r' or c == '\n' or c == 0xA0;
}

fn asciiLower(c: u16) u16 {
    return if (c >= 'A' and c <= 'Z') c + 32 else c;
}

fn pastedTagLen(text: []const u16, i: usize) usize {
    if (text[i] != '<') return 0;
    var j = i + 1;
    if (j < text.len and text[j] == '/') j += 1;
    const name = "pasted_content";
    if (j + name.len > text.len) return 0;
    for (name, 0..) |ch, k| {
        if (asciiLower(text[j + k]) != ch) return 0;
    }
    j += name.len;
    while (j < text.len) : (j += 1) {
        if (text[j] == '>') return j + 1 - i;
        if (text[j] == '<') return 0;
    }
    return 0;
}

pub fn normalize(text: []const u16, out: []u16) []const u16 {
    var n: usize = 0;
    var pending_space = false;
    var i: usize = 0;
    while (i < text.len) {
        const tag = pastedTagLen(text, i);
        if (tag > 0) {
            if (n > 0) pending_space = true;
            i += tag;
            continue;
        }
        const c = text[i];
        i += 1;
        if (isSpace(c)) {
            if (n > 0) pending_space = true;
            continue;
        }
        if (pending_space) {
            if (n >= out.len) break;
            out[n] = ' ';
            n += 1;
            pending_space = false;
        }
        if (n >= out.len) break;
        out[n] = c;
        n += 1;
    }
    return out[0..n];
}

fn stripTrailingEllipsis(s: []const u16) []const u16 {
    var end = s.len;
    while (end > 0 and (s[end - 1] == 0x2026 or s[end - 1] == '.' or s[end - 1] == ' ')) end -= 1;
    return s[0..end];
}

pub fn blockMatches(block_text: []const u16, prefix: []const u16) bool {
    if (prefix.len == 0) return false;
    var buf: [BLOCK_NORM_CAP]u16 = undefined;
    const norm = normalize(block_text, &buf);
    if (norm.len == 0) return false;
    if (norm.len >= prefix.len and std.mem.eql(u16, norm[0..prefix.len], prefix)) return true;
    if (norm.len < prefix.len) {
        const cut = stripTrailingEllipsis(norm);
        return cut.len >= MIN_PARTIAL and std.mem.eql(u16, prefix[0..cut.len], cut);
    }
    if (prefix.len >= MIN_PARTIAL) return std.mem.indexOf(u16, norm, prefix) != null;
    if (norm.len > prefix.len and norm[norm.len - prefix.len - 1] == ' ') {
        return std.mem.eql(u16, norm[norm.len - prefix.len ..], prefix);
    }
    return false;
}

fn readDigits(s: []const u8) ?i64 {
    if (s.len == 0) return null;
    var v: i64 = 0;
    for (s) |c| {
        if (c < '0' or c > '9') return null;
        v = v * 10 + (c - '0');
    }
    return v;
}

fn daysFromCivil(year: i64, month: i64, day: i64) i64 {
    const y = if (month <= 2) year - 1 else year;
    const era = @divFloor(y, 400);
    const yoe = y - era * 400;
    const mp = if (month > 2) month - 3 else month + 9;
    const doy = @divFloor(153 * mp + 2, 5) + day - 1;
    const doe = yoe * 365 + @divFloor(yoe, 4) - @divFloor(yoe, 100) + doy;
    return era * 146097 + doe - 719468;
}

pub fn stampMs(iso: []const u8) i64 {
    if (iso.len < 19 or iso[4] != '-' or iso[7] != '-' or iso[10] != 'T' or iso[13] != ':' or iso[16] != ':') return 0;
    const year = readDigits(iso[0..4]) orelse return 0;
    const month = readDigits(iso[5..7]) orelse return 0;
    const day = readDigits(iso[8..10]) orelse return 0;
    const hour = readDigits(iso[11..13]) orelse return 0;
    const minute = readDigits(iso[14..16]) orelse return 0;
    const second = readDigits(iso[17..19]) orelse return 0;
    if (year < 1970 or month < 1 or month > 12 or day < 1 or day > 31 or hour > 23 or minute > 59 or second > 60) return 0;
    var i: usize = 19;
    var millis: i64 = 0;
    if (i < iso.len and iso[i] == '.') {
        i += 1;
        var scale: i64 = 100;
        const frac_start = i;
        while (i < iso.len and iso[i] >= '0' and iso[i] <= '9') : (i += 1) {
            millis += (iso[i] - '0') * scale;
            scale = @divTrunc(scale, 10);
        }
        if (i == frac_start) return 0;
    }
    var offset_min: i64 = 0;
    if (i < iso.len and iso[i] == 'Z') {
        i += 1;
    } else if (i < iso.len and (iso[i] == '+' or iso[i] == '-')) {
        if (i + 6 != iso.len or iso[i + 3] != ':') return 0;
        const oh = readDigits(iso[i + 1 .. i + 3]) orelse return 0;
        const om = readDigits(iso[i + 4 .. i + 6]) orelse return 0;
        offset_min = oh * 60 + om;
        if (iso[i] == '-') offset_min = -offset_min;
        i += 6;
    }
    if (i != iso.len) return 0;
    const secs = daysFromCivil(year, month, day) * 86400 + hour * 3600 + minute * 60 + second - offset_min * 60;
    return secs * 1000 + millis;
}

pub fn fileTimeToUnixMs(filetime: u64) i64 {
    const epoch_diff: u64 = 116444736000000000;
    if (filetime <= epoch_diff) return 0;
    return @intCast((filetime - epoch_diff) / 10_000);
}

pub const SEND_SKEW_MS: i64 = 60_000;

pub const Anchor = struct {
    after_ms: i64 = 0,
    sent_ms: i64 = 0,
    user_count: u32 = 0,
    counted: bool = false,
};

pub const UserBlock = struct {
    text: []const u16,
    stamp_ms: i64 = 0,
};

pub const Pending = struct {
    prefix: []const u16,
    text: []const u16 = &.{},
    anchor: Anchor,
    unanchored_delivery: bool = false,
};

const Normalized = struct {
    text: []const u16,
    pos: usize = 0,
    started: bool = false,

    fn next(self: *Normalized) ?u16 {
        var space = false;
        while (self.pos < self.text.len) {
            const tag = pastedTagLen(self.text, self.pos);
            if (tag > 0 or isSpace(self.text[self.pos])) {
                self.pos += if (tag > 0) tag else 1;
                space = self.started;
                continue;
            }
            if (space) return ' ';
            const c = self.text[self.pos];
            self.pos += 1;
            self.started = true;
            return c;
        }
        return null;
    }
};

pub fn sameText(a: []const u16, b: []const u16) bool {
    var left = Normalized{ .text = a };
    var right = Normalized{ .text = b };
    while (true) {
        const l = left.next();
        const r = right.next();
        if (l != r) return false;
        if (l == null) return true;
    }
}

pub const OutboxState = enum(u8) { queued = 0, sending = 1, not_sent = 2, delivered = 3 };

pub const ISSUE_349_ORPHAN_SENDING_SETTLES = true;

pub fn orphanedSending(state: OutboxState, id: u64, verify_id: u64) bool {
    return ISSUE_349_ORPHAN_SENDING_SETTLES and state == .sending and id != verify_id;
}

pub fn mayType(state: OutboxState, write_started: bool, busy: bool, link_down: bool) bool {
    return state == .queued and !write_started and !busy and !link_down;
}

pub fn cancellable(state: OutboxState, removed_ms: i64) bool {
    return state == .delivered and removed_ms == 0;
}

test "IGSH-1010 only a message waiting in Claude's queue can be cancelled" {
    for (std.enums.values(OutboxState)) |state| {
        try std.testing.expectEqual(state == .delivered, cancellable(state, 0));
        try std.testing.expect(!cancellable(state, 1200));
    }
}

pub const PendingActions = struct { send_again: bool, remove: bool };

pub fn pendingActions(state: OutboxState) PendingActions {
    return .{ .send_again = state == .not_sent, .remove = state == .not_sent };
}

pub const ResendDecision = enum { mark_delivered, press_enter_only, write_again };

pub fn resendDecision(transcript_seen: bool, facts: DeliveryEvidence, input_held: ?bool) ResendDecision {
    if (transcript_seen or facts.enqueued) return .mark_delivered;
    if (input_held == true) return .press_enter_only;
    return .write_again;
}

pub fn verifyExpiredState(busy: bool, input_held: ?bool) OutboxState {
    return if (busy and input_held != true) .delivered else .not_sent;
}

pub fn needsFullSettle(state: OutboxState, write_started: bool, transcript_queued: bool, sent_ms: i64, now_ms: i64) bool {
    return ((state == .delivered and !transcript_queued) or (state == .not_sent and write_started)) and
        now_ms >= sent_ms and now_ms - sent_ms >= 60_000;
}

test "ISSUE-349 full settle waits for old written entries needing transcript evidence" {
    for (std.enums.values(OutboxState)) |state| {
        for ([_]bool{ false, true }) |written| {
            for ([_]bool{ false, true }) |queued| {
                const qualifies = (state == .delivered and !queued) or (state == .not_sent and written);
                try std.testing.expectEqual(qualifies, needsFullSettle(state, written, queued, 1000, 61_000));
                try std.testing.expect(!needsFullSettle(state, written, queued, 1000, 60_999));
                try std.testing.expect(!needsFullSettle(state, written, queued, 1000, 999));
            }
        }
    }
}

test "ISSUE-349 three stuck entries load unconfirmed and qualify for full settle" {
    const sent = [_]i64{ 1792250528437, 1792250551635, 1792250686932 };
    const relaunch_ms: i64 = 1792260198783;
    for (sent) |sent_ms| {
        const state = stateOnLoad(2, true);
        try std.testing.expectEqual(OutboxState.not_sent, state);
        try std.testing.expect(needsFullSettle(state, true, false, sent_ms, relaunch_ms));
    }
}

pub fn represented(text: []const u16, blocks: []const UserBlock) ?usize {
    if (text.len == 0) return null;
    for (blocks, 0..) |block, i| {
        if (sameText(text, block.text)) return i;
    }
    return null;
}

pub fn expiredSent(state: OutboxState, sent_ms: i64, now_ms: i64) bool {
    return state == .delivered and sent_ms > 0 and now_ms >= sent_ms and
        now_ms - sent_ms >= 10 * 60 * 1000;
}

pub fn pendingExpired(state: OutboxState, sent_ms: i64, now_ms: i64) bool {
    return state != .not_sent and now_ms >= sent_ms and now_ms - sent_ms >= 600_000;
}

pub const SETTLE_GRACE_MS: i64 = 20_000;

pub const DeliveryEvidence = struct {
    latest_ms: i64 = 0,
    refused: bool = false,
    removed_ms: i64 = 0,
    enqueued: bool = false,
};

pub const DeliveryWatch = struct {
    busy_seen: bool = false,
    idle_since_ms: i64 = 0,
    removed_ms: i64 = 0,
    removed_since_ms: i64 = 0,

    pub fn observe(self: *DeliveryWatch, busy: bool, now_ms: i64) void {
        if (busy) {
            self.busy_seen = true;
            self.idle_since_ms = 0;
        } else if (self.busy_seen and self.idle_since_ms == 0) {
            self.idle_since_ms = now_ms;
        }
    }

    pub fn evidence(self: *DeliveryWatch, facts: DeliveryEvidence, now_ms: i64) void {
        if (facts.removed_ms != self.removed_ms) {
            self.removed_ms = facts.removed_ms;
            self.removed_since_ms = if (facts.removed_ms > 0) now_ms else 0;
        }
    }

    pub fn due(self: DeliveryWatch, now_ms: i64, loaded_ms: i64) bool {
        for ([_]i64{ self.idle_since_ms, self.removed_since_ms }) |since| {
            if (since > 0 and now_ms >= since + SETTLE_GRACE_MS and loaded_ms >= since + SETTLE_GRACE_MS) return true;
        }
        return false;
    }
};

pub fn refusesCommand(warning: []const u16, text: []const u16) bool {
    var normalized: [16384]u16 = undefined;
    const norm = normalize(text, &normalized);
    if (norm.len == 0 or norm[0] != '/') return false;
    const end = std.mem.indexOfScalar(u16, norm, ' ') orelse norm.len;
    const lead = std.unicode.utf8ToUtf16LeStringLiteral("Unknown command: ");
    if (!std.mem.startsWith(u16, warning, lead)) return false;
    const rest = warning[lead.len..];
    if (!std.mem.startsWith(u16, rest, norm[0..end])) return false;
    return rest.len == end or rest[end] == ' ' or (rest[end] == '.' and (rest.len == end + 1 or rest[end + 1] == ' '));
}

pub fn stateOnLoad(saved: u8, write_started: bool) OutboxState {
    if (write_started) return if (saved == @intFromEnum(OutboxState.delivered)) .delivered else .not_sent;
    return if (saved == 0) .queued else .not_sent;
}

test "reserved uncertain sends stay unconfirmed across restart" {
    for ([_]OutboxState{ .queued, .sending, .not_sent }) |state| {
        try std.testing.expectEqual(OutboxState.not_sent, stateOnLoad(@intFromEnum(state), true));
        try std.testing.expect(!mayType(stateOnLoad(@intFromEnum(state), true), true, false, false));
    }
    try std.testing.expectEqual(OutboxState.queued, stateOnLoad(0, false));
    try std.testing.expectEqual(OutboxState.delivered, stateOnLoad(@intFromEnum(OutboxState.delivered), true));
}

fn messageMatches(block: []const u16, p: Pending) bool {
    if (p.text.len == 0) return newBlockMatches(block, p.prefix);
    if (sameText(block, p.text)) return true;
    var full: [16384]u16 = undefined;
    const norm = normalize(p.text, &full);
    if (pastePlaceholderMatches(block, norm)) return true;
    var buf: [BLOCK_NORM_CAP]u16 = undefined;
    const body = normalize(block, &buf);
    const cut = stripTrailingEllipsis(body);
    if (cut.len < body.len and cut.len >= MIN_PARTIAL and cut.len < norm.len and std.mem.startsWith(u16, norm, cut)) return true;
    if (norm.len == 0 or body.len <= norm.len) return false;
    if (norm.len < MIN_PARTIAL) return body[body.len - norm.len - 1] == ' ' and std.mem.endsWith(u16, body, norm);
    if (std.mem.endsWith(u16, body, norm)) return true;
    const at = std.mem.indexOf(u16, body, norm) orelse return false;
    return (at == 0 or body[at - 1] == ' ') and (at + norm.len == body.len or body[at + norm.len] == ' ');
}

pub fn isNewBlock(anchor: Anchor, stamp_ms: i64, ordinal: usize, window_full: bool) bool {
    if (stamp_ms > 0) {
        if (anchor.after_ms > 0) return stamp_ms > anchor.after_ms;
        if (anchor.sent_ms > 0) return stamp_ms + SEND_SKEW_MS >= anchor.sent_ms;
        return false;
    }
    return anchor.counted and !window_full and ordinal >= anchor.user_count;
}

const PASTE_PLACEHOLDER = [_]u16{ '[', 'P', 'a', 's', 't', 'e', 'd', ' ', 't', 'e', 'x', 't' };

fn pastePlaceholderMatches(block_text: []const u16, prefix: []const u16) bool {
    var buf: [BLOCK_NORM_CAP]u16 = undefined;
    const norm = normalize(block_text, &buf);
    const at = std.mem.indexOf(u16, norm, &PASTE_PLACEHOLDER) orelse return false;
    var end = at;
    while (end > 0 and norm[end - 1] == ' ') end -= 1;
    const before = norm[0..end];
    if (before.len == 0) return prefix.len >= MIN_PARTIAL;
    const n = @min(before.len, prefix.len);
    return std.mem.eql(u16, before[0..n], prefix[0..n]);
}

pub fn newBlockMatches(block_text: []const u16, prefix: []const u16) bool {
    if (prefix.len == 0) return false;
    return blockMatches(block_text, prefix) or pastePlaceholderMatches(block_text, prefix);
}

fn isTaken(taken: []const ?usize, bi: usize, earlier: []const Pending, current: Pending) bool {
    for (taken, 0..) |t, i| {
        if (t) |v| {
            if (v == bi and (current.text.len == 0 or earlier[i].text.len == 0 or sameText(current.text, earlier[i].text))) return true;
        }
    }
    return false;
}

fn pickBlock(p: Pending, blocks: []const UserBlock, window_full: bool, claimed: []const i64, taken: []const ?usize, earlier: []const Pending) ?usize {
    if (p.prefix.len == 0) return null;
    for (blocks, 0..) |b, bi| {
        if (!isNewBlock(p.anchor, b.stamp_ms, bi, window_full) and !p.unanchored_delivery) continue;
        if (p.unanchored_delivery and (p.text.len == 0 or !sameText(b.text, p.text))) continue;
        if (b.stamp_ms > 0 and std.mem.indexOfScalar(i64, claimed, b.stamp_ms) != null) continue;
        if (isTaken(taken, bi, earlier, p)) continue;
        if (messageMatches(b.text, p)) return bi;
    }
    return null;
}

pub fn assign(pending: []Pending, blocks: []const UserBlock, window_full: bool, claimed: []const i64, out: []?usize) void {
    for (out) |*o| o.* = null;
    const n = @min(pending.len, out.len);
    for (0..n) |i| {
        out[i] = pickBlock(pending[i], blocks, window_full, claimed, out[0..i], pending[0..i]);
        const bi = out[i] orelse continue;
        for (pending, 0..) |*other, j| {
            if (j <= i) continue;
            if (other.text.len > 0 and pending[i].text.len > 0 and !sameText(other.text, pending[i].text) and messageMatches(blocks[bi].text, other.*)) continue;
            if (blocks[bi].stamp_ms > 0) {
                other.anchor.after_ms = @max(other.anchor.after_ms, blocks[bi].stamp_ms);
                other.unanchored_delivery = false;
            } else if (other.anchor.user_count <= bi) {
                other.anchor.user_count = @intCast(bi + 1);
                if (other.unanchored_delivery) other.anchor.counted = true;
                other.unanchored_delivery = false;
            }
        }
    }
}

pub const Phase = enum { offline_queue, sending, delivered, not_sent };
pub const Label = enum { sending, waiting_connection, queued_in_claude, not_sent };

pub fn pendingLabel(phase: Phase, link_down: bool) Label {
    return switch (phase) {
        .sending => .sending,
        .offline_queue => if (link_down) .waiting_connection else .sending,
        .delivered => .queued_in_claude,
        .not_sent => .not_sent,
    };
}

fn w(comptime s: []const u8) [s.len]u16 {
    var out: [s.len]u16 = undefined;
    for (s, 0..) |c, i| out[i] = c;
    return out;
}

fn prefixOf(comptime s: []const u8, out: []u16) []const u16 {
    const wide = w(s);
    const full = normalize(&wide, out);
    return full[0..@min(full.len, 40)];
}

test "normalize collapses whitespace and strips pasted_content tags" {
    var out: [64]u16 = undefined;
    const input = w("  hello \n\n  <pasted_content id=\"1\">world</pasted_content>  ");
    const got = normalize(&input, &out);
    const expected = w("hello world");
    try std.testing.expectEqualSlices(u16, &expected, got);
}

test "a block that starts with the message matches" {
    var p: [64]u16 = undefined;
    const prefix = prefixOf("please fix the login bug", &p);
    const block = w("please   fix the login bug\nand then more");
    try std.testing.expect(blockMatches(&block, prefix));
}

test "a different message does not match" {
    var p: [64]u16 = undefined;
    const prefix = prefixOf("please fix the login bug", &p);
    const block = w("please fix the signup bug");
    try std.testing.expect(!blockMatches(&block, prefix));
}

test "a pasted_content wrapped copy matches" {
    var p: [64]u16 = undefined;
    const prefix = prefixOf("deploy the staging build now", &p);
    const block = w("<pasted_content>deploy the staging build\nnow</pasted_content>");
    try std.testing.expect(blockMatches(&block, prefix));
}

test "a cut-short copy of a long message matches" {
    var p: [64]u16 = undefined;
    const prefix = prefixOf("please refactor the whole settings page and add tests for it", &p);
    const dots = w("please refactor the whole...");
    try std.testing.expect(blockMatches(&dots, prefix));
    const ellipsis = w("please refactor the whole") ++ [_]u16{0x2026};
    try std.testing.expect(blockMatches(&ellipsis, prefix));
}

test "a very short cut is not enough to match" {
    var p: [64]u16 = undefined;
    const prefix = prefixOf("please refactor the whole settings page", &p);
    const block = w("please");
    try std.testing.expect(!blockMatches(&block, prefix));
}

test "a message merged into a bigger user turn matches" {
    var p: [64]u16 = undefined;
    const prefix = prefixOf("also update the changelog entry", &p);
    const block = w("run the tests first\n\nalso update the changelog entry");
    try std.testing.expect(blockMatches(&block, prefix));
}

test "a short message matches only at the end of a merged turn" {
    var p: [64]u16 = undefined;
    const prefix = prefixOf("yes", &p);
    const at_end = w("go ahead\nyes");
    const inside = w("yes please go ahead with it");
    const word_inside = w("they said no");
    try std.testing.expect(blockMatches(&at_end, prefix));
    try std.testing.expect(blockMatches(&inside, prefix));
    try std.testing.expect(!blockMatches(&word_inside, prefix));
}

test "empty prefix and empty block never match" {
    var p: [64]u16 = undefined;
    const prefix = prefixOf("hello there friend", &p);
    const empty = [_]u16{};
    try std.testing.expect(!blockMatches(&empty, prefix));
    const block = w("hello");
    try std.testing.expect(!blockMatches(&block, &empty));
}

test "IGSH-564 connected labels mirror Claude buffer without transcript evidence" {
    try std.testing.expectEqual(Label.queued_in_claude, pendingLabel(.delivered, false));
    try std.testing.expectEqual(Label.sending, pendingLabel(.offline_queue, false));
    try std.testing.expectEqual(Label.waiting_connection, pendingLabel(.offline_queue, true));
}

test "pending label is truthful" {
    try std.testing.expectEqual(Label.waiting_connection, pendingLabel(.offline_queue, true));
    try std.testing.expectEqual(Label.sending, pendingLabel(.offline_queue, false));
    try std.testing.expectEqual(Label.queued_in_claude, pendingLabel(.delivered, false));
    try std.testing.expectEqual(Label.queued_in_claude, pendingLabel(.delivered, true));
    try std.testing.expectEqual(Label.sending, pendingLabel(.sending, false));
    try std.testing.expectEqual(Label.not_sent, pendingLabel(.not_sent, false));
}

test "stampMs reads transcript times in any zone" {
    try std.testing.expectEqual(@as(i64, 0), stampMs("1970-01-01T00:00:00Z"));
    try std.testing.expectEqual(@as(i64, 1_760_170_353_456), stampMs("2025-10-11T08:12:33.456Z"));
    try std.testing.expectEqual(stampMs("2025-10-11T08:12:33Z"), stampMs("2025-10-11T10:12:33+02:00"));
    try std.testing.expectEqual(stampMs("2025-10-11T08:12:33Z"), stampMs("2025-10-11T03:12:33-05:00"));
    try std.testing.expectEqual(stampMs("2025-10-11T08:12:33.456Z"), stampMs("2025-10-11T08:12:33.456789Z"));
    try std.testing.expectEqual(@as(i64, 0), stampMs("-"));
    try std.testing.expectEqual(@as(i64, 0), stampMs("2025-13-11T08:12:33Z"));
    try std.testing.expectEqual(@as(i64, 0), stampMs("2025-10-11T08:12:33.Z"));
    try std.testing.expectEqual(@as(i64, 0), stampMs("2025-10-11T08:12:33Zjunk"));
}

test "fileTimeToUnixMs converts the Windows clock" {
    try std.testing.expectEqual(@as(i64, 0), fileTimeToUnixMs(116444736000000000));
    try std.testing.expectEqual(@as(i64, 1_000), fileTimeToUnixMs(116444736000000000 + 10_000_000));
}

fn ub(comptime s: []const u8, stamp: i64) UserBlock {
    const S = struct {
        const text = w(s);
    };
    return .{ .text = &S.text, .stamp_ms = stamp };
}

test "scenario: full window with an old identical yes never confirms a new yes" {
    var p: [64]u16 = undefined;
    const before = [_]UserBlock{ ub("yes", 1_000), ub("run the tests", 2_000) };
    var pending = [_]Pending{.{ .prefix = prefixOf("yes", &p), .anchor = .{ .after_ms = 2_000, .sent_ms = 2_500 } }};
    var out: [1]?usize = undefined;
    assign(&pending, &before, true, &.{}, &out);
    try std.testing.expect(out[0] == null);
    const after = [_]UserBlock{ ub("yes", 1_000), ub("run the tests", 2_000), ub("yes", 3_000) };
    assign(&pending, &after, true, &.{}, &out);
    try std.testing.expectEqual(@as(?usize, 2), out[0]);
}

test "scenario: a third yes confirms after two were confirmed" {
    var p: [64]u16 = undefined;
    const blocks = [_]UserBlock{ ub("yes", 1_000), ub("yes", 2_000) };
    const claimed = [_]i64{ 1_000, 2_000 };
    var pending = [_]Pending{.{ .prefix = prefixOf("yes", &p), .anchor = .{ .after_ms = 2_000, .sent_ms = 2_100 } }};
    var out: [1]?usize = undefined;
    assign(&pending, &blocks, false, &claimed, &out);
    try std.testing.expect(out[0] == null);
    const later = [_]UserBlock{ ub("yes", 1_000), ub("yes", 2_000), ub("yes", 3_000) };
    assign(&pending, &later, false, &claimed, &out);
    try std.testing.expectEqual(@as(?usize, 2), out[0]);
}

test "scenario: two pending yes with one delivered confirm only the oldest" {
    var p1: [64]u16 = undefined;
    var p2: [64]u16 = undefined;
    const blocks = [_]UserBlock{ ub("start", 500), ub("yes", 1_000) };
    var pending = [_]Pending{
        .{ .prefix = prefixOf("yes", &p1), .anchor = .{ .after_ms = 500, .sent_ms = 900 } },
        .{ .prefix = prefixOf("yes", &p2), .anchor = .{ .after_ms = 500, .sent_ms = 950 } },
    };
    var out: [2]?usize = undefined;
    assign(&pending, &blocks, false, &.{}, &out);
    try std.testing.expectEqual(@as(?usize, 1), out[0]);
    try std.testing.expect(out[1] == null);
    const claimed = [_]i64{1_000};
    assign(pending[1..], &blocks, false, &claimed, out[0..1]);
    try std.testing.expect(out[0] == null);
    const later = [_]UserBlock{ ub("start", 500), ub("yes", 1_000), ub("yes", 1_200) };
    assign(pending[1..], &later, false, &claimed, out[0..1]);
    try std.testing.expectEqual(@as(?usize, 2), out[0]);
}

test "scenario: an anchor scrolled out of the window never loosens matching" {
    var p: [64]u16 = undefined;
    var q: [64]u16 = undefined;
    const blocks = [_]UserBlock{ ub("please continue with the refactor", 600), ub("yes", 700) };
    var pending = [_]Pending{
        .{ .prefix = prefixOf("continue", &p), .anchor = .{ .after_ms = 650, .sent_ms = 660 } },
        .{ .prefix = prefixOf("yes", &q), .anchor = .{ .after_ms = 500, .sent_ms = 510 } },
    };
    var out: [2]?usize = undefined;
    assign(&pending, &blocks, true, &.{}, &out);
    try std.testing.expect(out[0] == null);
    try std.testing.expectEqual(@as(?usize, 1), out[1]);
}

test "scenario: wrapped, merged and pasted copies confirm" {
    var p1: [64]u16 = undefined;
    var p2: [64]u16 = undefined;
    var p3: [64]u16 = undefined;
    const blocks = [_]UserBlock{
        ub("<pasted_content>deploy the staging\nbuild now</pasted_content>", 1_000),
        ub("[Pasted text #1 +40 lines]", 1_100),
        ub("look at this [Pasted text #2 +12 lines]", 1_200),
    };
    var pending = [_]Pending{
        .{ .prefix = prefixOf("deploy the staging build now", &p1), .anchor = .{ .after_ms = 900 } },
        .{ .prefix = prefixOf("a long pasted log from the server", &p2), .anchor = .{ .after_ms = 900 } },
        .{ .prefix = prefixOf("look at this\nline one of the paste", &p3), .anchor = .{ .after_ms = 900 } },
    };
    var out: [3]?usize = undefined;
    assign(&pending, &blocks, false, &.{}, &out);
    try std.testing.expectEqual(@as(?usize, 0), out[0]);
    try std.testing.expectEqual(@as(?usize, 1), out[1]);
    try std.testing.expectEqual(@as(?usize, 2), out[2]);
    var p4: [64]u16 = undefined;
    var short = [_]Pending{.{ .prefix = prefixOf("ok", &p4), .anchor = .{ .after_ms = 900 } }};
    assign(&short, blocks[1..2], false, &.{}, out[0..1]);
    try std.testing.expect(out[0] == null);
}

test "scenario: a message queued by Claude and merged into a later turn confirms" {
    var p1: [64]u16 = undefined;
    var p2: [64]u16 = undefined;
    const blocks = [_]UserBlock{
        ub("run the tests first\n\nalso update the changelog entry", 100),
        ub("run the tests first\n\nalso update the changelog entry", 400),
        ub("go ahead\nyes", 500),
    };
    var pending = [_]Pending{
        .{ .prefix = prefixOf("also update the changelog entry", &p1), .anchor = .{ .after_ms = 300, .sent_ms = 310 } },
        .{ .prefix = prefixOf("yes", &p2), .anchor = .{ .after_ms = 300, .sent_ms = 320 } },
    };
    var out: [2]?usize = undefined;
    assign(&pending, &blocks, true, &.{}, &out);
    try std.testing.expectEqual(@as(?usize, 1), out[0]);
    try std.testing.expectEqual(@as(?usize, 2), out[1]);
}

test "no anchor time: the laptop send time decides, with skew" {
    const a = Anchor{ .sent_ms = 100_000 };
    try std.testing.expect(isNewBlock(a, 100_000 - SEND_SKEW_MS, 0, true));
    try std.testing.expect(!isNewBlock(a, 100_000 - SEND_SKEW_MS - 1, 0, true));
    try std.testing.expect(!isNewBlock(.{}, 5_000, 0, false));
}

test "entries without a time: counted only in a growing list, one bubble each" {
    var p1: [64]u16 = undefined;
    var p2: [64]u16 = undefined;
    const blocks = [_]UserBlock{ ub("yes", 0), ub("yes", 0) };
    var pending = [_]Pending{
        .{ .prefix = prefixOf("yes", &p1), .anchor = .{ .user_count = 1, .counted = true } },
        .{ .prefix = prefixOf("yes", &p2), .anchor = .{ .user_count = 1, .counted = true } },
    };
    var out: [2]?usize = undefined;
    assign(&pending, &blocks, true, &.{}, &out);
    try std.testing.expect(out[0] == null and out[1] == null);
    assign(&pending, &blocks, false, &.{}, &out);
    try std.testing.expectEqual(@as(?usize, 1), out[0]);
    try std.testing.expect(out[1] == null);
    try std.testing.expectEqual(@as(u32, 2), pending[1].anchor.user_count);
    assign(pending[1..], &blocks, false, &.{}, out[0..1]);
    try std.testing.expect(out[0] == null);
    var p3: [64]u16 = undefined;
    var uncounted = [_]Pending{.{ .prefix = prefixOf("yes", &p3), .anchor = .{} }};
    assign(&uncounted, &blocks, false, &.{}, out[0..1]);
    try std.testing.expect(out[0] == null);
}

test "delivery: normalized full text includes link text, unicode and trailing whitespace" {
    const a = std.unicode.utf8ToUtf16LeStringLiteral(" \tlook at\nhttps://screencast2.com/a.png 中文 😀 ");
    const b = std.unicode.utf8ToUtf16LeStringLiteral("look at https://screencast2.com/a.png 中文 😀");
    try std.testing.expect(sameText(a, b));
    try std.testing.expect(!sameText(a, std.unicode.utf8ToUtf16LeStringLiteral("look at https://screencast2.com/b.png 中文 😀")));
    var long_a = [_]u16{'a'} ** 4000;
    var long_b = long_a;
    long_b[3999] = 'b';
    try std.testing.expect(!sameText(&long_a, &long_b));
    var pending = [_]Pending{.{ .prefix = long_a[0..40], .text = &long_a, .anchor = .{ .after_ms = 100 } }};
    var out: [1]?usize = undefined;
    assign(&pending, &.{.{ .text = &long_b, .stamp_ms = 200 }}, false, &.{}, &out);
    try std.testing.expect(out[0] == null);
}

test "ISSUE-608 a message with leftover box text glued in front still confirms" {
    const text = w("so i hear there were also vulnerabilityes in the node js");
    var prefix: [64]u16 = undefined;
    var pending = [_]Pending{.{ .prefix = prefixOf("so i hear there were also vulnerabilityes in the node js", &prefix), .text = &text, .anchor = .{ .after_ms = 100 } }};
    var out: [1]?usize = undefined;
    assign(&pending, &.{ub("so i hear there were craso i hear there were also vulnerabilityes in the node js", 200)}, false, &.{}, &out);
    try std.testing.expectEqual(@as(?usize, 0), out[0]);
    assign(&pending, &.{ub("so i hear there were craso i hear there were also vulnerabilityes in the node js and more", 200)}, false, &.{}, &out);
    try std.testing.expect(out[0] == null);
    const short = w("yes");
    try std.testing.expect(short.len < MIN_PARTIAL);
    try std.testing.expect(!messageMatches(&w("leftoveryes"), .{ .prefix = &short, .text = &short, .anchor = .{ .after_ms = 100 } }));
}

test "delivery: busy then idle and restart reserve one text write" {
    try std.testing.expect(!mayType(.queued, false, true, false));
    try std.testing.expect(!mayType(.queued, false, false, true));
    try std.testing.expect(mayType(stateOnLoad(0, false), false, false, false));
    try std.testing.expect(mayType(.queued, false, false, false));
    for (std.enums.values(OutboxState)) |state| {
        try std.testing.expect(!mayType(state, true, false, false));
        try std.testing.expect(!mayType(stateOnLoad(@intFromEnum(state), true), true, false, false));
    }
}

test "delivery: intentional repeated text needs two entries even after confirmation claims are lost on restart" {
    const yes = w("yes");
    var pending = [_]Pending{
        .{ .prefix = &yes, .text = &yes, .anchor = .{ .after_ms = 100 } },
        .{ .prefix = &yes, .text = &yes, .anchor = .{ .after_ms = 100 } },
    };
    var out: [2]?usize = undefined;
    assign(&pending, &.{ub("yes", 200)}, false, &.{}, &out);
    try std.testing.expectEqual(@as(?usize, 0), out[0]);
    try std.testing.expect(out[1] == null);
    assign(pending[1..], &.{ub("yes", 200)}, false, &.{}, out[0..1]);
    try std.testing.expect(out[0] == null);
    assign(pending[1..], &.{ ub("yes", 200), ub(" yes  ", 300) }, false, &.{}, out[0..1]);
    try std.testing.expectEqual(@as(?usize, 1), out[0]);
}

test "delivery: legacy typed entries without anchors reconcile exact normalized text only" {
    const text = w(" https://screencast2.com/a.png ");
    var pending = [_]Pending{.{ .prefix = &text, .text = &text, .anchor = .{}, .unanchored_delivery = true }};
    var out: [1]?usize = undefined;
    assign(&pending, &.{ub("https://screencast2.com/b.png", 200)}, false, &.{}, &out);
    try std.testing.expect(out[0] == null);
    assign(&pending, &.{ub("https://screencast2.com/a.png", 200)}, false, &.{}, &out);
    try std.testing.expectEqual(@as(?usize, 0), out[0]);
    pending[0].unanchored_delivery = false;
    assign(&pending, &.{ub("https://screencast2.com/a.png", 200)}, false, &.{}, &out);
    try std.testing.expect(out[0] == null);
}

test "retirement: full transcript text ignores late anchors and claimed copies" {
    const text = std.unicode.utf8ToUtf16LeStringLiteral("https://screencast2.com/a.png");
    const blocks = [_]UserBlock{
        .{ .text = std.unicode.utf8ToUtf16LeStringLiteral("https://screencast2.com/b.png"), .stamp_ms = 100 },
        .{ .text = std.unicode.utf8ToUtf16LeStringLiteral(" https://screencast2.com/a.png \n"), .stamp_ms = 200 },
    };
    try std.testing.expectEqual(@as(?usize, 1), represented(text, &blocks));
    try std.testing.expectEqual(@as(?usize, 1), represented(text, &blocks));
    try std.testing.expectEqual(@as(?usize, null), represented(text, blocks[0..1]));
    try std.testing.expectEqual(@as(?usize, null), represented(&.{}, &blocks));
}

test "retirement: delivered messages have a hard ten minute bound even without transcript access" {
    try std.testing.expect(!expiredSent(.delivered, 1000, 600999));
    try std.testing.expect(expiredSent(.delivered, 1000, 601000));
    try std.testing.expect(!expiredSent(.delivered, 0, 601000));
    try std.testing.expect(!expiredSent(.delivered, 1000, 999));
    for ([_]OutboxState{ .queued, .sending, .not_sent }) |state| {
        try std.testing.expect(!expiredSent(state, 1000, 601000));
    }
}

test "settlement: refusal matches only a complete leading slash command" {
    try std.testing.expect(refusesCommand(&w("Unknown command: /hormozi-skills:audit-offer"), &w(" /hormozi-skills:audit-offer review my offer")));
    try std.testing.expect(refusesCommand(&w("Unknown command: /adivsor. Did you mean /advisor?"), &w("/adivsor fab le")));
    try std.testing.expect(!refusesCommand(&w("Args from unknown skill: review my offer"), &w("/unknown review my offer")));
    try std.testing.expect(!refusesCommand(&w("Unknown command: /audit-other"), &w("/audit x")));
    try std.testing.expect(!refusesCommand(&w("Unknown command: /audit.other"), &w("/audit x")));
    try std.testing.expect(!refusesCommand(&w("Unknown command: /audit"), &w("mention /audit")));
    try std.testing.expect(!refusesCommand(&w("Args from unknown skill: different args"), &w("/unknown review my offer")));
    try std.testing.expect(!refusesCommand(&w("Compacted while idle"), &w("/audit x")));
}

test "settlement: turn completion and queue removal allow twenty seconds and require a fresh load" {
    var watch = DeliveryWatch{};
    watch.observe(false, 1000);
    try std.testing.expect(!watch.due(100000, 100000));
    watch.observe(true, 2000);
    watch.observe(false, 3000);
    try std.testing.expect(!watch.due(22999, 23000));
    try std.testing.expect(!watch.due(23000, 22999));
    try std.testing.expect(watch.due(23000, 23000));
    watch = .{};
    watch.evidence(.{ .removed_ms = 1200 }, 3000);
    watch.evidence(.{ .removed_ms = 1200 }, 4000);
    try std.testing.expect(watch.due(23000, 23000));
    watch.evidence(.{}, 24000);
    try std.testing.expect(!watch.due(25000, 25000));
}

test "settlement: two different messages merged into one turn both match but repeated intent does not" {
    const first_text = w("please review the offer");
    const second_text = w("also review the pricing");
    var pending = [_]Pending{
        .{ .text = &first_text, .prefix = &first_text, .anchor = .{ .after_ms = 100 } },
        .{ .text = &second_text, .prefix = &second_text, .anchor = .{ .after_ms = 100 } },
        .{ .text = &first_text, .prefix = &first_text, .anchor = .{ .after_ms = 100 } },
    };
    var assigned: [3]?usize = undefined;
    assign(&pending, &.{ub("please review the offer\n\nalso review the pricing", 200)}, false, &.{}, &assigned);
    try std.testing.expectEqual(@as(?usize, 0), assigned[0]);
    try std.testing.expectEqual(@as(?usize, 0), assigned[1]);
    try std.testing.expectEqual(@as(?usize, null), assigned[2]);
}

test "ISSUE-349 orphaned sending settles without changing the active verification" {
    try std.testing.expect(orphanedSending(.sending, 1, 2));
    try std.testing.expect(orphanedSending(.sending, 1, 0));
    try std.testing.expect(!orphanedSending(.sending, 1, 1));
    for ([_]OutboxState{ .queued, .delivered, .not_sent }) |state| {
        try std.testing.expect(!orphanedSending(state, 1, 0));
    }
}

test "ISSUE-349 tagged pending matches the cleaned rendered user block" {
    const text = w("<pasted_content id=\"5ebf\">\nplease check the build\n</pasted_content id=\"5ebf\">");
    var normalized: [256]u16 = undefined;
    var pending = [_]Pending{.{ .text = &text, .prefix = normalize(&text, &normalized), .anchor = .{ .after_ms = 100 } }};
    var picked: [1]?usize = undefined;
    assign(&pending, &.{ub("please check the build", 200)}, false, &.{}, &picked);
    try std.testing.expectEqual(@as(?usize, 0), picked[0]);
}

pub const TranscriptEvidence = enum { none, enqueued, delivered };
pub const TranscriptDecision = enum { wait, queued, delivered, unconfirmed };

pub fn transcriptStatus(watch: *DeliveryWatch, busy: bool, now_ms: i64, loaded_ms: i64, evidence: TranscriptEvidence) TranscriptDecision {
    watch.observe(busy, now_ms);
    if (!busy and watch.idle_since_ms == 0) watch.idle_since_ms = now_ms;
    return switch (evidence) {
        .delivered => .delivered,
        .enqueued => .queued,
        .none => if (!busy and watch.due(now_ms, loaded_ms)) .unconfirmed else .wait,
    };
}

test "IGSH-442 unconfirmed written entries offer Send again and Remove" {
    const state = stateOnLoad(@intFromEnum(OutboxState.not_sent), true);
    const actions = pendingActions(state);
    try std.testing.expect(actions.send_again);
    try std.testing.expect(actions.remove);
    try std.testing.expect(pendingActions(.not_sent).send_again);
    for ([_]OutboxState{ .queued, .sending, .delivered }) |other| {
        try std.testing.expect(!pendingActions(other).send_again);
        try std.testing.expect(!pendingActions(other).remove);
    }
}

test "IGSH-442 resend prioritizes transcript and queued evidence over terminal input" {
    for ([_]?bool{ null, false, true }) |held| {
        try std.testing.expectEqual(ResendDecision.mark_delivered, resendDecision(true, .{}, held));
        try std.testing.expectEqual(ResendDecision.mark_delivered, resendDecision(false, .{ .enqueued = true }, held));
    }
}

test "IGSH-442 resend presses only Enter for held text and otherwise writes again" {
    try std.testing.expectEqual(ResendDecision.press_enter_only, resendDecision(false, .{}, true));
    try std.testing.expectEqual(ResendDecision.write_again, resendDecision(false, .{}, false));
    try std.testing.expectEqual(ResendDecision.write_again, resendDecision(false, .{}, null));
}

test "IGSH-442 busy verification waits for delivery watch expiry before not sent" {
    for ([_]?bool{ null, false }) |held| {
        try std.testing.expectEqual(OutboxState.delivered, verifyExpiredState(true, held));
        var watch = DeliveryWatch{};
        watch.observe(true, 1000);
        watch.observe(true, 100_000);
        try std.testing.expect(!watch.due(100_000, 100_000));
        watch.observe(false, 100_001);
        try std.testing.expect(!watch.due(100_001 + SETTLE_GRACE_MS - 1, 200_000));
        try std.testing.expect(watch.due(100_001 + SETTLE_GRACE_MS, 200_000));
    }
    try std.testing.expectEqual(OutboxState.not_sent, verifyExpiredState(true, true));
    try std.testing.expectEqual(OutboxState.not_sent, verifyExpiredState(false, null));
}

test "IGSH-442 busy with no transcript past both timeout budgets never retransmits" {
    var watch = DeliveryWatch{};
    for ([_]i64{ 2000, 11_999, 12_000, 22_000, 600_000 }) |now_ms| {
        try std.testing.expectEqual(TranscriptDecision.wait, transcriptStatus(&watch, true, now_ms, now_ms, .none));
        try std.testing.expect(watch.busy_seen);
        try std.testing.expectEqual(@as(i64, 0), watch.idle_since_ms);
    }
    watch.evidence(.{ .removed_ms = 1000 }, 2000);
    try std.testing.expectEqual(TranscriptDecision.wait, transcriptStatus(&watch, true, 700_000, 700_000, .none));
}

test "IGSH-442 positive transcript evidence confirms even while busy after timeouts" {
    var watch = DeliveryWatch{};
    try std.testing.expectEqual(TranscriptDecision.wait, transcriptStatus(&watch, true, 2000, 0, .none));
    try std.testing.expectEqual(TranscriptDecision.wait, transcriptStatus(&watch, true, 600_000, 600_000, .none));
    try std.testing.expectEqual(TranscriptDecision.queued, transcriptStatus(&watch, true, 600_001, 600_001, .enqueued));
    try std.testing.expectEqual(TranscriptDecision.delivered, transcriptStatus(&watch, true, 600_002, 600_002, .delivered));
}

test "IGSH-442 idle plus fresh transcript grace can fail without retransmission" {
    for ([_]bool{ false, true }) |was_busy| {
        var watch = DeliveryWatch{};
        if (was_busy) _ = transcriptStatus(&watch, true, 2000, 2000, .none);
        try std.testing.expectEqual(TranscriptDecision.wait, transcriptStatus(&watch, false, 600_000, 600_000, .none));
        try std.testing.expectEqual(TranscriptDecision.wait, transcriptStatus(&watch, false, 619_999, 620_000, .none));
        try std.testing.expectEqual(TranscriptDecision.wait, transcriptStatus(&watch, false, 620_000, 619_999, .none));
        try std.testing.expectEqual(TranscriptDecision.delivered, transcriptStatus(&watch, false, 620_000, 620_000, .delivered));
        try std.testing.expectEqual(TranscriptDecision.unconfirmed, transcriptStatus(&watch, false, 620_000, 620_000, .none));
        try std.testing.expectEqual(TranscriptDecision.wait, transcriptStatus(&watch, true, 620_001, 620_001, .none));
        try std.testing.expectEqual(TranscriptDecision.wait, transcriptStatus(&watch, false, 620_002, 620_002, .none));
    }
}

test "ISSUE-460 all pending states have a hard deadline independent of busy and transcript evidence" {
    for ([_]OutboxState{ .queued, .sending, .delivered }) |state| {
        try std.testing.expect(!pendingExpired(state, 1000, 600999));
        try std.testing.expect(pendingExpired(state, 1000, 601000));
        try std.testing.expect(!pendingExpired(state, 1000, 999));
        try std.testing.expect(pendingExpired(state, -600000, 0));
    }
    try std.testing.expect(!pendingExpired(.not_sent, 1000, 901000));
    try std.testing.expectEqual(@as(u8, 2), @intFromEnum(OutboxState.not_sent));
}
