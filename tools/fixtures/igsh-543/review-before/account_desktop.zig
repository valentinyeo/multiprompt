fn accountLock() void {
    if (g_account_pending_device_keys) |bytes| std.heap.page_allocator.free(bytes);
    g_account_pending_device_keys = null;
    app_state.g_account_locked = true;
    app_state.g_account_dirty_at = 0;
    _ = KillTimer(app_state.g_main_hwnd, TIMER_ACCOUNT_SAVE);
    app_state.g_search_active = false;
    app_state.g_inbox_active = false;
    app_state.g_all_sessions_active = false;
    if (app_state.g_chat_active) closeChatView();
    for (0..app_state.shell_count) |i| {
        if (app_state.shells[i].hwnd != null) _ = ShowWindow(app_state.shells[i].hwnd, SW_HIDE);
        closeBrowserForShell(@intCast(i));
    }
    app_state.g_account_status = "Sign in to multiprompt to open your workspaces.";
    _ = SetForegroundWindow(app_state.g_main_hwnd);
    _ = SetFocus(app_state.g_main_hwnd);
    _ = InvalidateRect(app_state.g_main_hwnd, null, 1);
}

fn layoutSyncWorker(submitted: AccountJob) void {
    const job = if (submitted.kind == .startup and submitted.base == null and submitted.edited == null) accountResumeJob(.startup) else submitted;
    const a = std.heap.page_allocator;
    const reply = a.create(LayoutReply) catch {
        accountJobFree(job);
        _ = PostMessageW(app_state.g_main_hwnd, WM_APP_LAYOUT_READY, 0, 0);
        return;
    };
    reply.* = .{ .job = job };
    accountRequest(job, reply) catch |err| {
        reply.cancelled = err == error.Cancelled;
    };
    if (job.kind == .login and app_state.g_account_cancel.load(.acquire)) reply.cancelled = true;
    if (reply.unauthorized or job.kind == .signout) {
        app_state.g_account_access.clear(a);
    }
    if (job.kind == .signout) {
        accountDeleteToken();
        reply.signed_out = true;
    }
    if (PostMessageW(app_state.g_main_hwnd, WM_APP_LAYOUT_READY, 0, @bitCast(@intFromPtr(reply))) == 0) {
        accountJobFree(job);
        if (reply.bytes) |bytes| a.free(bytes);
        if (reply.device_keys) |bytes| a.free(bytes);
        if (reply.key_error) |bytes| a.free(bytes);
        a.destroy(reply);
    }
}

fn accountSyncHosts(a: std.mem.Allocator, remote: []const account_hosts.Host) ![]const account_hosts.Host {
    const aliases = [_][]const u8{ app_state.SSH_TARGET_DE, app_state.SSH_TARGET_UK, app_state.SSH_TARGET_INNE };
    const names = [_][]const u8{ "Host 1", "Host 2", "Remote host 3" };
    var ssh_buf: [1024]u8 = undefined;
    var ssh_len: usize = 0;
    if (!@import("console.zig").appendSshExe(&ssh_buf, &ssh_len)) return &.{};
    const ssh = ssh_buf[0..ssh_len];
    const path = std.mem.trim(u8, ssh, "\" ");
    const dir = std.mem.lastIndexOfAny(u8, path, "\\/") orelse return &.{};
    const keygen = try std.fmt.allocPrint(a, "\"{s}\\ssh-keygen.exe\"", .{path[0..dir]});
    var profile_buf: [512]u8 = undefined;
    const n = GetEnvironmentVariableA("USERPROFILE", &profile_buf, profile_buf.len);
    if (n == 0 or n >= profile_buf.len) return &.{};
    const folder = try std.fmt.allocPrint(a, "{s}\\.ssh", .{profile_buf[0..n]});
    const config = try std.fmt.allocPrint(a, "{s}\\config", .{folder});
    const known = try std.fmt.allocPrint(a, "{s}\\known_hosts", .{folder});
    var hosts: std.ArrayList(account_hosts.Host) = .empty;
    for (aliases, names, 0..) |alias, name, slot| {
        const command = try std.fmt.allocPrint(a, "{s}-G {s}", .{ ssh, alias });
        const output = accountSshOutput(a, command, 5000) catch continue;
        const resolved = account_hosts.parseSshConfig(output) orelse continue;
        const missing = account_hosts.shouldImport(alias, resolved);
        var incoming: ?account_hosts.Host = null;
        if (missing) {
            for (remote) |host| if (host.slot == slot) {
                incoming = host;
                break;
            };
            if (incoming == null) continue;
        }
        var host = incoming orelse account_hosts.Host{ .slot = @intCast(slot), .name = name, .hostname = resolved.hostname, .port = resolved.port, .user = resolved.user };
        const target = try account_hosts.knownHostName(a, host.hostname, host.port);
        const lookup = try std.fmt.allocPrint(a, "{s} -F \"{s}\" -f \"{s}\"", .{ keygen, target, known });
        const key_output = accountSshOutput(a, lookup, 5000) catch "";
        const keys = try account_hosts.readKeys(a, key_output);
        if (missing) {
            host.hostname = try a.dupe(u8, host.hostname);
            host.user = try a.dupe(u8, host.user);
            if (host.host_keys) |incoming_keys| {
                const owned_keys = try a.alloc([]const u8, incoming_keys.len);
                for (incoming_keys, owned_keys) |key, *owned| owned.* = try a.dupe(u8, key);
                host.host_keys = owned_keys;
            }
            const block = try account_hosts.configBlock(a, alias, host);
            win32MakeDir(folder);
            var additions: std.ArrayList(u8) = .empty;
            for (host.host_keys orelse &.{}) |key| {
                var present = false;
                for (keys) |old| if (std.mem.eql(u8, old, key)) {
                    present = true;
                };
                if (!present) try additions.appendSlice(a, try account_hosts.knownHostLine(a, host, key));
            }
            if (additions.items.len > 0) {
                try accountAppendSshFile(known, "\r\n");
                try accountAppendSshFile(known, additions.items);
            }
            accountAppendSshFile(config, block) catch continue;
        } else host.host_keys = keys[0..@min(keys.len, 4)];
        host.name = name;
        try hosts.append(a, host);
    }
    return hosts.toOwnedSlice(a);
}

fn accountRequest(job: AccountJob, reply: *LayoutReply) !void {
    const a = std.heap.page_allocator;
    var renewed = job.kind == .login;
    var response = if (job.kind == .login) try account_client.signIn(&app_state.g_account_cancel) else blk: {
        if (app_state.g_account_access.bytes) |cached| {
            reply.has_token = true;
            if (app_state.g_account_access.usable(GetTickCount64()))
                break :blk account_client.Response{ .status = 200, .bytes = try a.dupe(u8, cached) };
        }
        const cached_credential = job.credential orelse app_state.g_account_access.bytes;
        const old = cached_credential orelse readDpapiFile("account-device.dat", 16384) orelse {
            reply.unauthorized = true;
            return;
        };
        reply.has_token = true;
        defer if (cached_credential == null) freeSecret(old);
        const refreshed = try account_client.refresh(old);
        renewed = refreshed.status == 200;
        break :blk refreshed;
    };
    defer response.deinit();
    if (app_state.g_account_cancel.load(.acquire)) return error.Cancelled;
    if (response.status != 200) {
        reply.unauthorized = account_state.invalidCredential(response.status, response.bytes);
        return error.Authentication;
    }
    if (renewed) try app_state.g_account_access.remember(a, response.bytes, GetTickCount64());
    reply.has_token = true;
    if (job.kind != .signout and !writeDpapiFile("account-device.dat", response.bytes)) return error.Storage;
    const access = try account_client.field(response.bytes, "access_token");
    defer freeSecret(access);
    if (job.kind == .signout or job.kind == .revoke) {
        const device = if (job.device) |id| try a.dupe(u8, id) else try account_client.field(response.bytes, "device_id");
        defer a.free(device);
        const path = try std.fmt.allocPrint(a, "/v1/devices/{s}", .{device});
        defer a.free(path);
        const revoked = try account_client.request("DELETE", path, access, "");
        defer revoked.deinit();
        if (revoked.status == 401) reply.unauthorized = true;
        if (revoked.status != 200) return error.Revoke;
        if (job.kind == .signout) {
            accountDeleteToken();
            reply.signed_out = true;
            return;
        }
    }
    if (job.kind == .devices or job.kind == .revoke) {
        const devices = try account_client.request("GET", "/v1/devices", access, "");
        defer devices.deinit();
        if (devices.status == 401) reply.unauthorized = true;
        if (devices.status != 200) return error.Authentication;
        reply.bytes = try a.dupe(u8, devices.bytes);
        return;
    }
    if (job.kind == .device_keys or job.kind == .decide_keys) {
        accountSyncDeviceKeys(access, job, reply) catch {
            accountDeviceKeyError(reply, "Could not update device approvals. Check your connection and SSH key pair, then try Account: Approve devices again.");
        };
        return;
    }
    var remote = try account_client.request("GET", "/v1/layout", access, "");
    defer remote.deinit();
    if (remote.status == 401) reply.unauthorized = true;
    if (remote.status != 200) return error.Network;
    var arena = std.heap.ArenaAllocator.init(a);
    defer arena.deinit();
    const alloc = arena.allocator();
    const initial_json = try accountReadLayout(alloc, remote.bytes);
    const initial = try session_layout.parse(alloc, initial_json);
    defer initial.deinit();
    if (remote.hosts_supported and account_hosts.shouldRefresh(GetTickCount64(), g_account_hosts_cache.refreshed_at, job.kind == .login or job.kind == .startup, g_account_hosts_cache.hosts, initial.value.hosts orelse &.{})) {
        var host_arena = std.heap.ArenaAllocator.init(a);
        errdefer host_arena.deinit();
        const discovered = try accountSyncHosts(host_arena.allocator(), initial.value.hosts orelse &.{});
        if (g_account_hosts_cache.arena) |*old| old.deinit();
        g_account_hosts_cache = .{ .arena = host_arena, .hosts = discovered, .refreshed_at = GetTickCount64() };
    }
    const hosts = g_account_hosts_cache.hosts;
    var attempts: usize = 0;
    while (attempts < 3) : (attempts += 1) {
        const json = try accountReadLayout(alloc, remote.bytes);
        const server = try session_layout.parse(alloc, json);
        defer server.deinit();
        var rebased = server.value;
        if (job.base != null and job.edited != null) {
            const base = try session_layout.parse(alloc, job.base.?);
            defer base.deinit();
            const edited = try session_layout.parse(alloc, job.edited.?);
            defer edited.deinit();
            rebased = try account_layout.rebase(alloc, base.value, edited.value, server.value);
        }
        if (account_layout.equal(server.value, rebased) and !(remote.hosts_supported and account_hosts.needsPublish(hosts, server.value.hosts orelse &.{}))) break;
        rebased.hosts = if (remote.hosts_supported) hosts else null;
        const body = try std.json.Stringify.valueAlloc(alloc, .{ .base_revision = server.value.revision, .layout = rebased }, .{ .emit_null_optional_fields = false });
        const put = try account_client.request("PUT", "/v1/layout", access, body);
        remote.deinit();
        remote = put;
        if (remote.status == 200) break;
        if (remote.status == 401) reply.unauthorized = true;
        if (remote.status != 409) return error.Network;
    }
    if (remote.status != 200) return error.Conflict;
    reply.bytes = try a.dupe(u8, try accountReadLayout(alloc, remote.bytes));
    accountSyncDeviceKeys(access, job, reply) catch {
        accountDeviceKeyError(reply, "Could not update device approvals. Check your connection and SSH key pair, then try Account: Approve devices again.");
    };
}

pub fn handleLayoutReply(lp: LPARAM) void {
    if (lp != 0 and @import("launch_cache.zig").pending) {
        const reply: *LayoutReply = @ptrFromInt(@as(usize, @bitCast(lp)));
        if (!reply.unauthorized and !reply.signed_out and reply.job.kind == .startup) {
            startup_reply = lp;
            return;
        }
    }
    app_state.g_account_busy = false;
    app_state.g_account_login_active = false;
    if (lp == 0) {
        g_account_key_prompt_active = false;
        accountSyncFailed(app_state.g_account_has_token);
        return;
    }
    const a = std.heap.page_allocator;
    const reply: *LayoutReply = @ptrFromInt(@as(usize, @bitCast(lp)));
    defer a.destroy(reply);
    defer accountJobFree(reply.job);
    if (reply.job.kind == .decide_keys) g_account_key_prompt_active = false;
    defer if (reply.bytes) |bytes| a.free(bytes);
    defer if (reply.device_keys) |bytes| a.free(bytes);
    defer if (reply.key_error) |bytes| a.free(bytes);
    defer {
        if (reply.key_error) |text| {
            app_state.g_account_busy = true;
            showSyncMessage(text, true);
            app_state.g_account_busy = false;
        }
        if (!reply.unauthorized and !reply.cancelled) {
            if (reply.device_keys) |bytes| accountPromptDeviceKeys(bytes, reply.job.kind == .device_keys);
        }
    }
    if (reply.signed_out) {
        accountLock();
        return;
    }
    if (reply.cancelled) {
        app_state.g_account_status = "Sign-in cancelled. Press Enter to retry.";
        _ = InvalidateRect(app_state.g_main_hwnd, null, 1);
        return;
    }
    if (reply.unauthorized) {
        accountDeleteToken();
        app_state.g_account_has_token = false;
        app_state.g_account_reauth = true;
        _ = KillTimer(app_state.g_main_hwnd, TIMER_ACCOUNT_SAVE);
        if (reply.job.kind == .startup) {
            accountLock();
        } else {
            showHeaderNoticeAscii("Sign in again: Ctrl+K > Sign in to multiprompt", 86400000, true);
            _ = InvalidateRect(app_state.g_main_hwnd, null, 1);
        }
        return;
    }
    if (reply.has_token) {
        app_state.g_account_has_token = true;
        if (reply.job.kind == .login) {
            app_state.g_account_reauth = false;
            app_state.g_cap_msg_until = 0;
        }
    }
    if (reply.job.kind == .device_keys or reply.job.kind == .decide_keys) return;
    const bytes = reply.bytes orelse {
        accountSyncFailed(reply.has_token or app_state.g_account_has_token);
        return;
    };
    if (reply.job.kind == .devices or reply.job.kind == .revoke) {
        accountDevices(bytes);
        return;
    }
    var arena = std.heap.ArenaAllocator.init(a);
    defer arena.deinit();
    const alloc = arena.allocator();
    const server = session_layout.parse(alloc, bytes) catch return;
    defer server.deinit();
    var to_apply = bytes;
    var local_ack: ?[]u8 = null;
    if (!app_state.g_account_bootstrapping and reply.job.edited != null) {
        const edit = reply.job.edited.?;
        const sent = session_layout.parse(alloc, edit) catch return;
        defer sent.deinit();
        var ownership: [MAX_SHELLS]bool = undefined;
        const previous = session_layout.parse(alloc, app_state.g_account_base orelse bytes) catch return;
        defer previous.deinit();
        for (sent.value.tabs, 0..) |tab, i| ownership[i] = account_layout.find(previous.value.tabs, tab) != null or account_layout.find(server.value.tabs, tab) != null;
        const ack = account_layout.apply(alloc, sent.value, ownership[0..sent.value.tabs.len], server.value, MAX_LWS, MAX_SHELLS) catch return;
        local_ack = session_layout.encode(alloc, ack) catch return;
        const current = accountCapturePush(alloc, sent.value) catch return;
        const rebased = account_layout.rebase(alloc, sent.value, current, server.value) catch return;
        to_apply = session_layout.encode(alloc, rebased) catch return;
    }
    if (app_state.g_account_bootstrapping) {
        accountPrepareRestore(to_apply) catch {
            app_state.g_account_status = "Could not reconcile saved layout. Local cache kept.";
            _ = InvalidateRect(app_state.g_main_hwnd, null, 1);
        };
    } else {
        app_state.g_account_locked = false;
        applyServerLayout(to_apply) catch {
            accountSyncFailed(true);
            if (app_state.active_shell < app_state.shell_count) switchToShell(app_state.active_shell);
            return;
        };
    }
    if (app_state.g_account_bootstrapping or reply.job.base != null) accountDeletePending();
    var keep_closed: usize = 0;
    for (app_state.g_account_closed[0..app_state.g_account_closed_count]) |c| {
        const probe = session_layout.Tab{ .name = "", .tmux_session = c.session[0..c.len], .tmux_host = c.host, .workspace = "" };
        if (account_layout.find(server.value.tabs, probe) == null) continue;
        app_state.g_account_closed[keep_closed] = c;
        keep_closed += 1;
    }
    app_state.g_account_closed_count = keep_closed;
    app_state.g_account_has_token = true;
    app_state.g_account_reauth = false;
    app_state.g_account_retry.succeeded();
    _ = KillTimer(app_state.g_main_hwnd, TIMER_ACCOUNT_SAVE);
    if (app_state.g_account_base) |old| a.free(old);
    app_state.g_account_base = a.dupe(u8, bytes) catch return;
    for (app_state.shells[0..app_state.shell_count]) |*shell| {
        shell.synced_input = 0;
        shell.input_publish_pending = false;
        const probe = session_layout.Tab{ .name = "", .tmux_session = shell.tmux_session[0..shell.tmux_session_len], .tmux_host = shell.tmux_host, .workspace = "" };
        if (account_layout.find(server.value.tabs, probe)) |i| shell.synced_input = server.value.tabs[i].input orelse 0;
    }
    app_state.g_account_dirty_at = 0;
    app_state.g_account_locked = false;
    if (app_state.g_account_local_base) |old| a.free(old);
    app_state.g_account_local_base = if (local_ack) |ack| a.dupe(u8, ack) catch null else null;
    if (!app_state.g_account_bootstrapping) {
        if (app_state.g_account_local_base == null) {
            const current = captureSessionLayout(alloc, false) catch return;
            app_state.g_account_local_base = session_layout.encode(a, current) catch null;
        }
        publishSessionLayout();
    }
    _ = InvalidateRect(app_state.g_main_hwnd, null, 1);
}
