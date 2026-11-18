import importlib.util
import json
import pathlib
import subprocess
import tempfile

from native import function, tick, load


def replay(root, results, output, source_root=None):
    source_root = source_root or root
    output.mkdir(parents=True, exist_ok=True)
    send = (source_root / "src/chat_send.zig").read_text()
    reducer = function(send, "chatMessageReduce")
    state_line = next(line for line in reducer.splitlines() if line.strip().startswith("entry.state = if "))
    source = '''const std = @import("std");
const chat_echo = @import("chat_echo.zig");
const ChatOutboxEntry = struct {
    state: chat_echo.OutboxState = .queued,
    sent_tick_ms: i64 = 1000,
    message_v1: bool = true,
    message_phase: [16]u8 = @splat(0),
    reset_pending: bool = false,
    write_started: bool = false,
    channel_sent: bool = false,
    channel_pending: bool = false,
    retryable: bool = false,
};
'''
    source += function(send, "chatEchoWaitsOnTranscript") + "\n" + tick(send) + load(send)
    source += "fn receipt(entry: *ChatOutboxEntry, phase: []const u8) void {\n" + state_line + "\n}\n"
    for rule, result in results.items():
        if result["status"] != "FAIL":
            continue
        source += f'test "formal replay {rule}" {{\n'
        actions = {step["action"] for step in result["trace"]}
        source += "    var entry = ChatOutboxEntry{};\n    var pending = false;\n"
        source += "    " + ("var" if "Echo" in actions else "const") + " transcript = false;\n"
        source += "    " + ("var" if "Wait" in actions else "const") + " now: i64 = 1001;\n"
        for step in result["trace"]:
            action, values = step["action"], step["values"]
            if action == "Send":
                source += "    pending = true; entry.state = .queued;\n"
            elif action == "Submit":
                source += "    try std.testing.expect(chat_echo.mayType(entry.state, entry.write_started, false, false));\n    entry.state = .sending; entry.write_started = true;\n"
            elif action == "Receipt":
                source += f'    receipt(&entry, "{values["host"]}"); entry.write_started = true;\n'
                source += f'    @memset(&entry.message_phase, 0); @memcpy(entry.message_phase[0..{len(values["phase"])}], "{values["phase"]}");\n'
            elif action == "Resume":
                source += "    resume(&entry);\n"
            elif action == "Wait":
                source += "    now = 601000; _ = timeout(&entry, now);\n"
            elif action == "Echo":
                source += '''    transcript = true;
    if (chatEchoWaitsOnTranscript(entry)) {
        const text = std.unicode.utf8ToUtf16LeStringLiteral("synthetic delivery probe");
        var p = [_]chat_echo.Pending{.{ .text = text, .prefix = text, .anchor = .{ .after_ms = 100 } }};
        const blocks = [_]chat_echo.UserBlock{.{ .text = text, .stamp_ms = 200, .message_id = 1 }};
        var picked: [1]?usize = undefined;
        chat_echo.assign(&p, &blocks, false, &.{}, &picked);
        if (picked[0] != null) pending = false;
    }
'''
            elif action == "Retry" and values["host"] != "accepted":
                source += "    entry.state = .sending; entry.write_started = true; @memset(&entry.message_phase, 0);\n"
            if values["state"] != "empty":
                source += f'    try std.testing.expectEqual(chat_echo.OutboxState.{values["state"]}, entry.state);\n'
                source += f'    try std.testing.expectEqual({str(values["pending"]).lower()}, pending);\n'
                source += f'    try std.testing.expectEqual({str(values["written"]).lower()}, entry.write_started);\n'
                phase = "" if values["phase"] == "empty" else values["phase"]
                source += f'    try std.testing.expectEqualStrings("{phase}", std.mem.sliceTo(&entry.message_phase, 0));\n'
        last = result["trace"][-1]["values"]
        expected_copies = int(last["pending"]) + int(last["transcript"])
        source += f"    try std.testing.expectEqual(@as(u32, {expected_copies}), @as(u32, @intFromBool(pending)) + @as(u32, @intFromBool(transcript)));\n"
        source += f'    const not_sent = pending and chat_echo.showsNotSent(true, entry.state, std.mem.sliceTo(&entry.message_phase, 0), 1000, now);\n'
        source += f"    try std.testing.expectEqual({str(rule.startswith('NoFalseNotSent')).lower()}, not_sent);\n}}\n"
    (output / "replay.zig").write_text(source)
    with tempfile.TemporaryDirectory(prefix="delivery-replay-") as directory:
        work = pathlib.Path(directory)
        (work / "replay.zig").write_text(source)
        (work / "chat_echo.zig").write_bytes((source_root / "src/chat_echo.zig").read_bytes())
        native = subprocess.run(["zig", "test", "-j1", "replay.zig", "--test-filter", "formal replay"], cwd=work, text=True, capture_output=True, timeout=90)
    (output / "native.log").write_text(native.stdout + native.stderr)
    if native.returncode:
        raise ValueError("Counterexample did not replay through production decisions; see " + str(output / "native.log"))
    spec = importlib.util.spec_from_file_location("delivery_reader_tests", root / "tools/chat-history-reader-test.py")
    tests = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(tests)
    host_reports = {}
    for rule, result in results.items():
        if result["status"] != "FAIL":
            continue
        fixture = tests.IGSH_1266_SharedMessageHostTest()
        fixture.setUp()
        rows = []
        try:
            for step in result["trace"]:
                action, values = step["action"], step["values"]
                token = "formal_message_000" + str(values["wire"])
                if action == "HostReceives":
                    row = fixture.submit(token, "synthetic delivery probe")
                    repeated = fixture.submit(token, "synthetic delivery probe")
                    if row != repeated or row["state"] != "queued":
                        raise ValueError("Host submit is not idempotent")
                elif action == "HostDispatch":
                    fixture.request("dispatch")
                    if fixture.status(token)["state"] != "sent":
                        raise ValueError("Host dispatch did not replay")
                elif action == "HostAccepts":
                    fixture.accept("synthetic delivery probe")
                    if fixture.status(token)["state"] != "accepted":
                        raise ValueError("Host acceptance did not replay")
                elif action == "Retry" and values["host"] == "accepted":
                    try:
                        fixture.request("submit", message_id="formal_replacement_0002", text="synthetic delivery probe", replaces=token)
                    except ValueError as error:
                        if str(error) != "message is not retryable":
                            raise
                    else:
                        raise ValueError("Host accepted a duplicate replacement of an accepted message")
                rows.append({"action": action, "model_host": values["host"]})
            if result["trace"][-1]["values"]["host"] == "accepted":
                accepted = fixture.status(token)
                if fixture.submit(token, "synthetic delivery probe") != accepted:
                    raise ValueError("Replaying the original wire ID changed the accepted message")
                try:
                    fixture.request("submit", message_id="formal_replacement_0002", text="synthetic delivery probe", replaces=token)
                except ValueError as error:
                    if str(error) != "message is not retryable":
                        raise
                else:
                    raise ValueError("Host allowed a duplicate replacement after acceptance")
                rows.append({"control": "accepted wire replay is idempotent; replacement refused"})
            host_reports[rule] = rows
        finally:
            fixture.doCleanups()
    (output / "host.json").write_text(json.dumps(host_reports, indent=2) + "\n")
