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
      return model >= 0 && args[model + 1] === 'haiku' && (effort === 'default' ? level < 0 : level >= 0 && args[level + 1] === effort);
    }));
  }
  for (const name of ['model-before', 'model-after', 'model-plus-menu-active', ...['haiku', 'low', 'medium', 'high'].flatMap(choice => [`model-plus-${choice}`, `model-after-${choice}`])]) {
    const png = fs.readFileSync(path.join(root, `${name}.png`));
    assert.equal(png.subarray(0, 8).toString('hex'), '89504e470d0a1a0a');
    assert.ok(png.length > 1000);
  }
  return { model: 'haiku', efforts: ['low', 'medium', 'high'], historyRetained: true, draftRetained: true };
}

module.exports = { verify };
if (require.main === module) {
  const root = process.argv[2];
  try {
    const proof = verify(root);
    fs.writeFileSync(path.join(root, 'result.json'), JSON.stringify({ feature: 'chat-model', status: 'passed', agentBoundary: 'Production embedded reader and host; fixture SSH, Windows compatibility and synthetic Claude process; no model call', cases: [{ name: 'model-settings', passed: true, detail: proof }] }, null, 2));
    console.log(JSON.stringify(proof));
  } catch (error) {
    console.error(error);
    process.exitCode = 1;
  }
}
