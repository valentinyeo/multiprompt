import assert from 'node:assert/strict';
import fs from 'node:fs';
import { execFileSync } from 'node:child_process';

const changed = new Set([
  ...execFileSync('git', ['diff', '--name-only', 'origin/master'], { encoding: 'utf8' }).trim().split('\n'),
  ...execFileSync('git', ['ls-files', '--others', '--exclude-standard'], { encoding: 'utf8' }).trim().split('\n'),
]);
let checked = 0;
for (const file of changed) {
  if (!file || !fs.existsSync(file)) continue;
  if (file.endsWith('.zig')) {
    execFileSync(process.env.ZIG || 'zig', ['ast-check', file], { stdio: 'pipe' });
    checked++;
  } else if (/\.[cm]?js$/.test(file)) {
    execFileSync(process.execPath, ['--check', file], { stdio: 'pipe' });
    checked++;
  } else if (file.endsWith('.json')) {
    JSON.parse(fs.readFileSync(file, 'utf8'));
    checked++;
  }
}
assert.ok(checked > 0);
execFileSync('git', ['diff', '--check', 'origin/master'], { stdio: 'pipe' });
console.log(`ISSUE-252 syntax verified (${checked} files)`);
