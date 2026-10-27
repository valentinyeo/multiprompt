import { execFileSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import { pathToFileURL } from 'node:url';

export const journeys = [
  'appearance', 'sessions', 'session-restore', 'tmux-binding', 'workspaces', 'workspace-focus', 'inbox',
  'command-palette', 'session-open', 'favorites-groups', 'chat-first-paint', 'chat-send-latency',
  'browser-switch-speed', 'chat-switch-speed', 'browser-pane-stuck', 'browser-pane-locked', 'browser-corners',
  'group-rail', 'pane-layout', 'title-bar', 'window-controls', 'chat-tables', 'chat-code-font', 'chat-working',
  'chat-composer-text', 'chat-skill-pill', 'chat-options', 'composer-buttons', 'chat-dictation', 'safe-updates',
  'chat-view', 'chat-view-everywhere', 'chat-focus', 'chat-delivery', 'chat-messages-only', 'chat-full-history',
  'browser-emulation', 'status-card', 'palette-order', 'browser-own-profile', 'remind-me', 'tab-names',
  'session-tabs', 'relaunch-saved-sessions',
];

const rules = [
  ['appearance', /^(?:src\/themes\.zig|src\/launch_plan\.zig|src\/startup\.zig|tools\/start-maximized\.test\.js)$/],
  ['chat-dictation', /^(?:src\/dictation_audio\.zig|src\/voice\.zig|src\/voice_duplex\.zig|src\/voice_filter\.zig|tools\/chat-dictation\.test\.js)$|^tools\/fixtures\/IGSH-812\//],
  ['session-restore', /^(?:src\/session\.zig|src\/launch_snapshot\.zig|src\/launch_cache\.zig)$/],
  ['workspace-focus', /^(?:src\/focus\.zig|tools\/check-workspace-focus\.mjs)$/],
  ['favorites-groups', /^tools\/favorites-groups\.test\.js$/],
  ['browser-pane-stuck', /^(?:tools\/check-browser-pane-stuck\.mjs|tools\/frozen-wake\.test\.js)$/],
  ['browser-pane-locked', /^tools\/check-browser-pane-locked\.test\.js$/],
  ['pane-layout', /^(?:src\/window_layout\.zig|tools\/pane-spacing\.test\.js)$/],
  ['chat-view', /^(?:src\/chat_view\.zig|tools\/chat-local-agent\.c)$/],
  ['chat-messages-only', /^tools\/chat-messages-only-proof\./],
  ['chat-view-everywhere', /^tools\/chat-view-everywhere.*\.test\.js$/],
  ['chat-focus', /^(?:src\/chat_find\.zig|src\/chat_find_ui\.zig|tools\/chat-focus\.test\.js)$/],
  ['browser-own-profile', /^(?:src\/browser_own_profile\.zig|tools\/browser-own-profile\.test\.js|tools\/screenshot-upload-receiver.*)$/],
  ['status-card', /^src\/status_line\.zig$/],
  ['palette-order', /^src\/command_palette\.zig$/],
  ['remind-me', /^src\/reminders(?:_load)?\.zig$/],
  ['chat-code-font', /^(?:src\/chat_code\.zig|tools\/chat-code-font-proof\.)/],
  ['chat-composer-text', /^(?:src\/chat_composer_text(?:_proof)?\.zig|tools\/chat-composer-text-proof\.)/],
  ['chat-send-latency', /^src\/send_latency\.zig$/],
  ['chat-tables', /^src\/chat_table_measure\.zig$/],
  ['title-bar', /^\.claude\/skills\/verify-multiprompt\/title-bar\.ps1$/],
  ['tmux-binding', /^(?:src\/tmux_identity\.zig|\.claude\/skills\/verify-multiprompt\/tmux-binding\.ps1)$/],
  ['chat-working', /^(?:src\/chat_working\.zig|\.claude\/skills\/verify-multiprompt\/chat-working\.ps1)$/],
  ['chat-skill-pill', /^(?:src\/chat_skill\.zig|\.claude\/skills\/verify-multiprompt\/chat-skill-pill\.ps1)$/],
  ['chat-options', /^(?:src\/chat_options\.zig|\.claude\/skills\/verify-multiprompt\/chat-options\.ps1)$/],
  ['composer-buttons', /^src\/chat_composer\.zig$/],
  ['relaunch-saved-sessions', /^src\/notify_ports\.zig$/],
  ['inbox', /^src\/inbox\.zig$/],
  ['workspaces', /^src\/workspaces\.zig$/],
];

const elsewhere = new Set(['browser-switch-speed', 'chat-switch-speed', 'chat-delivery', 'chat-full-history', 'window-controls', 'browser-corners']);

export function featuresForPaths(paths) {
  const selected = [];
  const add = name => {
    if (journeys.includes(name) && !elsewhere.has(name) && !selected.includes(name)) selected.push(name);
  };
  for (const file of paths) {
    const doc = file.match(/^\.claude\/skills\/verify-multiprompt\/features\/([a-z0-9-]+)\.md$/);
    if (doc) add(doc[1]);
    for (const [feature, pattern] of rules) {
      if (pattern.test(file)) add(feature);
    }
  }
  return selected;
}

export function selection(paths) {
  const features = featuresForPaths(paths);
  return { features, appearance: features.includes('appearance') };
}

export function journeyPlan(features, { prior = 0, merge = false } = {}) {
  const relevant = features.slice();
  const started = Math.min(Math.max(0, prior), 2, relevant.length);
  if (merge) {
    const budget = Math.max(0, prior - started);
    return relevant.slice(started, started + budget);
  }
  if (prior >= 2 || prior >= relevant.length) return [];
  return [relevant[prior]];
}

export function countPrior(runs, openedAt) {
  const opened = Date.parse(openedAt);
  if (Number.isNaN(opened)) return 2;
  return runs.filter(run => run.conclusion !== 'skipped' && Date.parse(run.createdAt) >= opened).length;
}

function priorCount() {
  if (process.env.PRIOR != null && process.env.PRIOR !== '') return Number(process.env.PRIOR);
  if (!process.env.GITHUB_TOKEN && !process.env.GH_TOKEN) return 2;
  try {
    const env = { ...process.env, GH_TOKEN: process.env.GH_TOKEN || process.env.GITHUB_TOKEN };
    const runs = JSON.parse(execFileSync('gh', ['run', 'list', '-R', process.env.GITHUB_REPOSITORY, '-w', 'verify.yml', '-b', process.env.BRANCH, '--event', 'pull_request', '--json', 'databaseId,conclusion,createdAt', '-L', '100'], { encoding: 'utf8', env }));
    const opened = execFileSync('gh', ['pr', 'view', String(process.env.PR), '-R', process.env.GITHUB_REPOSITORY, '--json', 'createdAt', '-q', '.createdAt'], { encoding: 'utf8', env }).trim();
    return countPrior(runs, opened);
  } catch {
    return 2;
  }
}

function changedPaths() {
  let base = process.env.BASE;
  const head = process.env.HEAD;
  if (process.env.EVENT === 'pull_request') base = execFileSync('git', ['merge-base', base, head], { encoding: 'utf8' }).trim();
  return execFileSync('git', ['diff', '--name-only', '-z', base, head]).toString('utf8').split('\0').filter(Boolean);
}

function main() {
  const chosen = journeyPlan(featuresForPaths(changedPaths()), { prior: priorCount(), merge: process.env.MERGE === 'true' });
  const body = `features=${JSON.stringify(chosen)}\nappearance=${chosen.includes('appearance')}\n`;
  if (process.env.GITHUB_OUTPUT) fs.appendFileSync(process.env.GITHUB_OUTPUT, body);
  else process.stdout.write(body);
}

if (process.argv[1] && import.meta.url === pathToFileURL(path.resolve(process.argv[1])).href) main();
