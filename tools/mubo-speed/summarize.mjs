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
lines.push('| release | version | click samples | click errors | click p50 ms | click max ms | hover p50 ms | hover max ms | hover minus dwell p50 ms | hover minus dwell max ms | dwell ms read back | UI blocked max ms | smooth max ms | panel pixels | status |');
lines.push('| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |');
for (const run of card) {
  lines.push(`| ${run.tag} | ${round(run.exeVersion)} | ${round(run.clickPainted)} | ${round(run.errors)} | ${round(run.clickP50Ms)} | ${round(run.clickMaxMs)} | ${round(run.hoverP50Ms)} | ${round(run.hoverMaxMs)} | ${round(run.hoverAdjustedP50Ms)} | ${round(run.hoverAdjustedMaxMs)} | ${round(run.hoverDelayReadBackMs)} | ${round(run.blockedMaxMs)} | ${round(run.smoothMaxMs)} | ${round(run.panelPixels)} | ${round(run.status)} |`);
}
for (const run of card) {
  const base = run.status === 'measured' && run.errors === 0 && run.panelPixels > 0 && typeof run.smoothMaxMs === 'number' && run.smoothMaxMs < 250;
  const clickPass = base && run.clickPainted >= 5 && typeof run.clickMaxMs === 'number' && run.clickMaxMs < 100;
  const hoverPass = base && run.hoverPainted >= 5 && typeof run.hoverAdjustedMaxMs === 'number' && run.hoverAdjustedMaxMs < 100;
  const pass = clickPass || hoverPass;
  lines.push(`- ${run.tag}: ${pass ? 'PASS' : 'FAIL'} (click max ${round(run.clickMaxMs)} ms over ${round(run.clickPainted)} samples, hover minus dwell max ${round(run.hoverAdjustedMaxMs)} ms, smooth max ${round(run.smoothMaxMs)} ms${run.error ? ', error: ' + run.error : ''})`);
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
