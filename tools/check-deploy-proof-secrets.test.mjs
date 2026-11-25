import { readFileSync } from 'node:fs';
import test from 'node:test';
import assert from 'node:assert/strict';
import { fileURLToPath } from 'node:url';

const path = fileURLToPath(new URL('../.github/workflows/service-deploy-proof.yml', import.meta.url));
const workflow = readFileSync(path, 'utf8');

const secretish = /SECRET|TOKEN|PASSWORD|CREDENTIAL|PRIVATE_KEY|API_KEY/i;
const generation = /^\s*([A-Za-z_][A-Za-z0-9_]*)=.*\$\(.*(?:openssl rand|randomBytes|rand_bytes|uuidgen)/;
const mentions = (line, name) => line.includes('$' + name) || line.includes('${' + name + '}');

export const stepBlocks = text => text.split(/(?=^      - )/m).filter(block => block.trim());

export function violations(text) {
  const found = [];
  for (const block of stepBlocks(text)) {
    const lines = block.split('\n');
    const generated = lines.map(line => generation.exec(line)).filter(Boolean).map(match => match[1]);
    for (const name of generated) {
      const start = lines.findIndex(line => generation.exec(line)?.[1] === name);
      const use = lines.findIndex((line, index) => index > start && mentions(line, name));
      if (use < 0 || !lines[use].includes('::add-mask::')) found.push(`generated secret ${name} is used before it is masked`);
    }
    lines.forEach((line, index) => {
      if (!/>>[ \t]*"?\$GITHUB_ENV"?/.test(line)) return;
      const assignment = /([A-Za-z_][A-Za-z0-9_]*)=(\S*)/.exec(line);
      if (!assignment) return;
      const [, target, value] = assignment;
      if (value.includes('${{ secrets.')) return;
      const source = /\$\{?([A-Za-z_][A-Za-z0-9_]*)\}?/.exec(value)?.[1];
      if (!source || !generated.includes(source)) return;
      if (!secretish.test(target) && !secretish.test(source)) return;
      const masked = lines.slice(0, index).some(previous => previous.includes('::add-mask::$' + source) || previous.includes('::add-mask::${' + source + '}'));
      if (!masked) found.push(`generated secret ${source} reaches GITHUB_ENV unmasked`);
    });
    for (const line of lines) {
      if (!/wrangler secret put/.test(line)) continue;
      if (/--value/.test(line)) found.push('wrangler secret put takes its value on the command line');
      if (!/<[ \t]*"?\$\{?(RUNNER_TEMP|GITHUB_ENV)/.test(line)) found.push('wrangler secret put must read the value from stdin');
    }
    for (const line of lines) {
      if (/vars\.BETTER_AUTH_SECRET\s*=/.test(line) || /--var[^\n]*BETTER_AUTH_SECRET/.test(line)) found.push('the auth secret is set as a plain var');
    }
  }
  const last = stepBlocks(text).at(-1) || '';
  if (!/if: always\(\)/.test(last)) found.push('the last step does not run with if: always()');
  if (!/wrangler delete/.test(last)) found.push('the last step does not delete the proof Worker');
  if (!/wrangler d1 delete/.test(last)) found.push('the last step does not delete the proof database');
  return found;
}

const mutate = (from, to) => {
  assert.ok(workflow.includes(from), `the workflow no longer contains ${from}`);
  return workflow.replace(from, to);
};

test('the deploy proof masks every secret it generates', () => {
  assert.deepEqual(violations(workflow), []);
});

test('the deploy proof never writes a generated secret to GITHUB_ENV unmasked', () => {
  const unmasked = mutate('          printf \'%s\' "$secret" > "$RUNNER_TEMP/proof-auth-secret"', '          echo "PROOF_AUTH_SECRET=$secret" >> "$GITHUB_ENV"\n          printf \'%s\' "$secret" > "$RUNNER_TEMP/proof-auth-secret"');
  const broken = unmasked.replace('          echo "::add-mask::$secret"\n', '');
  assert.match(violations(broken).join('\n'), /GITHUB_ENV unmasked/);
});

test('the deploy proof fails when the auth secret is not masked first', () => {
  const broken = mutate('          echo "::add-mask::$secret"\n', '');
  assert.match(violations(broken).join('\n'), /used before it is masked/);
});

test('the deploy proof fails when the auth secret goes in as a plain var', () => {
  const broken = mutate('delete config.vars.BETTER_AUTH_SECRET;', 'config.vars.BETTER_AUTH_SECRET=process.env.PROOF_AUTH_SECRET;');
  assert.match(violations(broken).join('\n'), /plain var/);
});

test('the deploy proof fails when the secret is passed on the command line', () => {
  const broken = mutate('< "$RUNNER_TEMP/proof-auth-secret"', '--value testing');
  assert.match(violations(broken).join('\n'), /command line|stdin/);
});

test('the deploy proof fails when nothing deletes the proof resources', () => {
  const broken = mutate('        if: always()\n', '');
  assert.match(violations(broken).join('\n'), /if: always\(\)/);
});
