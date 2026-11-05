const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const source = fs.readFileSync(path.join(__dirname, 'verify-chat-delivery/boundary.py'), 'utf8');

test('Windows cancellation worker uses the production reader with its fixture boundaries', () => {
  assert.match(source, /namespace = dict\(__name__="verified_remote_reader", READER_SOURCE=source\)/);
  assert.match(source, /sys\.modules\["fcntl"\] = locking/);
  assert.match(source, /if state\(\)\.get\("name"\) == "cancel-held":[\s\S]*?args\[4\] != '--message-worker'[\s\S]*?adapted = \[args\[0\], '-u', str\(Path\(__file__\)\.resolve\(\)\), 'message-worker', \*args\[5:\]\]/);
  const adapter = source.match(/def run_message_worker\(\):([\s\S]*?)\n\ndef serve_reader\(\):/);
  assert.ok(adapter, 'worker adapter is missing');
  assert.match(adapter[1], /os\.name != "nt"[\s\S]*?state\(\)\.get\("name"\) != "cancel-held"/);
  assert.match(adapter[1], /namespace = reader_namespace\(\)/);
  assert.match(adapter[1], /if original_host_switch\(provider, sid\):\s+raise RuntimeError/);
  assert.match(adapter[1], /if not self\.get_map\(\):\s+time\.sleep\([\s\S]*?return super\(\)\.select\(timeout\)/);
  assert.match(adapter[1], /namespace\["message_worker"\]\(tmux, provider, sid\)/);
  assert.doesNotMatch(adapter[1], /message_store_request|message_apply_connector|UPDATE shared_messages|message_dispatch/);
  assert.match(source, /MODE == "message-worker" else ssh\(\)/);
});
