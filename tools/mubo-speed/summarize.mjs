import fs from 'node:fs';
import path from 'node:path';

const root = process.argv[2];
if (!root) throw new Error('usage: node tools/mubo-speed/summarize.mjs <evidence-dir>');

function walk(dir, found = []) {
  if (!fs.existsSync(dir)) return found;
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) walk(full, found);
    else if (entry.name === 'open-timings.json' || entry.name === 'idle.json') found.push(full);
  }
  return found;
}

const card = [];
const idle = [];
for (const file of walk(root)) {
  const data = JSON.parse(fs.readFileSync(file, 'utf8'));
  const row = { file, ...data };
  if (data.probe === 'usage-card-open') card.push(row);
  else if (data.probe === 'idle-log-cpu') idle.push(row);
}

const lines = [];
const round = value => (value === null || value === undefined ? 'n/a' : String(value));

lines.push('## Usage card open time (MUBO-14)');
lines.push('');
lines.push('| release | version | samples | errors | open p50 ms | open max ms | hover-to-card p50 ms | hover-to-card max ms | UI blocked max ms | smooth max ms | panel pixels | status |');
lines.push('| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |');
for (const run of card) {
  lines.push(`| ${run.tag} | ${round(run.exeVersion)} | ${round(run.painted)} | ${round(run.errors)} | ${round(run.openedP50Ms)} | ${round(run.openedMaxMs)} | ${round(run.rawP50Ms)} | ${round(run.rawMaxMs)} | ${round(run.blockedMaxMs)} | ${round(run.smoothMaxMs)} | ${round(run.panelPixels)} | ${round(run.status)} |`);
}
for (const run of card) {
  const pass = run.status === 'measured' && run.painted >= 5 && run.errors === 0 && typeof run.openedMaxMs === 'number' && run.openedMaxMs < 100 && typeof run.smoothMaxMs === 'number' && run.smoothMaxMs < 250 && run.panelPixels > 0;
  lines.push(`- ${run.tag}: ${pass ? 'PASS' : 'FAIL'} (open max ${round(run.openedMaxMs)} ms, smooth max ${round(run.smoothMaxMs)} ms${run.error ? ', error: ' + run.error : ''})`);
}
lines.push('');

lines.push('## Idle log growth and processor use (MUBO-17)');
lines.push('');
lines.push('| release | scenario | window s | log bytes | bytes/min | MB/hour | CPU ms | CPU ms/min | CPU % of one core | status |');
lines.push('| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |');
for (const run of idle) {
  lines.push(`| ${run.tag} | ${run.scenario} | ${round(run.windowSeconds)} | ${round(run.logBytesDelta)} | ${round(run.logBytesPerMinute)} | ${round(run.logMbPerHour)} | ${round(run.cpuMs)} | ${round(run.cpuMsPerMinute)} | ${round(run.cpuPercentOfOneCore)} | ${round(run.status)} |`);
}
for (const run of idle) {
  const pass = run.status === 'measured' && typeof run.logMbPerHour === 'number' && run.logMbPerHour < 1;
  lines.push(`- ${run.tag} ${run.scenario}: ${pass ? 'PASS' : 'FAIL'} (${round(run.logMbPerHour)} MB/hour, ${round(run.cpuPercentOfOneCore)}% of one core${run.error ? ', error: ' + run.error : ''})`);
}
lines.push('');

const text = lines.join('\n');
fs.writeFileSync(path.join(root, 'summary.md'), text + '\n');
console.log(text);
