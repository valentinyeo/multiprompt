const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('path');

const root = path.resolve(__dirname, '..');

const rows = [
  ['Archive Session / Close Session', 'Archive chat'],
  ['Browser: Repair Agent Connection', 'Browser: Repair browser connection'],
  ['Browser: Switch Focus Between Terminal and Pane', 'Browser: Switch focus between chat and pane'],
  ['Commands: Edit commands.json', 'Edit custom commands'],
  ['Create Workspace / New Workspace / New Window', 'New workspace'],
  ['Edge Grey (theme)', 'Grey'],
  ['End tmux session / Delete', 'Delete chat'],
  ['Face options (20 faces)', 'Give each face its own name'],
  ['Favorite: Toggle / Favorite / Unfavorite', 'Favorite'],
  ['Pin to Top / Unpin from Top / Pin', 'Pin'],
  ['Power Saver: Auto', 'Power Saver'],
  ['Quit multi bot', 'Quit Multi Bot'],
  ['Restart multi bot', 'Restart Multi Bot'],
  ['Sidebar: expand', 'Sidebar'],
  ['Tab order: auto', 'Tab order'],
  ['Token Ladder: Auto', 'Token plan'],
  ['Usage and servers / collapsed status cards', 'Status cards'],
  ['Usage: Sign In to Primary Claude Account', 'Usage: Sign in to Claude'],
  ['Voice Speed: 1x', 'Voice speed'],
  ['Chat View: Add selection to chat', 'Add selection to chat'],
  ['Chat View: Allow', 'Allow'],
  ['Chat View: Always allow', 'Always allow'],
  ['Chat View: Attach File', 'Attach file'],
  ['Chat View: CLEAN chat: ON / OFF (toggle)', 'Hide read receipts'],
  ['Chat View: Copy Latest Code Block', 'Copy latest code block'],
  ['Chat View: Deny', 'Deny'],
  ['Chat View: Discard Unsent Messages', 'Clear unsent messages'],
  ['Chat View: Edit Queued Messages', 'Edit queued messages'],
  ['Chat View: Expand table', 'Expand table'],
  ['Chat View: Find in conversation', 'Find in conversation'],
  ['Chat View: Insert browser tab URL', 'Insert browser page link'],
  ['Chat View: Insert Command or Skill...', 'Insert command or skill'],
  ['Chat View: More Menu', 'More menu'],
  ['Chat View: Open or fold all tool steps', 'Open or fold tool steps'],
  ['Chat View: Plus Menu', 'Plus menu'],
  ['Chat View: Reply to latest agent message', 'Reply to latest message'],
  ['Chat View: Reset this chat', 'Reset this chat'],
  ['Chat View: Restart every idle live chat', 'Restart every idle chat'],
  ['Chat View: Restart this chat on the newest version', 'Restart this chat on the newest version'],
  ['Chat View: Resync chat', 'Resync chat'],
  ['Chat View: Scroll to newest message', 'Jump to newest message'],
  ['Chat View: Send Queued Messages Now', 'Send queued messages now'],
  ['Chat View: Stop the agent', 'Stop agent'],
  ['Chat View: Toggle Dictation', 'Dictate'],
  ['Chat View: Toggle todo list', 'Toggle todo list'],
];

const oldAliases = {
  'Archive Session / Close Session': ['Archive Session', 'Close Session'],
  'Create Workspace / New Workspace / New Window': ['Create Workspace', 'New Workspace', 'New Window'],
  'Edge Grey (theme)': ['Edge Grey'],
  'End tmux session / Delete': ['End tmux session'],
  'Face options (20 faces)': ['Face options (20 faces)', 'Bot face'],
  'Favorite: Toggle / Favorite / Unfavorite': ['Favorite: Toggle', 'Unfavorite'],
  'Pin to Top / Unpin from Top / Pin': ['Pin to Top', 'Unpin from Top'],
  'Chat View: CLEAN chat: ON / OFF (toggle)': ['Chat View: CLEAN chat: ON (toggle)', 'Chat View: CLEAN chat: OFF (toggle)'],
};

function quoted(text, pattern) {
  const out = [];
  const re = pattern;
  let match;
  while ((match = re.exec(text))) out.push(match[1]);
  return out;
}

function displayCorpus() {
  const words = fs.readFileSync(path.join(root, 'src/ui_words.zon'), 'utf8');
  const sidebar = fs.readFileSync(path.join(root, 'src/sidebar.zig'), 'utf8');
  const shortcuts = fs.readFileSync(path.join(root, 'src/shortcuts.zig'), 'utf8');
  const help = fs.readFileSync(path.join(root, 'openwiki/operations/keyboard-shortcuts.md'), 'utf8');
  return [
    ...quoted(words, /"((?:\\.|[^"\\])*)"/g),
    ...quoted(sidebar, /L\("((?:\\.|[^"\\])*)"\)/g),
    ...quoted(shortcuts, /\.a = "((?:\\.|[^"\\])*)"/g),
    help,
  ].join('\n');
}

function aliasesFor(oldName) {
  return oldAliases[oldName] || [oldName];
}

test('SOFT-1970 Ctrl+K shows the new names and keeps the old names as search text', () => {
  assert.equal(rows.length, 45);
  const shown = displayCorpus();
  const palette = fs.readFileSync(path.join(root, 'src/command_palette.zig'), 'utf8').toLowerCase();
  const seen = new Set();
  for (const [oldName, newName] of rows) {
    assert.ok(shown.includes(newName), `missing new name: ${newName}`);
    for (const alias of aliasesFor(oldName)) {
      if (alias !== newName) {
        assert.equal(shown.includes(alias), false, `old name still shown: ${alias}`);
      }
      assert.ok(palette.includes(alias.toLowerCase()), `old name missing from search: ${alias}`);
      seen.add(alias);
    }
  }
  assert.ok(seen.size >= 45);
});
