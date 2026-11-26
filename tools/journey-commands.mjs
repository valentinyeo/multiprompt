import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

export const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');

const rows = [
  ['Move to Group', 'SEARCH_GROUPMOVE_MENU_OFFSET', 'move to group'],
  ['Rename', 'SEARCH_TABCTX_RENAME', 'rename session'],
  ['Pin', 'SEARCH_TABCTX_PIN_TOP', 'pin'],
  ['Unpin', 'SEARCH_TABCTX_PIN_TOP', 'unpin'],
  ['Mute Tab', 'SEARCH_MUTETAB_OFFSET', 'mute tab'],
  ['Unmute Tab', 'SEARCH_MUTETAB_OFFSET', 'unmute tab'],
  ['Changelog', 'SEARCH_CHANGELOG_OFFSET', 'changelog'],
  ['Pick repo...', 'SEARCH_PICK_REPO_OFFSET', 'pick repo'],
  ['Set workspace folder...', 'SEARCH_SET_FOLDER_OFFSET', 'set workspace folder'],
  ['Archive chat', 'SEARCH_TABCTX_ARCHIVE', 'archive chat'],
  ['UI Size: Increase', 'SEARCH_UI_BIGGER_OFFSET', 'ui'],
  ['UI Size: Reset', 'SEARCH_UI_RESET_OFFSET', 'ui'],
  ['Restart to Update', 'SEARCH_UPDATE_OFFSET', 'restart to update'],
  ['Manage snippets', 'SEARCH_SNIPPET_MANAGE_OFFSET', 'manage snippets'],
  ['Use snippets', 'SEARCH_SNIPPETS_MENU_OFFSET', 'use snippets'],
  ['Tab order: auto', 'SEARCH_TABSORT_INBOX_OFFSET', 'tab order'],
  ['Sign in to Google in this profile', 'SEARCH_TABCTX_GOOGLE_SIGNIN', 'sign in to google'],
  ['Show Workspace Switcher', 'SEARCH_HIDEPILLS_OFFSET', 'workspace switcher'],
  ['Chat View on everywhere', 'SEARCH_CHAT_VIEW_MODE_EVERYWHERE_OFFSET', 'chat view on everywhere'],
  ['Chat View off everywhere', 'SEARCH_CHAT_VIEW_MODE_NOWHERE_OFFSET', 'chat view off everywhere'],
  ['Single-Window Mode', 'SEARCH_SINGLEWIN_OFFSET', 'single window'],
  ['Rename workspace', 'SEARCH_RENAMEWIN_OFFSET', 'rename workspace'],
  ['Delete workspace', 'SEARCH_WORKSPACE_DELETE_MENU_OFFSET', 'delete workspace'],
  ['Archive workspace', 'SEARCH_CLOSEWIN_OFFSET', 'archive workspace'],
  ['Open workspace', 'SEARCH_WORKSPACES_MENU_OFFSET', 'open workspace'],
  ['Archived workspaces', 'SEARCH_WORKSPACE_ARCHIVED_MENU_OFFSET', 'archived workspaces'],
  ['Browser: Auto-Suspend Idle Panes', 'SEARCH_BROWSER_AUTOSUSPEND_OFFSET', 'browser auto suspend'],
  ['Browser: Open URL...', 'SEARCH_BROWSER_URL_OFFSET', 'browser url'],
  ['Browser: Use App Address Bar', 'SEARCH_BROWSER_MODE_OFFSET', 'browser mode'],
  ['Browser: Switch Focus Between Terminal and Pane', 'SEARCH_BROWSER_FOCUS_TOGGLE_OFFSET', 'jump browser'],
  ['Open Browser Pane', 'SEARCH_BROWSER_TOGGLE_OFFSET', 'open browser'],
  ['Close all browser panes', 'SEARCH_CLOSE_ALL_BROWSER_PANES_OFFSET', 'close all browser panes'],
  ['Switch to shell', 'SEARCH_CHAT_VIEW_OFFSET', 'switch to terminal'],
  ['Themes', 'SEARCH_THEME_MENU_OFFSET', 'themes'],
  ['Settings', 'SEARCH_SETTINGS_OFFSET', 'settings'],
  ['Servers', 'SEARCH_SERVERS_OFFSET', 'servers'],
  ['Chat View: Expand table', 'SEARCH_CHAT_EXPAND_TABLE_OFFSET', 'expand table'],
  ['Chat View: More Menu', 'SEARCH_CHAT_MORE_MENU_OFFSET', 'more menu'],
  ['Computer: Show or hide', 'SEARCH_COMPUTER_TOGGLE_OFFSET', 'computer'],
  ['Chat permission mode: Accept edits', 'SEARCH_CHAT_MODE_EDITS_OFFSET', 'accept edits'],
  ['Sidebar: hide', 'SEARCH_SIDEBAR_HIDE_OFFSET', 'hide sidebar'],
  ['Sidebar: expand', 'SEARCH_HIDESIDEBAR_OFFSET', 'show sidebar'],
  ['Reopen closed tab', 'SEARCH_REOPEN_OFFSET', 'reopen closed tab'],
  ['chat view select all', 'SEARCH_CHAT_SELECT_ALL_OFFSET', 'chat view select all'],
];

const roomRows = [
  ['New room', 'new_room_target'],
  ['Edit room', 'edit_room_target'],
];

export function commandCatalog(read = file => fs.readFileSync(path.join(root, 'src', file), 'utf8')) {
  const state = read('app_state.zig');
  const palette = read('command_palette.zig');
  const sources = [palette, read('sidebar.zig'), read('ui_words.zon'), read('shortcuts.zig')].join('\n').toLowerCase();
  const offsets = new Map([...state.matchAll(/pub const (SEARCH_\w+): usize = (\d+);/g)].map(([, key, value]) => [key, Number(value)]));
  const commands = {};
  for (const [name, symbol, query] of rows) {
    if (!offsets.has(symbol)) throw new Error(`Unknown palette routing symbol ${symbol}`);
    if (!sources.includes(name.toLowerCase())) throw new Error(`Journey command name is no longer in the palette or shortcuts: ${name}`);
    commands[name.toLowerCase()] = { name, query, target: offsets.get(symbol) };
  }
  const shells = palette.match(/const labels = \[_\]\[\]const u8\{([^]*?)\};/);
  if (!shells) throw new Error('Palette shell catalog missing');
  [...shells[1].matchAll(/"([^"\n]+)"/g)].forEach(([, name], index) => {
    commands[name.toLowerCase()] = { name, query: name, target: offsets.get('SEARCH_NEW_OFFSET') + index };
  });
  for (const [, symbol, name] of palette.matchAll(/if \(target == (SEARCH_NEW_\w+_OFFSET)\) return "([^"\n]+)";/g)) {
    commands[name.toLowerCase()] = { name, query: name, target: offsets.get(symbol) };
  }
  const room = read('room_frontend.zig');
  for (const [name, symbol] of roomRows) {
    const target = Number(room.match(new RegExp(`pub const ${symbol}: usize = (\\d+);`))?.[1]);
    if (!target) throw new Error(`Unknown room palette target ${symbol}`);
    commands[name.toLowerCase()] = { name, query: name.toLowerCase(), target };
  }
  return commands;
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  process.stdout.write(JSON.stringify(commandCatalog()));
}
