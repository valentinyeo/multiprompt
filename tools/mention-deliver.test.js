const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const root = path.resolve(__dirname, '..');

function read(name) {
  return fs.readFileSync(path.join(root, 'src', name), 'utf8');
}

function readName(name) {
  return name.replace(/[\\"]/g, (ch) => `\\${ch}`);
}

function mentionNote(sourceName, visible) {
  const readAs = readName(sourceName);
  return `Valentin mentioned you in ${sourceName}: ${visible}. Answer his question first. Read that chat for context with mp-send read "${readAs}".`;
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
  const note = mentionNote('Factory', visible);
  assert.equal(note, 'Valentin mentioned you in Factory: ask @Design Lead and @Notes and @Factory and @Missing and @Term. Answer his question first. Read that chat for context with mp-send read "Factory".');
  assert.equal(isMentionNote(note), true);
  assert.deepEqual(mentionTargets(`${note} @Notes{live-notes}`, 'live-factory', live), []);
  assert.equal(mentionNote('Say "hi"', 'hello'), 'Valentin mentioned you in Say "hi": hello. Answer his question first. Read that chat for context with mp-send read "Say \\"hi\\"".');
  const mention = read('chat_mention.zig');
  const send = read('chat_send.zig');
  assert.match(mention, /pub fn mentionTargets\(/);
  assert.match(mention, /pub fn isMentionNote\(/);
  assert.match(mention, /pub fn mentionNote\(/);
  assert.match(mention, /Answer his question first\. Read that chat for context with mp-send read/);
  assert.match(mention, /test "SOFT-2430 a mention reaches that live chat once and the note does not fan out"/);
  assert.match(send, /deliverMentions\(app_state\.active_shell, app_state\.g_chat_outbox\.items\[ei\]\.id, send_text\)/);
  assert.match(send, /fn deliverMentions\(/);
  assert.match(send, /chatEchoEnqueueForShell\(target\.index, note, \.queued\)/);
  assert.match(send, /mentionMarkDelivered\(message_id, session\)/);
  assert.match(send, /mention\.isMentionNote\(text\)/);
});
