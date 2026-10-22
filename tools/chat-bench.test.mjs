import test from 'node:test';
import assert from 'node:assert/strict';
import { capacity, defaults, evaluate, isOutsideKill } from './chat-bench/lib.mjs';

const run = (errors = [], infra = []) => ({ samples: [], switches: [], fixtures: { tabs: [] }, appends: [], readerResponses: [], restarted: false, errors, infra });
const kill = 'app 0 killed by SIGKILL from outside the bench (server capacity)';
const memory = 'MemTotal: 16777216 kB\nMemAvailable: 8388608 kB\n';

test('outside SIGKILL is INFRA, not a build failure or pass', () => {
  const verdict = evaluate(run([kill], [kill]), defaults);
  assert.equal(verdict.status, 'INFRA'); assert.equal(verdict.pass, false);
  assert.equal(verdict.failures.filter(f => f === kill).length, 1);
  assert(evaluate(run([], [kill]), defaults).failures.includes(kill));
});

test('ordinary crashes remain FAIL', () => {
  const crash = 'app 0 exited unexpectedly: 1/null', verdict = evaluate(run([crash]), defaults);
  assert.equal(verdict.status, 'FAIL'); assert.equal(verdict.pass, false);
  assert(verdict.failures.includes(crash));
});

test('capacity rejects overloaded servers and accepts available load and memory', () => {
  const busy = capacity('27.5 26 25 3/900 1', memory, 18, defaults);
  assert.equal(busy.ok, false); assert.match(busy.reason, /load/);
  assert.equal(busy.load, 27.5); assert.equal(busy.cores, 18); assert.equal(busy.memAvailableMiB, 8192);
  assert.equal(capacity('5.0 4 3 1/900 1', memory, 18, defaults).ok, true);
  assert.equal(capacity('18.0 4 3 1/900 1', memory, 18, defaults).ok, false);
});

test('capacity requires at least the configured available memory', () => {
  const low = capacity('5.0 4 3 1/900 1', 'MemAvailable: 1048576 kB\n', 18, defaults);
  assert.equal(low.ok, false); assert.match(low.reason, /memory/);
  assert.equal(capacity('5.0 4 3 1/900 1', 'MemAvailable: 4194304 kB\n', 18, defaults).ok, true);
});

test('only SIGKILL is an outside kill', () => {
  assert.equal(isOutsideKill('SIGKILL'), true); assert.equal(isOutsideKill('SIGTERM'), false); assert.equal(isOutsideKill(null), false);
});

test('a switch that leaves two browser panes on screen fails the bench', () => {
  const r = run();
  r.fixtures.tabs = [{ index: 0, browser: 'docked' }, { index: 1, browser: 'pending' }];
  const shot = { phase: 'cold', index: 0, geometry: { browser_foreign: true, browser_live: true }, geometryInside: true, headerInk: true, composerInk: true };
  const config = { ...defaults, browserTabs: true };
  r.switches = [{ ...shot, foreignBrowsersOnScreen: 2 }];
  assert(evaluate(r, config).failures.includes('cold tab 0: 2 browser panes on screen'));
  r.switches = [{ ...shot, foreignBrowsersOnScreen: 1 }];
  assert(!evaluate(r, config).failures.some(f => f.includes('browser panes on screen')));
  r.switches = [{ ...shot }];
  assert(evaluate(r, config).failures.includes('cold tab 0: browser panes on screen not counted'));
});
