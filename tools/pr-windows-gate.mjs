import { execFileSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import { pathToFileURL } from 'node:url';

export function matches(file, pattern) {
  const expression = pattern
    .replace(/[.+^${}()|[\]\\*]/g, '\\$&')
    .replace(/\\\*\\\*/g, '.*')
    .replace(/\\\*/g, '[^/]*');
  return new RegExp(`^${expression}$`).test(file);
}

export function shouldRun({ event, action, label, review, draft, paths = [], patterns = [] }) {
  if (event === 'push' || event === 'workflow_dispatch' || event === 'merge_group') return true;
  if (event === 'pull_request' && action === 'labeled' && label === 'automerge') return true;
  if (event === 'pull_request') return false;
  if (event === 'pull_request_review' && review === 'approved' && String(draft) !== 'true') {
    return paths.some(file => patterns.some(pattern => matches(file, pattern)));
  }
  return false;
}

function changedPaths() {
  let base = process.env.BASE;
  const head = process.env.HEAD;
  if (!base || !head) return [];
  base = execFileSync('git', ['merge-base', base, head], { encoding: 'utf8' }).trim();
  return execFileSync('git', ['diff', '--name-only', '-z', base, head]).toString('utf8').split('\0').filter(Boolean);
}

function main() {
  const patterns = (process.env.PATTERNS || '').split('\n').map(line => line.trim()).filter(Boolean);
  const event = process.env.EVENT || '';
  const paths = event === 'pull_request_review' ? changedPaths() : [];
  const run = shouldRun({
    event,
    action: process.env.ACTION || '',
    label: process.env.LABEL || '',
    review: process.env.REVIEW || '',
    draft: process.env.DRAFT || '',
    paths,
    patterns,
  });
  const body = `run=${run}\n`;
  if (process.env.GITHUB_OUTPUT) fs.appendFileSync(process.env.GITHUB_OUTPUT, body);
  else process.stdout.write(body);
}

if (process.argv[1] && import.meta.url === pathToFileURL(path.resolve(process.argv[1])).href) main();
