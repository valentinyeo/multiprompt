// Turn the live-channel idle windows into the MUBO-17 verdict.
// usage: node tools/mubo-speed/live-verdict.mjs <evidence-root> [report.txt]
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const BAR_MB_PER_HOUR = 1;
const MIN_WINDOWS_PER_SIDE = 3;

function walk(dir, found = []) {
  if (!fs.existsSync(dir)) return found;
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) walk(full, found);
    else if (entry.name === 'idle.json') found.push(full);
  }
  return found;
}

export function median(values) {
  const sorted = [...values].sort((a, b) => a - b);
  if (!sorted.length) return null;
  const middle = Math.floor(sorted.length / 2);
  return sorted.length % 2 ? sorted[middle] : (sorted[middle - 1] + sorted[middle]) / 2;
}

function fixed(value, digits) {
  return value === null || value === undefined ? 'n/a' : Number(value).toFixed(digits);
}

function side(runs) {
  const measured = runs.filter((run) => run.status === 'measured');
  return {
    runs,
    windows: runs.length,
    measured: measured.length,
    mbPerHour: median(measured.map((run) => run.logMbPerHour)),
    mbMin: measured.length ? Math.min(...measured.map((run) => run.logMbPerHour)) : null,
    mbMax: measured.length ? Math.max(...measured.map((run) => run.logMbPerHour)) : null,
    cpu: median(measured.map((run) => run.cpuPercentOfOneCore)),
    cpuMin: measured.length ? Math.min(...measured.map((run) => run.cpuPercentOfOneCore)) : null,
    cpuMax: measured.length ? Math.max(...measured.map((run) => run.cpuPercentOfOneCore)) : null,
    bytes: median(measured.map((run) => run.logBytesDelta)),
    statusSnapshots: median(measured.map((run) => run.windowStatusSnapshots ?? 0)),
    paintLines: median(measured.map((run) => run.windowChatPaintLines ?? 0)),
    transcriptReads: median(measured.map((run) => run.transcriptReads ?? 0)),
  };
}

export function verdict(runs, before, after) {
  const byTag = { [before]: [], [after]: [] };
  for (const run of runs) {
    if (run.scenario !== 'live') continue;
    if (run.tag !== before && run.tag !== after) continue;
    byTag[run.tag].push(run);
  }
  const sides = { before: side(byTag[before]), after: side(byTag[after]) };
  const failures = [];
  for (const [name, tag] of [['before', before], ['after', after]]) {
    const data = sides[name];
    if (data.windows < MIN_WINDOWS_PER_SIDE) failures.push(`${tag} has ${data.windows} idle windows; at least ${MIN_WINDOWS_PER_SIDE} are required`);
    if (data.measured !== data.windows) failures.push(`${tag} has ${data.windows - data.measured} invalid window(s)`);
  }
  const base = sides.before;
  const head = sides.after;
  if (head.mbPerHour === null || base.mbPerHour === null) {
    failures.push('a side has no measured window');
  } else {
    if (head.mbPerHour >= BAR_MB_PER_HOUR) failures.push(`after logs ${fixed(head.mbPerHour, 3)} MB/hour; the bar is under ${BAR_MB_PER_HOUR} MB/hour`);
    if (!(head.cpu < base.cpu)) failures.push(`after burns ${fixed(head.cpu, 3)}% of one core, not lower than the ${fixed(base.cpu, 3)}% before`);
    if (head.cpu < base.cpu && (base.cpuMin === null || head.cpuMax >= base.cpuMin)) {
      failures.push(`after CPU ${fixed(head.cpu, 3)}% (up to ${fixed(head.cpuMax, 3)}%) is inside the before range ${fixed(base.cpuMin, 3)}-${fixed(base.cpuMax, 3)}%, so CPU shows no measurable difference`);
    }
  }
  return { sides, failures, pass: failures.length === 0 };
}

export function render(result, before, after) {
  const lines = [];
  lines.push('## MUBO-17 idle log growth and processor use, three live chats open');
  lines.push('');
  lines.push('| release | windows | median MB/hour | MB/hour range | median CPU % of one core | CPU % range | status snapshots per window | chat paint lines per window |');
  lines.push('| --- | --- | --- | --- | --- | --- | --- | --- |');
  for (const [name, tag] of [['before', before], ['after', after]]) {
    const data = result.sides[name];
    lines.push(`| ${tag} | ${data.windows} (${data.measured} measured) | ${fixed(data.mbPerHour, 3)} | ${fixed(data.mbMin, 3)}-${fixed(data.mbMax, 3)} | ${fixed(data.cpu, 3)} | ${fixed(data.cpuMin, 3)}-${fixed(data.cpuMax, 3)} | ${fixed(data.statusSnapshots, 0)} | ${fixed(data.paintLines, 0)} |`);
  }
  lines.push('');
  for (const run of result.sides.before.runs.concat(result.sides.after.runs)) {
    lines.push(`- ${run.tag} ${run.scenario} window ${run.windowSeconds} s: log ${fixed(run.logMbPerHour, 3)} MB/hour, CPU ${fixed(run.cpuPercentOfOneCore, 3)}% of one core, ${run.chatTabs ?? 'n/a'} live chats, ${run.transcriptReads ?? 'n/a'} transcript reads, ${run.windowStatusSnapshots ?? 'n/a'} snapshots in window, status ${run.status}${run.error ? ` (${run.error})` : ''}`);
  }
  lines.push('');
  lines.push(result.pass ? 'MUBO-17 IDLE LIVE PASSED' : 'MUBO-17 IDLE LIVE FAILED');
  for (const failure of result.failures) lines.push(`  ${failure}`);
  return lines.join('\n');
}

function main(argv) {
  const [root, outFile] = argv;
  if (!root) {
    console.error('usage: node tools/mubo-speed/live-verdict.mjs <evidence-root> [report.txt]');
    return 2;
  }
  const runs = walk(root).map((file) => JSON.parse(fs.readFileSync(file, 'utf8')));
  const before = process.env.BEFORE_TAG;
  const after = process.env.AFTER_TAG;
  const result = verdict(runs, before, after);
  const text = render(result, before, after);
  console.log(text);
  if (outFile) fs.writeFileSync(outFile, text + '\n');
  return result.pass ? 0 : 1;
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) process.exit(main(process.argv.slice(2)));
