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
  assert.match(source, /drawAscii\(hdc, "See all", &more_rect/);
  assert.match(source, /\[update\] card view=collapsed n=\{d\} first=\{s\}/);
  assert.match(source, /\[update\] card note \{d\}=\{s\}/);
  assert.match(source, /\[update\] card note id \{d\}=\{s\}/);
  assert.match(source, /\[update\] card remaining=/);
  assert.match(source, /\[update\] card see all=\{s\}/);
  assert.match(source, /\[update\] more row=\{d\},\{d\}/);
  assert.match(source, /if \(cardShowsSeeAll\(\) and ptInRect\(updateCardMoreRect\(card\), x, y\)\) return 4/);
}

function assertSeeAllAtAnyChangeCount(source) {
  assert.match(source, /fn cardShowsSeeAll\(\) bool \{\s+return card_notes\.count > 0;\s+\}/);
  assert.match(source, /if \(cardShowsSeeAll\(\)\) \{\s+var more_rect = updateCardMoreRect\(card\);\s+drawAscii\(hdc, "See all", &more_rect/);
  assert.match(source, /if \(cardShowsSeeAll\(\) and ptInRect\(updateCardMoreRect\(card\), x, y\)\) return 4/);
  assert.match(source, /fn seeAllUrl\(\) \[\]const u8 \{\s+return @import\("update_notes\.zig"\)\.releaseUrl\(&see_all_url/);
}

test('release asset includes every historical version, plain lines only, and the offered version rather than embedded-only notes', async () => {
  const { releaseNotes } = await import('./release-notes.mjs');
  const source = read('src/changelog.zig');
  const versions = [...source.matchAll(/\.ver = "(\d+\.\d+\.\d+)"/g)].map(match => match[1]);
  const notes = releaseNotes(source, `v${versions[0]}`);
  assert.deepEqual(notes.releases.map(release => release.version), versions);
  assert.ok(Buffer.byteLength(JSON.stringify(notes)) < 1024 * 1024);
  assert.ok(notes.releases.every(release => release.changes.every(line => /^(?:IGSH|MUBO)-[1-9]\d* \S/.test(line))));
  assert.ok(notes.releases[0].changes.length > 0);
  assert.equal(notes.version, versions[0]);
  assert.doesNotMatch(JSON.stringify(notes), /Checks and fixes, no visible change/);
  assert.throws(() => releaseNotes(source, 'v99.0.0'), /offered version/);
});

test('filler cannot be published as a ticket title', async () => {
  const { releaseNotes } = await import('./release-notes.mjs');
  const source = `pub const CHANGELOG = [_]ChangelogEntry{
    .{ .ver = "0.28.1400", .items = &.{
        .{ .text = "IGSH-1300 Checks and fixes, no visible change", .ticket = "IGSH-1300" },
    } },
};`;
  const warnings = [];
  assert.deepEqual(releaseNotes(source, 'v0.28.1400', line => warnings.push(line)).releases[0], { version: '0.28.1400', changes: [], tickets: [] });
  assert.equal(warnings.length, 1, warnings.join('\n'));
  assert.match(warnings[0], /IGSH-1300 has no title this release can publish/);
});

test('historical and current lines use the same authoritative title', async () => {
  const { buildChangelog } = await import('./version-stamp.mjs');
  const { releaseNotes } = await import('./release-notes.mjs');
  const files = {
    'src/changelog.zig': 'const SOURCE_CHANGELOG = [_]ChangelogEntry{\n    .{ .ver = "0.28.883", .items = &.{\n        .{ .text = "Earlier.", .ticket = "IGSH-1266" },\n    } },\n};\n',
  };
  const titles = { 'IGSH-1266': 'A title with café and "quotes"' };
  const source = buildChangelog(files, 'v0.28.1341', [], [{ sha: 'new', subject: 'IGSH-1266: Keep the real line' }], titles);
  const notes = releaseNotes(source, 'v0.28.1341');
  assert.deepEqual(notes.releases.map(release => release.changes), [['IGSH-1266 A title with café and "quotes"'], ['IGSH-1266 A title with café and "quotes"']]);
});

test('existing release workflow signs the versioned history alongside the update bundle', () => {
  const workflow = read('.github/workflows/release.yml');
  assert.match(workflow, /node tools\/release-notes\.mjs src\/changelog\.zig "\$TAG" release-notes\.json/);
  const release = workflow.slice(workflow.indexOf('\n  release:\n'));
  const signedNotesInOrder = text => {
    const notes = text.indexOf('cp release-notes.json dist/release-notes.json');
    const manifest = text.indexOf('sha256sum -- *.exe *.zip release-notes.json > SHA256SUMS.txt');
    const signature = text.indexOf('node tools/sign-release.mjs');
    const publication = text.indexOf('gh release create "$TAG" dist/*');
    return notes >= 0 && notes < manifest && manifest < signature && signature < publication;
  };
  assert.ok(signedNotesInOrder(release));
  const unsigned = release.replace('sha256sum -- *.exe *.zip release-notes.json > SHA256SUMS.txt', 'sha256sum -- *.exe *.zip > SHA256SUMS.txt');
  assert.equal(signedNotesInOrder(unsigned), false);
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

test('existing card uses the same growing rectangle for layout and hits, with three plain note rows and a See all link', () => {
  const card = read('src/update_card.zig');
  assertCardNotes(card);
  assertSeeAllAtAnyChangeCount(card);
  assert.equal((card.match(/update_release.cardNotes\(/g) || []).length, 2);
  assert.match(card, /const desired = base \+ notes_height/);
  assert.match(card, /return updateCardHeight\(\) \+ @import\("window_layout.zig"\).paneGap\(\)/);
  assert.match(card, /const bottom = client.bottom - uiScaled\(8\);\s+return \.\{ \.left = uiScaled\(8\), \.top = bottom - updateCardHeight\(\)/);
  assert.match(card, /const card = updateCardRect\(\)/);
  assert.match(card, /utf8ToUtf16Le\(&note_wide, card_notes.line\(i\)\)/);
  const painter = card.slice(card.indexOf('const notes_rect = updateCardNotesRect(card);'), card.indexOf('if (cardShowsSeeAll())', card.indexOf('pub fn paintSidebarUpdateCard')));
  assert.match(painter, /DrawTextW\(hdc, &note_wide, @intCast\(n\), &note, DT_WORDBREAK \| DT_NOPREFIX\)/);
  assert.doesNotMatch(painter, /DT_SINGLELINE|DT_END_ELLIPSIS/);
  assert.match(card, /DT_WORDBREAK \| DT_NOPREFIX \| @import\("win32.zig"\).DT_CALCRECT/);
  assert.match(card, /IntersectClipRect\(hdc, notes_rect.left, notes_rect.top, notes_rect.right, notes_rect.bottom\)/);
  assert.match(card, /card_scroll = std.math.clamp/);
  assert.match(card, /const bottom = card.bottom - uiScaled\(38\)/);
  assert.match(read('src/main.zig'), /if \(pt\.x >= 0 and pt\.x < SIDEBAR_W\(\) and pt\.y >= 0\) \{\s+const delta: i16 = @bitCast\(@as\(u16, @truncate\(wp >> 16\)\)\);\s+if \(@import\("update_card\.zig"\)\.updateCardScroll\(pt\.x, pt\.y, delta\)\) return 0/);
  const notes = read('src/update_notes.zig');
  for (const name of [
    'only the offered release change lines reach the card',
    'a release with no published change shows no lines instead of older changes',
    'invalid notes and filler are not displayed',
    'three cards lines show by default and the extra changes stay counted',
    'one published change still links the full release notes',
    'a release past the stored lines keeps every change behind the release notes link',
  ]) assert.ok(notes.includes(`test "${name}"`));
  assert.match(notes, /lines: \[MAX_LINES\]\[512\]u8/);
  assert.match(notes, /ids: \[MAX_LINES\]\[16\]u8/);
  assert.match(notes, /pub fn shown\(self: \*const Notes\) usize \{\s+return @min\(self.count, COLLAPSED_LINES\);\s+\}/);
  assert.match(notes, /RELEASE_URL = "https:\/\/github\.com\/valentinyeo\/multiprompt\/releases\/tag\/v"/);
  assert.match(notes, /fn productChange\(text: \[\]const u8\)/);
  assert.match(notes, /if \(!versionNewer\(installed, offered\)\) return result;/);
  assert.match(notes, /if \(!std\.mem\.eql\(u8, release\.version, offered\)\) continue;/);
  assert.doesNotMatch(notes, /versions\[/);
  assert.match(notes, /for \(TICKET_KEYS\) \|key\| if \(std\.mem\.startsWith\(u8, text, key\)\) return key\.len/);
  const rect = card.slice(card.indexOf('pub fn updateCardRect()'), card.indexOf('fn updateCardButtonRect('));
  assert.match(rect, /\.left = uiScaled\(8\), \.top = bottom - updateCardHeight\(\), \.right = @import\("browser_pane.zig"\).SIDEBAR_W\(\) - uiScaled\(8\), \.bottom = bottom/);
  const hit = card.slice(card.indexOf('pub fn updateCardHit('), card.indexOf('var release_ready'));
  assert.match(hit, /const card = updateCardRect\(\);\s+if \(!ptInRect\(card, x, y\)\) return 0/);
  assert.match(card.slice(card.indexOf('pub fn paintSidebarUpdateCard')), /const card = updateCardRect\(\)/);
});

test('master painter fails the exact card-note observability contract required by the new journey', () => {
  assert.throws(() => assertCardNotes(read('tools/fixtures/IGSH-728/master-update-card.zig')), assert.AssertionError);
  assertCardNotes(read('src/update_card.zig'));
});

test('the previous card stayed quiet and hid See all for a release with one to three changes', () => {
  const previous = read('tools/fixtures/MUBO-577/previous-update-card.zig');
  assert.match(previous, /fn cardHasToggle\(\) bool \{\s+return card_notes\.total > @import\("update_notes\.zig"\)\.COLLAPSED_LINES;\s+\}/);
  assert.throws(() => assertSeeAllAtAnyChangeCount(previous), assert.AssertionError);
  assert.throws(() => assertCardNotes(previous), assert.AssertionError);
  assertSeeAllAtAnyChangeCount(read('src/update_card.zig'));
});

test('safe-updates journey paints only the offered release notes and proves older entries stay out', () => {
  const suite = read('tools/update-release.test.ps1');
  assert.match(suite, /Copy-Item -LiteralPath \$Verifier -Destination \$cardExe/);
  assert.match(suite, /Save-Update \$cardExe '0.0.0' 'x64'/);
  assert.match(suite, /Start-Process \$cardExe -ArgumentList "--update-ready \$cardEventName"/);
  assert.match(suite, /\$cardMutex.WaitOne\(\)/);
  assert.match(suite, /Staged notes differ from the signed release/);
  assert.match(suite, /\$expectedNotes = @\('Typing feels faster', 'Chats keep your place'\)/);
  assert.match(suite, /\$stagedTitles\.Count -eq 4/);
  assert.match(suite, /An older release line was painted under the offered version/);
  assert.match(suite, /GetClientRect\(\$cardProcess.MainWindowHandle/);
  assert.match(suite, /GetDpiForWindow\(\$cardProcess.MainWindowHandle/);
  assert.match(suite, /\$collapsed \| ConvertTo-Json/);
  assert.match(suite, /Wait-CardView \$log 0 'collapsed' \$expectedNotes 'See all'/);
  assert.match(suite, /Update card See all does not point at the matching release notes/);
  assert.match(suite, /Update card See all did not open the release notes/);
  assert.match(suite, /Click-CardMore \$collapsed/);
  assert.match(suite, /PrintWindow\(\$cardProcess.MainWindowHandle/);
  assert.match(suite, /\$bitmap.Save\(\(Join-Path \$Evidence 'update-card-notes.png'\)\)/);
  assert.match(suite, /Tampered notes accepted/);
  assert.match(suite, /ticket-title staged notes retain title and ticket link/);
  assert.match(suite, /Ticket title is missing or changed/);
  assert.match(suite, /Ticket link is missing or changed/);
  assert.match(suite, /Ticket-title update marker missing/);
  assert.match(suite, /update-card-ticket-title\.png/);
  assert.match(suite, /Restored update marker missing/);
  assert.match(suite, /\$installedNotes\.version = \$newVersion/);
  assert.match(suite, /restart card reopens newer native app with session restored/);
  const journey = read('tools/update-release-journey.ps1');
  assert.match(journey, /signed staged notes retain expected data/);
  assert.match(journey, /zig test src\/update_notes\.zig/);
  assert.match(journey, /Missing update card screenshot/);
  assert.match(read('.claude/skills/verify-multiprompt/features/safe-updates.md'), /update-card-notes.png/);
  const fixture = read('tools/update-release-fixtures.mjs');
  for (const version of ['9.8.0', '9.9.0', '9.10.0', '10.0.0']) assert.ok(fixture.includes(version));
  assert.match(fixture, /version: '9.9.0', changes: \['IGSH-2 Middle change'\]/);
  assert.match(fixture, /names.push\('release-notes.json'\)/);
});

test('the published board keys reach the card and the real release explains itself', () => {
  const notes = read('src/update_notes.zig');
  for (const key of ['IGSH-', 'MUBO-']) assert.ok(notes.includes(`"${key}"`), key);
  assert.doesNotMatch(notes, /startsWith\(u8, text, "IGSH-"\)/);
  const published = JSON.parse(read('src/testdata/mubo-577-release-notes.json'));
  assert.equal(published.version, '0.28.1985');
  const newest = published.releases.find(release => release.version === '0.28.1985');
  assert.deepEqual(newest.changes, ['MUBO-243 Poteto tab points at its chat from before a clear']);
  assert.ok(published.releases.every(release => release.changes.every(line => /^(?:IGSH|MUBO)-[1-9]\d* \S/.test(line))));
  const month = published.releases.find(release => release.version === '0.28.1961');
  assert.equal(month.changes.length, 4);
  assert.match(notes, /test "MUBO-577 real published release paints change lines for an available update"/);
  assert.match(notes, /test "MUBO-577 offered release never paints an older release change"/);
});

test('the real release proof uses the downloaded production notes and their matching See all destination', () => {
  const proof = read('tools/update-card-real-notes.test.js');
  assert.match(proof, /const offer = '0\.28\.1985'/);
  assert.match(proof, /const installed = '0\.28\.1984'/);
  assert.match(proof, /releases\/tags\/v\$\{offer\}/);
  assert.match(proof, /asset\.digest/);
  assert.match(proof, /-Dversion=\$\{installed\}/);
  assert.match(proof, /update-card-real-release-proof\.ps1/);
  assert.match(proof, /src\/testdata\/mubo-577-release-notes\.json/);
  assert.match(proof, /Pinned fixture drifted/);
  assert.match(proof, /REAL_CARD_RECEIPT=/);
  assert.match(proof, /'-Before'/);
  assert.match(proof, /before-card\.png/);
  const cardProof = read('tools/update-card-release-proof.ps1');
  assert.match(cardProof, /\[ValidateSet\('new', 'released'\)\]\[string\]\$Contract = 'new'/);
  assert.match(cardProof, /New card painted no published change lines/);
  assert.match(cardProof, /Released old card already logs a ticket id/);
  assert.match(cardProof, /Released old card already links the release notes/);
  assert.match(cardProof, /Released old painter named no published note to wrap/);
  assert.match(cardProof, /Card binary carries no version marker/);
  assert.match(cardProof, /SetProcessDpiAwarenessContext/);
  assert.match(cardProof, /RedrawWindow/);
  assert.match(cardProof, /Card client size differs from the size the app laid out/);
  assert.match(cardProof, /screenshot cut the Restart button at /);
  assert.match(cardProof, /screenshot shows no Restart label/);
  assert.match(cardProof, /screenshot put the Restart button outside the card/);
  assert.match(cardProof, /screenshot shows no See all row below the notes/);
  assert.match(cardProof, /images = \$script:cardImages/);
  const script = read('tools/update-card-real-release-proof.ps1');
  assert.match(script, /\[switch\]\$Before/);
  assert.match(script, /'before-card'/);
  assert.match(script, /MPVERSION=\$Offer;multiprompt-x64\.exe/);
  assert.match(script, /releases\/tag\/v\$Offer/);
  assert.match(script, /'released-card'/);
  assert.match(script, /'see-all-release'/);
  assert.match(script, /painted a ticket number into the change text/);
  assert.match(read('.github/workflows/test-repeat.yml'), /path: evidence\//);
});

test('unidentified legacy lines publish without a link and warn', async () => {
  const { releaseNotes } = await import('./release-notes.mjs');
  const source = `pub const CHANGELOG = [_]ChangelogEntry{
    .{ .ver = "0.28.901", .items = &.{
        .{ .text = "Unidentified legacy note", .ticket = "" },
    } },
};`;
  const warnings = [];
  assert.deepEqual(releaseNotes(source, 'v0.28.901', line => warnings.push(line)).releases[0], { version: '0.28.901', changes: ['Unidentified legacy note'], tickets: [null] });
  assert.deepEqual(warnings, ['Release 0.28.901: a line has no ticket key; publishing it without a link']);
});

test('changed implementation is comment-free and leaves no error log', async () => {
  const { tokenize, languageFor } = await import('./strip-comments.mjs');
  for (const file of [
    'src/update_notes.zig', 'src/update_card.zig', 'src/update_release.zig', 'src/update_release.ps1',
    'tools/release-notes.mjs', 'tools/version-stamp.mjs', 'tools/update-release-fixtures.mjs',
    'tools/update-release.test.ps1', 'tools/update-release-journey.ps1',
    'tools/update-card-notes.test.js', 'tools/soft-2995-update-card.test.js', 'tools/changelog-fragments.test.js',
    'tools/update-card-real-release-proof.ps1', 'tools/update-card-release-proof.ps1', 'tools/update-card-real-notes.test.js',
    'tools/changelog-entry.test.js', 'tools/version-stamp.test.mjs',
    'tools/fixtures/IGSH-728/master-update-card.zig',
    '.github/workflows/release.yml', '.github/workflows/test.yml',
  ]) assert.deepEqual(tokenize(read(file), languageFor(file)).comments.filter(comment => !comment.reason), [], file);
  const files = fs.readdirSync(root, { recursive: true, withFileTypes: true });
  assert.equal(files.some(file => file.isFile() && file.name === 'error.log'), false);
  assert.match(read('changelog.d/README.md'), /No ticket ids, file names, paths, code names or PR numbers/);
});


test('IGSH-1090 published executable characterizes its own published notes, and a new build names every change', {
  skip: process.platform !== 'win32' || process.env.GITHUB_WORKFLOW !== 'Test repeat',
  timeout: 240000,
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
  const feature = history.releases.find(item => item.changes.some(change => change.startsWith('IGSH-1090 ') || change === 'Update cards explain each change, without generic messages.'));
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
  assert.ok(notes.releases.some(item => item.changes.some(change => change.startsWith('IGSH-1090 ') || change === 'Update cards explain each change, without generic messages.')));
  const newest = notes.releases.find(item => item.version === notes.version);
  assert.ok(newest && newest.changes.length > 0, 'The newest published release names no change');
  const featureShipped = notes.releases.some(item => item.changes.some(change => change.startsWith('MUBO-577 ') || change === 'Update card says what the new version brings'));
  const proof = (binary, label, contract) => spawnSync('pwsh', ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-File',
    path.join(root, 'tools/update-card-release-proof.ps1'), '-Exe', binary, '-Notes', assets['release-notes.json'],
    '-Evidence', path.join(directory, label), '-Contract', contract],
  { encoding: 'utf8', timeout: 120000, maxBuffer: 32 * 1024 * 1024 });
  const receipt = label => JSON.parse(fs.readFileSync(path.join(directory, label, 'released-card.json'), 'utf8'));
  const expected = newest.changes.map(change => change.replace(/^(?:IGSH|MUBO)-\d+ /, '')).slice(0, 3);
  const expectedIds = newest.changes.map(change => (change.match(/^(?:IGSH|MUBO)-\d+/) || [''])[0]).slice(0, 3);
  if (featureShipped) {
    const published = proof(assets['multiprompt-x64.exe'], 'published', 'new');
    assert.equal(published.status, 0, published.stdout + published.stderr);
    assert.match(published.stdout, /RELEASE_CARD_RECEIPT=/);
    assert.match(published.stdout, /RELEASE_CARD_PNG=/);
    const shipped = receipt('published');
    assert.equal(shipped.contract, 'new');
    assert.equal(shipped.binaryVersion, release.tag_name.slice(1));
    assert.deepEqual(shipped.painted, expected);
    assert.deepEqual(shipped.ids, expectedIds);
    assert.equal(shipped.seeAll, true);
    console.log(published.stdout);
  } else {
    const published = proof(assets['multiprompt-x64.exe'], 'before', 'released');
    assert.equal(published.status, 0, published.stdout + published.stderr);
    assert.match(published.stdout, /RELEASE_CARD_RECEIPT=/);
    assert.match(published.stdout, /RELEASE_CARD_PNG=/);
    const before = receipt('before');
    assert.equal(before.contract, 'released');
    assert.equal(before.binaryVersion, release.tag_name.slice(1));
    const legacy = newest.changes.filter(change => /^IGSH-\d+ /.test(change)).slice(0, 3);
    assert.ok(before.painted.length <= legacy.length, `Published card named ${before.painted.length} lines its old filter keeps ${legacy.length}`);
    for (const line of before.painted) assert.ok(legacy.includes(line), `Published card painted an unpublished line: ${line}`);
    if (legacy.length === 0) assert.deepEqual(before.painted, [], 'The published card named a change its IGSH-only filter drops');
    assert.deepEqual(before.ids, []);
    assert.equal(before.seeAll, false);
    const branch = path.join(root, 'zig-out/bin/multiprompt.exe');
    assert.ok(fs.existsSync(branch), 'Branch build is missing');
    const after = proof(branch, 'after', 'new');
    assert.equal(after.status, 0, after.stdout + after.stderr);
    assert.match(after.stdout, /RELEASE_CARD_RECEIPT=/);
    assert.match(after.stdout, /RELEASE_CARD_PNG=/);
    const built = receipt('after');
    assert.equal(built.contract, 'new');
    assert.deepEqual(built.painted, expected);
    assert.deepEqual(built.ids, expectedIds);
    assert.equal(built.seeAll, true);
    console.log(published.stdout + after.stdout);
  }
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
  const branch = path.join(root, 'zig-out/bin/multiprompt.exe');
  assert.ok(fs.existsSync(branch), 'Branch build is missing');
  const branchBytes = fs.readFileSync(branch);
  const branchDigest = `sha256:${createHash('sha256').update(branchBytes).digest('hex')}`;
  const branchVersion = (branchBytes.toString('latin1').match(/MPVERSION=(\d+\.\d+\.\d+);/) || [])[1];
  assert.ok(branchVersion, 'Branch build carries no version marker');
  const old = await api('releases/tags/v0.28.983');
  const before = path.join(directory, 'before.exe');
  await download(old, 'multiprompt-x64.exe', before);
  assert.match(fs.readFileSync(before, 'latin1'), /MPVERSION=0\.28\.983;/, 'Pinned old painter is not the v0.28.983 release binary');
  const beforeNotes = path.join(directory, 'before-notes.json');
  await download(old, 'release-notes.json', beforeNotes);
  const beforeHistory = JSON.parse(fs.readFileSync(beforeNotes, 'utf8'));
  assert.equal(beforeHistory.version, '0.28.983', 'Pinned old notes are not the ones v0.28.983 shipped with');
  const beforeLines = beforeHistory.releases.flatMap(release => release.changes);
  assert.ok(beforeLines.length > 0, 'Pinned old release named no change');
  assert.ok(beforeLines.every(line => !/^[A-Z]+-\d+ /.test(line)), 'v0.28.983 shipped plain note lines, before ticket keys');
  const evidence = path.join(root, 'evidence/wrapped-card');
  fs.rmSync(evidence, { recursive: true, force: true });
  const captured = ['released-card.png', 'wrapped-normal.png', 'wrapped-minimum.png', 'wrapped-scrolled.png', 'wrapped-collapsed.png'];
  const keepEvidence = label => {
    const target = path.join(evidence, label);
    fs.mkdirSync(target, { recursive: true });
    for (const name of [...captured, 'released-card.json', 'wrapped-card.json', 'debug.log']) {
      const file = path.join(directory, label, name);
      if (fs.existsSync(file)) fs.copyFileSync(file, path.join(target, name));
    }
  };
  const proof = (binary, source, label, contract) => spawnSync('pwsh', ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-File',
    path.join(root, 'tools/update-card-release-proof.ps1'), '-Exe', binary, '-Notes', source,
    '-Evidence', path.join(directory, label), '-Wrapped', '-Contract', contract],
  { encoding: 'utf8', timeout: 180000, maxBuffer: 32 * 1024 * 1024 });
  const red = proof(before, beforeNotes, 'red', 'released');
  keepEvidence('red');
  fs.writeFileSync(path.join(evidence, 'red', 'provenance.json'), JSON.stringify({
    tag: old.tag_name,
    binary: old.assets.find(asset => asset.name === 'multiprompt-x64.exe').digest,
    notes: old.assets.find(asset => asset.name === 'release-notes.json').digest,
    notesVersion: beforeHistory.version,
    notesChanges: beforeLines.length,
  }, null, 2));
  assert.notEqual(red.status, 0, red.stdout + red.stderr);
  assert.match(red.stdout + red.stderr, /Card did not expose wrapped note bounds/);
  const redReceipt = JSON.parse(fs.readFileSync(path.join(directory, 'red', 'released-card.json'), 'utf8'));
  assert.equal(redReceipt.contract, 'released');
  assert.equal(redReceipt.binaryVersion, '0.28.983');
  assert.equal(redReceipt.version, '0.28.983');
  assert.ok(redReceipt.painted.length > 0, 'The pinned old painter named no published note, so it cannot prove the wrapping rejection');
  for (const line of redReceipt.painted) assert.ok(beforeLines.includes(line), `Old painter named a line its own release never published: ${line}`);
  assert.deepEqual(redReceipt.ids, []);
  assert.equal(redReceipt.seeAll, false);
  assert.equal(redReceipt.image.name, 'released-card', 'The old painter kept no first screenshot record');
  assert.equal(redReceipt.image.window.width, 1024, 'The old painter screenshot was not taken at the normal proof size');
  assert.equal(redReceipt.image.maximized, false, 'The old painter screenshot was taken while the window was maximized');
  assert.ok(fs.existsSync(path.join(evidence, 'red', 'released-card.png')), 'The old painter screenshot was not kept as evidence');
  const legacyButton = redReceipt.image.legacyButton;
  assert.ok(legacyButton, 'The old painter screenshot recorded no Restart button pixels');
  assert.ok(legacyButton.width >= 70 && legacyButton.width <= 100, `The old painter Restart button is ${legacyButton.width} px wide`);
  assert.ok(legacyButton.height >= 15 && legacyButton.height <= 24, `The old painter Restart button is ${legacyButton.height} px tall`);
  assert.ok(legacyButton.labelInk >= 40, `The old painter Restart button shows ${legacyButton.labelInk} white label pixels`);
  assert.ok(legacyButton.left >= 8 && legacyButton.right <= 260, 'The old painter Restart button is not the sidebar card control');
  assert.ok(legacyButton.bottom <= redReceipt.image.window.height - 8, 'The old painter Restart button was cut by the window edge');
  console.log('WRAPPED_CARD_RED v0.28.983 painted its own published notes without wrapped bounds');
  const green = proof(branch, notes, 'green', 'new');
  keepEvidence('green');
  fs.writeFileSync(path.join(evidence, 'green', 'provenance.json'), JSON.stringify({
    revision: process.env.GITHUB_SHA || 'local',
    workflowRun: process.env.GITHUB_RUN_ID || '',
    binary: branchDigest,
    binaryVersion: branchVersion,
    notes: `sha256:${createHash('sha256').update(fs.readFileSync(notes)).digest('hex')}`,
    notesVersion: history.version,
  }, null, 2));
  assert.equal(green.status, 0, green.stdout + green.stderr);
  assert.match(green.stdout, /WRAPPED_CARD_RECEIPT=/);
  assert.match(green.stdout, /WRAPPED_CARD_IMAGE=wrapped-normal:/);
  assert.match(green.stdout, /WRAPPED_CARD_IMAGE=wrapped-minimum:/);
  assert.match(green.stdout, /WRAPPED_CARD_IMAGE=wrapped-scrolled:/);
  assert.match(green.stdout, /WRAPPED_CARD_IMAGE=wrapped-collapsed:/);
  const greenReceipt = JSON.parse(fs.readFileSync(path.join(directory, 'green', 'wrapped-card.json'), 'utf8'));
  assert.equal(greenReceipt.contract, 'new');
  assert.equal(greenReceipt.sha256, branchDigest.replace('sha256:', ''));
  assert.equal(greenReceipt.binaryVersion, branchVersion);
  assert.equal(greenReceipt.version, history.version);
  const strip = change => change.trim().replace(/^(?:IGSH|MUBO)-\d+ /, '');
  const paintedLines = greenReceipt.changes.map(strip);
  assert.equal(greenReceipt.painted.length, 3, 'The branch card did not paint three real notes');
  for (const [index, line] of greenReceipt.painted.entries()) {
    assert.ok(paintedLines.includes(line), `Branch card painted a line its notes never published: ${line}`);
    assert.ok(/^(?:IGSH|MUBO)-\d+$/.test(greenReceipt.ids[index]), `Branch card gave note ${index} no ticket id: ${greenReceipt.ids[index]}`);
    assert.ok(greenReceipt.changes.some(change => change.trim() === `${greenReceipt.ids[index]} ${line}`), `Branch card paired note ${index} with an id its notes never published: ${greenReceipt.ids[index]}`);
    assert.ok(line.length >= 80, `Branch card painted a short note, so the proof did not exercise wrapping: ${line}`);
  }
  assert.equal(greenReceipt.noteHeights.length, 3);
  for (const height of greenReceipt.noteHeights) assert.ok(height > 24, `Long real note did not wrap: ${height}`);
  assert.ok(greenReceipt.scrolled.content > greenReceipt.scrolled.bottom - greenReceipt.scrolled.top, 'The wrapped notes fit without scrolling, so the proof exercised no overflow');
  assert.ok(greenReceipt.scrolled.scroll > 0, 'The wrapped notes did not scroll');
  assert.deepEqual(greenReceipt.restartAfter, greenReceipt.restartBefore, 'Scrolling moved Restart');
  assert.equal(greenReceipt.scrollVerified, true);
  const pngSize = file => {
    const head = fs.readFileSync(file);
    return { width: head.readUInt32BE(16), height: head.readUInt32BE(20) };
  };
  const savedImage = (receipt, name) => receipt.images.find(image => image.name === name);
  assert.equal(greenReceipt.firstImage.name, 'released-card', 'The branch kept no first screenshot record');
  assert.equal(greenReceipt.firstImage.window.width, 1024, 'The first branch screenshot was not taken at the normal proof size');
  assert.equal(greenReceipt.firstImage.maximized, false, 'The first branch screenshot was taken while the window was maximized');
  assert.deepEqual(pngSize(path.join(evidence, 'green', 'released-card.png')), { width: greenReceipt.firstImage.window.width, height: greenReceipt.firstImage.window.height }, 'The first branch screenshot is not the window size it records');
  assert.equal(greenReceipt.firstImage.restartVisible, true, 'The first branch screenshot does not show Restart');
  assert.equal(greenReceipt.images.length, 5, 'The branch proof recorded no images for its captured card states');
  for (const name of ['wrapped-normal', 'wrapped-minimum', 'wrapped-scrolled', 'wrapped-collapsed']) {
    const image = savedImage(greenReceipt, name);
    assert.ok(image, `Branch proof recorded no ${name} image`);
    const file = path.join(evidence, 'green', `${name}.png`);
    assert.ok(fs.existsSync(file), `Branch proof kept no ${name}.png in its evidence`);
    assert.deepEqual(pngSize(file), { width: image.window.width, height: image.window.height }, `${name}.png is not the window size it records`);
    assert.ok(image.client.left >= 0 && image.client.top >= 0 && image.client.left + image.client.width <= image.window.width && image.client.top + image.client.height <= image.window.height, `${name}.png records a client area outside its window`);
    assert.equal(image.restartVisible, true, `${name}.png does not show Restart`);
    assert.equal(image.seeAllVisible, true, `${name}.png does not show See all`);
    assert.equal(image.notesVisible, true, `${name}.png shows no note lines`);
  }
  assert.equal(savedImage(greenReceipt, 'wrapped-normal').window.height, 768, 'The whole-card screenshot was not taken at the normal proof size');
  console.log(green.stdout);
});

test('release contains one linked authoritative line for each commit ticket', async () => {
  const { buildChangelog } = await import('./version-stamp.mjs');
  const { releaseNotes } = await import('./release-notes.mjs');
  const files = {
    'src/changelog.zig': 'const SOURCE_CHANGELOG = [_]ChangelogEntry{\n    .{ .ver = "0.28.883", .items = &.{\n        .{ .text = "Earlier.", .ticket = "IGSH-1" },\n    } },\n};\n',
    [path.posix.join('changelog.d', 'IGSH-2-chat.md')]: 'Chats open sooner.\nDrafts stay visible.\n',
  };
  const titles = { 'IGSH-1': 'Earlier title', 'IGSH-2': 'Chat title', 'IGSH-3': 'Checks title' };
  const commits = [{ sha: 'aaa', subject: 'IGSH-2: Improve chats' }, { sha: 'bbb', subject: 'IGSH-3: Repair checks' }, { sha: 'ccc', subject: 'IGSH-2: Follow up' }];
  const generated = buildChangelog(files, 'v0.28.1100', [], commits, titles);
  const latest = releaseNotes(generated, 'v0.28.1100').releases[0];
  assert.deepEqual(latest.changes, ['IGSH-2 Chat title', 'IGSH-3 Checks title']);
  assert.deepEqual(latest.tickets, ['https://app.hypertask.ai/detail/project-2060/2', 'https://app.hypertask.ai/detail/project-2060/3']);
  const warnings = [];
  const warn = line => warnings.push(line);
  const keyless = buildChangelog(files, 'v0.28.1100', [], [{ sha: 'bad123', subject: 'Repair checks' }], titles, warn);
  assert.match(keyless, /\.ticket = "no-ticket"/);
  assert.ok(warnings.includes('v0.28.1100: commit bad123 has no ticket key; publishing its line without a link'), warnings.join('\n'));
  const fragmentsOnly = buildChangelog(files, 'v0.28.1100', [], [], titles, warn);
  assert.match(fragmentsOnly, /IGSH-2 Chat title/);
  assert.ok(warnings.includes('v0.28.1100: IGSH-2 fragment has no matching commit ticket; publishing it from its fragment text'), warnings.join('\n'));
  const forgedWarnings = [];
  const forged = releaseNotes(generated.replace('.ticket = "IGSH-2"', '.ticket = ""'), 'v0.28.1100', line => forgedWarnings.push(line)).releases[0];
  assert.deepEqual(forged.tickets, [null, 'https://app.hypertask.ai/detail/project-2060/3']);
  assert.deepEqual(forgedWarnings, ['Release 0.28.1100: a line has no ticket key; publishing it without a link']);
});

test('IGSH-1615 releases a reviewed commit that has no ticket prefix', async () => {
  const { buildChangelog } = await import('./version-stamp.mjs');
  const { releaseNotes } = await import('./release-notes.mjs');
  const files = {
    'src/main.zig': 'pub const APP_VERSION = "0.28.1446";\n',
    'src/changelog.zig': 'const SOURCE_CHANGELOG = [_]ChangelogEntry{\n    .{ .ver = "0.28.1446", .items = &.{\n        .{ .text = "Earlier.", .ticket = "IGSH-1" },\n    } },\n};\n',
    [path.posix.join('changelog.d', 'IGSH-1610-device.md')]: 'Devices can be approved when one host is offline.\n',
  };
  const commits = [
    { sha: '8f52c2a6cf81d617d61bf6c439ec29719d850062', subject: 'Add AGENTS.md pointing every agent at CLAUDE.md (#737)' },
    { sha: '246972c5', subject: 'IGSH-1610: Approve a device even when one SSH host is unreachable (#738)' },
  ];
  let generated;
  assert.doesNotThrow(() => { generated = buildChangelog(files, 'v0.28.1448', [], commits, { ...JSON.parse(read('tools/fixtures/IGSH-1681/ticket-titles.json')), 'IGSH-1': 'Earlier title' }); });
  const latest = releaseNotes(generated, 'v0.28.1448').releases[0];
  assert.ok(latest.changes.some(line => line.startsWith('IGSH-1610 ')));
  assert.ok(latest.changes.some(line => line.startsWith('IGSH-1615 ')));
  assert.match(generated, /\.ticket = "IGSH-1615"/);
  const warnings = [];
  const unreviewed = buildChangelog(files, 'v0.28.1448', [], [{ sha: '8f52c2a6', subject: commits[0].subject }, commits[1]], undefined, line => warnings.push(line));
  assert.match(unreviewed, /Add AGENTS\.md pointing every agent at CLAUDE\.md/);
  assert.ok(warnings.some(line => /commit 8f52c2a has no ticket key/.test(line)), warnings.join('\n'));
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
  const files = { ...history.at(-1).files, [path.posix.join('changelog.d', 'IGSH-1243-notes.md')]: 'Changelog ticket links now open their tickets.\n' };
  const generated = buildChangelog(files, 'v0.28.1100', history, [{ sha: 'new', subject: 'IGSH-1243: Explain releases' }], { ...JSON.parse(read('tools/fixtures/IGSH-1681/ticket-titles.json')), 'IGSH-1': 'Earlier title' });
  const notes = releaseNotes(generated, 'v0.28.1100');
  for (const tag of tags) {
    const release = notes.releases.find(item => item.version === tag.slice(1));
    assert.ok(release, tag);
    assert.equal(release.changes.length, release.tickets.length, tag);
    assert.ok(release.tickets.every(ticket => /^https:\/\/app\.hypertask\.ai\/detail\/project-2060\/\d+$/.test(ticket)), tag);
  }
  assert.ok(notes.releases.some(release => release.changes.length > 0));
  assert.doesNotMatch(JSON.stringify(notes), /Checks and fixes/);
  assert.equal(notes.releases.some(item => item.version === '0.28.1041'), false);
  const release1038 = notes.releases.find(item => item.version === '0.28.1038');
  const actualFragment = 'IGSH-1238 ' + JSON.parse(read('tools/fixtures/IGSH-1681/ticket-titles.json'))['IGSH-1238'];
  const fragmentIndex = release1038.tickets.indexOf('https://app.hypertask.ai/detail/project-2060/1238');
  assert.equal(release1038.changes[fragmentIndex], actualFragment);
  assert.throws(() => buildChangelog(files, 'v0.28.1100', history.map(item => item.tag === 'v0.28.1048' ? { ...item, sha: 'wrong' } : item), [{ sha: 'new', subject: 'IGSH-1243: Explain releases' }]), /reviewed release commit does not match/);
});

test('a board 2060 commit numbered SOFT releases its IGSH fragment', async () => {
  const { buildChangelog } = await import('./version-stamp.mjs');
  const files = {
    'src/changelog.zig': 'const SOURCE_CHANGELOG = [_]ChangelogEntry{\n    .{ .ver = "0.28.883", .items = &.{\n        .{ .text = "Earlier.", .ticket = "IGSH-1" },\n    } },\n};\n',
    [path.posix.join('changelog.d', 'IGSH-2272-clear-live-chat.md')]: 'Cleared chats keep their new replies.\n',
  };
  const titles = { 'IGSH-1': 'Earlier title', 'IGSH-2272': 'Check clear works in live chats' };
  let generated = null;
  try {
    generated = buildChangelog(files, 'v0.28.1100', [], [{ sha: 'aaa', subject: 'SOFT-2272: Keep cleared chats replying' }], titles);
  } catch (error) {
    generated = { error: error.message };
  }
  assert.equal(typeof generated, 'string', `release notes build: ${generated?.error}`);
  assert.match(generated, /IGSH-2272/);
});
