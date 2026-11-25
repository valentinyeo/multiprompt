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

function mentionFyiNote(sourceName, visible, context) {
  const ctx = context ? `\n\n${context}` : '';
  return `Valentin mentioned you in ${sourceName} (FYI only; read along, do not act unless asked). Context:\n\n${visible}${ctx}`;
}

function isMentionNote(text) {
  return text.startsWith('Valentin mentioned you in ');
}

const markerRe = /(^|[\t\r\n ])@([^{}\n\r]+?)\{([A-Za-z0-9_.:-]{1,64})\}/g;
const blockedBeforeFyi = new Set(['to', 'not', 'no', 'dont', "don't", 'never', 'please', 'pls', 'did', 'didnt', "didn't", 'should', 'could', 'would', 'will', 'can', 'might', 'must', 'may', 'a', 'an', 'the']);

function listSep(gap) {
  let t = gap.trim();
  if (!t) return true;
  if (t.startsWith(',')) {
    t = t.slice(1).trim();
    if (!t) return true;
  }
  return t === '&' || t.toLowerCase() === 'and';
}

function lineMarkers(line) {
  const spans = [];
  for (const match of line.matchAll(markerRe)) {
    if (match[2].endsWith(' ') || match[2].length === 0) continue;
    const start = match.index + match[1].length;
    spans.push({ start, end: match.index + match[0].length, session: match[3] });
  }
  return spans;
}

function classifyLineSpan(line, spans, idx) {
  const trimmedStart = line.replace(/^[ \t]+/, '');
  const lead = line.length - trimmedStart.length;
  if (!trimmedStart || trimmedStart.startsWith('>')) return null;
  const fyiLead = /^[(\[]?[ \t]*(?:fyi|cc)(?:[ \t]+(?:[:,–—-][ \t]*)?|[:,–—-][ \t]*)/i.exec(trimmedStart);
  if (fyiLead) {
    const startPos = lead + fyiLead[0].length;
    const first = spans.findIndex((s) => s.start === startPos);
    if (first >= 0) {
      let ok = first === idx;
      for (let k = first; !ok && k < idx; k++) {
        if (!listSep(line.slice(spans[k].end, spans[k + 1].start))) break;
        if (k + 1 === idx) ok = true;
      }
      if (ok) return 'fyi';
    }
  }
  const firstAddr = spans.findIndex((s) => s.start === lead);
  if (firstAddr >= 0) {
    let ok = firstAddr === idx;
    for (let k = firstAddr; !ok && k < idx; k++) {
      if (!listSep(line.slice(spans[k].end, spans[k + 1].start))) break;
      if (k + 1 === idx) ok = true;
    }
    if (ok) return 'address';
  }
  let endIdx = idx;
  while (endIdx + 1 < spans.length && listSep(line.slice(spans[endIdx].end, spans[endIdx + 1].start))) endIdx++;
  if (/^[ \t.!)\]]*$/.test(line.slice(spans[endIdx].end))) {
    let startIdx = idx;
    while (startIdx > 0 && listSep(line.slice(spans[startIdx - 1].end, spans[startIdx].start))) startIdx--;
    const before = line.slice(0, spans[startIdx].start).replace(/[ \t]+$/, '').replace(/[:,–—-]$/, '').replace(/[ \t]+$/, '');
    const m = /(^|[^A-Za-z0-9_'@])(fyi|cc)$/i.exec(before);
    if (m) {
      const pre = before.slice(0, m.index + m[1].length).replace(/[ \t]+$/, '');
      const word = /([A-Za-z0-9_']+)$/.exec(pre);
      if (!word || !blockedBeforeFyi.has(word[1].toLowerCase())) return 'fyi';
    }
  }
  return null;
}

function mentionDeliveries(text, sourceSession, live) {
  if (isMentionNote(text)) return [];
  const found = [];
  for (const line of text.split(/\r?\n/)) {
    const spans = lineMarkers(line);
    for (let i = 0; i < spans.length; i++) {
      const kind = classifyLineSpan(line, spans, i);
      if (!kind) continue;
      const session = spans[i].session;
      if (!session.startsWith('live-') || session === sourceSession) continue;
      const chat = live.find((row) => row.session === session);
      if (!chat) continue;
      const prior = found.find((row) => row.chat.session === session);
      if (prior) {
        if (kind === 'address') prior.kind = 'address';
      } else {
        found.push({ chat, kind });
      }
    }
  }
  return found;
}

function mentionTargets(text, sourceSession, live) {
  return mentionDeliveries(text, sourceSession, live).filter((row) => row.kind === 'address').map((row) => row.chat);
}

function mentionSourceNote(names) {
  if (names.length === 0) return '';
  const listed = names.length === 1 ? names[0] : `${names.slice(0, -1).join(', ')} and ${names.at(-1)}`;
  const warn = names.length === 1 ? names[0] : names.join(' or ');
  const copy = names.length === 1 ? 'its own copy' : 'their own copies';
  return `(Valentin wrote this to you. It also mentions ${listed}, which already got ${copy}. Answer it as your own message, but do not answer for ${warn} or relay it.)`;
}

const live = [
  { name: 'Factory', session: 'live-factory', index: 0 },
  { name: 'Design Lead', session: 'live-design', index: 1 },
  { name: 'Notes', session: 'live-notes', index: 2 },
  { name: 'Term', session: 'term-main', index: 3 },
];

test('SOFT-2430 a live mention is delivered once and the note does not fan out', () => {
  const text = '@Design Lead{live-design} and @Design Lead{live-design} and @Notes{live-notes} and @Factory{live-factory} and @Missing{live-missing} and @Term{term-main} check this';
  const targets = mentionTargets(text, 'live-factory', live);
  assert.deepEqual(targets.map((row) => row.session), ['live-design', 'live-notes']);
  assert.deepEqual(mentionTargets('@Design Lead check this', 'live-factory', live), []);
  assert.deepEqual(mentionTargets('mail user@example.com', 'live-factory', live), []);
  const visible = '@Design Lead and @Notes and @Factory and @Missing and @Term check this';
  const note = mentionNote('Factory', visible, '');
  assert.equal(note, 'Valentin mentioned you in Factory. This message is for you. Context:\n\n' + visible);
  assert.equal(isMentionNote(note), true);
  assert.deepEqual(mentionTargets(`${note} @Notes{live-notes}`, 'live-factory', live), []);
  assert.equal(mentionNote('Say "hi"', 'hello', ''), 'Valentin mentioned you in Say "hi". This message is for you. Context:\n\nhello');
  const mention = read('chat_mention.zig');
  const send = read('chat_send.zig');
  assert.match(mention, /pub fn mentionDeliveries\(/);
  assert.match(mention, /pub fn mentionTargets\(/);
  assert.match(mention, /pub fn isMentionNote\(/);
  assert.match(mention, /pub fn mentionNote\(/);
  assert.match(mention, /pub fn mentionFyiNote\(/);
  assert.match(mention, /pub fn revealChatNames\(/);
  assert.match(mention, /pub fn composeWireText\(/);
  assert.match(mention, /pub fn trimWireNote\(/);
  assert.match(mention, /test "SOFT-2430 a bot reply shows the chat name instead of a raw mention token"/);
  assert.match(read('chat_transcript.zig'), /revealChatNames\(wide, len\)/);
  assert.doesNotMatch(mention, /mp-send read/);
  assert.match(mention, /test "SOFT-3084 mention framing separates typing chat from recipients"/);
  assert.match(mention, /test "MUBO-247 real mention shapes separate addressing, reference, fyi and unsure"/);
  assert.match(send, /deliverMentions\(app_state\.active_shell, app_state\.g_chat_outbox\.items\[ei\]\.id, send_text\)/);
  assert.match(send, /fn deliverMentions\(/);
  assert.match(send, /mention\.mentionDeliveries\(/);
  assert.match(send, /mention\.mentionFyiNote\(/);
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
  assert.equal(suffix, '(Valentin wrote this to you. It also mentions X, which already got its own copy. Answer it as your own message, but do not answer for X or relay it.)');
  assert.match(suffix, /Answer it as your own message/);
  assert.match(suffix, /do not answer for X or relay it/);
  const multi = mentionSourceNote(['X', 'Y']);
  assert.match(multi, /mentions X and Y/);
  assert.match(multi, /Answer it as your own message/);
  assert.match(multi, /do not answer for X or Y or relay it/);
  assert.deepEqual(mentionTargets('@A{live-a}', 'live-a', live), []);
});

test('MUBO-247 real mention shapes separate addressing, reference, fyi and unsure', () => {
  const fixtureRaw = fs.readFileSync(path.join(root, 'tools', 'fixtures', 'MUBO-247', 'cases.json'), 'utf8');
  assert.equal(fs.readFileSync(path.join(root, 'src', 'testdata', 'mubo-247-cases.json'), 'utf8'), fixtureRaw);
  const cases = JSON.parse(fixtureRaw);
  const chats = [
    { name: 'Current', session: 'live-current', index: 0 },
    { name: 'Builder', session: 'live-builder', index: 1 },
    { name: 'Reviewer', session: 'live-reviewer', index: 2 },
    { name: 'Maintainer', session: 'live-maintainer', index: 3 },
    { name: 'Cleaner', session: 'live-cleaner', index: 4 },
    { name: 'Reconciler', session: 'live-reconciler', index: 5 },
    { name: 'Router', session: 'live-router', index: 6 },
    { name: 'Ops', session: 'live-ops', index: 7 },
    { name: 'Verifier', session: 'live-verifier', index: 8 },
    { name: 'Mobile', session: 'live-mobile', index: 9 },
  ];
  assert.ok(cases.length >= 20);
  for (const item of cases) {
    const deliveries = mentionDeliveries(item.text, 'live-current', chats);
    const gotAddr = deliveries.filter((row) => row.kind === 'address').map((row) => row.chat.session);
    const gotFyi = deliveries.filter((row) => row.kind === 'fyi').map((row) => row.chat.session);
    assert.deepEqual(gotAddr, item.address, item.id);
    assert.deepEqual(gotFyi, item.fyi, item.id);
    assert.equal(gotAddr.length > 0, item.has_wire_note, item.id);
  }
  const fyiNote = mentionFyiNote('Current', 'FYI @Reviewer we switched branches', '');
  assert.equal(isMentionNote(fyiNote), true);
  assert.match(fyiNote, /FYI only; read along, do not act unless asked/);
  assert.deepEqual(mentionDeliveries(`${fyiNote}\n@Builder{live-builder} ping`, 'live-current', chats), []);
});
test('MUBO-454 the typing chat answers a line that mentions another chat', () => {
  const chats = [
    { name: 'A', session: 'live-a', index: 0 },
    { name: 'X', session: 'live-x', index: 1 },
    { name: 'Y', session: 'live-y', index: 2 },
  ];
  assert.deepEqual(mentionTargets('@X{live-x} ship it', 'live-a', chats).map((row) => row.session), ['live-x']);
  const suffix = mentionSourceNote(['X']);
  assert.match(suffix, /Valentin wrote this to you/);
  assert.match(suffix, /already got its own copy/);
  assert.match(suffix, /do not answer for X or relay it/);
  assert.match(mentionSourceNote(['X', 'Y']), /already got their own copies/);
  assert.deepEqual(mentionTargets('@A{live-a} note to me', 'live-a', chats), []);
  assert.equal(mentionNote('A', '@X ship it', ''), 'Valentin mentioned you in A. This message is for you. Context:\n\n@X ship it');
});
