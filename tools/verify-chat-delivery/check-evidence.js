const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const names = ['busy-send', 'idle-suggestion', 'steer-chord', 'wrapped-leftover'];
const queueName = 'queue-draft-sync';
const allNames = [...names, queueName];
const queueTexts = {
  a: 'shell queued alpha',
  b: 'chat queued beta',
  a2: 'shell queued alpha edited',
  shellDraft: 'shell draft gamma',
  chatDraft: 'chat draft delta',
  suggestion: 'Try asking about the next step',
};
const queueSteps = [
  'chat-view-read-transcript',
  'chat-lists-shell-queued',
  'chat-lists-both-in-order',
  'shell-lists-both-in-order',
  'queue-pulled-into-box',
  'chat-lists-edited-in-order',
  'shell-lists-edited-in-order',
  'chat-marks-both-sent',
  'shell-took-both',
  'suggestion-not-draft',
  'composer-shows-shell-draft',
  'composer-clears-with-shell',
  'shell-box-shows-chat-draft',
];
const agentBoundary = 'stand-in remote shell + fake tmux + scripted agent screen, not real Claude or a real server';

function evaluateDelivery(observation, events) {
  assert.equal(observation.error, null, observation.error || 'driver error');
  assert.ok(names.includes(observation.name));
  assert.equal(observation.composerText, observation.text, 'real composer text');
  assert.ok(Number.isSafeInteger(observation.actionMs) && observation.actionMs > 0);
  assert.ok(observation.endMs >= observation.actionMs + 15000, 'full observation window');
  const boxed = observation.name === 'wrapped-leftover' || observation.name === 'idle-suggestion';
  if (boxed) {
    assert.ok(events.length > 0, 'box keys reached fake tmux');
    assert.ok(events.every(event => event.argv[0] === 'send-keys' && Object.hasOwn(event, 'submitted')), 'stateful box rows');
    const submitted = events.filter(event => event.submitted !== null).map(event => event.submitted);
    assert.deepEqual(submitted, [observation.text], 'exactly one submission equal to the typed composer text, no leftover glued in');
    if (observation.name === 'idle-suggestion') {
      assert.ok(observation.suggestion && !observation.text.includes(observation.suggestion));
      const typed = events.filter(event => event.argv.includes('-l')).map(event => event.argv.slice(event.argv.indexOf('--') + 1).join(''));
      assert.ok(typed.length > 0 && typed.every(text => !text.includes(observation.suggestion)), 'suggestion text is never typed');
      assert.ok(events.every(event => event.submitted === null || !event.submitted.includes(observation.suggestion)), 'suggestion text is never submitted');
    }
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

function queueViews(debugLog) {
  return debugLog.split(/\r?\n/).map(line => line.match(/CHAT_QUEUE items=(\[.*\])\s*$/)).filter(Boolean).map(match => JSON.parse(match[1]));
}

function firstView(views, from, expected) {
  const wanted = JSON.stringify(expected.map(([state, text]) => ({ text, state })));
  const index = views.findIndex((view, position) => position >= from && JSON.stringify(view.map(item => ({ text: item.text, state: item.state }))) === wanted);
  assert.ok(index >= 0, `Chat View never listed ${JSON.stringify(expected)}`);
  return index;
}

function evaluateQueueCase(context) {
  const { root, json, lines, png } = context;
  const name = queueName;
  const t = queueTexts;
  const observation = json(`${name}/observation.json`);
  assert.equal(observation.name, name);
  assert.equal(observation.error, null, observation.error || 'driver error');
  assert.deepEqual(observation.texts, t, 'driver used the contract texts');
  assert.deepEqual(observation.steps.map(step => step.name), queueSteps, 'every journey step ran in order');
  const failed = observation.steps.filter(step => step.ok !== true).map(step => step.name);
  assert.ok(failed.length === 0, `journey steps failed: ${failed.join(', ')}`);
  const stand = `${name}/stand-in`;
  const state = json(`${stand}/state.json`);
  assert.equal(state.name, name);
  assert.equal(state.fake, true);
  assert.equal(state.mode, 'busy');
  assert.equal(state.suggestion, t.suggestion);
  const transcript = lines(`${name}/transcript.jsonl`);
  const operations = transcript.filter(row => row.type === 'queue-operation');
  assert.deepEqual(operations.filter(row => row.operation === 'enqueue').map(row => row.content), [t.a, t.b, t.a2, t.b], 'enqueue events in order');
  assert.deepEqual(operations.filter(row => row.operation === 'popAll').map(row => row.content), [`${t.a}\n${t.b}`]);
  assert.deepEqual(operations.filter(row => row.operation === 'remove').map(row => [row.content, row.reason]), [[t.a2, 'absorbed_mid_turn']]);
  assert.equal(operations.filter(row => row.operation === 'dequeue').length, 1);
  assert.deepEqual(transcript.filter(row => row.type === 'attachment' && row.attachment.type === 'queued_command').map(row => row.attachment.prompt), [t.a2, t.b], 'Claude took both in order');
  const frames = lines(`${stand}/frames.jsonl`);
  assert.ok(frames.length > 0 && frames.every(frame => frame.case === name));
  const frameIndex = (from, test) => {
    const index = frames.findIndex((frame, position) => position >= from && test(frame));
    assert.ok(index >= 0, 'expected shell frame missing');
    return index;
  };
  const shellQueue = (from, expected) => frameIndex(from, frame => JSON.stringify(frame.queue) === JSON.stringify(expected) && frame.screen.indexOf(`Queued: ${expected[0]}`) < frame.screen.indexOf(`Queued: ${expected.at(-1)}`));
  const appB = frameIndex(0, frame => frame.origin === 'app' && frame.mode === 'busy' && JSON.stringify(frame.queue) === JSON.stringify([t.a, t.b]));
  const both = shellQueue(0, [t.a, t.b]);
  assert.ok(appB <= both);
  const pulled = frameIndex(both, frame => frame.origin === 'shell' && frame.op === 'key' && frame.queue.length === 0 && frame.box === `${t.a}\n${t.b}`);
  const edited = shellQueue(pulled, [t.a2, t.b]);
  const idle = frameIndex(edited, frame => frame.mode === 'idle' && frame.queue.length === 0 && frame.box === '');
  assert.ok(frames[idle].suggestionShown === true && frames[idle].escaped.includes(`\u001b[2m${t.suggestion}\u001b[0m`) && frames[idle].screen.includes(t.suggestion), 'dim suggestion rendered when the box is empty');
  const shellDraft = frameIndex(idle, frame => frame.origin === 'shell' && frame.box === t.shellDraft && frame.suggestionShown === false);
  const last = frames.at(-1);
  assert.ok(frameIndex(shellDraft, frame => frame.origin === 'app' && frame.box === t.chatDraft) > shellDraft);
  assert.equal(last.box, t.chatDraft, 'fake shell input box holds the Chat View draft at the end');
  assert.equal(last.origin, 'app', 'the draft reached the shell box through the app, not the shell');
  const keys = lines(`${stand}/agent-buffer.jsonl`);
  assert.ok(keys.length > 0 && keys.every(row => row.case === name));
  assert.ok(keys.some(row => row.argv.includes('-l') && row.argv.at(-1) === t.b), 'Chat View sent its queued message through the tmux channel');
  assert.ok(keys.every(row => !row.argv.some(value => value.includes(t.suggestion))), 'the grey suggestion was never treated as text');
  const views = queueViews(fs.readFileSync(path.join(root, name, 'debug.log'), 'utf8'));
  const one = firstView(views, 0, [['queued', t.a]]);
  const two = firstView(views, one, [['queued', t.a], ['queued', t.b]]);
  const three = firstView(views, two, [['queued', t.a2], ['queued', t.b]]);
  firstView(views, three, [['sent', t.a2], ['sent', t.b]]);
  const log = fs.readFileSync(path.join(root, name, 'debug.log'), 'utf8');
  assert.match(log, /\[chat\] transcript load shell=\d+ ok/, 'Chat View read the fake session transcript');
  const consoles = lines(`${stand}/console.jsonl`);
  assert.ok(consoles.length > 0 && consoles.every(row => row.session === 'verify-agent'));
  assert.ok(consoles.every(row => JSON.stringify(row.rows) === JSON.stringify(row.screen.trimEnd().split('\n').map(line => line.trimEnd()))), 'actual console character readback');
  assert.ok(consoles.some(row => row.greySuggestion === true && row.suggestionAttribute === 8), 'grey suggestion attribute observed on the real console');
  const captures = lines(`${stand}/capture.jsonl`);
  assert.ok(captures.length > 0 && captures.every(row => row.case === name), 'production reader inspected fake tmux input box');
  const invocations = lines(`${stand}/invocations.jsonl`);
  assert.ok(invocations.some(row => row.kind === 'attach' && row.session === 'verify-agent'));
  assert.ok(invocations.some(row => row.kind === 'reader' && row.argv.join(' ') === "python3 -u -c import base64,sys;exec(base64.b64decode(sys.stdin.buffer.readline())) --serve"), 'app-supplied persistent reader bootstrap');
  assert.equal(lines(`${stand}/unsupported.jsonl`).length, 0, 'no silently unsupported boundary operations');
  const doctor = json(`${name}/doctor.json`);
  const build = json('build.json');
  assert.equal(doctor.version, build.version);
  assert.equal(doctor.sha256.toLowerCase(), build.sha256.toLowerCase());
  assert.ok(doctor.pid > 0 && doctor.hwnd > 0 && doctor.composer > 0 && doctor.chat && doctor.tmux);
  assert.deepEqual(doctor.focus, [doctor.hwnd, doctor.composer]);
  const actions = json('actions.json').filter(action => action.case === name);
  assert.deepEqual(actions.slice(0, 2).map(action => action.input), ['Ctrl+1: select saved tmux tab', 'Alt+C: open Chat View']);
  assert.ok(actions.filter(action => action.input === 'shell input').length >= 9, 'shell side driven through the fake terminal');
  assert.ok(actions.some(action => action.input === 'type composer text' && action.text === t.b));
  assert.ok(actions.some(action => action.input === 'type composer text' && action.text === t.chatDraft));
  const saved = json(`${name}/session-chat.json`);
  assert.equal(saved.active_tab, 0);
  assert.equal(saved.tabs.length, 1);
  assert.equal(saved.tabs[0].tmux_session, 'verify-agent');
  assert.equal(saved.tabs[0].cv, true);
  const cleanup = json(`${name}/cleanup.json`);
  assert.equal(cleanup.remaining_owned_processes, 0);
  assert.equal(cleanup.evidence_preserved, true);
  assert.equal(cleanup.scratch_removed, true);
  assert.equal(json(`${name}/process-tree.json`).ActiveProcesses, 0);
  for (const suffix of ['before', 'action', 'after', 'final']) png(`${name}-${suffix}.png`);
  return { steps: observation.steps.length, queueViews: views.length, frames: frames.length, finalBox: last.box };
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
      if (name === 'wrapped-leftover' || name === 'idle-suggestion') {
        assert.equal(captures[0].screen, ready.screen, 'first capture is the seeded box');
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
  try {
    cases.push({ name: queueName, passed: true, detail: evaluateQueueCase({ root, json, lines, png }) });
  } catch (error) {
    cases.push({ name: queueName, passed: false, detail: error.message });
  }
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

module.exports = { names, queueName, allNames, queueTexts, queueSteps, agentBoundary, evaluateDelivery, evaluateEvidence };
