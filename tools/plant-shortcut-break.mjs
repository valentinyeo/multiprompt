import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

export function plantShortcutBreak(source) {
  const action = '_ = PostMessageW(app_state.g_main_hwnd, WM_APP_TOGGLE_SIDEBAR, 0, 0);';
  const hook = /if \(kb\.vkCode == 0x42 and shift\) \{\s*([^]*?)\s*return 1;\s*\}/g;
  const matches = [...source.matchAll(hook)].filter(match => match[1].trim() === action);
  if (matches.length !== 1) throw new Error('Expected exactly one Ctrl+Shift+B sidebar hook; mutation was not applied');
  const match = matches[0];
  return source.slice(0, match.index) + match[0].replace(action, '') + source.slice(match.index + match[0].length);
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const root = process.argv[2];
  if (!root || process.argv.length !== 3) throw new Error('Usage: node tools/plant-shortcut-break.mjs <disposable-source-checkout>');
  if (process.env.GITHUB_ACTIONS !== 'true' || process.env.RUNNER_OS !== 'Windows') throw new Error('Plant the shortcut break only on GitHub Windows');
  const file = path.join(root, 'src/shortcuts.zig');
  fs.writeFileSync(file, plantShortcutBreak(fs.readFileSync(file, 'utf8')));
  fs.mkdirSync(path.join(root, 'zig-out/bin'), { recursive: true });
  fs.writeFileSync(path.join(root, 'zig-out/bin/shortcut-break.json'), JSON.stringify({ source: 'src/shortcuts.zig', mutation: 'Consume Ctrl+Shift+B without posting the sidebar action', journey: 'generated-sidebar-cycle' }, null, 2) + '\n');
}
