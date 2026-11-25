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
    {
      name: 'Work',
      tabs: [
        { id: 41, title: 'Plain Shell', host: 'remote-1', tmux: 'sh-1', chat: false, provider: null },
        { id: 42, title: 'Local CMD', host: null, tmux: null, chat: false, provider: null },
        { id: 43, title: 'Alpha Chat', host: 'remote-1', tmux: 'live-alpha', chat: true, provider: 'claude' },
        { id: 44, title: 'Already Codex', host: 'remote-1', tmux: 'live-codex', chat: true, provider: 'codex' }
      ],
      groups: [
        {
          name: 'Ops',
          tabs: [
            { id: 45, title: 'Grouped Pi', host: 'remote-2', tmux: 'live-pi', chat: true, provider: 'pi' },
            { id: 46, title: 'Grouped Shell', host: 'remote-2', tmux: 'sh-2', chat: false, provider: null }
          ]
        }
      ]
    },
    {
      name: 'Other',
      groups: [],
      tabs: [
        { id: 50, title: 'Other Chat', host: 'remote-1', tmux: 'live-other', chat: true, provider: 'claude' }
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
if args[0] == 'session-switch-ai' and len(args) == 5 and args[1] == '--tab' and args[3] == '--to':
    tab_id = args[2]
    target = args[4]
    for tab in tabs():
        if str(tab['id']) == tab_id:
            if not tab.get('chat'):
                print(json.dumps({'ok': False, 'error': 'not_chat_tab'}))
                sys.exit(1)
            if tab.get('provider') == target:
                print(json.dumps({'ok': True, 'status': 'already', 'tab': int(tab_id), 'provider': target}))
                sys.exit(0)
            if tab.get('test_busy'):
                print(json.dumps({'ok': True, 'status': 'busy', 'reason': 'Wait for the current reply first', 'tab': int(tab_id), 'provider': tab.get('provider')}))
                sys.exit(0)
            if tab.get('test_fail'):
                print(json.dumps({'ok': True, 'status': 'failed', 'reason': tab['test_fail'], 'tab': int(tab_id), 'provider': tab.get('provider')}))
                sys.exit(0)
            tab['provider'] = target
            new_sid = 'new-' + tab_id + '-' + target
            json.dump(state, open(state_path, 'w'), sort_keys=True)
            print(json.dumps({'ok': True, 'status': 'switched', 'tab': int(tab_id), 'provider': target, 'sid': new_sid}))
            sys.exit(0)
    print(json.dumps({'ok': False, 'error': 'unknown_tab'}))
    sys.exit(1)
print(json.dumps({'ok': False, 'error': 'bad_args', 'message': 'unexpected ' + ' '.join(args)}))
sys.exit(2)
`;

function harness(listing = LISTING) {
  const dir = mkdtempSync(join(tmpdir(), 'mb-ws-switch-ai-'));
  const statePath = join(dir, 'state.json');
  const logPath = join(dir, 'calls.log');
  writeFileSync(statePath, JSON.stringify(listing));
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
      fetch() { assert.fail('workspace switch-ai must not call the account service'); },
      tmux() { assert.fail('workspace switch-ai must not touch local tmux sessions'); }
    });
    return { code, lines, errors };
  };
  const bridge = () => readFileSync(logPath, 'utf8').split('\n').filter(line => line && line !== 'workspace-list');
  return { dir, statePath, calls, bridge };
}

test('workspace switch-ai switches every chat in the workspace, skips shells, leaves other workspaces alone, and is idempotent', async t => {
  const h = harness();
  t.after(() => rmSync(h.dir, { recursive: true, force: true }));
  const first = await h.calls(['workspace', 'switch-ai', 'Work', 'codex']);
  assert.equal(first.code, 0, first.errors.join('\n'));
  assert.deepEqual(first.lines, [
    'switched Alpha Chat -> codex',
    'already Already Codex (codex)',
    'switched Grouped Pi -> codex',
    'workspace Work: 2 switched, 1 already, 0 busy, 0 failed'
  ]);
  assert.deepEqual(h.bridge(), [
    'session-switch-ai --tab 43 --to codex',
    'session-switch-ai --tab 45 --to codex'
  ]);
  const afterFirst = readFileSync(h.statePath, 'utf8');
  const parsed = JSON.parse(afterFirst);
  assert.equal(parsed.workspaces[1].tabs[0].provider, 'claude');

  const second = await h.calls(['workspace', 'switch-ai', 'Work', 'codex']);
  assert.equal(second.code, 0, second.errors.join('\n'));
  assert.deepEqual(second.lines, [
    'already Alpha Chat (codex)',
    'already Already Codex (codex)',
    'already Grouped Pi (codex)',
    'workspace Work: 0 switched, 3 already, 0 busy, 0 failed'
  ]);
  assert.equal(readFileSync(h.statePath, 'utf8'), afterFirst);
  assert.deepEqual(h.bridge(), [
    'session-switch-ai --tab 43 --to codex',
    'session-switch-ai --tab 45 --to codex'
  ]);
});

test('workspace switch-ai skips busy chats with reason without interrupting them', async t => {
  const state = structuredClone(LISTING);
  state.workspaces[0].tabs[2].test_busy = true;
  const h = harness(state);
  t.after(() => rmSync(h.dir, { recursive: true, force: true }));
  const result = await h.calls(['workspace', 'switch-ai', 'Work', 'codex']);
  assert.equal(result.code, 0, result.errors.join('\n'));
  assert.deepEqual(result.lines, [
    'skipped Alpha Chat (busy: Wait for the current reply first)',
    'already Already Codex (codex)',
    'switched Grouped Pi -> codex',
    'workspace Work: 1 switched, 1 already, 1 busy, 0 failed'
  ]);
  const saved = JSON.parse(readFileSync(h.statePath, 'utf8'));
  assert.equal(saved.workspaces[0].tabs[2].provider, 'claude');
  assert.equal(saved.workspaces[0].groups[0].tabs[0].provider, 'codex');

  const json = await h.calls(['workspace', 'switch-ai', 'Work', 'codex', '--json']);
  assert.equal(json.code, 0, json.errors.join('\n'));
  const body = JSON.parse(json.lines[0]);
  assert.equal(body.ok, true);
  assert.equal(body.busy, 1);
  assert.equal(body.already, 2);
  assert.equal(body.ignored, 3);
  assert.equal(body.chats[0].outcome, 'busy');
  assert.equal(body.chats[0].reason, 'Wait for the current reply first');
});

test('workspace switch-ai exits nonzero when any chat fails while still processing the rest', async t => {
  const state = structuredClone(LISTING);
  state.workspaces[0].tabs[2].test_fail = 'the new AI could not start';
  const h = harness(state);
  t.after(() => rmSync(h.dir, { recursive: true, force: true }));
  const result = await h.calls(['workspace', 'switch-ai', 'Work', 'codex']);
  assert.equal(result.code, 1);
  assert.deepEqual(result.lines, [
    'failed Alpha Chat: the new AI could not start',
    'already Already Codex (codex)',
    'switched Grouped Pi -> codex',
    'workspace Work: 1 switched, 1 already, 0 busy, 1 failed'
  ]);
  const json = await h.calls(['workspace', 'switch-ai', 'Work', 'codex', '--json']);
  assert.equal(json.code, 1);
  const body = JSON.parse(json.lines[0]);
  assert.equal(body.ok, false);
  assert.equal(body.failed, 1);
  assert.equal(body.chats[0].outcome, 'failed');
  assert.equal(body.chats[0].reason, 'the new AI could not start');
});

test('workspace switch-ai refuses unknown workspaces and bad arguments before calling switch', async t => {
  const h = harness();
  t.after(() => rmSync(h.dir, { recursive: true, force: true }));
  const unknown = await h.calls(['workspace', 'switch-ai', 'Nowhere', 'codex']);
  assert.equal(unknown.code, 1);
  assert.match(unknown.errors[0], /no workspace named 'Nowhere'/);
  const badAi = await h.calls(['workspace', 'switch-ai', 'Work', 'grok']);
  assert.equal(badAi.code, 1);
  assert.match(badAi.errors[0], /target AI must be claude, codex or pi/);
  const missingArg = await h.calls(['workspace', 'switch-ai', 'Work']);
  assert.equal(missingArg.code, 1);
  assert.match(missingArg.errors[0], /workspace switch-ai needs/);
  assert.deepEqual(h.bridge(), []);
});
