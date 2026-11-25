import { test } from 'node:test';
import assert from 'node:assert/strict';
import { existsSync, mkdirSync, mkdtempSync, readdirSync, writeFileSync, readFileSync, rmSync, statSync } from 'node:fs';
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
        { id: 43, title: 'Alpha Chat', host: 'remote-1', tmux: 'live-alpha', chat: true, provider: 'claude', messages: 2 },
        { id: 44, title: 'Already Antigravity', host: 'remote-1', tmux: 'live-agy', chat: true, provider: 'antigravity', messages: 1 }
      ],
      groups: [
        {
          name: 'Ops',
          tabs: [
            { id: 45, title: 'Grouped Pi', host: 'remote-2', tmux: 'live-pi', chat: true, provider: 'pi', messages: 3 },
            { id: 46, title: 'Grouped Shell', host: 'remote-2', tmux: 'sh-2', chat: false, provider: null }
          ]
        }
      ]
    },
    {
      name: 'Other',
      groups: [],
      tabs: [
        { id: 50, title: 'Other Chat', host: 'remote-1', tmux: 'live-other', chat: true, provider: 'claude', messages: 1 }
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
def save():
    json.dump(state, open(state_path, 'w'), sort_keys=True)
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
    tab_id = int(args[2])
    target = args[4]
    for tab in tabs():
        if tab['id'] != tab_id:
            continue
        if not tab.get('chat'):
            print(json.dumps({'ok': False, 'error': 'not_chat_tab'}))
            sys.exit(1)
        if tab.get('provider') == target:
            print(json.dumps({'ok': True, 'status': 'already', 'tab': tab_id, 'provider': target}))
            sys.exit(0)
        if tab.get('overlap') and tab.get('busy_replies', 0) > 0:
            tab['messages'] = tab.get('messages', 0) + 1
            save()
        if tab.get('busy_replies', 0) > 0:
            tab['busy_replies'] -= 1
            save()
            print(json.dumps({'ok': True, 'status': 'busy', 'reason': 'chat_busy', 'message': 'Wait for the current reply first', 'tab': tab_id, 'provider': tab.get('provider')}))
            sys.exit(0)
        if tab.get('refuse'):
            print(json.dumps({'ok': True, 'status': 'refused', 'reason': tab['refuse'], 'tab': tab_id, 'provider': tab.get('provider')}))
            sys.exit(0)
        if tab.get('fail_once'):
            tab['fail_once'] = False
            save()
            print(json.dumps({'ok': True, 'status': 'failed', 'reason': 'the new AI could not start', 'tab': tab_id, 'provider': tab.get('provider')}))
            sys.exit(0)
        if tab.get('fail_every'):
            print(json.dumps({'ok': True, 'status': 'failed', 'reason': 'the new AI could not start', 'tab': tab_id, 'provider': tab.get('provider')}))
            sys.exit(0)
        tab['provider'] = target
        tab['sid'] = 'new-' + str(tab_id) + '-' + target
        model = {'codex': 'gpt-6.1-sol', 'claude': 'opus'}.get(target)
        if model:
            tab['model'] = model
        save()
        reply = {'ok': True, 'status': 'switched', 'tab': tab_id, 'provider': target, 'sid': tab['sid']}
        if model:
            reply['model'] = model
        print(json.dumps(reply))
        sys.exit(0)
    print(json.dumps({'ok': False, 'error': 'unknown_tab'}))
    sys.exit(1)
print(json.dumps({'ok': False, 'error': 'bad_args', 'message': 'unexpected ' + ' '.join(args)}))
sys.exit(2)
`;

function harness(listing = LISTING, extraEnv = {}, extraOverrides = {}) {
  const dir = mkdtempSync(join(tmpdir(), 'mb-ws-switch-ai-'));
  const statePath = join(dir, 'state.json');
  const logPath = join(dir, 'calls.log');
  writeFileSync(statePath, JSON.stringify(listing));
  writeFileSync(logPath, '');
  const binary = join(dir, 'mp-zsb');
  writeFileSync(binary, ZSB, { mode: 0o755 });
  const calls = async (argv, callEnv = {}, callOverrides = {}) => {
    const lines = [], errors = [];
    const env = { HOME: dir, PATH: process.env.PATH, MULTIPROMPT_ZSB: binary, MB_TEST_STATE: statePath, MB_TEST_LOG: logPath, ...extraEnv, ...callEnv };
    const code = await run(argv, {
      env,
      delay: async () => {},
      out: line => lines.push(line),
      err: line => errors.push(line),
      fetch() { assert.fail('workspace switch-ai must not call the account service'); },
      tmux() { assert.fail('workspace switch-ai must not touch local tmux sessions'); },
      ...extraOverrides,
      ...callOverrides
    });
    return { code, lines, errors };
  };
  const bridge = () => readFileSync(logPath, 'utf8').split('\n').filter(line => line && line !== 'workspace-list');
  const state = () => JSON.parse(readFileSync(statePath, 'utf8'));
  const providersPath = join(dir, '.local/state/multiprompt/agent-providers.json');
  const providers = () => JSON.parse(readFileSync(providersPath, 'utf8'));
  return { dir, statePath, providersPath, calls, bridge, state, providers };
}

test('workspace switch-ai moves every agent chat in the workspace, ignores shells and workers, leaves other workspaces alone, and is idempotent', async t => {
  const h = harness();
  t.after(() => rmSync(h.dir, { recursive: true, force: true }));
  const first = await h.calls(['workspace', 'switch-ai', 'Work', 'antigravity']);
  assert.equal(first.code, 0, first.errors.join('\n'));
  assert.deepEqual(first.lines, [
    'switching 2 of 3 chats in Work to antigravity (1 already there), one at a time',
    'switched Alpha Chat -> antigravity',
    'already Already Antigravity (antigravity)',
    'switched Grouped Pi -> antigravity',
    'workspace Work: 2 switched, 1 already, 0 busy, 0 refused, 0 failed'
  ]);
  assert.deepEqual(h.bridge(), [
    'session-switch-ai --tab 43 --to antigravity',
    'session-switch-ai --tab 45 --to antigravity'
  ]);
  const afterFirst = readFileSync(h.statePath, 'utf8');
  const parsed = JSON.parse(afterFirst);
  assert.equal(parsed.workspaces[1].tabs[0].provider, 'claude');
  assert.equal(parsed.workspaces[0].groups[0].tabs[0].provider, 'antigravity');
  assert.equal(parsed.workspaces[0].tabs[0].provider, null);
  assert.equal(parsed.workspaces[0].tabs[0].chat, false);

  const second = await h.calls(['workspace', 'switch-ai', 'Work', 'antigravity']);
  assert.equal(second.code, 0, second.errors.join('\n'));
  assert.deepEqual(second.lines, [
    'switching 0 of 3 chats in Work to antigravity (3 already there), one at a time',
    'already Alpha Chat (antigravity)',
    'already Already Antigravity (antigravity)',
    'already Grouped Pi (antigravity)',
    'workspace Work: 0 switched, 3 already, 0 busy, 0 refused, 0 failed'
  ]);
  assert.equal(readFileSync(h.statePath, 'utf8'), afterFirst);
  assert.deepEqual(h.bridge(), [
    'session-switch-ai --tab 43 --to antigravity',
    'session-switch-ai --tab 45 --to antigravity'
  ]);
});

test('workspace switch-ai waits for a busy chat to go idle and then switches it without losing the reply', async t => {
  const listing = structuredClone(LISTING);
  listing.workspaces[0].tabs[2].busy_replies = 2;
  const h = harness(listing);
  t.after(() => rmSync(h.dir, { recursive: true, force: true }));
  const result = await h.calls(['workspace', 'switch-ai', 'Work', 'antigravity']);
  assert.equal(result.code, 0, result.errors.join('\n'));
  assert.deepEqual(result.lines, [
    'switching 2 of 3 chats in Work to antigravity (1 already there), one at a time',
    'switched Alpha Chat -> antigravity',
    'already Already Antigravity (antigravity)',
    'switched Grouped Pi -> antigravity',
    'workspace Work: 2 switched, 1 already, 0 busy, 0 refused, 0 failed'
  ]);
  assert.deepEqual(h.bridge(), [
    'session-switch-ai --tab 43 --to antigravity',
    'session-switch-ai --tab 43 --to antigravity',
    'session-switch-ai --tab 43 --to antigravity',
    'session-switch-ai --tab 45 --to antigravity'
  ]);
  assert.equal(h.state().workspaces[0].tabs[2].messages, 2);
  assert.equal(h.state().workspaces[0].tabs[2].provider, 'antigravity');
});

test('workspace switch-ai reports a chat still busy when the wait runs out and never claims success', async t => {
  const listing = structuredClone(LISTING);
  listing.workspaces[0].tabs[2].busy_replies = 99;
  const h = harness(listing);
  t.after(() => rmSync(h.dir, { recursive: true, force: true }));
  const result = await h.calls(['workspace', 'switch-ai', 'Work', 'antigravity', '--timeout', '0']);
  assert.equal(result.code, 1, result.errors.join('\n'));
  assert.deepEqual(result.lines, [
    'switching 2 of 3 chats in Work to antigravity (1 already there), one at a time',
    'still busy Alpha Chat: Wait for the current reply first',
    'already Already Antigravity (antigravity)',
    'switched Grouped Pi -> antigravity',
    'workspace Work: 1 switched, 1 already, 1 busy, 0 refused, 0 failed',
    'workspace switch incomplete: 1 chat not on antigravity'
  ]);
  const saved = h.state();
  assert.equal(saved.workspaces[0].tabs[2].provider, 'claude');
  assert.equal(saved.workspaces[0].tabs[2].messages, 2);
  const json = await h.calls(['workspace', 'switch-ai', 'Work', 'antigravity', '--timeout', '0', '--json']);
  assert.equal(json.code, 1, json.errors.join('\n'));
  const body = JSON.parse(json.lines[0]);
  assert.equal(body.ok, false);
  assert.equal(body.status, 'incomplete');
  assert.equal(body.busy, 1);
  assert.equal(body.already, 2);
  assert.equal(body.chats[0].outcome, 'busy');
  assert.equal(body.chats[0].reason, 'Wait for the current reply first');
});

test('workspace switch-ai retries after an idle chat takes a new send and never reports a switch it did not get', async t => {
  const listing = structuredClone(LISTING);
  listing.workspaces[0].tabs[2].busy_replies = 1;
  listing.workspaces[0].tabs[2].overlap = true;
  const h = harness(listing);
  t.after(() => rmSync(h.dir, { recursive: true, force: true }));
  const result = await h.calls(['workspace', 'switch-ai', 'Work', 'antigravity']);
  assert.equal(result.code, 0, result.errors.join('\n'));
  assert.match(result.lines[0], /^switching 2 of 3 chats in Work to antigravity/);
  assert.ok(result.lines.includes('switched Alpha Chat -> antigravity'), result.lines.join('\n'));
  assert.ok(!result.lines.some(line => line.includes('refused') || line.includes('failed')), result.lines.join('\n'));
  const saved = h.state();
  assert.equal(saved.workspaces[0].tabs[2].provider, 'antigravity');
  assert.equal(saved.workspaces[0].tabs[2].messages, 3);
  assert.deepEqual(h.bridge().filter(line => line.startsWith('session-switch-ai --tab 43')), [
    'session-switch-ai --tab 43 --to antigravity',
    'session-switch-ai --tab 43 --to antigravity'
  ]);
});

test('workspace switch-ai reports a refused target with the host reason and exits nonzero', async t => {
  const listing = structuredClone(LISTING);
  listing.workspaces[0].tabs[3].provider = 'codex';
  listing.workspaces[0].tabs[3].refuse = 'unsupported_provider';
  listing.workspaces[0].groups[0].tabs[0].refuse = 'unsupported_provider';
  const h = harness(listing);
  t.after(() => rmSync(h.dir, { recursive: true, force: true }));
  const blocked = await h.calls(['workspace', 'switch-ai', 'Work', 'antigravity']);
  assert.equal(blocked.code, 1);
  assert.deepEqual(blocked.lines, [
    'switching 3 of 3 chats in Work to antigravity, one at a time',
    'switched Alpha Chat -> antigravity',
    'refused Already Antigravity: unsupported_provider',
    'refused Grouped Pi: unsupported_provider',
    'workspace Work: 1 switched, 0 already, 0 busy, 2 refused, 0 failed'
  ]);
  assert.equal(h.state().workspaces[0].tabs[3].provider, 'codex');
  assert.equal(h.state().workspaces[0].groups[0].tabs[0].provider, 'pi');
  const json = await h.calls(['workspace', 'switch-ai', 'Work', 'antigravity', '--json']);
  assert.equal(json.code, 1);
  const body = JSON.parse(json.lines[0]);
  assert.equal(body.ok, false);
  assert.equal(body.refused, 2);
  assert.equal(body.chats[2].reason, 'unsupported_provider');
});

test('workspace switch-ai leaves a chat on its old AI when the switch start fails, and a later run retries it', async t => {
  const listing = structuredClone(LISTING);
  listing.workspaces[0].tabs[2].fail_once = true;
  const h = harness(listing);
  t.after(() => rmSync(h.dir, { recursive: true, force: true }));
  const failed = await h.calls(['workspace', 'switch-ai', 'Work', 'antigravity']);
  assert.equal(failed.code, 1);
  assert.deepEqual(failed.lines, [
    'switching 2 of 3 chats in Work to antigravity (1 already there), one at a time',
    'failed Alpha Chat: the new AI could not start',
    'already Already Antigravity (antigravity)',
    'switched Grouped Pi -> antigravity',
    'workspace Work: 1 switched, 1 already, 0 busy, 0 refused, 1 failed'
  ]);
  const broken = h.state();
  assert.equal(broken.workspaces[0].tabs[2].provider, 'claude');
  assert.equal(broken.workspaces[0].tabs[2].messages, 2);
  assert.deepEqual(h.bridge(), [
    'session-switch-ai --tab 43 --to antigravity',
    'session-switch-ai --tab 45 --to antigravity'
  ]);
  const retried = await h.calls(['workspace', 'switch-ai', 'Work', 'antigravity']);
  assert.equal(retried.code, 0, retried.errors.join('\n'));
  assert.ok(retried.lines.includes('switched Alpha Chat -> antigravity'), retried.lines.join('\n'));
  assert.equal(h.state().workspaces[0].tabs[2].provider, 'antigravity');
  assert.equal(h.state().workspaces[0].tabs[2].messages, 2);
});

test('workspace switch-ai refuses an unknown workspace and a second run while one is in progress', async t => {
  const h = harness();
  t.after(() => rmSync(h.dir, { recursive: true, force: true }));
  const unknown = await h.calls(['workspace', 'switch-ai', 'Nowhere', 'antigravity']);
  assert.equal(unknown.code, 1);
  assert.match(unknown.errors[0], /no workspace named 'Nowhere'/);
  const badAi = await h.calls(['workspace', 'switch-ai', 'Work', 'grok']);
  assert.equal(badAi.code, 1);
  assert.match(badAi.errors[0], /target AI must be claude, codex or antigravity/);
  const missingArg = await h.calls(['workspace', 'switch-ai', 'Work']);
  assert.equal(missingArg.code, 1);
  assert.match(missingArg.errors[0], /workspace switch-ai needs/);
  const badTimeout = await h.calls(['workspace', 'switch-ai', 'Work', 'antigravity', '--timeout', 'soon']);
  assert.equal(badTimeout.code, 1);
  assert.match(badTimeout.errors[0], /--timeout must be whole seconds/);
  assert.deepEqual(h.bridge(), []);

  const lockPath = join(h.dir, '.local/state/multiprompt/switch-ai.lock');
  mkdirSync(join(h.dir, '.local/state/multiprompt'), { recursive: true });
  writeFileSync(lockPath, 'other', { flag: 'wx', mode: 0o600 });
  const busy = await h.calls(['workspace', 'switch-ai', 'Work', 'antigravity']);
  assert.equal(busy.code, 1);
  assert.match(busy.errors[0], /another workspace switch-ai is already running/);
  assert.deepEqual(h.bridge(), []);
  rmSync(lockPath);
  const released = await h.calls(['workspace', 'switch-ai', 'Work', 'antigravity']);
  assert.equal(released.code, 0, released.errors.join('\n'));
  assert.equal(existsSync(lockPath), false);
});

test('workspace switch-ai rewrites agent-providers.json atomically after each switch with every agent chat on that server and accurate counts', async t => {
  const listing = {
    ok: true,
    hosts: ['remote-1', 'remote-2', 'remote-3'],
    workspaces: [
      {
        name: 'HT Product',
        tabs: [
          { id: 10, title: 'Plain Shell', host: 'remote-1', tmux: 'sh-1', chat: false, provider: null },
          { id: 11, title: 'Worker Run', host: 'remote-1', tmux: 'wrk-1', chat: true, worker: true, provider: 'codex' },
          { id: 12, title: 'HT Bugs', host: 'remote-1', tmux: 'live-bugs', chat: true, provider: 'claude', messages: 2 },
          { id: 13, title: 'HT Design', host: 'remote-1', tmux: 'live-design', chat: true, provider: 'antigravity', messages: 1 },
          { id: 14, title: 'Remote Two Chat', host: 'remote-2', tmux: 'live-r2', chat: true, provider: 'claude', messages: 1 }
        ],
        groups: [
          {
            name: 'Infra',
            tabs: [
              { id: 15, title: 'HT Ops', host: 'remote-1', tmux: 'live-ops', chat: true, provider: 'pi', fail_once: true, messages: 1 }
            ]
          }
        ]
      },
      {
        name: 'Other Server Space',
        groups: [],
        tabs: [
          { id: 20, title: 'HT Support', host: 'remote-1', tmux: 'live-support', chat: true, provider: 'codex', model: 'sol', messages: 1 },
          { id: 21, title: 'HT OpenCode', host: 'remote-1', tmux: 'live-oc', chat: true, provider: 'opencode', model: 'glm-5', messages: 1 }
        ]
      }
    ]
  };
  let tick = 0;
  const times = [
    '2026-11-25T11:30:00.000Z',
    '2026-11-25T11:30:01.000Z',
    '2026-11-25T11:30:02.000Z',
    '2026-11-25T11:30:03.000Z',
    '2026-11-25T11:30:04.000Z'
  ];
  const now = () => new Date(times[Math.min(tick++, times.length - 1)]);
  const h = harness(listing, { MULTIPROMPT_HOST: '0' }, { now });
  t.after(() => rmSync(h.dir, { recursive: true, force: true }));

  const first = await h.calls(['workspace', 'switch-ai', 'HT Product', 'antigravity']);
  assert.equal(first.code, 1);
  assert.equal(existsSync(h.providersPath), true);
  const stateDir = join(h.dir, '.local/state/multiprompt');
  assert.deepEqual(readdirSync(stateDir).filter(name => name.endsWith('.tmp')), []);
  assert.equal(statSync(h.providersPath).mode & 0o777, 0o600);

  const afterPartial = h.providers();
  assert.deepEqual(Object.keys(afterPartial), ['updated', 'chats', 'by_provider']);
  assert.match(afterPartial.updated, /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$/);
  assert.deepEqual(afterPartial.by_provider, { antigravity: 2, pi: 1, codex: 1, opencode: 1 });
  assert.equal(afterPartial.chats.length, 5);
  for (const entry of afterPartial.chats) {
    assert.deepEqual(Object.keys(entry), ['workspace', 'chat', 'tmux', 'provider', 'model', 'since']);
    assert.match(entry.since, /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$/);
  }
  assert.ok(!afterPartial.chats.some(item => item.tmux === 'sh-1' || item.tmux === 'wrk-1' || item.tmux === 'live-r2'));
  const bugs = afterPartial.chats.find(item => item.tmux === 'live-bugs');
  assert.equal(bugs.workspace, 'HT Product');
  assert.equal(bugs.chat, 'HT Bugs');
  assert.equal(bugs.provider, 'antigravity');
  assert.equal(bugs.model, 'gemini-4-neon');
  const support = afterPartial.chats.find(item => item.tmux === 'live-support');
  assert.equal(support.workspace, 'Other Server Space');
  assert.equal(support.provider, 'codex');
  assert.equal(support.model, 'gpt-6.1-sol');

  const second = await h.calls(['workspace', 'switch-ai', 'HT Product', 'codex']);
  assert.equal(second.code, 0, second.errors.join('\n'));
  const afterCodex = h.providers();
  assert.deepEqual(afterCodex.by_provider, { codex: 4, opencode: 1 });
  const bugsCodex = afterCodex.chats.find(item => item.tmux === 'live-bugs');
  assert.equal(bugsCodex.provider, 'codex');
  assert.equal(bugsCodex.model, 'gpt-6.1-sol');
});

test('agents providers --write rebuilds agent-providers.json idempotently, preserves since, filters by server slot, and supports offline host fallback', async t => {
  const listing = {
    ok: true,
    hosts: ['remote-1', 'remote-2', 'remote-3'],
    workspaces: [
      {
        name: 'HT Product',
        tabs: [
          { id: 31, title: 'HT Bugs', host: 'remote-1', tmux: 'live-bugs', chat: true, provider: 'agy' },
          { id: 32, title: 'HT Shell', host: 'remote-1', tmux: 'sh-1', chat: false, provider: null },
          { id: 33, title: 'HT Second', host: 'remote-2', tmux: 'live-second', chat: true, provider: 'claude' }
        ],
        groups: []
      },
      {
        name: 'Personal',
        tabs: [
          { id: 34, title: 'My Claude', host: 'remote-1', tmux: 'live-claude', chat: true, provider: 'claude' },
          { id: 35, title: 'My Codex', host: 'remote-1', tmux: 'live-codex', chat: true, provider: 'codex' }
        ],
        groups: []
      }
    ]
  };
  const h = harness(listing);
  t.after(() => rmSync(h.dir, { recursive: true, force: true }));

  const serversPath = join(h.dir, 'servers.json');
  writeFileSync(serversPath, JSON.stringify({ servers: [{ id: 's1', hostname: 'box-one', multiprompt_slot: 0 }] }));
  const hostDir = join(h.dir, '.local/state/multiprompt/agent-host');
  mkdirSync(hostDir, { recursive: true });
  writeFileSync(join(hostDir, 'codex-1.config.json'), JSON.stringify({ enabled: true, provider: 'codex', tmux: 'live-codex', model: 'sol' }));
  writeFileSync(join(hostDir, 'headless.config.json'), JSON.stringify({ enabled: true, provider: 'claude', tmux: 'live-worker', spawn_mode: 'headless' }));
  writeFileSync(join(hostDir, 'old.config.json'), JSON.stringify({ enabled: false, provider: 'claude', tmux: 'live-old', switched_to: { provider: 'codex', sid: 'x' } }));

  const dry = await h.calls(['agents', 'providers', '--json'], { MULTIPROMPT_SERVERS_FILE: serversPath }, { hostname: () => 'box-one', now: () => new Date('2026-11-25T10:00:00.000Z') });
  assert.equal(dry.code, 0, dry.errors.join('\n'));
  assert.equal(existsSync(h.providersPath), false);
  const dryBody = JSON.parse(dry.lines[0]);
  assert.deepEqual(dryBody.by_provider, { antigravity: 1, claude: 1, codex: 1 });
  assert.equal(dryBody.chats.find(item => item.tmux === 'live-bugs').provider, 'antigravity');
  assert.equal(dryBody.chats.find(item => item.tmux === 'live-codex').model, 'gpt-6.1-sol');

  const firstWrite = await h.calls(['agents', 'providers', '--write'], { MULTIPROMPT_SERVERS_FILE: serversPath }, { hostname: () => 'box-one', now: () => new Date('2026-11-25T10:00:00.000Z') });
  assert.equal(firstWrite.code, 0, firstWrite.errors.join('\n'));
  assert.match(firstWrite.lines[0], /^wrote .* \(3 chats: antigravity=1, claude=1, codex=1\)$/);
  const snap1 = h.providers();
  assert.equal(snap1.updated, '2026-11-25T10:00:00.000Z');
  assert.equal(snap1.chats.find(item => item.tmux === 'live-bugs').since, '2026-11-25T10:00:00.000Z');

  const secondWrite = await h.calls(['agents', 'providers', '--write', '--json'], { MULTIPROMPT_SERVERS_FILE: serversPath }, { hostname: () => 'box-one', now: () => new Date('2026-11-26T10:00:00.000Z') });
  assert.equal(secondWrite.code, 0, secondWrite.errors.join('\n'));
  const snap2 = h.providers();
  assert.equal(snap2.updated, '2026-11-26T10:00:00.000Z');
  assert.deepEqual(snap2.chats, snap1.chats);
  assert.deepEqual(snap2.by_provider, snap1.by_provider);

  const brokenZsb = join(h.dir, 'broken-zsb');
  writeFileSync(brokenZsb, '#!/bin/sh\nexit 1\n', { mode: 0o755 });
  const offline = await h.calls(['agents', 'providers', '--write', '--json'], { MULTIPROMPT_ZSB: brokenZsb }, { now: () => new Date('2026-11-26T12:00:00.000Z') });
  assert.equal(offline.code, 0, offline.errors.join('\n'));
  const snapOffline = h.providers();
  assert.equal(snapOffline.updated, '2026-11-26T12:00:00.000Z');
  assert.deepEqual(snapOffline.by_provider, { codex: 1 });
  assert.equal(snapOffline.chats[0].workspace, 'Personal');
  assert.equal(snapOffline.chats[0].chat, 'My Codex');
  assert.equal(snapOffline.chats[0].tmux, 'live-codex');
  assert.equal(snapOffline.chats[0].model, 'gpt-6.1-sol');

  const badSub = await h.calls(['agents', 'nope']);
  assert.equal(badSub.code, 1);
  assert.match(badSub.errors[0], /agents needs providers/);
});
