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
    { name: 'Home', groups: [], tabs: [{ id: 41, title: 'Home shell', host: 'remote-1', tmux: 'home-1' }] },
    {
      name: 'Work',
      groups: [{ name: 'Ops', tabs: [{ id: 42, title: 'Fixture', host: 'remote-2', tmux: 'fixture-7' }] }],
      tabs: []
    },
    {
      name: 'Twins',
      groups: [],
      tabs: [
        { id: 43, title: 'Twin', host: 'remote-1', tmux: 'twin-a' },
        { id: 44, title: 'Twin', host: 'remote-2', tmux: 'twin-b' }
      ]
    }
  ],
  archived_sessions: []
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
            yield workspace, tab
        for group in workspace['groups']:
            for tab in group['tabs']:
                yield workspace, tab
def save():
    json.dump(state, open(state_path, 'w'), sort_keys=True)
if args == ['workspace-list']:
    print(json.dumps(state))
    sys.exit(0)
if args[0] == 'session-archive' and len(args) == 3 and args[1] == '--tab':
    for workspace, tab in tabs():
        if str(tab['id']) == args[2]:
            workspace['tabs'] = [item for item in workspace['tabs'] if item is not tab]
            for group in workspace['groups']:
                group['tabs'] = [item for item in group['tabs'] if item is not tab]
            state['archived_sessions'].append({'tmux': tab['tmux'], 'host': tab['host'], 'title': tab['title']})
            save()
            print(json.dumps({'ok': True, 'archived': True, 'tab': int(args[2])}))
            sys.exit(0)
    print(json.dumps({'ok': False, 'error': 'unknown_tab'}))
    sys.exit(1)
if args[0] == 'session-unarchive' and len(args) == 5 and args[1] == '--tmux' and args[3] == '--host':
    for entry in state['archived_sessions']:
        if entry['tmux'] == args[2] and entry['host'] == args[4]:
            state['archived_sessions'] = [item for item in state['archived_sessions'] if item is not entry]
            state['workspaces'][0]['tabs'].append({'id': 90 + len(state['workspaces'][0]['tabs']), 'title': entry['title'], 'host': entry['host'], 'tmux': entry['tmux']})
            save()
            print(json.dumps({'ok': True, 'unarchived': True, 'tmux': entry['tmux']}))
            sys.exit(0)
    print(json.dumps({'ok': False, 'error': 'unknown_archived_session'}))
    sys.exit(1)
print(json.dumps({'ok': False, 'error': 'bad_args', 'message': 'unexpected ' + ' '.join(args)}))
sys.exit(2)
`;

function harness() {
  const dir = mkdtempSync(join(tmpdir(), 'mb-archive-'));
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
      fetch() { assert.fail('archive and unarchive must not call the account service'); },
      tmux() { assert.fail('archive and unarchive must not touch local tmux sessions'); }
    });
    return { code, lines, errors };
  };
  const bridge = () => readFileSync(logPath, 'utf8').split('\n').filter(line => line && line !== 'workspace-list');
  return { dir, statePath, calls, bridge };
}

test('archive twice leaves one archived session and reports the same result', async t => {
  const h = harness();
  t.after(() => rmSync(h.dir, { recursive: true, force: true }));
  const first = await h.calls(['archive', 'Fixture']);
  assert.equal(first.code, 0, first.errors.join('\n'));
  assert.deepEqual(first.lines, ['archived Fixture']);
  const archived = readFileSync(h.statePath, 'utf8');
  assert.deepEqual(JSON.parse(archived).workspaces[1].groups[0].tabs, []);
  assert.deepEqual(JSON.parse(archived).archived_sessions, [{ tmux: 'fixture-7', host: 'remote-2', title: 'Fixture' }]);
  const second = await h.calls(['archive', 'Fixture']);
  assert.equal(second.code, 0, second.errors.join('\n'));
  assert.deepEqual(second.lines, ['already archived Fixture']);
  assert.equal(readFileSync(h.statePath, 'utf8'), archived);
  assert.deepEqual(h.bridge(), ['session-archive --tab 42']);
  const json = await h.calls(['archive', 'Fixture', '--json']);
  assert.equal(json.code, 0, json.errors.join('\n'));
  assert.deepEqual(JSON.parse(json.lines[0]), { ok: true, verb: 'archive', changed: false, title: 'Fixture' });
});

test('unarchive twice leaves the tab open and reports the same result', async t => {
  const h = harness();
  t.after(() => rmSync(h.dir, { recursive: true, force: true }));
  assert.equal((await h.calls(['archive', 'fixture-7'])).code, 0);
  const first = await h.calls(['unarchive', 'fixture-7']);
  assert.equal(first.code, 0, first.errors.join('\n'));
  assert.deepEqual(first.lines, ['unarchived Fixture']);
  const reopened = readFileSync(h.statePath, 'utf8');
  assert.deepEqual(JSON.parse(reopened).archived_sessions, []);
  assert.equal(JSON.parse(reopened).workspaces[0].tabs.length, 2);
  const second = await h.calls(['unarchive', 'Fixture']);
  assert.equal(second.code, 0, second.errors.join('\n'));
  assert.deepEqual(second.lines, ['already unarchived Fixture']);
  assert.equal(readFileSync(h.statePath, 'utf8'), reopened);
  assert.deepEqual(h.bridge(), ['session-archive --tab 42', 'session-unarchive --tmux fixture-7 --host remote-2']);
});

test('archive names its host when two tabs share a title and refuses an unknown tab', async t => {
  const h = harness();
  t.after(() => rmSync(h.dir, { recursive: true, force: true }));
  const ambiguous = await h.calls(['archive', 'Twin']);
  assert.equal(ambiguous.code, 1);
  assert.match(ambiguous.errors[0], /more than one tab matches/);
  const unknown = await h.calls(['archive', 'Nowhere']);
  assert.equal(unknown.code, 1);
  assert.match(unknown.errors[0], /no tab named/);
  const notArchived = await h.calls(['unarchive', 'Nowhere']);
  assert.equal(notArchived.code, 1);
  assert.match(notArchived.errors[0], /no tab named/);
  assert.deepEqual(h.bridge(), []);
  const hosted = await h.calls(['archive', 'Twin', '--host', '1']);
  assert.equal(hosted.code, 0, hosted.errors.join('\n'));
  assert.deepEqual(hosted.lines, ['archived Twin']);
  assert.deepEqual(JSON.parse(readFileSync(h.statePath, 'utf8')).archived_sessions, [{ tmux: 'twin-b', host: 'remote-2', title: 'Twin' }]);
  assert.deepEqual(h.bridge(), ['session-archive --tab 44']);
  const refused = await h.calls(['archive', 'Fixture', 'extra']);
  assert.equal(refused.code, 1);
  assert.match(refused.errors[0], /archive needs one tab name/);
});
