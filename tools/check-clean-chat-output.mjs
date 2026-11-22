import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const source = fs.readdirSync(path.join(root, 'src')).filter(file => file.endsWith('.zig')).map(file => fs.readFileSync(path.join(root, 'src', file), 'utf8')).join('\n');
const names = [...source.matchAll(/^test "(IGSH-816 CLEAN[^"\n]+)"/gm)].map(match => match[1]);
assert.ok(names.length > 0, 'No CLEAN pixel tests found in source');
export function verifyCleanCoverage(output) {
  output = output.replace(/\x1b\[[0-9;]*m/g, '');
  const passed = new Set([...output.matchAll(/^\d+\/\d+ [\w.]+\.test\.(IGSH-816 CLEAN[^\r\n]+)\.\.\.OK\r?$/gm)].map(match => match[1]));
  const missing = names.filter(name => !passed.has(name));
  assert.deepEqual(missing, [], `Missing passing CLEAN pixel tests: ${missing.join(', ')}`);
  return names.length;
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const count = verifyCleanCoverage(fs.readFileSync(process.argv[2], 'utf8'));
  console.log(`CLEAN pixel coverage verified: ${count}/${count} tests passed`);
}
