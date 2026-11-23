const std = @import("std");

test "SOFT-2445 Waiting means waiting on you, not hidden" {
    const waiting = SessionOverviewRow{ .kind = .open, .attention = true };
    const hidden = SessionOverviewRow{ .kind = .hidden, .attention = false };
    try std.testing.expect(allSessionsRowInTab(&waiting, AS_TAB_WAITING));
    try std.testing.expect(!allSessionsRowInTab(&hidden, AS_TAB_WAITING));
}
