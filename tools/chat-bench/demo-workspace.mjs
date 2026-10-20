export const sessions = [
  { sid: 'demo-dark-mode', name: 'Dark mode toggle', hero: true },
  { sid: 'demo-flaky-test', name: 'Flaky login test', favorite: true },
  { sid: 'demo-release-notes', name: 'Release notes 1.4' },
  { sid: 'demo-rate-limits', name: 'API rate limits' },
  { sid: 'demo-docs-search', name: 'Docs search' },
  { sid: 'demo-onboarding', name: 'Onboarding copy' }
];

const hero = [
  ['user', 'Where does the app pick its colors today?'],
  ['tool', 'Grep', { pattern: 'theme', path: '/home/dev/notebook/src' }, 'src/theme.ts\nsrc/App.tsx'],
  ['assistant', 'Colors live in `src/theme.ts`. `App.tsx` always loads the light theme, and nothing reads the system setting yet.'],
  ['user', 'Add a dark mode toggle to the settings page. It should follow the system theme until someone picks one.'],
  ['tool', 'Read', { file_path: '/home/dev/notebook/src/settings/SettingsPage.tsx' }, 'export function SettingsPage() { ... }'],
  ['tool', 'Read', { file_path: '/home/dev/notebook/src/theme.ts' }, 'export const themes = { light, dark };'],
  ['tool', 'Edit', { file_path: '/home/dev/notebook/src/theme.ts' }, 'Updated theme.ts'],
  ['assistant', 'Done. Settings now has an **Appearance** row with three choices: *System*, *Light* and *Dark*.\n\n' +
    'Until someone picks one, the app follows the system theme and switches live when the OS changes. The choice is saved per device.\n\n' +
    '- `src/theme.ts`: `useTheme()` reads the saved choice and falls back to the system\n- `src/settings/SettingsPage.tsx`: new Appearance row\n- `src/theme.test.ts`: 4 new tests\n\n' +
    '```ts\nexport function useTheme(): Theme {\n  const saved = useStoredChoice("theme");\n  const system = useMediaQuery("(prefers-color-scheme: dark)");\n  return saved === "system" ? (system ? "dark" : "light") : saved;\n}\n```'],
  ['user', 'Nice. Run the tests and check contrast on the dark theme.'],
  ['tool', 'Bash', { command: 'npm test' }, 'Tests: 52 passed, 52 total'],
  ['tool', 'Bash', { command: 'npm run contrast' }, 'All text pairs meet WCAG AA'],
  ['tool', 'Edit', { file_path: '/home/dev/notebook/src/settings/SettingsPage.tsx', old_string: 'const theme = "light";\napplyTheme(theme);', new_string: 'const theme = useTheme();\napplyTheme(theme);' }, 'Updated SettingsPage.tsx',
    { filePath: '/home/dev/notebook/src/settings/SettingsPage.tsx', structuredPatch: [{ oldStart: 12, oldLines: 2, newStart: 12, newLines: 3, lines: ['-const theme = "light";', '+const theme = useTheme();', '+watchSystemTheme();', ' applyTheme(theme);'] }] }],
  ['assistant', 'All **52 tests** pass, including the 4 new ones.\n\nContrast check: every text and background pair in the dark theme meets WCAG AA. The muted labels were the closest at 4.8 to 1, so I left them as they are.\n\nReady for review whenever you are.']
];

const short = name => [
  ['user', `Pick up "${name}" where we left off.`],
  ['assistant', `Picking up **${name}**. I read the notes from last time and will start with the open item.`]
];

export function transcript(session) {
  const turns = session.hero ? hero : short(session.name);
  const out = [];
  let parent = null;
  turns.forEach((turn, i) => {
    const timestamp = new Date(Date.UTC(2026, 9, 17, 14, 0, i * 20)).toISOString();
    const entry = (role, content, suffix) => {
      const uuid = `${session.sid}-${suffix}-${i}`;
      const record = { type: role, uuid, parentUuid: parent, sessionId: session.sid, cwd: '/home/dev/notebook', timestamp, isSidechain: false, message: { role, id: uuid, content } };
      parent = uuid;
      return record;
    };
    if (turn[0] === 'tool') {
      const id = `${session.sid}-tool-${i}`;
      out.push(entry('assistant', [{ type: 'tool_use', id, name: turn[1], input: turn[2] }], 'tool'));
      const result = entry('user', [{ type: 'tool_result', tool_use_id: id, content: turn[3] }], 'result');
      if (turn[4]) result.toolUseResult = turn[4];
      out.push(result);
    } else out.push(entry(turn[0], [{ type: 'text', text: turn[1] }], turn[0][0]));
  });
  return out;
}

export const usage = { accounts: [
  { id: 'demo-claude', provider: 'claude', label: 'Claude', status: 'ok', guidance: { usedPercent: 41 }, quotas: [{ id: 'five_hour', windowMinutes: 300, usedPercent: 22 }], dailyGoal: { progressPercent: 64 } },
  { id: 'demo-codex', provider: 'codex', label: 'Codex', status: 'ok', guidance: { usedPercent: 58 }, quotas: [{ id: 'codex-five-hour', limitId: 'codex', windowMinutes: 300, usedPercent: 35 }], dailyGoal: { progressPercent: 100 } }
] };
