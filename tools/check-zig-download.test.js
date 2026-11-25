import { test } from 'node:test';
import assert from 'node:assert/strict';
import { checkZigDownload, readWorkflows } from './check-zig-download.mjs';

test('every checked-in workflow installs Zig through the shared action', () => {
  assert.deepEqual(checkZigDownload(readWorkflows()), []);
});

test('an inline curl download fails', () => {
  const problems = checkZigDownload({ '.github/workflows/journey.yml': `      - name: Install Zig\n        run: |\n          curl -fsSL https://ziglang.org/download/0.16.0/zig-x86_64-linux-0.16.0.tar.xz -o zig.tar.xz\n` });
  assert.equal(problems.length, 1, problems.join('\n'));
  assert.match(problems[0], /journey\.yml:3: downloads Zig inline instead of \.\/\.github\/actions\/setup-zig/);
});

test('an inline PowerShell download fails', () => {
  const problems = checkZigDownload({ '.github/workflows/journey.yml': `      - name: Install Zig\n        shell: pwsh\n        run: Invoke-WebRequest https://ziglang.org/download/0.16.0/zig-x86_64-windows-0.16.0.zip -OutFile $zip\n` });
  assert.match(problems.join('\n'), /journey\.yml:3: downloads Zig inline/);
});

test('a job that calls the action is clean', () => {
  const source = `      - uses: ./.github/actions/setup-zig\n        with:\n          version: '0.16.0'\n`;
  assert.deepEqual(checkZigDownload({ '.github/workflows/journey.yml': source }), []);
});
