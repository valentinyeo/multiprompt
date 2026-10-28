const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const root = path.resolve(__dirname, "..");
const source = require('./app-source').readAppSource();
const telemetry = fs.readFileSync(path.join(root, "src", "usage_telemetry.zig"), "utf8");
const build = fs.readFileSync(path.join(root, "build.zig"), "utf8");

function functionBody(text, name, nextName) {
  const start = text.indexOf(`fn ${name}(`);
  const end = text.indexOf(`fn ${nextName}(`, start + 1);
  assert.notStrictEqual(start, -1, `missing ${name}`);
  assert.notStrictEqual(end, -1, `missing boundary ${nextName}`);
  return text.slice(start, end);
}

test("usage telemetry is native, headless, and file based", () => {
  assert.doesNotMatch(build, /\.name = "multiprompt-telemetry"/);
  assert.match(source, /usage_telemetry\.main\(init\)/);
  assert.match(build, /root_source_file = b\.path\("src\/usage_telemetry\.zig"\)/);
  assert.doesNotMatch(build, /multiprompt-usage|usage_companion/);
  assert.match(telemetry, /usage-telemetry\.json/);
  assert.match(telemetry, /writeFileAtomic/);
  assert.match(source, /fn fetchAiPaceSnapshot/);
  assert.match(source, /win32OpenRead\(path\)/);
  assert.doesNotMatch(source, /WinHttpConnect\(session, L\("127\.0\.0\.1"\), 47831/);
  assert.doesNotMatch(source, /openUsageCoach|showUsageCompanionPopup/);
});

test("native collector preserves retry cache and shared Claude cooldown", () => {
  assert.match(telemetry, /loadLegacyProviderCache/);
  assert.match(telemetry, /account\.status = \.retrying/);
  assert.match(telemetry, /claude_rate_limited_until_ms/);
  assert.match(telemetry, /CLAUDE_RATE_LIMIT_MS: i64 = 15 \* 60_000/);
  assert.match(telemetry, /runtime\.claude_rate_limited_until_ms = account\.rate_limited_until_ms/);
  assert.match(telemetry, /fn oldestDueClaudeIndex/);
  assert.match(telemetry, /const stamp = if \(account\.last_updated_at\.len == 0\)/);
  assert.match(telemetry, /account\.last_attempt_ms < runtime\.accounts\[selected\.\?\]\.last_attempt_ms/);
  assert.match(telemetry, /while \(oldestDueClaudeIndex\(runtime, now\)\) \|index\|/);
  assert.match(telemetry, /if \(now < runtime\.claude_rate_limited_until_ms\) break/);
});

test("OAuth renewal keeps the collector identifier instead of the usage header", () => {
  const renewal = functionBody(telemetry, "claudeAccessToken", "mergeClaudeRefresh");
  assert.match(renewal, /httpRequest\(runtime, "platform\.claude\.com", "\/v1\/oauth\/token", "POST", "Content-Type: application\/json\\r\\n", request_body\)/);
  assert.match(telemetry, /WinHttpOpen\(L\("multiprompt-telemetry\/" \+\+ COLLECTOR_VERSION\)/);
});

test("telemetry account labels are safe for live-stream display", () => {
  const collectorLabel = functionBody(telemetry, "publicAccountLabel", "loadConfig");
  assert.match(collectorLabel, /claude-primary[^\n]*return "Primary"/);
  assert.match(collectorLabel, /claude-secondary[^\n]*return "Secondary"/);
  assert.match(collectorLabel, /indexOfScalar\(u8, configured, '@'\)/);
  const cardLabel = functionBody(source, "aiPacePublicAccountLabel", "parseAiPaceSnapshot");
  assert.match(cardLabel, /claude-primary[^\n]*return "Primary"/);
  assert.match(cardLabel, /claude-secondary[^\n]*return "Secondary"/);
  assert.match(cardLabel, /indexOfScalar\(u8, configured, '@'\)/);
  const parse = functionBody(source, "parseAiPaceSnapshot", "aiPaceSnapshotPath");
  assert.match(parse, /goal\.setLabel\(aiPacePublicAccountLabel\(id, provider, configured_label\)\)/);
});

test("daily goals remain uncapped and persist through the sanitized snapshot", () => {
  const update = functionBody(telemetry, "updateGuidanceAndDailyGoal", "providerName");
  assert.match(update, /used_today \/ target \* 100/);
  assert.doesNotMatch(update, /clampPercent\([^\n]*used_today \/ target/);
  assert.match(telemetry, /usage-daily-goals\.json/);
  assert.match(telemetry, /"targetQuotaPercent"/);
  assert.match(telemetry, /"usedTodayQuotaPercent"/);
  assert.match(telemetry, /"remainingQuotaPercent"/);
  assert.match(telemetry, /canonicalDeadline/);
});

test("one-line carousel retains overview/VPS hover while AI opens the existing data menu", () => {
  assert.match(source, /const SIDEBAR_STICKY_CARD_H: i32 = 26;/);
  assert.match(source, /const SIDEBAR_STATUS_DETAIL_H: i32 = 222;/);
  assert.match(source, /const SIDEBAR_STICKY_CARD_COLLAPSED_H: i32 = 58;/);
  assert.match(source, /var g_sidebar_status_card: u8 = 0;/);
  const carousel = functionBody(source, "paintSidebarStickyStatusCard", "sidebarStatusPopupRect");
  assert.match(carousel, /paintSidebarCombinedCard\(hdc, rect, font_subtitle\)/);
  assert.match(carousel, /paintSidebarVpsCard\(hdc, host, rect, font_subtitle\)/);
  assert.match(carousel, /paintSidebarAiPaceCard\(hdc, rect, font_subtitle\)/);
  const popupAt = source.indexOf("fn paintSidebarStatusCardPopup(");
  assert.ok(popupAt >= 0);
  const popup = source.slice(popupAt, source.indexOf("\n}\n", popupAt));
  assert.match(popup, /if \(!g_status_card_hover/);
  assert.match(popup, /paintSidebarCombinedDetail/);
  assert.match(popup, /paintSidebarVpsDetail/);
  assert.match(popup, /g_sidebar_status_card == 2/);
  assert.doesNotMatch(popup, /paintSidebarAiPaceDetail/);
  assert.match(functionBody(source, "sidebarStatusPopupRect", "paintSidebarStatusCardPopup"), /uiScaled\(SIDEBAR_STATUS_DETAIL_H\)/);
  const move = source.slice(source.indexOf("WM_MOUSEMOVE => {"), source.indexOf("const upd_hit = updateCardHit(GET_X(lp), GET_Y(lp));"));
  assert.match(move, /sidebarStickyCardHoverTest\(GET_X\(lp\), GET_Y\(lp\)\)/);
  assert.match(move, /TrackMouseEvent\(&tracking\)/);
  assert.match(source, /0x02A3 => \{\s+if \(g_status_card_hover\) \{\s+g_status_card_hover = false;/);
  const line = functionBody(source, "paintSidebarAiPaceCard", "createAiUsageMenu");
  assert.match(line, /paintAiPaceWeekRuns/);
  assert.doesNotMatch(line, /formatResetHours|aiPaceNextWeeklyReset/);
  assert.doesNotMatch(line, /"CX"|"CL"/);
  assert.doesNotMatch(line, /ladder_mode/);
});

test("the usage display draws no burn label and no hours to reset", () => {
  assert.doesNotMatch(source, /fn aiPaceNextWeeklyReset|formatResetHours|earliestReset/);
  const detail = functionBody(source, "createAiUsageMenu", "showSidebarAiUsageMenu");
  assert.doesNotMatch(detail, /"BURN"|ladder_mode|CODEX" else "CLAUDE/);
  assert.doesNotMatch(source, /"Burn \{s\}: /);
});

test("the entire card cycles and has no dashboard deep-link target", () => {
  const clickAt = source.indexOf("if (sidebarStickyCardHitTest(my)) {");
  const logicalAt = source.indexOf("const logical_my = my + g_sidebar_scroll;", clickAt);
  assert.ok(clickAt >= 0 && logicalAt > clickAt);
  const click = source.slice(clickAt, logicalAt);
  assert.match(click, /cycleSidebarStatusCard\(1\)/);
  assert.doesNotMatch(click, /openUsageCoach|ReportSlot/);
  assert.doesNotMatch(source, /paintAiPaceReportIcon|sidebarAiPaceReportSlotHitTest/);
});

test("Ctrl+Shift+G cycles telemetry cards even when the browser owns focus", () => {
  const hook = functionBody(source, "keyboardHookProc", "pointOverActiveShell");
  const shortcutAt = hook.indexOf("kb.vkCode == 0x47) {");
  const browserIsolationAt = hook.indexOf("if (ctrl and (kb.flags & 0x20) == 0 and kb.vkCode != 0x09");
  assert.ok(shortcutAt >= 0 && shortcutAt < browserIsolationAt);
  assert.match(hook, /PostMessageW\(g_main_hwnd, WM_APP_CYCLE_STATUS_CARD, 0, 0\)/);
  assert.match(source, /WM_APP_CYCLE_STATUS_CARD => \{[\s\S]*?cycleSidebarStatusCard\(1\)/);
});

test("configured rows pair weekly usage with its reset and retain secondary quotas", () => {
  assert.match(source, /goals: \[4\]AiPaceGoal/);
  assert.match(source, /goal_count: usize = 0/);
  const parse = functionBody(source, "parseAiPaceSnapshot", "aiPaceSnapshotPath");
  assert.match(parse, /goal\.setLabel\(aiPacePublicAccountLabel\(id, provider, configured_label\)\)/);
  assert.match(parse, /next\.goal_count \+= 1/);
  assert.match(parse, /account_status, "retrying"/);
  assert.match(parse, /goal\.status = \.stale/);
  assert.match(parse, /"seven_day_fable"/);
  assert.match(parse, /goal\.fable_used_tenths = used/);
  assert.match(parse, /guidance\.get\("quotaId"\)/);
  assert.match(parse, /std\.mem\.eql\(u8, quota_id, guidance_quota_id\)/);
  assert.match(parse, /goal\.weekly_reset_filetime = reset_filetime/);
  assert.match(parse, /quota\.get\("windowMinutes"\)/);
  assert.match(parse, /goal\.five_hour_reset_filetime = reset_filetime/);
  const menu = functionBody(source, "createAiUsageMenu", "showSidebarAiUsageMenu");
  assert.match(menu, /snapshot\.goals\[0\.\.count\]/);
  assert.match(menu, /aiPaceProviderLabel\(&goal\)/);
  assert.match(menu, /formatAiPaceResetDetail/);
  assert.match(menu, /formatAiUsagePace\(&pace_buf, goal\.weekly_pace\)/);
  assert.match(menu, /formatAiUsagePace\(&five_pace_buf, goal\.five_hour_pace\)/);
  assert.match(menu, /formatAiPaceBonusReset/);
  assert.match(menu, /5H \{s\}.*Fable \{s\}/);
  assert.match(menu, /goal\.retrying/);
  assert.match(menu, /AppendMenuW/);
  assert.match(source, /IGSH-908 native usage menu retains distinct pools/);

});
