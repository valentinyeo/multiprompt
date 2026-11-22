import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import { pathToFileURL } from 'node:url';

const evidence = path.resolve(process.argv[2] || 'evidence');
const dwrite = JSON.parse(fs.readFileSync(path.join(evidence, 'chat-render-dwrite.json'), 'utf8'));
const gdi = JSON.parse(fs.readFileSync(path.join(evidence, 'chat-render-gdi.json'), 'utf8'));
assert.equal(dwrite.dwrite_enabled, true);
assert.equal(gdi.dwrite_enabled, false);
assert.equal(dwrite.n, 200);
assert.equal(gdi.n, dwrite.n);
assert.ok(dwrite.glyph_runs > dwrite.n);
assert.equal(gdi.glyph_runs, 0);
for (const key of ['width', 'height', 'font_px', 'heading_px', 'code_px', 'foreground', 'background', 'bubble_background', 'code_background', 'link_color', 'bubble', 'padding', 'radius', 'paragraph']) {
  assert.deepEqual(gdi[key], dwrite[key], `GDI and DirectWrite geometry/style differs: ${key}`);
}
for (const value of [gdi.repaint_ms, dwrite.repaint_ms]) assert.ok(Number.isFinite(value) && value > 0);
fs.writeFileSync(path.join(evidence, 'repaint-ms.json'), JSON.stringify({ gdi_ms: gdi.repaint_ms, dwrite_ms: dwrite.repaint_ms, n: dwrite.n }, null, 2) + '\n');
assert.notDeepEqual(fs.readFileSync(path.join(evidence, 'chat-markdown-render.png')), fs.readFileSync(path.join(evidence, 'chat-markdown-render-gdi.png')), 'DirectWrite must change the actual painter pixels');
assert.equal(dwrite.paragraph, 'Ready with inline code and docs.');
const fontDir = path.join(evidence, 'fonts');
fs.mkdirSync(fontDir, { recursive: true });
for (const file of ['IBMPlexSans-Regular.ttf', 'IBMPlexSans-Bold.ttf', 'NordwandMono-SemiBold.ttf']) {
  fs.copyFileSync(path.join('src', 'fonts', file), path.join(fontDir, file));
}
const cssColor = color => '#' + [color & 255, (color >>> 8) & 255, (color >>> 16) & 255].map(byte => byte.toString(16).padStart(2, '0')).join('');
const html = `<!doctype html><meta charset="utf-8"><style>
@font-face{font-family:Plex;src:url('fonts/IBMPlexSans-Regular.ttf');font-weight:400}
@font-face{font-family:Plex;src:url('fonts/IBMPlexSans-Bold.ttf');font-weight:700}
@font-face{font-family:Nordwand;src:url('fonts/NordwandMono-SemiBold.ttf');font-weight:600}
*{box-sizing:border-box}html,body{margin:0;width:${dwrite.width}px;height:${dwrite.height}px;overflow:hidden;background:${cssColor(dwrite.background)};color:${cssColor(dwrite.foreground)}}
article{position:absolute;left:${dwrite.bubble.left}px;top:${dwrite.bubble.top}px;width:${dwrite.bubble.right - dwrite.bubble.left}px;padding:${dwrite.padding}px;border-radius:${dwrite.radius}px;background:${cssColor(dwrite.bubble_background)};font:400 ${dwrite.font_px}px Plex;font-synthesis:none}
h1{font-size:${dwrite.heading_px}px;font-weight:700;margin:0 0 6px}p{margin:0}strong{font-weight:700}code{font:600 ${dwrite.code_px}px Nordwand;background:${cssColor(dwrite.code_background)}}a{color:${cssColor(dwrite.link_color)};text-decoration:none}
</style><article><h1>Progress</h1><p><strong>Ready</strong> with <code>inline code</code> and <a href="https://example.test">docs</a>.</p></article>`;
const htmlPath = path.join(evidence, 'chrome-reference.html');
fs.writeFileSync(htmlPath, html);
const chrome = [process.env.CHROME_PATH, path.join(process.env.PROGRAMFILES || '', 'Google/Chrome/Application/chrome.exe'), path.join(process.env['PROGRAMFILES(X86)'] || '', 'Google/Chrome/Application/chrome.exe')].find(file => file && fs.existsSync(file));
assert.ok(chrome, 'Installed Chrome not found');
const profile = fs.mkdtempSync(path.join(process.env.RUNNER_TEMP || os.tmpdir(), 'chat-chrome-'));
try {
  const result = spawnSync(chrome, ['--headless=new', '--disable-gpu', '--no-first-run', '--no-default-browser-check', `--user-data-dir=${profile}`, '--force-device-scale-factor=1', '--hide-scrollbars', '--allow-file-access-from-files', '--run-all-compositor-stages-before-draw', '--virtual-time-budget=2000', `--window-size=${dwrite.width},${dwrite.height}`, `--screenshot=${path.join(evidence, 'chrome-reference.png')}`, pathToFileURL(htmlPath).href], { encoding: 'utf8', timeout: 60000 });
  assert.equal(result.status, 0, result.stdout + result.stderr);
  const png = fs.readFileSync(path.join(evidence, 'chrome-reference.png'));
  assert.equal(png.readUInt32BE(16), dwrite.width);
  assert.equal(png.readUInt32BE(20), dwrite.height);
} finally {
  fs.rmSync(profile, { recursive: true, force: true, maxRetries: 3 });
}
console.log('Chat rendering reference and repaint evidence complete.');
