import { test } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, writeFileSync, readFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { run } from './mb.mjs';

const LISTING = {
  ok: true,
  hosts: ['remote-1', 'remote-2', 'remote-3'],
  workspaces: [
    { name: 'Home', groups: [], tabs: [{ id: 41, title: 'Home shell', host: 'remote-1', tmux: 'home-1', pinned: false }] },
    {
      name: 'Work',
      groups: [{ name: 'Ops', tabs: [{ id: 42, title: 'Fixture', host: 'remote-2', tmux: 'fixture-7', pinned: false }] }],
      tabs: []
    },
    {
      name: 'Twins',
      groups: [],
      tabs: [
        { id: 43, title: 'Twin', host: 'remote-1', tmux: 'twin-a', pinned: false },
        { id: 44, title: 'Twin', host: 'remote-2', tmux: 'twin-b', pinned: false }
      ]
    }
  ]
};

const ZSB = `#!/usr/bin/env python3
import json, os, sys
state_path = os.environ['MB_TEST_STATE']
log_path = os.environ['MB_TEST_LOG']
state = json.load(open(state_path))
args = sys.argv[1:]
with open(log_path, 'a') as log:
    log.write(' '.join(args) + '\\n')
def tabs():
    for workspace in state['workspaces']:
        for tab in workspace['tabs']:
            yield tab
        for group in workspace['groups']:
            for tab in group['tabs']:
                yield tab
if args == ['workspace-list']:
    print(json.dumps(state))
    sys.exit(0)
if args[0] in ('session-pin', 'session-unpin') and len(args) == 3 and args[1] == '--tab':
    want = args[0] == 'session-pin'
    for tab in tabs():
        if str(tab['id']) == args[2]:
            tab['pinned'] = want
            json.dump(state, open(state_path, 'w'), sort_keys=True)
            print(json.dumps({'ok': True, 'pinned': want, 'tab': int(args[2])}))
            sys.exit(0)
    print(json.dumps({'ok': False, 'error': 'unknown_tab'}))
    sys.exit(1)
print(json.dumps({'ok': False, 'error': 'bad_args', 'message': 'unexpected ' + ' '.join(args)}))
sys.exit(2)
`;

function harness() {
  const dir = mkdtempSync(join(tmpdir(), 'mb-pin-'));
  const statePath = join(dir, 'state.json');
  const logPath = join(dir, 'calls.log');
  writeFileSync(statePath, JSON.stringify(LISTING));
  writeFileSync(logPath, '');
  const binary = join(dir, 'mp-zsb');
  writeFileSync(binary, ZSB, { mode: 0o755 });
  const calls = async argv => {
    const lines = [], errors = [];
    const env = { HOME: dir, PATH: process.env.PATH, MULTIPROMPT_ZSB: binary, MB_TEST_STATE: statePath, MB_TEST_LOG: logPath };
    const code = await run(argv, {
      env,
      out: line => lines.push(line),
      err: line => errors.push(line),
      fetch() { assert.fail('pin and unpin must not call the account service'); },
      tmux() { assert.fail('pin and unpin must not touch local tmux sessions'); }
    });
    return { code, lines, errors };
  };
  const bridge = () => readFileSync(logPath, 'utf8').split('\n').filter(line => line && line !== 'workspace-list');
  return { dir, statePath, calls, bridge };
}

test('pin twice leaves one pin and reports the same result', async t => {
  const h = harness();
  t.after(() => rmSync(h.dir, { recursive: true, force: true }));
  const first = await h.calls(['pin', 'Fixture']);
  assert.equal(first.code, 0, first.errors.join('\n'));
  assert.deepEqual(first.lines, ['pinned Fixture']);
  const pinned = readFileSync(h.statePath, 'utf8');
  assert.equal(JSON.parse(pinned).workspaces[1].groups[0].tabs[0].pinned, true);
  const second = await h.calls(['pin', 'Fixture']);
  assert.equal(second.code, 0, second.errors.join('\n'));
  assert.deepEqual(second.lines, ['already pinned Fixture']);
  assert.equal(readFileSync(h.statePath, 'utf8'), pinned);
  assert.deepEqual(h.bridge(), ['session-pin --tab 42']);
  const json = await h.calls(['pin', 'Fixture', '--json']);
  assert.equal(json.code, 0, json.errors.join('\n'));
  assert.deepEqual(JSON.parse(json.lines[0]), { ok: true, verb: 'pin', changed: false, tab: 42, pinned: true });
});

test('unpin twice leaves the tab unpinned and reports the same result', async t => {
  const h = harness();
  t.after(() => rmSync(h.dir, { recursive: true, force: true }));
  assert.equal((await h.calls(['pin', 'fixture-7'])).code, 0);
  const first = await h.calls(['unpin', 'fixture-7']);
  assert.equal(first.code, 0, first.errors.join('\n'));
  assert.deepEqual(first.lines, ['unpinned Fixture']);
  const unpinned = readFileSync(h.statePath, 'utf8');
  assert.equal(JSON.parse(unpinned).workspaces[1].groups[0].tabs[0].pinned, false);
  const second = await h.calls(['unpin', 'Fixture']);
  assert.equal(second.code, 0, second.errors.join('\n'));
  assert.deepEqual(second.lines, ['already unpinned Fixture']);
  assert.equal(readFileSync(h.statePath, 'utf8'), unpinned);
  assert.deepEqual(h.bridge(), ['session-pin --tab 42', 'session-unpin --tab 42']);
});

test('pin names its host when two tabs share a title and refuses an unknown tab', async t => {
  const h = harness();
  t.after(() => rmSync(h.dir, { recursive: true, force: true }));
  const ambiguous = await h.calls(['pin', 'Twin']);
  assert.equal(ambiguous.code, 1);
  assert.match(ambiguous.errors[0], /more than one tab matches/);
  const unknown = await h.calls(['pin', 'Nowhere']);
  assert.equal(unknown.code, 1);
  assert.match(unknown.errors[0], /no tab named/);
  assert.deepEqual(h.bridge(), []);
  const hosted = await h.calls(['pin', 'Twin', '--host', '1']);
  assert.equal(hosted.code, 0, hosted.errors.join('\n'));
  assert.deepEqual(hosted.lines, ['pinned Twin']);
  const state = JSON.parse(readFileSync(h.statePath, 'utf8'));
  assert.equal(state.workspaces[2].tabs[0].pinned, false);
  assert.equal(state.workspaces[2].tabs[1].pinned, true);
  assert.deepEqual(h.bridge(), ['session-pin --tab 44']);
  const refused = await h.calls(['pin', 'Fixture', 'extra']);
  assert.equal(refused.code, 1);
  assert.match(refused.errors[0], /pin needs one tab name/);
});
