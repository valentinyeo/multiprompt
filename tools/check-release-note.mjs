import { execFileSync } from 'node:child_process';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { autoRevertBranch, checkFragments, classifyTrees, compareTags } from './version-stamp.mjs';

const releaseTag = /^v(?:0|[1-9]\d*)\.(?:0|[1-9]\d*)\.(?:0|[1-9]\d*)$/;
const noteEscape = /^No-Note: \S/;
const shipped = file => file.startsWith('src/') || file.startsWith('extension/');

export function newestReleaseTag(tags) {
  return tags.filter(name => releaseTag.test(name)).sort(compareTags).at(-1) ?? null;
}

export function escapedNote(lines) {
  return lines.some(line => noteEscape.test(line));
}

export function checkReleaseNote(base, head, changed, lines) {
  if (escapedNote(lines)) return 'No-Note';
  if (classifyTrees(base, head, changed) === 'STAMP') return 'STAMP';
  checkFragments(base, head, changed);
  return 'OK';
}

function git(args) {
  return execFileSync('git', args, { encoding: 'utf8', maxBuffer: 64 * 1024 * 1024 }).trim();
}

function readTree(rev) {
  const names = git(['ls-tree', '-r', '--name-only', '-z', rev, '--', 'src/', 'changelog.d/']).split('\0')
    .filter(file => file && (file.startsWith('changelog.d/') || file.endsWith('.zig')));
  return Object.fromEntries(names.map(file => [file, git(['show', `${rev}:${file}`])]));
}

function run() {
  if (autoRevertBranch()) {
    console.log('SKIP auto-revert branch');
    return;
  }
  const tag = newestReleaseTag(git(['tag', '--merged', 'HEAD', '--list', 'v*']).split('\n').filter(Boolean));
  if (!tag) {
    console.log('SKIP no release tag');
    return;
  }
  const changed = git(['diff', '--name-only', '-z', tag, 'HEAD']).split('\0').filter(Boolean);
  if (!changed.some(shipped)) {
    console.log(`OK ${tag}: no shipped change`);
    return;
  }
  const lines = git(['log', '--format=%B', `${tag}..HEAD`]).split(/\r?\n/);
  let kind;
  try {
    kind = checkReleaseNote(readTree(tag), readTree('HEAD'), changed, lines);
  } catch (error) {
    throw new Error(`${error.message} since ${tag}, or add a "No-Note: <reason>" line to a commit message for a change with no visible effect`);
  }
  console.log(`${kind} ${tag}`);
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  try {
    run();
  } catch (error) {
    console.error(error.message);
    process.exitCode = 1;
  }
}
