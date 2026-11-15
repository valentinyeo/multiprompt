const test = require('node:test');
const assert = require('node:assert/strict');
const { sessionLinks } = require('./session-link');

test('a reply containing Poteto{live-8bc7bac} yields a link span with the name and tmux target', () => {
  assert.deepEqual(sessionLinks('See Poteto{live-8bc7bac} now'), [{ name: 'Poteto', tmux: 'live-8bc7bac' }]);
});

test('the @ form and a name that ends in LC use the same token', () => {
  assert.deepEqual(sessionLinks('@Poteto 2 LC{live-8bc7bac}'), [{ name: 'Poteto 2 LC', tmux: 'live-8bc7bac' }]);
  assert.deepEqual(sessionLinks('Poteto{live-8bc7bac}'), [{ name: 'Poteto', tmux: 'live-8bc7bac' }]);
  assert.deepEqual(sessionLinks('Alpha Lead{live-alpha}'), [{ name: 'Alpha Lead', tmux: 'live-alpha' }]);
});

test('a brace that is not a session id stays out of the link spans', () => {
  assert.deepEqual(sessionLinks('config{debug} stays'), []);
});
