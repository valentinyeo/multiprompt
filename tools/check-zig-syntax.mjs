import fs from 'node:fs';
import path from 'node:path';
import { spawnSync } from 'node:child_process';

const started = performance.now();
let checked = 0;
let failed = false;
try {
  const files = process.argv.slice(2);
  if (!files.length) {
    files.push('build.zig');
    const walk = dir => {
      for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
        const name = path.join(dir, entry.name);
        if (entry.isDirectory()) walk(name);
        else if (entry.isFile() && name.endsWith('.zig')) files.push(name);
      }
    };
    walk('src');
    if (!files.includes(path.join('src', 'changelog.zig'))) throw new Error('src/changelog.zig is missing');
  }
  for (const file of files) {
    const result = spawnSync(process.env.ZIG || 'zig', ['ast-check', file], { encoding: 'utf8' });
    checked++;
    if (result.error || result.status !== 0) {
      if (result.stdout) process.stdout.write(result.stdout);
      if (result.stderr) process.stderr.write(result.stderr);
      if (result.error) console.error(`${file}: ${result.error.message}`);
      if (result.signal) console.error(`${file}: terminated by ${result.signal}`);
      failed = true;
      break;
    }
  }
} catch (error) {
  console.error(error.message);
  failed = true;
}
console.log(`Zig syntax ${failed ? 'failed' : 'passed'}: ${checked} files in ${(performance.now() - started).toFixed(0)} ms`);
if (failed) process.exitCode = 1;
