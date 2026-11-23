const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const source = require('./app-source').readAppSource();

const jsonReader = fs.readFileSync(path.join(path.resolve(__dirname, ".."), "src", "json_reader.zig"), "utf8");

function functionBody(name, nextName) {
  const start = source.indexOf(`fn ${name}(`);
  const end = source.indexOf(`fn ${nextName}(`, start + 1);
  assert.notStrictEqual(start, -1, `missing ${name}`);
  assert.notStrictEqual(end, -1, `missing boundary ${nextName}`);
  return source.slice(start, end);
}

test("blue-dot attention survives save, restart, and reconnect", () => {
  const save = functionBody("saveSessionTo", "saveSession");
  assert.match(save, /shells\[i\]\.needs_attention/);
  assert.ok(save.includes('const att = ",\\"att\\":true";'));
  assert.match(functionBody("saveSession", "preserveFailedRemoteSavedTab"), /saveSessionTo\(path, null\)/);
  assert.match(source, /needs_attention: bool = false/);

  const parse = functionBody("parseSessionTabs", "restoreBrowserStateFromSavedTab");
  assert.match(parse, /json_reader\.sessionTabs\(parsed\.value, tabs\[0\.\.\], MAX_LWS\)/);
  assert.match(jsonReader, /tab\.needs_attention = boolTrue\(obj, "att"\)/);

  const failedRestore = functionBody("preserveFailedRemoteSavedTab", "parseSessionTabs");
  assert.match(failedRestore, /shell\.needs_attention = tab\.needs_attention/);

  const restore = functionBody("spawnSavedTab", "restoreSession");
  assert.match(restore, /shells\[idx\]\.needs_attention = tabs\[t\]\.needs_attention/);
  assert.match(functionBody("restoreSession", "enumWindowsCallback"), /spawnSavedTab\(&tabs\[t\], \.continue_latest\)/);

  const respawn = functionBody("respawnShellInPlace", "faviconHostForShell");
  assert.match(respawn, /saved_needs_attention/);
  assert.match(respawn, /\.needs_attention = saved_needs_attention/);
});

test("every lifecycle transition durably saves its attention state", () => {
  const apply = functionBody("applyShellEvent", "openInbox");
  assert.match(apply, /setBlueDot\(i, \.hook_done, true\)/);
  assert.match(apply, /turn_pending/);
  assert.match(apply, /needs_attention = false/);
  assert.match(apply, /saveSession\(\)/);
  assert.match(source, /last_done_content_valid: bool = false/);
  assert.match(functionBody("writeArchiveMarkers", "hideActiveTabUntilAttention"), /done_rows/);
  assert.match(functionBody("saveSessionTo", "saveSession"), /inbox_archived or shells\[i\]\.last_done_content_valid/);
  assert.match(functionBody("exportSlotSessionFile", "closeMyWorkspaceSlot"), /inbox_archived or shells\[i\]\.last_done_content_valid/);
  assert.match(jsonReader, /tab\.last_done_content = archiveContent\(obj, "done_rows"\)/);
});

test("ACTIVE clears any prior dot and a resumed DONE respects filing content", () => {
  const apply = functionBody("applyShellEvent", "openInbox");
  const active = apply.slice(apply.indexOf("if (active) {"), apply.indexOf("} else {", apply.indexOf("if (active) {")));
  assert.match(active, /shells\[i\]\.needs_attention = false;/);
  assert.doesNotMatch(active, /last_blue_dot_source/);
  assert.match(apply, /archive_rules\.doneHasActivity\(/);
  assert.match(apply, /last_done_content_valid/);
  assert.match(apply, /completed_turn and dotTargetsTab\(i\) and \(!shells\[i\]\.inbox_archived or archiveHasNewContent\(i\)\)/);
});

test("workspace exports retain blue dots too", () => {
  const exported = functionBody("exportSlotSessionFile", "closeMyWorkspaceSlot");
  assert.match(exported, /shells\[i\]\.needs_attention/);
  assert.ok(exported.includes('const att = ",\\"att\\":true";'));
});

test("console scans cannot invent DONE for hooked tabs", () => {
  const capture = functionBody("captureShellPreview", "shellProcessAliveForRead");
  assert.match(capture, /setBlueDot\(i, \.heuristic, false\)/);
  assert.match(capture, /shells\[i\]\.hook_capable or shells\[i\]\.claude_sid_len > 0/);
  assert.doesNotMatch(capture, /DONE idle-prompt fallback/);
  assert.match(capture, /shells\[i\]\.console_working = saw_ai_working/);
  assert.match(capture, /deferred_done and !saw_ai_working/);

  const setter = functionBody("setBlueDot", "noteRestoredBlueDot");
  assert.match(setter, /attention_rules\.allow/);
  assert.match(setter, /last_blue_dot_source = source/);
  assert.match(setter, /debugLog\(msg\)/);
});

test("Alt+E watchdog only returns unhooked sessions", () => {
  const capture = functionBody("captureShellPreview", "shellProcessAliveForRead");
  assert.match(capture, /nextHiddenIdleWatchdogStreak/);
  assert.match(capture, /HIDDEN_IDLE_WATCHDOG_POLLS/);
  assert.match(capture, /if \(shells\[i\]\.hook_capable or shells\[i\]\.claude_sid_len > 0\) 0 else shells\[i\]\.ai_agent/);
  assert.match(capture, /setBlueDot\(i, \.heuristic, false\)/);
  const apply = functionBody("applyShellEvent", "openInbox");
  assert.match(apply, /const completed_turn = archive_rules\.doneHasActivity\(/);
  assert.match(apply, /shells\[i\]\.turn_pending = false/);
  assert.match(apply, /setBlueDot\(i, \.notification, false\)/);
  assert.match(apply, /explicit_prompt or \(!shells\[i\]\.hook_capable and shells\[i\]\.claude_sid_len == 0\)/);
  assert.match(functionBody("pollNotifications", "etaAgentDisplayName"), /NOTIFICATION:/);
});
