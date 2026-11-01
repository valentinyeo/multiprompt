const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const root = path.resolve(__dirname, '..');

const read = (file) => fs.readFileSync(path.join(root, file), 'utf8');

test('D1 the live model subscribes with a replay cursor on the existing channel', () => {
  const live = read('src/chat_live.zig');
  assert.match(live, /"events_subscribe"/);
  assert.ok(live.includes('provider\\":\\"claude'));
  assert.ok(live.includes('after\\":{d}'));
  assert.match(live, /"events_unsubscribe"/);
});

test('D1 every live kind the host sends reduces into the model', () => {
  const live = read('src/chat_live.zig');
  for (const kind of [
    'turn.started',
    'text.delta',
    'thinking.delta',
    'text.done',
    'thinking.done',
    'item.started',
    'item.done',
    'turn.ended',
    'host.status',
  ]) assert.ok(live.includes(`"${kind}"`), kind);
});

test('D1 a duplicate seq never moves the cursor and a delta replaces the text', () => {
  const live = read('src/chat_live.zig');
  assert.match(live, /if \(seq <= self\.after\) return false;/);
  assert.match(live, /self\.text\.clearRetainingCapacity\(\);\s*\n\s*try self\.text\.appendSlice\(a, value\[0\.\.@min\(value\.len, MAX_TEXT\)\]\);/);
});

test('D1 the live channel is opened only for a hosted agent chat and feeds the model', () => {
  const session = read('src/chat_session.zig');
  assert.match(session, /chatMessageGoesToHost\(shell\.kind, shell\.ai_agent\)/);
  assert.match(session, /chatLiveStreamEnsure\(key\)/);
  assert.match(session, /@import\("chat_live\.zig"\)\.subscribeLine\(/);
  assert.match(session, /@import\("chat_live\.zig"\)\.applyPage\(/);
});

test('D1 the live tail renders inside the same transcript buffer the view reads', () => {
  const session = read('src/chat_session.zig');
  assert.match(session, /var live_tail = @import\("chat_live\.zig"\)\.Tail\{\};\s*\n\s*if \(len < app_state\.g_chat_capture\.len\) live_tail = @import\("chat_live\.zig"\)\.tailFor\(shell_id, app_state\.g_chat_capture\[len\.\.\], len, live_blocks\[0\.\.live_room\]\);/);
  assert.match(session, /app_state\.g_chat_last_len = total;/);
  assert.match(session, /app_state\.g_chat_block_count \+= live_tail\.blocks;/);
});

test('D1 working dots follow the live turn through the working the bar already reads', () => {
  const session = read('src/chat_session.zig');
  assert.match(session, /const working = live\.running\(shell\.shell_id\);/);
  assert.match(session, /app_state\.g_chat_screen_working = working;/);
  assert.match(session, /shell\.working_since_ms = @import\("chat_working\.zig"\)\.workingSince\(shell\.working_since_ms, working, GetTickCount64\(\)\);/);
  const layout = read('src/window_layout.zig');
  assert.match(layout, /app_state\.g_chat_screen_working or app_state\.g_chat_screen_status_len > 0\);/);
});

test('D2 a live approval fills the existing permission card and clears when it resolves', () => {
  const session = read('src/chat_session.zig');
  assert.match(session, /live\.approvalMenu\(shell_id, &menu\)/);
  assert.match(session, /app_state\.g_chat_permission = menu;/);
  assert.match(session, /app_state\.g_chat_permission_sid = shell_id;/);
  assert.match(session, /live\.cardDismissed\(shell_id\)/);
});

test('D2 the three existing card buttons reply with the request id on the live channel', () => {
  const send = read('src/chat_send.zig');
  assert.match(send, /\.requestId\(shell_id, \.approval, &request\)/);
  assert.match(send, /approvalReplyLine\(/);
  assert.match(send, /\.decisionFor\(action\)/);
  assert.match(send, /chatLiveWrite\(/);
  const session = read('src/chat_session.zig');
  assert.match(session, /pub fn chatLiveWrite\(line: \[\]const u8\) bool/);
});

test('D2 escape on a live approval cancels it instead of typing into a pane', () => {
  const send = read('src/chat_send.zig');
  assert.match(send, /pub fn chatStopAgent\(shell_index: u32\) bool \{[\s\S]{0,200}if \(chatLiveCancelApproval\(shell_index\)\) return true;/);
  assert.match(send, /live\.approvalReplyLine\(std\.heap\.page_allocator, shell_id, std\.mem\.sliceTo\(&key\.sid, 0\), request\[0\.\.len\], \.cancel\)/);
});

test('D3 a live question shows the existing pills and answers one question at a time', () => {
  const session = read('src/chat_session.zig');
  assert.match(session, /live\.questionPrompt\(shell_id, &prompt\)/);
  assert.match(session, /entry\.history\.status\.question = prompt;/);
  const send = read('src/chat_send.zig');
  assert.match(send, /live\.answerQuestion\(shell_id, index, /);
  assert.match(send, /live\.questionAnswerLine\(shell_id, std\.heap\.page_allocator\)/);
  const render = read('src/chat_render.zig');
  assert.match(render, /chatChoiceDigitKey\(wp\)/);
});

test('D4 a plan cards the send button as implement or feedback for the open plan', () => {
  const send = read('src/chat_send.zig');
  assert.match(send, /fn chatLivePlanReply\(text: \[\]const u16\) bool \{/);
  assert.match(send, /std\.ascii\.eqlIgnoreCase\(value, "implement"\)/);
  assert.match(send, /\.plan, &request\)/);
  assert.match(send, /\.implement, null\)/);
  assert.match(send, /\.feedback, value\)/);
  assert.match(send, /if \(chatLivePlanReply\(text_buf\[0\.\.@intCast\(@max\(0, text_len_i\)\)\]\)\) return;/);
});

test('D5 stop on a live turn interrupts it and the turn ends interrupted', () => {
  const send = read('src/chat_send.zig');
  assert.match(send, /fn chatLiveInterrupt\(shell_index: u32\) bool \{/);
  assert.match(send, /if \(!live\.running\(shell_id\)\) return false;/);
  assert.match(send, /live\.interruptLine\(std\.heap\.page_allocator, shell_id/);
  assert.match(send, /if \(chatLiveCancelApproval\(shell_index\)\) return true;\s*\n\s*if \(chatLiveInterrupt\(shell_index\)\) return true;/);
  const live = read('src/chat_live.zig');
  assert.match(live, /std\.mem\.eql\(u8, kind, "turn\.ended"\)\) \{\s*\n(?:\s*self\.held = self\.state == \.running;\s*\n)?\s*self\.state = \.idle;\s*\n\s*self\.ended = statusOf\(strOf\(payload, "status"\)\);/);
});

test('D6 a single newline inside a paragraph is a line break, not a space', () => {
  const render = read('src/chat_render.zig');
  const rich = render.slice(render.indexOf('fn chatRichText('), render.indexOf('fn chatRichSize('));
  const branch = rich.slice(rich.indexOf("text[pos] == '\\n'"));
  assert.match(branch.slice(0, 400), /x = 0;\s*\n\s*y \+= line_h;/);
  assert.doesNotMatch(rich, /text\[pos\] == '\\n' or text\[pos\] == ' '/);
});
