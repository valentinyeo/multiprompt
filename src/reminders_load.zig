const std = @import("std");

pub const ERROR_FILE_NOT_FOUND: u32 = 2;
pub const ERROR_PATH_NOT_FOUND: u32 = 3;

pub const LoadResult = enum {
    ok,
    missing,
    failed,
    corrupt,
};

pub const BAD_READS_BEFORE_QUARANTINE: u32 = 3;

pub fn classify(opened: bool, open_error: u32, bytes_read: usize, has_array: bool, bad_reads_before: u32) LoadResult {
    if (!opened) {
        return if (open_error == ERROR_FILE_NOT_FOUND or open_error == ERROR_PATH_NOT_FOUND) .missing else .failed;
    }
    if (bytes_read == 0 or !has_array) {
        return if (bad_reads_before + 1 >= BAD_READS_BEFORE_QUARANTINE) .corrupt else .failed;
    }
    return .ok;
}

pub fn mayAutoSave(load_ok: bool) bool {
    return load_ok;
}

test "missing file is a clean start" {
    try std.testing.expectEqual(LoadResult.missing, classify(false, ERROR_FILE_NOT_FOUND, 0, false, 0));
    try std.testing.expectEqual(LoadResult.missing, classify(false, ERROR_PATH_NOT_FOUND, 0, false, 0));
}

test "a busy or unreadable file stays a failed load, never corrupt" {
    try std.testing.expectEqual(LoadResult.failed, classify(false, 32, 0, false, 0));
    try std.testing.expectEqual(LoadResult.failed, classify(false, 5, 0, false, 99));
}

test "an empty or unparsable file is retried, then quarantined" {
    try std.testing.expectEqual(LoadResult.failed, classify(true, 0, 0, false, 0));
    try std.testing.expectEqual(LoadResult.failed, classify(true, 0, 12, false, 1));
    try std.testing.expectEqual(LoadResult.corrupt, classify(true, 0, 0, false, 2));
    try std.testing.expectEqual(LoadResult.corrupt, classify(true, 0, 12, false, 5));
}

test "a parsed file loads" {
    try std.testing.expectEqual(LoadResult.ok, classify(true, 0, 2, true, 0));
    try std.testing.expectEqual(LoadResult.ok, classify(true, 0, 2, true, 7));
}

test "auto saves need a good load" {
    try std.testing.expect(mayAutoSave(true));
    try std.testing.expect(!mayAutoSave(false));
}
