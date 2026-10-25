import assert from 'node:assert/strict';
import fs from 'node:fs';

const source = fs.readFileSync('src/chat_render.zig', 'utf8');
const names = [...source.matchAll(/^test "(IGSH-816 CLEAN[^"\n]+)"/gm)].map(match => match[1]);
assert.ok(names.length > 0, 'No CLEAN pixel tests found in source');
const output = fs.readFileSync(process.argv[2], 'utf8').replace(/\x1b\[[0-9;]*m/g, '');
const passed = new Set([...output.matchAll(/^\d+\/\d+ chat_render\.test\.(IGSH-816 CLEAN[^\r\n]+)\.\.\.OK\r?$/gm)].map(match => match[1]));
const missing = names.filter(name => !passed.has(name));
assert.deepEqual(missing, [], `Missing passing CLEAN pixel tests: ${missing.join(', ')}`);
console.log(`CLEAN pixel coverage verified: ${names.length}/${names.length} tests passed`);
