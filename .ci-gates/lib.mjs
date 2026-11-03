import { execFileSync } from 'node:child_process';

export const REPO = 'valentinyeo/multiprompt';
export const PR = 726;

export function gh(args) {
  return execFileSync('gh', args, { encoding: 'utf8', maxBuffer: 64 * 1024 * 1024 });
}

export function ghJson(args) {
  const out = gh(args);
  return out.trim() ? JSON.parse(out) : null;
}

export function fail(message) {
  console.error(message);
  process.exit(1);
}
