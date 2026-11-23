import { test } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';

const root = fileURLToPath(new URL('..', import.meta.url));
const read = file => readFileSync(join(root, file), 'utf8');
const FEATURES = 'favorite,muted,used,visits,input,settings,hosts,host_removal,workspace_color,bot_appearance,bot_photo,bot_palette8,groups';
const SID = '11111111-2222-4333-8444-555555555555';
const LIVE = 'live-11111111222243338444555555555555';

function body(source, name) {
  const start = source.indexOf(`fn ${name}(`);
  assert.ok(start >= 0, `${name} is missing`);
  return source.slice(start, source.indexOf('\n}', start) + 2);
}

function zig(dir, source) {
  writeFileSync(join(dir, 'chat_identity.zig'), read('src/chat_identity.zig'));
  writeFileSync(join(dir, 'one-tab.zig'), source);
  const result = spawnSync(process.env.ZIG || 'zig', ['test', 'one-tab.zig', '-j1'], { cwd: dir, encoding: 'utf8', timeout: 120000 });
  assert.equal(result.status, 0, `${result.stdout || ''}${result.stderr || ''}${result.error ? result.error.message : ''}`);
}

function scratch() {
  return mkdtempSync(join(tmpdir(), 'mubo-252-'));
}

const identity = read('src/chat_identity.zig');
const tmux = read('src/tmux_identity.zig');

test('MUBO-252 two tabs for one chat keep the original tab', () => {
  const dir = scratch();
  try {
    zig(dir, `
const std = @import("std");

${body(tmux, 'same')}
${body(tmux, 'sameChat')}
${body(tmux, 'restoreWinner')}

const Tab = struct {
    tmux_host: u8 = 0,
    tmux_session: []const u8 = "",
    tmux_session_len: usize = 0,
    claude_sid: [40]u8 = @splat(0),
    claude_sid_len: u32 = 0,
    last_viewed: u64 = 0,
    manual: bool = false,
};

fn withSid(sid: []const u8) [40]u8 {
    var value: [40]u8 = @splat(0);
    @memcpy(value[0..sid.len], sid);
    return value;
}

test "two tabs for one chat restore the original tab" {
    var tabs = [_]Tab{
        .{ .tmux_session = "${LIVE}", .tmux_session_len = ${LIVE.length}, .claude_sid = withSid("${SID}"), .claude_sid_len = 36, .last_viewed = 10 },
        .{ .tmux_session = "term-restore", .tmux_session_len = 12, .claude_sid = withSid("${SID}"), .claude_sid_len = 36, .last_viewed = 40 },
    };
    try std.testing.expectEqual(@as(usize, 0), restoreWinner(&tabs, 0));
    try std.testing.expectEqual(@as(usize, 0), restoreWinner(&tabs, 1));
    tabs[1].manual = true;
    try std.testing.expectEqual(@as(usize, 1), restoreWinner(&tabs, 0));
    try std.testing.expectEqual(@as(usize, 1), restoreWinner(&tabs, 1));
}

test "one tmux name is one chat and other chats stay separate" {
    const tabs = [_]Tab{
        .{ .tmux_session = "term-one", .tmux_session_len = 8 },
        .{ .tmux_session = "TERM-ONE", .tmux_session_len = 8, .last_viewed = 99 },
        .{ .tmux_session = "term-two", .tmux_session_len = 8 },
        .{ .tmux_host = 1, .tmux_session = "term-one", .tmux_session_len = 8 },
    };
    try std.testing.expectEqual(@as(usize, 1), restoreWinner(&tabs, 0));
    try std.testing.expectEqual(@as(usize, 2), restoreWinner(&tabs, 2));
    try std.testing.expectEqual(@as(usize, 3), restoreWinner(&tabs, 3));
}
`);
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

test('MUBO-252 the chat identity module is tested on its own', () => {
  const dir = scratch();
  try {
    writeFileSync(join(dir, 'chat_identity.zig'), identity);
    const result = spawnSync(process.env.ZIG || 'zig', ['test', 'chat_identity.zig', '-j1'], { cwd: dir, encoding: 'utf8', timeout: 120000 });
    assert.equal(result.status, 0, `${result.stdout || ''}${result.stderr || ''}${result.error ? result.error.message : ''}`);
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

test('MUBO-252 the saved session restore asks the chat winner first', () => {
  assert.match(read('src/session.zig'), /if \(tmux_identity\.restoreWinner\(tabs\[0\.\.tab_count\], t\) != t\) continue;/);
  assert.match(tmux, /if \(i == index or !sameChat\(tab, other\)\) continue;/);
});

test('MUBO-252 the account layout sync keeps the row already on screen', () => {
  const source = read('src/account_desktop.zig');
  assert.match(source, /if \(tmux_identity\.duplicateOfLocalChat\(app_state\.shells\[0\.\.app_state\.shell_count\], tab\.tmux_host, tab\.tmux_session\)\) continue;/);
});

test('MUBO-252 opening an already open chat writes nothing', async () => {
  const { run } = await import('./mb.mjs');
  const dir = scratch();
  const layout = { schema: 1, revision: 1, workspaces: [{ name: 'Work' }], tabs: [{ kind: 'tmux', name: 'Poteto', tmux_session: LIVE, tmux_host: 0, workspace: 'Work' }] };
  const puts = [];
  const out = [];
  const fetch = async (url, init = {}) => {
    const headers = { get: () => FEATURES };
    if ((init.method || 'GET') === 'PUT') {
      puts.push(JSON.parse(init.body));
      return { status: 200, headers, json: async () => ({ revision: 2, layout }) };
    }
    return { status: 200, headers, json: async () => ({ revision: 1, layout }) };
  };
  try {
    const code = await run(['open', '--kind', 'chat', '--title', 'Poteto', '--folder', '/work', '--workspace', 'Work', '--host', '0'], {
      env: { MULTIPROMPT_KEY: 'test-key', MULTIPROMPT_URL: 'https://account.test', HOME: dir },
      out: line => out.push(line),
      err: line => out.push(line),
      fetch
    });
    assert.deepEqual(puts, []);
    assert.equal(code, 0, out.join('\n'));
    assert.match(out.join('\n'), /already open/);
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});
