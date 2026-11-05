const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');

const root = path.resolve(__dirname, '..');
const read = file => fs.readFileSync(path.join(root, 'src', file), 'utf8');
const extract = (source, start, end) => {
  const first = source.indexOf(start), last = source.indexOf(end, first + start.length);
  assert.ok(first >= 0 && last > first);
  return source.slice(first, last);
};

test('IGSH-1747 actual archive serialization and resume retain the original assistant', () => {
  const source = read('archive.zig');
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'archive-provider-'));
  try {
    for (const file of ['agent_host.zig', 'json_reader.zig', 'archive_rules.zig']) fs.copyFileSync(path.join(root, 'src', file), path.join(directory, file));
    fs.writeFileSync(path.join(directory, 'proof.zig'), `const std = @import("std");
const agent_host = @import("agent_host.zig");
const json_reader = @import("json_reader.zig");
${extract(read('app_state.zig'), 'pub const ArchivedEntry = struct {', 'pub var g_archived:')}
${extract(source, 'pub fn appendAsciiBuf(', 'fn getArchivePath(')}
${extract(read('workspaces.zig'), 'pub fn appendJsonEscaped(', 'fn lockWorkspaceRegistry(')}
${extract(source, 'fn archiveJsonCapacity(', 'test "archive JSON grows')}
${extract(source, 'fn buildClaudeResumePayload(', 'pub fn resurrectArchivedByKey(')}
test "archive providers round trip and legacy Claude stays readable" {
    const allocator = std.testing.allocator;
    for ([_]agent_host.Provider{ .claude, .codex, .pi }) |provider| {
        var entry = ArchivedEntry{};
        @memcpy(entry.tmux_session[0..7], "restore");
        entry.tmux_session_len = 7;
        @memcpy(entry.claude_sid[0..36], "ffffffff-ffff-4fff-bfff-ffffffffffff");
        entry.claude_sid_len = 36;
        @memcpy(entry.claude_cwd[0..11], "/work/proof");
        entry.claude_cwd_len = 11;
        if (@hasField(ArchivedEntry, "provider")) entry.provider = provider;
        var output: [2048]u8 = undefined;
        const length = serializeArchiveJson(&.{entry}, &output) orelse return error.TestUnexpectedResult;
        var document = try json_reader.parse(allocator, output[0..length]);
        defer document.deinit();
        const value = json_reader.array(document.value)[0];
        try std.testing.expectEqualStrings(provider.wire(), json_reader.string(json_reader.field(value, "provider")) orelse "missing");
        var parsed: std.ArrayList(ArchivedEntry) = .empty;
        defer parsed.deinit(allocator);
        try std.testing.expect(parseArchiveJson(allocator, output[0..length], &parsed));
        var command_buffer: [2048]u8 = undefined;
        const command = buildArchiveResurrectCommand(&parsed.items[0], &command_buffer) orelse return error.TestUnexpectedResult;
        if (provider == .claude) {
            try std.testing.expect(std.mem.indexOf(u8, command, "claude --resume") != null);
        } else {
            var expected_buffer: [80]u8 = undefined;
            const expected = try std.fmt.bufPrint(&expected_buffer, "host start {s} ffffffff-ffff-4fff-bfff-ffffffffffff", .{provider.wire()});
            try std.testing.expect(std.mem.indexOf(u8, command, expected) != null);
            try std.testing.expect(std.mem.indexOf(u8, command, "claude") == null);
        }
    }
    var legacy: std.ArrayList(ArchivedEntry) = .empty;
    defer legacy.deinit(allocator);
    try std.testing.expect(parseArchiveJson(allocator, "[{\\"tmux_session\\":\\"old-chat\\",\\"csid\\":\\"ffffffff-ffff-4fff-bfff-ffffffffffff\\"}]", &legacy));
    var buffer: [2048]u8 = undefined;
    const command = buildArchiveResurrectCommand(&legacy.items[0], &buffer) orelse return error.TestUnexpectedResult;
    try std.testing.expect(std.mem.indexOf(u8, command, "claude --resume") != null);
    std.debug.print("IGSH1747_ARCHIVE_PROVIDER_PROVEN\\n", .{});
}
`);
    const result = spawnSync(process.env.ZIG || 'zig', ['test', 'proof.zig'], { cwd: directory, encoding: 'utf8', timeout: 120000 });
    const output = (result.stdout || '') + (result.stderr || '');
    assert.equal(result.status, 0, output);
    assert.match(output, /IGSH1747_ARCHIVE_PROVIDER_PROVEN/);
    process.stdout.write(output);
  } finally {
    fs.rmSync(directory, { recursive: true, force: true });
  }
});
