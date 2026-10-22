const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const root = process.env.UPDATE_SOURCE_ROOT || path.resolve(__dirname, '..');
const read = name => fs.readFileSync(path.join(root, name), 'utf8');

test('release updater is default on and checks before session restoration', () => {
  const main = read('src/main.zig');
  assert.match(main, /if \(update_release\.startup\(args\)\) return;/);
  const updater = read('src/update_release.zig');
  assert.match(updater, /pub const IGSH_246 = true;/);
  assert.ok(main.indexOf('update_release.startup(args)') < main.indexOf('const restored = restoreSession()'));
  assert.match(main, /update_release\.ready\(\)/);
  assert.match(read('src/update_card.zig'), /update_release\.poll\(\)/);
  assert.match(main, /_ = startUpdateCardWatch\(\);\s*_ = SetTimer\(hwnd, TIMER_UPDATE_CHECK/);
});

test('periodic update never invokes restart and explicit restart uses the verified helper', () => {
  const updater = read('src/update_release.zig');
  const poll = updater.slice(updater.indexOf('pub fn poll()'), updater.indexOf('pub fn restart('));
  assert.doesNotMatch(poll, /restart\(|"Apply"|quitAll/);
  assert.match(updater, /3 \* 60 \* 60 \* 1000/);
  assert.match(read('src/update_card.zig'), /update_release\.restart\(/);
  assert.match(read('src/sidebar.zig'), /Restart to update/);
  assert.match(read('src/update_card.zig'), /Update ready: restart to get v/);
});

test('Windows behavioral update tests are required by CI', () => {
  const workflow = read('.github/workflows/test.yml');
  const jobs = Object.fromEntries([...workflow.matchAll(/^  ([\w-]+):\n((?:(?!^  [\w-]+:)[\s\S])*)/gm)].map(match => [match[1], match[2]]));
  const update = jobs['test-windows-update'];
  const build = jobs['build-windows'];
  const source = jobs['test-update-source'];
  assert.doesNotMatch(update, /^    needs:/m);
  assert.match(update, /^    runs-on: windows-latest$/m);
  assert.match(update, /name: Wait for x64 update verifier/);
  assert.match(update, /ARTIFACT: update-verifier-x64-\$\{\{ github.run_id \}\}-\$\{\{ github.run_attempt \}\}/);
  assert.match(update, /AddMinutes\(4\)/);
  assert.ok(update.indexOf('name: Prepare unsigned update fixtures') < update.indexOf('name: Wait for x64 update verifier'));
  assert.match(build, /run: zig build update-verifier -Dtarget=x86_64-windows-gnu -Drelease=true --summary all/);
  assert.ok(build.indexOf('actions/upload-artifact@') < build.indexOf('name: Build release executable for x64'));
  assert.ok(read('build.zig').includes('b.step("update-verifier", "Build the signed-update release verifier").dependOn(&b.addInstallArtifact(exe, .{}).step)'));
  assert.match(update, /if \(\$LASTEXITCODE -ne 0\) \{ throw 'Could not list update artifacts' \}/);
  assert.match(update, /scenario: \[Lifecycle, Rollback\]/);
  assert.match(update, /fail-fast: false/);
  assert.match(source, /runs-on: ubuntu-latest/);
  assert.doesNotMatch(jobs.test, /Test safe release updates|update-release/);
  assert.equal((workflow.match(/- name: Test safe release updates/g) || []).length, 1);
  assert.match(update, /- name: Test safe release updates\n        if: steps\.paths\.outputs\.heavy == 'true' && steps\.rule\.outputs\.kind != 'STAMP'/);
  for (const command of [
    'node --test tools/update-release-review.test.js',
    'node --test tools/update-release.test.js',
  ]) assert.equal(source.split('\n').filter(line => line.trim() === command).length, 1, command);
  for (const command of [
    'powershell -NoProfile -File tools/update-release-fixtures.ps1 -Root "$env:RUNNER_TEMP/update-release-fixtures"',
    'powershell -NoProfile -File tools/update-release.test.ps1 -Verifier "$pwd/update-verifier/multiprompt.exe" -TestGroup ${{ matrix.scenario }}',
  ]) assert.equal(update.split('\n').filter(line => line.trim() === command).length, 1, command);
  assert.match(source, /node --test tools\/update-release-review\.test\.js > "\$env:RUNNER_TEMP\/update-review-before\.log"/);
  assert.match(source, /foreach \(\$finding in 1\.\.9\)/);
  assert.doesNotMatch(update, /zig build|actions\/cache@|actions\/cache\/restore@|Install Zig|ZIG_GLOBAL_CACHE_DIR/);
  assert.match(update, /actions\/download-artifact@d3f86a106a0bac45b974a628896c90dbdf5c8093\n        if: steps\.paths\.outputs\.heavy == 'true' && steps\.rule\.outputs\.kind != 'STAMP'\n        with:\n          name: update-verifier-x64-\$\{\{ github.run_id \}\}-\$\{\{ github.run_attempt \}\}\n          path: update-verifier/);
  assert.match(build, /runs-on: ubuntu-latest/);
  assert.match(build, /arch: \[arm64, x64\]/);
  assert.match(build, /if: steps\.paths\.outputs\.heavy == 'true' && matrix.arch == 'x64'\n        run: zig build -Dtarget=x86_64-windows-gnu -Drelease=true --summary all\n/);
  const releaseBuild = read('.github/workflows/release.yml').match(/run: (zig build -Dtarget=.+)/)[1]
    .replace('${{ matrix.target }}', 'x86_64-windows-gnu')
    .replace("${{ github.event_name != 'pull_request' }}", 'true');
  assert.ok(build.includes(`run: ${releaseBuild} --summary all\n`));
  assert.match(build, /actions\/upload-artifact@ea165f8d65b6e75b540449e92b4886f43607fa02\n        if: steps\.paths\.outputs\.heavy == 'true' && matrix.arch == 'x64'\n        with:\n          name: update-verifier-x64-\$\{\{ github.run_id \}\}-\$\{\{ github.run_attempt \}\}\n          path: \|\n            zig-out\/bin\/multiprompt.exe\n            zig-out\/bin\/update-test-key.der\n          if-no-files-found: error\n          retention-days: 1\n          overwrite: true/);
  assert.match(build, /key: \$\{\{ runner\.os \}\}-zig-0\.16\.0-shards-v4-\$\{\{ matrix.arch \}\}-\$\{\{ hashFiles\('build\.zig', 'build\.zig\.zon'\) \}\}/);
  assert.match(update, /MULTIPROMPT_TEST_SIGNING_KEY: \$\{\{ github.workspace \}\}\/update-verifier\/update-test-key.der/);
  assert.match(build, /- name: Prepare throwaway update-test signing key\n        if: steps\.paths\.outputs\.heavy == 'true' && matrix.arch == 'x64'\n        run: node tools\/update-release-fixtures.mjs --prepare-key zig-out\/bin\/update-test-key.der/);
  assert.ok(build.indexOf('run: node tools/update-release-fixtures.mjs --prepare-key') < build.indexOf('run: zig build -Dtarget=x86_64-windows-gnu -Drelease=true --summary all'));
  const signer = read('tools/update-release-fixtures.mjs');
  assert.match(signer, /process.env.MULTIPROMPT_TEST_SIGNING_KEY[\s\S]*createPrivateKey\(\{ key: fs.readFileSync\(process.env.MULTIPROMPT_TEST_SIGNING_KEY\)/);
  assert.match(signer, /const publicKey = createPublicKey\(privateKey\)/);
  assert.match(signer, /if \(root === '--prepare-key'\) \{[\s\S]*fs.writeFileSync\(keyPath, privateKey.export\(\{ type: 'pkcs8', format: 'der' \}\)\)/);
  assert.match(source, /- name: Reject placeholder release signing key/);
  assert.match(source, /trap 'cp "\$RUNNER_TEMP\/release-signing-public-key.txt" "\$key"' EXIT/);
  assert.match(source, /printf '%s\\n' 'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=' > "\$key"/);
  assert.match(source, /if zig build -Dtarget=x86_64-windows-gnu -Drelease=true > "\$RUNNER_TEMP\/placeholder-error.txt" 2>&1; then\n            echo 'Release build did not reject the fake public key loudly'\n            exit 1/);
  assert.match(source, /grep -F 'Release signing public key is still the all-zero placeholder' "\$RUNNER_TEMP\/placeholder-error.txt"/);
  assert.doesNotMatch(read('tools/update-release-fixtures.ps1'), /zig\.exe|zig build/);
  const suite = read('tools/update-release.test.ps1');
  assert.match(suite, /ValidateSet\('All', 'Lifecycle', 'Rollback'\)/);
  assert.match(suite, /\$TestGroup = 'All'/);
  assert.match(suite, /if \(\$TestGroup -ne 'Rollback'\)/);
  assert.match(suite, /if \(\$TestGroup -ne 'Lifecycle'\)/);
  assert.match(suite, /Copy-Item "\$Root\/v1\.11\.0\/multiprompt-x64\.exe" \$target -Force/);
  assert.match(suite, /Copy-Item "\$Root\/v1\.11\.0\/zigshell-bridge-x64\.exe" "\$Root\/zigshell-bridge\.exe" -Force/);
  assert.match(suite, /if \(\$TestGroup -ne 'Rollback'\) \{\s*Select-Release 'v1.11.0'\s*Assert \(Save-Update \$target '1.10.0'/);
  assert.match(suite, /Start-Sleep -Seconds 61/);
  for (const name of ['checksum mismatch refused', 'rollback after failed start', 'no automatic restart while running', 'version comparison']) assert.ok(suite.includes(name), name);
});

const repeatedProcessPathFilters = source => {
  const lines = [];
  for (const match of source.matchAll(/\bWhere-Object\s*\{/gi)) {
    let depth = 1;
    let end = match.index + match[0].length;
    while (end < source.length && depth > 0) {
      if (source[end] === '{') depth++;
      if (source[end] === '}') depth--;
      end++;
    }
    const block = source.slice(match.index, end);
    if ((block.match(/\$_\.Path\b/gi) || []).length > 1) lines.push(source.slice(0, match.index).split('\n').length);
  }
  return lines;
};

test('process path guard detects repeated reads in single-line and nested filters', () => {
  assert.deepEqual(repeatedProcessPathFilters('Get-Process | Where-Object { $_.Path -and $_.Path.StartsWith($Root) }'), [1]);
  assert.deepEqual(repeatedProcessPathFilters('Get-Process | Where-Object {\n if ($_.Path) { $_.Path -eq $target }\n}'), [1]);
  assert.deepEqual(repeatedProcessPathFilters('Get-Process | Where-Object { $p = $_.Path; $p -and $p.StartsWith($Root) }'), []);
  assert.deepEqual(repeatedProcessPathFilters('Get-Process | Where-Object { $_.Path -eq $target }\nGet-Process | Where-Object { $_.Path -eq $other }'), []);
});

test('PowerShell test helpers read each process path once per filter', () => {
  const violations = [];
  for (const directory of ['tools', '.claude/skills/verify-multiprompt']) {
    for (const name of fs.readdirSync(path.join(root, directory), { recursive: true }).filter(name => /\.ps1$/i.test(name))) {
      const file = path.join(directory, name);
      for (const line of repeatedProcessPathFilters(read(file))) violations.push(`${file}:${line}`);
    }
  }
  assert.deepEqual(violations, [], 'Snapshot $_.Path once before checking or invoking methods on it');
});

test('the update command cannot be interpreted as a snippet', () => {
  const state = read('src/app_state.zig');
  const value = name => Number(new RegExp(`pub const ${name}: usize = (\\d+);`).exec(state)[1]);
  const update = value('SEARCH_UPDATE_OFFSET');
  const snippets = value('SEARCH_SNIPPET_OFFSET');
  assert.ok(update < snippets || update >= snippets + value('MAX_SNIPPETS'), 'Update command overlaps snippet IDs');
  const duplicates = [...state.matchAll(/pub const (SEARCH_\w+): usize = (\d+);/g)].filter(([, name, number]) => name !== 'SEARCH_UPDATE_OFFSET' && Number(number) === update);
  assert.deepEqual(duplicates, []);
});

test('fixture cleanup snapshots each live process path once and tolerates inaccessible or exited processes', () => {
  const cleanup = read('tools/update-release.test.ps1').split('function Stop-FixtureApps {')[1].split('function Wait-File')[0];
  assert.equal((cleanup.match(/\$_\.Path/g) || []).length, 1);
  assert.match(cleanup, /try \{\s*\$processPath = \$_\.Path\s*\$processPath -and \$processPath\.StartsWith\(\$Root, \[StringComparison\]::OrdinalIgnoreCase\)\s*\} catch \{ \$false \}/);
  assert.match(cleanup, /Stop-Process -Id \$_\.Id -Force -ErrorAction SilentlyContinue/);
  assert.match(cleanup, /WaitForExit\(5000\)/);
});
