const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const names = ['busy-send', 'idle-suggestion', 'steer-chord', 'wrapped-leftover'];
const agentBoundary = 'stand-in remote shell + fake tmux + scripted agent screen, not real Claude or a real server';

function evaluateDelivery(observation, events) {
  assert.equal(observation.error, null, observation.error || 'driver error');
  assert.ok(names.includes(observation.name));
  assert.equal(observation.composerText, observation.text, 'real composer text');
  assert.ok(Number.isSafeInteger(observation.actionMs) && observation.actionMs > 0);
  assert.ok(observation.endMs >= observation.actionMs + 15000, 'full observation window');
  const wrapped = observation.name === 'wrapped-leftover';
  if (wrapped) {
    assert.ok(events.length > 0, 'box keys reached fake tmux');
    assert.ok(events.every(event => event.argv[0] === 'send-keys' && Object.hasOwn(event, 'submitted')), 'stateful box rows');
    const submitted = events.filter(event => event.submitted !== null).map(event => event.submitted);
    assert.deepEqual(submitted, [observation.text], 'exactly one submission equal to the typed composer text, no leftover glued in');
  } else {
    const expected = [
      ['send-keys', '-t', '=verify-agent:', '-l', '--', observation.text],
      ['send-keys', '-t', '=verify-agent:', 'Enter'],
    ];
    if (observation.name === 'steer-chord') expected.push(['send-keys', '-t', '=verify-agent:', 'C-x', 'C-s']);
    assert.deepEqual(events.map(event => event.argv), expected, 'exact text, Enter and optional trailing native steer chord, with no extras');
  }
  let previous = observation.actionMs;
  for (const event of events) {
    assert.equal(event.case, observation.name);
    assert.ok(Number.isSafeInteger(event.ms) && event.ms >= previous, 'timestamped ordered buffer writes');
    assert.ok(event.ms <= observation.actionMs + 15000, 'delivery within 15 seconds');
    previous = event.ms;
  }
  return { text: observation.text, elapsedMs: events.at(-1).ms - observation.actionMs, writes: events.length };
}

function evaluateEvidence(root) {
  const json = file => JSON.parse(fs.readFileSync(path.join(root, file), 'utf8').replace(/^\uFEFF/, ''));
  const lines = file => fs.existsSync(path.join(root, file))
    ? fs.readFileSync(path.join(root, file), 'utf8').replace(/^\uFEFF/, '').trim().split(/\r?\n/).filter(Boolean).map(line => JSON.parse(line)) : [];
  const png = file => {
    const bytes = fs.readFileSync(path.join(root, file));
    assert.equal(bytes.subarray(0, 8).toString('hex'), '89504e470d0a1a0a');
    assert.ok(bytes.length > 10000, 'nonempty desktop screenshot');
  };
  const cases = names.map(name => {
    try {
      const observation = json(`${name}/observation.json`);
      assert.equal(observation.name, name);
      const measured = evaluateDelivery(observation, lines(`${name}/stand-in/agent-buffer.jsonl`));
      const state = json(`${name}/stand-in/state.json`);
      assert.equal(state.name, name);
      assert.equal(state.mode, name === 'idle-suggestion' ? 'idle' : 'busy');
      assert.equal(state.suggestion, observation.suggestion);
      assert.equal(state.leftover, name === 'wrapped-leftover' ? observation.leftover : undefined);
      const ready = json(`${name}/stand-in/ready.json`);
      const consoles = lines(`${name}/stand-in/console.jsonl`);
      assert.ok(consoles.length > 0);
      assert.ok(consoles.every(row => row.screen === ready.screen && row.session === 'verify-agent'));
      assert.ok(consoles.every(row => JSON.stringify(row.rows) === JSON.stringify(ready.screen.trimEnd().split('\n').map(line => line.trimEnd()))), 'actual console character readback');
      if (name === 'wrapped-leftover') {
        assert.ok(state.leftover.length > 60 && state.leftover.length < 90 && !state.leftover.includes('\n'), 'single long line wrapping into three rows');
        const rows = [0, 30, 60].map(start => state.leftover.slice(start, start + 30));
        assert.ok(ready.screen.includes(`\u276f ${rows[0]}\n  ${rows[1]}\n  ${rows[2]}\n  \n\u2500`), 'leftover wrapped into three rows plus trailing line break');
      }
      if (state.mode === 'busy') assert.match(ready.screen, /esc to interrupt/);
      else {
        assert.ok(state.suggestion.length > 0 && !observation.text.includes(state.suggestion));
        assert.ok(ready.screen.includes(`\u276f ${state.suggestion}\n`), 'nonblank suggested prompt');
        assert.ok(consoles.every(row => row.greySuggestion === true && row.suggestionAttribute === 8));
        assert.doesNotMatch(ready.screen, /esc to interrupt/);
      }
      const captures = lines(`${name}/stand-in/capture.jsonl`);
      assert.ok(captures.length > 0, 'production reader inspected fake tmux screen');
      if (name === 'wrapped-leftover') {
        assert.equal(captures[0].screen, ready.screen, 'first capture is the seeded leftover box');
        assert.ok(captures.every(row => row.case === name && row.screen.startsWith('Claude Code\n\n') && /\n\u276f [^\n]*\n(?:  [^\n]*\n)*\u2500+\n$/.test(row.screen)), 'captures render the stateful box like Claude');
      } else assert.ok(captures.every(row => row.screen === ready.screen && row.case === name));
      const invocations = lines(`${name}/stand-in/invocations.jsonl`);
      assert.ok(invocations.some(row => row.kind === 'attach' && row.session === 'verify-agent'));
      assert.ok(invocations.some(row => row.kind === 'reader' && row.argv.join(' ') === "python3 -u -c import base64,sys;exec(base64.b64decode(sys.stdin.buffer.readline())) --serve"), 'app-supplied persistent reader bootstrap');
      assert.equal(lines(`${name}/stand-in/unsupported.jsonl`).length, 0, 'no silently unsupported boundary operations');
      const doctor = json(`${name}/doctor.json`);
      const build = json('build.json');
      assert.equal(doctor.version, build.version);
      assert.equal(doctor.sha256.toLowerCase(), build.sha256.toLowerCase());
      assert.ok(doctor.pid > 0 && doctor.hwnd > 0 && doctor.composer > 0 && doctor.chat && doctor.tmux);
      assert.deepEqual(doctor.focus, [doctor.hwnd, doctor.composer]);
      const actions = json('actions.json').filter(action => action.case === name);
      assert.deepEqual(actions.map(action => action.input), [
        'Ctrl+1: select saved tmux tab', 'Alt+C: open Chat View', 'type composer text',
        ...(name === 'steer-chord' ? ['Ctrl+X: steer prefix', 'Ctrl+S: steer send'] : ['Enter: send composer']),
      ]);
      assert.equal(actions[2].text, observation.text);
      const saved = json(`${name}/session-chat.json`);
      assert.equal(saved.active_tab, 0);
      assert.equal(saved.tabs.length, 1);
      assert.equal(saved.tabs[0].kind, 'tmux');
      assert.equal(saved.tabs[0].tmux_session, 'verify-agent');
      assert.equal(saved.tabs[0].cv, true);
      const cleanup = json(`${name}/cleanup.json`);
      assert.equal(cleanup.remaining_owned_processes, 0);
      assert.equal(cleanup.evidence_preserved, true);
      assert.equal(cleanup.scratch_removed, true);
      assert.equal(json(`${name}/process-tree.json`).ActiveProcesses, 0);
      assert.ok(fs.readFileSync(path.join(root, name, 'debug.log'), 'utf8').length > 0);
      for (const suffix of ['before', 'action', 'after', 'final']) png(`${name}-${suffix}.png`);
      png('before.png');
      png('after.png');
      return { name, passed: true, detail: measured };
    } catch (error) {
      return { name, passed: false, detail: error.message };
    }
  });
  return { feature: 'chat-delivery', status: cases.every(row => row.passed) ? 'passed' : 'failed', agentBoundary, cases };
}

if (require.main === module) {
  const root = process.argv[2];
  assert.ok(root, 'usage: node tools/verify-chat-delivery/check-evidence.js EVIDENCE');
  const result = evaluateEvidence(root);
  fs.writeFileSync(path.join(root, 'result.json'), JSON.stringify(result, null, 2) + '\n');
  for (const row of result.cases) console.log(`${row.passed ? 'PASS' : 'FAIL'} ${row.name}: ${JSON.stringify(row.detail)}`);
  process.exitCode = result.status === 'passed' ? 0 : 1;
}

module.exports = { names, agentBoundary, evaluateDelivery, evaluateEvidence };
