const fs = require('node:fs');
const path = require('node:path');
const { spawnSync } = require('node:child_process');

const localOnly = new Set(['tools/chat-working-bar.test.mjs', 'tools/chat-permission-buttons.test.mjs']);

function discoverTests(root) {
  const workflows = path.join(root, '.github/workflows');
  const runners = [fs.readFileSync(path.join(root, 'build.zig'), 'utf8'),
    ...fs.readdirSync(workflows).filter(file => /\.ya?ml$/.test(file))
      .flatMap(file => fs.readFileSync(path.join(workflows, file), 'utf8').split('\n')
        .filter(line => /\bnode\s+--test\b/.test(line)))].join('\n');
  const explicit = new Set(runners.match(/(?:tools|extension|service\/test)\/[\w./-]+\.test\.[cm]?js\b/g) || []);
  return ['tools', 'extension', 'service/test'].flatMap(dir =>
    fs.readdirSync(path.join(root, dir), { withFileTypes: true })
      .filter(file => file.isFile() && /\.test\.[cm]?js$/.test(file.name))
      .map(file => `${dir}/${file.name}`))
    .filter(file => !localOnly.has(file) && !explicit.has(file)).sort();
}

if (require.main === module) {
  const root = process.cwd();
  const files = discoverTests(root);
  if (process.argv.length === 3 && process.argv[2] === '--list') {
    for (const file of files) console.log(file);
  } else if (process.argv.length !== 2) {
    console.error('usage: node tools/discover-tests.cjs [--list]');
    process.exitCode = 2;
  } else if (process.env.GITHUB_ACTIONS !== 'true' && process.env.MULTIPROMPT_ALLOW_LOCAL_HEAVY !== '1') {
    console.error('runs on GitHub Actions only; push and read gh pr checks, or set MULTIPROMPT_ALLOW_LOCAL_HEAVY=1 on a machine you own');
    process.exitCode = 2;
  } else if (files.length) {
    const result = spawnSync(process.execPath, ['--test', '--test-concurrency=4', ...files], {
      cwd: root, stdio: 'inherit', env: { ...process.env, NODE_TEST_CONTEXT: undefined },
    });
    if (result.error) console.error(result.error.message);
    process.exitCode = result.status ?? 1;
  }
}

module.exports = { discoverTests };
