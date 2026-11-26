import { test } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
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

test('every verify step that runs zig also installs it on the tagged path', () => {
  const workflow = fs.readFileSync(new URL('../.github/workflows/verify.yml', import.meta.url), 'utf8');
  const verify = workflow.split('\n  verify:\n')[1];
  const steps = verify.split(/\n      - (?=name:|uses:)/).slice(1);
  const condition = (text) => (/\n        if: ([^\n]+)/.exec(text) || [])[1] || '';
  const install = steps.find((step) => step.startsWith('name: Install Zig 0.16.0'));
  assert.ok(install, 'the verify job installs Zig');
  const installed = condition(install);
  assert.match(installed, /env\.RELEASE_TAG == ''/, 'the branch path always installs Zig');
  const covered = (term) => installed.includes(term);
  const missing = [];
  for (const step of steps) {
    const name = step.split('\n')[0].replace('name: ', '');
    if (!/\bzig (cc|build|test)\b/.test(step)) continue;
    const when = condition(step);
    if (when.includes("RELEASE_TAG == ''")) continue;
    const terms = when.match(/env\.[A-Za-z_]+ == '[^']*'/g) || [];
    assert.ok(terms.length, `${name} runs zig unconditionally`);
    if (!terms.some(covered)) missing.push(name);
  }
  assert.deepEqual(missing, [], 'these steps run zig on the tagged path without installing it');
});
