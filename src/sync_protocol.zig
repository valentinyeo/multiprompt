const std = @import("std");
const Allocator = std.mem.Allocator;
const Gcm = std.crypto.aead.aes_gcm.Aes256Gcm;
const b64 = std.base64.standard;

const fixtures = @embedFile("sync_fixtures/sync-protocol-v1-fixtures.json");

pub const Kdf = struct {
    memory_kib: u32 = 65536,
    iterations: u32 = 3,
    parallelism: u24 = 1,
    version: u32 = 19,
    salt: [16]u8,
};
pub const Record = struct { id: []const u8, iv: [12]u8, body: []const u8 };
pub const Metadata = struct {
    record_id: []const u8,
    entity_id: []const u8,
    account_id: []const u8,
    revision: i64,
    schema_version: u32 = 1,
};

fn string(obj: std.json.Value, key: []const u8) ![]const u8 {
    if (obj != .object) return error.Malformed;
    const v = obj.object.get(key) orelse return error.Malformed;
    if (v != .string) return error.Malformed;
    return v.string;
}
fn field(obj: std.json.Value, key: []const u8) !std.json.Value {
    if (obj != .object) return error.Malformed;
    return obj.object.get(key) orelse error.Malformed;
}
fn integer(obj: std.json.Value, key: []const u8) !i64 {
    const v = try field(obj, key);
    if (v != .integer) return error.Malformed;
    return v.integer;
}
fn enc(a: Allocator, bytes: []const u8) ![]u8 {
    const result = try a.alloc(u8, b64.Encoder.calcSize(bytes.len));
    return @constCast(b64.Encoder.encode(result, bytes));
}
fn dec(a: Allocator, text: []const u8) ![]u8 {
    const decoder = if (std.mem.endsWith(u8, text, "=")) b64.Decoder else std.base64.standard_no_pad.Decoder;
    const n = decoder.calcSizeForSlice(text) catch return error.Malformed;
    const result = try a.alloc(u8, n);
    errdefer a.free(result);
    decoder.decode(result, text) catch return error.Malformed;
    return result;
}
fn fixed(comptime n: usize, a: Allocator, text: []const u8) ![n]u8 {
    const bytes = try dec(a, text);
    defer a.free(bytes);
    if (bytes.len != n) return error.Malformed;
    return bytes[0..n].*;
}
fn kdfJson(a: Allocator, k: Kdf) ![]u8 {
    const salt = try enc(a, &k.salt);
    defer a.free(salt);
    return std.fmt.allocPrint(a, "{{\"alg\":\"argon2id\",\"version\":{d},\"memoryKiB\":{d},\"iterations\":{d},\"parallelism\":{d},\"salt\":\"{s}\"}}", .{ k.version, k.memory_kib, k.iterations, k.parallelism, salt });
}
fn parseKdf(a: Allocator, value: std.json.Value) !Kdf {
    if (!std.mem.eql(u8, try string(value, "alg"), "argon2id")) return error.Malformed;
    if (try integer(value, "version") != 19) return error.UnsupportedVersion;
    const m = try integer(value, "memoryKiB");
    const t = try integer(value, "iterations");
    const p = try integer(value, "parallelism");
    if (m < 8 or m > std.math.maxInt(i32) or t < 1 or t > std.math.maxInt(i32) or p < 1 or p > std.math.maxInt(u24)) return error.Malformed;
    return .{ .memory_kib = @intCast(m), .iterations = @intCast(t), .parallelism = @intCast(p), .salt = try fixed(16, a, try string(value, "salt")) };
}
pub fn deriveKek(a: Allocator, passphrase: []const u8, k: Kdf) ![32]u8 {
    if (k.version != 19) return error.UnsupportedVersion;
    var io = std.Io.Threaded.init(a, .{});
    defer io.deinit();
    var result: [32]u8 = undefined;
    try std.crypto.pwhash.argon2.kdf(a, &result, passphrase, &k.salt, .{ .m = k.memory_kib, .t = k.iterations, .p = k.parallelism }, .argon2id, io.io());
    return result;
}
fn sealBytes(a: Allocator, key: [32]u8, iv: [12]u8, body: []const u8, aad: []const u8) ![]u8 {
    const ct = try a.alloc(u8, body.len + 16);
    Gcm.encrypt(ct[0..body.len], ct[body.len..][0..16], body, aad, iv, key);
    return ct;
}
fn openBytes(a: Allocator, key: [32]u8, iv: [12]u8, ct: []const u8, aad: []const u8) ![]u8 {
    if (ct.len < 16) return error.Malformed;
    const body = try a.alloc(u8, ct.len - 16);
    errdefer a.free(body);
    Gcm.decrypt(body, ct[0 .. ct.len - 16], ct[ct.len - 16 ..][0..16].*, aad, iv, key) catch return error.AuthenticationFailed;
    return body;
}
pub fn wrap(a: Allocator, kek: [32]u8, k: Kdf, vault_key: [32]u8, iv: [12]u8) ![]u8 {
    const canonical = try kdfJson(a, k);
    defer a.free(canonical);
    const aad = try std.fmt.allocPrint(a, "mp-sync-v1/wrap/{s}", .{canonical});
    defer a.free(aad);
    return sealBytes(a, kek, iv, &vault_key, aad);
}
pub fn unwrap(a: Allocator, kek: [32]u8, k: Kdf, ct: []const u8, iv: [12]u8) ![32]u8 {
    if (ct.len != 48) return error.Malformed;
    const canonical = try kdfJson(a, k);
    defer a.free(canonical);
    const aad = try std.fmt.allocPrint(a, "mp-sync-v1/wrap/{s}", .{canonical});
    defer a.free(aad);
    const plain = openBytes(a, kek, iv, ct, aad) catch |err| return if (err == error.AuthenticationFailed) error.WrongPassphrase else err;
    defer {
        std.crypto.secureZero(u8, plain);
        a.free(plain);
    }
    return plain[0..32].*;
}
fn recordId(id: []const u8) bool {
    if (id.len == 0 or id[0] < 'a' or id[0] > 'z') return false;
    for (id[1..]) |c| if (!std.ascii.isAlphanumeric(c)) return false;
    return true;
}
pub fn sealRecord(a: Allocator, key: [32]u8, record_id: []const u8, body: []const u8, iv: [12]u8) ![]u8 {
    if (!recordId(record_id)) return error.Malformed;
    const aad = try std.fmt.allocPrint(a, "mp-sync-v1/record/{s}", .{record_id});
    defer a.free(aad);
    return sealBytes(a, key, iv, body, aad);
}
pub fn openRecord(a: Allocator, key: [32]u8, record_id: []const u8, ct: []const u8, iv: [12]u8) ![]u8 {
    const aad = try std.fmt.allocPrint(a, "mp-sync-v1/record/{s}", .{record_id});
    defer a.free(aad);
    return openBytes(a, key, iv, ct, aad) catch |err| return if (err == error.AuthenticationFailed) error.Tampered else err;
}
fn entityAad(a: Allocator, m: Metadata) ![]u8 {
    if (!recordId(m.record_id) or m.entity_id.len == 0 or !std.ascii.isAlphanumeric(m.entity_id[0]) or m.account_id.len == 0 or m.revision < 0) return error.Malformed;
    for (m.entity_id[1..]) |c| if (!std.ascii.isAlphanumeric(c) and std.mem.indexOfScalar(u8, "._%*-", c) == null) return error.Malformed;
    return std.fmt.allocPrint(a, "mp-sync-v1/entity/{s}/{s}/{s}/{d}/{d}", .{ m.record_id, m.entity_id, m.account_id, m.revision, m.schema_version });
}
pub fn sealEntity(a: Allocator, key: [32]u8, m: Metadata, body: []const u8, iv: [12]u8) ![]u8 {
    const aad = try entityAad(a, m);
    defer a.free(aad);
    const ct = try sealBytes(a, key, iv, body, aad);
    defer a.free(ct);
    const iv64 = try enc(a, &iv);
    defer a.free(iv64);
    const ct64 = try enc(a, ct);
    defer a.free(ct64);
    return std.fmt.allocPrint(a, "{{\"v\":1,\"recordId\":\"{s}\",\"entityId\":\"{s}\",\"iv\":\"{s}\",\"ct\":\"{s}\"}}", .{ m.record_id, m.entity_id, iv64, ct64 });
}
pub fn openEntity(a: Allocator, key: [32]u8, m: Metadata, payload: []const u8) ![]u8 {
    const aad = try entityAad(a, m);
    defer a.free(aad);
    const json = std.json.parseFromSlice(std.json.Value, a, payload, .{}) catch return error.Malformed;
    defer json.deinit();
    if (try integer(json.value, "v") != 1) return error.UnsupportedVersion;
    if (!std.mem.eql(u8, try string(json.value, "recordId"), m.record_id) or !std.mem.eql(u8, try string(json.value, "entityId"), m.entity_id)) return error.Malformed;
    const iv = try fixed(12, a, try string(json.value, "iv"));
    const ct = try dec(a, try string(json.value, "ct"));
    defer a.free(ct);
    return openBytes(a, key, iv, ct, aad) catch |err| return if (err == error.AuthenticationFailed) error.Tampered else err;
}
fn lessRecord(_: void, left: Record, right: Record) bool {
    return std.mem.lessThan(u8, left.id, right.id);
}
fn appendRecords(out: *std.ArrayList(u8), a: Allocator, key: [32]u8, records: []const Record) !void {
    const sorted = try a.dupe(Record, records);
    defer a.free(sorted);
    std.mem.sort(Record, sorted, {}, lessRecord);
    for (sorted, 0..) |rec, index| {
        if (index > 0 and std.mem.eql(u8, rec.id, sorted[index - 1].id)) return error.Malformed;
        const ct = try sealRecord(a, key, rec.id, rec.body, rec.iv);
        defer a.free(ct);
        const iv64 = try enc(a, &rec.iv);
        defer a.free(iv64);
        const ct64 = try enc(a, ct);
        defer a.free(ct64);
        const entry = try std.fmt.allocPrint(a, "{s}\"{s}\":{{\"iv\":\"{s}\",\"ct\":\"{s}\"}}", .{ if (index == 0) "" else ",", rec.id, iv64, ct64 });
        defer a.free(entry);
        try out.appendSlice(a, entry);
    }
}
pub fn sealEnvelope(a: Allocator, passphrase: []const u8, k: Kdf, key: [32]u8, wrap_iv: [12]u8, records: []const Record) ![]u8 {
    if (records.len == 0) return error.Malformed;
    var kek = try deriveKek(a, passphrase, k);
    defer std.crypto.secureZero(u8, &kek);
    const wrapped = try wrap(a, kek, k, key, wrap_iv);
    defer a.free(wrapped);
    const kj = try kdfJson(a, k);
    defer a.free(kj);
    const wi = try enc(a, &wrap_iv);
    defer a.free(wi);
    const wc = try enc(a, wrapped);
    defer a.free(wc);
    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(a);
    const header = try std.fmt.allocPrint(a, "{{\"v\":1,\"kdf\":{s},\"wrap\":{{\"alg\":\"AES-256-GCM\",\"iv\":\"{s}\",\"ct\":\"{s}\"}},\"records\":{{", .{ kj, wi, wc });
    defer a.free(header);
    try out.appendSlice(a, header);
    try appendRecords(&out, a, key, records);
    try out.appendSlice(a, "}}");
    return out.toOwnedSlice(a);
}
pub fn sealNew(a: Allocator, passphrase: []const u8, records: []const struct { id: []const u8, body: []const u8 }) !struct { envelope: []u8, vault_key: [32]u8 } {
    var io = std.Io.Threaded.init(a, .{});
    defer io.deinit();
    var k: Kdf = .{ .salt = undefined };
    try io.io().randomSecure(&k.salt);
    var key: [32]u8 = undefined;
    try io.io().randomSecure(&key);
    errdefer std.crypto.secureZero(u8, &key);
    var wrap_iv: [12]u8 = undefined;
    try io.io().randomSecure(&wrap_iv);
    const items = try a.alloc(Record, records.len);
    defer a.free(items);
    for (records, items) |record, *item| {
        item.* = .{ .id = record.id, .body = record.body, .iv = undefined };
        try io.io().randomSecure(&item.iv);
    }
    return .{ .envelope = try sealEnvelope(a, passphrase, k, key, wrap_iv, items), .vault_key = key };
}

fn decryptRecordsObject(a: Allocator, key: [32]u8, records: std.json.Value) !std.ArrayList(Record) {
    if (records != .object) return error.Malformed;
    var result: std.ArrayList(Record) = .empty;
    errdefer {
        for (result.items) |rec| {
            a.free(rec.id);
            a.free(rec.body);
        }
        result.deinit(a);
    }
    var iter = records.object.iterator();
    while (iter.next()) |entry| {
        const id = entry.key_ptr.*;
        if (!recordId(id)) return error.Malformed;
        const ri = try fixed(12, a, try string(entry.value_ptr.*, "iv"));
        const rc = try dec(a, try string(entry.value_ptr.*, "ct"));
        defer a.free(rc);
        const body = try openRecord(a, key, id, rc, ri);
        errdefer a.free(body);
        try result.append(a, .{ .id = try a.dupe(u8, id), .iv = ri, .body = body });
    }
    return result;
}
pub fn openEnvelope(a: Allocator, passphrase: []const u8, envelope: []const u8) ![]Record {
    const json = std.json.parseFromSlice(std.json.Value, a, envelope, .{}) catch return error.Malformed;
    defer json.deinit();
    if (try integer(json.value, "v") != 1) return error.UnsupportedVersion;
    const k = try parseKdf(a, try field(json.value, "kdf"));
    const w = try field(json.value, "wrap");
    if (!std.mem.eql(u8, try string(w, "alg"), "AES-256-GCM")) return error.Malformed;
    const iv = try fixed(12, a, try string(w, "iv"));
    const ct = try dec(a, try string(w, "ct"));
    defer a.free(ct);
    var kek = try deriveKek(a, passphrase, k);
    defer std.crypto.secureZero(u8, &kek);
    var key = try unwrap(a, kek, k, ct, iv);
    defer std.crypto.secureZero(u8, &key);
    var result = try decryptRecordsObject(a, key, try field(json.value, "records"));
    return result.toOwnedSlice(a);
}

pub fn openEnvelopeVaultKey(a: Allocator, passphrase: []const u8, envelope: []const u8) ![32]u8 {
    const json = std.json.parseFromSlice(std.json.Value, a, envelope, .{}) catch return error.Malformed;
    defer json.deinit();
    if (try integer(json.value, "v") != 1) return error.UnsupportedVersion;
    const k = try parseKdf(a, try field(json.value, "kdf"));
    const w = try field(json.value, "wrap");
    if (!std.mem.eql(u8, try string(w, "alg"), "AES-256-GCM")) return error.Malformed;
    const iv = try fixed(12, a, try string(w, "iv"));
    const ct = try dec(a, try string(w, "ct"));
    defer a.free(ct);
    var kek = try deriveKek(a, passphrase, k);
    defer std.crypto.secureZero(u8, &kek);
    return unwrap(a, kek, k, ct, iv);
}

pub const RECOVERY_INFO = "multiprompt-sync-v1 recovery";
const crockford_alphabet = "0123456789ABCDEFGHJKMNPQRSTVWXYZ";

fn crockfordIndex(c: u8) ?u5 {
    for (crockford_alphabet, 0..) |sym, i| {
        if (sym == c) return @intCast(i);
    }
    return null;
}

fn encodeRecoveryPayload(key: [32]u8, out: *[52]u8) void {
    var buffer: u64 = 0;
    var bits: u6 = 0;
    var oi: usize = 0;
    for (key) |b| {
        buffer = (buffer << 8) | b;
        bits += 8;
        while (bits >= 5) {
            bits -= 5;
            out[oi] = crockford_alphabet[@intCast((buffer >> bits) & 0x1F)];
            oi += 1;
        }
        buffer &= (@as(u64, 1) << bits) - 1;
    }
    if (bits > 0) {
        out[oi] = crockford_alphabet[@intCast((buffer << @intCast(5 - bits)) & 0x1F)];
        oi += 1;
    }
}
fn decodeRecoveryPayload(symbols: []const u8) ![32]u8 {
    if (symbols.len != 52) return error.Malformed;
    var buffer: u64 = 0;
    var bits: u6 = 0;
    var out: [32]u8 = undefined;
    var oi: usize = 0;
    for (symbols, 0..) |c, i| {
        const v = crockfordIndex(c) orelse return error.Malformed;
        if (i == symbols.len - 1 and (v & 1) != 0) return error.BadRecoveryKeyFormat;
        buffer = (buffer << 5) | v;
        bits += 5;
        if (bits >= 8) {
            bits -= 8;
            out[oi] = @intCast((buffer >> bits) & 0xFF);
            oi += 1;
            buffer &= (@as(u64, 1) << bits) - 1;
        }
    }
    return out;
}
fn encodeRecoveryChecksum(key: [32]u8, out: *[4]u8) void {
    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(&key, &digest, .{});
    const value: u32 = (@as(u32, digest[0]) << 12) | (@as(u32, digest[1]) << 4);
    out[0] = crockford_alphabet[@intCast((value >> 15) & 0x1F)];
    out[1] = crockford_alphabet[@intCast((value >> 10) & 0x1F)];
    out[2] = crockford_alphabet[@intCast((value >> 5) & 0x1F)];
    out[3] = crockford_alphabet[@intCast(value & 0x1F)];
}
pub fn encodeRecoveryKey(key: [32]u8) [69]u8 {
    var symbols: [56]u8 = undefined;
    encodeRecoveryPayload(key, symbols[0..52]);
    encodeRecoveryChecksum(key, symbols[52..56]);
    var out: [69]u8 = undefined;
    var oi: usize = 0;
    for (symbols, 0..) |c, i| {
        if (i != 0 and i % 4 == 0) {
            out[oi] = '-';
            oi += 1;
        }
        out[oi] = c;
        oi += 1;
    }
    return out;
}
pub fn decodeRecoveryKey(text: []const u8) ![32]u8 {
    var symbols: [56]u8 = undefined;
    var n: usize = 0;
    for (text) |c| {
        if (c == '-' or std.ascii.isWhitespace(c)) continue;
        if (n >= 56) return error.BadRecoveryKeyFormat;
        const upper = std.ascii.toUpper(c);
        if (crockfordIndex(upper) == null) return error.BadRecoveryKeyFormat;
        symbols[n] = upper;
        n += 1;
    }
    if (n != 56) return error.BadRecoveryKeyFormat;
    const key = decodeRecoveryPayload(symbols[0..52]) catch |err| return if (err == error.Malformed) error.BadRecoveryKeyFormat else err;
    var expected: [4]u8 = undefined;
    encodeRecoveryChecksum(key, &expected);
    if (!std.mem.eql(u8, &expected, symbols[52..56])) return error.BadRecoveryKeyFormat;
    return key;
}
pub fn isValidRecoveryKeyFormat(text: []const u8) bool {
    _ = decodeRecoveryKey(text) catch return false;
    return true;
}
pub fn generateRecoveryKey(a: Allocator) ![32]u8 {
    var io = std.Io.Threaded.init(a, .{});
    defer io.deinit();
    var key: [32]u8 = undefined;
    try io.io().randomSecure(&key);
    return key;
}

fn recoveryKdfJson(a: Allocator, salt: [16]u8) ![]u8 {
    const s = try enc(a, &salt);
    defer a.free(s);
    return std.fmt.allocPrint(a, "{{\"alg\":\"hkdf-sha256\",\"info\":\"{s}\",\"salt\":\"{s}\"}}", .{ RECOVERY_INFO, s });
}
fn recoveryAad(a: Allocator, salt: [16]u8) ![]u8 {
    const canonical = try recoveryKdfJson(a, salt);
    defer a.free(canonical);
    return std.fmt.allocPrint(a, "mp-sync-v1/recovery/{s}", .{canonical});
}
fn deriveRecoveryKek(recovery_key: [32]u8, salt: [16]u8) [32]u8 {
    const Hkdf = std.crypto.kdf.hkdf.HkdfSha256;
    const prk = Hkdf.extract(&salt, &recovery_key);
    var out: [32]u8 = undefined;
    Hkdf.expand(&out, RECOVERY_INFO, prk);
    return out;
}
pub fn wrapRecovery(a: Allocator, recovery_key: [32]u8, recovery_salt: [16]u8, vault_key: [32]u8, recovery_iv: [12]u8) ![]u8 {
    const kek = deriveRecoveryKek(recovery_key, recovery_salt);
    const aad = try recoveryAad(a, recovery_salt);
    defer a.free(aad);
    return sealBytes(a, kek, recovery_iv, &vault_key, aad);
}
pub fn unwrapRecovery(a: Allocator, recovery_key: [32]u8, recovery_salt: [16]u8, ct: []const u8, recovery_iv: [12]u8) ![32]u8 {
    if (ct.len != 48) return error.Malformed;
    const kek = deriveRecoveryKek(recovery_key, recovery_salt);
    const aad = try recoveryAad(a, recovery_salt);
    defer a.free(aad);
    const plain = openBytes(a, kek, recovery_iv, ct, aad) catch |err| return if (err == error.AuthenticationFailed) error.WrongRecoveryKey else err;
    defer {
        std.crypto.secureZero(u8, plain);
        a.free(plain);
    }
    return plain[0..32].*;
}
pub fn sealEnvelopeWithRecovery(a: Allocator, passphrase: []const u8, k: Kdf, key: [32]u8, wrap_iv: [12]u8, records: []const Record, recovery_key: [32]u8, recovery_salt: [16]u8, recovery_iv: [12]u8) ![]u8 {
    if (records.len == 0) return error.Malformed;
    var kek = try deriveKek(a, passphrase, k);
    defer std.crypto.secureZero(u8, &kek);
    const wrapped = try wrap(a, kek, k, key, wrap_iv);
    defer a.free(wrapped);
    const kj = try kdfJson(a, k);
    defer a.free(kj);
    const wi = try enc(a, &wrap_iv);
    defer a.free(wi);
    const wc = try enc(a, wrapped);
    defer a.free(wc);
    const recovery_ct = try wrapRecovery(a, recovery_key, recovery_salt, key, recovery_iv);
    defer a.free(recovery_ct);
    const rkj = try recoveryKdfJson(a, recovery_salt);
    defer a.free(rkj);
    const ri = try enc(a, &recovery_iv);
    defer a.free(ri);
    const rc = try enc(a, recovery_ct);
    defer a.free(rc);
    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(a);
    const header = try std.fmt.allocPrint(a, "{{\"v\":1,\"kdf\":{s},\"wrap\":{{\"alg\":\"AES-256-GCM\",\"iv\":\"{s}\",\"ct\":\"{s}\"}},\"recoveryKdf\":{s},\"recovery\":{{\"alg\":\"AES-256-GCM\",\"iv\":\"{s}\",\"ct\":\"{s}\"}},\"records\":{{", .{ kj, wi, wc, rkj, ri, rc });
    defer a.free(header);
    try out.appendSlice(a, header);
    try appendRecords(&out, a, key, records);
    try out.appendSlice(a, "}}");
    return out.toOwnedSlice(a);
}
pub fn sealNewWithRecovery(a: Allocator, passphrase: []const u8, records: []const struct { id: []const u8, body: []const u8 }) !struct { envelope: []u8, vault_key: [32]u8, recovery_key: [32]u8 } {
    var io = std.Io.Threaded.init(a, .{});
    defer io.deinit();
    var k: Kdf = .{ .salt = undefined };
    try io.io().randomSecure(&k.salt);
    var key: [32]u8 = undefined;
    try io.io().randomSecure(&key);
    errdefer std.crypto.secureZero(u8, &key);
    var wrap_iv: [12]u8 = undefined;
    try io.io().randomSecure(&wrap_iv);
    var recovery_key: [32]u8 = undefined;
    try io.io().randomSecure(&recovery_key);
    var recovery_salt: [16]u8 = undefined;
    try io.io().randomSecure(&recovery_salt);
    var recovery_iv: [12]u8 = undefined;
    try io.io().randomSecure(&recovery_iv);
    const items = try a.alloc(Record, records.len);
    defer a.free(items);
    for (records, items) |record, *item| {
        item.* = .{ .id = record.id, .body = record.body, .iv = undefined };
        try io.io().randomSecure(&item.iv);
    }
    return .{
        .envelope = try sealEnvelopeWithRecovery(a, passphrase, k, key, wrap_iv, items, recovery_key, recovery_salt, recovery_iv),
        .vault_key = key,
        .recovery_key = recovery_key,
    };
}

pub const RecoveryOpenResult = struct { vault_key: [32]u8, records: []Record };
pub fn openEnvelopeWithRecoveryKey(a: Allocator, recovery_key_text: []const u8, envelope: []const u8) !RecoveryOpenResult {
    const recovery_key = try decodeRecoveryKey(recovery_key_text);
    const json = std.json.parseFromSlice(std.json.Value, a, envelope, .{}) catch return error.Malformed;
    defer json.deinit();
    if (try integer(json.value, "v") != 1) return error.UnsupportedVersion;
    const rk = try field(json.value, "recoveryKdf");
    if (!std.mem.eql(u8, try string(rk, "alg"), "hkdf-sha256")) return error.Malformed;
    const recovery_salt = try fixed(16, a, try string(rk, "salt"));
    const rc = try field(json.value, "recovery");
    if (!std.mem.eql(u8, try string(rc, "alg"), "AES-256-GCM")) return error.Malformed;
    const recovery_iv = try fixed(12, a, try string(rc, "iv"));
    const recovery_ct = try dec(a, try string(rc, "ct"));
    defer a.free(recovery_ct);
    var vault_key = try unwrapRecovery(a, recovery_key, recovery_salt, recovery_ct, recovery_iv);
    errdefer std.crypto.secureZero(u8, &vault_key);
    var result = try decryptRecordsObject(a, vault_key, try field(json.value, "records"));
    return .{ .vault_key = vault_key, .records = try result.toOwnedSlice(a) };
}

fn recoverySortLess(_: void, l: []const u8, r: []const u8) bool {
    return std.mem.lessThan(u8, l, r);
}
pub fn rewrapPassphraseWith(a: Allocator, vault_key: [32]u8, new_passphrase: []const u8, new_salt: [16]u8, new_wrap_iv: [12]u8, envelope: []const u8) ![]u8 {
    const json = std.json.parseFromSlice(std.json.Value, a, envelope, .{}) catch return error.Malformed;
    defer json.deinit();
    if (try integer(json.value, "v") != 1) return error.UnsupportedVersion;
    const records_value = try field(json.value, "records");
    if (records_value != .object) return error.Malformed;

    const new_kdf = Kdf{ .salt = new_salt };
    var kek = try deriveKek(a, new_passphrase, new_kdf);
    defer std.crypto.secureZero(u8, &kek);
    const wrapped = try wrap(a, kek, new_kdf, vault_key, new_wrap_iv);
    defer a.free(wrapped);
    const kj = try kdfJson(a, new_kdf);
    defer a.free(kj);
    const wi = try enc(a, &new_wrap_iv);
    defer a.free(wi);
    const wc = try enc(a, wrapped);
    defer a.free(wc);

    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(a);
    const header = try std.fmt.allocPrint(a, "{{\"v\":1,\"kdf\":{s},\"wrap\":{{\"alg\":\"AES-256-GCM\",\"iv\":\"{s}\",\"ct\":\"{s}\"}}", .{ kj, wi, wc });
    defer a.free(header);
    try out.appendSlice(a, header);

    if (json.value.object.get("recoveryKdf")) |rk| {
        if (json.value.object.get("recovery")) |rc| {
            const recovery_part = try std.fmt.allocPrint(
                a,
                ",\"recoveryKdf\":{{\"alg\":\"{s}\",\"info\":\"{s}\",\"salt\":\"{s}\"}},\"recovery\":{{\"alg\":\"{s}\",\"iv\":\"{s}\",\"ct\":\"{s}\"}}",
                .{ try string(rk, "alg"), try string(rk, "info"), try string(rk, "salt"), try string(rc, "alg"), try string(rc, "iv"), try string(rc, "ct") },
            );
            defer a.free(recovery_part);
            try out.appendSlice(a, recovery_part);
        }
    }
    try out.appendSlice(a, ",\"records\":{");

    var ids: std.ArrayList([]const u8) = .empty;
    defer ids.deinit(a);
    var iter = records_value.object.iterator();
    while (iter.next()) |entry| {
        if (!recordId(entry.key_ptr.*)) return error.Malformed;
        try ids.append(a, entry.key_ptr.*);
    }
    std.mem.sort([]const u8, ids.items, {}, recoverySortLess);
    for (ids.items, 0..) |id, index| {
        const entry_value = records_value.object.get(id).?;
        const part = try std.fmt.allocPrint(a, "{s}\"{s}\":{{\"iv\":\"{s}\",\"ct\":\"{s}\"}}", .{ if (index == 0) "" else ",", id, try string(entry_value, "iv"), try string(entry_value, "ct") });
        defer a.free(part);
        try out.appendSlice(a, part);
    }
    try out.appendSlice(a, "}}");
    return out.toOwnedSlice(a);
}
pub fn rewrapPassphrase(a: Allocator, vault_key: [32]u8, new_passphrase: []const u8, envelope: []const u8) ![]u8 {
    var io = std.Io.Threaded.init(a, .{});
    defer io.deinit();
    var new_salt: [16]u8 = undefined;
    try io.io().randomSecure(&new_salt);
    var new_wrap_iv: [12]u8 = undefined;
    try io.io().randomSecure(&new_wrap_iv);
    return rewrapPassphraseWith(a, vault_key, new_passphrase, new_salt, new_wrap_iv, envelope);
}
pub fn freeRecords(a: Allocator, records: []Record) void {
    for (records) |rec| {
        a.free(rec.id);
        a.free(rec.body);
    }
    a.free(records);
}

pub const Host = struct {
    id: []const u8,
    label: []const u8,
    hostname: []const u8,
    port: i64,
    username: []const u8,
    key_secret_id: []const u8,
    passphrase_secret_id: ?[]const u8 = null,
    host_key_type: ?[]const u8 = null,
    host_key_fingerprint: ?[]const u8 = null,
};
pub const Workspace = struct { id: []const u8, name: []const u8, host_id: []const u8, remote_path: []const u8 };
pub const SessionState = struct { last_read_at: i64, archived_at: ?i64 = null, resume_at: ?i64 = null };

fn quoted(out: *std.ArrayList(u8), a: Allocator, value: []const u8) !void {
    try out.append(a, '"');
    const hex = "0123456789abcdef";
    for (value) |c| switch (c) {
        '"' => try out.appendSlice(a, "\\\""),
        '\\' => try out.appendSlice(a, "\\\\"),
        '\n' => try out.appendSlice(a, "\\n"),
        '\r' => try out.appendSlice(a, "\\r"),
        '\t' => try out.appendSlice(a, "\\t"),
        else => if (c < 32) {
            try out.appendSlice(a, &.{ '\\', 'u', '0', '0', hex[c >> 4], hex[c & 15] });
        } else {
            try out.append(a, c);
        },
    };
    try out.append(a, '"');
}
fn ciLess(left: []const u8, right: []const u8) ?bool {
    for (left[0..@min(left.len, right.len)], right[0..@min(left.len, right.len)]) |x, y| {
        const l = std.ascii.toLower(x);
        const r = std.ascii.toLower(y);
        if (l != r) return l < r;
    }
    if (left.len != right.len) return left.len < right.len;
    return null;
}
fn lessHost(_: void, x: Host, y: Host) bool {
    return ciLess(x.label, y.label) orelse std.mem.lessThan(u8, x.id, y.id);
}
fn lessWorkspace(_: void, x: Workspace, y: Workspace) bool {
    return ciLess(x.name, y.name) orelse false;
}
pub fn hostsBody(a: Allocator, hosts: []const Host) ![]u8 {
    const sorted = try a.dupe(Host, hosts);
    defer a.free(sorted);
    std.mem.sort(Host, sorted, {}, lessHost);
    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(a);
    try out.appendSlice(a, "{\"hosts\":[");
    for (sorted, 0..) |h, i| {
        try out.appendSlice(a, if (i == 0) "{\"id\":" else ",{\"id\":");
        try quoted(&out, a, h.id);
        try out.appendSlice(a, ",\"label\":");
        try quoted(&out, a, h.label);
        try out.appendSlice(a, ",\"hostname\":");
        try quoted(&out, a, h.hostname);
        const port = try std.fmt.allocPrint(a, ",\"port\":{d},\"username\":", .{h.port});
        defer a.free(port);
        try out.appendSlice(a, port);
        try quoted(&out, a, h.username);
        try out.appendSlice(a, ",\"keySecretId\":");
        try quoted(&out, a, h.key_secret_id);
        try out.appendSlice(a, ",\"passphraseSecretId\":");
        if (h.passphrase_secret_id) |s| {
            try quoted(&out, a, s);
        } else {
            try out.appendSlice(a, "null");
        }
        try out.appendSlice(a, ",\"hostKeyType\":");
        try quoted(&out, a, h.host_key_type orelse "");
        try out.appendSlice(a, ",\"hostKeyFingerprint\":");
        try quoted(&out, a, h.host_key_fingerprint orelse "");
        try out.append(a, '}');
    }
    try out.appendSlice(a, "]}");
    return out.toOwnedSlice(a);
}
pub fn workspacesBody(a: Allocator, workspaces: []const Workspace) ![]u8 {
    const sorted = try a.dupe(Workspace, workspaces);
    defer a.free(sorted);
    std.mem.sort(Workspace, sorted, {}, lessWorkspace);
    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(a);
    try out.appendSlice(a, "{\"workspaces\":[");
    for (sorted, 0..) |w, i| {
        try out.appendSlice(a, if (i == 0) "{\"id\":" else ",{\"id\":");
        try quoted(&out, a, w.id);
        try out.appendSlice(a, ",\"name\":");
        try quoted(&out, a, w.name);
        try out.appendSlice(a, ",\"hostId\":");
        try quoted(&out, a, w.host_id);
        try out.appendSlice(a, ",\"remotePath\":");
        try quoted(&out, a, w.remote_path);
        try out.append(a, '}');
    }
    try out.appendSlice(a, "]}");
    return out.toOwnedSlice(a);
}
pub fn sessionStateBody(a: Allocator, state: SessionState) ![]u8 {
    const archived = if (state.archived_at) |n| try std.fmt.allocPrint(a, "{d}", .{n}) else try a.dupe(u8, "null");
    defer a.free(archived);
    const resume_text = if (state.resume_at) |n| try std.fmt.allocPrint(a, "{d}", .{n}) else try a.dupe(u8, "null");
    defer a.free(resume_text);
    return std.fmt.allocPrint(a, "{{\"lastReadAt\":{d},\"archivedAt\":{s},\"resumeAt\":{s}}}", .{ state.last_read_at, archived, resume_text });
}
fn nullableInteger(value: std.json.Value, key: []const u8) !?i64 {
    const v = try field(value, key);
    return switch (v) {
        .null => null,
        .integer => v.integer,
        else => error.Malformed,
    };
}
pub fn parseSessionState(a: Allocator, body: []const u8) !SessionState {
    const parsed = std.json.parseFromSlice(std.json.Value, a, body, .{}) catch return error.Malformed;
    defer parsed.deinit();
    const resume_at = try nullableInteger(parsed.value, "resumeAt");
    return .{ .last_read_at = try integer(parsed.value, "lastReadAt"), .archived_at = try nullableInteger(parsed.value, "archivedAt"), .resume_at = if (resume_at != null and resume_at.? > 0) resume_at else null };
}
pub const LocalEntity = struct { record_id: []const u8, entity_id: []const u8, body: []const u8, revision: i64, tombstone: bool = false };
pub const Rebase = union(enum) { applied: []const u8, no_op: []const u8, dropped };
pub fn rebase(a: Allocator, local: LocalEntity, remote: LocalEntity) !Rebase {
    if (!std.mem.eql(u8, local.record_id, remote.record_id) or !std.mem.eql(u8, local.entity_id, remote.entity_id)) return error.Malformed;
    if (remote.tombstone) return .dropped;
    if (local.tombstone) return if (local.revision >= remote.revision) .{ .applied = local.body } else .dropped;
    if (local.revision == remote.revision) return .{ .no_op = remote.body };
    if (std.mem.eql(u8, local.record_id, "hosts") or std.mem.eql(u8, local.record_id, "workspaces")) return .{ .applied = local.body };
    if (!std.mem.eql(u8, local.record_id, "sessionState")) return error.Malformed;
    const ls = try parseSessionState(a, local.body);
    const rs = try parseSessionState(a, remote.body);
    const newer = if (local.revision > remote.revision) ls else rs;
    const body = try sessionStateBody(a, .{ .last_read_at = @max(ls.last_read_at, rs.last_read_at), .archived_at = newer.archived_at, .resume_at = if (newer.archived_at != null) newer.resume_at else null });
    if (std.mem.eql(u8, body, remote.body)) {
        a.free(body);
        return .{ .no_op = remote.body };
    }
    return .{ .applied = body };
}

fn fixtureRoot(a: Allocator) !std.json.Parsed(std.json.Value) {
    return std.json.parseFromSlice(std.json.Value, a, fixtures, .{});
}
fn elements(value: std.json.Value) ![]std.json.Value {
    return if (value == .array) value.array.items else error.Malformed;
}
fn hexSha(bytes: []const u8) [64]u8 {
    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(bytes, &digest, .{});
    var result: [64]u8 = undefined;
    const hex = "0123456789abcdef";
    for (digest, 0..) |byte, i| {
        result[2 * i] = hex[byte >> 4];
        result[2 * i + 1] = hex[byte & 15];
    }
    return result;
}
test "all Android envelope vectors (KEK, wrap, records, canonical JSON, SHA-256 and opening)" {
    const a = std.testing.allocator;
    const parsed = try fixtureRoot(a);
    defer parsed.deinit();
    try std.testing.expectEqualStrings("multiprompt-sync-v1", try string(parsed.value, "protocol"));
    const vectors = try elements(try field(parsed.value, "vectors"));
    try std.testing.expectEqual(@as(usize, 3), vectors.len);
    for (vectors) |v| {
        const salt = try fixed(16, a, try string(v, "salt"));
        const k = Kdf{ .salt = salt };
        const key = try fixed(32, a, try string(v, "vaultKey"));
        const iv = try fixed(12, a, try string(v, "wrapIv"));
        var kek = try deriveKek(a, try string(v, "passphrase"), k);
        defer std.crypto.secureZero(u8, &kek);
        const encoded_kek = try enc(a, &kek);
        defer a.free(encoded_kek);
        try std.testing.expectEqualStrings(try string(v, "kek"), encoded_kek);
        const wrapped = try wrap(a, kek, k, key, iv);
        defer a.free(wrapped);
        const encoded_wrap = try enc(a, wrapped);
        defer a.free(encoded_wrap);
        try std.testing.expectEqualStrings(try string(v, "wrapCt"), encoded_wrap);
        var records: std.ArrayList(Record) = .empty;
        defer records.deinit(a);
        for (try elements(try field(v, "records"))) |r| {
            const id = try string(r, "id");
            const ri = try fixed(12, a, try string(r, "iv"));
            const body = try string(r, "plaintextUtf8");
            try records.append(a, .{ .id = id, .iv = ri, .body = body });
            const ct = try sealRecord(a, key, id, body, ri);
            defer a.free(ct);
            const encoded_ct = try enc(a, ct);
            defer a.free(encoded_ct);
            try std.testing.expectEqualStrings(try string(r, "ct"), encoded_ct);
        }
        const envelope = try sealEnvelope(a, try string(v, "passphrase"), k, key, iv, records.items);
        defer a.free(envelope);
        try std.testing.expectEqualStrings(try string(v, "envelopeJson"), envelope);
        try std.testing.expectEqualStrings(try string(v, "envelopeSha256"), &hexSha(envelope));
        const opened = try openEnvelope(a, try string(v, "passphrase"), envelope);
        defer freeRecords(a, opened);
        try std.testing.expectEqual(records.items.len, opened.len);
        for (records.items) |r| {
            var found = false;
            for (opened) |o| if (std.mem.eql(u8, r.id, o.id)) {
                try std.testing.expectEqualStrings(r.body, o.body);
                found = true;
            };
            try std.testing.expect(found);
        }
        try std.testing.expectError(error.WrongPassphrase, openEnvelope(a, "wrong passphrase", envelope));
        const tampered = try a.dupe(u8, envelope);
        defer a.free(tampered);
        const needle = try string((try elements(try field(v, "records")))[0], "ct");
        const pos = std.mem.indexOf(u8, tampered, needle).?;
        tampered[pos] = if (tampered[pos] == 'A') 'B' else 'A';
        try std.testing.expectError(error.Tampered, openEnvelope(a, try string(v, "passphrase"), tampered));
        const decoded = try dec(a, needle);
        defer a.free(decoded);
        try std.testing.expectError(error.Tampered, openRecord(a, key, "different", decoded, records.items[0].iv));
    }
}
test "all Android entity vectors and bound metadata" {
    const a = std.testing.allocator;
    const parsed = try fixtureRoot(a);
    defer parsed.deinit();
    const vectors = try elements(try field(parsed.value, "entityVectors"));
    try std.testing.expectEqual(@as(usize, 2), vectors.len);
    for (vectors) |v| {
        const key = try fixed(32, a, try string(v, "vaultKey"));
        const iv = try fixed(12, a, try string(v, "iv"));
        const m = Metadata{ .record_id = try string(v, "recordId"), .entity_id = try string(v, "entityId"), .account_id = try string(v, "accountId"), .revision = try integer(v, "revision") };
        const payload = try sealEntity(a, key, m, try string(v, "plaintextUtf8"), iv);
        defer a.free(payload);
        try std.testing.expectEqualStrings(try string(v, "payloadJson"), payload);
        try std.testing.expectEqualStrings(try string(v, "payloadSha256"), &hexSha(payload));
        const opened = try openEntity(a, key, m, payload);
        defer a.free(opened);
        try std.testing.expectEqualStrings(try string(v, "plaintextUtf8"), opened);
        var changed = m;
        changed.revision += 1;
        try std.testing.expectError(error.Tampered, openEntity(a, key, changed, payload));
        changed = m;
        changed.account_id = "other-account";
        try std.testing.expectError(error.Tampered, openEntity(a, key, changed, payload));
        changed = m;
        changed.schema_version = 2;
        try std.testing.expectError(error.Tampered, openEntity(a, key, changed, payload));
    }
}

test "all Android schema vectors are reproduced by canonical writers" {
    const a = std.testing.allocator;
    const parsed = try fixtureRoot(a);
    defer parsed.deinit();
    const vectors = try elements(try field(parsed.value, "schemaVectors"));
    try std.testing.expectEqual(@as(usize, 4), vectors.len);
    for (vectors) |v| {
        const expected = try string(v, "canonicalBodyJson");
        const body_json = try std.json.parseFromSlice(std.json.Value, a, expected, .{});
        defer body_json.deinit();
        const id = try string(v, "recordId");
        const body = if (std.mem.eql(u8, id, "hosts")) blk: {
            var hosts: std.ArrayList(Host) = .empty;
            defer hosts.deinit(a);
            for (try elements(try field(body_json.value, "hosts"))) |h| {
                const pass = try field(h, "passphraseSecretId");
                try hosts.insert(a, 0, .{
                    .id = try string(h, "id"),
                    .label = try string(h, "label"),
                    .hostname = try string(h, "hostname"),
                    .port = try integer(h, "port"),
                    .username = try string(h, "username"),
                    .key_secret_id = try string(h, "keySecretId"),
                    .passphrase_secret_id = if (pass == .null) null else try string(h, "passphraseSecretId"),
                    .host_key_type = try string(h, "hostKeyType"),
                    .host_key_fingerprint = try string(h, "hostKeyFingerprint"),
                });
            }
            break :blk try hostsBody(a, hosts.items);
        } else if (std.mem.eql(u8, id, "workspaces")) blk: {
            var workspaces: std.ArrayList(Workspace) = .empty;
            defer workspaces.deinit(a);
            for (try elements(try field(body_json.value, "workspaces"))) |w| try workspaces.insert(a, 0, .{
                .id = try string(w, "id"),
                .name = try string(w, "name"),
                .host_id = try string(w, "hostId"),
                .remote_path = try string(w, "remotePath"),
            });
            break :blk try workspacesBody(a, workspaces.items);
        } else try sessionStateBody(a, try parseSessionState(a, expected));
        defer a.free(body);
        try std.testing.expectEqualStrings(expected, body);
        try std.testing.expectEqualStrings(try string(v, "canonicalBodySha256"), &hexSha(body));
    }
}
test "rebase preserves watermarks, revision intent, and tombstones" {
    const a = std.testing.allocator;
    const local = LocalEntity{ .record_id = "sessionState", .entity_id = "host--session", .body = "{\"lastReadAt\":30,\"archivedAt\":null,\"resumeAt\":null}", .revision = 2 };
    const remote = LocalEntity{ .record_id = "sessionState", .entity_id = "host--session", .body = "{\"lastReadAt\":40,\"archivedAt\":20,\"resumeAt\":50}", .revision = 1 };
    const result = try rebase(a, local, remote);
    switch (result) {
        .applied => |body| {
            defer a.free(body);
            try std.testing.expectEqualStrings("{\"lastReadAt\":40,\"archivedAt\":null,\"resumeAt\":null}", body);
        },
        else => return error.TestUnexpectedResult,
    }
    var deleted = remote;
    deleted.tombstone = true;
    try std.testing.expect((try rebase(a, local, deleted)) == .dropped);
}

test "fresh vault generates independently sealed records" {
    if (@import("builtin").os.tag == .windows) return;
    const a = std.testing.allocator;
    const fresh = try sealNew(a, "passphrase", &.{.{ .id = "hosts", .body = "{}" }});
    defer a.free(fresh.envelope);
    const opened = try openEnvelope(a, "passphrase", fresh.envelope);
    defer freeRecords(a, opened);
    try std.testing.expectEqualStrings("{}", opened[0].body);
}
test "openEnvelopeVaultKey returns the same key sealNew generated" {
    if (@import("builtin").os.tag == .windows) return;
    const a = std.testing.allocator;
    const fresh = try sealNew(a, "passphrase", &.{.{ .id = "hosts", .body = "{}" }});
    defer a.free(fresh.envelope);
    const key = try openEnvelopeVaultKey(a, "passphrase", fresh.envelope);
    try std.testing.expectEqualSlices(u8, &fresh.vault_key, &key);
    try std.testing.expectError(error.WrongPassphrase, openEnvelopeVaultKey(a, "wrong", fresh.envelope));
}
test "negative envelope versions and authenticated metadata" {
    const a = std.testing.allocator;
    const parsed = try fixtureRoot(a);
    defer parsed.deinit();
    const vector = (try elements(try field(parsed.value, "vectors")))[0];
    const passphrase = try string(vector, "passphrase");
    const envelope = try string(vector, "envelopeJson");
    try std.testing.expectError(error.Malformed, openEnvelope(a, "passphrase", "not json"));
    const changed = try a.dupe(u8, envelope);
    defer a.free(changed);
    const version = std.mem.indexOf(u8, changed, "\"v\":1").?;
    changed[version + 4] = '2';
    try std.testing.expectError(error.UnsupportedVersion, openEnvelope(a, passphrase, changed));
    changed[version + 4] = '1';
    const id = std.mem.indexOf(u8, changed, "\"hosts\":{").?;
    changed[id + 5] = 'z';
    try std.testing.expectError(error.Tampered, openEnvelope(a, passphrase, changed));
    changed[id + 5] = 's';
    const wrap_iv = std.mem.indexOf(u8, changed, "\"wrap\":{").?;
    const iv = std.mem.indexOf(u8, changed[wrap_iv..], "\"iv\":\"").? + wrap_iv + 6;
    changed[iv] = if (changed[iv] == 'A') 'B' else 'A';
    try std.testing.expectError(error.WrongPassphrase, openEnvelope(a, passphrase, changed));
    try std.testing.expectError(error.Malformed, sealEntity(a, try fixed(32, a, try string(vector, "vaultKey")), .{ .record_id = "hosts", .entity_id = "a/b", .account_id = "acc", .revision = 1 }, "{}", [_]u8{0} ** 12));
}

test "all Android recovery vectors reproduce byte-for-byte, open, and rewrap" {
    const a = std.testing.allocator;
    const parsed = try fixtureRoot(a);
    defer parsed.deinit();
    const vectors = try elements(try field(parsed.value, "recoveryVectors"));
    try std.testing.expect(vectors.len > 0);
    for (vectors) |v| {
        const salt = try fixed(16, a, try string(v, "salt"));
        const key = try fixed(32, a, try string(v, "vaultKey"));
        const wrap_iv = try fixed(12, a, try string(v, "wrapIv"));
        const recovery_key = try fixed(32, a, try string(v, "recoveryKeyBytes"));
        const recovery_salt = try fixed(16, a, try string(v, "recoverySalt"));
        const recovery_iv = try fixed(12, a, try string(v, "recoveryIv"));
        const k = Kdf{ .salt = salt };

        const record = (try elements(try field(v, "records")))[0];
        const record_id = try string(record, "id");
        const record_iv = try fixed(12, a, try string(record, "iv"));
        const body = try string(record, "plaintextUtf8");

        const encoded = encodeRecoveryKey(recovery_key);
        try std.testing.expectEqualStrings(try string(v, "recoveryKeyString"), &encoded);

        const envelope = try sealEnvelopeWithRecovery(a, try string(v, "passphrase"), k, key, wrap_iv, &.{.{ .id = record_id, .iv = record_iv, .body = body }}, recovery_key, recovery_salt, recovery_iv);
        defer a.free(envelope);
        try std.testing.expectEqualStrings(try string(v, "envelopeJson"), envelope);
        try std.testing.expectEqualStrings(try string(v, "envelopeSha256"), &hexSha(envelope));

        const opened = try openEnvelope(a, try string(v, "passphrase"), envelope);
        defer freeRecords(a, opened);
        try std.testing.expectEqual(@as(usize, 1), opened.len);
        try std.testing.expectEqualStrings(body, opened[0].body);

        const recovered = try openEnvelopeWithRecoveryKey(a, &encoded, envelope);
        defer freeRecords(a, recovered.records);
        try std.testing.expectEqualSlices(u8, &key, &recovered.vault_key);
        try std.testing.expectEqual(@as(usize, 1), recovered.records.len);
        try std.testing.expectEqualStrings(body, recovered.records[0].body);

        const new_salt = [_]u8{7} ** 16;
        const new_wrap_iv = [_]u8{9} ** 12;
        const rewrapped = try rewrapPassphraseWith(a, recovered.vault_key, "a brand new passphrase", new_salt, new_wrap_iv, envelope);
        defer a.free(rewrapped);
        try std.testing.expectError(error.WrongPassphrase, openEnvelope(a, try string(v, "passphrase"), rewrapped));
        const reopened = try openEnvelope(a, "a brand new passphrase", rewrapped);
        defer freeRecords(a, reopened);
        try std.testing.expectEqualStrings(body, reopened[0].body);
        const stillRecovers = try openEnvelopeWithRecoveryKey(a, &encoded, rewrapped);
        defer freeRecords(a, stillRecovers.records);
        try std.testing.expectEqualSlices(u8, &key, &stillRecovers.vault_key);

        var wrong_key = recovery_key;
        wrong_key[0] +%= 1;
        const wrong_key_string = encodeRecoveryKey(wrong_key);
        try std.testing.expectError(error.WrongRecoveryKey, openEnvelopeWithRecoveryKey(a, &wrong_key_string, envelope));

        const tampered = try a.dupe(u8, envelope);
        defer a.free(tampered);
        const recovery_block = std.mem.indexOf(u8, tampered, "\"recovery\":{").?;
        const ct_pos = std.mem.indexOf(u8, tampered[recovery_block..], "\"ct\":\"").? + recovery_block + 6;
        tampered[ct_pos] = if (tampered[ct_pos] == 'A') 'B' else 'A';
        try std.testing.expectError(error.WrongRecoveryKey, openEnvelopeWithRecoveryKey(a, &encoded, tampered));

        const no_recovery_vector = (try elements(try field(parsed.value, "vectors")))[0];
        try std.testing.expectError(error.Malformed, openEnvelopeWithRecoveryKey(a, &encoded, try string(no_recovery_vector, "envelopeJson")));
    }
}

test "recovery key string vectors encode, decode, and reject a bad checksum" {
    const a = std.testing.allocator;
    const parsed = try fixtureRoot(a);
    defer parsed.deinit();
    const vectors = try elements(try field(parsed.value, "recoveryKeyStringVectors"));
    try std.testing.expect(vectors.len >= 2);

    const good = vectors[0];
    const key_bytes = try fixed(32, a, try string(good, "keyBytes"));
    const encoded = encodeRecoveryKey(key_bytes);
    try std.testing.expectEqualStrings(try string(good, "encoded"), &encoded);
    try std.testing.expectEqualSlices(u8, &key_bytes, &try decodeRecoveryKey(&encoded));
    try std.testing.expect(isValidRecoveryKeyFormat(&encoded));

    var messy_buf: [128]u8 = undefined;
    var messy_len: usize = 0;
    messy_buf[messy_len] = ' ';
    messy_len += 1;
    for (encoded) |c| {
        messy_buf[messy_len] = if (c == '-') ' ' else std.ascii.toLower(c);
        messy_len += 1;
        if (c == '-') {
            messy_buf[messy_len] = '-';
            messy_len += 1;
        }
    }
    try std.testing.expectEqualSlices(u8, &key_bytes, &try decodeRecoveryKey(messy_buf[0..messy_len]));

    for (vectors[1..]) |bad| {
        const bad_encoded = try string(bad, "encoded");
        try std.testing.expect(!isValidRecoveryKeyFormat(bad_encoded));
        try std.testing.expectError(error.BadRecoveryKeyFormat, decodeRecoveryKey(bad_encoded));
    }
}

test "malformed recovery key strings are rejected without a fixture" {
    try std.testing.expect(!isValidRecoveryKeyFormat("not even close"));
    try std.testing.expect(!isValidRecoveryKeyFormat(""));
    try std.testing.expectError(error.BadRecoveryKeyFormat, decodeRecoveryKey("too-short"));
}

test "fresh vault with recovery key round-trips through sealNewWithRecovery" {
    if (@import("builtin").os.tag == .windows) return;
    const a = std.testing.allocator;
    const fresh = try sealNewWithRecovery(a, "passphrase", &.{.{ .id = "hosts", .body = "{}" }});
    defer a.free(fresh.envelope);
    const encoded = encodeRecoveryKey(fresh.recovery_key);
    const recovered = try openEnvelopeWithRecoveryKey(a, &encoded, fresh.envelope);
    defer freeRecords(a, recovered.records);
    try std.testing.expectEqualSlices(u8, &fresh.vault_key, &recovered.vault_key);
    try std.testing.expectEqualStrings("{}", recovered.records[0].body);
}
