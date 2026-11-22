import fs from 'node:fs';

export const runtimeAsset = 'multiprompt-runtime.py';
const reader = 'chat_history_reader.py';
const sources = ['mp_send.py', 'multibot_feedback.py', 'mp_helper.py', 'mp_shell.py', 'mp_sessions.py', 'mp_layout.mjs', 'mp_fresh.py', 'mp_zsb.sh'];
const connectors = ['chat_connectors/claude.py', 'chat_connectors/codex.py'];
const names = { 'mp_send.py': 'MP_SEND_SOURCE', 'multibot_feedback.py': 'FEEDBACK_SOURCE', 'mp_helper.py': 'MP_HELPER_SOURCE', 'mp_shell.py': 'MP_SHELL_SOURCE', 'mp_sessions.py': 'MP_SESSIONS_SOURCE', 'mp_layout.mjs': 'MP_LAYOUT_SOURCE', 'mp_fresh.py': 'MP_FRESH_SOURCE', 'mp_zsb.sh': 'ZSB_SOURCE' };

const readSource = name => fs.readFileSync(new URL(`../src/${name}`, import.meta.url));

export function runtimePayload(version, read = readSource) {
  if (!/^(?:0|[1-9]\d*)\.(?:0|[1-9]\d*)\.(?:0|[1-9]\d*)$/.test(version || '')) throw new Error('Invalid runtime version');
  const encoded = name => read(name).toString('base64');
  return [
    `CONNECTOR_SOURCES = {'claude':'${encoded(connectors[0])}','codex':'${encoded(connectors[1])}'}`,
    ...sources.map(name => `${names[name]} = '${encoded(name)}'`),
    `MULTIBOT_APP_VERSION = '${version}'`,
    read(reader).toString('utf8'),
  ].join('\n');
}

export function runtimeGeneration(payload) {
  const found = /^RUNTIME_GENERATION = (\d+)$/m.exec(payload.toString('utf8'));
  if (!found) throw new Error('Runtime payload has no generation');
  return Number(found[1]);
}

if (import.meta.url === `file://${process.argv[1]}`) {
  const [tag, target] = process.argv.slice(2);
  const version = /^v((?:0|[1-9]\d*)\.(?:0|[1-9]\d*)\.(?:0|[1-9]\d*))$/.exec(tag || '')?.[1];
  if (!version || !target) throw new Error('Usage: runtime-release-asset.mjs <vX.Y.Z> <output>');
  fs.writeFileSync(target, runtimePayload(version));
  console.log(`RUNTIME_ASSET ${target} generation ${runtimeGeneration(fs.readFileSync(target))}`);
}
