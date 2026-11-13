import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

const palette = readFileSync(new URL('../src/command_palette.zig', import.meta.url), 'utf8');
const claude = readFileSync(new URL('../CLAUDE.md', import.meta.url), 'utf8');
const doc = readFileSync(new URL('../openwiki/operations/spawn-multibot-session.md', import.meta.url), 'utf8');
const usage = readFileSync(new URL('./mb.mjs', import.meta.url), 'utf8');

async function map() {
  try {
    return await import('./palette-verbs.mjs');
  } catch {
    assert.fail('palette verb map missing');
  }
}

test('every palette row has a verb or a screen-only place', async () => {
  const { verbs, screen, screenOnly, coverage } = await map();
  const result = coverage(palette);
  assert.deepEqual(result.missing, []);
  assert.deepEqual(result.both, []);
  assert.ok(result.ids.length > 150);
  for (const id of result.ids) {
    if (verbs[id]) assert.equal(screen[id], undefined);
    else assert.ok(screenOnly[screen[id]], id);
  }
});

test('a new palette row with no verb fails the check', async () => {
  const { coverage } = await map();
  const result = coverage(palette + '\napp_state.g_search_results[0] = SEARCH_NOT_A_REAL_OFFSET;\n');
  assert.deepEqual(result.missing, ['SEARCH_NOT_A_REAL_OFFSET']);
});

test('each verb is an mb command', async () => {
  const { verbs } = await map();
  for (const name of new Set(Object.values(verbs))) assert.match(usage, new RegExp('^  ' + name + ' ', 'm'));
});

test('the screen-only list is written next to the three-part rule', async () => {
  const { screenOnly } = await map();
  for (const line of Object.values(screenOnly)) {
    assert.ok(claude.includes(line), line);
    assert.ok(doc.includes(line), line);
  }
});
