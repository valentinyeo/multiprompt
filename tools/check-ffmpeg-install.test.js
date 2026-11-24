import { test } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import { actionFile, checkFfmpegInstall, readWorkflows } from './check-ffmpeg-install.mjs';

const action = () => fs.readFileSync(actionFile, 'utf8');
const call = `      - name: Install FFmpeg
        uses: ./.github/actions/install-ffmpeg
        with:
          version: '7.1.1'
`;

test('every checked-in journey installs FFmpeg through the retried action', () => {
  assert.deepEqual(checkFfmpegInstall(readWorkflows(), action()), []);
});

test('an inline chocolatey install fails', () => {
  const problems = checkFfmpegInstall({ '.github/workflows/journey.yml': `      - name: Install\n        run: choco install ffmpeg --version=7.1.1 --yes\n` }, action());
  assert.equal(problems.length, 1, problems.join('\n'));
  assert.match(problems[0], /journey\.yml:2: installs FFmpeg inline/);
});

test('an inline apt install fails', () => {
  const problems = checkFfmpegInstall({ '.github/workflows/journey.yml': `      - run: sudo apt-get update -qq && sudo apt-get install -y ffmpeg\n` }, action());
  assert.match(problems.join('\n'), /installs FFmpeg inline/);
});

test('a commented install is not a real install', () => {
  assert.deepEqual(checkFfmpegInstall({ '.github/workflows/journey.yml': `      - run: echo ok\n        # choco install ffmpeg\n` }, action()), []);
});

test('a call without a pinned version fails', () => {
  const broken = call.replace("        with:\n          version: '7.1.1'\n", '');
  const problems = checkFfmpegInstall({ '.github/workflows/journey.yml': broken }, action());
  assert.equal(problems.length, 1, problems.join('\n'));
  assert.match(problems[0], /called without a pinned version/);
});

test('a call with an unpinned version fails', () => {
  const broken = call.replace("version: '7.1.1'", 'version: latest');
  const problems = checkFfmpegInstall({ '.github/workflows/journey.yml': broken }, action());
  assert.match(problems.join('\n'), /called without a pinned version/);
});

test('a pinned call keeps the workflow clean', () => {
  assert.deepEqual(checkFfmpegInstall({ '.github/workflows/journey.yml': call }, action()), []);
});

test('a cached call does not swallow the next step', () => {
  const source = `${call}      - name: Next\n        run: echo ok\n`;
  assert.deepEqual(checkFfmpegInstall({ '.github/workflows/journey.yml': source }, action()), []);
});

test('an action without a retry fails', () => {
  const broken = action().replace(/    - name: Install FFmpeg\n      if: runner.os != 'Windows'[\s\S]*$/, '');
  assert.notEqual(broken, action(), 'the Linux install step moved; update this control');
  const problems = checkFfmpegInstall({}, broken);
  assert.match(problems.join('\n'), /does not retry the download/);
});

test('an action without a cache fails', () => {
  const broken = action().replace(/    - name: Restore cached FFmpeg[\s\S]*?key: [^\n]*\n/, '');
  assert.notEqual(broken, action(), 'the cache step moved; update this control');
  const problems = checkFfmpegInstall({}, broken);
  assert.match(problems.join('\n'), /does not cache the install/);
});

test('an action with an unpinned default version fails', () => {
  const broken = action().replace(/default: '7\.1\.1'/, "default: 'latest'");
  assert.notEqual(broken, action(), 'the default version moved; update this control');
  const problems = checkFfmpegInstall({}, broken);
  assert.match(problems.join('\n'), /does not declare a pinned default version/);
});

test('an action that never gives up fails', () => {
  const broken = action().replace(/throw "FFmpeg \$pinned install failed after \$limit attempts"/, "Write-Host 'gave up'").replace(/exit 1\n$/, 'exit 0\n');
  assert.notEqual(broken, action(), 'the failure path moved; update this control');
  const problems = checkFfmpegInstall({}, broken);
  assert.match(problems.join('\n'), /does not fail the step once the retries run out/);
});

test('an action that trusts a restored cache fails', () => {
  const broken = action().replace(/\n\s*\$cached = [^]*?installing a fresh copy"\n\s*Remove-Item -Recurse -Force -ErrorAction SilentlyContinue \$target\n/, '\n');
  assert.notEqual(broken, action(), 'the cache check moved; update this control');
  const problems = checkFfmpegInstall({}, broken);
  assert.match(problems.join('\n'), /trusts a restored cache without checking it runs/);
});
