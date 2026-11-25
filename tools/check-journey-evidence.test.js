import { test } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import { checkJourneyEvidence, readWorkflows, root, workflowsDirectory } from './check-journey-evidence.mjs';

const verify = () => fs.readFileSync(path.join(workflowsDirectory, 'verify.yml'), 'utf8');
const durableUpload = 'if: always()\n        uses: actions/upload-artifact@ea165f8d65b6e75b540449e92b4886f43607fa02\n        with:\n          name: verify-${{ matrix.feature }}';

test('every checked-in journey evidence upload survives failure', () => {
  assert.deepEqual(checkJourneyEvidence(readWorkflows()), []);
});

test('a journey evidence upload without if: always() fails', () => {
  const broken = verify().replace(durableUpload, durableUpload.replace('if: always()', 'if: success()'));
  assert.notEqual(broken, verify(), 'the durable evidence upload moved; update this control');
  const problems = checkJourneyEvidence({ '.github/workflows/verify.yml': broken });
  assert.equal(problems.length, 1, problems.join('\n'));
  assert.match(problems[0], /verify\.yml:\d+ \(job verify, evidence\/\): uploads journey evidence without if: always\(\)/);
});

test('an evidence upload whose if: line is gone entirely fails', () => {
  const broken = verify().replace(durableUpload, durableUpload.replace(/^.*if: always\(\)\n/m, ''));
  const problems = checkJourneyEvidence({ '.github/workflows/verify.yml': broken });
  assert.match(problems.join('\n'), /uploads journey evidence without if: always\(\)/);
});

test('removing evidence before its upload fails', () => {
  const removal = '      - name: Tidy before upload\n        run: Remove-Item evidence -Recurse -Force\n';
  const broken = verify().replace('      - name: Upload durable verification evidence', `${removal}      - name: Upload durable verification evidence`);
  assert.notEqual(broken, verify(), 'the durable evidence upload moved; update this control');
  const problems = checkJourneyEvidence({ '.github/workflows/verify.yml': broken });
  assert.equal(problems.length, 1, problems.join('\n'));
  assert.match(problems[0], /removes evidence before the upload/);
});

test('an evidence upload that also requires success() fails', () => {
  for (const condition of ['always() && success()', 'always() && !cancelled()']) {
    const broken = verify().replace(durableUpload, durableUpload.replace('if: always()', `if: ${condition}`));
    assert.notEqual(broken, verify(), 'the durable evidence upload moved; update this control');
    const problems = checkJourneyEvidence({ '.github/workflows/verify.yml': broken });
    assert.equal(problems.length, 1, problems.join('\n'));
    assert.match(problems[0], /skips the upload when the run fails or is cancelled/);
  }
});

test('removing a screenshot named by a plain path before its upload fails', () => {
  const source = [
    'jobs:',
    '  journey:',
    '    steps:',
    '      - name: Drive',
    '        run: ./drive.ps1',
    '      - name: Tidy',
    '        run: Remove-Item output/proof.png -Force',
    '      - if: always()',
    '        uses: actions/upload-artifact@ea165f8d65b6e75b540449e92b4886f43607fa02',
    '        with:',
    '          name: proof',
    '          path: output/proof.png',
    '',
  ].join('\n');
  const problems = checkJourneyEvidence({ '.github/workflows/journey.yml': source });
  assert.equal(problems.length, 1, problems.join('\n'));
  assert.match(problems[0], /removes output\/proof\.png before the upload/);
});

test('removing an evidence subdirectory before its upload fails', () => {
  const removal = '      - name: Drop old screenshots\n        run: rm -rf evidence/negative\n';
  const broken = verify().replace('      - name: Upload durable verification evidence', `${removal}      - name: Upload durable verification evidence`);
  assert.match(checkJourneyEvidence({ '.github/workflows/verify.yml': broken }).join('\n'), /removes evidence\/negative before the upload/);
});

test('removing evidence after the upload is allowed', () => {
  const removal = '      - name: Tidy after upload\n        run: Remove-Item evidence -Recurse -Force\n';
  const source = verify().replace('  tmux-identity-semantics:\n', `${removal}\n  tmux-identity-semantics:\n`);
  assert.notEqual(source, verify(), 'the verify job moved; update this control');
  assert.deepEqual(checkJourneyEvidence({ '.github/workflows/verify.yml': source }), []);
});

test('build products and page keys may upload without if: always()', () => {
  const source = [
    'jobs:',
    '  build:',
    '    steps:',
    '      - uses: actions/upload-artifact@ea165f8d65b6e75b540449e92b4886f43607fa02',
    '        with:',
    '          name: app',
    '          path: zig-out/bin/',
    '',
  ].join('\n');
  assert.deepEqual(checkJourneyEvidence({ '.github/workflows/build.yml': source }), []);
});

test('a cancelled run keeps its always() journey evidence upload', () => {
  const source = [
    'jobs:',
    '  journey:',
    '    steps:',
    '      - name: Drive',
    '        run: ./drive.ps1',
    '      - if: always()',
    '        uses: actions/upload-artifact@ea165f8d65b6e75b540449e92b4886f43607fa02',
    '        with:',
    '          name: proof',
    '          path: |',
    '            evidence/result.json',
    '            evidence/before.png',
    '',
  ].join('\n');
  assert.deepEqual(checkJourneyEvidence({ '.github/workflows/journey.yml': source }), []);
});

test('removing journey.mp4 before its upload fails', () => {
  const source = [
    'jobs:',
    '  journey:',
    '    steps:',
    '      - name: Drive',
    '        run: ./drive.ps1',
    '      - name: Tidy',
    '        run: Remove-Item output/journey.mp4 -Force',
    '      - if: always()',
    '        uses: actions/upload-artifact@ea165f8d65b6e75b540449e92b4886f43607fa02',
    '        with:',
    '          name: proof',
    '          path: output/journey.mp4',
    '',
  ].join('\n');
  const problems = checkJourneyEvidence({ '.github/workflows/journey.yml': source });
  assert.equal(problems.length, 1, problems.join('\n'));
  assert.match(problems[0], /removes output\/journey\.mp4 before the upload/);
});

test('gating FFmpeg install or bypassing drive.ps1 in verify.yml fails', () => {
  const gatedFfmpeg = verify().replace(
    '      - name: Install journey video recorder\n        uses: ./.github/actions/install-ffmpeg',
    "      - name: Install journey video recorder\n        if: env.FEATURE == 'appearance'\n        uses: ./.github/actions/install-ffmpeg",
  );
  assert.notEqual(gatedFfmpeg, verify());
  assert.match(checkJourneyEvidence({ '.github/workflows/verify.yml': gatedFfmpeg }).join('\n'), /installs FFmpeg conditionally/);

  const bypassedDrive = verify().replace(
    '& .claude/skills/verify-multiprompt/drive.ps1 -Feature $env:FEATURE',
    '& .claude/skills/verify-multiprompt/control.ps1 -Feature $env:FEATURE',
  );
  assert.notEqual(bypassedDrive, verify());
  assert.match(checkJourneyEvidence({ '.github/workflows/verify.yml': bypassedDrive }).join('\n'), /bypassing journey\.mp4 recording/);
});

test('the CLI fails on a broken workflow directory and passes on the real one', () => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'journey-evidence-'));
  try {
    fs.writeFileSync(path.join(directory, 'journey.yml'), verify().replace(durableUpload, durableUpload.replace('if: always()', 'if: success()')));
    const broken = spawnSync(process.execPath, [path.join(root, 'tools/check-journey-evidence.mjs'), directory], { encoding: 'utf8' });
    assert.equal(broken.status, 1, broken.stdout + broken.stderr);
    assert.match(broken.stderr, /uploads journey evidence without if: always\(\)/);
  } finally {
    fs.rmSync(directory, { recursive: true, force: true });
  }
  const green = spawnSync(process.execPath, [path.join(root, 'tools/check-journey-evidence.mjs')], { encoding: 'utf8' });
  assert.equal(green.status, 0, green.stdout + green.stderr);
  assert.match(green.stdout, /Journey evidence uploads survive failure and cancellation/);
});
