const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const assert = require('node:assert/strict');

const root = path.join(__dirname, '..');
const skill = '.claude/skills/verify-multiprompt/';
const stems = [
  'mb-tab-open', 'mb-tab-close', 'mb-tab-move', 'mb-tab-pin', 'mb-tab-unpin',
  'mb-tab-archive', 'mb-tab-unarchive', 'mb-tab-wait', 'mb-tab-restore',
  'mb-tab-layout-sync', 'mb-tab-idempotent',
];

test('SOFT-3142 every mb tab stem is registered and mapped', () => {
  const control = fs.readFileSync(path.join(root, skill, 'control.ps1'), 'utf8');
  const driver = fs.readFileSync(path.join(root, skill, 'control-feature-mb-tab-verbs.ps1'), 'utf8');
  const { discoverFeatures } = require('./verify-features.cjs');
  const available = discoverFeatures(path.join(root, skill, 'features')).available;
  for (const stem of stems) {
    assert.match(control, new RegExp(`'${stem}'`), `${stem} must be in control.ps1 ValidateSet`);
    assert.ok(available.includes(stem), `${stem} must be an available journey`);
    const map = fs.readFileSync(path.join(root, skill, 'features', `${stem}.md`), 'utf8');
    assert.match(map, /^Source files: /m);
    assert.match(map, /tools\/mp-layout\.mjs/);
    if (stem === 'mb-tab-layout-sync') assert.match(map, /session_layout_sync\.zig/);
    assert.match(map, /control-feature-mb-tab-verbs\.ps1/);
    assert.match(map, /^## Driving it with control\.ps1$/m);
  }
  assert.match(control, /if \(\$Feature -match '\^mb-tab-'\) \{[\s\S]*control-feature-mb-tab-verbs\.ps1/);
  assert.match(driver, /throw "Journey condition not met:/);
  assert.match(driver, /Join-Path \$Evidence 'result\.json'/);
  assert.match(driver, /Join-Path \$Evidence 'before\.png'/);
  assert.match(driver, /Join-Path \$Evidence 'after\.png'/);
  assert.match(driver, /function Assert-MbTabVerbLine/);
  assert.match(driver, /@\('pin', \$MbTabSession, '--host', '0'\)/);
  assert.match(driver, /@\('unpin', \$MbTabSession, '--host', '0'\)/);
  assert.match(driver, /@\('wait', \$MbTabSession, '--host', '0'\)/);
  assert.match(driver, /@\('restore', \$MbTabSession, '--host', '0'\)/);
  assert.match(driver, /@\('archive', \$MbTabSession, '--host', '0'\)/);
  assert.doesNotMatch(driver, /'pin', \$MbTabSession, 'on'/);
  assert.doesNotMatch(driver, /'wait', \$MbTabSession, 'on'/);
  assert.match(driver, /'--no-tmux'/);
  assert.match(driver, /tunnel-inbound listening port=\(\\d\+\) err=0/);
  assert.match(driver, /function Assert-MbTabZsbBeforeVerb/);
  assert.match(driver, /Invoke-MbTabStandInZsb @\('workspace-list'\)/);
  assert.match(driver, /Invoke-MbTabStandInZsb @\('pc-state'\)/);
  assert.match(driver, /pc_state_pr1312/);
  assert.match(driver, /function Invoke-MbTabStandInNode/);
  assert.match(driver, /src\/mp_zsb\.sh/);
  assert.match(driver, /function Resolve-MbTabZsbPath/);
  assert.match(driver, /function Build-MbTabZsbProbeArgv/);
  assert.match(driver, /function New-MbTabStandInProcessStartInfo/);
  assert.match(driver, /\.stdout\.txt/);
  assert.match(driver, /\.stderr\.txt/);
  assert.match(driver, /\.cmdline\.txt/);
  assert.match(driver, /\.exit\.txt/);
  assert.doesNotMatch(driver, /Start-Process -FilePath \$script:MbTabBash -ArgumentList @\('--noprofile', '--norc', '-c'/);
  assert.match(driver, /return @\(\$script:MbTabZsbPath\) \+ @\(\$ZsbArgs\)/);
  assert.match(driver, /'probe' \+ \$script:MbTabZsbOrdinal/);
  const { touchedJourneys } = require('./touched-journeys.cjs');
  const picked = touchedJourneys(['src/session_layout_sync.zig'], path.join(root, skill, 'features'));
  assert.deepEqual(picked.features, ['mb-tab-layout-sync']);
  const workflow = fs.readFileSync(path.join(root, '.github/workflows/verify.yml'), 'utf8');
  const drive = fs.readFileSync(path.join(root, skill, 'drive.ps1'), 'utf8');
  assert.match(workflow, /Install browser toggle recorder[\s\S]*startsWith\(env\.FEATURE, 'mb-tab-'\)/);
  assert.match(workflow, /startsWith\(env\.FEATURE, 'mb-tab-'\)[^\n]*\n\s+uses: \.\/\.github\/actions\/install-ffmpeg/);
  assert.match(workflow, /uses: actions\/setup-node[\s\S]*startsWith\(env\.FEATURE, 'mb-tab-'\)/);
  assert.match(workflow, /name: Build the test account service[\s\S]*startsWith\(env\.FEATURE, 'mb-tab-'\)/);
  assert.match(drive, /Resolve-DriveRecorder 'ffmpeg\.exe'/);
  assert.match(drive, /Resolve-DriveRecorder 'ffprobe\.exe'/);
  assert.match(driver, /Resolve-MbTabExecutable 'node\.exe'/);
  assert.match(driver, /Resolve-MbTabExecutable 'npm\.cmd'/);
  const mbTabRecorderIf = workflow.match(/name: Install browser toggle recorder\n\s+if: ([^\n]+)/)[1];
  assert.ok(mbTabRecorderIf.includes("startsWith(env.FEATURE, 'mb-tab-')"), 'ffmpeg install must cover mb-tab journeys');
  const setupNodeBlocks = [...workflow.matchAll(/uses: actions\/setup-node@[^\n]+\n\s+if: ([^\n]+)/g)];
  assert.ok(setupNodeBlocks.some(block => block[1].includes("startsWith(env.FEATURE, 'mb-tab-')")), 'Node setup must cover mb-tab journeys');
});