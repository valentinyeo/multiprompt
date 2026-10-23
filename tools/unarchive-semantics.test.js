const assert = require("assert");
const fs = require("fs");
const path = require("path");

const source = require('./app-source').readAppSource();
const start = source.indexOf("fn unarchiveHiddenWorkspaceSessions(");
const end = source.indexOf("\nfn commitArchivedSessionReturn", start);

assert.notStrictEqual(start, -1, "workspace Alt+E unarchive function is missing");
assert.notStrictEqual(end, -1, "could not isolate workspace Alt+E unarchive function");

const body = source.slice(start, end);
const executableBody = body.replace(/\/\/.*$/gm, "");
assert.match(body, /shells\[i\]\.workspace != workspace/, "hidden restore must stay in the selected workspace");
assert.match(body, /inbox_archived = false/, "hidden restore must clear only the Alt+E visibility flag");
assert.doesNotMatch(executableBody, /archive\.json|loadArchive|resurrect|spawnShell|tmux/i,
  "Alt+E unarchive must not touch killed sessions or launch processes");
assert.doesNotMatch(source, /fn resurrectArchivedWorkspaceSessions\(/,
  "the dangerous dissolved-session bulk resurrection helper must stay removed");

for (const label of [
  "Unarchive Hidden (Alt+E) Sessions",
  "Restore Disconnected Workspace Sessions",
  "Unarchive Killed (Alt+X) Sessions",
]) {
  assert.match(source, new RegExp(label.replace(/[()+]/g, "\\$&")), `missing Ctrl+K action: ${label}`);
}

const queueStart = source.indexOf("fn startUnarchiveUnattachedWorkspaceSessions(");
const queueEnd = source.indexOf("\nfn activateSessionOverviewRow", queueStart);
assert.notStrictEqual(queueStart, -1, "unattached sequential queue is missing");
const queueBody = source.slice(queueStart, queueEnd);
assert.match(queueBody, /row\.kind != \.vps_only/, "unattached action must only queue existing remote tmux rows");
assert.match(queueBody, /row\.workspace != workspace/, "unattached action must stay in the selected workspace");
assert.match(queueBody, /TIMER_UNARCHIVE_UNATTACHED/, "unattached sessions must be paced by a timer");
assert.strictEqual((queueBody.match(/spawnShellWithSession\(/g) || []).length, 1,
  "the timer step must contain exactly one attach call, never a bulk spawn loop");

assert.match(source, /g_all_sessions_killed_only and row\.kind != \.archived/,
  "killed action must filter out live hidden and unattached rows");
assert.match(source, /if \(target == SEARCH_ARCHIVED_VIEW_OFFSET\)[\s\S]*?openAllSessions\(hwnd\)/,
  "killed action must open an individual selection view");

console.log("PASS: hidden, unattached, and killed unarchive semantics stay isolated");
