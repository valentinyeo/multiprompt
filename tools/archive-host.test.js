const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const source = fs.readFileSync(path.join(__dirname, '..', 'src', 'archive.zig'), 'utf8');

function parseArchiveBody() {
  const start = source.indexOf('fn parseArchiveJson');
  assert.ok(start >= 0, 'missing parseArchiveJson');
  const end = source.indexOf('\nfn ', start + 1);
  return source.slice(start, end > start ? end : undefined);
}

test('an archived chat keeps the server it ran on', () => {
  const body = parseArchiveBody();
  const reads = body.split('\n').filter(line => /"host"/.test(line));
  assert.equal(reads.length, 1, 'archive reader should read the host once');
  assert.doesNotMatch(reads[0], /==\s*1\b/, 'archive reader must not keep only server 1');
  assert.match(body, /tmux_host\s*=\s*if\s*\(\s*host\s*<=\s*TMUX_HOST_INNE\s*\)\s*@intCast\(\s*host\s*\)\s*else\s*0/);
});

test('the archive writer and reader share the server numbering', () => {
  assert.match(source, /TMUX_HOST_INNE/);
  assert.match(source, /TMUX_HOST_UK/);
});
