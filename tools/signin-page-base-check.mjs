import { readFileSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

export const signinPageFiles = ['service/pages.js', 'service/test/signin-page.test.js'];

export function baseCheckApplies(changed) {
  const files = new Set(changed.map(file => String(file).trim()).filter(Boolean));
  return signinPageFiles.some(file => files.has(file));
}

function main() {
  const argv = process.argv.slice(2);
  const changed = argv.length ? argv : readFileSync(0, 'utf8').split(/\r?\n/);
  process.stdout.write(`${baseCheckApplies(changed)}\n`);
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) main();
