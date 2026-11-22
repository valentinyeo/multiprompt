const std = @import("std");
const archive_rules = @import("archive_rules");
const DWORD = u32;
const MAX_SHELLS = 256;
const MAX_LWS = 9;
const BROWSER_SPLIT_DEFAULT_PERMILLE: u16 = 350;
const ShellKind = enum(u3) { cmd, pwsh, vps, tmux, vps2, bash, gitbash };
pub const SavedTab = struct {
    sync_owned: bool = false,
    kind: ShellKind,
    name: [64]u8,
    name_len: u32,
    manual: bool,
    sem: bool,
    tmux_session: [64]u8,
    tmux_session_len: u32,
    cwd: [512]u8,
    cwd_len: u32,
    claude_session: bool,
    wake_id: u32 = 0,
    pid: DWORD,
    muted: bool,
    keep_alive: bool,
    pinned_top: bool = false,
    inbox_excluded: bool = false,
    favorite: bool = false,
    locked: bool = false,
    favicon_path: [512]u8,
    favicon_path_len: u32,
    group_id: u32,
    tmux_host: u8,
    workspace: u8 = 0,
    last_active: u64 = 0,
    last_viewed: u64 = 0,
    claude_sid: [40]u8 = std.mem.zeroes([40]u8),
    claude_sid_len: u32 = 0,
    claude_cwd: [192]u8 = std.mem.zeroes([192]u8),
    claude_cwd_len: u32 = 0,
    bon: bool = false,
    inbox_archived: bool = false,
    archive_time: u64 = 0,
    archive_done: u64 = 0,
    last_done_time: u64 = 0,
    last_done_content: archive_rules.Content = .{},
    last_done_content_valid: bool = false,
    archive_content: archive_rules.Content = .{},
    archive_content_valid: bool = false,
    needs_attention: bool = false,
    burl: [512]u8 = std.mem.zeroes([512]u8),
    burl_len: u32 = 0,
    bnat: bool = true,
    bsplit_permille: u16 = BROWSER_SPLIT_DEFAULT_PERMILLE,
    kaw: bool = false,
    cv: bool = false,
};
fn parseJsonStringField(obj: []const u8, field: []const u8, out: []u8) u32 {
    var key_buf: [80]u8 = undefined;
    var kp: usize = 0;
    key_buf[kp] = '"';
    kp += 1;
    @memcpy(key_buf[kp .. kp + field.len], field);
    kp += field.len;
    key_buf[kp] = '"';
    kp += 1;
    const key = key_buf[0..kp];
    var search_from: usize = 0;
    while (std.mem.indexOfPos(u8, obj, search_from, key)) |at| {
        var p = at + key.len;
        while (p < obj.len and (obj[p] == ' ' or obj[p] == '\n' or obj[p] == '\r' or obj[p] == '\t')) : (p += 1) {}
        if (p >= obj.len or obj[p] != ':') {
            search_from = at + key.len;
            continue;
        }
        p += 1;
        while (p < obj.len and (obj[p] == ' ' or obj[p] == '\n' or obj[p] == '\r' or obj[p] == '\t')) : (p += 1) {}
        if (p >= obj.len or obj[p] != '"') return 0;
        p += 1;
        var n: u32 = 0;
        while (p < obj.len and n < out.len - 1) : (p += 1) {
            if (obj[p] == '\\' and p + 1 < obj.len) {
                out[n] = obj[p + 1];
                n += 1;
                p += 1;
            } else if (obj[p] == '"') {
                break;
            } else {
                out[n] = obj[p];
                n += 1;
            }
        }
        out[n] = 0;
        return n;
    }
    return 0;
}

fn findJsonObjectEndFrom(json: []const u8, inside_pos: usize) ?usize {
    if (inside_pos >= json.len) return null;
    var start = inside_pos;
    while (start > 0) : (start -= 1) {
        if (json[start] == '{') break;
    }
    if (json[start] != '{') return null;

    var depth: u32 = 0;
    var in_string = false;
    var escaped = false;
    var p = start;
    while (p < json.len) : (p += 1) {
        const c = json[p];
        if (in_string) {
            if (escaped) {
                escaped = false;
            } else if (c == '\\') {
                escaped = true;
            } else if (c == '"') {
                in_string = false;
            }
            continue;
        }
        if (c == '"') {
            in_string = true;
        } else if (c == '{') {
            depth += 1;
        } else if (c == '}') {
            if (depth == 0) return null;
            depth -= 1;
            if (depth == 0) return p;
        }
    }
    return null;
}

fn customCmdJsonBoolTrue(obj: []const u8, field: []const u8) bool {
    var key_buf: [80]u8 = undefined;
    var kp: usize = 0;
    key_buf[kp] = '"';
    kp += 1;
    @memcpy(key_buf[kp .. kp + field.len], field);
    kp += field.len;
    key_buf[kp] = '"';
    kp += 1;
    const key = key_buf[0..kp];
    const at = std.mem.indexOf(u8, obj, key) orelse return false;
    var p = at + key.len;
    while (p < obj.len and (obj[p] == ' ' or obj[p] == '\n' or obj[p] == '\r' or obj[p] == '\t')) : (p += 1) {}
    if (p >= obj.len or obj[p] != ':') return false;
    p += 1;
    while (p < obj.len and (obj[p] == ' ' or obj[p] == '\n' or obj[p] == '\r' or obj[p] == '\t')) : (p += 1) {}
    return p + 4 <= obj.len and std.mem.eql(u8, obj[p .. p + 4], "true");
}

fn jsonHexNibble(c: u8) ?u16 {
    if (c >= '0' and c <= '9') return c - '0';
    if (c >= 'a' and c <= 'f') return c - 'a' + 10;
    if (c >= 'A' and c <= 'F') return c - 'A' + 10;
    return null;
}

fn parseJsonUintField(obj: []const u8, field: []const u8) u64 {
    var key_buf: [80]u8 = undefined;
    var kp: usize = 0;
    key_buf[kp] = '"';
    kp += 1;
    @memcpy(key_buf[kp .. kp + field.len], field);
    kp += field.len;
    key_buf[kp] = '"';
    kp += 1;
    const key = key_buf[0..kp];
    const at = std.mem.indexOf(u8, obj, key) orelse return 0;
    var p = at + key.len;
    while (p < obj.len and (obj[p] == ' ' or obj[p] == '\n' or obj[p] == '\r' or obj[p] == '\t')) : (p += 1) {}
    if (p >= obj.len or obj[p] != ':') return 0;
    p += 1;
    while (p < obj.len and (obj[p] == ' ' or obj[p] == '\n' or obj[p] == '\r' or obj[p] == '\t' or obj[p] == '"')) : (p += 1) {}
    var v: u64 = 0;
    while (p < obj.len and obj[p] >= '0' and obj[p] <= '9') : (p += 1) {
        v = v *% 10 +% (obj[p] - '0');
    }
    return v;
}

fn parseArchiveContent(obj: []const u8, pre: []const u8) archive_rules.Content {
    var result = archive_rules.Content{};
    const start = (std.mem.indexOf(u8, obj, pre) orelse return result) + pre.len;
    var p = start;
    while (p + 16 <= obj.len and result.len < result.rows.len) : (p += 16) {
        var row: u64 = 0;
        for (obj[p .. p + 16]) |ch| {
            const nibble: u64 = if (ch >= '0' and ch <= '9') ch - '0' else if (ch >= 'a' and ch <= 'f') ch - 'a' + 10 else return result;
            row = (row << 4) | nibble;
        }
        result.rows[result.len] = row;
        result.len += 1;
    }
    return result;
}

fn clampBrowserSplitPermille(v: u32) u16 {
    if (v < 50) return 50;
    if (v > 950) return 950;
    return @intCast(v);
}

pub fn parseSessionTabs(json: []const u8, tabs: *[MAX_SHELLS]SavedTab) u32 {
    var tab_count: u32 = 0;
    var i: usize = 0;

    while (i < json.len and tab_count < MAX_SHELLS) {
        if (std.mem.indexOfPos(u8, json, i, "\"kind\":\"")) |ki| {
            const kind_start = ki + 8;
            if (std.mem.indexOfPos(u8, json, kind_start, "\"")) |kind_end| {
                const kind_str = json[kind_start..kind_end];
                const kind: ShellKind = if (std.mem.eql(u8, kind_str, "cmd")) .cmd else if (std.mem.eql(u8, kind_str, "pwsh")) .pwsh else if (std.mem.eql(u8, kind_str, "vps")) .vps else if (std.mem.eql(u8, kind_str, "tmux")) .tmux else if (std.mem.eql(u8, kind_str, "vps2")) .vps2 else if (std.mem.eql(u8, kind_str, "bash")) .bash else if (std.mem.eql(u8, kind_str, "gitbash")) .gitbash else .cmd;

                if (std.mem.indexOfPos(u8, json, kind_end, "\"name\":\"")) |ni| {
                    const name_start = ni + 8;
                    var ne = name_start;
                    var name_buf: [64]u8 = std.mem.zeroes([64]u8);
                    var name_len: u32 = 0;
                    while (ne < json.len and name_len < 63) {
                        if (json[ne] == '\\' and ne + 1 < json.len) {
                            if (json[ne + 1] == 'u' and ne + 5 < json.len) {
                                const h0 = jsonHexNibble(json[ne + 2]);
                                const h1 = jsonHexNibble(json[ne + 3]);
                                const h2 = jsonHexNibble(json[ne + 4]);
                                const h3 = jsonHexNibble(json[ne + 5]);
                                if (h0 != null and h1 != null and h2 != null and h3 != null) {
                                    const wc = (h0.? << 12) | (h1.? << 8) | (h2.? << 4) | h3.?;
                                    name_buf[name_len] = if (wc <= 0xFF) @intCast(wc) else '?';
                                    name_len += 1;
                                    ne += 6;
                                    continue;
                                }
                            }
                            name_buf[name_len] = json[ne + 1];
                            name_len += 1;
                            ne += 2;
                        } else if (json[ne] == '"') {
                            break;
                        } else if (json[ne] >= 0x80) {
                            const size = std.unicode.utf8ByteSequenceLength(json[ne]) catch break;
                            if (ne + size > json.len) break;
                            const cp = std.unicode.utf8Decode(json[ne..][0..size]) catch break;
                            name_buf[name_len] = if (cp <= 0xFF) @intCast(cp) else '?';
                            name_len += 1;
                            ne += size;
                        } else {
                            name_buf[name_len] = json[ne];
                            name_len += 1;
                            ne += 1;
                        }
                    }

                    const obj_end = findJsonObjectEndFrom(json, ki) orelse json.len - 1;
                    const next_brace: ?usize = obj_end;

                    var is_manual = false;
                    if (std.mem.indexOfPos(u8, json, ne, "\"manual\":true")) |mi| {
                        if (next_brace == null or mi < next_brace.?) {
                            is_manual = true;
                        }
                    }

                    var is_sem = false;
                    if (std.mem.indexOfPos(u8, json, ne, "\"sem\":true")) |si| {
                        if (next_brace == null or si < next_brace.?) {
                            is_sem = true;
                        }
                    }

                    var ts_buf: [64]u8 = std.mem.zeroes([64]u8);
                    var ts_len: u32 = 0;
                    if (std.mem.indexOfPos(u8, json, ne, "\"tmux_session\":\"")) |tsi| {
                        if (next_brace == null or tsi < next_brace.?) {
                            const ts_start = tsi + 16;
                            var ts_end = ts_start;
                            while (ts_end < json.len and json[ts_end] != '"' and ts_len < 63) {
                                ts_buf[ts_len] = json[ts_end];
                                ts_len += 1;
                                ts_end += 1;
                            }
                        }
                    }

                    var cwd_buf2: [512]u8 = std.mem.zeroes([512]u8);
                    var cwd_len: u32 = 0;
                    if (std.mem.indexOfPos(u8, json, ne, "\"cwd\":\"")) |cwdi| {
                        if (next_brace == null or cwdi < next_brace.?) {
                            const cwd_start = cwdi + 7;
                            var ci2 = cwd_start;
                            while (ci2 < json.len and cwd_len < 511) {
                                if (json[ci2] == '\\' and ci2 + 1 < json.len) {
                                    cwd_buf2[cwd_len] = json[ci2 + 1];
                                    cwd_len += 1;
                                    ci2 += 2;
                                } else if (json[ci2] == '"') {
                                    break;
                                } else {
                                    cwd_buf2[cwd_len] = json[ci2];
                                    cwd_len += 1;
                                    ci2 += 1;
                                }
                            }
                        }
                    }

                    var is_claude = false;
                    if (std.mem.indexOfPos(u8, json, ne, "\"claude_session\":true")) |cli| {
                        if (next_brace == null or cli < next_brace.?) {
                            is_claude = true;
                        }
                    }

                    var saved_pid: DWORD = 0;
                    if (std.mem.indexOfPos(u8, json, ne, "\"pid\":")) |pid_i| {
                        if (next_brace == null or pid_i < next_brace.?) {
                            var pi2 = pid_i + 6;
                            while (pi2 < json.len and json[pi2] >= '0' and json[pi2] <= '9') {
                                saved_pid = saved_pid * 10 + @as(DWORD, json[pi2] - '0');
                                pi2 += 1;
                            }
                        }
                    }

                    var is_muted = false;
                    if (std.mem.indexOfPos(u8, json, ne, "\"muted\":true")) |mi| {
                        if (next_brace == null or mi < next_brace.?) {
                            is_muted = true;
                        }
                    }

                    var is_keep_alive = false;
                    if (std.mem.indexOfPos(u8, json, ne, "\"keep_alive\":true")) |kai| {
                        if (next_brace == null or kai < next_brace.?) {
                            is_keep_alive = true;
                        }
                    }

                    var is_pinned_top = false;
                    if (std.mem.indexOfPos(u8, json, ne, "\"pinned_top\":true")) |pti| {
                        if (next_brace == null or pti < next_brace.?) {
                            is_pinned_top = true;
                        }
                    }

                    const is_inbox_excluded = std.mem.indexOf(u8, json[ki .. obj_end + 1], "\"inbox_excluded\":true") != null;
                    var is_locked = false;
                    if (std.mem.indexOfPos(u8, json, ne, "\"locked\":true")) |li| {
                        if (next_brace == null or li < next_brace.?) {
                            is_locked = true;
                        }
                    }

                    var favi_buf: [512]u8 = std.mem.zeroes([512]u8);
                    var favi_len: u32 = 0;
                    if (std.mem.indexOfPos(u8, json, ne, "\"favicon_path\":\"")) |fai| {
                        if (next_brace == null or fai < next_brace.?) {
                            const fav_start = fai + 16;
                            var fi2 = fav_start;
                            while (fi2 < json.len and favi_len < 511) {
                                if (json[fi2] == '\\' and fi2 + 1 < json.len) {
                                    favi_buf[favi_len] = json[fi2 + 1];
                                    favi_len += 1;
                                    fi2 += 2;
                                } else if (json[fi2] == '"') {
                                    break;
                                } else {
                                    favi_buf[favi_len] = json[fi2];
                                    favi_len += 1;
                                    fi2 += 1;
                                }
                            }
                        }
                    }

                    var tab_group_id: u32 = 0;
                    if (std.mem.indexOfPos(u8, json, ne, "\"group_id\":")) |gii| {
                        if (next_brace == null or gii < next_brace.?) {
                            var pi2 = gii + 11;
                            while (pi2 < json.len and json[pi2] >= '0' and json[pi2] <= '9') {
                                tab_group_id = tab_group_id * 10 + @as(u32, json[pi2] - '0');
                                pi2 += 1;
                            }
                        }
                    }

                    var tab_tmux_host: u8 = 0;
                    if (std.mem.indexOfPos(u8, json, ne, "\"tmux_host\":")) |tii| {
                        if (next_brace == null or tii < next_brace.?) {
                            var pi3 = tii + 12;
                            var hv: u32 = 0;
                            while (pi3 < json.len and json[pi3] >= '0' and json[pi3] <= '9') {
                                hv = hv * 10 + @as(u32, json[pi3] - '0');
                                pi3 += 1;
                            }
                            tab_tmux_host = @intCast(hv & 0xFF);
                        }
                    }

                    var tab_workspace: u8 = 0;
                    if (std.mem.indexOfPos(u8, json, ne, "\"workspace\":")) |wsi| {
                        if (next_brace == null or wsi < next_brace.?) {
                            var pw = wsi + 12;
                            var wv: u32 = 0;
                            while (pw < json.len and json[pw] >= '0' and json[pw] <= '9') {
                                wv = wv * 10 + @as(u32, json[pw] - '0');
                                pw += 1;
                            }
                            if (wv < MAX_LWS) tab_workspace = @intCast(wv);
                        }
                    }

                    var tab_last_active: u64 = 0;
                    if (std.mem.indexOfPos(u8, json, ne, "\"la\":")) |lai| {
                        if (next_brace == null or lai < next_brace.?) {
                            var lp = lai + 5;
                            var lv: u64 = 0;
                            while (lp < json.len and json[lp] >= '0' and json[lp] <= '9') {
                                lv = lv * 10 + @as(u64, json[lp] - '0');
                                lp += 1;
                            }
                            tab_last_active = lv;
                        }
                    }
                    var tab_last_viewed: u64 = 0;
                    if (std.mem.indexOfPos(u8, json, ne, "\"lv\":")) |lvi| {
                        if (next_brace == null or lvi < next_brace.?) {
                            var lvp = lvi + 5;
                            var lv2: u64 = 0;
                            while (lvp < json.len and json[lvp] >= '0' and json[lvp] <= '9') {
                                lv2 = lv2 * 10 + @as(u64, json[lvp] - '0');
                                lvp += 1;
                            }
                            tab_last_viewed = lv2;
                        }
                    }

                    var tab_csid: [40]u8 = std.mem.zeroes([40]u8);
                    var tab_csid_len: u32 = 0;
                    if (std.mem.indexOfPos(u8, json, ne, "\"csid\":\"")) |csi| {
                        if (next_brace == null or csi < next_brace.?) {
                            var cp = csi + 8;
                            while (cp < json.len and json[cp] != '"' and tab_csid_len < 39) {
                                tab_csid[tab_csid_len] = json[cp];
                                tab_csid_len += 1;
                                cp += 1;
                            }
                        }
                    }
                    var tab_ccwd: [192]u8 = std.mem.zeroes([192]u8);
                    var tab_ccwd_len: u32 = 0;
                    if (std.mem.indexOfPos(u8, json, ne, "\"ccwd\":\"")) |cci| {
                        if (next_brace == null or cci < next_brace.?) {
                            var cp2 = cci + 8;
                            while (cp2 < json.len and json[cp2] != '"' and tab_ccwd_len < 191) {
                                if (json[cp2] == '\\' and cp2 + 1 < json.len) {
                                    tab_ccwd[tab_ccwd_len] = json[cp2 + 1];
                                    tab_ccwd_len += 1;
                                    cp2 += 2;
                                } else {
                                    tab_ccwd[tab_ccwd_len] = json[cp2];
                                    tab_ccwd_len += 1;
                                    cp2 += 1;
                                }
                            }
                        }
                    }

                    var tab_burl: [512]u8 = std.mem.zeroes([512]u8);
                    var tab_burl_len: u32 = 0;
                    var tab_bon = false;
                    if (std.mem.indexOfPos(u8, json, ne, "\"bon\":true")) |boi| {
                        if (next_brace == null or boi < next_brace.?) {
                            tab_bon = true;
                        }
                    }
                    var tab_inbox_archived = false;
                    if (std.mem.indexOfPos(u8, json, ne, "\"iah\":true")) |iahi| {
                        if (next_brace == null or iahi < next_brace.?) {
                            tab_inbox_archived = true;
                        }
                    }
                    var tab_needs_attention = false;
                    if (std.mem.indexOfPos(u8, json, ne, "\"att\":true")) |atti| {
                        if (next_brace == null or atti < next_brace.?) {
                            tab_needs_attention = true;
                        }
                    }
                    var tab_kaw = false;
                    if (std.mem.indexOfPos(u8, json, ne, "\"kaw\":true")) |kawi| {
                        if (next_brace == null or kawi < next_brace.?) {
                            tab_kaw = true;
                        }
                    }
                    var tab_cv = false;
                    if (std.mem.indexOfPos(u8, json, ne, "\"cv\":true")) |cvi| {
                        if (next_brace == null or cvi < next_brace.?) {
                            tab_cv = true;
                        }
                    }
                    var tab_bnat: bool = true;
                    if (std.mem.indexOfPos(u8, json, ne, "\"bnat\":false")) |bnati| {
                        if (next_brace == null or bnati < next_brace.?) {
                            tab_bnat = false;
                        }
                    }
                    var tab_bsplit = BROWSER_SPLIT_DEFAULT_PERMILLE;
                    if (std.mem.indexOfPos(u8, json, ne, "\"bsplit\":")) |bsi| {
                        if (next_brace == null or bsi < next_brace.?) {
                            var bsp = bsi + 9;
                            var bsv: u32 = 0;
                            while (bsp < json.len and json[bsp] >= '0' and json[bsp] <= '9') {
                                bsv = bsv * 10 + @as(u32, json[bsp] - '0');
                                bsp += 1;
                            }
                            tab_bsplit = clampBrowserSplitPermille(bsv);
                        }
                    }
                    if (std.mem.indexOfPos(u8, json, ne, "\"burl\":\"")) |bui| {
                        if (next_brace == null or bui < next_brace.?) {
                            var bp = bui + 8;
                            while (bp < json.len and json[bp] != '"' and tab_burl_len < 511) {
                                if (json[bp] == '\\' and bp + 1 < json.len) {
                                    tab_burl[tab_burl_len] = json[bp + 1];
                                    tab_burl_len += 1;
                                    bp += 2;
                                } else {
                                    tab_burl[tab_burl_len] = json[bp];
                                    tab_burl_len += 1;
                                    bp += 1;
                                }
                            }
                        }
                    }

                    tabs[tab_count] = .{ .sync_owned = customCmdJsonBoolTrue(json[ki .. obj_end + 1], "sync_owned"), .wake_id = @intCast(@min(parseJsonUintField(json[ki .. obj_end + 1], "wake_id"), std.math.maxInt(u32))), .kind = kind, .name = name_buf, .name_len = name_len, .manual = is_manual, .sem = is_sem, .tmux_session = ts_buf, .tmux_session_len = ts_len, .cwd = cwd_buf2, .cwd_len = cwd_len, .claude_session = is_claude, .pid = saved_pid, .muted = is_muted, .keep_alive = is_keep_alive, .pinned_top = is_pinned_top, .inbox_excluded = is_inbox_excluded, .locked = is_locked, .favorite = customCmdJsonBoolTrue(json[ki .. obj_end + 1], "favorite"), .favicon_path = favi_buf, .favicon_path_len = favi_len, .group_id = tab_group_id, .tmux_host = tab_tmux_host, .workspace = tab_workspace, .last_active = tab_last_active, .last_viewed = tab_last_viewed, .claude_sid = tab_csid, .claude_sid_len = tab_csid_len, .claude_cwd = tab_ccwd, .claude_cwd_len = tab_ccwd_len, .bon = tab_bon, .inbox_archived = tab_inbox_archived, .archive_time = parseJsonUintField(json[ki .. obj_end + 1], "archive_time"), .archive_done = parseJsonUintField(json[ki .. obj_end + 1], "archive_done"), .last_done_time = parseJsonUintField(json[ki .. obj_end + 1], "last_done_time"), .archive_content = parseArchiveContent(json[ki .. obj_end + 1], "\"archive_rows\":\""), .archive_content_valid = std.mem.indexOf(u8, json[ki .. obj_end + 1], "\"archive_rows\":\"") != null, .last_done_content = parseArchiveContent(json[ki .. obj_end + 1], "\"done_rows\":\""), .last_done_content_valid = std.mem.indexOf(u8, json[ki .. obj_end + 1], "\"done_rows\":\"") != null, .needs_attention = tab_needs_attention, .burl = tab_burl, .burl_len = tab_burl_len, .bnat = tab_bnat, .bsplit_permille = tab_bsplit, .kaw = tab_kaw, .cv = tab_cv };
                    tab_count += 1;
                    i = obj_end + 1;
                } else {
                    i = kind_end + 1;
                }
            } else {
                break;
            }
        } else {
            break;
        }
    }
    return tab_count;
}
