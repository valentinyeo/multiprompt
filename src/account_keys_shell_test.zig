const std = @import("std");
const keys = @import("account_keys.zig");

test "remote add is idempotent and removal leaves other keys in a real shell" {
    const a = std.testing.allocator;
    const add = try keys.addCommand(a, "ssh-ed25519 AAAA");
    defer a.free(add);
    const remove = try keys.removeCommand(a, "ssh-ed25519 AAAA");
    defer a.free(remove);
    const script = try std.fmt.allocPrint(a,
        \\set -eu
        \\HOME=$(mktemp -d)
        \\export HOME
        \\trap 'rm -rf "$HOME"' EXIT
        \\{s}
        \\{s}
        \\test "$(awk '$1 == "ssh-ed25519" && $2 == "AAAA" {{ n++ }} END {{ print n+0 }}' ~/.ssh/authorized_keys)" = 1
        \\printf '%s\n' 'ssh-ed25519 BBBB other' 'ssh-rsa AAAA other-type' > "$HOME/expected"
        \\printf '%s\n' 'ssh-ed25519 AAAA comment' 'ssh-ed25519 AAAAB prefix' >> ~/.ssh/authorized_keys
        \\{s}
        \\test "$(awk '$1 == "ssh-ed25519" && $2 == "AAAA" {{ n++ }} END {{ print n+0 }}' ~/.ssh/authorized_keys)" = 2
        \\cat "$HOME/expected" >> ~/.ssh/authorized_keys
        \\{s}
        \\{s}
        \\printf '%s\n' 'ssh-ed25519 AAAAB prefix' > "$HOME/want"
        \\cat "$HOME/expected" >> "$HOME/want"
        \\sed '/^$/d' ~/.ssh/authorized_keys > "$HOME/got"
        \\cmp "$HOME/want" "$HOME/got"
        \\rm ~/.ssh/authorized_keys
        \\{s}
        \\test ! -e ~/.ssh/authorized_keys
        \\printf 'KEY_SHELL_TESTS_OK\n'
    , .{ add, add, add, remove, remove, remove });
    defer a.free(script);
    const result = try std.process.run(a, std.testing.io, .{ .argv = &.{ "sh", "-c", script } });
    defer a.free(result.stdout);
    defer a.free(result.stderr);
    if (result.term != .exited or result.term.exited != 0) std.debug.print("{s}", .{result.stderr});
    try std.testing.expectEqual(std.process.Child.Term{ .exited = 0 }, result.term);
    try std.testing.expectEqualStrings("KEY_SHELL_TESTS_OK\n", result.stdout);
}
