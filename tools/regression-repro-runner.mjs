import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { execFileSync, spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { createRequire } from 'node:module';

const require = createRequire(import.meta.url);
const fixture = require('./regression-fixture.cjs');

function normalizePullRequest(pr) {
  if (!pr) return null;
  return {
    title: pr.title || '',
    body: pr.body || '',
    labels: (pr.labels || []).map(label => (typeof label === 'string' ? label : label.name)).filter(Boolean),
  };
}

function pullRequest() {
  const eventPath = process.env.GITHUB_EVENT_PATH;
  if (!eventPath || !fs.existsSync(eventPath)) return null;
  const event = JSON.parse(fs.readFileSync(eventPath, 'utf8'));
  if (!event.pull_request) return null;
  return normalizePullRequest(event.pull_request);
}

function pullRequestFile(file) {
  return normalizePullRequest(JSON.parse(fs.readFileSync(file, 'utf8')));
}

function runCommand(command, cwd, env = {}) {
  const result = spawnSync(command[0], command.slice(1), {
    cwd,
    env: { ...process.env, ...env },
    encoding: 'utf8',
    timeout: 600000,
  });
  return { status: result.status ?? 1, output: `${result.stdout || ''}${result.stderr || ''}` };
}

function copyFiles(files, fromRoot, toRoot) {
  for (const file of files) {
    const source = path.join(fromRoot, file);
    if (!fs.existsSync(source)) continue;
    const target = path.join(toRoot, file);
    fs.mkdirSync(path.dirname(target), { recursive: true });
    fs.copyFileSync(source, target);
  }
}

function ensureCommit(root, ref) {
  try {
    execFileSync('git', ['rev-parse', '--verify', `${ref}^{commit}`], { cwd: root, stdio: 'pipe' });
    return ref;
  } catch {
    execFileSync('git', ['fetch', '--depth', '1', 'origin', ref], { cwd: root, stdio: 'pipe' });
    return execFileSync('git', ['rev-parse', '--verify', `${ref}^{commit}`], { cwd: root, encoding: 'utf8' }).trim();
  }
}

export function runRegressionRepro({ root = '.', base, pr, headRoot = root }) {
  if (!fixture.isBugPullRequest(pr, root)) return null;
  const ticket = fixture.primaryTicket(pr);
  if (!ticket) return null;
  const manifest = fixture.readReproManifest(headRoot, ticket);
  if (!manifest) return null;
  const baseSha = ensureCommit(root, base);
  const carry = manifest.files.length
    ? manifest.files
    : [
        path.join(fixture.FIXTURE_ROOT, manifest.folder, fixture.REPRO_FILE),
        ...fixture.gitNames(base, `${base}...HEAD`, headRoot).filter(file => file.startsWith(`${fixture.FIXTURE_ROOT}/${manifest.folder}/`)),
      ];
  const headOut = runCommand(manifest.command, headRoot);
  const tempBase = fs.mkdtempSync(path.join(os.tmpdir(), 'regression-base-'));
  try {
    execFileSync('git', ['worktree', 'add', '--detach', tempBase, baseSha], { cwd: root });
    copyFiles(carry, headRoot, tempBase);
    const baseOut = runCommand(manifest.command, tempBase, { REGRESSION_REPRO_BASE: '1' });
    return {
      ticket: manifest.ticket,
      folder: manifest.folder,
      command: manifest.command.join(' '),
      base_exit_code: baseOut.status,
      head_exit_code: headOut.status,
      base_log: baseOut.output.slice(-4000),
      head_log: headOut.output.slice(-4000),
    };
  } finally {
    try {
      execFileSync('git', ['worktree', 'remove', '--force', tempBase], { cwd: root });
    } catch {
      fs.rmSync(tempBase, { recursive: true, force: true });
    }
  }
}

export function mergeSummary(summaryPath, row) {
  const summary = fs.existsSync(summaryPath) ? JSON.parse(fs.readFileSync(summaryPath, 'utf8')) : { head: {} };
  summary.fixtureRepro = row ? [row] : (summary.fixtureRepro || []);
  fs.writeFileSync(summaryPath, JSON.stringify(summary, null, 2));
  return summary;
}

export function auditPullRequest({ root = '.', base, pr }) {
  return fixture.checkBugFixtureErrors({ base, root, pr });
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const argv = process.argv.slice(2);
  const command = argv[0];
  if (!command || command === '--help') {
    console.error('Usage: node tools/regression-repro-runner.mjs run <base-ref> <summary.json> [--pr-json FILE]');
    console.error('       node tools/regression-repro-runner.mjs audit <base-ref> --title TITLE [--body BODY]');
    process.exit(2);
  }
  if (command === 'audit') {
    const titleIndex = argv.indexOf('--title');
    const bodyIndex = argv.indexOf('--body');
    const pr = {
      title: titleIndex >= 0 ? argv[titleIndex + 1] : '',
      body: bodyIndex >= 0 ? argv[bodyIndex + 1] : '',
      labels: [],
    };
    const errors = auditPullRequest({ root: '.', base: argv[1], pr });
    if (errors.length) {
      console.error(errors.join('\n'));
      process.exitCode = 1;
    } else console.log('Bug-fix fixture requirements satisfied');
  } else if (command === 'run') {
    const base = argv[1];
    const summaryPath = argv[2];
    const jsonIndex = argv.indexOf('--pr-json');
    const jsonArg = jsonIndex >= 0 ? argv[jsonIndex + 1] : '';
    const pr = pullRequest() || (jsonIndex >= 0
      ? (jsonArg.trimStart().startsWith('{')
        ? normalizePullRequest(JSON.parse(jsonArg))
        : pullRequestFile(jsonArg))
      : null);
    if (!base || !summaryPath || !pr) throw new Error('run needs base ref, summary path and pull request metadata');
    try {
      const row = runRegressionRepro({ root: '.', base, pr });
      mergeSummary(summaryPath, row);
      if (!row) {
        console.log('No failing-first repro scheduled for this pull request');
      } else {
        console.log(`fixture repro ticket=${row.ticket} base=${row.base_exit_code} head=${row.head_exit_code}`);
        if (!fixture.provenFixtureRepro(row)) console.error('fixture repro is not failing-first');
      }
    } catch (error) {
      console.error(error.message);
      process.exitCode = 1;
    }
  } else {
    console.error('Unknown command');
    process.exitCode = 2;
  }
}