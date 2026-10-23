import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const mainPath = 'src/main.zig';
const changelogPath = 'src/changelog.zig';
const versionLine = /^pub const APP_VERSION = "(\d+)\.(\d+)\.(\d+)";$/m;
const changelogStart = 'pub const CHANGELOG = [_]ChangelogEntry{';
export const fixHint = 'add changelog.d/<TICKET>-<slug>.md instead; the version is stamped after merge (node tools/version-stamp.mjs release)';

export function stampTree(files) {
  const removed = Object.keys(files).filter(file => file.startsWith('changelog.d/') && file !== 'changelog.d/README.md').sort();
  if (!removed.length) return null;
  const current = files[mainPath]?.match(versionLine);
  if (!current) throw new Error('Expected one APP_VERSION line in src/main.zig');
  const version = `${current[1]}.${current[2]}.${BigInt(current[3]) + 1n}`;
  const tickets = [];
  const bullets = [];
  const escape = text => text.replaceAll('\\', '\\\\').replaceAll('"', '\\"').replaceAll('\t', '\\t');
  for (const file of removed) {
    const match = /^changelog\.d\/([A-Z][A-Z0-9]*-\d+)-([^/]+)\.md$/.exec(file);
    if (!match) throw new Error(`Bad fragment filename: ${file}`);
    const lines = files[file].split(/\r?\n/).map(line => line.trim()).filter(Boolean);
    if (!lines.length) throw new Error(`Fragment has no text: ${file}`);
    if (!tickets.includes(match[1])) tickets.push(match[1]);
    bullets.push(...lines.map(text => `        .{ .text = "${escape(text)}", .ticket = "${match[1]}" },`));
  }
  if (!files[changelogPath]?.includes(changelogStart)) throw new Error('Missing CHANGELOG in src/changelog.zig');
  const result = { ...files };
  result[mainPath] = files[mainPath].replace(versionLine, `pub const APP_VERSION = "${version}";`);
  result[changelogPath] = files[changelogPath].replace(changelogStart, () => `${changelogStart}\n    .{ .ver = "${version}", .items = &.{\n${bullets.join('\n')}\n    } },`);
  for (const file of removed) delete result[file];
  return { version, tickets, files: result, removed };
}

export function classifyTrees(base, head, changed) {
  const kept = Object.keys(base).filter(file => file.startsWith('changelog.d/') && file in head);
  const folded = { ...base };
  for (const file of kept) delete folded[file];
  let stamp;
  try { stamp = stampTree(folded); } catch {}
  if (stamp) for (const file of kept) stamp.files[file] = base[file];
  if (stamp && changed.length && changed.every(file => file === mainPath || file === changelogPath || stamp.removed.includes(file) && !(file in head))) {
    const paths = new Set([...Object.keys(stamp.files), ...Object.keys(head)]);
    if ([...paths].every(file => stamp.files[file] === head[file])) return 'STAMP';
  }
  const lines = (tree, file, pattern) => (tree[file] || '').split(/\r?\n/).filter(line => pattern.test(line));
  if (JSON.stringify(lines(base, mainPath, /\bAPP_VERSION\s*=/)) !== JSON.stringify(lines(head, mainPath, /\bAPP_VERSION\s*=/)) ||
      JSON.stringify(lines(base, changelogPath, /\.ver = /)) !== JSON.stringify(lines(head, changelogPath, /\.ver = /))) return 'HAND_EDIT';
  return 'CODE';
}

function git(args, cwd, timeout) {
  return execFileSync('git', args, { cwd, encoding: 'utf8', maxBuffer: 64 * 1024 * 1024, timeout });
}

function readTree(rev, cwd, remaining) {
  const read = args => git(args, cwd, remaining?.());
  const names = read(['ls-tree', '-r', '--name-only', '-z', rev, '--', mainPath, changelogPath, 'changelog.d/']).split('\0').filter(Boolean);
  return Object.fromEntries(names.map(file => [file, read(['show', `${rev}:${file}`])]));
}

function check(baseRev, headRev) {
  const base = readTree(baseRev);
  const head = readTree(headRev);
  const changed = git(['diff', '--name-only', '-z', baseRev, headRev]).split('\0').filter(Boolean);
  const kind = classifyTrees(base, head, changed);
  if (kind === 'HAND_EDIT') {
    const diff = git(['diff', '--no-ext-diff', '--unified=0', baseRev, headRev, '--', mainPath, changelogPath]);
    console.error(diff.split(/\r?\n/).filter(line => /^[+-](?![+-])/.test(line) && (/\bAPP_VERSION\s*=/.test(line) || /\.ver = /.test(line))).join('\n'));
    console.error(fixHint);
  }
  if (process.env.GITHUB_OUTPUT) fs.appendFileSync(process.env.GITHUB_OUTPUT, `kind=${kind}\n`);
  console.log(kind);
  return kind === 'HAND_EDIT' ? 1 : 0;
}

async function release() {
  const root = git(['rev-parse', '--show-toplevel']).trim();
  const deadline = Date.now() + 45 * 60 * 1000;
  const remaining = () => {
    const left = deadline - Date.now();
    if (left <= 0) throw new Error('Release timed out after 45 minutes');
    return left;
  };
  const runGit = (args, cwd = root) => git(args, cwd, remaining());
  const gh = args => execFileSync('gh', args, { cwd: root, encoding: 'utf8', timeout: remaining(), stdio: ['ignore', 'pipe', 'inherit'] }).trim();
  const pollMs = Number(process.env.VERSION_STAMP_POLL_MS || 20000);
  const wait = async () => {
    await new Promise(resolve => setTimeout(resolve, Math.min(pollMs, remaining())));
    remaining();
  };
  while (true) {
    runGit(['fetch', 'origin', 'master']);
    const open = JSON.parse(gh(['pr', 'list', '--state', 'open', '--search', 'head:release/', '--json', 'number,url']));
    if (open.length) {
      const pr = open[0];
      console.log(pr.url);
      let greenNames;
      let mergeRequested = false;
      while (true) {
        const { state, statusCheckRollup } = JSON.parse(gh(['pr', 'view', String(pr.number), '--json', 'state,statusCheckRollup']));
        if (state === 'MERGED') break;
        if (state === 'CLOSED') throw new Error(`Release PR closed without merging: ${pr.url}`);
        const failed = (statusCheckRollup || []).filter(c => ['FAILURE', 'CANCELLED', 'TIMED_OUT', 'ERROR'].includes(c.conclusion || c.state));
        if (failed.length) throw new Error(`Release PR check failed (${failed.map(c => c.name || c.context).join(', ')}): ${pr.url}`);
        const checks = statusCheckRollup || [];
        const names = state === 'OPEN' && checks.length && checks.every(c => c.__typename === 'CheckRun' ? c.status === 'COMPLETED' && ['SUCCESS', 'SKIPPED', 'NEUTRAL'].includes(c.conclusion) : c.__typename === 'StatusContext' && c.state === 'SUCCESS') ? JSON.stringify([...new Set(checks.map(c => c.name || c.context))].sort()) : null;
        if (names && names === greenNames && !mergeRequested) {
          gh(['pr', 'merge', String(pr.number), '--squash', '--delete-branch']);
          mergeRequested = true;
        }
        greenNames = names;
        await wait();
      }
      continue;
    }
    const base = readTree('origin/master', root, remaining);
    const stamp = stampTree(base);
    if (!stamp) {
      console.log(`NOTHING_TO_STAMP ${base[mainPath].match(versionLine)?.slice(1).join('.')}`);
      return;
    }
    const temp = fs.mkdtempSync(path.join(os.tmpdir(), 'version-stamp-'));
    const tree = path.join(temp, 'tree');
    const branch = `release/${stamp.version}`;
    try {
      runGit(['worktree', 'add', '--detach', tree, 'origin/master']);
      for (const file of [mainPath, changelogPath]) fs.writeFileSync(path.join(tree, file), stamp.files[file]);
      runGit(['rm', '--', ...stamp.removed], tree);
      runGit(['add', '--', mainPath, changelogPath], tree);
      const title = `v${stamp.version}: release ${stamp.tickets.join(', ')}`;
      runGit(['commit', '-m', title], tree);
      try {
        runGit(['push', 'origin', `HEAD:refs/heads/${branch}`], tree);
      } catch (error) {
        if (/non-fast-forward|fetch first|already exists/.test(String(error.stderr)) && runGit(['ls-remote', '--heads', 'origin', `refs/heads/${branch}`]).trim()) {
          continue;
        }
        throw error;
      }
      const url = gh(['pr', 'create', '--base', 'master', '--head', branch, '--title', title, '--body', 'Stamped by tools/version-stamp.mjs from changelog.d.']);
      console.log(url);
      try {
        execFileSync('gh', ['pr', 'merge', url, '--squash', '--auto', '--delete-branch'], { cwd: root, encoding: 'utf8', timeout: remaining(), stdio: ['ignore', 'pipe', 'pipe'] });
      } catch (error) {
        if (error.stderr) process.stderr.write(error.stderr);
        if (!/auto.?merge is not allowed|not allowed for this repository|enablePullRequestAutoMerge/i.test(`${error.stderr || ''}\n${error.message}`)) throw error;
      }
    } finally {
      try {
        if (fs.existsSync(tree)) git(['worktree', 'remove', '--force', tree], root, 60000);
      } finally {
        fs.rmSync(temp, { recursive: true, force: true });
      }
    }
  }
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  try {
    const [command, base, head, ...extra] = process.argv.slice(2);
    if (command === 'check' && base && head && !extra.length) process.exitCode = check(base, head);
    else if (command === 'release' && !base) await release();
    else throw new Error('Usage: node tools/version-stamp.mjs check <base> <head> | release');
  } catch (error) {
    console.error(error.message);
    process.exitCode = 1;
  }
}
