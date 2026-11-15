const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

function verify(root) {
  const dir = path.join(root, 'model-settings');
  const read = name => fs.readFileSync(path.join(dir, name), 'utf8').replace(/^\uFEFF/, '');
  const json = name => JSON.parse(read(name));
  const lines = name => read(name).trim().split(/\r?\n/).filter(Boolean).map(JSON.parse);
  const cleanup = json('cleanup.json');
  assert.equal(cleanup.remaining_owned_processes, 0);
  assert.equal(cleanup.scratch_removed, true);
  assert.equal(cleanup.evidence_preserved, true);
  assert.equal(json('observation.json').error, null);
  assert.equal(json('observation.json').draft, 'model draft retained');
  for (const stage of ['before', 'after']) {
    const history = read(`${stage}-history.txt`);
    assert.ok(history.includes('start the fake session'));
    assert.ok(history.includes('The fake session is ready.'));
  }
  const plus = json('plus-active.json');
  assert.deepEqual(plus.failures, []);
  assert.ok(plus.expected_active.includes('model_haiku'));
  assert.ok(plus.expected_active.includes('effort_high'));
  for (const row of plus.rows) {
    assert.equal(row.mark, 0, row.item);
    if (plus.expected_active.includes(row.item)) assert.ok(row.accent >= 10, row.item);
  }
  for (const item of plus.expected_active) assert.ok(plus.rows.some(row => row.item === item), item);
  const hostFiles = fs.readdirSync(path.join(dir, 'host'));
  const eventFile = hostFiles.filter(name => name.endsWith('.events.log'));
  assert.equal(eventFile.length, 1);
  const finalLog = read(`host/${eventFile[0]}`);
  const finalArgs = read('stand-in/model-argv.jsonl');
  const reader = lines('stand-in/model-reader.jsonl');
  assert.ok(reader.some(row => /^[a-f0-9]{64}$/.test(row.inner_sha256)));
  const doctor = json('doctor.json');
  assert.ok(doctor.pid > 0 && doctor.hwnd > 0 && doctor.chat);
  assert.match(doctor.sha256, /^[a-f0-9]{64}$/i);
  const actions = JSON.parse(fs.readFileSync(path.join(root, 'actions.json'), 'utf8').replace(/^\uFEFF/, ''));
  assert.equal(json('saved-settings.json').model, 'fable');
  assert.ok(!json('config-initial.json').model);
  assert.ok(!json('config-initial.json').effort);
  const initial = lines('argv-initial.jsonl');
  assert.ok(initial.length > 0);
  for (const row of initial) {
    assert.equal(row.saved_model, 'fable');
    assert.deepEqual(row.aliases, {});
    const args = row.argv;
    assert.equal(args.filter(arg => arg === '--model').length, 1);
    assert.equal(args[args.indexOf('--model') + 1], 'opus');
    assert.equal(args[args.indexOf('--effort') + 1], 'medium');
  }
  const defaults = json('plus-default.json');
  assert.deepEqual(defaults.failures, []);
  for (const item of ['model_opus', 'effort_medium']) {
    assert.ok(defaults.expected_active.includes(item));
    assert.ok(defaults.rows.some(row => row.item === item && row.accent >= 10));
  }
  for (const row of defaults.rows) {
    assert.equal(row.mark, 0, row.item);
    if (/^(model_|effort_)/.test(row.item) && !['model_opus', 'effort_medium'].includes(row.item)) assert.ok(row.accent < 10, row.item);
  }
  for (const [name, text, amber] of [['fable', 'Fable 5.2 · medium', true], ['opus', 'Opus 5.5 · medium', false]]) {
    const header = json(`header-${name}.json`);
    assert.equal(header.text, text);
    assert.equal(header.amber, amber);
    assert.ok(header.ink >= 10);
    assert.ok(header.rect[1] >= header.titleBottom - 1 && header.rect[3] > header.titleBottom);
    assert.equal(header.hand, true);
    const cursor = json(`header-${name}-cursor.json`);
    assert.equal(cursor.flags, 1);
    assert.ok(cursor.expectedHand > 0);
    assert.equal(cursor.actual, cursor.expectedHand);
    assert.equal(header.pickerOpened, true);
    assert.ok(actions.some(action => action.input === 'click header model' && action.text === text));
  }
  assert.ok(actions.some(action => action.input === 'Enter: send with the default model'));
  for (const [name, item, effort] of [['haiku', 'model_haiku', 'default'], ['low', 'effort_low', 'low'], ['medium', 'effort_medium', 'medium'], ['high', 'effort_high', 'high']]) {
    assert.ok(actions.some(action => action.input === 'choose plus menu row' && action.text === item));
    const config = json(`config-${name}.json`);
    assert.equal(config.enabled, true);
    assert.equal(config.model, 'haiku');
    if (effort === 'default') assert.ok(!config.effort);
    else assert.equal(config.effort, effort);
    assert.ok(finalLog.startsWith(read(`host-${name}.jsonl`)));
    assert.ok(finalArgs.startsWith(read(`argv-${name}.jsonl`)));
    assert.ok(lines(`host-${name}.jsonl`).some(row => row.event === 'model_effort_settings_applied' && row.detail.model === 'haiku' && row.detail.effort === effort));
    assert.ok(lines(`argv-${name}.jsonl`).some(row => {
      const args = row.argv;
      const model = args.indexOf('--model');
      const level = args.indexOf('--effort');
      return model >= 0 && args[model + 1] === 'haiku' && (level >= 0 && args[level + 1] === (effort === 'default' ? 'medium' : effort));
    }));
  }
  for (const name of ['model-before', 'model-after', 'model-plus-menu-active', 'model-default-menu', 'model-header-fable', 'model-header-fable-picker', 'model-header-opus', 'model-header-opus-picker', ...['haiku', 'low', 'medium', 'high'].flatMap(choice => [`model-plus-${choice}`, `model-after-${choice}`])]) {
    const png = fs.readFileSync(path.join(root, `${name}.png`));
    assert.equal(png.subarray(0, 8).toString('hex'), '89504e470d0a1a0a');
    assert.ok(png.length > 1000);
  }
  return { defaultModel: 'opus', defaultEffort: 'medium', savedModel: 'fable', aliasesCleared: true, headers: ['Fable 5.2 · medium', 'Opus 5.5 · medium'], headerClickOpensPicker: true, handCursor: true, defaultMenu: ['model_opus', 'effort_medium'], model: 'haiku', efforts: ['low', 'medium', 'high'], historyRetained: true, draftRetained: true };
}

module.exports = { verify };
if (require.main === module) {
  const root = process.argv[2];
  try {
    const proof = verify(root);
    fs.writeFileSync(path.join(root, 'result.json'), JSON.stringify({ feature: 'chat-model', status: 'passed', checks: ['Opus and medium launch despite saved Fable and aliases', 'Running transcript model below the chat name', 'Amber Fable and grey Opus header pixels', 'Header hand cursor and click open the plus picker', 'Opus and medium menu defaults'], cleanup: JSON.parse(fs.readFileSync(path.join(root, 'cleanup.json'), 'utf8').replace(/^\uFEFF/, '')), agentBoundary: 'Production embedded reader and host; fixture SSH, Windows compatibility and synthetic Claude process; no model call', cases: [{ name: 'model-settings', passed: true, detail: proof }] }, null, 2));
    console.log(JSON.stringify(proof));
  } catch (error) {
    console.error(error);
    process.exitCode = 1;
  }
}
