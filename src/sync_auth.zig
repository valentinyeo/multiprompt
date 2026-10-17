const std = @import("std");

pub const Config = struct {
    client_id: []const u8,
    authorization_endpoint: []const u8,
    token_endpoint: []const u8,
    redirect_uri: []const u8,
    scope: []const u8 = "openid profile email",
};

const DEFAULT_CLIENT_ID = "YOUR_OIDC_CLIENT_ID";
const DEFAULT_AUTHORIZATION_ENDPOINT = "https://auth.example.com/authorize";
const DEFAULT_TOKEN_ENDPOINT = "https://auth.example.com/token";
const DEFAULT_REDIRECT_URI = "multiprompt://auth/callback";
const DEFAULT_SCOPE = "openid profile email";

pub fn defaultConfig(allocator: std.mem.Allocator) !Config {
    return Config{
        .client_id = try allocator.dupe(u8, DEFAULT_CLIENT_ID),
        .authorization_endpoint = try allocator.dupe(u8, DEFAULT_AUTHORIZATION_ENDPOINT),
        .token_endpoint = try allocator.dupe(u8, DEFAULT_TOKEN_ENDPOINT),
        .redirect_uri = try allocator.dupe(u8, DEFAULT_REDIRECT_URI),
        .scope = try allocator.dupe(u8, DEFAULT_SCOPE),
    };
}

pub const Pending = struct {
    state: []const u8,
    verifier: []const u8,
};

pub const Callback = struct {
    code: ?[]const u8 = null,
    state: ?[]const u8 = null,
    oauth_error: ?[]const u8 = null,
};

pub const DATA_BLOB = extern struct {
    cbData: u32,
    pbData: ?[*]u8,
};

const CRYPTPROTECT_UI_FORBIDDEN: u32 = 0x1;
extern "crypt32" fn CryptProtectData(*const DATA_BLOB, ?[*:0]const u16, ?*const DATA_BLOB, ?*anyopaque, ?*anyopaque, u32, *DATA_BLOB) callconv(.winapi) i32;
extern "crypt32" fn CryptUnprotectData(*const DATA_BLOB, ?*?[*:0]u16, ?*const DATA_BLOB, ?*anyopaque, ?*anyopaque, u32, *DATA_BLOB) callconv(.winapi) i32;
extern "bcrypt" fn BCryptGenRandom(?*anyopaque, [*]u8, u32, u32) callconv(.winapi) i32;
extern "kernel32" fn LocalFree(?*anyopaque) callconv(.winapi) ?*anyopaque;
const BCRYPT_USE_SYSTEM_PREFERRED_RNG: u32 = 0x00000002;

fn jsonString(root: std.json.Value, key: []const u8) ?[]const u8 {
    if (root != .object) return null;
    const value = root.object.get(key) orelse return null;
    if (value != .string or value.string.len == 0) return null;
    return value.string;
}

pub fn parseConfig(allocator: std.mem.Allocator, bytes: []const u8) !Config {
    var parsed = try std.json.parseFromSlice(std.json.Value, allocator, bytes, .{});
    errdefer parsed.deinit();
    const value = parsed.value;
    const client_id = jsonString(value, "clientId") orelse return error.MissingClientId;
    const authorization_endpoint = jsonString(value, "authorizationEndpoint") orelse return error.MissingAuthorizationEndpoint;
    const token_endpoint = jsonString(value, "tokenEndpoint") orelse return error.MissingTokenEndpoint;
    const redirect_uri = jsonString(value, "redirectUri") orelse return error.MissingRedirectUri;
    const scope = jsonString(value, "scope") orelse DEFAULT_SCOPE;
    const owned_client_id = try allocator.dupe(u8, client_id);
    errdefer allocator.free(owned_client_id);
    const owned_authorization_endpoint = try allocator.dupe(u8, authorization_endpoint);
    errdefer allocator.free(owned_authorization_endpoint);
    const owned_token_endpoint = try allocator.dupe(u8, token_endpoint);
    errdefer allocator.free(owned_token_endpoint);
    const owned_redirect_uri = try allocator.dupe(u8, redirect_uri);
    errdefer allocator.free(owned_redirect_uri);
    const owned_scope = try allocator.dupe(u8, scope);
    errdefer allocator.free(owned_scope);
    const owned = Config{
        .client_id = owned_client_id,
        .authorization_endpoint = owned_authorization_endpoint,
        .token_endpoint = owned_token_endpoint,
        .redirect_uri = owned_redirect_uri,
        .scope = owned_scope,
    };
    parsed.deinit();
    return owned;
}

pub fn deinitConfig(allocator: std.mem.Allocator, config: Config) void {
    allocator.free(config.client_id);
    allocator.free(config.authorization_endpoint);
    allocator.free(config.token_endpoint);
    allocator.free(config.redirect_uri);
    allocator.free(config.scope);
}

fn appendPercentEncoded(out: *std.ArrayList(u8), allocator: std.mem.Allocator, value: []const u8) !void {
    const hex = "0123456789ABCDEF";
    for (value) |c| {
        if (std.ascii.isAlphanumeric(c) or c == '-' or c == '.' or c == '_' or c == '~') {
            try out.append(allocator, c);
        } else {
            try out.appendSlice(allocator, &.{ '%', hex[c >> 4], hex[c & 15] });
        }
    }
}

fn appendParameter(out: *std.ArrayList(u8), allocator: std.mem.Allocator, first: *bool, key: []const u8, value: []const u8) !void {
    try out.append(allocator, if (first.*) '?' else '&');
    first.* = false;
    try out.appendSlice(allocator, key);
    try out.append(allocator, '=');
    try appendPercentEncoded(out, allocator, value);
}

pub fn buildAuthorizationUrl(allocator: std.mem.Allocator, config: Config, state: []const u8, challenge: []const u8) ![]u8 {
    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(allocator);
    try out.appendSlice(allocator, config.authorization_endpoint);
    var first = std.mem.indexOfScalar(u8, config.authorization_endpoint, '?') == null;
    try appendParameter(&out, allocator, &first, "response_type", "code");
    try appendParameter(&out, allocator, &first, "client_id", config.client_id);
    try appendParameter(&out, allocator, &first, "redirect_uri", config.redirect_uri);
    try appendParameter(&out, allocator, &first, "scope", config.scope);
    try appendParameter(&out, allocator, &first, "state", state);
    try appendParameter(&out, allocator, &first, "code_challenge", challenge);
    try appendParameter(&out, allocator, &first, "code_challenge_method", "S256");
    return out.toOwnedSlice(allocator);
}

pub fn buildTokenForm(allocator: std.mem.Allocator, config: Config, code: []const u8, verifier: []const u8) ![]u8 {
    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(allocator);
    var first = true;
    const fields = [_]struct { key: []const u8, value: []const u8 }{
        .{ .key = "grant_type", .value = "authorization_code" },
        .{ .key = "client_id", .value = config.client_id },
        .{ .key = "code", .value = code },
        .{ .key = "redirect_uri", .value = config.redirect_uri },
        .{ .key = "code_verifier", .value = verifier },
    };
    for (fields) |field| {
        if (!first) try out.append(allocator, '&');
        first = false;
        try out.appendSlice(allocator, field.key);
        try out.append(allocator, '=');
        try appendPercentEncoded(&out, allocator, field.value);
    }
    return out.toOwnedSlice(allocator);
}

pub fn generatePkce(verifier_buf: *[64]u8, state_buf: *[43]u8, challenge_buf: *[43]u8) !struct { verifier: []const u8, state: []const u8, challenge: []const u8 } {
    var verifier_random: [48]u8 = undefined;
    var state_random: [32]u8 = undefined;
    if (BCryptGenRandom(null, &verifier_random, verifier_random.len, BCRYPT_USE_SYSTEM_PREFERRED_RNG) < 0) return error.RandomFailed;
    if (BCryptGenRandom(null, &state_random, state_random.len, BCRYPT_USE_SYSTEM_PREFERRED_RNG) < 0) return error.RandomFailed;
    const verifier_len = std.base64.url_safe_no_pad.Encoder.calcSize(verifier_random.len);
    _ = std.base64.url_safe_no_pad.Encoder.encode(verifier_buf[0..verifier_len], &verifier_random);
    const state_len = std.base64.url_safe_no_pad.Encoder.calcSize(state_random.len);
    _ = std.base64.url_safe_no_pad.Encoder.encode(state_buf[0..state_len], &state_random);
    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(verifier_buf[0..verifier_len], &digest, .{});
    const challenge_len = std.base64.url_safe_no_pad.Encoder.calcSize(digest.len);
    _ = std.base64.url_safe_no_pad.Encoder.encode(challenge_buf[0..challenge_len], &digest);
    return .{
        .verifier = verifier_buf[0..verifier_len],
        .state = state_buf[0..state_len],
        .challenge = challenge_buf[0..challenge_len],
    };
}

fn hexValue(c: u8) ?u8 {
    return if (c >= '0' and c <= '9') c - '0' else if (c >= 'a' and c <= 'f') c - 'a' + 10 else if (c >= 'A' and c <= 'F') c - 'A' + 10 else null;
}

fn decodeQueryValue(allocator: std.mem.Allocator, value: []const u8) ![]u8 {
    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(allocator);
    var i: usize = 0;
    while (i < value.len) {
        if (value[i] == '%' and i + 2 < value.len) {
            const hi = hexValue(value[i + 1]) orelse return error.InvalidPercentEncoding;
            const lo = hexValue(value[i + 2]) orelse return error.InvalidPercentEncoding;
            try out.append(allocator, (hi << 4) | lo);
            i += 3;
        } else {
            try out.append(allocator, if (value[i] == '+') ' ' else value[i]);
            i += 1;
        }
    }
    return out.toOwnedSlice(allocator);
}

pub fn parseCallback(allocator: std.mem.Allocator, url: []const u8) !Callback {
    const question = std.mem.indexOfScalar(u8, url, '?') orelse return error.MissingQuery;
    const fragment = std.mem.indexOfPos(u8, url, question + 1, "#") orelse url.len;
    var result: Callback = .{};
    errdefer deinitCallback(allocator, result);
    var fields = std.mem.splitScalar(u8, url[question + 1 .. fragment], '&');
    while (fields.next()) |field| {
        const equals = std.mem.indexOfScalar(u8, field, '=') orelse continue;
        const key = field[0..equals];
        const value = try decodeQueryValue(allocator, field[equals + 1 ..]);
        if (std.mem.eql(u8, key, "code")) {
            if (result.code) |previous| allocator.free(previous);
            result.code = value;
        } else if (std.mem.eql(u8, key, "state")) {
            if (result.state) |previous| allocator.free(previous);
            result.state = value;
        } else if (std.mem.eql(u8, key, "error")) {
            if (result.oauth_error) |previous| allocator.free(previous);
            result.oauth_error = value;
        } else allocator.free(value);
    }
    return result;
}

pub fn deinitCallback(allocator: std.mem.Allocator, callback: Callback) void {
    if (callback.code) |value| allocator.free(value);
    if (callback.state) |value| allocator.free(value);
    if (callback.oauth_error) |value| allocator.free(value);
}

pub fn protect(allocator: std.mem.Allocator, plaintext: []const u8) ![]u8 {
    if (plaintext.len > std.math.maxInt(u32)) return error.ValueTooLarge;
    var input = DATA_BLOB{ .cbData = @intCast(plaintext.len), .pbData = if (plaintext.len == 0) null else @constCast(plaintext.ptr) };
    var output = DATA_BLOB{ .cbData = 0, .pbData = null };
    if (CryptProtectData(&input, null, null, null, null, CRYPTPROTECT_UI_FORBIDDEN, &output) == 0) return error.ProtectFailed;
    defer _ = LocalFree(output.pbData);
    const data = output.pbData orelse return error.ProtectFailed;
    return allocator.dupe(u8, data[0..output.cbData]);
}

pub fn unprotect(allocator: std.mem.Allocator, ciphertext: []const u8) ![]u8 {
    if (ciphertext.len > std.math.maxInt(u32)) return error.ValueTooLarge;
    var input = DATA_BLOB{ .cbData = @intCast(ciphertext.len), .pbData = if (ciphertext.len == 0) null else @constCast(ciphertext.ptr) };
    var output = DATA_BLOB{ .cbData = 0, .pbData = null };
    if (CryptUnprotectData(&input, null, null, null, null, CRYPTPROTECT_UI_FORBIDDEN, &output) == 0) return error.UnprotectFailed;
    defer _ = LocalFree(output.pbData);
    const data = output.pbData orelse return error.UnprotectFailed;
    defer std.crypto.secureZero(u8, data[0..output.cbData]);
    return allocator.dupe(u8, data[0..output.cbData]);
}

pub fn tokenJsonHasAccessToken(allocator: std.mem.Allocator, token_json: []const u8) bool {
    var parsed = std.json.parseFromSlice(std.json.Value, allocator, token_json, .{}) catch return false;
    defer parsed.deinit();
    if (parsed.value != .object) return false;
    const access = parsed.value.object.get("access_token") orelse return false;
    return access == .string and access.string.len > 0;
}

fn base64UrlDecodeAlloc(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    const decoder = std.base64.url_safe_no_pad.Decoder;
    const size = try decoder.calcSizeForSlice(input);
    const out = try allocator.alloc(u8, size);
    errdefer allocator.free(out);
    try decoder.decode(out, input);
    return out;
}

pub fn extractEmailFromIdToken(allocator: std.mem.Allocator, id_token: []const u8) ?[]u8 {
    var parts = std.mem.splitScalar(u8, id_token, '.');
    _ = parts.next() orelse return null;
    const payload_b64 = parts.next() orelse return null;
    const payload = base64UrlDecodeAlloc(allocator, payload_b64) catch return null;
    defer allocator.free(payload);
    var parsed = std.json.parseFromSlice(std.json.Value, allocator, payload, .{}) catch return null;
    defer parsed.deinit();
    if (parsed.value != .object) return null;
    const email = parsed.value.object.get("email") orelse return null;
    if (email != .string or email.string.len == 0) return null;
    return allocator.dupe(u8, email.string) catch null;
}

pub fn commandLineIsExactly(cmdline: []const u8, flag: []const u8) bool {
    var i: usize = 0;
    if (cmdline.len > 0 and cmdline[0] == '"') {
        i = 1;
        while (i < cmdline.len and cmdline[i] != '"') : (i += 1) {}
        if (i < cmdline.len) i += 1;
    } else {
        while (i < cmdline.len and cmdline[i] != ' ' and cmdline[i] != '\t') : (i += 1) {}
    }
    return std.mem.eql(u8, std.mem.trim(u8, cmdline[i..], " \t"), flag);
}

pub const VaultAction = enum {
    already_unlocked,
    create_new,
    unlock_with_passphrase,
};

pub fn decideVaultAction(remote_vault_exists: bool, have_local_vault_key: bool) VaultAction {
    if (have_local_vault_key) return .already_unlocked;
    return if (remote_vault_exists) .unlock_with_passphrase else .create_new;
}

test "PKCE authorization URL contains S256 and encoded redirect" {
    var verifier: [64]u8 = undefined;
    var state: [43]u8 = undefined;
    var challenge: [43]u8 = undefined;
    const values = try generatePkce(&verifier, &state, &challenge);
    try std.testing.expectEqual(@as(usize, 64), values.verifier.len);
    try std.testing.expectEqual(@as(usize, 43), values.state.len);
    try std.testing.expectEqual(@as(usize, 43), values.challenge.len);
    const url = try buildAuthorizationUrl(std.testing.allocator, .{
        .client_id = "desktop-client",
        .authorization_endpoint = "https://login.example/authorize",
        .token_endpoint = "https://login.example/token",
        .redirect_uri = "multiprompt://auth/callback",
    }, "expected state", "challenge");
    defer std.testing.allocator.free(url);
    try std.testing.expect(std.mem.indexOf(u8, url, "code_challenge_method=S256") != null);
    try std.testing.expect(std.mem.indexOf(u8, url, "state=expected%20state") != null);
    try std.testing.expect(std.mem.indexOf(u8, url, "redirect_uri=multiprompt%3A%2F%2Fauth%2Fcallback") != null);
}

test "callback parser decodes code and state" {
    const callback = try parseCallback(std.testing.allocator, "multiprompt://auth/callback?code=a%2Fb%2Bc&state=hello%20there");
    defer deinitCallback(std.testing.allocator, callback);
    try std.testing.expectEqualStrings("a/b+c", callback.code.?);
    try std.testing.expectEqualStrings("hello there", callback.state.?);
}

test "token form carries verifier without a client secret" {
    const form = try buildTokenForm(std.testing.allocator, .{
        .client_id = "public-client",
        .authorization_endpoint = "https://login.example/authorize",
        .token_endpoint = "https://login.example/token",
        .redirect_uri = "multiprompt://auth/callback",
    }, "code/value", "verifier");
    defer std.testing.allocator.free(form);
    try std.testing.expect(std.mem.indexOf(u8, form, "code=code%2Fvalue") != null);
    try std.testing.expect(std.mem.indexOf(u8, form, "code_verifier=verifier") != null);
    try std.testing.expect(std.mem.indexOf(u8, form, "client_secret") == null);
}

test "DPAPI protects and restores desktop auth state" {
    const protected = try protect(std.testing.allocator, "state-and-verifier");
    defer std.testing.allocator.free(protected);
    try std.testing.expect(!std.mem.eql(u8, protected, "state-and-verifier"));
    const restored = try unprotect(std.testing.allocator, protected);
    defer std.testing.allocator.free(restored);
    try std.testing.expectEqualStrings("state-and-verifier", restored);
}

test "default config carries a real scope with no offline_access and is independently freeable" {
    const config = try defaultConfig(std.testing.allocator);
    defer deinitConfig(std.testing.allocator, config);
    try std.testing.expectEqualStrings("openid profile email", config.scope);
    try std.testing.expect(std.mem.indexOf(u8, config.scope, "offline_access") == null);
    try std.testing.expect(config.client_id.len > 0);
    try std.testing.expect(std.mem.startsWith(u8, config.authorization_endpoint, "https://"));
    try std.testing.expect(std.mem.startsWith(u8, config.token_endpoint, "https://"));
}

test "token JSON round trip: access_token present vs missing vs malformed" {
    try std.testing.expect(tokenJsonHasAccessToken(std.testing.allocator, "{\"access_token\":\"abc123\"}"));
    try std.testing.expect(!tokenJsonHasAccessToken(std.testing.allocator, "{\"access_token\":\"\"}"));
    try std.testing.expect(!tokenJsonHasAccessToken(std.testing.allocator, "{\"token_type\":\"bearer\"}"));
    try std.testing.expect(!tokenJsonHasAccessToken(std.testing.allocator, "not json"));
    try std.testing.expect(!tokenJsonHasAccessToken(std.testing.allocator, "[]"));
}

test "email extraction reads the id_token payload without checking the signature" {
    const id_token = "eyJhbGciOiJSUzI1NiJ9.eyJlbWFpbCI6InVzZXJAZXhhbXBsZS5jb20iLCJzdWIiOiJ1MSJ9.sig";
    const email = extractEmailFromIdToken(std.testing.allocator, id_token).?;
    defer std.testing.allocator.free(email);
    try std.testing.expectEqualStrings("user@example.com", email);
}

test "email extraction returns null on a malformed or claimless token" {
    try std.testing.expect(extractEmailFromIdToken(std.testing.allocator, "not-a-jwt") == null);
    const no_email = "eyJhbGciOiJSUzI1NiJ9.eyJzdWIiOiJ1MSJ9.sig";
    try std.testing.expect(extractEmailFromIdToken(std.testing.allocator, no_email) == null);
}

test "vault action decision: local key wins, then remote existence" {
    try std.testing.expectEqual(VaultAction.already_unlocked, decideVaultAction(true, true));
    try std.testing.expectEqual(VaultAction.already_unlocked, decideVaultAction(false, true));
    try std.testing.expectEqual(VaultAction.unlock_with_passphrase, decideVaultAction(true, false));
    try std.testing.expectEqual(VaultAction.create_new, decideVaultAction(false, false));
}

test "vault helper flag only matches as the sole argument" {
    const flag = "--sync-vault-unlock";
    try std.testing.expect(commandLineIsExactly("\"C:\\Program Files\\mp\\zigshell.exe\" --sync-vault-unlock", flag));
    try std.testing.expect(commandLineIsExactly("zigshell.exe --sync-vault-unlock ", flag));
    try std.testing.expect(!commandLineIsExactly("\"C:\\mp\\zigshell.exe\" \"multiprompt://x/--sync-vault-unlock\"", flag));
    try std.testing.expect(!commandLineIsExactly("\"C:\\mp\\zigshell.exe\" multiprompt://auth/callback?x=--sync-vault-unlock", flag));
    try std.testing.expect(!commandLineIsExactly("\"C:\\mp\\zigshell.exe\" --sync-vault-unlock extra", flag));
    try std.testing.expect(!commandLineIsExactly("\"C:\\mp\\zigshell.exe\"", flag));
}
