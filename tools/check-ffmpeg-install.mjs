import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

export const root = fileURLToPath(new URL('..', import.meta.url));
export const workflowsDirectory = path.join(root, '.github/workflows');
export const actionDirectory = path.join(root, '.github/actions/install-ffmpeg');
export const actionFile = path.join(actionDirectory, 'action.yml');
export const installFile = path.join(actionDirectory, 'install.ps1');
export const probeFile = path.join(root, 'tools/probe-native-version.ps1');
export const probeTestFile = path.join(root, 'tools/probe-native-version.test.ps1');
export const actionUse = './.github/actions/install-ffmpeg';

const directInstall = /(?:choco\s+install\s+ffmpeg\b|apt-get\s+[^\n]*install[^\n]*\bffmpeg\b|apt\s+install[^\n]*\bffmpeg\b|brew\s+install\s+ffmpeg\b|winget\s+install[^\n]*ffmpeg\b|scoop\s+install[^\n]*ffmpeg\b)/i;
const pinnedVersion = /^\s*default:\s*'?\d+\.\d+\.\d+'?\s*$/m;
const nativePipeline = /&\s*\(?[^\n|]*\|\s*(?:Select-Object|select)\s+-First\b/;

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

export function nativeFirstLineProblems(files) {
  const problems = [];
  for (const [file, source] of Object.entries(files)) {
    for (const [index, line] of source.split(/\r?\n/).entries()) {
      if (!nativePipeline.test(line)) continue;
      problems.push(`${file}:${index + 1}: pipes a native program into Select-Object -First, so PowerShell never waits for it and the exit code is not recorded; run it with tools/probe-native-version.ps1`);
    }
  }
  return problems;
}

export function actionProblems(files) {
  const problems = [];
  const action = files['action.yml'] || '';
  const install = files['install.ps1'] || '';
  if (!pinnedVersion.test(action)) {
    problems.push(`${actionFile}: does not declare a pinned default version, so a runner can install an untested FFmpeg`);
  }
  if (!/uses:\s*actions\/cache@[0-9a-f]{40}/.test(action)) {
    problems.push(`${actionFile}: does not cache the install, so every run repeats the download that fails`);
  }
  if (!/run:\s*\.\/\.github\/actions\/install-ffmpeg\/install\.ps1/.test(action)) {
    problems.push(`${actionFile}: does not run install.ps1, so the install it verifies is not the install under test`);
  }
  if (!/GyanD\/codexffmpeg\/releases\/download\/\$pinned\/ffmpeg-\$pinned-essentials_build\.zip/.test(install)) {
    problems.push(`${installFile}: does not download the pinned release archive, so a package mirror outage or a different build decides what the journeys run`);
  }
  if (!/Get-FileHash[^\n]*-Algorithm SHA256/.test(install)) {
    problems.push(`${installFile}: does not hash the downloaded archive, so a corrupted or replaced download still passes`);
  }
  if (!/if \(\$actual -ne \$sourceSha\)/.test(install)) {
    problems.push(`${installFile}: does not refuse an archive whose checksum disagrees with the pin`);
  }
  if (!/Invoke-NativeVersionProbe/.test(install) || !/probe-native-version\.ps1/.test(install)) {
    problems.push(`${installFile}: reads the version without tools/probe-native-version.ps1, so a program that never ran the version check decides the install`);
  }
  if (/\$LASTEXITCODE/.test(install)) {
    problems.push(`${installFile}: reads a version through $LASTEXITCODE, which PowerShell leaves unset when a cmdlet stops a native program`);
  }
  if (!/apt-get install -y ffmpeg/.test(action)) {
    problems.push(`${actionFile}: does not install FFmpeg on Linux`);
  }
  if (!/-le \$limit/.test(install) || !/Start-Sleep -Seconds/.test(install) || !/sleep "\$delay"/.test(action)) {
    problems.push(`${actionFile}: does not retry the download a few times with backoff`);
  }
  if (!/install failed after \$limit attempts/.test(install) || !/exit 1/.test(action)) {
    problems.push(`${actionFile}: does not fail the step once the retries run out`);
  }
  if (!/does not run; installing a fresh copy/.test(install)) {
    problems.push(`${actionFile}: trusts a restored cache without checking it runs, so one bad cache entry fails every journey until the key changes`);
  }
  return problems;
}

export function probeProblems(source) {
  const problems = [];
  if (!/Start-Process[^\n]*-RedirectStandardOutput/.test(source) || !/Start-Process[^\n]*-RedirectStandardError/.test(source)) {
    problems.push(`${probeFile}: does not keep the stdout and stderr of the program it runs`);
  }
  if (!/WaitForExit\(\)/.test(source) || !/\$process\.ExitCode/.test(source)) {
    problems.push(`${probeFile}: does not wait for the program and read its own exit code`);
  }
  if (/\$LASTEXITCODE/.test(source)) {
    problems.push(`${probeFile}: reads a version through $LASTEXITCODE, which PowerShell leaves unset when a cmdlet stops a native program`);
  }
  return problems;
}

export function probeTestProblems(source) {
  const problems = [];
  const lines = source.split(/\r?\n/).filter(line => line.trim().length > 0);
  const last = lines.length ? lines[lines.length - 1].trim() : '';
  if (!/^exit\s+\d+$/.test(last)) {
    problems.push(`${probeTestFile}: does not end with an explicit exit code, so the nonzero exit of the programs it deliberately runs becomes the step result`);
  }
  if (!/ExitCode -ne 3/.test(source)) {
    problems.push(`${probeTestFile}: no longer proves a nonzero program exit is reported as nonzero`);
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

export function readAction() {
  return {
    'action.yml': fs.readFileSync(actionFile, 'utf8'),
    'install.ps1': fs.readFileSync(installFile, 'utf8'),
  };
}

export function checkFfmpegInstall(files, action = readAction(), probe = fs.readFileSync(probeFile, 'utf8'), probeTest = fs.readFileSync(probeTestFile, 'utf8')) {
  const sources = { ...files, ...Object.fromEntries(Object.entries(action).map(([name, source]) => [`.github/actions/install-ffmpeg/${name}`, source])) };
  return [
    ...directInstalls(files),
    ...unpinnedCalls(files),
    ...nativeFirstLineProblems(sources),
    ...actionProblems(action),
    ...probeProblems(probe),
    ...probeTestProblems(probeTest),
  ];
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const problems = checkFfmpegInstall(readWorkflows(process.argv[2]));
  if (problems.length) {
    console.error(problems.join('\n'));
    process.exitCode = 1;
  } else {
    console.log('Every journey installs the pinned FFmpeg through the cached, retried action, reads its version from the real process, and owns its own exit code');
  }
}
