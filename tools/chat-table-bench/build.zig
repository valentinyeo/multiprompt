const std = @import("std");

pub fn build(b: *std.Build) void {
    const source = b.option([]const u8, "source", "Absolute revision checkout path") orelse @panic("-Dsource is required");
    const exe = b.addExecutable(.{
        .name = "chat-table-bench",
        .root_module = b.createModule(.{
            .root_source_file = .{ .cwd_relative = b.pathJoin(&.{ source, "src", "chat_table_bench.zig" }) },
            .target = b.graph.host,
            .optimize = .ReleaseSmall,
            .link_libc = true,
        }),
    });
    exe.stack_size = 64 * 1024 * 1024;
    const options = b.addOptions();
    options.addOption(bool, "is_dev", false);
    exe.root_module.addOptions("build_config", options);
    for ([_][]const u8{ "winhttp", "winmm", "crypt32", "bcrypt", "credui", "wininet", "comdlg32", "shell32" }) |library| {
        exe.root_module.linkSystemLibrary(library, .{});
    }
    b.installArtifact(exe);
}
