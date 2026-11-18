import json
import pathlib
import re
import subprocess
import tempfile


def function(source, name):
    match = re.search(r"^(?:pub )?fn " + re.escape(name) + r"\(", source, re.M)
    if match is None:
        raise ValueError("Missing production function " + name)
    end = source.index("\n}", match.start()) + 2
    return source[match.start():end]


def tick(source):
    body = function(source, "chatOutboxTick")
    start = body.index("            if (chat_echo.v1SendingAbandoned(")
    end = body.index("\n            }", start) + len("\n            }")
    return "fn timeout(entry: *ChatOutboxEntry, now_ms: i64) bool {\n    var changed = false;\n" + body[start:end] + "\n    return changed;\n}\n"


def tables(root, output):
    echo = (root / "src/chat_echo.zig").read_text()
    send = (root / "src/chat_send.zig").read_text()
    source = '''const std = @import("std");
const chat_echo = @import("chat_echo.zig");
const ChatOutboxEntry = struct {
    state: chat_echo.OutboxState = .queued,
    sent_tick_ms: i64 = 1000,
    message_v1: bool = true,
    write_started: bool = true,
    channel_sent: bool = false,
    channel_pending: bool = false,
    retryable: bool = false,
};
'''
    source += function(send, "chatEchoWaitsOnTranscript") + "\n" + tick(send)
    source += '''test "formal source decisions" {
    const text = std.unicode.utf8ToUtf16LeStringLiteral("synthetic delivery probe");
    const block = [_]chat_echo.UserBlock{.{ .text = text, .stamp_ms = 200, .message_id = 1 }};
    var pending = [_]chat_echo.Pending{
        .{ .text = text, .prefix = text, .anchor = .{ .after_ms = 100 } },
        .{ .text = text, .prefix = text, .anchor = .{ .after_ms = 100 } },
    };
    var picked: [2]?usize = undefined;
    chat_echo.assign(&pending, &block, false, &.{}, &picked);
    try std.testing.expectEqual(@as(?usize, 0), picked[0]);
    try std.testing.expectEqual(@as(?usize, null), picked[1]);
    var queued = ChatOutboxEntry{};
    var sending = ChatOutboxEntry{ .state = .sending };
    try std.testing.expect(timeout(&queued, 601000));
    try std.testing.expect(timeout(&sending, 601000));
    std.debug.print("FORMAL {{\\\"Reconciles\\\":{},\\\"LoadQueued\\\":\\\"{s}\\\",\\\"LoadSending\\\":\\\"{s}\\\",\\\"ShowQueuedOld\\\":{},\\\"ShowNotSent\\\":{},\\\"ShowDelivered\\\":{},\\\"CanSendQueued\\\":{},\\\"CanSendWritten\\\":{},\\\"TimeoutQueued\\\":\\\"{s}\\\",\\\"TimeoutSending\\\":\\\"{s}\\\"}}\\n", .{
        chatEchoWaitsOnTranscript(.{}) and picked[0] != null,
        @tagName(chat_echo.stateOnLoad(0, true)),
        @tagName(chat_echo.stateOnLoad(1, true)),
        chat_echo.showsNotSent(true, .queued, "sent", 1000, 601000),
        chat_echo.showsNotSent(true, .not_sent, "sent", 1000, 1001),
        chat_echo.showsNotSent(true, .delivered, "accepted", 1000, 1001),
        chat_echo.mayType(.queued, false, false, false),
        chat_echo.mayType(.queued, true, false, false),
        @tagName(queued.state),
        @tagName(sending.state),
    });
}
'''
    output.mkdir(parents=True, exist_ok=True)
    (output / "decisions.zig").write_text(source)
    with tempfile.TemporaryDirectory(prefix="delivery-native-") as directory:
        work = pathlib.Path(directory)
        (work / "decisions.zig").write_text(source)
        (work / "chat_echo.zig").write_text(echo)
        result = subprocess.run(["zig", "test", "-j1", "decisions.zig", "--test-filter", "formal"], cwd=work, text=True, capture_output=True, timeout=90)
    (output / "native.log").write_text(result.stdout + result.stderr)
    if result.returncode:
        raise ValueError("Production decision replay failed; see " + str(output / "native.log"))
    match = re.search(r"FORMAL (\{[^\n]+\})", result.stderr)
    if match is None:
        raise ValueError("Production replay emitted no decision table")
    return json.loads(match[1])
