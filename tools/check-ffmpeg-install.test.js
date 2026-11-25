import { test } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import { actionFile, checkFfmpegInstall, installFile, probeFile, readAction, readWorkflows } from './check-ffmpeg-install.mjs';

const action = () => readAction();
const probe = () => fs.readFileSync(probeFile, 'utf8');
const call = `      - name: Install FFmpeg
        uses: ./.github/actions/install-ffmpeg
        with:
          version: '7.1.1'
`;

test('every checked-in journey installs FFmpeg through the retried action', () => {
  assert.deepEqual(checkFfmpegInstall(readWorkflows(), action(), probe()), []);
});

test('an inline chocolatey install fails', () => {
  const problems = checkFfmpegInstall({ '.github/workflows/journey.yml': `      - name: Install\n        run: choco install ffmpeg --version=7.1.1 --yes\n` }, action(), probe());
  assert.equal(problems.length, 1, problems.join('\n'));
  assert.match(problems[0], /journey\.yml:2: installs FFmpeg inline/);
});

test('an inline apt install fails', () => {
  const problems = checkFfmpegInstall({ '.github/workflows/journey.yml': `      - run: sudo apt-get update -qq && sudo apt-get install -y ffmpeg\n` }, action(), probe());
  assert.match(problems.join('\n'), /installs FFmpeg inline/);
});

test('a commented install is not a real install', () => {
  assert.deepEqual(checkFfmpegInstall({ '.github/workflows/journey.yml': `      - run: echo ok\n        # choco install ffmpeg\n` }, action(), probe()), []);
});

test('a call without a pinned version fails', () => {
  const broken = call.replace("        with:\n          version: '7.1.1'\n", '');
  const problems = checkFfmpegInstall({ '.github/workflows/journey.yml': broken }, action(), probe());
  assert.equal(problems.length, 1, problems.join('\n'));
  assert.match(problems[0], /called without a pinned version/);
});

test('a call with an unpinned version fails', () => {
  const broken = call.replace("version: '7.1.1'", 'version: latest');
  const problems = checkFfmpegInstall({ '.github/workflows/journey.yml': broken }, action(), probe());
  assert.match(problems.join('\n'), /called without a pinned version/);
});

test('a pinned call keeps the workflow clean', () => {
  assert.deepEqual(checkFfmpegInstall({ '.github/workflows/journey.yml': call }, action(), probe()), []);
});

test('a cached call does not swallow the next step', () => {
  const source = `${call}      - name: Next\n        run: echo ok\n`;
  assert.deepEqual(checkFfmpegInstall({ '.github/workflows/journey.yml': source }, action(), probe()), []);
});

test('an action without a retry fails', () => {
  const files = action();
  const broken = files['action.yml'].replace(/    - name: Install FFmpeg\n      if: runner\.os != 'Windows'[\s\S]*$/, '');
  assert.notEqual(broken, files['action.yml'], 'the Linux install step moved; update this control');
  const problems = checkFfmpegInstall({}, { ...files, 'action.yml': broken }, probe());
  assert.match(problems.join('\n'), /does not retry the download/);
});

test('an action without a cache fails', () => {
  const files = action();
  const broken = files['action.yml'].replace(/    - name: Restore cached FFmpeg[\s\S]*?key: [^\n]*\n/, '');
  assert.notEqual(broken, files['action.yml'], 'the cache step moved; update this control');
  const problems = checkFfmpegInstall({}, { ...files, 'action.yml': broken }, probe());
  assert.match(problems.join('\n'), /does not cache the install/);
});

test('an action that inlines the Windows install fails', () => {
  const files = action();
  const broken = files['action.yml'].replace(/run: \.\/\.github\/actions\/install-ffmpeg\/install\.ps1/, `run: |\n        $ErrorActionPreference = 'Stop'\n        Invoke-WebRequest -Uri 'https://example.invalid/ffmpeg.zip' -OutFile ffmpeg.zip`);
  assert.notEqual(broken, files['action.yml'], 'the Windows install step moved; update this control');
  const problems = checkFfmpegInstall({}, { ...files, 'action.yml': broken }, probe());
  assert.match(problems.join('\n'), /does not run install\.ps1/);
});

test('an action without a pinned source version fails', () => {
  const files = action();
  const broken = files['install.ps1'].replace(/\$archive = "https:\/\/github\.com\/GyanD\/codexffmpeg\/releases\/download[^\n]*\n/, '$archive = "https://community.chocolatey.org/api/v2/"\n');
  assert.notEqual(broken, files['install.ps1'], 'the download source moved; update this control');
  const problems = checkFfmpegInstall({}, { ...files, 'install.ps1': broken }, probe());
  assert.match(problems.join('\n'), /does not download the pinned release archive/);
});

test('an action that skips the checksum fails', () => {
  const files = action();
  const broken = files['install.ps1'].replace(/\n\s*\$actual = \(Get-FileHash[^\n]*\n\s*if \(\$actual -ne \$sourceSha\)[^\n]*\n/, '\n');
  assert.notEqual(broken, files['install.ps1'], 'the checksum check moved; update this control');
  const problems = checkFfmpegInstall({}, { ...files, 'install.ps1': broken }, probe());
  assert.match(problems.join('\n'), /does not hash the downloaded archive/);
  assert.match(problems.join('\n'), /does not refuse an archive whose checksum disagrees with the pin/);
});

test('an action with an unpinned default version fails', () => {
  const files = action();
  const broken = files['action.yml'].replace(/default: '7\.1\.1'/, "default: 'latest'");
  assert.notEqual(broken, files['action.yml'], 'the default version moved; update this control');
  const problems = checkFfmpegInstall({}, { ...files, 'action.yml': broken }, probe());
  assert.match(problems.join('\n'), /does not declare a pinned default version/);
});

test('an action that never gives up fails', () => {
  const files = action();
  const broken = files['install.ps1'].replace(/throw "FFmpeg \$pinned install failed after \$limit attempts"/, "Write-Host 'gave up'");
  const linux = files['action.yml'].replace(/exit 1\n$/, 'exit 0\n');
  assert.notEqual(broken, files['install.ps1'], 'the failure path moved; update this control');
  assert.notEqual(linux, files['action.yml'], 'the Linux failure path moved; update this control');
  const problems = checkFfmpegInstall({}, { ...files, 'install.ps1': broken, 'action.yml': linux }, probe());
  assert.match(problems.join('\n'), /does not fail the step once the retries run out/);
});

test('an action that trusts a restored cache fails', () => {
  const files = action();
  const broken = files['install.ps1'].replace(/\n\s*\$cached = [^]*?installing a fresh copy"\n\s*Remove-Item -Recurse -Force -ErrorAction SilentlyContinue \$target\n/, '\n');
  assert.notEqual(broken, files['install.ps1'], 'the cache check moved; update this control');
  const problems = checkFfmpegInstall({}, { ...files, 'install.ps1': broken }, probe());
  assert.match(problems.join('\n'), /trusts a restored cache without checking it runs/);
});

test('an install script that reads the version through a pipeline fails', () => {
  const files = action();
  const broken = files['install.ps1'].replace(/\$probe = Invoke-NativeVersionProbe[^\n]*\n/, "$first = (& $exe -version 2>$null | Select-Object -First 1)\n  if ($LASTEXITCODE -ne 0 -or -not $first) { throw 'the version never ran' }\n");
  assert.notEqual(broken, files['install.ps1'], 'the version check moved; update this control');
  const problems = checkFfmpegInstall({}, { ...files, 'install.ps1': broken }, probe());
  assert.match(problems.join('\n'), /reads a version through \$LASTEXITCODE/);
  assert.match(problems.join('\n'), /pipes a native program into Select-Object -First/);
});

test('a probe that drops the exit code fails', () => {
  const files = action();
  const broken = probe().replace(/\$process\.WaitForExit\(\)\n\s*\$exitCode = \$process\.ExitCode\n/, "$process.WaitForExit()\n        $exitCode = $LASTEXITCODE\n");
  assert.notEqual(broken, probe(), 'the exit code line moved; update this control');
  const problems = checkFfmpegInstall({}, files, broken);
  assert.match(problems.join('\n'), /does not wait for the program and read its own exit code/);
  assert.match(problems.join('\n'), /reads a version through \$LASTEXITCODE/);
});

test('a journey that pipes a program into a truncated pipeline fails', () => {
  const problems = checkFfmpegInstall({ '.github/workflows/journey.yml': `        run: $reader = (& $ocr --version 2>$null | Select-Object -First 1)\n` }, action(), probe());
  assert.match(problems.join('\n'), /journey\.yml:1: pipes a native program into Select-Object -First/);
});

test('the action reads its version through the shared process probe', () => {
  assert.match(fs.readFileSync(installFile, 'utf8'), /probe-native-version\.ps1/);
  assert.match(fs.readFileSync(actionFile, 'utf8'), /run: \.\/\.github\/actions\/install-ffmpeg\/install\.ps1/);
});
