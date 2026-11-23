import { test } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, writeFileSync, readFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { run } from './mb.mjs';
import { validTabState } from '../service/tab-state.js';

const fixture = JSON.parse(readFileSync(new URL('./fixtures/SOFT-3141/pc-state.json', import.meta.url)));
const verbs = ['open', 'close', 'move', 'pin', 'unpin', 'archive', 'unarchive', 'wait', 'restore'];

for (const verb of verbs) {
  test(`${verb} uses the installed desktop bridge without an account key`, async t => {
    const dir = mkdtempSync(join(tmpdir(), 'tab-verbs-'));
    t.after(() => rmSync(dir, { recursive: true, force: true }));
    const statePath = join(dir, 'pc-state.json');
    const state = structuredClone(fixture);
    if (['open', 'restore'].includes(verb)) state.tabs[0].closed = true;
    if (verb === 'unpin') state.tabs[0].pinned = true;
    if (verb === 'unarchive') state.tabs[0].archived = true;
    writeFileSync(statePath, JSON.stringify(state));
    const fake = fileURLToPath(new URL('./fixtures/SOFT-3141/desktop.py', import.meta.url));
    writeFileSync(join(dir, 'zsb'), `#!/bin/sh\nexec python3 '${fake}' "$@"\n`, { mode: 0o755 });
    const call = async (mode = 'applied', json = true) => {
      const lines = [], errors = [];
      const args = [verb, 'Fixture', ...(verb === 'move' ? ['--workspace', 'Home', '--position', '0'] : []), ...(json ? ['--json'] : [])];
      const code = await run(args, {
        env: { HOME: dir, PATH: `${dir}:${process.env.PATH}`, MP_TAB_STATE_FILE: statePath, MP_TAB_STATE_MODE: mode },
        out: line => lines.push(line), err: line => errors.push(line),
        fetch() { assert.fail('tab verbs must not write the account service'); },
        tmux() { assert.fail('tab verbs must not edit local tmux sessions'); }
      });
      return { code, lines, errors };
    };
    for (const mode of ['refused', 'offline', 'ignored']) {
      const before = readFileSync(statePath, 'utf8');
      const result = await call(mode);
      assert.notEqual(result.code, 0, `${mode}: ${result.lines} ${result.errors}`);
      assert.equal(readFileSync(statePath, 'utf8'), before);
      assert.equal(result.lines.length + result.errors.length, 1);
    }
    const applied = await call();
    assert.equal(applied.code, 0, applied.errors.join('\n'));
    assert.equal(applied.lines.length, 1);
    const report = JSON.parse(applied.lines[0]);
    assert.equal(report.ok, true);
    const after = readFileSync(statePath, 'utf8');
    const again = await call();
    assert.equal(again.code, 0, again.errors.join('\n'));
    assert.equal(JSON.parse(again.lines[0]).changed, false);
    assert.equal(readFileSync(statePath, 'utf8'), after);
    const plain = await call('applied', false);
    assert.deepEqual(plain.lines, [`${verb} Fixture`]);
    assert.equal(report.state.host, fixture.tabs[0].host);
    assert.equal(report.state.workspace, verb === 'move' ? 'Home' : fixture.tabs[0].workspace);
  });
}

test('account layouts accept the same model and reject divergent identity', () => {
  const state = fixture.tabs[0];
  const tab = { name: state.name, tmux_session: state.tmux, workspace: state.workspace };
  assert.equal(validTabState(state, tab), true);
  assert.equal(validTabState({ ...state, tmux: 'another' }, tab), false);
  assert.equal(validTabState({ ...state, waiting: true, archived: true }, tab), false);
  assert.equal(validTabState({ ...state, chat_id: 101 }, tab), true);
  assert.equal(validTabState({ ...state, chat_id: Number.MAX_SAFE_INTEGER + 1 }, tab), false);
});
