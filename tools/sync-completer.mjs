import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const installer = path.join(root, 'tools/agent-notifications/mp_complete.py');
const embedded = path.join(root, 'src/mp_complete.py');

if (process.argv.includes('--check')) {
  const same = fs.existsSync(embedded) && fs.readFileSync(embedded).equals(fs.readFileSync(installer));
  if (!same) {
    console.error('src/mp_complete.py is out of date; run node tools/sync-completer.mjs');
    process.exit(1);
  }
  console.log('src/mp_complete.py matches the installer copy');
} else {
  fs.copyFileSync(installer, embedded);
  console.log('wrote src/mp_complete.py');
}
