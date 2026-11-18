import fs from 'node:fs';
import path from 'node:path';

const [outDir, part, log, exitCode, pattern, baseLog, baseExit] = process.argv.slice(2);
if (!outDir || !part || !log || !/^\d+$/.test(exitCode ?? '') || !pattern || Boolean(baseLog) !== Boolean(baseExit) || (baseExit && !/^\d+$/.test(baseExit))) {
  console.error('usage: ci-receipt-summary.mjs <outDir> <part> <log> <exitCode> <line-pattern> [<baseLog> <baseExitCode>]');
  process.exit(2);
}
const matcher = new RegExp(pattern);
const read = file => fs.readFileSync(file, 'utf8').split(/\r?\n/);
const count = (lines, name) => {
  const hit = lines.map(line => line.match(new RegExp(`^# ${name} (\\d+)$`))).find(Boolean);
  return hit ? Number(hit[1]) : null;
};
const lines = read(log);
const entry = { exit_code: Number(exitCode), tests_passed: count(lines, 'pass'), tests_failed: count(lines, 'fail'), lines: lines.filter(line => matcher.test(line)) };
if (baseLog) Object.assign(entry, { base_exit_code: Number(baseExit), base_lines: read(baseLog).filter(line => matcher.test(line)) });
fs.mkdirSync(outDir, { recursive: true });
const file = path.join(outDir, 'summary.json');
const summary = fs.existsSync(file) ? JSON.parse(fs.readFileSync(file, 'utf8')) : { parts: {} };
summary.head_sha = process.env.HEAD_SHA || summary.head_sha || '';
summary.parts[part] = entry;
if (baseLog) summary.repro = { part, base_exit_code: entry.base_exit_code, head_exit_code: entry.exit_code };
summary.exit_code = Math.max(...Object.values(summary.parts).map(item => item.exit_code));
fs.copyFileSync(log, path.join(outDir, path.basename(log)));
if (baseLog) fs.copyFileSync(baseLog, path.join(outDir, path.basename(baseLog)));
fs.writeFileSync(file, JSON.stringify(summary, null, 2));
if (entry.exit_code !== 0 || !entry.lines.length) process.exit(1);
