const fs = require('node:fs');
const path = require('node:path');

const MODEL_IDS = [12003, 12004, 12005, 12011, 12012, 12013, 12014, 12015];

function load(file = path.join(__dirname, 'harness-matrix.json')) {
  return JSON.parse(fs.readFileSync(file, 'utf8'));
}

function cells(matrix = load()) {
  const rows = [];
  for (const harness of matrix.harnesses) {
    for (const mode of matrix.modes) {
      for (const host of matrix.hosts) {
        const id = `${harness.id}.${mode}.${host.id}`;
        if (mode === 'live_chat') {
          const skills = harness.skills ? ' Open the skill list and require it to list entries.' : '';
          rows.push({
            id,
            kind: 'cells',
            mode,
            harness: harness.id,
            host: host.id,
            journey: `Ctrl+K, choose ${harness.live_query} for ${host.id}, require that host's channel, send "reply with the word pong", and require a reply that contains pong. Open the model picker, require it to list this harness's models, pick ${harness.pick_model || 'a non-default model'}, send again, and require the host log or the chat header to name that model.${skills}`,
            pass: 'The reply contains pong, the picked model is the one that answered, and a harness with a skill list shows entries.',
            evidence: `${id}.json`,
            screenshot: `${id}.png`,
            live_query: harness.live_query,
            live_target: harness.live_target,
            models: harness.models,
            model_ids: harness.model_ids,
            pick_model: harness.pick_model,
            pick_target: harness.pick_target,
            skills: harness.skills,
          });
        } else {
          rows.push({
            id,
            kind: 'cells',
            mode,
            harness: harness.id,
            host: host.id,
            journey: `Ctrl+K, choose ${host.query}, require the tab cols and rows to match that window rather than 80x24, type ${harness.version_command}, and require the version output.`,
            pass: 'The shell grid matches the window and the version command prints a version line.',
            evidence: `${id}.json`,
            screenshot: `${id}.png`,
            shell_query: host.query,
            shell_target: host.target,
            version_command: harness.version_command,
          });
        }
      }
    }
  }
  for (const row of matrix.shell_quality) rows.push({ ...row, mode: 'shell_quality', harness: '', host: 'vps1' });
  return rows;
}

function select(part, matrix = load()) {
  const name = part || 'all';
  return cells(matrix).filter(row => name === 'all' || row.kind === name);
}

function report(results) {
  const byId = new Map(results.map(row => [row.id, row]));
  const lines = [
    '| cell | result | screenshot |',
    '| --- | --- | --- |',
  ];
  for (const row of cells()) {
    const found = byId.get(row.id) || {};
    const result = found.pass === true ? 'pass' : found.pass === false ? 'fail' : 'missing';
    const detail = found.detail ? ` ${String(found.detail).replace(/\|/g, '/')}` : '';
    const shot = found.screenshot || row.screenshot;
    lines.push(`| ${row.id} | ${result}${detail} | [${shot}](${shot}) |`);
  }
  return lines.join('\n') + '\n';
}

function mismatches(source) {
  const matrix = load();
  const problems = [];
  for (const harness of matrix.harnesses) {
    if (!source.includes(`= ${harness.live_target}`)) problems.push(`${harness.id} target ${harness.live_target}`);
    for (const id of harness.model_ids) {
      if (!MODEL_IDS.includes(id) || !source.includes(`= ${id}`)) problems.push(`${harness.id} model ${id}`);
    }
  }
  for (const host of matrix.hosts) {
    if (host.target !== 2003 && host.target !== 2004) problems.push(host.id);
  }
  if (!source.includes('SEARCH_NEW_OFFSET: usize = 2000')) problems.push('shell offset');
  return problems;
}

module.exports = { load, cells, select, report, mismatches, MODEL_IDS };

function readResults(file) {
  const parsed = JSON.parse(fs.readFileSync(file, 'utf8').replace(/^\uFEFF/, ''));
  if (Array.isArray(parsed)) return parsed;
  if (parsed && typeof parsed === 'object') return [parsed];
  throw new Error('matrix results must be a list');
}

if (require.main === module) {
  const [command, ...args] = process.argv.slice(2);
  if (command === 'journeys') {
    process.stdout.write(JSON.stringify(select(args[0])));
  } else if (command === 'report') {
    process.stdout.write(report(args.flatMap(readResults)));
  } else {
    throw new Error('Expected journeys or report');
  }
}
