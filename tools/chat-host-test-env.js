const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');

function chatHostIsolatedEnv(extra = {}) {
  const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'mp-host-test-'));
  return { env: { ...process.env, TMPDIR: tmp, TMP: tmp, TEMP: tmp, ...extra }, tmp };
}

module.exports = { chatHostIsolatedEnv };