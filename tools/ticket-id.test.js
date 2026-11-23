const assert = require('node:assert/strict');
const test = require('node:test');
const fs = require('node:fs');
const path = require('node:path');

function load() {
  assert.ok(fs.existsSync(path.join(__dirname, 'ticket-id.js')), 'the shared ticket parser exists');
  return require('./ticket-id.js');
}

test('SOFT and IGSH identify the same board ticket while HYCI stays distinct', () => {
  const { parseTicketId, canonicalTicketId, fragmentTicketId, ticketIds } = load();
  for (const id of ['SOFT-2489', 'IGSH-2489']) {
    assert.deepEqual(parseTicketId(id), { id: 'IGSH-2489', prefix: 'IGSH', number: '2489', boardId: 2060 });
    assert.equal(canonicalTicketId(id), 'IGSH-2489');
    assert.equal(fragmentTicketId(`changelog.d/${id}-x.md`), 'IGSH-2489');
  }
  assert.deepEqual(parseTicketId('HYCI-2489'), { id: 'HYCI-2489', prefix: 'HYCI', number: '2489', boardId: 11514 });
  assert.deepEqual(ticketIds('SOFT-2489, IGSH-2489 and HYCI-2489'), ['IGSH-2489', 'HYCI-2489']);
});

test('ticket parsing rejects malformed IDs and unsafe fragment names', () => {
  const { parseTicketId, canonicalTicketId, fragmentTicketId, ticketIds } = load();
  for (const id of [null, 2489, 'SOFT-0', 'SOFT-01', 'soft-2489', 'OTHER-2489', 'SOFT-2489x', ' SOFT-2489', 'SOFT-2489\n', '../SOFT-2489', 'constructor-2489']) {
    assert.equal(parseTicketId(id), null);
    assert.throws(() => canonicalTicketId(id), /Invalid ticket ID/);
  }
  for (const name of ['changelog.d/SOFT-2489.md', 'changelog.d/SOFT-2489-x/y.md', '../changelog.d/SOFT-2489-x.md']) {
    assert.throws(() => fragmentTicketId(name), /Bad fragment filename/);
  }
  assert.deepEqual(ticketIds('XSOFT-2489 SOFT-2489x foo-SOFT-2489 SOFT-0'), []);
});


test('MUBO-244 release fragments retain the Multiprompt board identity', () => {
  const { parseTicketId, canonicalTicketId, fragmentTicketId, ticketIds } = load();
  assert.deepEqual(parseTicketId('MUBO-244'), { id: 'MUBO-244', prefix: 'MUBO', number: '244', boardId: 13734 });
  assert.equal(canonicalTicketId('MUBO-244'), 'MUBO-244');
  assert.equal(fragmentTicketId('changelog.d/MUBO-244-photo-follows-chat.md'), 'MUBO-244');
  assert.deepEqual(ticketIds('MUBO-244 and SOFT-244'), ['MUBO-244', 'IGSH-244']);
});
