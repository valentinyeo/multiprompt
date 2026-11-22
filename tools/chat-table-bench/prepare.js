const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');

function prepare(root) {
  const render = path.join(root, 'src/chat_render.zig');
  const source = fs.readFileSync(render, 'utf8');
  assert.equal([...source.matchAll(/^fn chatTableLayout\(/gm)].length, 1, 'production layout entry must be unique');
  assert.ok(!source.includes('pub const benchTableLayout'), 'checkout already prepared');
  fs.writeFileSync(render, `${source}\npub const benchTableLayout = chatTableLayout;\n`);
  fs.copyFileSync(path.join(__dirname, 'main.zig'), path.join(root, 'src/chat_table_bench.zig'));
}

module.exports = { prepare };
if (require.main === module) prepare(path.resolve(process.argv[2]));
