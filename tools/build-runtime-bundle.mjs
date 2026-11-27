import fs from 'node:fs';
import path from 'node:path';

export const ASSET_NAME = 'multiprompt-runtime.py';
export const READER_SOURCE = 'src/chat_history_reader.py';

export const BUNDLE_TEMPLATE =
  "ROOM_SERVICE_SOURCE = '{room_service}'\n" +
  "ROOM_BRIDGE_SOURCE = '{room_bridge}'\n" +
  "CONNECTOR_SOURCES = {'claude':'{claude}','codex':'{codex}'}\n" +
  "MP_SEND_SOURCE = '{mp_send}'\n" +
  "FEEDBACK_SOURCE = '{feedback}'\n" +
  "MP_HELPER_SOURCE = '{mp_helper}'\n" +
  "MP_SHELL_SOURCE = '{mp_shell}'\n" +
  "MP_SESSIONS_SOURCE = '{mp_sessions}'\n" +
  "MP_LAYOUT_SOURCE = '{mp_layout}'\n" +
  "MP_FRESH_SOURCE = '{mp_fresh}'\n" +
  "ZSB_SOURCE = '{zsb}'\n" +
  "MULTIBOT_APP_VERSION = '{version}'\n" +
  '{reader}';

export const BUNDLE_SOURCES = {
  room_service: 'src/room_service.py',
  room_bridge: 'src/room_bridge.py',
  claude: 'src/chat_connectors/claude.py',
  codex: 'src/chat_connectors/codex.py',
  mp_send: 'src/mp_send.py',
  feedback: 'src/multibot_feedback.py',
  mp_helper: 'src/mp_helper.py',
  mp_shell: 'src/mp_shell.py',
  mp_sessions: 'src/mp_sessions.py',
  mp_layout: 'src/mp_layout.mjs',
  mp_fresh: 'src/mp_fresh.py',
  zsb: 'src/mp_zsb.sh',
};

export function readAppVersion(root) {
  const source = fs.readFileSync(path.join(root, 'src/main.zig'), 'utf8');
  const match = /^pub const APP_VERSION = (?:build_config\.app_version orelse )?"(\d+)\.(\d+)\.(\d+)";$/m.exec(source);
  if (!match) throw new Error('src/main.zig has no APP_VERSION');
  return `${match[1]}.${match[2]}.${match[3]}`;
}

export function checkVersion(version) {
  if (typeof version !== 'string' || !/^(?:0|[1-9]\d*)\.(?:0|[1-9]\d*)\.(?:0|[1-9]\d*)$/.test(version)) {
    throw new Error(`Invalid bundle version: ${version}`);
  }
  return version;
}

export function buildRuntimeBundle({ version, root = process.cwd(), reader = READER_SOURCE, sources = {} } = {}) {
  checkVersion(version);
  const files = { ...BUNDLE_SOURCES, ...sources };
  const values = {};
  for (const [name, file] of Object.entries(files)) {
    const bytes = fs.readFileSync(path.resolve(root, file));
    values[name] = bytes.toString('base64');
  }
  values.version = version;
  values.reader = fs.readFileSync(path.resolve(root, reader));
  let offset = 0;
  const parts = [];
  const markers = [...BUNDLE_TEMPLATE.matchAll(/\{(\w+)\}/g)];
  for (const marker of markers) {
    if (!(marker[1] in values)) throw new Error(`Unknown bundle placeholder: ${marker[1]}`);
    parts.push(Buffer.from(BUNDLE_TEMPLATE.slice(offset, marker.index), 'utf8'));
    const value = values[marker[1]];
    parts.push(Buffer.isBuffer(value) ? value : Buffer.from(value, 'utf8'));
    offset = marker.index + marker[0].length;
  }
  parts.push(Buffer.from(BUNDLE_TEMPLATE.slice(offset), 'utf8'));
  return Buffer.concat(parts);
}

export function parseArgs(argv) {
  const options = { out: null, version: null, root: process.cwd(), reader: READER_SOURCE, sources: {} };
  for (let index = 0; index < argv.length; index += 1) {
    const argument = argv[index];
    if (argument === '--version') options.version = argv[++index];
    else if (argument === '--root') options.root = argv[++index];
    else if (argument === '--reader') options.reader = argv[++index];
    else if (argument === '--source') {
      const pair = String(argv[++index] || '').split('=');
      if (pair.length !== 2 || !pair[0] || !pair[1]) throw new Error('--source expects name=path');
      options.sources[pair[0]] = pair[1];
    } else if (argument.startsWith('--')) throw new Error(`Unknown option: ${argument}`);
    else if (options.out === null) options.out = argument;
    else throw new Error(`Unexpected argument: ${argument}`);
  }
  if (options.out === null) throw new Error('Usage: node tools/build-runtime-bundle.mjs <out> [--version x.y.z] [--reader path] [--source name=path]');
  options.version = checkVersion(options.version === null ? readAppVersion(options.root) : options.version);
  for (const name of Object.keys(options.sources)) {
    if (!(name in BUNDLE_SOURCES)) throw new Error(`Unknown bundle source: ${name}`);
  }
  return options;
}

if (import.meta.url === `file://${process.argv[1]}`) {
  const options = parseArgs(process.argv.slice(2));
  const bundle = buildRuntimeBundle(options);
  fs.mkdirSync(path.dirname(path.resolve(options.out)), { recursive: true });
  fs.writeFileSync(options.out, bundle);
  console.log(JSON.stringify({ asset: ASSET_NAME, version: options.version, bytes: bundle.length }));
}
