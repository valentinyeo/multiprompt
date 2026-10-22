const app_state = @import("app_state.zig");
const std = @import("std");
const json_reader = @import("json_reader.zig");
const tmux_identity = @import("tmux_identity.zig");
const chat_complete = @import("chat_complete.zig");
const IS_DEV = @import("main.zig").IS_DEV;
const workspace_snooze = @import("workspace_snooze.zig");
const DWORD = @import("win32.zig").DWORD;
const UINT = @import("win32.zig").UINT;
const SW_SHOW = @import("win32.zig").SW_SHOW;
const LoadImageW = @import("win32.zig").LoadImageW;
const IMAGE_ICON = @import("win32.zig").IMAGE_ICON;
const InvalidateRect = @import("win32.zig").InvalidateRect;
const CloseHandle = @import("win32.zig").CloseHandle;
const GetFileAttributesW = @import("win32.zig").GetFileAttributesW;
const GetEnvironmentVariableA = @import("win32.zig").GetEnvironmentVariableA;
const OpenProcess = @import("win32.zig").OpenProcess;
const GetTickCount64 = @import("win32.zig").GetTickCount64;
const PROCESS_TERMINATE = @import("win32.zig").PROCESS_TERMINATE;
const GetExitCodeProcess = @import("win32.zig").GetExitCodeProcess;
const STILL_ACTIVE = @import("win32.zig").STILL_ACTIVE;
const SESSION_JSON_CAPACITY = @import("app_state.zig").SESSION_JSON_CAPACITY;
const getInstanceName = @import("startup.zig").getInstanceName;
const isRemoteShellKind = @import("console.zig").isRemoteShellKind;
const ShellActivity = @import("app_state.zig").ShellActivity;
const BROWSER_SPLIT_DEFAULT_PERMILLE = @import("app_state.zig").BROWSER_SPLIT_DEFAULT_PERMILLE;
const empty_shell = @import("app_state.zig").empty_shell;
const MAX_SHELLS = @import("app_state.zig").MAX_SHELLS;
const setWideAscii = @import("themes.zig").setWideAscii;
const ensureDevThemeInitialized = @import("themes.zig").ensureDevThemeInitialized;
const loadGlobalTheme = @import("themes.zig").loadGlobalTheme;
const parseThemeIntField = @import("themes.zig").parseThemeIntField;
const parseThemeFontField = @import("themes.zig").parseThemeFontField;
const BROWSER_SUSPEND_DEFAULT_MIN = @import("app_state.zig").BROWSER_SUSPEND_DEFAULT_MIN;
const loadBrowserEngineConfig = @import("browser_pane.zig").loadBrowserEngineConfig;
const loadEdgeProfileConfig = @import("browser_pane.zig").loadEdgeProfileConfig;
const loadEdgeExeConfig = @import("browser_pane.zig").loadEdgeExeConfig;
const loadChromeExeConfig = @import("browser_pane.zig").loadChromeExeConfig;
const DEV_CONSOLE_FONTS = @import("app_state.zig").DEV_CONSOLE_FONTS;
const MAX_LWS = @import("app_state.zig").MAX_LWS;
const MAX_GROUPS = @import("app_state.zig").MAX_GROUPS;
const GROUP_COLORS = @import("app_state.zig").GROUP_COLORS;
const findGroupIdx = @import("sidebar.zig").findGroupIdx;
const writeArchiveMarkers = @import("sidebar.zig").writeArchiveMarkers;
const restoreArchiveMarkers = @import("sidebar.zig").restoreArchiveMarkers;
const noteRestoredBlueDot = @import("sidebar.zig").noteRestoredBlueDot;
const pruneEmptyGroups = @import("sidebar.zig").pruneEmptyGroups;
const normalizeGroupOrder = @import("sidebar.zig").normalizeGroupOrder;
const tmuxHostLongLabel = @import("capacity.zig").tmuxHostLongLabel;
const CHAT_FONT_DEFAULT_PT = @import("app_state.zig").CHAT_FONT_DEFAULT_PT;
const ProcessPollCache = @import("app_state.zig").ProcessPollCache;
const win32OpenRead = @import("file_io.zig").win32OpenRead;
const win32OpenWrite = @import("file_io.zig").win32OpenWrite;
const win32WriteAll = @import("file_io.zig").win32WriteAll;
const win32ReadAll = @import("file_io.zig").win32ReadAll;
const win32MakeDir = @import("file_io.zig").win32MakeDir;
const win32MovePath = @import("file_io.zig").win32MovePath;
const writeFileAtomicW = @import("file_io.zig").writeFileAtomicW;
const appendJsonEscaped = @import("workspaces.zig").appendJsonEscaped;
const ensureWorkspaceSlotId = @import("workspaces.zig").ensureWorkspaceSlotId;
const debugLog = @import("diagnostics.zig").debugLog;
const debugLog2 = @import("diagnostics.zig").debugLog2;
const writeAuditEscapedBytes = @import("diagnostics.zig").writeAuditEscapedBytes;
const writeAuditEscapedWideAscii = @import("diagnostics.zig").writeAuditEscapedWideAscii;
const writeAuditU64 = @import("diagnostics.zig").writeAuditU64;
const openSessionAudit = @import("diagnostics.zig").openSessionAudit;
const writeAuditHeader = @import("diagnostics.zig").writeAuditHeader;
const logSessionAuditAlways = @import("diagnostics.zig").logSessionAuditAlways;
const logSessionAudit = @import("diagnostics.zig").logSessionAudit;
const publishSessionLayout = @import("account_desktop.zig").publishSessionLayout;
const SavedTab = @import("app_state.zig").SavedTab;
const reclaimShell = @import("console.zig").reclaimShell;
const TMUX_HOST_DE = @import("app_state.zig").TMUX_HOST_DE;
const TMUX_HOST_UK = @import("app_state.zig").TMUX_HOST_UK;
const VOICE_SPEED_DEFAULT = @import("app_state.zig").VOICE_SPEED_DEFAULT;
const voiceSpeedSessionValue = @import("voice.zig").voiceSpeedSessionValue;
const capacityJsonValue = @import("capacity.zig").capacityJsonValue;
const appendJsonEscapedWide = @import("snippets.zig").appendJsonEscapedWide;
const spawnShellWithSession = @import("console.zig").spawnShellWithSession;
const killProcessTree = @import("console.zig").killProcessTree;
const switchToShell = @import("console.zig").switchToShell;
const ensureOtherWorkspaceSlot = @import("workspaces.zig").ensureOtherWorkspaceSlot;
const compactWorkspaceSlots = @import("workspaces.zig").compactWorkspaceSlots;
const ensureBrowserDefaultUrl = @import("browser_pane.zig").ensureBrowserDefaultUrl;
const browserUrlIsRealPage = @import("browser_pane.zig").browserUrlIsRealPage;
const chatBenchEnabled = @import("chat_session.zig").chatBenchEnabled;
const showShellConsole = @import("chat_composer.zig").showShellConsole;
const repositionActive = @import("window_layout.zig").repositionActive;
const findLocalTmuxTab = @import("notifications.zig").findLocalTmuxTab;
const nowFileTime = @import("inbox.zig").nowFileTime;
const writeUintTo = @import("inbox.zig").writeUintTo;
const inboxPublishesShell = @import("inbox.zig").inboxPublishesShell;
const findShellById = @import("inbox.zig").findShellById;

pub fn getSessionPath(buf: *[512]u8) ?[]const u8 {
    const appdata_len = GetEnvironmentVariableA("APPDATA", buf, 512);
    if (appdata_len == 0 or appdata_len >= 460) return null;
    const inst = getInstanceName();
    if (std.mem.eql(u8, inst, "default")) {
        const rest = "\\ZigShell\\session.json";
        @memcpy(buf[appdata_len .. appdata_len + rest.len], rest);
        return buf[0 .. appdata_len + rest.len];
    } else {
        const prefix = "\\ZigShell\\session-";
        const suffix = ".json";
        var pos: usize = appdata_len;
        @memcpy(buf[pos .. pos + prefix.len], prefix);
        pos += prefix.len;
        @memcpy(buf[pos .. pos + inst.len], inst);
        pos += inst.len;
        @memcpy(buf[pos .. pos + suffix.len], suffix);
        pos += suffix.len;
        return buf[0..pos];
    }
}

pub fn getSessionPathForWorkspace(buf: *[512]u8, id: []const u8) ?[]const u8 {
    const appdata_len = GetEnvironmentVariableA("APPDATA", buf, 512);
    if (appdata_len == 0 or appdata_len >= 460) return null;
    if (std.mem.eql(u8, id, "default")) {
        const rest = "\\ZigShell\\session.json";
        @memcpy(buf[appdata_len .. appdata_len + rest.len], rest);
        return buf[0 .. appdata_len + rest.len];
    } else {
        const prefix = "\\ZigShell\\session-";
        const suffix = ".json";
        if (appdata_len + prefix.len + id.len + suffix.len >= buf.len) return null;
        var pos: usize = appdata_len;
        @memcpy(buf[pos .. pos + prefix.len], prefix);
        pos += prefix.len;
        @memcpy(buf[pos .. pos + id.len], id);
        pos += id.len;
        @memcpy(buf[pos .. pos + suffix.len], suffix);
        pos += suffix.len;
        return buf[0..pos];
    }
}

pub fn getSessionDir(buf: *[512]u8) ?[]const u8 {
    const appdata_len = GetEnvironmentVariableA("APPDATA", buf, 512);
    if (appdata_len == 0 or appdata_len >= 500) return null;
    const rest = "\\ZigShell";
    @memcpy(buf[appdata_len .. appdata_len + rest.len], rest);
    return buf[0 .. appdata_len + rest.len];
}

pub fn getFaviconDir(buf: *[512]u8) ?[]const u8 {
    const appdata_len = GetEnvironmentVariableA("APPDATA", buf, 512);
    if (appdata_len == 0 or appdata_len >= 490) return null;
    const rest = "\\ZigShell\\favicons";
    @memcpy(buf[appdata_len .. appdata_len + rest.len], rest);
    return buf[0 .. appdata_len + rest.len];
}

pub fn saveSessionTo(path: []const u8, workspace_filter: ?u8) bool {
    var dir_buf: [512]u8 = undefined;
    if (getSessionDir(&dir_buf)) |dir| {
        win32MakeDir(dir);
    }

    var json_buf: [SESSION_JSON_CAPACITY]u8 = undefined;
    var pos: usize = 0;
    var proc_cache: ProcessPollCache = undefined;
    var proc_cache_ready = false;

    const header = "{\"tabs\":[";
    @memcpy(json_buf[pos .. pos + header.len], header);
    pos += header.len;

    var written_tabs: usize = 0;
    for (0..app_state.shell_count) |i| {
        if (workspace_filter != null and app_state.shells[i].workspace != workspace_filter.?) continue;
        if (pos >= json_buf.len - 4096) return false;
        if (written_tabs > 0) {
            json_buf[pos] = ',';
            pos += 1;
        }

        written_tabs += 1;
        const kind_str: []const u8 = switch (app_state.shells[i].kind) {
            .cmd => "cmd",
            .pwsh => "pwsh",
            .vps => "vps",
            .tmux => "tmux",
            .vps2 => "vps2",
            .bash => "bash",
            .gitbash => "gitbash",
        };

        const pre = "{\"kind\":\"";
        @memcpy(json_buf[pos .. pos + pre.len], pre);
        pos += pre.len;
        @memcpy(json_buf[pos .. pos + kind_str.len], kind_str);
        pos += kind_str.len;
        const mid = "\",\"name\":\"";
        @memcpy(json_buf[pos .. pos + mid.len], mid);
        pos += mid.len;

        appendJsonEscapedWide(&json_buf, &pos, app_state.shells[i].name[0..app_state.shells[i].name_len]);

        if (app_state.shells[i].sync_owned) {
            const owned = "\",\"sync_owned\":true";
            @memcpy(json_buf[pos .. pos + owned.len], owned);
            pos += owned.len;
        } else {
            json_buf[pos] = '"';
            pos += 1;
        }

        const wake_id: u32 = if (workspace_filter != null) @intCast(written_tabs) else app_state.shells[i].wake_id;
        if (wake_id != 0) {
            const pre_id = ",\"wake_id\":";
            @memcpy(json_buf[pos .. pos + pre_id.len], pre_id);
            pos += pre_id.len;
            pos += writeUintTo(json_buf[pos..], wake_id);
        }

        if (app_state.shells[i].name_source == .manual) {
            const mf = ",\"manual\":true";
            @memcpy(json_buf[pos .. pos + mf.len], mf);
            pos += mf.len;
        } else if (app_state.shells[i].name_source == .semantic) {
            const sf = ",\"sem\":true";
            @memcpy(json_buf[pos .. pos + sf.len], sf);
            pos += sf.len;
        }

        if (app_state.shells[i].kind == .tmux and app_state.shells[i].tmux_session_len > 0) {
            const ts_pre = ",\"tmux_session\":\"";
            @memcpy(json_buf[pos .. pos + ts_pre.len], ts_pre);
            pos += ts_pre.len;
            for (0..app_state.shells[i].tmux_session_len) |j| {
                json_buf[pos] = app_state.shells[i].tmux_session[j];
                pos += 1;
            }
            json_buf[pos] = '"';
            pos += 1;
        }

        if (app_state.shells[i].kind == .cmd or app_state.shells[i].kind == .pwsh or app_state.shells[i].kind == .bash) {
            if (app_state.shells[i].cached_cwd_len > 0) {
                const cwd = app_state.shells[i].cached_cwd[0..app_state.shells[i].cached_cwd_len];
                const cwd_pre = ",\"cwd\":\"";
                @memcpy(json_buf[pos .. pos + cwd_pre.len], cwd_pre);
                pos += cwd_pre.len;
                for (cwd) |c| {
                    if (c == '\\' or c == '"') {
                        json_buf[pos] = '\\';
                        pos += 1;
                    }
                    json_buf[pos] = c;
                    pos += 1;
                    if (pos >= json_buf.len - 40) break;
                }
                json_buf[pos] = '"';
                pos += 1;
            }

            if (!proc_cache_ready) {
                proc_cache.refresh();
                proc_cache_ready = true;
            }
            if (proc_cache.findClaudeChildPid(app_state.shells[i].pid) != null or app_state.shells[i].claude_sid_len > 0) {
                const cf = ",\"claude_session\":true";
                @memcpy(json_buf[pos .. pos + cf.len], cf);
                pos += cf.len;
            }
        }

        if (app_state.shells[i].pid != 0) {
            const pid_pre = ",\"pid\":";
            @memcpy(json_buf[pos .. pos + pid_pre.len], pid_pre);
            pos += pid_pre.len;
            var pid_val = app_state.shells[i].pid;
            var pid_digits: [10]u8 = undefined;
            var pid_dlen: usize = 0;
            if (pid_val == 0) {
                json_buf[pos] = '0';
                pos += 1;
            } else {
                while (pid_val > 0) {
                    pid_digits[pid_dlen] = @intCast((pid_val % 10) + '0');
                    pid_dlen += 1;
                    pid_val /= 10;
                }
                var di: usize = pid_dlen;
                while (di > 0) {
                    di -= 1;
                    json_buf[pos] = pid_digits[di];
                    pos += 1;
                }
            }
        }

        if (app_state.shells[i].muted) {
            const mf = ",\"muted\":true";
            @memcpy(json_buf[pos .. pos + mf.len], mf);
            pos += mf.len;
        }

        if (app_state.shells[i].keep_alive) {
            const kf = ",\"keep_alive\":true";
            @memcpy(json_buf[pos .. pos + kf.len], kf);
            pos += kf.len;
        }

        if (app_state.shells[i].pinned_top) {
            const pf = ",\"pinned_top\":true";
            @memcpy(json_buf[pos .. pos + pf.len], pf);
            pos += pf.len;
        }
        if (app_state.shells[i].inbox_excluded) {
            const ix = ",\"inbox_excluded\":true";
            @memcpy(json_buf[pos .. pos + ix.len], ix);
            pos += ix.len;
        }
        const used = ",\"used_unix\":true,\"used\":";
        @memcpy(json_buf[pos .. pos + used.len], used);
        pos += used.len;
        pos += writeUintTo(json_buf[pos..], app_state.shells[i].last_used);
        pos += @import("frequent.zig").writeInput(json_buf[pos..], app_state.shells[i].input);
        pos += @import("frequent.zig").writeVisits(json_buf[pos..], app_state.shells[i].visits);
        if (app_state.shells[i].favorite) {
            const ff = ",\"favorite\":true";
            @memcpy(json_buf[pos .. pos + ff.len], ff);
            pos += ff.len;
        }
        if (app_state.shells[i].locked) {
            const lf = ",\"locked\":true";
            @memcpy(json_buf[pos .. pos + lf.len], lf);
            pos += lf.len;
        }
        if (app_state.shells[i].group_id != 0) {
            const gp = ",\"group_id\":";
            @memcpy(json_buf[pos .. pos + gp.len], gp);
            pos += gp.len;
            var gv = app_state.shells[i].group_id;
            var gdig: [10]u8 = undefined;
            var gdi: usize = 0;
            if (gv == 0) {
                gdig[0] = '0';
                gdi = 1;
            } else {
                while (gv > 0) : (gdi += 1) {
                    gdig[gdi] = @intCast(gv % 10 + '0');
                    gv /= 10;
                }
            }
            while (gdi > 0) {
                gdi -= 1;
                json_buf[pos] = gdig[gdi];
                pos += 1;
            }
        }

        if (app_state.shells[i].workspace != 0) {
            const wsp = ",\"workspace\":";
            @memcpy(json_buf[pos .. pos + wsp.len], wsp);
            pos += wsp.len;
            json_buf[pos] = @as(u8, '0') + app_state.shells[i].workspace;
            pos += 1;
        }

        if (app_state.shells[i].kind == .tmux and app_state.shells[i].tmux_host != 0) {
            const hp = ",\"tmux_host\":";
            @memcpy(json_buf[pos .. pos + hp.len], hp);
            pos += hp.len;
            json_buf[pos] = @as(u8, '0') + app_state.shells[i].tmux_host;
            pos += 1;
        }

        if (app_state.shells[i].favicon_path_len > 0) {
            const fp_pre = ",\"favicon_path\":\"";
            @memcpy(json_buf[pos .. pos + fp_pre.len], fp_pre);
            pos += fp_pre.len;
            for (app_state.shells[i].favicon_path[0..app_state.shells[i].favicon_path_len]) |c| {
                if (c == '\\' or c == '"') {
                    json_buf[pos] = '\\';
                    pos += 1;
                }
                json_buf[pos] = c;
                pos += 1;
                if (pos >= json_buf.len - 40) break;
            }
            json_buf[pos] = '"';
            pos += 1;
        }

        const saved_id = std.fmt.bufPrint(json_buf[pos..], ",\"shell_id\":{d}", .{app_state.shells[i].shell_id}) catch return false;
        pos += saved_id.len;
        if (app_state.shells[i].last_active != 0) {
            const la_pre = ",\"la\":";
            @memcpy(json_buf[pos .. pos + la_pre.len], la_pre);
            pos += la_pre.len;
            pos += writeUintTo(json_buf[pos..], app_state.shells[i].last_active);
        }
        if (app_state.shells[i].last_viewed != 0) {
            const lv_pre = ",\"lv\":";
            @memcpy(json_buf[pos .. pos + lv_pre.len], lv_pre);
            pos += lv_pre.len;
            pos += writeUintTo(json_buf[pos..], app_state.shells[i].last_viewed);
        }
        const chat_id_pre = ",\"chat_id\":";
        @memcpy(json_buf[pos .. pos + chat_id_pre.len], chat_id_pre);
        pos += chat_id_pre.len;
        pos += writeUintTo(json_buf[pos..], app_state.shells[i].chat_id);
        if (app_state.shells[i].claude_sid_len > 0 and pos < json_buf.len - 60) {
            const cs_pre = ",\"csid\":\"";
            @memcpy(json_buf[pos .. pos + cs_pre.len], cs_pre);
            pos += cs_pre.len;
            for (0..app_state.shells[i].claude_sid_len) |j| {
                if (pos >= json_buf.len - 20) break;
                json_buf[pos] = app_state.shells[i].claude_sid[j];
                pos += 1;
            }
            json_buf[pos] = '"';
            pos += 1;
        }
        if (app_state.shells[i].claude_cwd_len > 0 and pos < json_buf.len - 220) {
            const cc_pre = ",\"ccwd\":\"";
            @memcpy(json_buf[pos .. pos + cc_pre.len], cc_pre);
            pos += cc_pre.len;
            appendJsonEscaped(&json_buf, &pos, app_state.shells[i].claude_cwd[0..app_state.shells[i].claude_cwd_len]);
            json_buf[pos] = '"';
            pos += 1;
        }
        if (app_state.shells[i].browser_enabled and pos < json_buf.len - 560) {
            const bon = ",\"bon\":true";
            @memcpy(json_buf[pos .. pos + bon.len], bon);
            pos += bon.len;
        }
        if (app_state.shells[i].keep_awake and pos < json_buf.len - 540) {
            const kaw = ",\"kaw\":true";
            @memcpy(json_buf[pos .. pos + kaw.len], kaw);
            pos += kaw.len;
        }
        if (app_state.shells[i].chat_view_on and pos < json_buf.len - 540) {
            const cv = ",\"cv\":true";
            @memcpy(json_buf[pos .. pos + cv.len], cv);
            pos += cv.len;
        }
        if (app_state.ISSUE_373_SHELL_OVERRIDE and app_state.shells[i].chat_shell_override and pos < json_buf.len - 540) {
            const cso = ",\"cso\":true";
            @memcpy(json_buf[pos .. pos + cso.len], cso);
            pos += cso.len;
        }
        if (app_state.ISSUE_347_KEEP_FULL_WIDTH and app_state.shells[i].full_width and pos < json_buf.len - 540) {
            const fw = ",\"fw\":true";
            @memcpy(json_buf[pos .. pos + fw.len], fw);
            pos += fw.len;
        }
        if (app_state.shells[i].inbox_archived and pos < json_buf.len - 540) {
            const iah = ",\"iah\":true";
            @memcpy(json_buf[pos .. pos + iah.len], iah);
            pos += iah.len;
        }
        if (app_state.shells[i].inbox_archived or app_state.shells[i].last_done_content_valid) {
            if (pos >= json_buf.len - 2700) return false;
            pos += writeArchiveMarkers(json_buf[pos..], &app_state.shells[i]);
        }
        if (app_state.shells[i].needs_attention and pos < json_buf.len - 540) {
            const att = ",\"att\":true";
            @memcpy(json_buf[pos .. pos + att.len], att);
            pos += att.len;
        }
        if (app_state.shells[i].browser_split_permille != BROWSER_SPLIT_DEFAULT_PERMILLE and pos < json_buf.len - 540) {
            const bs_pre = ",\"bsplit\":";
            @memcpy(json_buf[pos .. pos + bs_pre.len], bs_pre);
            pos += bs_pre.len;
            pos += writeUintTo(json_buf[pos..], app_state.shells[i].browser_split_permille);
        }
        if (app_state.shells[i].browser_enabled and !app_state.shells[i].browser_native and pos < json_buf.len - 540) {
            const bnat_str = ",\"bnat\":false";
            @memcpy(json_buf[pos .. pos + bnat_str.len], bnat_str);
            pos += bnat_str.len;
        }
        if (app_state.shells[i].browser_enabled and app_state.shells[i].browser_url_len > 0 and pos < json_buf.len - 540) {
            const bu_pre = ",\"burl\":\"";
            @memcpy(json_buf[pos .. pos + bu_pre.len], bu_pre);
            pos += bu_pre.len;
            appendJsonEscaped(&json_buf, &pos, app_state.shells[i].browser_url[0..app_state.shells[i].browser_url_len]);
            json_buf[pos] = '"';
            pos += 1;
        }

        json_buf[pos] = '}';
        pos += 1;
    }

    const footer_tabs = "]";
    @memcpy(json_buf[pos .. pos + footer_tabs.len], footer_tabs);
    pos += footer_tabs.len;

    if (app_state.active_shell < app_state.shell_count and (!app_state.g_single_window or app_state.shells[app_state.active_shell].workspace == app_state.g_active_workspace) and pos + 32 < json_buf.len) {
        var at_buf: [32]u8 = undefined;
        const at = std.fmt.bufPrint(&at_buf, ",\"active_tab\":{d}", .{app_state.active_shell}) catch at_buf[0..0];
        @memcpy(json_buf[pos .. pos + at.len], at);
        pos += at.len;
    }

    if (app_state.g_light_theme) {
        const tf = ",\"light_theme\":true";
        @memcpy(json_buf[pos .. pos + tf.len], tf);
        pos += tf.len;
    }
    if (app_state.g_mid_theme) {
        const mf = ",\"mid_theme\":true";
        @memcpy(json_buf[pos .. pos + mf.len], mf);
        pos += mf.len;
    }
    if (app_state.g_edge_gray_theme) {
        const egf = ",\"edge_gray_theme\":true";
        @memcpy(json_buf[pos .. pos + egf.len], egf);
        pos += egf.len;
    }
    if (app_state.g_amoled_theme) {
        const af = ",\"amoled_theme\":true";
        @memcpy(json_buf[pos .. pos + af.len], af);
        pos += af.len;
    }
    if (IS_DEV and app_state.g_dev_theme_active) {
        const df = ",\"dev_theme_active\":true";
        @memcpy(json_buf[pos .. pos + df.len], df);
        pos += df.len;
    }
    if (IS_DEV) {
        ensureDevThemeInitialized();
        var devbuf: [160]u8 = undefined;
        const ds = std.fmt.bufPrint(&devbuf, ",\"dev_amoled\":{s},\"dev_font_idx\":{d},\"dev_console_size\":{d}", .{ if (app_state.g_amoled_theme) "true" else "false", app_state.g_dev_font_idx, app_state.g_dev_theme.console_font_height }) catch devbuf[0..0];
        if (pos + ds.len < json_buf.len) {
            @memcpy(json_buf[pos .. pos + ds.len], ds);
            pos += ds.len;
        }
    }
    if (app_state.g_sound_enabled) {
        const sf = ",\"sound_enabled\":true";
        @memcpy(json_buf[pos .. pos + sf.len], sf);
        pos += sf.len;
    }
    if (app_state.g_mobile_mode) {
        const mmf = ",\"mobile_mode\":true";
        @memcpy(json_buf[pos .. pos + mmf.len], mmf);
        pos += mmf.len;
    }
    if (app_state.g_hide_sidebar) {
        const hsf = ",\"hide_sidebar\":true";
        @memcpy(json_buf[pos .. pos + hsf.len], hsf);
        pos += hsf.len;
    }
    if (app_state.g_sidebar_collapsed) {
        const scf = ",\"sidebar_collapsed\":true";
        @memcpy(json_buf[pos .. pos + scf.len], scf);
        pos += scf.len;
    }
    if (app_state.g_locked_section_collapsed) {
        const lsc = ",\"locked_section_collapsed\":true";
        @memcpy(json_buf[pos .. pos + lsc.len], lsc);
        pos += lsc.len;
    }
    if (app_state.g_pinned_section_collapsed) {
        const psc = ",\"pinned_section_collapsed\":true";
        @memcpy(json_buf[pos .. pos + psc.len], psc);
        pos += psc.len;
    }
    if (app_state.g_recents_section_collapsed) {
        const rsc = ",\"recents_section_collapsed\":true";
        @memcpy(json_buf[pos .. pos + rsc.len], rsc);
        pos += rsc.len;
    }
    if (IS_DEV and !app_state.g_thread_title) {
        const ttf = ",\"thread_title\":false";
        @memcpy(json_buf[pos .. pos + ttf.len], ttf);
        pos += ttf.len;
    }
    if (app_state.g_console_font_override > 0 and pos + 32 < json_buf.len) {
        var cfh_buf: [32]u8 = undefined;
        const cfh = std.fmt.bufPrint(&cfh_buf, ",\"console_font_h\":{d}", .{app_state.g_console_font_override}) catch cfh_buf[0..0];
        @memcpy(json_buf[pos .. pos + cfh.len], cfh);
        pos += cfh.len;
    }
    if (app_state.g_chat_font_pt != CHAT_FONT_DEFAULT_PT and pos + 32 < json_buf.len) {
        var cfp_buf: [32]u8 = undefined;
        const cfp = std.fmt.bufPrint(&cfp_buf, ",\"chat_font_pt\":{d}", .{app_state.g_chat_font_pt}) catch cfp_buf[0..0];
        @memcpy(json_buf[pos .. pos + cfp.len], cfp);
        pos += cfp.len;
    }
    for (0..2) |a| for (0..app_state.g_chat_ac_mru_count[a]) |i| {
        const name = std.mem.sliceTo(&app_state.g_chat_ac_mru[a][i], 0);
        if (name.len == 0 or pos + name.len * 2 + 64 >= json_buf.len) continue;
        var key_buf: [48]u8 = undefined;
        const key = std.fmt.bufPrint(&key_buf, ",\"chat_ac_{s}_{d}\":\"", .{ if (a == 0) @as([]const u8, "claude") else "codex", i }) catch continue;
        @memcpy(json_buf[pos .. pos + key.len], key);
        pos += key.len;
        appendJsonEscaped(&json_buf, &pos, name);
        json_buf[pos] = '"';
        pos += 1;
    };
    if (app_state.g_chat_view_mode != .per_session and pos + 40 < json_buf.len) {
        const cvm: []const u8 = if (app_state.g_chat_view_mode == .everywhere) ",\"chat_view_mode\":\"everywhere\"" else ",\"chat_view_mode\":\"nowhere\"";
        @memcpy(json_buf[pos .. pos + cvm.len], cvm);
        pos += cvm.len;
    }
    if (app_state.g_chat_view_mode == .everywhere and app_state.g_chat_active and pos + 24 < json_buf.len) {
        const gca = ",\"chat_active\":true";
        @memcpy(json_buf[pos .. pos + gca.len], gca);
        pos += gca.len;
    }
    if (!app_state.g_igsh354_paste_focus and pos + 36 < json_buf.len) {
        const setting = ",\"igsh354_paste_focus\":false";
        @memcpy(json_buf[pos .. pos + setting.len], setting);
        pos += setting.len;
    }
    if (!app_state.g_voice_always_listen and pos + 36 < json_buf.len) {
        const setting = ",\"voice_always_listen\":false";
        @memcpy(json_buf[pos .. pos + setting.len], setting);
        pos += setting.len;
    }
    if (!app_state.g_eta_numbers_on and pos + 32 < json_buf.len) {
        const etn = ",\"eta_numbers\":false";
        @memcpy(json_buf[pos .. pos + etn.len], etn);
        pos += etn.len;
    }
    if (!app_state.g_eta_progress_on and pos + 32 < json_buf.len) {
        const etp = ",\"eta_progress\":false";
        @memcpy(json_buf[pos .. pos + etp.len], etp);
        pos += etp.len;
    }
    if (app_state.g_voice_speed != VOICE_SPEED_DEFAULT and pos + 40 < json_buf.len) {
        var vsp_buf: [40]u8 = undefined;
        const vsp = std.fmt.bufPrint(&vsp_buf, ",\"voice_speed\":\"{s}\"", .{voiceSpeedSessionValue(app_state.g_voice_speed)}) catch vsp_buf[0..0];
        @memcpy(json_buf[pos .. pos + vsp.len], vsp);
        pos += vsp.len;
    }
    if (app_state.g_ui_scale != 100 and pos + 24 < json_buf.len) {
        var uis_buf: [24]u8 = undefined;
        const uis = std.fmt.bufPrint(&uis_buf, ",\"ui_scale\":{d}", .{app_state.g_ui_scale}) catch uis_buf[0..0];
        @memcpy(json_buf[pos .. pos + uis.len], uis);
        pos += uis.len;
    }
    if ((!app_state.g_browser_autosuspend or app_state.g_browser_suspend_min != BROWSER_SUSPEND_DEFAULT_MIN) and pos + 32 < json_buf.len) {
        var bsm_buf: [32]u8 = undefined;
        const bsm = std.fmt.bufPrint(&bsm_buf, ",\"browser_suspend_min\":{d}", .{if (app_state.g_browser_autosuspend) app_state.g_browser_suspend_min else 0}) catch bsm_buf[0..0];
        @memcpy(json_buf[pos .. pos + bsm.len], bsm);
        pos += bsm.len;
    }
    {
        const hpf = if (app_state.g_hide_pills) ",\"hide_pills\":true" else ",\"hide_pills\":false";
        @memcpy(json_buf[pos .. pos + hpf.len], hpf);
        pos += hpf.len;
    }

    if (app_state.g_layout_settings) |settings| {
        const text = std.fmt.bufPrint(json_buf[pos..], ",\"settings\":{{\"frequent\":{},\"favorites\":{},\"all\":{},\"frequent_first\":{}}}", .{ settings.frequent, settings.favorites, settings.all, settings.frequent_first }) catch return false;
        pos += text.len;
    }
    const split_state = std.fmt.bufPrint(json_buf[pos..], ",\"inbox_tab\":{d},\"inbox_visits_order\":true", .{app_state.g_inbox_tab}) catch return false;
    pos += split_state.len;
    if (app_state.g_single_window and pos + 256 < json_buf.len) {
        var swbuf: [96]u8 = undefined;
        const sw = std.fmt.bufPrint(&swbuf, ",\"single_window\":true,\"active_workspace\":{d},\"workspace_count\":{d},\"workspaces\":[", .{ app_state.g_active_workspace, app_state.g_lws_count }) catch swbuf[0..0];
        @memcpy(json_buf[pos .. pos + sw.len], sw);
        pos += sw.len;
        var wi: usize = 0;
        while (wi < app_state.g_lws_count and pos + 160 < json_buf.len) : (wi += 1) {
            if (wi > 0) {
                json_buf[pos] = ',';
                pos += 1;
            }
            const np = "{\"name\":\"";
            @memcpy(json_buf[pos .. pos + np.len], np);
            pos += np.len;
            const nlen = @min(app_state.g_ws_name_len[wi], 31);
            appendJsonEscaped(&json_buf, &pos, app_state.g_ws_names[wi][0..nlen]);
            json_buf[pos] = '"';
            pos += 1;
            ensureWorkspaceSlotId(@intCast(wi));
            const wp_ = ",\"wid\":\"";
            @memcpy(json_buf[pos .. pos + wp_.len], wp_);
            pos += wp_.len;
            const widl = app_state.g_ws_id_len[wi];
            @memcpy(json_buf[pos .. pos + widl], app_state.g_ws_ids[wi][0..widl]);
            pos += widl;
            json_buf[pos] = '"';
            pos += 1;
            const last_shell = std.fmt.bufPrint(json_buf[pos..], ",\"last_shell\":{d}", .{app_state.g_ws_last_shell[wi]}) catch return false;
            pos += last_shell.len;
            if (app_state.g_ws_snoozed[wi]) {
                const sn = ",\"snoozed\":true";
                @memcpy(json_buf[pos .. pos + sn.len], sn);
                pos += sn.len;
            }
            json_buf[pos] = '}';
            pos += 1;
        }
        json_buf[pos] = ']';
        pos += 1;
    }

    if (app_state.group_count > 0) {
        const gh = ",\"groups\":[";
        @memcpy(json_buf[pos .. pos + gh.len], gh);
        pos += gh.len;
        for (0..app_state.group_count) |gi| {
            if (pos >= json_buf.len - 512) break;
            if (gi > 0) {
                json_buf[pos] = ',';
                pos += 1;
            }
            const gpre = "{\"id\":";
            @memcpy(json_buf[pos .. pos + gpre.len], gpre);
            pos += gpre.len;
            var gv = app_state.groups[gi].id;
            var gdig: [10]u8 = undefined;
            var gdi: usize = 0;
            if (gv == 0) {
                gdig[0] = '0';
                gdi = 1;
            } else {
                while (gv > 0) : (gdi += 1) {
                    gdig[gdi] = @intCast(gv % 10 + '0');
                    gv /= 10;
                }
            }
            while (gdi > 0) {
                gdi -= 1;
                json_buf[pos] = gdig[gdi];
                pos += 1;
            }
            const gmid = ",\"name\":\"";
            @memcpy(json_buf[pos .. pos + gmid.len], gmid);
            pos += gmid.len;
            for (0..app_state.groups[gi].name_len) |j| {
                const u = app_state.groups[gi].name[j];
                const b: u8 = if (u < 128) @intCast(u) else '?';
                appendJsonEscaped(&json_buf, &pos, &.{b});
                if (pos >= json_buf.len - 40) break;
            }
            json_buf[pos] = '"';
            pos += 1;
            if (app_state.groups[gi].collapsed) {
                const cf = ",\"collapsed\":true";
                @memcpy(json_buf[pos .. pos + cf.len], cf);
                pos += cf.len;
            }
            if (app_state.groups[gi].color != 0) {
                const cpfx = ",\"color\":";
                @memcpy(json_buf[pos .. pos + cpfx.len], cpfx);
                pos += cpfx.len;
                var cv: u32 = app_state.groups[gi].color;
                var cdig: [3]u8 = undefined;
                var cdi: usize = 0;
                if (cv == 0) {
                    cdig[0] = '0';
                    cdi = 1;
                } else {
                    while (cv > 0) : (cdi += 1) {
                        cdig[cdi] = @intCast(cv % 10 + '0');
                        cv /= 10;
                    }
                }
                while (cdi > 0) {
                    cdi -= 1;
                    json_buf[pos] = cdig[cdi];
                    pos += 1;
                }
            }
            json_buf[pos] = '}';
            pos += 1;
        }
        json_buf[pos] = ']';
        pos += 1;
    }

    json_buf[pos] = '}';
    pos += 1;

    if (workspace_filter != null and !sessionFileIsValid(json_buf[0..pos])) return false;
    const ok = writeFileAtomicW(path, json_buf[0..pos]);
    if (workspace_filter == null) debugLog2("saveSession: ", json_buf[0..pos]);
    return ok;
}

pub fn saveSession() void {
    @import("launch_cache.zig").changed();
    if (@import("launch_cache.zig").pending) return;
    if (app_state.g_account_locked or app_state.g_restoring) return;
    logSessionAudit("saveSession:before-write");
    var path_buf: [512]u8 = undefined;
    const path = getSessionPath(&path_buf) orelse return;
    if (saveSessionTo(path, null)) publishSessionLayout();
}

pub fn preserveFailedRemoteSavedTab(tab: *const SavedTab) ?u32 {
    if (findLocalTmuxTab(tab.tmux_host, tab.tmux_session[0..tab.tmux_session_len])) |existing| return existing;
    if (!isRemoteShellKind(tab.kind) or app_state.shell_count >= MAX_SHELLS) return null;

    const idx = app_state.shell_count;
    var shell = empty_shell;
    shell.kind = tab.kind;
    shell.shell_id = app_state.allocateShellId() orelse return null;
    shell.wake_id = tab.wake_id;
    shell.chat_id = tab.chat_id;
    for (0..tab.name_len) |j| shell.name[j] = @intCast(tab.name[j]);
    shell.name_len = tab.name_len;
    shell.name_source = if (tab.manual) .manual else if (tab.sem) .semantic else .default;
    if (tab.tmux_session_len > 0) {
        @memcpy(shell.tmux_session[0..tab.tmux_session_len], tab.tmux_session[0..tab.tmux_session_len]);
        shell.tmux_session_len = tab.tmux_session_len;
        shell.ssh_reconnect.restored_session = tab.kind == .tmux;
    }
    if (tab.cwd_len > 0) {
        @memcpy(shell.cached_cwd[0..tab.cwd_len], tab.cwd[0..tab.cwd_len]);
        shell.cached_cwd_len = tab.cwd_len;
    }
    shell.muted = tab.muted;
    shell.sync_owned = tab.sync_owned;
    shell.keep_alive = tab.keep_alive;
    shell.pinned_top = tab.pinned_top;
    shell.inbox_excluded = tab.inbox_excluded;
    shell.locked = tab.locked;
    shell.favorite = tab.favorite;
    shell.last_used = tab.last_used;
    shell.input = tab.input;
    shell.visits = tab.visits;
    shell.claude_session = tab.claude_session;
    shell.group_id = tab.group_id;
    shell.tmux_host = tab.tmux_host;
    shell.workspace = tab.workspace;
    shell.last_active = if (tab.last_active != 0) tab.last_active else nowFileTime();
    shell.last_viewed = tab.last_viewed;
    shell.inbox_archived = tab.inbox_archived;
    restoreArchiveMarkers(&shell, tab);
    shell.needs_attention = tab.needs_attention;
    if (tab.claude_sid_len > 0) {
        @memcpy(shell.claude_sid[0..tab.claude_sid_len], tab.claude_sid[0..tab.claude_sid_len]);
        shell.claude_sid_len = tab.claude_sid_len;
        shell.ai_agent = 1;
    }
    if (tab.claude_sid_len > 0) shell.hook_capable = true;
    if (shell.needs_attention) {
        shell.last_blue_dot_source = .restore;
        shell.last_blue_dot_time = nowFileTime();
        var name_utf8: [192]u8 = undefined;
        debugLog2("blue dot source=restore tab=", json_reader.utf8(tab.name[0..tab.name_len], &name_utf8));
    }
    if (tab.claude_cwd_len > 0) {
        @memcpy(shell.claude_cwd[0..tab.claude_cwd_len], tab.claude_cwd[0..tab.claude_cwd_len]);
        shell.claude_cwd_len = tab.claude_cwd_len;
    }
    if (tab.favicon_path_len > 0) {
        @memcpy(shell.favicon_path[0..tab.favicon_path_len], tab.favicon_path[0..tab.favicon_path_len]);
        shell.favicon_path_len = tab.favicon_path_len;
    }
    app_state.shells[idx] = shell;
    restoreBrowserStateFromSavedTab(idx, tab);
    app_state.shell_count += 1;
    if (app_state.g_restoring) {
        @import("chat_send.zig").sshDisconnect(idx, "restore-pending");
    } else {
        @import("chat_send.zig").sshDisconnect(idx, "restore-spawn-failed");
    }
    var name_utf8: [192]u8 = undefined;
    debugLog2("restoreSession: preserved failed remote tab: ", json_reader.utf8(tab.name[0..tab.name_len], &name_utf8));
    return idx;
}

pub fn logSavedTabsAudit(reason: []const u8, tabs: []const SavedTab) void {
    const h = openSessionAudit() orelse return;
    defer _ = CloseHandle(h);

    writeAuditHeader(h, reason, @intCast(tabs.len));
    const kind_names = [_][]const u8{ "cmd", "pwsh", "vps", "tmux", "vps2", "bash", "gitbash" };
    for (tabs, 0..) |tab, i| {
        win32WriteAll(h, "  saved_tab=");
        writeAuditU64(h, i);
        win32WriteAll(h, " kind=");
        writeAuditEscapedBytes(h, kind_names[@intFromEnum(tab.kind)]);
        win32WriteAll(h, " host=");
        const host: ?u8 = switch (tab.kind) {
            .vps => TMUX_HOST_DE,
            .vps2 => TMUX_HOST_UK,
            .tmux => tab.tmux_host,
            else => null,
        };
        if (host) |remote_host| {
            win32WriteAll(h, tmuxHostLongLabel(remote_host));
        } else {
            win32WriteAll(h, "-");
        }
        win32WriteAll(h, " pid=");
        writeAuditU64(h, tab.pid);
        win32WriteAll(h, " keep_alive=");
        win32WriteAll(h, if (tab.keep_alive) "1" else "0");
        win32WriteAll(h, " muted=");
        win32WriteAll(h, if (tab.muted) "1" else "0");
        win32WriteAll(h, " manual=");
        win32WriteAll(h, if (tab.manual) "1" else "0");
        win32WriteAll(h, " sem=");
        win32WriteAll(h, if (tab.sem) "1" else "0");
        win32WriteAll(h, " name=\"");
        writeAuditEscapedWideAscii(h, tab.name[0..tab.name_len]);
        win32WriteAll(h, "\" tmux=\"");
        writeAuditEscapedBytes(h, tab.tmux_session[0..tab.tmux_session_len]);
        win32WriteAll(h, "\" cwd=\"");
        writeAuditEscapedBytes(h, tab.cwd[0..tab.cwd_len]);
        win32WriteAll(h, "\"\n");
    }
}

pub fn parseSessionTabs(json: []const u8, tabs: *[MAX_SHELLS]SavedTab) u32 {
    var parsed = json_reader.parse(std.heap.page_allocator, json) catch return 0;
    defer parsed.deinit();
    return json_reader.sessionTabs(parsed.value, tabs[0..], MAX_LWS);
}

pub fn restoreBrowserStateFromSavedTab(idx: u32, tab: *const SavedTab) void {
    if (idx >= app_state.shell_count) return;
    app_state.shells[idx].inbox_archived = tab.inbox_archived;
    app_state.shells[idx].inbox_excluded = tab.inbox_excluded;
    restoreArchiveMarkers(&app_state.shells[idx], tab);
    app_state.shells[idx].keep_awake = tab.kaw;
    app_state.shells[idx].chat_view_on = tab.cv;
    if (app_state.ISSUE_373_SHELL_OVERRIDE) app_state.shells[idx].chat_shell_override = tab.cso;
    if (app_state.ISSUE_347_KEEP_FULL_WIDTH) app_state.shells[idx].full_width = tab.fw;
    if (tab.burl_len > 0) {
        @memcpy(app_state.shells[idx].browser_url[0..tab.burl_len], tab.burl[0..tab.burl_len]);
        app_state.shells[idx].browser_url_len = tab.burl_len;
    }
    app_state.shells[idx].browser_native = tab.bnat;
    app_state.shells[idx].browser_split_permille = tab.bsplit_permille;
    const old_real_page = tab.burl_len > 0 and browserUrlIsRealPage(tab.burl[0..tab.burl_len]);
    if (tab.bon or old_real_page) {
        if (app_state.shells[idx].browser_url_len == 0) ensureBrowserDefaultUrl(idx);
        app_state.shells[idx].browser_enabled = true;
    }
}

pub fn sessionFileIsValid(json: []const u8) bool {
    var parsed = std.json.parseFromSlice(std.json.Value, std.heap.page_allocator, json, .{}) catch return false;
    defer parsed.deinit();
    if (parsed.value != .object) return false;
    const tabs = parsed.value.object.get("tabs") orelse return false;
    if (tabs != .array) return false;
    for (tabs.array.items) |tab| {
        if (tab != .object) return false;
        const kind = tab.object.get("kind") orelse return false;
        if (kind != .string) return false;
    }
    return true;
}

test "session validation accepts standalone exports and rejects partial documents" {
    try std.testing.expect(sessionFileIsValid("{\"tabs\":[],\"workspace_count\":1,\"workspaces\":[{\"name\":\"Empty\",\"wid\":\"qa\"}]}"));
    try std.testing.expect(sessionFileIsValid("{\"tabs\":[{\"kind\":\"cmd\",\"name\":\"Saved\"}],\"groups\":[{\"id\":1,\"name\":\"Dev\"}]}"));
    try std.testing.expect(sessionFileIsValid("{\"tabs\":[],\"hide_pills\":false}"));
    for ([_][]const u8{ "{\"tabs\":[{\"kind\":\"cmd\"}", "{\"tabs\":[],\"hide_pills\":false,}", "{\"tabs\":{}}", "{\"tabs\":[null]}", "{\"tabs\":[{}]}", "{}", "[]" }) |bad| {
        try std.testing.expect(!sessionFileIsValid(bad));
    }
}

test "session IDs before names and nested fields stay attached to their own tab" {
    const json = "{\"extra\":{\"tabs\":[{\"kind\":\"cmd\",\"name\":\"Ignore\"}]},\"tabs\":[{\"kind\":\"tmux\",\"csid\":\"correct\",\"ccwd\":\"/repo/日\",\"name\":\"Literal \\\"csid\\\":\\\"x\\\" } \\u65e5\\ud83d\\ude80\",\"extra\":{\"csid\":\"wrong\",\"favorite\":true}},{\"kind\":\"cmd\",\"name\":\"Old\"}]}";
    var tabs: [MAX_SHELLS]SavedTab = undefined;
    try std.testing.expectEqual(@as(u32, 2), parseSessionTabs(json, &tabs));
    try std.testing.expectEqualStrings("correct", tabs[0].claude_sid[0..tabs[0].claude_sid_len]);
    try std.testing.expectEqualStrings("/repo/日", tabs[0].claude_cwd[0..tabs[0].claude_cwd_len]);
    try std.testing.expect(!tabs[0].favorite and !tabs[1].bon and tabs[1].bnat);
    const expected = std.unicode.utf8ToUtf16LeStringLiteral("Literal \"csid\":\"x\" } 日🚀");
    try std.testing.expectEqualSlices(u16, expected, tabs[0].name[0..tabs[0].name_len]);
}

test "JSON byte writer escapes every control character without changing valid bytes" {
    var out: [256]u8 = undefined;
    out[0] = '"';
    var pos: usize = 1;
    const text = "quote \" \\ café\n\r\t\x00\x08\x0c\x1f";
    appendJsonEscaped(&out, &pos, text);
    out[pos] = '"';
    pos += 1;
    var parsed = try json_reader.parse(std.testing.allocator, out[0..pos]);
    defer parsed.deinit();
    try std.testing.expectEqualStrings(text, json_reader.string(parsed.value).?);
}

test "theme and capacity values ignore nested decoys and preserve absent fallbacks" {
    var parsed = try json_reader.parse(std.testing.allocator, "{\"extra\":{\"title_height\":99,\"amber_load_percent\":1},\"fonts\":{\"title_font\":\"日 Font\",\"title_height\":-12},\"colors\":{\"text\":\"#abcdef\"},\"amber_load_percent\":0}");
    defer parsed.deinit();
    var height: i32 = 20;
    parseThemeIntField(parsed.value, "title_height", &height);
    try std.testing.expectEqual(@as(i32, -12), height);
    parseThemeIntField(parsed.value, "missing", &height);
    try std.testing.expectEqual(@as(i32, -12), height);
    var font: [64]u16 = undefined;
    parseThemeFontField(parsed.value, "title_font", &font);
    try std.testing.expectEqual(@as(u16, 0x65e5), font[0]);
    try std.testing.expectEqual(@as(u64, 75), capacityJsonValue(parsed.value, "amber_load_percent", 75, 10, 1000));
    try std.testing.expectEqual(@as(u64, 8), capacityJsonValue(parsed.value, "missing", 8, 1, 128));
}

test "snapshot wake IDs are parsed per tab independently of changing names" {
    var tabs: [MAX_SHELLS]SavedTab = undefined;
    const json = "{\"tabs\":[{\"kind\":\"cmd\",\"name\":\"Renamed\",\"wake_id\":1},{\"kind\":\"cmd\",\"name\":\"Renamed\",\"wake_id\":2}]}";
    try std.testing.expectEqual(@as(u32, 2), parseSessionTabs(json, &tabs));
    try std.testing.expectEqual(@as(u32, 1), tabs[0].wake_id);
    try std.testing.expectEqual(@as(u32, 2), tabs[1].wake_id);
}

test "favorite JSON flag is scoped to its own saved tab and defaults off" {
    var tabs: [MAX_SHELLS]SavedTab = undefined;
    const json = "{\"tabs\":[{\"kind\":\"cmd\",\"name\":\"Starred\",\"favorite\":true},{\"kind\":\"cmd\",\"name\":\"Old\"},{\"kind\":\"cmd\",\"name\":\"Unstarred\",\"favorite\":false}]}";
    try std.testing.expectEqual(@as(u32, 3), parseSessionTabs(json, &tabs));
    try std.testing.expect(tabs[0].favorite);
    try std.testing.expect(!tabs[1].favorite);
    try std.testing.expect(!tabs[2].favorite);
}

test "ISSUE-373 shell override survives session write, parse and restore with legacy defaults" {
    var tabs: [MAX_SHELLS]SavedTab = undefined;
    try std.testing.expectEqual(@as(u32, 3), parseSessionTabs(@embedFile("fixtures/json-reader/session-shell-override.json"), &tabs));
    try std.testing.expect(tabs[0].cso);
    try std.testing.expect(!tabs[1].cso);
    try std.testing.expect(!tabs[2].cso);
    const saved_count = app_state.shell_count;
    const saved_shells = app_state.shells[0..3].*;
    defer {
        app_state.shells[0..3].* = saved_shells;
        app_state.shell_count = saved_count;
    }
    app_state.shell_count = 3;
    for (0..3) |i| {
        app_state.shells[i] = empty_shell;
        app_state.shells[i].kind = .tmux;
        app_state.shells[i].chat_shell_override = true;
        restoreBrowserStateFromSavedTab(@intCast(i), &tabs[i]);
    }
    try std.testing.expect(app_state.shells[0].chat_shell_override);
    try std.testing.expect(app_state.shells[0].chat_view_on);
    try std.testing.expect(!app_state.shells[1].chat_shell_override);
    try std.testing.expect(!app_state.shells[2].chat_shell_override);
    var temp: [512]u8 = undefined;
    const temp_len = GetEnvironmentVariableA("TEMP", &temp, temp.len);
    try std.testing.expect(temp_len > 0 and temp_len < temp.len);
    var path_buf: [600]u8 = undefined;
    const path = try std.fmt.bufPrint(&path_buf, "{s}\\issue-373-{d}-{d}.json", .{ temp[0..temp_len], @import("win32.zig").GetCurrentProcessId(), GetTickCount64() });
    defer {
        for ([_][]const u8{ "", ".tmp", ".bak" }) |suffix| {
            var clean_buf: [640]u8 = undefined;
            const clean = std.fmt.bufPrint(&clean_buf, "{s}{s}", .{ path, suffix }) catch unreachable;
            var wide: [640]u16 = undefined;
            const wp = @import("file_io.zig").win32WidePath(&wide, clean).?;
            _ = @import("win32.zig").DeleteFileW(wp.ptr);
        }
    }
    try std.testing.expect(saveSessionTo(path, 0));
    const bytes = @import("file_io.zig").readFileAllocWin32(path, SESSION_JSON_CAPACITY) orelse return error.TestUnexpectedResult;
    defer std.heap.page_allocator.free(bytes);
    try std.testing.expect(std.mem.indexOf(u8, bytes, "\"cso\":true") != null);
    try std.testing.expectEqual(@as(u32, 3), parseSessionTabs(bytes, &tabs));
    try std.testing.expect(tabs[0].cso);
    try std.testing.expect(!tabs[1].cso);
    try std.testing.expect(!tabs[2].cso);
}

test "full width JSON flag is scoped to its own saved tab, defaults off and restores onto the shell" {
    var tabs: [MAX_SHELLS]SavedTab = undefined;
    const json = "{\"tabs\":[{\"kind\":\"cmd\",\"name\":\"btop\",\"fw\":true},{\"kind\":\"cmd\",\"name\":\"Old\"},{\"kind\":\"cmd\",\"name\":\"Narrow\",\"fw\":false}]}";
    try std.testing.expectEqual(@as(u32, 3), parseSessionTabs(json, &tabs));
    try std.testing.expect(tabs[0].fw);
    try std.testing.expect(!tabs[1].fw);
    try std.testing.expect(!tabs[2].fw);
    const saved_count = app_state.shell_count;
    const saved_shells = app_state.shells[0..2].*;
    defer {
        app_state.shells[0..2].* = saved_shells;
        app_state.shell_count = saved_count;
    }
    app_state.shells[0] = empty_shell;
    app_state.shells[1] = empty_shell;
    app_state.shells[1].full_width = true;
    app_state.shell_count = 2;
    restoreBrowserStateFromSavedTab(0, &tabs[0]);
    restoreBrowserStateFromSavedTab(1, &tabs[1]);
    try std.testing.expect(app_state.shells[0].full_width);
    try std.testing.expect(!app_state.shells[1].full_width);
}

test "inbox exclusion parses only for its own saved tab and defaults off" {
    var tabs: [MAX_SHELLS]SavedTab = undefined;
    const json = "{\"tabs\":[{\"kind\":\"cmd\",\"name\":\"Hidden\",\"inbox_excluded\":true},{\"kind\":\"cmd\",\"name\":\"Visible\"}]}";
    try std.testing.expectEqual(@as(u32, 2), parseSessionTabs(json, &tabs));
    try std.testing.expect(tabs[0].inbox_excluded);
    try std.testing.expect(!tabs[1].inbox_excluded);
}

test "inbox exclusion keeps the tab's attention and activity untouched" {
    var shell = empty_shell;
    shell.needs_attention = true;
    shell.activity = .active;
    shell.eta_deadline_tick = 12345;
    try std.testing.expect(inboxPublishesShell(&shell));
    shell.inbox_excluded = true;
    try std.testing.expect(!inboxPublishesShell(&shell));
    try std.testing.expect(shell.needs_attention);
    try std.testing.expectEqual(ShellActivity.active, shell.activity);
    try std.testing.expectEqual(@as(u64, 12345), shell.eta_deadline_tick);
    shell.inbox_excluded = false;
    try std.testing.expect(inboxPublishesShell(&shell));
    shell.inbox_archived = true;
    shell.needs_attention = false;
    try std.testing.expect(!inboxPublishesShell(&shell));
}

test "session names serialize localized text without invalid UTF-8 bytes" {
    var escaped: [64]u8 = undefined;
    var escaped_len: usize = 0;
    const localized = [_]u16{ '3', ' ', 'K', 'r', 'a', 'k', 0x00F3, 'w' };
    appendJsonEscapedWide(&escaped, &escaped_len, &localized);
    try std.testing.expectEqualStrings("3 Krak\\u00F3w", escaped[0..escaped_len]);

    var document: [128]u8 = undefined;
    const json = try std.fmt.bufPrint(&document, "{{\"tabs\":[{{\"kind\":\"vps\",\"name\":\"{s}\"}}]}}", .{escaped[0..escaped_len]});
    try std.testing.expect(sessionFileIsValid(json));
    var tabs: [MAX_SHELLS]SavedTab = undefined;
    try std.testing.expectEqual(@as(u32, 1), parseSessionTabs(json, &tabs));
    try std.testing.expectEqual(@as(u16, 0xF3), tabs[0].name[6]);
}

pub fn spawnSavedTab(tab: *const SavedTab, claude_resume: workspace_snooze.ClaudeResume) bool {
    if (findLocalTmuxTab(tab.tmux_host, tab.tmux_session[0..tab.tmux_session_len])) |existing| {
        if (!app_state.g_restoring) switchToShell(existing);
        return false;
    }
    const tabs = [_]SavedTab{tab.*};
    const t: usize = 0;
    const tmux_name: ?[]const u8 = if (tabs[t].kind == .tmux and tabs[t].tmux_session_len > 0)
        tabs[t].tmux_session[0..tabs[t].tmux_session_len]
    else
        null;

    const tab_cwd: ?[]const u8 = if (tabs[t].cwd_len > 0) tabs[t].cwd[0..tabs[t].cwd_len] else if (tabs[t].claude_session and tabs[t].claude_cwd_len > 0) tabs[t].claude_cwd[0..tabs[t].claude_cwd_len] else null;
    var claude_cmd_buf: [1024]u8 = undefined;
    var cd_buf: [512]u8 = undefined;
    var startup_cmd: ?[]const u8 = null;
    if (tabs[t].claude_session) {
        const sid = tabs[t].claude_sid[0..tabs[t].claude_sid_len];
        const mode = claude_resume;
        const prefix: []const u8 = if (tab_cwd) |cwd|
            std.fmt.bufPrint(&cd_buf, "cd /d \"{s}\" && claude", .{cwd}) catch "claude"
        else
            "claude";
        startup_cmd = switch (mode) {
            .exact => std.fmt.bufPrint(&claude_cmd_buf, "{s} --resume {s} --dangerously-skip-permissions", .{ prefix, sid }) catch null,
            .continue_latest => std.fmt.bufPrint(&claude_cmd_buf, "{s} --continue --dangerously-skip-permissions", .{prefix}) catch null,
            .fresh => std.fmt.bufPrint(&claude_cmd_buf, "{s} --dangerously-skip-permissions", .{prefix}) catch null,
        };
    }

    if (!@import("launch_cache.zig").pending) {
        const kind_names = [_][]const u8{ "cmd", "pwsh", "vps", "tmux", "vps2", "bash", "gitbash" };
        debugLog2("restoreSession: kind=", kind_names[@intFromEnum(tabs[t].kind)]);
        if (tab_cwd) |cwd| {
            debugLog2("restoreSession: cwd=", cwd);
        } else {
            debugLog("restoreSession: cwd=<none>");
        }
        if (startup_cmd) |cmd| {
            debugLog2("restoreSession: startup_cmd=", cmd);
        }
    }

    var reclaimed = false;
    if (tabs[t].keep_alive and tabs[t].pid != 0) {
        if (reclaimShell(tabs[t].pid, tabs[t].kind)) {
            debugLog("restoreSession: reclaimed keep-alive shell");
            reclaimed = true;
        } else {
            debugLog("restoreSession: keep-alive reclaim failed, spawning fresh");
        }
    }

    app_state.g_pending_tmux_host = tabs[t].tmux_host;
    defer app_state.g_pending_tmux_host = 0;
    const ok = if (reclaimed)
        true
    else if (app_state.g_restoring and isRemoteShellKind(tabs[t].kind))
        preserveFailedRemoteSavedTab(tab) != null
    else if (tmux_name != null)
        spawnShellWithSession(tabs[t].kind, tmux_name, null, null)
    else
        spawnShellWithSession(tabs[t].kind, null, tab_cwd, startup_cmd);

    if (!ok) return false;
    const idx = app_state.shell_count - 1;
    for (0..tabs[t].name_len) |j| {
        app_state.shells[idx].name[j] = @intCast(tabs[t].name[j]);
    }
    app_state.shells[idx].name[tabs[t].name_len] = 0;
    app_state.shells[idx].name_len = tabs[t].name_len;
    app_state.shells[idx].name_source = if (tabs[t].manual) .manual else if (tabs[t].sem) .semantic else .default;
    if ((tabs[t].kind == .vps or tabs[t].kind == .vps2) and tabs[t].tmux_session_len == 0 and app_state.shells[idx].name_source == .semantic) {
        app_state.shells[idx].name_source = .default;
    }
    app_state.shells[idx].tmux_host = tabs[t].tmux_host;
    if (tabs[t].tmux_session_len > 0) {
        @memcpy(app_state.shells[idx].tmux_session[0..tabs[t].tmux_session_len], tabs[t].tmux_session[0..tabs[t].tmux_session_len]);
        app_state.shells[idx].tmux_session_len = tabs[t].tmux_session_len;
    }
    if (tabs[t].cwd_len > 0) {
        @memcpy(app_state.shells[idx].cached_cwd[0..tabs[t].cwd_len], tabs[t].cwd[0..tabs[t].cwd_len]);
        app_state.shells[idx].cached_cwd_len = tabs[t].cwd_len;
    }
    app_state.shells[idx].muted = tabs[t].muted;
    app_state.shells[idx].sync_owned = tabs[t].sync_owned;
    app_state.shells[idx].keep_alive = tabs[t].keep_alive;
    app_state.shells[idx].pinned_top = tabs[t].pinned_top;
    app_state.shells[idx].inbox_excluded = tabs[t].inbox_excluded;
    app_state.shells[idx].locked = tabs[t].locked;
    app_state.shells[idx].favorite = tabs[t].favorite;
    app_state.shells[idx].last_used = tabs[t].last_used;
    app_state.shells[idx].input = tabs[t].input;
    app_state.shells[idx].visits = tabs[t].visits;
    app_state.shells[idx].claude_session = tabs[t].claude_session;
    app_state.shells[idx].wake_id = tabs[t].wake_id;
    app_state.shells[idx].chat_id = tabs[t].chat_id;
    app_state.shells[idx].group_id = tabs[t].group_id;
    app_state.shells[idx].workspace = tabs[t].workspace;
    app_state.shells[idx].last_active = if (tabs[t].last_active != 0) tabs[t].last_active else nowFileTime();
    app_state.shells[idx].last_viewed = tabs[t].last_viewed;
    app_state.shells[idx].activity = .idle;
    app_state.shells[idx].needs_attention = tabs[t].needs_attention;
    app_state.shells[idx].last_active_event = 0;
    if (tabs[t].claude_sid_len > 0) {
        @memcpy(app_state.shells[idx].claude_sid[0..tabs[t].claude_sid_len], tabs[t].claude_sid[0..tabs[t].claude_sid_len]);
        app_state.shells[idx].claude_sid_len = tabs[t].claude_sid_len;
        app_state.shells[idx].ai_agent = 1;
        app_state.shells[idx].hook_capable = true;
    }
    noteRestoredBlueDot(idx);
    if (tabs[t].claude_cwd_len > 0) {
        @memcpy(app_state.shells[idx].claude_cwd[0..tabs[t].claude_cwd_len], tabs[t].claude_cwd[0..tabs[t].claude_cwd_len]);
        app_state.shells[idx].claude_cwd_len = tabs[t].claude_cwd_len;
    }
    restoreBrowserStateFromSavedTab(@intCast(idx), &tabs[t]);
    if (tabs[t].favicon_path_len > 0 and tabs[t].favicon_path_len < 512) {
        var fav_wpath: [512]u16 = undefined;
        for (0..tabs[t].favicon_path_len) |pi| fav_wpath[pi] = @as(u16, tabs[t].favicon_path[pi]);
        fav_wpath[tabs[t].favicon_path_len] = 0;
        const INVALID_FA: DWORD = 0xFFFFFFFF;
        if (GetFileAttributesW(@ptrCast(&fav_wpath)) != INVALID_FA) {
            const LR_LOADFROMFILE_R: UINT = 0x00000010;
            const LR_DEFAULTSIZE_R: UINT = 0x00000040;
            const hico = LoadImageW(null, @ptrCast(&fav_wpath), IMAGE_ICON, 16, 16, LR_LOADFROMFILE_R | LR_DEFAULTSIZE_R);
            if (hico != null) {
                app_state.shells[idx].favicon_hicon = hico;
                @memcpy(app_state.shells[idx].favicon_path[0..tabs[t].favicon_path_len], tabs[t].favicon_path[0..tabs[t].favicon_path_len]);
                app_state.shells[idx].favicon_path_len = tabs[t].favicon_path_len;
            }
        }
    }
    if (tabs[t].muted) {
        var name_utf8: [192]u8 = undefined;
        debugLog2("restoreSession: restored MUTED tab: ", json_reader.utf8(tabs[t].name[0..tabs[t].name_len], &name_utf8));
    }
    return true;
}

fn seedActiveWorkspaceLastShell(shells: []const app_state.Shell, active_shell: u32, last_shell: []u32) void {
    if (active_shell >= shells.len) return;
    const shell = shells[active_shell];
    if (last_shell[shell.workspace] == 0) last_shell[shell.workspace] = shell.shell_id;
}

test "ISSUE-439 restore seeds missing active workspace memory without replacing saved choices" {
    var shells = [_]app_state.Shell{ empty_shell, empty_shell, empty_shell };
    shells[0].workspace = 1;
    shells[0].shell_id = 41;
    shells[0].last_active = 10;
    shells[1].workspace = 1;
    shells[1].shell_id = 99;
    shells[1].last_active = 1000;
    shells[2].workspace = 0;
    shells[2].shell_id = 42;
    var last_shell = [_]u32{0} ** MAX_LWS;

    seedActiveWorkspaceLastShell(&shells, shells.len, &last_shell);
    seedActiveWorkspaceLastShell(shells[0..0], 0, &last_shell);
    try std.testing.expectEqual(@as(u32, 0), last_shell[1]);

    seedActiveWorkspaceLastShell(&shells, 0, &last_shell);
    try std.testing.expectEqual(@as(u32, 41), last_shell[1]);
    try std.testing.expectEqual(@as(u32, 0), last_shell[0]);
    try std.testing.expectEqual(@as(?u32, 0), @import("workspaces.zig").pickWorkspaceTarget(&shells, 1, last_shell[1]));

    seedActiveWorkspaceLastShell(&shells, 2, &last_shell);
    try std.testing.expectEqual(@as(u32, 42), last_shell[0]);
    seedActiveWorkspaceLastShell(&shells, 1, &last_shell);
    try std.testing.expectEqual(@as(u32, 41), last_shell[1]);
}

var startup_bytes: ?[]u8 = null;
var startup_parsed: ?std.json.Parsed(std.json.Value) = null;
var startup_ready = std.atomic.Value(bool).init(false);

pub fn prepareStartupRestore() bool {
    var path_buf: [512]u8 = @splat(0);
    const path = getSessionPath(&path_buf) orelse return false;
    const len = if (app_state.g_empty_workspace or app_state.g_adopt_hwnd != null) 0 else path.len;
    const thread = std.Thread.spawn(.{}, startupRestoreWorker, .{ path_buf, len }) catch return false;
    thread.detach();
    return true;
}

fn startupRestoreWorker(path_buf: [512]u8, len: usize) void {
    _ = @import("console.zig").resolveSshPath(false);
    startup_bytes = if (len == 0) null else readSessionBytes(path_buf[0..len]);
    if (startup_bytes) |bytes| {
        startup_parsed = json_reader.parse(std.heap.page_allocator, bytes) catch null;
        if (startup_parsed) |parsed| {
            const tabs = std.heap.page_allocator.alloc(SavedTab, MAX_SHELLS) catch {
                startup_ready.store(true, .release);
                return;
            };
            defer std.heap.page_allocator.free(tabs);
            const count = json_reader.sessionTabs(parsed.value, tabs, MAX_LWS);
            for (tabs[0..count]) |tab| {
                if (tab.pid == 0 or tab.keep_alive) continue;
                const orphan = OpenProcess(PROCESS_TERMINATE, 0, tab.pid) orelse continue;
                defer _ = CloseHandle(orphan);
                var exit_code: DWORD = 0;
                if (GetExitCodeProcess(orphan, &exit_code) != 0 and exit_code == STILL_ACTIVE) killProcessTree(tab.pid);
            }
        }
    }
    startup_ready.store(true, .release);
}

pub fn startupRestoreReady() bool {
    return startup_ready.load(.acquire);
}

fn readSessionBytes(path: []const u8) ?[]u8 {
    const json_buf = std.heap.page_allocator.alloc(u8, SESSION_JSON_CAPACITY) catch return null;
    defer std.heap.page_allocator.free(json_buf);
    var json_len: usize = 0;
    {
        const h = win32OpenRead(path) orelse {
            debugLog("restoreSession:no-session-file");
            return null;
        };
        json_len = win32ReadAll(h, json_buf);
        _ = CloseHandle(h);
    }
    if (json_len == 0) {
        debugLog("restoreSession:empty-session-file");
        return null;
    }

    if (!sessionFileIsValid(json_buf[0..json_len])) {
        var arch_buf: [540]u8 = undefined;
        const arch_path = std.fmt.bufPrint(&arch_buf, "{s}.corrupt-{d}", .{ path, GetTickCount64() }) catch "";
        if (arch_path.len > 0) _ = win32MovePath(path, arch_path);
        debugLog("restoreSession:corrupt-main-archived-trying-bak");
        debugLog("restoreSession: main session file failed validity check — archived, trying .bak");
        var bak_pbuf: [520]u8 = undefined;
        const bak_path_str = std.fmt.bufPrint(&bak_pbuf, "{s}.bak", .{path}) catch "";
        json_len = 0;
        if (bak_path_str.len > 0) {
            if (win32OpenRead(bak_path_str)) |bh| {
                json_len = win32ReadAll(bh, json_buf);
                _ = CloseHandle(bh);
            }
        }
        if (json_len == 0 or !sessionFileIsValid(json_buf[0..json_len])) {
            debugLog("restoreSession:corrupt-main-and-bak-zero-tabs");
            debugLog("restoreSession: .bak also invalid or missing — starting with zero tabs");
            return null;
        }
        debugLog("restoreSession:restored-from-bak");
        debugLog("restoreSession: successfully restored from .bak");
    }

    return std.heap.page_allocator.dupe(u8, json_buf[0..json_len]) catch null;
}

pub fn restoreSession() u32 {
    if (app_state.g_account_locked) return 0;
    app_state.g_restored_valid_session = false;
    app_state.g_restoring = true;
    defer {
        if (!@import("launch_cache.zig").pending) logSessionAudit("restoreSession:after-spawn-before-save");
        ensureOtherWorkspaceSlot();
        app_state.g_restoring = false;
        saveSession();
    }
    var path_buf: [512]u8 = undefined;
    const path = getSessionPath(&path_buf) orelse {
        logSessionAudit("restoreSession:no-session-path");
        return 0;
    };

    const json_buf = if (@import("launch_cache.zig").pending and startupRestoreReady()) ready: {
        const bytes = startup_bytes;
        startup_bytes = null;
        break :ready bytes;
    } else readSessionBytes(path);
    const bytes = json_buf orelse return 0;
    defer std.heap.page_allocator.free(bytes);

    const prepared = @import("launch_cache.zig").pending and startupRestoreReady();
    var parsed = if (prepared) ready: {
        const value = startup_parsed;
        startup_parsed = null;
        break :ready value orelse return 0;
    } else json_reader.parse(std.heap.page_allocator, bytes) catch return 0;
    defer parsed.deinit();
    const json = parsed.value;

    var tabs: [MAX_SHELLS]SavedTab = undefined;
    const tab_count = json_reader.sessionTabs(json, tabs[0..], MAX_LWS);
    app_state.g_restored_valid_session = true;
    var restored_active_tab: ?u32 = null;
    const active = json_reader.uintDefault(json, "active_tab", std.math.maxInt(u32));
    if (active < tab_count) restored_active_tab = @intCast(active);
    if (json_reader.boolTrue(json, "sound_enabled")) app_state.g_sound_enabled = true;
    if (!prepared) {
        loadGlobalTheme();
        loadBrowserEngineConfig();
        loadEdgeProfileConfig();
        loadEdgeExeConfig();
        loadChromeExeConfig();
    }
    if (IS_DEV) {
        ensureDevThemeInitialized();
        app_state.g_dev_font_idx = app_state.DEFAULT_CONSOLE_FONT_IDX;
        setWideAscii(&app_state.g_dev_theme.console_font, DEV_CONSOLE_FONTS[app_state.g_dev_font_idx]);
        const size = json_reader.uint(json, "dev_console_size");
        if (size >= 8 and size <= 40) app_state.g_dev_theme.console_font_height = @intCast(size);
    }
    if (json_reader.boolTrue(json, "mobile_mode")) app_state.g_mobile_mode = true;
    if (json_reader.boolTrue(json, "hide_sidebar")) app_state.g_hide_sidebar = true;
    if (json_reader.boolTrue(json, "sidebar_collapsed")) app_state.g_sidebar_collapsed = true;
    app_state.g_locked_section_collapsed = json_reader.boolTrue(json, "locked_section_collapsed");
    app_state.g_pinned_section_collapsed = json_reader.boolTrue(json, "pinned_section_collapsed");
    app_state.g_recents_section_collapsed = json_reader.boolTrue(json, "recents_section_collapsed");
    if (IS_DEV and json_reader.boolFalse(json, "thread_title")) app_state.g_thread_title = false;
    const console_font = json_reader.uint(json, "console_font_h");
    if (console_font >= 8 and console_font <= 40) app_state.g_console_font_override = @intCast(console_font);
    if (json == .object and json.object.contains("shell_zoom_scale")) app_state.g_console_font_override = 0;
    const chat_font = json_reader.uint(json, "chat_font_pt");
    if (chat_font >= 10 and chat_font <= 28) app_state.g_chat_font_pt = @intCast(chat_font);
    for (0..2) |a| {
        var i: usize = 20;
        while (i > 0) {
            i -= 1;
            var key_buf: [48]u8 = undefined;
            const key = std.fmt.bufPrint(&key_buf, "chat_ac_{s}_{d}", .{ if (a == 0) @as([]const u8, "claude") else "codex", i }) catch continue;
            var name: [201]u8 = .{0} ** 201;
            const n = json_reader.copyString(json, key, &name);
            if (n > 0) chat_complete.promoteRecent(&app_state.g_chat_ac_mru[a], &app_state.g_chat_ac_mru_count[a], name[0..n]);
        }
    }
    const saved_settings = json_reader.field(json, "settings");
    if (saved_settings != .null) {
        const parsed_settings = std.json.parseFromValue(@import("frequent.zig").Settings, std.heap.page_allocator, saved_settings, .{}) catch null;
        if (parsed_settings) |settings| {
            app_state.g_layout_settings = settings.value;
            settings.deinit();
        }
    }
    app_state.g_inbox_tab = @import("frequent.zig").migrateSplit(@intCast(@min(json_reader.uint(json, "inbox_tab"), std.math.maxInt(u32))), json_reader.boolTrue(json, "inbox_visits_order"));
    const chat_mode = json_reader.string(json_reader.field(json, "chat_view_mode")) orelse "";
    if (std.mem.eql(u8, chat_mode, "everywhere")) {
        app_state.g_chat_view_mode = .everywhere;
    } else if (std.mem.eql(u8, chat_mode, "nowhere")) {
        app_state.g_chat_view_mode = .nowhere;
    }
    if (app_state.g_chat_view_mode == .everywhere and json_reader.boolTrue(json, "chat_active")) app_state.g_chat_view_restore_on = true;
    app_state.g_igsh354_paste_focus = !json_reader.boolFalse(json, "igsh354_paste_focus");
    app_state.g_voice_always_listen = !json_reader.boolFalse(json, "voice_always_listen");
    if (json_reader.boolFalse(json, "eta_numbers")) app_state.g_eta_numbers_on = false;
    if (json_reader.boolFalse(json, "eta_progress")) app_state.g_eta_progress_on = false;
    const voice_speed = json_reader.string(json_reader.field(json, "voice_speed")) orelse "";
    if (std.mem.eql(u8, voice_speed, "1.0")) {
        app_state.g_voice_speed = .s100;
    } else if (std.mem.eql(u8, voice_speed, "1.4")) {
        app_state.g_voice_speed = .s140;
    } else if (std.mem.eql(u8, voice_speed, "1.5")) {
        app_state.g_voice_speed = .s150;
    }
    const scale = json_reader.uint(json, "ui_scale");
    if (scale >= 80 and scale <= 150) app_state.g_ui_scale = @intCast(scale);
    const suspend_min = json_reader.uintDefault(json, "browser_suspend_min", std.math.maxInt(u64));
    if (suspend_min == 0) {
        app_state.g_browser_autosuspend = false;
        app_state.g_browser_suspend_min = BROWSER_SUSPEND_DEFAULT_MIN;
    } else if (suspend_min <= 24 * 60) {
        app_state.g_browser_autosuspend = true;
        app_state.g_browser_suspend_min = @intCast(suspend_min);
    }
    app_state.g_hide_pills = json_reader.boolean(json_reader.field(json, "hide_pills"), app_state.g_hide_pills);

    var saved_last_shell: [MAX_LWS]u32 = [_]u32{0} ** MAX_LWS;
    app_state.g_ws_last_shell = [_]u32{0} ** MAX_LWS;
    var restored_active_ws: u8 = 0;
    if (json_reader.boolTrue(json, "single_window")) app_state.g_single_window = true;
    if (app_state.g_single_window) {
        const workspace = json_reader.uint(json, "active_workspace");
        if (workspace < MAX_LWS) restored_active_ws = @intCast(workspace);
        const count = json_reader.uint(json, "workspace_count");
        if (count >= 1 and count <= MAX_LWS) app_state.g_lws_count = @intCast(count);
        for (json_reader.array(json_reader.field(json, "workspaces")), 0..) |obj, wi| {
            if (wi >= MAX_LWS) break;
            app_state.g_ws_name_len[wi] = json_reader.copyString(obj, "name", &app_state.g_ws_names[wi]);
            var wid_tmp: [64]u8 = std.mem.zeroes([64]u8);
            const wid_n = json_reader.copyString(obj, "wid", &wid_tmp);
            const wid_cap = @min(wid_n, @as(u32, @intCast(app_state.g_ws_ids[wi].len)));
            if (wid_cap > 0) @memcpy(app_state.g_ws_ids[wi][0..wid_cap], wid_tmp[0..wid_cap]);
            app_state.g_ws_id_len[wi] = wid_cap;
            app_state.g_ws_snoozed[wi] = json_reader.boolTrue(obj, "snoozed");
            saved_last_shell[wi] = @intCast(@min(json_reader.uint(obj, "last_shell"), std.math.maxInt(u32)));
        }
    }

    if (restored_active_tab) |at| {
        if (at < tab_count) {
            const winner = tmux_identity.restoreWinner(tabs[0..tab_count], at);
            restored_active_tab = @intCast(winner);
            if (app_state.g_single_window and winner != at) app_state.g_active_workspace = tabs[winner].workspace;
        }
    }
    if (!prepared) logSavedTabsAudit("restoreSession:parsed-session-file", tabs[0..tab_count]);

    app_state.group_count = 0;
    app_state.next_group_id = 1;
    for (json_reader.array(json_reader.field(json, "groups"))) |obj| {
        if (app_state.group_count >= MAX_GROUPS) break;
        const gid: u32 = @truncate(json_reader.uint(obj, "id"));
        var gname: [64]u16 = std.mem.zeroes([64]u16);
        const gname_len = json_reader.copyWide(obj, "name", &gname);
        const gcoll = json_reader.boolTrue(obj, "collapsed");
        const gcolor: u8 = @intCast(json_reader.uint(obj, "color") % GROUP_COLORS.len);
        if (gid != 0) {
            app_state.groups[app_state.group_count] = .{ .id = gid, .name = gname, .name_len = gname_len, .collapsed = gcoll, .color = gcolor };
            app_state.group_count += 1;
            if (gid + 1 > app_state.next_group_id) app_state.next_group_id = gid + 1;
        }
    }

    for (0..if (prepared) 0 else tab_count) |t| {
        if (tabs[t].pid != 0 and !tabs[t].keep_alive) {
            const orphan = OpenProcess(PROCESS_TERMINATE, 0, tabs[t].pid);
            if (orphan != null) {
                var exit_code: DWORD = 0;
                if (GetExitCodeProcess(orphan, &exit_code) != 0 and exit_code == STILL_ACTIVE) {
                    debugLog("restoreSession: killing orphan process tree");
                    killProcessTree(tabs[t].pid);
                }
                _ = CloseHandle(orphan);
            }
        }
    }

    debugLog("restoreSession: starting restore");
    var spawned: u32 = 0;
    var restored_active_shell_id: u32 = 0;
    var restored_shell_ids: [MAX_SHELLS]u32 = [_]u32{0} ** MAX_SHELLS;
    for (0..tab_count) |t| {
        if (@import("launch_cache.zig").closedDuringStartup(tabs[t].shell_id)) continue;
        if (tmux_identity.restoreWinner(tabs[0..tab_count], t) != t) continue;
        const ok = if (chatBenchEnabled() and isRemoteShellKind(tabs[t].kind)) false else spawnSavedTab(&tabs[t], .continue_latest);
        if (ok) {
            const idx = app_state.shell_count - 1;
            app_state.active_shell = idx;
            restored_shell_ids[t] = app_state.shells[idx].shell_id;
            if (restored_active_tab != null and restored_active_tab.? == t) {
                restored_active_shell_id = app_state.shells[idx].shell_id;
            }
            spawned += 1;
        } else {
            debugLog("restoreSession: spawn FAILED");
            if (preserveFailedRemoteSavedTab(&tabs[t])) |idx| {
                app_state.active_shell = idx;
                restored_shell_ids[t] = app_state.shells[idx].shell_id;
                if (restored_active_tab != null and restored_active_tab.? == t) {
                    restored_active_shell_id = app_state.shells[idx].shell_id;
                }
                spawned += 1;
            }
        }
    }

    for (tabs[0..tab_count], 0..) |tab, t| {
        if (tab.shell_id != 0 and saved_last_shell[tab.workspace] == tab.shell_id) {
            app_state.g_ws_last_shell[tab.workspace] = restored_shell_ids[tmux_identity.restoreWinner(tabs[0..tab_count], t)];
        }
    }
    if (restored_active_shell_id != 0) {
        if (findShellById(restored_active_shell_id)) |idx| app_state.active_shell = idx;
    }

    for (0..app_state.shell_count) |si| {
        if (app_state.shells[si].group_id != 0 and findGroupIdx(app_state.shells[si].group_id) == null) {
            app_state.shells[si].group_id = 0;
        }
    }
    pruneEmptyGroups();
    normalizeGroupOrder();

    if (app_state.g_single_window) {
        var max_ws: u8 = 0;
        for (0..app_state.shell_count) |si| {
            if (app_state.shells[si].workspace > max_ws) max_ws = app_state.shells[si].workspace;
        }
        if (@as(u32, max_ws) + 1 > app_state.g_lws_count) app_state.g_lws_count = max_ws + 1;
        if (app_state.g_lws_count < 1) app_state.g_lws_count = 1;
        app_state.g_active_workspace = if (restored_active_shell_id != 0 and app_state.active_shell < app_state.shell_count)
            app_state.shells[app_state.active_shell].workspace
        else if (restored_active_ws < app_state.g_lws_count)
            restored_active_ws
        else
            0;
        compactWorkspaceSlots();
        if (restored_active_shell_id == 0) {
            for (0..app_state.shell_count) |si| {
                if (app_state.shells[si].workspace == app_state.g_active_workspace) {
                    app_state.active_shell = @intCast(si);
                    break;
                }
            }
        }
    }

    const selected_shell = @import("launch_cache.zig").selected_shell_id;
    if (@import("launch_cache.zig").pending and selected_shell != 0) {
        for (tabs[0..tab_count], 0..) |tab, t| {
            if (tab.shell_id != selected_shell) continue;
            const restored_id = restored_shell_ids[tmux_identity.restoreWinner(tabs[0..tab_count], t)];
            if (findShellById(restored_id)) |idx| {
                app_state.active_shell = idx;
                app_state.g_active_workspace = app_state.shells[idx].workspace;
            }
            break;
        }
    }
    const selected_live = @import("launch_cache.zig").selected_live_shell_id;
    if (@import("launch_cache.zig").pending and selected_live != 0) {
        if (findShellById(selected_live)) |idx| {
            app_state.active_shell = idx;
            app_state.g_active_workspace = app_state.shells[idx].workspace;
        }
    }
    seedActiveWorkspaceLastShell(app_state.shells[0..app_state.shell_count], app_state.active_shell, &app_state.g_ws_last_shell);

    if (spawned > 0 and app_state.active_shell < app_state.shell_count and app_state.shells[app_state.active_shell].hwnd != null) {
        _ = showShellConsole(app_state.active_shell, SW_SHOW, "restoreSession");
        app_state.g_nudge_repaint = true;
        repositionActive();
        _ = InvalidateRect(app_state.g_main_hwnd, null, 0);
    }

    if (spawned > 0) {
        var lg_buf: [520]u8 = undefined;
        const lg_path = std.fmt.bufPrint(&lg_buf, "{s}.lastgood", .{path}) catch "";
        if (lg_path.len > 0) {
            if (prepared) {
                if (std.heap.page_allocator.dupe(u8, bytes)) |copy| {
                    const thread = std.Thread.spawn(.{}, writeStartupLastgood, .{ lg_buf, lg_path.len, copy }) catch {
                        std.heap.page_allocator.free(copy);
                        return spawned;
                    };
                    thread.detach();
                } else |_| {}
            } else if (win32OpenWrite(lg_path)) |lh| {
                win32WriteAll(lh, bytes);
                _ = CloseHandle(lh);
            }
        }
    }

    return spawned;
}

fn writeStartupLastgood(path_buf: [520]u8, len: usize, bytes: []u8) void {
    defer std.heap.page_allocator.free(bytes);
    const file = win32OpenWrite(path_buf[0..len]) orelse return;
    defer _ = CloseHandle(file);
    win32WriteAll(file, bytes);
}
