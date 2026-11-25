const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");
const assert = require("node:assert/strict");

const source = require('./app-source').readAppSource();
const tmuxList = fs.readFileSync(path.join(__dirname, "tmux-list.sh"), "utf8");

function functionBody(name, nextName) {
  const start = source.indexOf(`fn ${name}(`);
  const end = source.indexOf(`fn ${nextName}(`, start);
  assert.notEqual(start, -1, `${name} must exist`);
  assert.notEqual(end, -1, `${nextName} must follow ${name}`);
  return source.slice(start, end);
}

test("Kimi has a stable persisted agent identity and diagnostic label", () => {
  assert.match(source, /const AgentName = enum \{[^}]*kimi[^}]*\}/);
  assert.match(functionBody("agentLabel", "agentId"), /\.kimi => "Kimi"/);
  assert.match(functionBody("agentId", "agentFromId"), /\.kimi => 4/);
  assert.match(functionBody("agentFromId", "setDetectedShellAgent"), /4 => \.kimi/);
  assert.match(functionBody("aiAgentLabelValue", "diagAppend"), /4 => "kimi"/);
});

test("Kimi is recognized from local processes, titles, and its TUI", () => {
  const shellDetection = functionBody("detectAgentForShell", "hostLabelForShell");
  assert.match(shellDetection, /"kimi\.exe", "kimi\.cmd"/);
  assert.match(shellDetection, /return \.kimi/);

  const textDetection = functionBody("detectAgentFromText", "detectAgentForShell");
  assert.match(textDetection, /"kimi code cli"[\s\S]*return \.kimi/);

  const previewDetection = functionBody("captureShellPreview", "pollShellNames");
  assert.match(previewDetection, /"kimi code cli"/i);
  assert.match(previewDetection, /saw_kimi_agent/);
  assert.match(previewDetection, /saw_kimi_agent\) 4/);
});

test("Kimi is recognized from remote tmux and AGENT notifications", () => {
  const tmuxDetection = functionBody("tmuxAgentFromPaneCommand", "fetchHostIntoCache");
  assert.match(tmuxDetection, /"kimi-code"/);
  assert.match(tmuxDetection, /return 4/);
  assert.match(source, /entry\.agent = tmuxAgentFromPaneCommand\(f\)/);
  assert.match(source, /eql\(u8, kind_part, "kimi"\)\) 4/);
});

test("Kimi gets its own native K-and-blue-dot icon", () => {
  const draw = functionBody("drawAgentIcon", "threadTitleBandRightFor");
  assert.match(draw, /agent == 4/);
  assert.match(draw, /kimi_blue/);
  assert.match(draw, /drawNativeLine[\s\S]*Ellipse/);
});

test("Hax has a stable identity across tmux, text, diagnostics, and capacity admission", () => {
  assert.match(source, /const AgentName = enum \{[^}]*hax[^}]*\}/);
  assert.match(functionBody("agentLabel", "agentId"), /\.hax => "Hax"/);
  assert.match(functionBody("agentId", "agentFromId"), /\.hax => 5/);
  assert.match(functionBody("agentFromId", "setDetectedShellAgent"), /5 => \.hax/);
  assert.match(functionBody("aiAgentLabelValue", "diagAppend"), /5 => "hax"/);

  const textDetection = functionBody("detectAgentFromText", "detectAgentForShell");
  assert.match(textDetection, /"hax"[\s\S]*return \.hax/);

  const tmuxDetection = functionBody("tmuxAgentFromPaneCommand", "fetchHostIntoCache");
  assert.match(tmuxDetection, /"hax"[\s\S]*return 5/);
  assert.match(tmuxList, /#\{pane_current_command\}/);

  assert.match(source, /fn commandCreatesAgentWorkload\([^}]*"hax"/);
});

test("Hax uses the official terminal-chevron and cursor colors", () => {
  const draw = functionBody("drawAgentIcon", "threadTitleBandRightFor");
  assert.match(draw, /agent == 5/);
  assert.match(draw, /RGB\(215, 135, 95\)/);
  assert.match(draw, /RGB\(0, 175, 175\)/);
  assert.match(draw, /drawNativeLine[\s\S]*drawNativeLine[\s\S]*FillRect/);
});

test("Grok has a stable identity across tmux, text, diagnostics, and capacity admission", () => {
  assert.match(source, /const AgentName = enum \{[^}]*grok[^}]*\}/);
  assert.match(functionBody("agentLabel", "agentId"), /\.grok => "Grok"/);
  assert.match(functionBody("agentId", "agentFromId"), /\.grok => 6/);
  assert.match(functionBody("agentFromId", "setDetectedShellAgent"), /6 => \.grok/);
  assert.match(functionBody("aiAgentLabelValue", "diagAppend"), /6 => "grok"/);

  const textDetection = functionBody("detectAgentFromText", "detectAgentForShell");
  assert.match(textDetection, /"grok"[\s\S]*return \.grok/);
  const shellDetection = functionBody("detectAgentForShell", "hostLabelForShell");
  assert.match(shellDetection, /"grok\.exe", "grok\.cmd"/);

  const tmuxDetection = functionBody("tmuxAgentFromPaneCommand", "fetchHostIntoCache");
  assert.match(tmuxDetection, /"grok"[\s\S]*return 6/);
  assert.match(tmuxList, /#\{pane_current_command\}/);
  assert.match(source, /eql\(u8, kind_part, "grok"\)\) 6/);
  assert.match(source, /fn commandCreatesAgentWorkload\([^}]*"grok"/);

  const previewDetection = functionBody("captureShellPreview", "pollShellNames");
  assert.match(previewDetection, /"grok coding allowance"/i);
  assert.match(previewDetection, /saw_grok_agent\) 6/);
});

test("Grok gets a distinct native G and orbital-slash icon", () => {
  const draw = functionBody("drawAgentIcon", "threadTitleBandRightFor");
  assert.match(draw, /agent == 6/);
  assert.match(draw, /grok_blue/);
  assert.match(draw, /L\("G"\)/);
  assert.match(draw, /drawNativeLine/);
});

test("Cursor has a stable identity and overrides stale Claude metadata", () => {
  assert.match(source, /const AgentName = enum \{[^}]*cursor[^}]*\}/);
  assert.match(functionBody("agentLabel", "agentId"), /\.cursor => "Cursor"/);
  assert.match(functionBody("agentId", "agentFromId"), /\.cursor => 7/);
  assert.match(functionBody("agentFromId", "setDetectedShellAgent"), /7 => \.cursor/);
  assert.match(functionBody("aiAgentLabelValue", "diagAppend"), /7 => "cursor"/);

  const shellDetection = functionBody("detectAgentForShell", "hostLabelForShell");
  assert.match(shellDetection, /"cursor-agent\.exe"/);
  assert.match(shellDetection, /text_agent == \.cursor\) return \.cursor/,
    "a live Cursor title must replace historical Claude identity");
});

test("Cursor is recognized from titles, tmux process evidence, and notifications", () => {
  const textDetection = functionBody("detectAgentFromText", "detectAgentForShell");
  assert.match(textDetection, /"cursor"[\s\S]*return \.cursor/);

  const tmuxDetection = functionBody("tmuxAgentFromPaneCommand", "fetchHostIntoCache");
  assert.match(tmuxDetection, /"cursor-agent"[\s\S]*return 7/);
  assert.match(tmuxList, /cursor-agent\\\/versions/,
    "tmux inventory must inspect Cursor's real child command path");
  assert.match(tmuxList, /AGENT\["\$s"\]/);
  assert.match(source, /eql\(u8, kind_part, "cursor"\)\) 7/);
});

test("Cursor gets a native nested-diamond sidebar icon", () => {
  const draw = functionBody("drawAgentIcon", "threadTitleBandRightFor");
  assert.match(draw, /agent == 7/);
  assert.match(draw, /cursor_ink/);
  assert.match(draw, /cursor_core/);
  assert.match(draw, /drawNativeLine[\s\S]*drawNativeLine/);
});

test("Antigravity has a stable identity across tmux, text, diagnostics, and capacity admission", () => {
  assert.match(source, /const AgentName = enum \{[^}]*antigravity[^}]*\}/);
  assert.match(functionBody("agentLabel", "agentId"), /\.antigravity => "Antigravity"/);
  assert.match(functionBody("agentId", "agentFromId"), /\.antigravity => 8/);
  assert.match(functionBody("agentFromId", "setDetectedShellAgent"), /8 => \.antigravity/);
  assert.match(functionBody("aiAgentLabelValue", "diagAppend"), /8 => "antigravity"/);

  const textDetection = functionBody("detectAgentFromText", "detectAgentForShell");
  assert.match(textDetection, /"antigravity"[\s\S]*return \.antigravity/);
  assert.match(textDetection, /"agy"[\s\S]*return \.antigravity/);
  const shellDetection = functionBody("detectAgentForShell", "hostLabelForShell");
  assert.match(shellDetection, /"agy\.exe", "agy\.cmd"/);

  const tmuxDetection = functionBody("tmuxAgentFromPaneCommand", "fetchHostIntoCache");
  assert.match(tmuxDetection, /"agy"[\s\S]*return 8/);
  assert.match(source, /fn commandCreatesAgentWorkload\([^}]*"antigravity"/);
  assert.match(source, /eql\(u8, kind_part, "antigravity"\)\) 8/);
  assert.match(functionBody("shellLooksLikeCodingAgent", "syncShellDisplayNameSurfaces"), /"antigravity"/);
  assert.match(source, /ai_agent == 7 or .*ai_agent == 8/);
});

test('a bound Antigravity chat ignores stale console provider text', () => {
  const preview = functionBody('captureShellPreview', 'pollShellNames');
  const condition = preview.match(/if \((detect_agent != 0[^\n]+)\) \{/)?.[1];
  assert.ok(condition, 'console provider adoption condition is missing');
  const replaceAgent = new Function('detect_agent', 'kept_agent', 'sid_len', `return ${condition
    .replaceAll('shells[i].claude_sid_len', 'sid_len')
    .replaceAll(' and ', ' && ').replaceAll(' or ', ' || ')};`);
  for (const detected of [1, 2, 4, 6]) {
    for (const bound of [1, 2, 3, 8]) assert.equal(replaceAgent(detected, bound, 36), false);
    assert.equal(replaceAgent(detected, 8, 0), true);
  }
});
