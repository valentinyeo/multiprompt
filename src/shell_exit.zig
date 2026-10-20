const std = @import("std");
const ShellKind = @import("app_state.zig").ShellKind;

pub const ISSUE_416_FAST_FAIL_MS: u64 = 60_000;

pub const ExitAction = enum { respawn, preserve, close };

pub fn decide(kind: ShellKind, got_code: bool, exit_code: u32, in_resume_window: bool, pinned_or_locked: bool, keep_tmux: bool, alive_ms: u64) ExitAction {
    if (kind == .tmux and (!got_code or exit_code == 255) and !in_resume_window and alive_ms < ISSUE_416_FAST_FAIL_MS) return .preserve;
    const is_ssh_kind = kind == .vps or kind == .vps2 or kind == .tmux;
    if (is_ssh_kind and (in_resume_window or !got_code or exit_code == 255 or exit_code == 0xC0000139)) return .respawn;
    if (pinned_or_locked or (keep_tmux and kind == .tmux)) return .preserve;
    return .close;
}

pub fn hostProbeBusy(running: bool, since_spawn_ms: u64, attempts: u8, backoff_ms: u64) bool {
    if (attempts == 0) return false;
    if (running) return since_spawn_ms < ISSUE_416_FAST_FAIL_MS;
    return since_spawn_ms < backoff_ms;
}

pub fn reconnectAllowed(probe_in_flight: bool, host_healthy: bool, attempted_this_tick: bool) bool {
    if (ISSUE_416_FAST_FAIL_MS == 0) return true;
    return !probe_in_flight and (host_healthy or !attempted_this_tick);
}

test "ISSUE-350 real BTOP exit keeps its live tmux tab" {
    const fixture = @embedFile("fixtures/btop-exit.txt");
    var lines = std.mem.tokenizeScalar(u8, fixture, '\n');
    var count: usize = 0;
    var in_resume_window: bool = true;
    while (lines.next()) |line| {
        const start = (std.mem.indexOf(u8, line, "kind=") orelse return error.MissingKind) + "kind=".len;
        const end = std.mem.indexOfScalarPos(u8, line, start, ' ') orelse line.len;
        const kind = std.meta.stringToEnum(ShellKind, line[start..end]) orelse return error.InvalidKind;
        try std.testing.expectEqual(ShellKind.tmux, kind);
        if (std.mem.indexOf(u8, line, "in_window=")) |window_start| {
            const value_start = window_start + "in_window=".len;
            const value_end = std.mem.indexOfScalarPos(u8, line, value_start, ' ') orelse line.len;
            in_resume_window = (try std.fmt.parseInt(u8, line[value_start..value_end], 10)) != 0;
            try std.testing.expect(!in_resume_window);
            try std.testing.expectEqual(ExitAction.close, decide(kind, true, 0, in_resume_window, false, false, 3_600_000));
            try std.testing.expectEqual(ExitAction.preserve, decide(kind, true, 0, in_resume_window, false, true, 3_600_000));
        }
        count += 1;
    }
    try std.testing.expectEqual(@as(usize, 2), count);
    try std.testing.expect(!in_resume_window);
}

test "SSH exits keep transport recovery and plain SSH clean close" {
    for ([_]ShellKind{ .vps, .vps2, .tmux }) |kind| {
        for ([_]bool{ false, true }) |keep_tmux| {
            try std.testing.expectEqual(ExitAction.respawn, decide(kind, true, 255, false, false, keep_tmux, 3_600_000));
            try std.testing.expectEqual(ExitAction.respawn, decide(kind, false, 0, false, false, keep_tmux, 3_600_000));
            try std.testing.expectEqual(ExitAction.respawn, decide(kind, true, 0xC0000139, false, false, keep_tmux, 3_600_000));
            try std.testing.expectEqual(ExitAction.respawn, decide(kind, true, 0, true, true, keep_tmux, 3_600_000));
            try std.testing.expectEqual(ExitAction.preserve, decide(kind, true, 0, false, true, keep_tmux, 3_600_000));
        }
    }
    for ([_]ShellKind{ .vps, .vps2 }) |kind| {
        try std.testing.expectEqual(ExitAction.close, decide(kind, true, 0, false, false, true, 3_600_000));
    }
}

test "local exits ignore SSH recovery and preserve only pinned or locked tabs" {
    for ([_]ShellKind{ .cmd, .pwsh, .bash, .gitbash }) |kind| {
        for ([_]bool{ false, true }) |keep_tmux| {
            try std.testing.expectEqual(ExitAction.close, decide(kind, false, 255, true, false, keep_tmux, 3_600_000));
            try std.testing.expectEqual(ExitAction.preserve, decide(kind, false, 0xC0000139, true, true, keep_tmux, 3_600_000));
        }
    }
}

test "ISSUE-416 real dead-host burst preserves every fast-failing tmux tab" {
    const fixture = @embedFile("fixtures/ssh-dead-host-burst.txt");
    for ([_]bool{ false, true }) |keep_tmux| {
        for ([_]bool{ false, true }) |got_code| {
            var lines = std.mem.tokenizeScalar(u8, fixture, '\n');
            var count: usize = 0;
            var respawns: usize = 0;
            var preserved: usize = 0;
            while (lines.next()) |line| {
                const kind_start = (std.mem.indexOf(u8, line, "kind=") orelse return error.MissingKind) + "kind=".len;
                const kind_end = std.mem.indexOfScalarPos(u8, line, kind_start, ' ') orelse line.len;
                const kind = std.meta.stringToEnum(ShellKind, line[kind_start..kind_end]) orelse return error.InvalidKind;
                const window_start = (std.mem.indexOf(u8, line, "in_window=") orelse return error.MissingWindow) + "in_window=".len;
                const window_end = std.mem.indexOfScalarPos(u8, line, window_start, ' ') orelse line.len;
                const in_window = (try std.fmt.parseInt(u8, line[window_start..window_end], 10)) != 0;
                const alive_start = (std.mem.indexOf(u8, line, "alive_ms=") orelse return error.MissingLifetime) + "alive_ms=".len;
                const alive_end = std.mem.indexOfScalarPos(u8, line, alive_start, ' ') orelse line.len;
                const alive_ms = try std.fmt.parseInt(u64, line[alive_start..alive_end], 10);
                try std.testing.expectEqual(ShellKind.tmux, kind);
                try std.testing.expect(!in_window);
                const action = decide(kind, got_code, 255, in_window, false, keep_tmux, alive_ms);
                if (action == .respawn) respawns += 1;
                if (action == .preserve) preserved += 1;
                count += 1;
            }
            try std.testing.expectEqual(@as(usize, 31), count);
            try std.testing.expectEqual(@as(usize, 0), respawns);
            try std.testing.expectEqual(count, preserved);
        }
    }
}

test "ISSUE-416 dead-host reconnect tick allows one probe until the host is healthy" {
    const fixture = @embedFile("fixtures/ssh-dead-host-burst.txt");
    for ([_]struct { probe_in_flight: bool, host_healthy: bool, expected: usize }{
        .{ .probe_in_flight = false, .host_healthy = false, .expected = 1 },
        .{ .probe_in_flight = true, .host_healthy = false, .expected = 0 },
        .{ .probe_in_flight = false, .host_healthy = true, .expected = 31 },
        .{ .probe_in_flight = true, .host_healthy = true, .expected = 0 },
    }) |scenario| {
        var attempted_this_tick = [_]bool{false} ** 256;
        var lines = std.mem.tokenizeScalar(u8, fixture, '\n');
        var count: usize = 0;
        var attempts: usize = 0;
        while (lines.next()) |line| {
            const host_start = (std.mem.indexOf(u8, line, "host=") orelse return error.MissingHost) + "host=".len;
            const host_end = std.mem.indexOfScalarPos(u8, line, host_start, ' ') orelse line.len;
            const host = try std.fmt.parseInt(u8, line[host_start..host_end], 10);
            try std.testing.expectEqual(@as(u8, 1), host);
            if (reconnectAllowed(scenario.probe_in_flight, scenario.host_healthy, attempted_this_tick[host])) {
                attempted_this_tick[host] = true;
                attempts += 1;
            }
            count += 1;
        }
        try std.testing.expectEqual(@as(usize, 31), count);
        try std.testing.expectEqual(scenario.expected, attempts);
    }
}

test "ISSUE-416 long-lived tmux transport drops still respawn immediately" {
    for ([_]bool{ false, true }) |keep_tmux| {
        try std.testing.expectEqual(ExitAction.respawn, decide(.tmux, true, 255, false, false, keep_tmux, 3 * 60 * 60 * 1000));
        try std.testing.expectEqual(ExitAction.respawn, decide(.tmux, false, 0, false, false, keep_tmux, 3 * 60 * 60 * 1000));
        try std.testing.expectEqual(ExitAction.respawn, decide(.tmux, true, 255, false, false, keep_tmux, 60_000));
    }
}

test "ISSUE-416 fast failure leaves loader resume and plain SSH recovery unchanged" {
    for ([_]bool{ false, true }) |keep_tmux| {
        try std.testing.expectEqual(ExitAction.preserve, decide(.tmux, true, 255, false, false, keep_tmux, 59_999));
        try std.testing.expectEqual(ExitAction.respawn, decide(.tmux, true, 0xC0000139, false, false, keep_tmux, 0));
        try std.testing.expectEqual(ExitAction.respawn, decide(.tmux, true, 255, true, false, keep_tmux, 0));
        try std.testing.expectEqual(ExitAction.respawn, decide(.tmux, false, 0, true, false, keep_tmux, 0));
        for ([_]ShellKind{ .vps, .vps2 }) |kind| {
            try std.testing.expectEqual(ExitAction.respawn, decide(kind, true, 255, false, false, keep_tmux, 0));
            try std.testing.expectEqual(ExitAction.respawn, decide(kind, false, 0, false, false, keep_tmux, 0));
        }
    }
}

test "ISSUE-416 tabs parked after a fast failure still reconnect on their own" {
    try std.testing.expect(@import("app_state.zig").SSH_AUTO_RECONNECT_ENABLED or ISSUE_416_FAST_FAIL_MS == 0);
}

test "ISSUE-416 a host that refuses instantly gets one probe per backoff, not one per tick" {
    const backoff = [_]u64{ 5_000, 10_000, 20_000, 30_000 };
    var spawn_tick = [_]u64{0} ** 31;
    var attempts = [_]u8{0} ** 31;
    var next_tick = [_]u64{0} ** 31;
    var probes: usize = 0;
    var now: u64 = 1_000;
    while (now <= 61_000) : (now += 1_000) {
        var busy = false;
        for (0..31) |i| {
            if (spawn_tick[i] != 0 and hostProbeBusy(false, now -| spawn_tick[i], attempts[i], backoff[@min(attempts[i] -| 1, 3)])) busy = true;
        }
        var attempted = false;
        for (0..31) |i| {
            if (next_tick[i] != 0 and now < next_tick[i]) continue;
            if (!reconnectAllowed(busy, false, attempted)) continue;
            attempted = true;
            next_tick[i] = now + backoff[@min(attempts[i], 3)];
            attempts[i] +|= 1;
            spawn_tick[i] = now;
            probes += 1;
        }
    }
    try std.testing.expect(probes <= 13);
    try std.testing.expect(probes >= 1);
}

test "ISSUE-416 probe busy window covers a running probe and the backoff after a dead one" {
    try std.testing.expect(!hostProbeBusy(false, 1_000, 0, 5_000));
    try std.testing.expect(hostProbeBusy(false, 1_000, 1, 5_000));
    try std.testing.expect(!hostProbeBusy(false, 5_000, 1, 5_000));
    try std.testing.expect(hostProbeBusy(true, 30_000, 1, 5_000));
    try std.testing.expect(!hostProbeBusy(true, ISSUE_416_FAST_FAIL_MS, 1, 5_000));
}
