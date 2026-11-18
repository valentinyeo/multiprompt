import fs from 'node:fs';
import path from 'node:path';

const [log, outDir, exitCode, pattern] = process.argv.slice(2);
if (!log || !outDir || !/^\d+$/.test(exitCode ?? '') || !pattern) {
  console.error('usage: ci-receipt-summary.mjs <log> <outDir> <exitCode> <line-pattern>');
  process.exit(2);
}
const lines = fs.readFileSync(log, 'utf8').split(/\r?\n/);
const matcher = new RegExp(pattern);
const count = name => {
  const hit = lines.map(line => line.match(new RegExp(`^# ${name} (\\d+)$`))).find(Boolean);
  return hit ? Number(hit[1]) : null;
};
const summary = {
  head_sha: process.env.HEAD_SHA || '',
  exit_code: Number(exitCode),
  tests_passed: count('pass'),
  tests_failed: count('fail'),
  lines: lines.filter(line => matcher.test(line)),
};
fs.mkdirSync(outDir, { recursive: true });
fs.copyFileSync(log, path.join(outDir, path.basename(log)));
fs.writeFileSync(path.join(outDir, 'summary.json'), JSON.stringify(summary, null, 2));
if (summary.exit_code !== 0 || !summary.lines.length) process.exit(1);
