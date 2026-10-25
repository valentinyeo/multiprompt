const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const read = file => fs.readFileSync(path.join(__dirname, '..', file), 'utf8');

function anchorContract(source) {
  assert.match(source, /if \(marker == 0 or blocks.len == 0\) return \.\{\};/);
  assert.match(source, /block.message_id == marker\) last = i/);
  assert.match(source, /blocks\[read \+ 1 \.\.\]/);
  assert.match(source, /block.role != \.tool and block.first and block.message_id != marker/);
  assert.match(source, /return \.\{ \.index = i, \.unknown = true \}/);
}

test('IGSH-814 anchors on stable message identity and never guesses from offsets', () => {
  const history = read('src/chat_history.zig');
  const boundary = history.slice(history.indexOf('pub fn unreadBoundary'), history.indexOf('test "IGSH-814'));
  anchorContract(boundary);
  assert.doesNotMatch(boundary, /source_offset|stamp_ms|\.start/);
  assert.throws(() => anchorContract(boundary.replace('if (marker == 0 or blocks.len == 0) return .{};', '')));
  assert.throws(() => anchorContract(boundary.replace('block.message_id == marker', 'block.source_offset == marker')));
  assert.throws(() => anchorContract(boundary.replace('.unknown = true', '.unknown = false')));
  assert.match(history, /const message_id = if \(id.len == 0\) 0 else std.hash.Wyhash.hash\(std.hash.Wyhash.hash\(0, &self.sid\), id\)/);
  const reader = read('src/chat_history_reader.py');
  assert.match(reader, /text\["read_id"\] = f"\{stable_id\}:text:\{start\}" if stable_id else ""/);
  assert.doesNotMatch(reader, /text\["read_id"\] = f.*\{offset\}/);
  assert.match(history, /last_read_id.appendSlice\(a, m.read_id orelse m.id\)/);
  assert.match(reader, /if not result\["id"\] and result\["timestamp"\]:\s+result\["read_id"\] = "event:" \+ hashlib.sha256\(json.dumps\(event, sort_keys=True/);
  assert.match(history, /test "IGSH-814 ID-less Codex source records retain their saved read anchor"/);
});

test('IGSH-814 marker rides saved tabs, launch rows, reconnect and account cache reconciliation', () => {
  const session = read('src/session.zig');
  assert.match(session, /last_read_message_id\\":\\"\{d\}\\"/);
  assert.match(session, /app_state.shells\[idx\].last_read_message_id = tab.last_read_message_id/);
  assert.match(read('src/json_reader.zig'), /tab.last_read_message_id = uint\(obj, "last_read_message_id"\)/);
  assert.equal((read('src/app_state.zig').match(/last_read_message_id: u64 = 0/g) || []).length, 2);
  assert.match(read('src/launch_cache.zig'), /shell.last_read_message_id = row.last_read_message_id/);
  assert.match(read('src/launch_cache.zig'), /\.last_read_message_id = shell.last_read_message_id/);
  assert.match(read('src/launch_snapshot.zig'), /last_read_message_id: u64 = 0/);
  assert.match(read('src/console.zig'), /\.last_read_message_id = saved_read_message_id/);
  assert.match(read('src/account_layout.zig'), /test "IGSH-814 resync retains each matching chat read anchor"/);
  for (const name of ['saved read marker round trip restores each chat and legacy defaults', 'launch snapshot preserves the saved read anchor per chat', 'history gap never guesses from offsets and resync keeps the message anchor', 'all read and legacy chats never draw a divider']) {
    assert.ok([session, read('src/launch_snapshot.zig'), read('src/chat_history.zig')].some(source => source.includes(`test "IGSH-814 ${name}"`)));
  }
});

test('IGSH-814 leave, bottom and send lifecycle preserve anchors until live history is ready', () => {
  const model = read('src/chat_session.zig');
  assert.match(model, /!disk and !history.more\) app_state.g_chat_read_open_ready = true/);
  assert.match(model, /const restore_read = app_state.g_chat_read_open_pending and app_state.g_chat_read_open_ready/);
  assert.match(model, /!app_state.g_chat_active or app_state.g_chat_read_open_pending/);
  assert.match(model, /if \(!refreshed and !restore_read\) return/);
  assert.match(model, /restore_read or \(!app_state.g_chat_read_open_pending and !previous_boundary.unknown and app_state.g_chat_read_boundary.unknown\)/);
  assert.match(model, /read <= previous\.\?/);
  assert.match(read('src/chat_composer.zig'), /chatReadMark\(false\)/);
  assert.match(read('src/console.zig'), /if \(idx != prev\) _ = @import\("chat_session.zig"\).chatReadMark\(false\)/);
  assert.match(read('src/main.zig'), /chatReadMark\(false\);\s+logSessionAudit\("WM_CLOSE/);
  assert.match(read('src/chat_send.zig'), /g_chat_read_open_pending = false;\s+app_state.g_chat_read_open_ready = true;\s+_ = @import\("chat_session.zig"\).chatReadMark\(true\)/);
  const render = read('src/chat_render.zig');
  assert.match(render, /!app_state.g_chat_scrolled_up and @import\("chat_session.zig"\).chatReadMark\(true\)/);
  assert.match(render, /g_chat_new_messages.atBottom\(app_state.g_chat_scrolled_up\)/);
  assert.equal((render.match(/chatPaintReadDivider\(mem_dc, w\)/g) || []).length, 1);
  assert.match(render, /if \(boundary.index == null\) return/);
  assert.match(render, /if \(boundary.unknown\) \{\s+_ = chatDrawText\(hdc, L\("Earlier read position is unknown"\)/);
  assert.match(render, /test "IGSH-814 painter leaves all-read chats unchanged and paints one unread line"/);
  assert.match(render, /expectEqualSlices\(u8, before, pixels\)/);
  assert.match(render, /expect\(!std.mem.eql\(u8, before, pixels\)\)/);
});

test('IGSH-814 existing messages-only recipe exercises real reopen, restart, gap, bottom and send', () => {
  const driver = read('tools/verify-chat-delivery/drive.ps1');
  const press = driver.slice(driver.indexOf('function Press('), driver.indexOf('function Read-Shared('));
  assert.ok(press.indexOf("existing Alt+C debounce elapsed") < press.indexOf('    Doctor'), 'ownership is checked after the debounce, immediately before input');
  for (const phrase of ['leave the read chat', "Shell-Input 'messages' '2'", 'Restart-OwnedApp', 'reopen chat after offline arrivals', "Shell-Input 'forget-message' $readId", 'bottom clears the divider', 'sending clears the divider', 'all-read reopen has no divider']) assert.ok(driver.includes(phrase), phrase);
  assert.match(driver, /Copy-Item \$cache.FullName "\$caseDir\/app-cache-reopened.jsonl"/);
  assert.match(driver, /Copy-Item "\$settings\/session.json" "\$caseDir\/session-read-anchor.json"/);
  assert.match(driver, /Require-Divider 1 0 'one divider on reopen'/);
  assert.match(driver, /\$divider.offset -ne \$unreadOffset/);
  assert.match(read('.github/workflows/verify.yml'), /node --test tools\/chat-unread-divider.test.js/);
  const proof = read('tools/chat-messages-only-proof.mjs');
  assert.match(proof, /verifyUnreadDivider\(root\);/);
  assert.match(proof, /cache.slice\(read \+ 1\).find/);
  assert.match(proof, /dividerPixels\(image\('unread-divider-reopened'\).*1\)/);
  for (const file of ['.claude/skills/verify-multiprompt/features/chat-messages-only.md', 'openwiki/architecture/features.md']) assert.match(read(file), /IGSH-814/);
});

test('IGSH-814 pixel oracle rejects duplicate, misplaced and all-read dividers with a positive control', async () => {
  const { dividerPixels } = await import('./chat-messages-only-proof.mjs');
  const width = 400;
  const height = 200;
  const image = () => ({ width, height, pixels: Buffer.alloc(width * height * 4, 24) });
  const rect = { left: 0, top: 0, width, height };
  const rule = (frame, y) => {
    for (let x = 16; x < width - 16; x++) {
      if (x >= 176 && x < 224) continue;
      frame.pixels.writeUIntLE(0xa0a0a0, (y * width + x) * 4, 3);
    }
  };
  const blank = image();
  assert.equal(dividerPixels(blank, rect, 0, 0).rules, 0);
  const unread = image();
  rule(unread, 14);
  assert.equal(dividerPixels(unread, rect, 14, 1).rules, 1);
  assert.throws(() => dividerPixels(unread, rect, 0, 0), /expected number/);
  assert.throws(() => dividerPixels(unread, rect, 15, 1), /logged boundary/);
  rule(unread, 114);
  assert.throws(() => dividerPixels(unread, rect, 14, 1), /expected number/);
});
