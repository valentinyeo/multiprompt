import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

export const root = fileURLToPath(new URL('..', import.meta.url));
export const workflowsDirectory = path.join(root, '.github/workflows');
export const actionFile = path.join(root, '.github/actions/install-ffmpeg/action.yml');
export const actionUse = './.github/actions/install-ffmpeg';

const directInstall = /(?:choco\s+install\s+ffmpeg\b|apt-get\s+[^\n]*install[^\n]*\bffmpeg\b|apt\s+install[^\n]*\bffmpeg\b|brew\s+install\s+ffmpeg\b|winget\s+install[^\n]*ffmpeg\b|scoop\s+install\s+ffmpeg\b)/i;
const pinnedVersion = /^\s*default:\s*'?\d+\.\d+\.\d+'?\s*$/m;

export function directInstalls(files) {
  const problems = [];
  for (const [file, source] of Object.entries(files)) {
    for (const [index, line] of source.split(/\r?\n/).entries()) {
      if (!directInstall.test(line) || /^\s*#/.test(line)) continue;
      problems.push(`${file}:${index + 1}: installs FFmpeg inline instead of ${actionUse}, so one failed download fails the whole journey`);
    }
  }
  return problems;
}

export function unpinnedCalls(files) {
  const problems = [];
  for (const [file, source] of Object.entries(files)) {
    const lines = source.split(/\r?\n/);
    for (const [index, line] of lines.entries()) {
      const dash = /^(\s*)-\s+uses:\s*\.\/\.github\/actions\/install-ffmpeg\s*$/.exec(line);
      const plain = /^(\s*)uses:\s*\.\/\.github\/actions\/install-ffmpeg\s*$/.exec(line);
      const uses = dash || plain;
      if (!uses) continue;
      const minimum = uses[1].length + (dash ? 1 : 0);
      const block = [];
      for (const next of lines.slice(index + 1)) {
        if (next.trim() && next.match(/^\s*/)[0].length < minimum) break;
        block.push(next);
      }
      if (!/^\s*version:\s*'?\d+\.\d+\.\d+'?\s*$/m.test(block.join('\n'))) {
        problems.push(`${file}:${index + 1}: ${actionUse} is called without a pinned version`);
      }
    }
  }
  return problems;
}

export function actionProblems(source) {
  const problems = [];
  if (!pinnedVersion.test(source)) {
    problems.push(`${actionFile}: does not declare a pinned default version, so a runner can install an untested FFmpeg`);
  }
  if (!/uses:\s*actions\/cache@[0-9a-f]{40}/.test(source)) {
    problems.push(`${actionFile}: does not cache the install, so every run repeats the download that fails`);
  }
  if (!/GyanD\/codexffmpeg\/releases\/download\/\$pinned\/ffmpeg-\$pinned-essentials_build\.zip/.test(source)) {
    problems.push(`${actionFile}: does not download the pinned release archive, so a package mirror outage or a different build decides what the journeys run`);
  }
  if (!/Get-FileHash[^\n]*-Algorithm SHA256/.test(source)) {
    problems.push(`${actionFile}: does not hash the downloaded archive, so a corrupted or replaced download still passes`);
  }
  if (!/if \(\$actual -ne \$sourceSha\)/.test(source)) {
    problems.push(`${actionFile}: does not refuse an archive whose checksum disagrees with the pin`);
  }
  if (!/apt-get install -y ffmpeg/.test(source)) {
    problems.push(`${actionFile}: does not install FFmpeg on Linux`);
  }
  if (!/-le \$limit/.test(source) || !/Start-Sleep -Seconds/.test(source) || !/sleep "\$delay"/.test(source)) {
    problems.push(`${actionFile}: does not retry the download a few times with backoff`);
  }
  if (!/install failed after \$limit attempts/.test(source) || !/exit 1/.test(source)) {
    problems.push(`${actionFile}: does not fail the step once the retries run out`);
  }
  if (!/does not run; installing a fresh copy/.test(source)) {
    problems.push(`${actionFile}: trusts a restored cache without checking it runs, so one bad cache entry fails every journey until the key changes`);
  }
  return problems;
}

export function readWorkflows(directory = workflowsDirectory) {
  const files = {};
  for (const name of fs.readdirSync(directory).sort()) {
    if (!/\.ya?ml$/.test(name)) continue;
    files[`.github/workflows/${name}`] = fs.readFileSync(path.join(directory, name), 'utf8');
  }
  return files;
}

export function checkFfmpegInstall(files, action) {
  return [...directInstalls(files), ...unpinnedCalls(files), ...actionProblems(action)];
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const problems = checkFfmpegInstall(readWorkflows(process.argv[2]), fs.readFileSync(actionFile, 'utf8'));
  if (problems.length) {
    console.error(problems.join('\n'));
    process.exitCode = 1;
  } else {
    console.log('Every journey installs the pinned FFmpeg through the cached, retried action');
  }
}
