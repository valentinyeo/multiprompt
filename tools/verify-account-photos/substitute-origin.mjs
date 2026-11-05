import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';

const [client, endpointFile] = process.argv.slice(2);
const endpoint = readFileSync(endpointFile, 'utf8').trim();
if (!/^https:\/\/[a-z0-9-]+\.trycloudflare\.com$/.test(endpoint)) throw new Error('Invalid isolated endpoint');
const host = endpoint.slice('https://'.length);
let path;
let replacements;
let evidence;
if (client === 'desktop') {
  path = 'src/account_client.zig';
  replacements = [
    ['pub const origin = "https://account.multiprompt.dev";', `pub const origin = "${endpoint}";`],
    ['WinHttpConnect(session, L("account.multiprompt.dev"), 443, 0)', `WinHttpConnect(session, L("${host}"), 443, 0)`]
  ];
  evidence = 'desktop-evidence';
} else if (client === 'android') {
  path = 'companion/app/build.gradle.kts';
  replacements = [[
    'buildConfigField("String", "ACCOUNT_ORIGIN", "\\"https://account.multiprompt.dev\\"")',
    `buildConfigField("String", "ACCOUNT_ORIGIN", "\\"${endpoint}\\"")`
  ]];
  evidence = 'phone-evidence';
} else throw new Error('Invalid client');
let source = readFileSync(path, 'utf8');
for (const [before, after] of replacements) {
  if (source.split(before).length !== 2) throw new Error('Expected exactly one production origin');
  source = source.replace(before, after);
}
writeFileSync(path, source);
mkdirSync(evidence, { recursive: true });
writeFileSync(`${evidence}/origin-provenance.json`, JSON.stringify({ mode: 'isolated-source-substitution', client, source_revision: client === 'android' ? 'b109a086e010831d90770656df499405fda3d3bd' : process.env.GITHUB_SHA, production_origin: 'https://account.multiprompt.dev', fixture_origin: endpoint, release_byte_equivalent: false }) + '\n');
