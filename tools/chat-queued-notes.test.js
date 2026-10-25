const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const read = file => fs.readFileSync(path.join(__dirname, '..', 'src', file), 'utf8');
const transcript = read('chat_transcript.zig');
const sync = read('chat_shell_sync.zig');
const render = read('chat_render.zig');

function body(source, name) {
  const start = source.indexOf(`fn ${name}(`);
  assert.ok(start >= 0, name);
  const end = source.indexOf('\n}', start);
  assert.ok(end > start, name);
  return source.slice(start, end + 2);
}

function checkQueueParsing(source) {
  const fill = body(source, 'fillQueue');
  assert.match(fill, /items: \?\[\]const std\.json\.Value/);
  assert.match(fill, /utf8ToUtf16LeAlloc[\s\S]*injectedEnvelope\(wide, true\)/);
  assert.match(fill, /item\.injected = true/);
  assert.match(fill, /decodeXml\(injected\.sender, item\.sender/);
  assert.match(fill, /decodeXml\(injected\.body, &item\.text, true\)/);
  assert.match(fill, /object\.get\("text"\)/);
  assert.match(fill, /object\.get\("sender"\)/);
  assert.match(fill, /object\.get\("injected"\)/);
  assert.match(body(source, 'injectedMessage'), /injectedEnvelope\(raw, false\)/);
  assert.match(body(source, 'injectedEnvelope'), /orelse if \(allow_truncated\) text\.len else return null/);
}

function checkPendingIsolation(source) {
  const build = body(source, 'build');
  assert.match(build, /\.injected = item\.injected, \.sender = item\.sender/);
  assert.match(build, /if \(item\.injected or i >= MAX_ROWS or used\[i\]\) continue;/);
  assert.ok(build.indexOf('item.injected or') < build.indexOf('chat_echo.sameText'));
}

function checkIncomingPaint(source) {
  const paint = body(source, 'chatPaintShellRow');
  assert.match(paint, /row: \*const chat_shell_sync\.Row/);
  assert.match(paint, /if \(row\.injected\) chatInjectedBubbleColor\(\) else chatUserBubbleColor\(\)/);
  assert.match(paint, /if \(row\.injected\) chatPaintTime\(hdc, .*\.role = \.injected, \.sender = row\.sender/);
  assert.match(paint, /const sender_h = if \(row\.injected\) uiScaled\(CHAT_STATUS_H\) else @as\(i32, 0\);/);
  assert.match(paint, /rc\.bottom - status_h - sender_h/);
  assert.match(paint, /if \(row\.injected\) \{\s*area\.top \+= status_h;\s*area\.bottom \+= status_h;/);
  assert.match(paint, /Queued in Claude/);
  assert.match(body(source, 'chatShellRowsLayout'), /if \(row\.injected\) rc\.bottom \+= uiScaled\(CHAT_STATUS_H\)/);
  assert.match(source, /chatPaintShellRow\(mem_dc, &g_shell_view\.rows\[g_shell_rect_row\[i\]\], rc\)/);
}

test('IGSH-722 Zig queue source accepts reader notes and unwraps legacy envelopes before clipping', () => {
  checkQueueParsing(transcript);
});

test('IGSH-722 incoming queue notes cannot consume local outbox pending entries', () => {
  checkPendingIsolation(sync);
});

test('IGSH-722 queued incoming paint reuses injected color and sender with separate queue status', () => {
  checkIncomingPaint(render);
});

test('IGSH-722 source oracles reject raw clipping, local matching, and own-bubble regressions', () => {
  assert.throws(() => checkQueueParsing(transcript.replace('injectedEnvelope(wide, true)', 'injectedEnvelope(wide, false)')));
  assert.throws(() => checkPendingIsolation(sync.replace('item.injected or ', '')));
  assert.throws(() => checkIncomingPaint(render.replace('if (row.injected) chatInjectedBubbleColor() else chatUserBubbleColor()', 'chatUserBubbleColor()')));
  assert.throws(() => checkIncomingPaint(render.replace('.sender = row.sender', '.sender = @splat(0)')));
  assert.throws(() => checkIncomingPaint(render.replace('if (row.injected) rc.bottom += uiScaled(CHAT_STATUS_H);', '')));
});

test('IGSH-722 Zig regression cases cover long raw strings, decoded notes, tasks and pending isolation', () => {
  assert.match(transcript, /test "IGSH-722 long queued envelopes/);
  assert.match(transcript, /"x" \*\* 700/);
  assert.match(transcript, /prefix \+\+ opening \+\+ body\[0\.\.300\]/);
  assert.match(transcript, /w\("uds:"\), w\("hop-chain"\)/);
  assert.match(transcript, /test "IGSH-722 queue accepts decoded reader notes and legacy task and sender fallback"/);
  assert.match(sync, /test "IGSH-722 incoming queued and sent notes never consume matching local pending"/);
});
