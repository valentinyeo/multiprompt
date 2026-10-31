const assert = require("node:assert/strict");
const childProcess = require("node:child_process");
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");

const source = require('./app-source').readAppSource();
const accountReconnect = fs.readFileSync(
  path.join(__dirname, "usage-telemetry", "reconnect-accounts.ps1"),
  "utf8",
);

function functionBody(name, nextName) {
  const start = source.indexOf(`fn ${name}(`);
  const end = source.indexOf(`\nfn ${nextName}(`, start);
  assert.notStrictEqual(start, -1, `${name} is missing`);
  assert.notStrictEqual(end, -1, `could not isolate ${name}`);
  return source.slice(start, end);
}

test("Alt+T starts only the configured program in a fresh workspace tmux session", () => {
  const spawn = functionBody("spawnWorkspaceTmuxSession", "activeRemoteContextForCodexTmux");
  assert.match(spawn, /workspaceConfiguredTerminalFolder\(workspace, &host, &cwd_buf, &cwd_len, &program_buf, &program_len\)/);
  assert.match(spawn, /workspacePrimaryRepo\(&host, &cwd_buf, &cwd_len\)/,
    "live workspace inference must remain the neutral fallback");
  assert.match(spawn, /const launch_cmd = workspaceLaunchCommand\(program, session, cwd, host_sid, &host_buf, &cmd_buf\) orelse return false;/);
  const chooser = functionBody("workspaceLaunchCommand", "spawnWorkspaceTmuxSession");
  assert.match(chooser, /return buildWorkspaceTmuxLaunchCmd\(command_out, session, cwd, program\);/,
    "a program that is not a Claude workload must still start through the typed tmux command");
  assert.match(spawn, /spawnShellWithSession\(\.tmux, session, null, null\)/);
  assert.match(spawn, /ai_agent = if \(claude\) 1 else 0/);
  assert.match(spawn, /program\.len > 0 and commandCreatesAgentWorkload\(program\)/);

  const build = functionBody("buildWorkspaceTmuxLaunchCmd", "buildWorkspaceTmuxSessionName");
  assert.match(build, /"tmux new-session -d -s "/);
  assert.match(build, /" -c "/);
  assert.match(build, /" 2>\/dev\/null; tmux send-keys -t "/);
  assert.match(build, /" 'cd "/);
  assert.match(build, /" && "/);
  assert.match(build, /" 2>\/dev\/null; tmux attach -t "/);

  const handlerStart = source.indexOf("WM_APP_NEW_TAB_DEFAULT => {");
  const handlerEnd = source.indexOf("\n        WM_APP_UI_BIGGER => {", handlerStart);
  assert.notStrictEqual(handlerStart, -1);
  assert.notStrictEqual(handlerEnd, -1);
  const handler = source.slice(handlerStart, handlerEnd);
  assert.match(handler, /spawnWorkspaceTmuxSession\(\)/);
  assert.doesNotMatch(handler, /spawnCustomCmd|workspaceScopedDefaultCustomCommand|globalDefaultCustomCommand/,
    "legacy command defaults must not launch cmd for Alt+T");

  const folder = functionBody("workspaceConfiguredTerminalFolder", "customCmdMatchesQuery");
  assert.match(folder, /c\.is_default/);
  assert.match(folder, /c\.cwd/);
  assert.match(folder, /c\.alt_t/);
  assert.doesNotMatch(folder, /startup_cmd|spawnCustomCmd|tnn|Claude/);
});

test("Alt+T and shell Ctrl+T open workspace tabs while browser Ctrl+T passes through", () => {
  const hook = functionBody("keyboardHookProc", "pointOverActiveShell");
  assert.match(hook,
    /!isCtrlDown\(\) and kb\.vkCode == 0x54 and foregroundIsOurs\(\)[\s\S]*?WM_APP_NEW_TAB_DEFAULT/,
    "one AltGr-safe universal Alt+T handler must route to the workspace new-session action");

  const allSessionsStart = hook.indexOf("if (g_all_sessions_active and !g_search_active) {");
  const inboxStart = hook.indexOf("if (g_inbox_active and !g_search_active", allSessionsStart);
  const browserStart = hook.indexOf("\n        if (g_browser_focus_mode and activeBrowserSurfaceHasForegroundFocus())");
  assert.notStrictEqual(allSessionsStart, -1);
  assert.notStrictEqual(inboxStart, -1);
  assert.notStrictEqual(browserStart, -1);

  const allSessions = hook.slice(allSessionsStart, hook.indexOf("if (g_inbox_active and !g_search_active", allSessionsStart));
  const inbox = hook.slice(inboxStart, hook.indexOf("\n            if (g_search_active)", inboxStart));
  const browser = hook.slice(browserStart, hook.indexOf("\n        if ((wp == WM_KEYDOWN or wp == WM_SYSKEYDOWN) and !g_win_held and kb.vkCode == 0x25", browserStart));
  for (const [name, body] of [["All Sessions", allSessions], ["Inbox", inbox], ["browser focus", browser]]) {
    assert.doesNotMatch(body, /kb\.vkCode == 0x54[\s\S]{0,400}?WM_APP_NEW_TAB_DEFAULT/,
      `${name} must not intercept Ctrl+T as a shell action`);
  }

  const isolationStart = hook.indexOf("if (ctrl and (kb.flags & 0x20) == 0 and kb.vkCode != 0x09");
  const isolationEnd = hook.indexOf("if (ctrl and kb.vkCode == 0x56) {", isolationStart);
  const isolation = hook.slice(isolationStart, isolationEnd);
  assert.match(isolation, /activeBrowserHasForegroundFocus\(\)\) \{\s+return CallNextHookEx/,
    "browser-owned Ctrl shortcuts must pass to the native browser");
  assert.doesNotMatch(isolation, /kb\.vkCode == 0x54/,
    "Ctrl+T must not be exempted from browser passthrough");
  assert.match(hook, /kb\.vkCode == 0x54[\s\S]*?activeBrowserHasForegroundFocus\(\)[\s\S]*?WM_APP_NEW_TAB_DEFAULT/,
    "Ctrl+T outside browser focus uses the workspace default");
  assert.match(hook, /kb\.vkCode == 0x54[\s\S]*?WM_APP_REOPEN_CLOSED/,
    "Ctrl+Shift+T must keep reopening the last closed multiprompt tab");
});

test("Ctrl+K ranks intent, workspace context, and decaying usage stably", () => {
  const key = functionBody("paletteUsageKey", "loadPaletteUsage");
  for (const field of ["label", "workspace", "startup_cmd", "cwd"]) {
    assert.match(key, new RegExp(`c\\.${field}`),
      `custom command usage identity must include ${field}`);
  }
  assert.match(key, /@intFromEnum\(c\.kind\)/,
    "reordering commands.json must not transfer usage to a different command");

  const primary = functionBody("palettePrimaryLabel", "asciiStartsWithCI");
  for (const dynamicSource of ["g_tmux_cache", "g_archived", "g_reminders", "g_session_overview_rows"]) {
    assert.match(primary, new RegExp(dynamicSource),
      `typed dynamic-session matches must rank from ${dynamicSource}`);
  }
  const queryRank = functionBody("paletteQueryRank", "paletteWorkspaceRank");
  assert.match(queryRank, /target < shell_count[\s\S]*?paletteWideTextMatchRank/,
    "an exact live-tab search must outrank unrelated learned commands");

  const outranks = functionBody("paletteResultOutranks", "sortSearchResultsByRank");
  const matchPos = outranks.indexOf("paletteQueryRank(key)");
  const workspacePos = outranks.indexOf("paletteWorkspaceRank(key)");
  const frecencyPos = outranks.indexOf("paletteFrecencyAt(key_usage, now)");
  assert.ok(matchPos >= 0 && matchPos < workspacePos && workspacePos < frecencyPos,
    "typed match quality must outrank workspace context, which must outrank usage");
  assert.match(outranks, /else \{[\s\S]*?paletteTargetIsDestructive/,
    "an empty palette must keep destructive actions below ordinary commands");
  assert.doesNotMatch(outranks, /key_usage\.count > prev_usage\.count/,
    "raw lifetime counts must never directly determine palette order");

  const frecency = functionBody("paletteFrecencyAt", "paletteResultOutranks");
  assert.match(frecency, /age < 24 \* ticks_per_hour/);
  assert.match(frecency, /age < 7 \* 24 \* ticks_per_hour/);
  assert.match(frecency, /frequency < 15/,
    "frequency must be capped below the gap between recency bands");

  const sort = functionBody("sortSearchResultsByRank", "asciiEqualsCI");
  assert.match(sort, /paletteResultOutranks\(key, prev, now\)/);
  assert.match(sort, /if \(!paletteResultOutranks/,
    "equal/unseen commands must preserve their curated fallback order");

  const update = functionBody("updateSearchResults", "u16ToLower");
  assert.match(update, /sortSearchResultsByRank\(\);[\s\S]*?keepSearchSelectionVisible\(\)/,
    "the completed top-level result list must be ranked before selection is clamped");
  assert.match(source, /const target = g_search_results\[g_search_sel\];\s+if \(paletteRowIsHeader\(target\)\) return 0;\s+recordPaletteUsage\(target\);/,
    "confirming a palette action must persist its use, and a group header row is never confirmed");
  assert.match(source, /loadPaletteUsage\(\);[\s\S]*?loadSnippetsIfChanged\(\);[\s\S]*?updateSearchResults\(\);/,
    "each palette open must see usage recorded by other workspace windows");
});

test("empty Ctrl+K promotes the session just left for one-Enter toggling", () => {
  const switching = functionBody("switchToShell", "nthVisibleShell");
  assert.match(switching,
    /idx != prev[\s\S]*?g_previous_shell_sid = shells\[prev\]\.shell_id/,
    "a real session switch must remember the stable id of the session just left");

  const update = functionBody("updateSearchResults", "u16ToLower");
  const rankPos = update.indexOf("sortSearchResultsByRank();");
  const resolvePos = update.indexOf("findShellById(g_previous_shell_sid)");
  const promotePos = update.indexOf("promoteSearchTargetToFront", resolvePos);
  assert.ok(rankPos >= 0 && rankPos < resolvePos && resolvePos < promotePos,
    "the previous live session must be resolved by id and promoted after normal ranking");
  assert.match(update, /g_search_len == 0\) \{[\s\S]*?pickRecentSessions[\s\S]*?promoteSearchTargetToFront/,
    "typed searches must keep intent-first ranking instead of forcing history to row zero");
});

test("all session rename entry points synchronize display surfaces without changing stable ids", () => {
  const rename = functionBody("startRenameInternal", "startGroupRename");
  assert.match(rename, /g_edit_sync_remote_name = true/,
    "F2, double-click, and title-band renames must use the canonical synchronized path");

  const inboxRename = functionBody("startInboxRename", "inboxRelTime");
  assert.match(inboxRename, /g_edit_is_inbox = true;[\s\S]*?g_edit_sync_remote_name = true/,
    "Inbox F2 must synchronize the same logical session name");

  const commit = functionBody("commitRename", "openTabContextPalette");
  assert.match(commit, /applyCanonicalSessionRename\(g_edit_tab, buf\[0\.\.ulen\], sync_remote\)/);
  assert.doesNotMatch(commit, /tmux_session_len\s*=\s*0/,
    "clearing a display name must not destroy the stable tmux binding");

  const canonical = functionBody("applyCanonicalSessionRename", "shellNameFromU16AsciiTrimmed");
  assert.match(canonical, /syncShellDisplayNameSurfaces\(idx, sync_name, true\)/);
  assert.doesNotMatch(canonical, /tmux_session_len\s*=/,
    "the canonical rename path may update display surfaces but not stable bindings");

  const modal = functionBody("beginPaletteRenameInput", "startThreadTitleRename");
  assert.match(modal, /g_search_rename_sid = shells\[idx\]\.shell_id/,
    "the modal target must survive index movement by keeping the stable shell id");
  assert.match(modal, /g_search_rename_select_all = true/,
    "the proposed/current name must be preselected for immediate replacement");
  assert.match(modal, /g_search_buf\[0\.\.g_search_len\].*shells\[idx\]\.name/s,
    "the rename modal must be prefilled with the proposed current session name");

  assert.match(source, /WM_APP_SEARCH_SELECT_ALL/);
  assert.match(source, /Ctrl\+A selects all/);
  assert.match(source, /findShellById\(g_search_rename_sid\)[\s\S]*?applyCanonicalSessionRename\(idx, g_search_buf\[start\.\.end\], true\)/,
    "modal confirmation must resolve the stable target and use the canonical synchronized commit");
  assert.match(source, /target == SEARCH_RENAME_SYNC_OFFSET[\s\S]*?beginPaletteRenameInput\(active_shell\)/,
    "Ctrl+K Rename Session must enter the app modal rather than the inline F2 editor");
  assert.match(source, /L\("Rename Session"\)/);
  assert.match(source, /L\("Use Agent or Terminal Session Name"\)/);

  assert.match(canonical, /blockExternalNameSyncUntilTitleChanges/,
    "an outbound rename must block the old agent title from taking the tab name back");
  assert.match(source, /localAgentTerminalDisplayName\(title\)/,
    "local coding-agent titles must participate in reverse name synchronization");
  assert.match(source, /codexDisplayNameIsAutomaticProjectTitle/,
    "Codex project-name terminal titles must not impersonate thread renames");

  const codexLaunch = functionBody("buildCodexTmuxLaunchCmd", "buildCodexTmuxSessionName");
  assert.match(codexLaunch, /tui\.terminal_title=\[\\\\\\"thread-title\\\\\\"\]/,
    "multiprompt-launched Codex sessions must expose the durable thread name in their terminal title");
});

test("Ctrl+K spawn actions use normalized names without decorative plus prefixes", () => {
  const paintStart = source.indexOf("if (g_search_active) {", source.indexOf("fn paintSidebar("));
  const paintEnd = source.indexOf("\nfn updateSearchResults(", paintStart);
  const paint = source.slice(paintStart, paintEnd);
  assert.doesNotMatch(paint, /L\("\+ /, "palette action names must not start with '+'");
  for (const label of [
    "New CMD Shell",
    "Attach Host 1 tmux Session",
    "Attach Host 2 tmux Session",
    "New Host 1 VPS Shell",
    "New Host 2 VPS Shell",
    "New PowerShell",
    "New Bash Shell",
    "New Git Bash Shell",
    "New Codex Session in This Folder",
  ]) {
    assert.match(paint, new RegExp(label), `missing normalized palette label: ${label}`);
  }
});

test("Ctrl+K opens every unopened tmux session from one selected VPS", () => {
  const update = functionBody("updateSearchResults", "u16ToLower");
  assert.match(update, /if \(g_search_openall_host_mode\)/);
  for (const id of [
    "SEARCH_OPENALL_HOST_BACK_OFFSET",
    "SEARCH_OPENALL_HOST_DE_OFFSET",
    "SEARCH_OPENALL_HOST_UK_OFFSET",
    "SEARCH_OPENALL_HOST_INNE_OFFSET",
  ]) {
    assert.match(update, new RegExp(id), `missing host picker row: ${id}`);
  }

  const dispatchStart = source.indexOf("if (target == SEARCH_OPENALL_OFFSET)");
  const dispatchEnd = source.indexOf("\n                if (target == SEARCH_THEME_BACK_OFFSET)", dispatchStart);
  assert.notStrictEqual(dispatchStart, -1);
  assert.notStrictEqual(dispatchEnd, -1);
  const dispatch = source.slice(dispatchStart, dispatchEnd);
  assert.match(dispatch, /g_search_openall_host_mode = true/,
    "the root action must enter the VPS picker instead of opening every host");
  assert.match(dispatch, /SEARCH_OPENALL_HOST_INNE_OFFSET => 2/);
  assert.match(dispatch, /if \(host_mode and e\.host != selected_host\) continue/,
    "bulk attach must stay on the chosen host");
  assert.match(dispatch, /spawnShellWithSession\(\.tmux, sn, null, null\)/);
});

test("Ctrl+K reconnects each Claude telemetry profile separately", () => {
  assert.match(source, /const SEARCH_USAGE_LOGIN_PRIMARY_OFFSET: usize = 6298;/);
  assert.match(source, /const SEARCH_USAGE_LOGIN_INNE_OFFSET: usize = 6299;/);
  assert.match(source,
    /SEARCH_USAGE_LOGIN_PRIMARY_OFFSET => "usage: sign in to primary claude account"/);
  assert.match(source,
    /SEARCH_USAGE_LOGIN_INNE_OFFSET => "usage: sign in to secondary claude account"/);

  const update = functionBody("updateSearchResults", "u16ToLower");
  for (const alias of [
    "reconnect ai usage accounts",
    "login ai usage",
    "fix stale telemetry",
    "claude telemetry login",
    "usage account login",
  ]) {
    assert.match(update, new RegExp(`"${alias}"`), `missing reconnect alias: ${alias}`);
  }
  assert.match(update,
    /g_search_results\[g_search_result_count\] = SEARCH_USAGE_LOGIN_PRIMARY_OFFSET;/);
  assert.match(update,
    /g_search_results\[g_search_result_count\] = SEARCH_USAGE_LOGIN_INNE_OFFSET;/);
  assert.match(update, /"owner@example.com"/);
  assert.match(update, /"secondary@example.com"/);

  const paintStart = source.indexOf("if (g_search_active) {", source.indexOf("fn paintSidebar("));
  const paintEnd = source.indexOf("\nfn updateSearchResults(", paintStart);
  const paint = source.slice(paintStart, paintEnd);
  assert.match(paint, /const is_usage_login = is_usage_login_primary or is_usage_login_inne;/);
  assert.match(paint,
    /else if \(is_usage_login\)[\s\S]*?L\("Usage: Sign In to Primary Claude Account"\)[\s\S]*?L\("Usage: Sign In to Secondary Claude Account"\)[\s\S]*?L\("secondary@example.com"\)/);
  for (const classifier of ["const is_newwin =", "const is_openall =", "const is_new_shell ="]) {
    const start = paint.indexOf(classifier);
    const end = paint.indexOf(";", start);
    assert.match(paint.slice(start, end), /!is_usage_login/,
      `${classifier} must not claim the reconnect action's numeric offset`);
  }

  const launcher = functionBody("showUsageAccountLogin", "ensureUsageTelemetryCollector");
  assert.match(launcher, /tools\\\\usage-telemetry\\\\reconnect-accounts\.ps1/);
  assert.match(launcher, /-AccountId claude-primary -ForceLogin/);
  assert.match(launcher, /-AccountId claude-secondary -ForceLogin/);
  assert.match(launcher, /L\("wt\.exe"\)/,
    "the OAuth wizard should prefer a terminal with a working paste shortcut");
  assert.match(launcher, /L\("-w new pwsh\.exe "\)/);
  assert.match(launcher, /if \(terminal != null[\s\S]*?return true;/,
    "a successful Windows Terminal launch must not open a second wizard");
  assert.match(launcher, /fallback = ShellExecuteW\(null, L\("open"\), L\("pwsh\.exe"\)/,
    "machines without Windows Terminal still need a visible PowerShell fallback");

  const dispatchStart = source.indexOf("if (target == SEARCH_USAGE_LOGIN_PRIMARY_OFFSET or target == SEARCH_USAGE_LOGIN_INNE_OFFSET)");
  assert.notStrictEqual(dispatchStart, -1);
  const dispatch = source.slice(dispatchStart, source.indexOf("\n                if (target ==", dispatchStart + 10));
  assert.match(dispatch, /showUsageAccountLogin\(account\)/);
  assert.match(dispatch, /AI usage account login is not installed/);

  assert.match(accountReconnect,
    /Where-Object \{ \$_\.provider -eq 'claude' \}/,
    "provider-specific login flows must not be mixed");
  assert.match(accountReconnect, /\[ValidateSet\('', 'claude-primary', 'claude-secondary'\)\]/);
  assert.match(accountReconnect, /Where-Object Id -eq \$AccountId/,
    "a targeted action must select exactly one configured profile");
  assert.match(accountReconnect, /if \(\$ForceLogin -or \$assessment\.NeedsLogin\)/,
    "a manual per-account reconnect must bypass a misleading reusable-token assessment");
  assert.match(accountReconnect, /Read-ClaudeCredential/);
  assert.match(accountReconnect, /FutureExpiry/);
  assert.match(accountReconnect, /RefreshUsable/,
    "an expired access token remains reusable while Claude's refresh token exists");
  assert.match(accountReconnect,
    /@\('AuthenticationRequired', 'CredentialsMissing'\) -contains \$errorName/,
    "only exact collector authentication failures may force OAuth");
  assert.doesNotMatch(accountReconnect, /@\('stale', 'error'\)/,
    "a generic provider error must not be mistaken for a broken login");
  assert.match(accountReconnect,
    /\$latestSnapshot = Read-TelemetrySnapshot[\s\S]*?Get-ClaudeAccountAssessment[\s\S]*?already current; login skipped/,
    "each queued profile must be checked again before another browser login opens");
  assert.match(accountReconnect, /Find-TelemetryAccountRow/);
  assert.doesNotMatch(accountReconnect, /Where-Object id -eq [^\r\n]+\)\[0\]/,
    "a missing first-run snapshot row must not abort the reconnect wizard under strict mode");
  assert.match(accountReconnect, /NO TERMINAL PASTE NEEDED[\s\S]*?masked native field[\s\S]*?clipboard watcher remains available as a fallback/,
    "the visible wizard must explain native-field submission and its fallback");
  assert.match(accountReconnect, /function Show-ClaudeAuthorizationCodeDialog/);
  assert.match(accountReconnect, /UseSystemPasswordChar = \$true/,
    "the native authorization-code field must mask its contents");
  assert.match(accountReconnect, /ShortcutsEnabled = \$true/,
    "the native field must accept ordinary Ctrl+V");
  assert.match(accountReconnect, /\$form\.AcceptButton = \$submit/,
    "Enter must submit the focused native field");
  assert.match(accountReconnect, /\$form\.CancelButton = \$cancel/,
    "Escape must cancel the native field");
  assert.match(accountReconnect,
    /\$manualCode = Show-ClaudeAuthorizationCodeDialog \$publicLabel[\s\S]*?Send-ClaudeAuthorizationCode \$manualCode/,
    "the validated native field must feed the exact console input writer");
  assert.match(accountReconnect, /Get-ClaudePublicAccountLabel/);
  assert.match(accountReconnect, /return 'Primary'[\s\S]*?return 'Secondary'/,
    "the reconnect UI must not expose account email addresses on a live stream");
  assert.match(accountReconnect, /function Test-ClaudeAuthorizationCode/);
  assert.match(accountReconnect, /\[A-Za-z0-9_-\]\{20,\}#\[A-Za-z0-9_-\]\{20,\}/,
    "only a Claude authorization-code-shaped clipboard value may be submitted");
  assert.match(accountReconnect, /WriteConsoleInputW/,
    "the wizard must bypass terminal paste bindings through the console input buffer");
  assert.match(accountReconnect, /VirtualKeyCode = VK_PACKET/,
    "authorization-code characters must use the Unicode console key identity");
  assert.match(accountReconnect,
    /\$clipboardBeforeLogin = \(Get-ClipboardText\)\.Trim\(\)[\s\S]*?\$clipboardNow -ne \$clipboardBeforeLogin[\s\S]*?Send-ClaudeAuthorizationCode/,
    "only a fresh browser clipboard code may be submitted to the waiting login");
  assert.match(accountReconnect, /\$env:CLAUDE_CONFIG_DIR = \$account\.ConfigDir/,
    "each email must keep its isolated Claude profile");
  assert.match(accountReconnect, /& claude auth logout/,
    "a forced reconnect must clear only the selected profile before login");
  assert.match(accountReconnect,
    /if \(-not \[string\]::IsNullOrWhiteSpace\(\$account\.Email\)\) \{\s*\$loginArguments \+= @\('--email', \$account\.Email\)/,
    "only a configured email may prefill the login, never a display label");
  assert.match(accountReconnect,
    /Start-Process -FilePath \$claudeExe -ArgumentList \$loginArguments/,
    "the optional email arguments must reach the observable login child process");
  assert.match(accountReconnect, /LastWriteTimeUtc -ge \$loginStartedAt/);
  assert.match(accountReconnect, /Stop-Process -Id \$loginProcess\.Id -Force/,
    "a browser flow that wrote the credential must not leave the terminal waiting forever");
  assert.match(accountReconnect, /Request-TelemetryRefresh/);
  assert.match(accountReconnect, /Test-CredentialNewerThanTelemetry/,
    "a manual Claude sign-in must be detected even when the old row is only retrying");
  assert.match(accountReconnect, /LastWriteTimeUtc -gt \$sampleAt/,
    "only a credential newer than its last telemetry sample may bypass the provider cooldown once");
  assert.match(accountReconnect, /Get-CimInstance Win32_Process/);
  assert.match(accountReconnect, /-ArgumentList '--usage-telemetry'/);
  assert.match(accountReconnect, /GetFullPath\(\$_\.ExecutablePath\)\) -ne \$expectedDirectory/,
    "the recovery flow must never stop a collector from another installation");
  assert.match(accountReconnect, /\$restartExisting = @\(\$results \| Where-Object \{ \$_\.Success -and \(\$_\.LoginAttempted -or \$_\.CredentialChanged\) \}\)\.Count -gt 0/,
    "a verified interactive login must restart the stale single-instance collector");
  assert.match(accountReconnect, /status -eq 'ok'/);
  assert.doesNotMatch(accountReconnect, /Write-Host[^\r\n]*\$accessToken/,
    "credential values must never be printed");
});

test("Claude reconnect assessment distinguishes provider errors from auth failures", () => {
  const result = childProcess.spawnSync(
    process.platform === "win32" ? "pwsh.exe" : "pwsh",
    ["-NoProfile", "-ExecutionPolicy", "Bypass", "-File",
      path.join(__dirname, "usage-telemetry", "test_reconnect_accounts.ps1")],
    { encoding: "utf8", env: { ...process.env, APPDATA: process.env.APPDATA || require("node:os").tmpdir() } },
  );
  assert.equal(result.status, 0, `${result.stdout}\n${result.stderr}`);
  assert.match(result.stdout, /Reconnect account assessment: PASS/);
});
