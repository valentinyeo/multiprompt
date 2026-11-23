const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const root = path.resolve(__dirname, '..');

function read(name) {
  return fs.readFileSync(path.join(root, 'src', name), 'utf8');
}

function mentionNote(sourceName, visible, context) {
  const ctx = context ? `\n\n${context}` : '';
  return `Valentin mentioned you in ${sourceName}. This message is for you. Context:\n\n${visible}${ctx}`;
}

function isMentionNote(text) {
  return text.startsWith('Valentin mentioned you in ');
}

function mentionTargets(text, sourceSession, live) {
  if (isMentionNote(text)) return [];
  const found = [];
  const pattern = /(^|[\t\r\n ])@([^{}\n\r]+?)\{([A-Za-z0-9_.:-]{1,64})\}/g;
  for (const match of text.matchAll(pattern)) {
    const session = match[3];
    if (!session.startsWith('live-') || session === sourceSession) continue;
    if (match[2].endsWith(' ') || match[2].length === 0) continue;
    const chat = live.find((row) => row.session === session);
    if (!chat || found.some((row) => row.session === session)) continue;
    found.push(chat);
  }
  return found;
}

function mentionSourceNote(names) {
  if (names.length === 0) return '';
  const listed = names.length === 1 ? names[0] : `${names.slice(0, -1).join(', ')} and ${names.at(-1)}`;
  const warn = names.length === 1 ? names[0] : names.join(' or ');
  return `(This line is addressed to ${listed} and was already delivered to ${names.length === 1 ? 'it' : 'them'}. Do not answer for ${warn} or relay it unless you are also asked.)`;
}

const live = [
  { name: 'Factory', session: 'live-factory', index: 0 },
  { name: 'Design Lead', session: 'live-design', index: 1 },
  { name: 'Notes', session: 'live-notes', index: 2 },
  { name: 'Term', session: 'term-main', index: 3 },
];

test('SOFT-2430 a live mention is delivered once and the note does not fan out', () => {
  const text = 'ask @Design Lead{live-design} and @Design Lead{live-design} and @Notes{live-notes} and @Factory{live-factory} and @Missing{live-missing} and @Term{term-main}';
  const targets = mentionTargets(text, 'live-factory', live);
  assert.deepEqual(targets.map((row) => row.session), ['live-design', 'live-notes']);
  assert.deepEqual(mentionTargets('ask @Design Lead', 'live-factory', live), []);
  assert.deepEqual(mentionTargets('mail user@example.com', 'live-factory', live), []);
  const visible = 'ask @Design Lead and @Notes and @Factory and @Missing and @Term';
  const note = mentionNote('Factory', visible, '');
  assert.equal(note, 'Valentin mentioned you in Factory. This message is for you. Context:\n\n' + visible);
  assert.equal(isMentionNote(note), true);
  assert.deepEqual(mentionTargets(`${note} @Notes{live-notes}`, 'live-factory', live), []);
  assert.equal(mentionNote('Say "hi"', 'hello', ''), 'Valentin mentioned you in Say "hi". This message is for you. Context:\n\nhello');
  const mention = read('chat_mention.zig');
  const send = read('chat_send.zig');
  assert.match(mention, /pub fn mentionTargets\(/);
  assert.match(mention, /pub fn isMentionNote\(/);
  assert.match(mention, /pub fn mentionNote\(/);
  assert.match(mention, /pub fn revealChatNames\(/);
  assert.match(mention, /pub fn composeWireText\(/);
  assert.match(mention, /pub fn trimWireNote\(/);
  assert.match(mention, /test "SOFT-2430 a bot reply shows the chat name instead of a raw mention token"/);
  assert.match(read('chat_transcript.zig'), /revealChatNames\(wide, len\)/);
  assert.doesNotMatch(mention, /mp-send read/);
  assert.match(mention, /test "SOFT-3084 mention framing separates typing chat from recipients"/);
  assert.match(send, /deliverMentions\(app_state\.active_shell, app_state\.g_chat_outbox\.items\[ei\]\.id, send_text\)/);
  assert.match(send, /fn deliverMentions\(/);
  assert.match(send, /chatEchoEnqueueForShell\(target\.index, note, \.queued\)/);
  assert.match(send, /mentionMarkDelivered\(message_id, session\)/);
  assert.match(send, /mention\.isMentionNote\(text\)/);
  assert.match(send, /composeWireText\(/);
});

test('SOFT-3084 typing chat wires a source note and recipient copy is framed', () => {
  const targets = mentionTargets('@X{live-x} question', 'live-a', [
    { name: 'X', session: 'live-x', index: 2 },
    { name: 'A', session: 'live-a', index: 0 },
  ]);
  assert.deepEqual(targets.map((row) => row.name), ['X']);
  const note = mentionNote('A', '@X question', 'user: context');
  assert.match(note, /This message is for you/);
  assert.match(note, /user: context/);
  const suffix = mentionSourceNote(['X']);
  assert.match(suffix, /addressed to X/);
  assert.match(suffix, /Do not answer for X/);
  const multi = mentionSourceNote(['X', 'Y']);
  assert.match(multi, /addressed to X and Y/);
  assert.match(multi, /Do not answer for X or Y/);
  assert.deepEqual(mentionTargets('@A{live-a}', 'live-a', live), []);
});