const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const assert = require('node:assert/strict');

const root = path.join(__dirname, '..');
const driver = fs.readFileSync(
  path.join(root, '.claude/skills/verify-multiprompt/control-feature-mb-tab-verbs.ps1'),
  'utf8',
);

function extractFunctionBody(source, name) {
  const start = source.indexOf(`function ${name}`);
  assert.ok(start >= 0, `${name} must exist in the mb tab driver`);
  const open = source.indexOf('{', start);
  let depth = 0;
  for (let i = open; i < source.length; i++) {
    if (source[i] === '{') depth += 1;
    else if (source[i] === '}') {
      depth -= 1;
      if (depth === 0) return source.slice(open + 1, i);
    }
  }
  throw new Error(`${name} body not found`);
}

test('SOFT-3142 zsb probe argv is an explicit zsb invocation from the driver', () => {
  const body = extractFunctionBody(driver, 'Build-MbTabZsbProbeArgv');
  assert.match(body, /\$script:MbTabZsbPath/);
  assert.match(body, /\+\s*@\(\$ZsbArgs\)/);
  const probeStart = extractFunctionBody(driver, 'Invoke-MbTabStandInZsb');
  assert.match(probeStart, /Build-MbTabZsbProbeArgv \$ZsbArgs/);
  assert.match(probeStart, /Invoke-MbTabStandInProcess/);
  const before = extractFunctionBody(driver, 'Assert-MbTabZsbBeforeVerb');
  assert.match(before, /@\('workspace-list'\)/);
  assert.match(before, /@\('pc-state'\)/);
  const processInfo = extractFunctionBody(driver, 'New-MbTabStandInProcessStartInfo');
  assert.match(processInfo, /Format-MbTabBashArguments \$bashArgv/);
  assert.doesNotMatch(processInfo, /'-c'/);
});