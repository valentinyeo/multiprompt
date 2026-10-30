const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const root = path.resolve(__dirname, '..');
const read = file => fs.readFileSync(path.join(root, file), 'utf8');

function assertCardNotes(source) {
  assert.match(source, /for \(0\.\.shown\)/);
  assert.match(source, /card_notes\.line\(i\)/);
  assert.match(source, /DrawTextW/);
  assert.match(source, /card_notes\.more\(&more_buf, false\)/);
  assert.match(source, /\[update\] card view=\{s\} n=\{d\} first=\{s\}/);
  assert.match(source, /\[update\] card note \{d\}=\{s\}/);
  assert.match(source, /\[update\] card remaining=/);
  assert.match(source, /\[update\] more row=\{d\},\{d\}/);
  assert.match(source, /if \(cardHasToggle\(\) and ptInRect\(updateCardMoreRect\(card\), x, y\)\) return 4/);
}

test('release asset includes every historical version, plain lines only, and the offered version rather than embedded-only notes', async () => {
  const { releaseNotes } = await import('./release-notes.mjs');
  const { plainChange } = await import('./version-stamp.mjs');
  const source = read('src/changelog.zig');
  const versions = [...source.matchAll(/\.ver = "(\d+\.\d+\.\d+)"/g)].map(match => match[1]);
  const notes = releaseNotes(source, `v${versions[0]}`);
  assert.deepEqual(notes.releases.map(release => release.version), versions);
  assert.ok(Buffer.byteLength(JSON.stringify(notes)) < 1024 * 1024);
  assert.ok(notes.releases.every(release => release.changes.every(plainChange)));
  assert.ok(notes.releases[0].changes.length > 0);
  assert.equal(notes.version, versions[0]);
  assert.throws(() => releaseNotes(source, 'v99.0.0'), /offered version/);
});

test('publication exports pending fragments after the release fold and handles older Zig string escapes', async () => {
  const { releaseNotes } = await import('./release-notes.mjs');
  const { stampTree } = await import('./version-stamp.mjs');
  const changelog = 'pub const CHANGELOG = [_]ChangelogEntry{\n    .{ .ver = "0.28.900", .summary = "Old", .ticket = "", .items = &.{\n        .{ .text = "Opening browser\\u{2026}", .ticket = "" },\n        .{ .text = "Fix IGSH-123.", .ticket = "" },\n        .{ .text = "Fix src/main.zig.", .ticket = "" },\n        .{ .text = "Fix #12.", .ticket = "" },\n    } },\n};\n';
  const stamp = stampTree({
    'src/main.zig': 'pub const APP_VERSION = "0.28.900";\n',
    'src/changelog.zig': changelog,
    'changelog.d/DEMO-1-notes.md': 'Tabs open sooner.\n',
  });
  assert.deepEqual(releaseNotes(stamp.files['src/changelog.zig'], 'v0.28.901'), {
    version: '0.28.901', releases: [
      { version: '0.28.901', changes: ['Tabs open sooner.'] },
      { version: '0.28.900', changes: ['Opening browser…'] },
    ],
  });
});

test('existing release workflow signs the versioned history alongside the update bundle', () => {
  const workflow = read('.github/workflows/release.yml');
  assert.match(workflow, /node tools\/release-notes\.mjs src\/changelog\.zig "\$TAG" dist\/release-notes\.json/);
  assert.match(workflow, /sha256sum \*\.exe \*\.zip release-notes\.json > SHA256SUMS\.txt/);
  assert.ok(workflow.indexOf('node tools/release-notes.mjs') < workflow.indexOf('sha256sum'));
  assert.ok(workflow.indexOf('sha256sum') < workflow.indexOf('node tools/sign-release.mjs'));
  assert.match(workflow, /gh release create "\$TAG" dist\/\*/);
});

test('updater stages checksum-verified notes before publishing ready, without a new network host', () => {
  const ps = read('src/update_release.ps1');
  const save = ps.slice(ps.indexOf('function Save-Update'), ps.indexOf('function Start-UpdatedApp'));
  assert.match(save, /Get-ReleaseAsset \$release 'release-notes.json'/);
  assert.match(save, /Assert-Update "\$dir\/notes.tmp" "\$dir\/SHA256SUMS.txt" 'release-notes.json' \$Target/);
  assert.ok(save.indexOf('Assert-Manifest') < save.indexOf('Assert-Update "$dir/notes.tmp"'));
  assert.ok(save.indexOf('Assert-Update "$dir/notes.tmp"') < save.indexOf('-Destination "$dir/release-notes.json"'));
  assert.ok(save.indexOf('-Destination "$dir/release-notes.json"') < save.indexOf('-Destination "$dir/ready.txt"'));
  assert.match(save, /Release notes version mismatch/);
  assert.match(save, /Release notes too large/);
  assert.deepEqual([...new Set([...ps.matchAll(/https:\/\/([^/'"\s]+)/g)].map(match => match[1]))].sort(), ['api.github.com', 'github.com']);
  assert.match(save, /Remove-Item -LiteralPath "\$dir\/release-notes.json"/);
  const zig = read('src/update_release.zig');
  assert.match(zig, /readFileAllocWin32\(path, 1024 \* 1024 \+ 1\)/);
  assert.match(zig, /parseFromSlice\(@import\("update_notes.zig"\)\.Document/);
  assert.match(zig, /pick\(parsed.value.releases, APP_VERSION, offered\)/);
  assert.match(zig, /defer parsed.deinit\(\)/);
  assert.doesNotMatch(zig, /@import\("changelog.zig"\)/);
});

test('existing card uses the same growing rectangle for layout and hits, with three Unicode note rows, an expandable full list and remaining count', () => {
  const card = read('src/update_card.zig');
  assertCardNotes(card);
  assert.equal((card.match(/update_release.cardNotes\(/g) || []).length, 2);
  assert.match(card, /const desired = uiScaled\(UPDATE_CARD_H\) \+ notes_height/);
  assert.match(card, /return updateCardHeight\(\) \+ @import\("window_layout.zig"\).paneGap\(\)/);
  assert.match(card, /\.top = sticky.top - @import\("window_layout.zig"\).paneGap\(\) - updateCardHeight\(\)/);
  assert.match(card, /const card = updateCardRect\(\)/);
  assert.match(card, /utf8ToUtf16Le\(&wide, card_notes.line\(i\)\)/);
  const painter = card.slice(card.indexOf('const notes_rect = updateCardNotesRect(card);'), card.indexOf('var more_buf:', card.indexOf('pub fn paintSidebarUpdateCard')));
  assert.match(painter, /DrawTextW\(hdc, &wide, @intCast\(n\), &note_rc, DT_WORDBREAK \| DT_NOPREFIX\)/);
  assert.doesNotMatch(painter, /DT_SINGLELINE|DT_END_ELLIPSIS/);
  assert.match(card, /DT_WORDBREAK \| DT_NOPREFIX \| @import\("win32.zig"\).DT_CALCRECT/);
  assert.match(card, /IntersectClipRect\(hdc, notes_rect.left, notes_rect.top, notes_rect.right, notes_rect.bottom\)/);
  assert.match(card, /card_scroll = std.math.clamp/);
  assert.match(card, /const bottom = card.bottom - uiScaled\(30\)/);
  assert.match(read('src/main.zig'), /if \(@import\("update_card.zig"\).updateCardScroll\(pt.x, pt.y, delta\)\) return 0/);
  const notes = read('src/update_notes.zig');
  for (const name of [
    'IGSH-728 picks only versions between installed and offered, newest first',
    'IGSH-948 shows three lines then and N more, and the full list when expanded',
    'IGSH-948 keeps sixteen lines and counts the rest as more even when expanded',
    'IGSH-1090 keeps real notes individual and maintenance releases quiet',
    'IGSH-728 skips ticket ids, file paths, file names and PR numbers',
  ]) assert.ok(notes.includes(`test "${name}"`));
  assert.match(notes, /lines: \[16\]\[512\]u8/);
  assert.match(notes, /!versionNewer\(installed, release.version\) or versionNewer\(offered, release.version\)/);
  assert.match(notes, /while \(at < result.count and !versionNewer\(versions\[at\], release.version\)\)/);
  assert.match(notes, /"and \{d\} more", \.\{rest\}/);
  assert.match(card, /if \(card_notes\.count == 0 or/);
});

test('master painter fails the exact card-note observability contract required by the new journey', () => {
  assert.throws(() => assertCardNotes(read('tools/fixtures/IGSH-728/master-update-card.zig')), assert.AssertionError);
  assertCardNotes(read('src/update_card.zig'));
});

test('safe-updates journey requires painted multi-version notes and screenshot from the real branch app', () => {
  const suite = read('tools/update-release.test.ps1');
  assert.match(suite, /Copy-Item -LiteralPath \$Verifier -Destination \$cardExe/);
  assert.match(suite, /Save-Update \$cardExe '0.0.0' 'x64'/);
  assert.match(suite, /Start-Process \$cardExe -ArgumentList "--update-ready \$cardEventName"/);
  assert.match(suite, /\$cardMutex.WaitOne\(\)/);
  assert.match(suite, /Update card did not paint release notes/);
    assert.match(suite, /card remaining=and 1 more/);
  assert.match(suite, /card view=collapsed n=3 first=Typing feels faster/);
  assert.match(suite, /card view=expanded n=4 first=Typing feels faster/);
  assert.match(suite, /PostMessage\(\$cardProcess.MainWindowHandle, 0x201, \[IntPtr\]1, \$moreClick\)/);
  assert.match(suite, /Card showed generic filler text/);
  assert.match(suite, /update-card-expanded.png/);
  assert.match(suite, /\$note.Groups\[1\].Value -ceq \$expectedNotes\[\$i\]/);
  assert.match(suite, /\$observedNotes \| ConvertTo-Json/);
  assert.match(suite, /PrintWindow\(\$cardProcess.MainWindowHandle/);
  assert.match(suite, /\$bitmap.Save\(\(Join-Path \$Evidence 'update-card-notes.png'\)\)/);
  assert.match(suite, /Tampered notes accepted/);
  assert.match(suite, /maintenance release waits without an update card/);
  assert.match(suite, /update-card-quiet\.png/);
  assert.match(suite, /Real product notes did not show again/);
  assert.match(suite, /\$installedNotes\.version = \$newVersion/);
  assert.match(suite, /Restart keeps your chats open/);
  const journey = read('tools/update-release-journey.ps1');
  assert.match(journey, /update card shows aggregated plain notes/);
  assert.match(journey, /Missing update card screenshot/);
  assert.match(journey, /update card opens the full list on click/);
  assert.match(read('.claude/skills/verify-multiprompt/features/safe-updates.md'), /update-card-notes.png/);
  const fixture = read('tools/update-release-fixtures.mjs');
  for (const version of ['9.8.0', '9.9.0', '9.10.0', '10.0.0']) assert.ok(fixture.includes(version));
  assert.match(fixture, /version: '9.9.0', changes: \['Middle change.'\]/);
  assert.match(fixture, /names.push\('release-notes.json'\)/);
});

test('IGSH-1090 publication removes engineering notes and filler, not real product lines', async () => {
  const { releaseNotes } = await import('./release-notes.mjs');
  const source = `pub const CHANGELOG = [_]ChangelogEntry{
    .{ .ver = "0.28.901", .items = &.{
        .{ .text = "Behind the scenes fixes.", .ticket = "" },
        .{ .text = "Chat speed checks now ignore shared-machine pauses.", .ticket = "" },
        .{ .text = "Dictation shortcuts keep working when keys queue up.", .ticket = "" },
    } },
};`;
  assert.deepEqual(releaseNotes(source, 'v0.28.901').releases[0].changes, ['Dictation shortcuts keep working when keys queue up.']);
  assert.doesNotMatch(read('tools/version-stamp.mjs'), /IGSH-834-maintenance|export const behindTheScenes/);
});

test('changed implementation is comment-free and leaves no error log', async () => {
  const { tokenize, languageFor } = await import('./strip-comments.mjs');
  for (const file of [
    'src/update_notes.zig', 'src/update_card.zig', 'src/update_release.zig', 'src/update_release.ps1',
    'tools/release-notes.mjs', 'tools/version-stamp.mjs', 'tools/update-release-fixtures.mjs',
    'tools/update-release.test.ps1', 'tools/update-release-journey.ps1',
    'tools/update-card-notes.test.js', 'tools/changelog-fragments.test.js',
    'tools/changelog-entry.test.js', 'tools/version-stamp.test.mjs',
    'tools/fixtures/IGSH-728/master-update-card.zig',
    '.github/workflows/release.yml', '.github/workflows/test.yml',
  ]) assert.deepEqual(tokenize(read(file), languageFor(file)).comments.filter(comment => !comment.reason), [], file);
  const files = fs.readdirSync(root, { recursive: true, withFileTypes: true });
  assert.equal(files.some(file => file.isFile() && file.name === 'error.log'), false);
  assert.match(read('changelog.d/README.md'), /No ticket ids, file names, paths, code names or PR numbers/);
});


test('IGSH-1090 published executable paints its own published notes, with no binary edits', {
  skip: process.platform !== 'win32' || process.env.GITHUB_WORKFLOW !== 'Test repeat',
  timeout: 180000,
}, async t => {
  const os = require('node:os');
  const { createHash } = require('node:crypto');
  const { spawnSync } = require('node:child_process');
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'released-card-'));
  t.after(() => fs.rmSync(directory, { recursive: true, force: true }));
  const response = await fetch('https://api.github.com/repos/valentinyeo/multiprompt/releases/latest');
  assert.equal(response.status, 200);
  let release = await response.json();
  const historyAsset = release.assets.find(asset => asset.name === 'release-notes.json');
  assert.ok(historyAsset);
  const historyResponse = await fetch(historyAsset.browser_download_url);
  assert.equal(historyResponse.status, 200);
  const history = await historyResponse.json();
  const feature = history.releases.find(item => item.changes.includes('Update cards explain each change, without generic messages.'));
  assert.ok(feature, 'Feature must be published before its release-card proof');
  assert.match(release.tag_name, /^v\d+\.\d+\.\d+$/);
  const assets = {};
  for (const name of ['multiprompt-x64.exe', 'release-notes.json']) {
    const asset = release.assets.find(asset => asset.name === name);
    assert.ok(asset, name);
    assert.match(asset.browser_download_url, /^https:\/\/github\.com\/valentinyeo\/multiprompt\/releases\/download\//);
    const download = await fetch(asset.browser_download_url);
    assert.equal(download.status, 200);
    const bytes = Buffer.from(await download.arrayBuffer());
    assert.equal(`sha256:${createHash('sha256').update(bytes).digest('hex')}`, asset.digest);
    assets[name] = path.join(directory, name);
    fs.writeFileSync(assets[name], bytes);
  }
  const notes = JSON.parse(fs.readFileSync(assets['release-notes.json'], 'utf8'));
  assert.equal(notes.version, release.tag_name.slice(1));
  assert.ok(notes.releases.some(item => item.changes.includes('Update cards explain each change, without generic messages.')));
  const proof = spawnSync('pwsh', ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-File',
    path.join(root, 'tools/update-card-release-proof.ps1'), '-Exe', assets['multiprompt-x64.exe'],
    '-Notes', assets['release-notes.json'], '-Evidence', path.join(directory, 'proof')],
  { encoding: 'utf8', timeout: 120000, maxBuffer: 8 * 1024 * 1024 });
  assert.equal(proof.status, 0, proof.stdout + proof.stderr);
  assert.match(proof.stdout, /RELEASE_CARD_RECEIPT=/);
  assert.match(proof.stdout, /RELEASE_CARD_PNG=/);
  console.log(proof.stdout);
});

test('IGSH-1118 native card wraps long real notes, scrolls internally, and rejects the old released painter', {
  skip: process.platform !== 'win32' || process.env.GITHUB_WORKFLOW !== 'Test repeat',
  timeout: 300000,
}, async t => {
  const os = require('node:os');
  const { createHash } = require('node:crypto');
  const { spawnSync } = require('node:child_process');
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'wrapped-card-'));
  t.after(() => fs.rmSync(directory, { recursive: true, force: true }));
  const fragment = 'Update notes wrap in full, with scrolling for longer lists.';
  const api = async endpoint => {
    const response = await fetch(`https://api.github.com/repos/valentinyeo/multiprompt/${endpoint}`);
    assert.equal(response.status, 200);
    return response.json();
  };
  const download = async (release, name, destination) => {
    const asset = release.assets.find(item => item.name === name);
    assert.ok(asset, name);
    const response = await fetch(asset.browser_download_url);
    assert.equal(response.status, 200);
    const bytes = Buffer.from(await response.arrayBuffer());
    assert.equal(`sha256:${createHash('sha256').update(bytes).digest('hex')}`, asset.digest);
    fs.writeFileSync(destination, bytes);
  };
  const latest = await api('releases/latest');
  const notes = path.join(directory, 'notes.json');
  await download(latest, 'release-notes.json', notes);
  const history = JSON.parse(fs.readFileSync(notes, 'utf8'));
  const shipped = history.releases.find(release => release.changes.includes(fragment));
  let exe = path.join(root, 'zig-out/bin/multiprompt.exe');
  if (shipped) {
    const release = shipped.version === latest.tag_name.slice(1) ? latest : await api(`releases/tags/v${shipped.version}`);
    exe = path.join(directory, 'released.exe');
    await download(release, 'multiprompt-x64.exe', exe);
    history.version = shipped.version;
    fs.writeFileSync(notes, JSON.stringify(history));
  }
  const old = await api('releases/tags/v0.28.983');
  const before = path.join(directory, 'before.exe');
  await download(old, 'multiprompt-x64.exe', before);
  const proof = (binary, label) => spawnSync('pwsh', ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-File',
    path.join(root, 'tools/update-card-release-proof.ps1'), '-Exe', binary, '-Notes', notes,
    '-Evidence', path.join(directory, label), '-Wrapped'],
  { encoding: 'utf8', timeout: 120000, maxBuffer: 16 * 1024 * 1024 });
  const red = proof(before, 'red');
  assert.notEqual(red.status, 0, red.stdout + red.stderr);
  assert.match(red.stdout + red.stderr, /Card did not expose wrapped note bounds/);
  console.log('WRAPPED_CARD_RED v0.28.983 rejects the unwrapped painter');
  const green = proof(exe, 'green');
  assert.equal(green.status, 0, green.stdout + green.stderr);
  assert.match(green.stdout, /WRAPPED_CARD_RECEIPT=/);
  assert.match(green.stdout, /WRAPPED_CARD_IMAGE=wrapped-normal:/);
  assert.match(green.stdout, /WRAPPED_CARD_IMAGE=wrapped-minimum:/);
  assert.match(green.stdout, /WRAPPED_CARD_IMAGE=wrapped-scrolled:/);
  assert.match(green.stdout, /WRAPPED_CARD_IMAGE=wrapped-collapsed:/);
  console.log(green.stdout);
});

test('IGSH-1243 builds one linked line for each commit ticket', async () => {
  const { buildChangelog } = await import('./version-stamp.mjs');
  const { releaseNotes } = await import('./release-notes.mjs');
  const files = {
    'src/main.zig': 'pub const APP_VERSION = "0.28.883";\n',
    'src/changelog.zig': 'const SOURCE_CHANGELOG = [_]ChangelogEntry{\n    .{ .ver = "0.28.883", .items = &.{\n        .{ .text = "Earlier.", .ticket = "IGSH-1" },\n    } },\n};\n',
    'changelog.d/IGSH-2-chat.md': 'Chats open sooner.\nDrafts stay visible.\n',
  };
  const commits = [{ sha: 'aaa', subject: 'IGSH-2: Improve chats' }, { sha: 'bbb', subject: 'IGSH-3: Repair checks' }, { sha: 'ccc', subject: 'IGSH-2: Follow up' }];
  const generated = buildChangelog(files, 'v0.28.1100', [], commits);
  const latest = releaseNotes(generated, 'v0.28.1100').releases[0];
  assert.deepEqual(latest.changes, ['Chats open sooner. Drafts stay visible.', 'Checks and fixes, no visible change']);
  assert.deepEqual(latest.tickets, ['https://app.hypertask.ai/detail/project-2060/2', 'https://app.hypertask.ai/detail/project-2060/3']);
  assert.match(generated, /\.text = "Chats open sooner\. Drafts stay visible\.", \.ticket = "IGSH-2"/);
  assert.throws(() => buildChangelog(files, 'v0.28.1100', [], [{ sha: 'bad123', subject: 'Repair checks' }]), /bad123.*leading ticket ID/);
  assert.throws(() => buildChangelog(files, 'v0.28.1100', [], []), /fragment has no matching commit ticket/);
  const noFragments = { ...files };
  delete noFragments['changelog.d/IGSH-2-chat.md'];
  assert.throws(() => buildChangelog(noFragments, 'v0.28.1100'), /no ticketed release lines/);
  const tooling = releaseNotes(buildChangelog(noFragments, 'v0.28.1100', [], [commits[1]]), 'v0.28.1100').releases[0];
  assert.deepEqual(tooling.changes, ['Checks and fixes, no visible change']);
  assert.deepEqual(tooling.tickets, ['https://app.hypertask.ai/detail/project-2060/3']);
  assert.throws(() => releaseNotes(generated.replace('.ticket = "IGSH-2"', '.ticket = ""'), 'v0.28.1100'), /needs plain ticketed lines/);
});

test('IGSH-1243 reconstructs every published 1027 to 1048 release', async () => {
  const { execFileSync } = require('node:child_process');
  const { buildChangelog } = await import('./version-stamp.mjs');
  const { releaseNotes } = await import('./release-notes.mjs');
  const git = (...args) => execFileSync('git', args, { cwd: root, encoding: 'utf8' }).trim();
  const tags = [1027, 1028, 1029, 1030, 1031, 1032, 1033, 1034, 1035, 1036, 1037, 1038, 1039, 1040, 1042, 1043, 1044, 1045, 1046, 1047, 1048].map(n => `v0.28.${n}`);
  const source = {
    'src/main.zig': 'pub const APP_VERSION = "0.28.883";\n',
    'src/changelog.zig': 'const SOURCE_CHANGELOG = [_]ChangelogEntry{\n    .{ .ver = "0.28.883", .items = &.{\n        .{ .text = "Earlier.", .ticket = "IGSH-1" },\n    } },\n};\n',
  };
  const history = [{ tag: 'v0.28.1026', files: source }];
  for (const tag of tags) {
    const names = git('diff', '--name-only', '--diff-filter=AM', 'v0.28.1026', tag, '--', 'changelog.d/').split('\n').filter(Boolean);
    const fragments = Object.fromEntries(names.map(name => [name, git('show', `${tag}:${name}`)]));
    history.push({ tag, files: { ...source, ...fragments }, sha: git('rev-parse', `${tag}^{commit}`) });
  }
  const files = { ...history.at(-1).files, 'changelog.d/IGSH-1243-notes.md': 'Changelog ticket links now open their tickets.\n' };
  const generated = buildChangelog(files, 'v0.28.1100', history, [{ sha: 'new', subject: 'IGSH-1243: Explain releases' }]);
  const notes = releaseNotes(generated, 'v0.28.1100');
  for (const tag of tags) {
    const release = notes.releases.find(item => item.version === tag.slice(1));
    assert.ok(release?.changes.length, tag);
    assert.equal(release.changes.length, release.tickets.length, tag);
    assert.ok(release.tickets.every(ticket => /^https:\/\/app\.hypertask\.ai\/detail\/project-2060\/\d+$/.test(ticket)), tag);
  }
  assert.equal(notes.releases.some(item => item.version === '0.28.1041'), false);
  const release1038 = notes.releases.find(item => item.version === '0.28.1038');
  const actualFragment = git('show', 'v0.28.1038:changelog.d/IGSH-1238-busy-queue.md').split('\n').join(' ');
  const fragmentIndex = release1038.tickets.indexOf('https://app.hypertask.ai/detail/project-2060/1238');
  assert.equal(release1038.changes[fragmentIndex], actualFragment);
  assert.throws(() => buildChangelog(files, 'v0.28.1100', history.map(item => item.tag === 'v0.28.1048' ? { ...item, sha: 'wrong' } : item), [{ sha: 'new', subject: 'IGSH-1243: Explain releases' }]), /reviewed release commit does not match/);
});
