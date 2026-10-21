const std = @import("std");

const MAIN_STACK_SIZE: u64 = 64 * 1024 * 1024;

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const stable_optimize: std.builtin.OptimizeMode = if (optimize == .Debug) .ReleaseSmall else optimize;

    const mod = b.addModule("multiprompt", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
    });

    const exe = b.addExecutable(.{
        .name = "multiprompt",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .link_libc = true,
            .target = target,
            .optimize = stable_optimize,
            .imports = &.{
                .{ .name = "multiprompt", .module = mod },
            },
        }),
    });

    exe.subsystem = .Windows;
    exe.stack_size = MAIN_STACK_SIZE;
    exe.root_module.addWin32ResourceFile(.{ .file = b.path("assets/zigshell.rc") });
    exe.root_module.linkSystemLibrary("winhttp", .{});
    exe.root_module.linkSystemLibrary("winmm", .{});
    exe.root_module.linkSystemLibrary("crypt32", .{});
    exe.root_module.linkSystemLibrary("bcrypt", .{});
    exe.root_module.linkSystemLibrary("credui", .{});
    exe.root_module.linkSystemLibrary("wininet", .{});
    exe.root_module.linkSystemLibrary("comdlg32", .{});
    exe.root_module.linkSystemLibrary("shell32", .{});
    const stable_opts = b.addOptions();
    stable_opts.addOption(bool, "is_dev", false);
    exe.root_module.addOptions("build_config", stable_opts);

    b.installArtifact(exe);

    const probe = b.addExecutable(.{ .name = "font-probe", .root_module = b.createModule(.{
        .root_source_file = b.path("src/font_probe.zig"),
        .target = b.resolveTargetQuery(.{ .cpu_arch = if (target.result.cpu.arch == .aarch64) .aarch64 else .x86_64, .os_tag = .windows, .abi = .gnu }),
        .optimize = .ReleaseSmall,
        .link_libc = true,
    }) });
    probe.root_module.addCSourceFile(.{ .file = b.path("tools/font-probe-dwrite.cpp"), .flags = &.{"-std=c++17"} });
    probe.root_module.link_libcpp = true;
    probe.root_module.linkSystemLibrary("dwrite", .{});
    probe.subsystem = .Windows;
    b.step("font-probe", "Build the windowless chat font raster probe").dependOn(&b.addInstallArtifact(probe, .{}).step);

    const dev_exe = b.addExecutable(.{
        .name = "multiprompt-dev",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .link_libc = true,
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "multiprompt", .module = mod },
            },
        }),
    });
    dev_exe.subsystem = .Windows;
    dev_exe.stack_size = MAIN_STACK_SIZE;
    dev_exe.root_module.addWin32ResourceFile(.{ .file = b.path("assets/zigshell.rc") });
    dev_exe.root_module.linkSystemLibrary("winhttp", .{});
    dev_exe.root_module.linkSystemLibrary("winmm", .{});
    dev_exe.root_module.linkSystemLibrary("crypt32", .{});
    dev_exe.root_module.linkSystemLibrary("bcrypt", .{});
    dev_exe.root_module.linkSystemLibrary("credui", .{});
    dev_exe.root_module.linkSystemLibrary("wininet", .{});
    dev_exe.root_module.linkSystemLibrary("comdlg32", .{});
    dev_exe.root_module.linkSystemLibrary("shell32", .{});
    const dev_opts = b.addOptions();
    dev_opts.addOption(bool, "is_dev", true);
    dev_exe.root_module.addOptions("build_config", dev_opts);
    b.installArtifact(dev_exe);

    const bridge_exe = b.addExecutable(.{
        .name = "zigshell-bridge",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/bridge.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const livetest_exe = b.addExecutable(.{ .name = "mp-livetest", .root_module = b.createModule(.{
        .root_source_file = b.path("tools/live-test-window/main.zig"),
        .target = target,
        .optimize = optimize,
    }) });
    livetest_exe.subsystem = .Console;
    b.installArtifact(livetest_exe);

    const manifest_text = std.Io.Dir.cwd().readFileAlloc(b.graph.io, b.pathFromRoot("extension/manifest.json"), b.allocator, .limited(1024 * 1024)) catch @panic("cannot read extension/manifest.json");
    const manifest = std.json.parseFromSlice(struct { version: []const u8 }, b.allocator, manifest_text, .{ .ignore_unknown_fields = true }) catch @panic("invalid extension/manifest.json");
    const bridge_opts = b.addOptions();
    bridge_opts.addOption([]const u8, "extension_version", manifest.value.version);
    bridge_exe.root_module.addOptions("bridge_config", bridge_opts);
    bridge_exe.subsystem = .Console;
    b.installArtifact(bridge_exe);

    const dev_step = b.step("dev", "Build multiprompt-dev and the browser bridge");
    const dev_install = b.addInstallArtifact(dev_exe, .{});
    const bridge_install = b.addInstallArtifact(bridge_exe, .{});
    dev_step.dependOn(&dev_install.step);
    dev_step.dependOn(&bridge_install.step);

    const run_step = b.step("run", "Run the app");

    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const mod_tests = b.addTest(.{
        .root_module = mod,
    });

    const run_mod_tests = b.addRunArtifact(mod_tests);

    const exe_tests = b.addTest(.{
        .root_module = exe.root_module,
    });

    const run_exe_tests = b.addRunArtifact(exe_tests);
    const main_test_step = b.step("test-main", "Run desktop module tests");
    main_test_step.dependOn(&run_exe_tests.step);

    const usage_telemetry_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/usage_telemetry.zig"),
            .target = target,
            .optimize = .Debug,
            .link_libc = true,
        }),
    });
    usage_telemetry_tests.root_module.linkSystemLibrary("winhttp", .{});
    const run_usage_telemetry_tests = b.addRunArtifact(usage_telemetry_tests);

    const test_step = b.step(if (b.graph.host.result.os.tag == .windows) "test" else "test-desktop", "Run desktop tests");
    const font_tests = b.addTest(.{ .root_module = b.createModule(.{
        .root_source_file = b.path("src/fonts.zig"),
        .target = target,
        .optimize = .Debug,
    }) });
    test_step.dependOn(&b.addRunArtifact(font_tests).step);
    const livetest_tests = b.addTest(.{ .root_module = livetest_exe.root_module });
    test_step.dependOn(&b.addRunArtifact(livetest_tests).step);
    const vps_test_step = b.step("test-vps", "Run tests for the Linux server tools");
    const chat_audit = b.addExecutable(.{ .name = "chat-audit", .root_module = b.createModule(.{
        .root_source_file = b.path("src/chat_audit.zig"),
        .target = b.graph.host,
        .optimize = .ReleaseSafe,
    }) });
    const install_chat_audit = b.addInstallArtifact(chat_audit, .{});
    b.step("chat-audit", "Build and install the host Chat View sync audit").dependOn(&install_chat_audit.step);
    const chat_audit_tests = b.addSystemCommand(&.{ "python3", "tools/chat-sync-audit.test.py" });
    chat_audit_tests.step.dependOn(&install_chat_audit.step);
    vps_test_step.dependOn(&chat_audit_tests.step);
    const chat_send_tests = b.addSystemCommand(&.{ "python3", "tools/chat-tmux-send-test.py" });
    vps_test_step.dependOn(&chat_send_tests.step);
    const chat_send_integration = b.addSystemCommand(&.{ "python3", "tools/chat-tmux-send-test.py", "--integration" });
    vps_test_step.dependOn(&chat_send_integration.step);
    const outbox_test_step = b.step("test-chat-outbox", "Run native outbox delivery and restart tests");
    const chat_send_routing = b.addSystemCommand(&.{ "node", "--test", "tools/chat-tmux-send.test.js", "tools/chat-full-settle.test.js", "tools/chat-delivery.test.js", "tools/chat-outbox-key.test.js", "tools/chat-history-connection.test.js" });
    chat_send_routing.setEnvironmentVariable("ZIG", b.graph.zig_exe);
    vps_test_step.dependOn(&chat_send_routing.step);
    outbox_test_step.dependOn(&chat_send_routing.step);
    const chat_view_gaps_tests = b.addSystemCommand(&.{ "node", "--test", "tools/chat-view-gaps.test.js" });
    vps_test_step.dependOn(&chat_view_gaps_tests.step);
    const chat_reader_tests = b.addSystemCommand(&.{ "python3", "tools/chat-history-reader-test.py" });
    vps_test_step.dependOn(&chat_reader_tests.step);
    const chat_settle_tests = b.addSystemCommand(&.{ "python3", "tools/chat-settle-test.py" });
    vps_test_step.dependOn(&chat_settle_tests.step);
    if (b.graph.host.result.os.tag != .windows) b.step("test", "Run Linux server tests").dependOn(vps_test_step);
    test_step.dependOn(&b.addSystemCommand(&.{ "node", "--test", "tools/portable-paths.test.js" }).step);
    const version_stamp_tests = b.addSystemCommand(&.{ "node", "--test", "tools/version-stamp.test.mjs", "tools/release-version.test.mjs" });
    test_step.dependOn(&version_stamp_tests.step);
    vps_test_step.dependOn(&version_stamp_tests.step);
    const changelog_entry_tests = b.addSystemCommand(&.{ "node", "--test", "tools/changelog-entry.test.js", "tools/changelog-fragment-reads.test.js" });
    test_step.dependOn(&changelog_entry_tests.step);
    vps_test_step.dependOn(&changelog_entry_tests.step);
    const smooth_shapes_tests = b.addSystemCommand(&.{ "node", "--test", "tools/smooth-shapes.test.js" });
    test_step.dependOn(&smooth_shapes_tests.step);
    vps_test_step.dependOn(&smooth_shapes_tests.step);
    const root_images_tests = b.addSystemCommand(&.{ "node", "--test", "tools/root-images.test.js" });
    test_step.dependOn(&root_images_tests.step);
    vps_test_step.dependOn(&root_images_tests.step);
    const chat_perf_tests = b.addTest(.{ .root_module = b.createModule(.{
        .root_source_file = b.path("src/chat_perf_test.zig"),
        .target = b.resolveTargetQuery(.{ .cpu_model = .baseline }),
        .optimize = .ReleaseFast,
    }) });
    const run_chat_perf_tests = b.addRunArtifact(chat_perf_tests);
    b.step("test-chat-perf", "Run native Chat View CPU and 50 MB history regressions").dependOn(&run_chat_perf_tests.step);
    test_step.dependOn(&run_chat_perf_tests.step);
    vps_test_step.dependOn(&run_chat_perf_tests.step);
    const chat_cpu_regression = b.addSystemCommand(&.{ "node", "--test", "tools/chat-cpu.test.js" });
    test_step.dependOn(&chat_cpu_regression.step);
    const chat_bench_tests = b.addSystemCommand(&.{ "node", "--test", "tools/chat-bench.test.mjs" });
    test_step.dependOn(&chat_bench_tests.step);
    vps_test_step.dependOn(&chat_bench_tests.step);
    const chat_bench_ab_summary_tests = b.addSystemCommand(&.{ "node", "--test", "tools/chat-bench-ab-summary.test.js" });
    test_step.dependOn(&chat_bench_ab_summary_tests.step);
    vps_test_step.dependOn(&chat_bench_ab_summary_tests.step);
    const chat_bench_linux_tests = b.addSystemCommand(&.{ "node", "--test", "tools/chat-bench.test.js", "tools/chat-bench/receipt.test.mjs" });
    vps_test_step.dependOn(&chat_bench_linux_tests.step);
    const install_guard_tests = b.addSystemCommand(&.{ "node", "--test", "tools/install-guard.test.js" });
    vps_test_step.dependOn(&install_guard_tests.step);
    test_step.dependOn(&run_mod_tests.step);
    test_step.dependOn(&run_exe_tests.step);
    test_step.dependOn(&run_usage_telemetry_tests.step);
    const launch_regression = b.addSystemCommand(&.{ "node", "--test", "tools/instant-launch.test.js" });
    test_step.dependOn(&launch_regression.step);
    vps_test_step.dependOn(&launch_regression.step);
    const usage_mode_regression = b.addSystemCommand(&.{ "node", "--test", "tools/usage_telemetry_single_exe.test.js" });
    test_step.dependOn(&usage_mode_regression.step);
    const usage_mode_tests = b.addTest(.{ .root_module = b.createModule(.{
        .root_source_file = b.path("src/usage_telemetry_mode.zig"),
        .target = target,
        .optimize = .Debug,
    }) });
    test_step.dependOn(&b.addRunArtifact(usage_mode_tests).step);
    const account_test_step = b.step("test-account", "Run portable account layout and SSH host tests");
    for ([_][]const u8{ "src/account_client.zig", "src/account_hosts.zig", "src/account_keys.zig", "src/account_keys_shell_test.zig", "src/session_layout.zig", "src/account_layout.zig", "src/workspace_view.zig" }) |source| {
        const tests = b.addTest(.{ .root_module = b.createModule(.{
            .root_source_file = b.path(source),
            .target = b.resolveTargetQuery(.{ .cpu_model = .baseline }),
            .optimize = .Debug,
        }) });
        const run_tests = b.addRunArtifact(tests);
        account_test_step.dependOn(&run_tests.step);
        if (std.mem.eql(u8, source, "src/workspace_view.zig")) test_step.dependOn(&run_tests.step);
    }
    vps_test_step.dependOn(account_test_step);
    const session_layout_tests = b.addTest(.{ .root_module = b.createModule(.{
        .root_source_file = b.path("src/session_layout.zig"),
        .target = target,
        .optimize = .Debug,
    }) });
    test_step.dependOn(&b.addRunArtifact(session_layout_tests).step);
    const browser_onscreen_tests = b.addTest(.{ .root_module = b.createModule(.{
        .root_source_file = b.path("src/browser_onscreen.zig"),
        .target = target,
        .optimize = .Debug,
    }) });
    const run_browser_onscreen_tests = b.addRunArtifact(browser_onscreen_tests);
    test_step.dependOn(&run_browser_onscreen_tests.step);
    vps_test_step.dependOn(&run_browser_onscreen_tests.step);
    const browser_onscreen_source = b.addSystemCommand(&.{ "node", "--test", "tools/browser-onscreen.test.js" });
    test_step.dependOn(&browser_onscreen_source.step);
    vps_test_step.dependOn(&browser_onscreen_source.step);
    const account_layout_tests = b.addTest(.{ .root_module = b.createModule(.{
        .root_source_file = b.path("src/account_layout.zig"),
        .target = target,
        .optimize = .Debug,
    }) });
    test_step.dependOn(&b.addRunArtifact(account_layout_tests).step);
    const account_state_tests = b.addTest(.{ .root_module = b.createModule(.{
        .root_source_file = b.path("src/account_state.zig"),
        .target = target,
        .optimize = .Debug,
    }) });
    test_step.dependOn(&b.addRunArtifact(account_state_tests).step);
    const account_desktop_tests = b.addSystemCommand(&.{ "python3", "tests/test_account_desktop.py" });
    test_step.dependOn(&account_desktop_tests.step);
    account_test_step.dependOn(&account_desktop_tests.step);
    const session_layout_sync_tests = b.addTest(.{ .root_module = b.createModule(.{
        .root_source_file = b.path("src/session_layout_sync.zig"),
        .target = target,
        .optimize = .Debug,
    }) });
    test_step.dependOn(&b.addRunArtifact(session_layout_sync_tests).step);
    const session_layout_transport_tests = b.addSystemCommand(&.{ "python3", "tests/session_sync_checks.py", "transport" });
    vps_test_step.dependOn(&session_layout_transport_tests.step);
    const sync_protocol_tests = b.addTest(.{ .root_module = b.createModule(.{
        .root_source_file = b.path("src/sync_protocol.zig"),
        .target = target,
        .optimize = .Debug,
    }) });
    const run_sync_protocol_tests = b.addRunArtifact(sync_protocol_tests);
    test_step.dependOn(&run_sync_protocol_tests.step);
    const sync_auth_tests = b.addTest(.{ .root_module = b.createModule(.{
        .root_source_file = b.path("src/sync_auth.zig"),
        .target = target,
        .optimize = .Debug,
    }) });
    sync_auth_tests.root_module.linkSystemLibrary("crypt32", .{});
    sync_auth_tests.root_module.linkSystemLibrary("bcrypt", .{});
    test_step.dependOn(&b.addRunArtifact(sync_auth_tests).step);
    const sync_vault_tests = b.addTest(.{ .root_module = b.createModule(.{
        .root_source_file = b.path("src/sync_vault.zig"),
        .target = target,
        .optimize = .Debug,
    }) });
    test_step.dependOn(&b.addRunArtifact(sync_vault_tests).step);
    const voice_duplex_tests = b.addTest(.{ .root_module = b.createModule(.{
        .root_source_file = b.path("src/voice_duplex.zig"),
        .target = target,
        .optimize = .Debug,
    }) });
    test_step.dependOn(&b.addRunArtifact(voice_duplex_tests).step);
    const voice_filter_tests = b.addTest(.{ .root_module = b.createModule(.{
        .root_source_file = b.path("src/voice_filter.zig"),
        .target = target,
        .optimize = .Debug,
    }) });
    test_step.dependOn(&b.addRunArtifact(voice_filter_tests).step);
    const attention_rules_tests = b.addTest(.{ .root_module = b.createModule(.{
        .root_source_file = b.path("src/attention_rules.zig"),
        .target = target,
        .optimize = optimize,
    }) });
    test_step.dependOn(&b.addRunArtifact(attention_rules_tests).step);
    const archive_rules_tests = b.addTest(.{ .root_module = b.createModule(.{
        .root_source_file = b.path("src/archive_rules.zig"),
        .target = target,
        .optimize = .Debug,
    }) });
    test_step.dependOn(&b.addRunArtifact(archive_rules_tests).step);
    const link_detect_tests = b.addTest(.{ .root_module = b.createModule(.{
        .root_source_file = b.path("src/link_detect.zig"),
        .target = target,
        .optimize = .Debug,
    }) });
    test_step.dependOn(&b.addRunArtifact(link_detect_tests).step);
    const workspace_snooze_tests = b.addTest(.{ .root_module = b.createModule(.{
        .root_source_file = b.path("src/workspace_snooze.zig"),
        .target = target,
        .optimize = optimize,
    }) });
    test_step.dependOn(&b.addRunArtifact(workspace_snooze_tests).step);
    const reminders_load_tests = b.addTest(.{ .root_module = b.createModule(.{
        .root_source_file = b.path("src/reminders_load.zig"),
        .target = target,
        .optimize = .Debug,
    }) });
    test_step.dependOn(&b.addRunArtifact(reminders_load_tests).step);
    const crash_recorder_tests = b.addTest(.{ .root_module = b.createModule(.{
        .root_source_file = b.path("src/crash_recorder.zig"),
        .target = target,
        .optimize = .Debug,
    }) });
    test_step.dependOn(&b.addRunArtifact(crash_recorder_tests).step);
    const chat_complete_tests = b.addTest(.{ .root_module = b.createModule(.{
        .root_source_file = b.path("src/chat_complete.zig"),
        .target = target,
        .optimize = .Debug,
    }) });
    test_step.dependOn(&b.addRunArtifact(chat_complete_tests).step);
    var previous_chat_run: ?*std.Build.Step = null;
    for ([_][]const u8{ "src/chat_drafts.zig", "src/chat_reply.zig", "src/chat_permission.zig", "src/chat_working.zig", "src/chat_markdown.zig", "src/chat_transcript.zig", "src/chat_switch.zig", "src/chat_history.zig", "src/chat_find.zig", "src/chat_style.zig", "src/chat_code.zig", "src/chat_echo.zig", "src/chat_image.zig", "src/chat_image_insert.zig", "src/chat_drop.zig", "src/chat_diff.zig", "src/dblclick_toggle.zig" }) |file| {
        const tests = b.addTest(.{ .root_module = b.createModule(.{
            .root_source_file = b.path(file),
            .target = b.resolveTargetQuery(.{ .cpu_model = .baseline }),
            .optimize = .Debug,
        }) });
        const run = b.addRunArtifact(tests);
        if (previous_chat_run) |previous| run.step.dependOn(previous);
        previous_chat_run = &run.step;
        test_step.dependOn(&run.step);
        vps_test_step.dependOn(&run.step);
        outbox_test_step.dependOn(&run.step);
    }
    const frequent_tests = b.addTest(.{ .root_module = b.createModule(.{
        .root_source_file = b.path("src/frequent.zig"),
        .target = b.resolveTargetQuery(.{ .cpu_model = .baseline }),
        .optimize = .Debug,
    }) });
    const run_frequent_tests = b.addRunArtifact(frequent_tests);
    test_step.dependOn(&run_frequent_tests.step);
    vps_test_step.dependOn(&run_frequent_tests.step);
    const frequent_integration_tests = b.addSystemCommand(&.{ "node", "--test", "tools/frequent.test.js", "tools/account-used.test.js", "tools/account-hosts.test.js", "tools/account-keys.test.js", "tools/split-settings.test.js" });
    frequent_integration_tests.setEnvironmentVariable("ZIG", b.graph.zig_exe);
    test_step.dependOn(&frequent_integration_tests.step);
    vps_test_step.dependOn(&frequent_integration_tests.step);
    const reply_quote_tests = b.addSystemCommand(&.{ "node", "--test", "tools/reply-quote-fixture.test.js" });
    reply_quote_tests.setEnvironmentVariable("ZIG", b.graph.zig_exe);
    test_step.dependOn(&reply_quote_tests.step);
    vps_test_step.dependOn(&reply_quote_tests.step);
    const chat_skill_tab_tests = b.addSystemCommand(&.{ "node", "--test", "tools/chat-skill-tab.test.js" });
    chat_skill_tab_tests.setEnvironmentVariable("ZIG", b.graph.zig_exe);
    test_step.dependOn(&chat_skill_tab_tests.step);
    vps_test_step.dependOn(&chat_skill_tab_tests.step);
    const chat_drafts_tests = b.addSystemCommand(&.{ "node", "--test", "tools/chat-drafts.test.js" });
    chat_drafts_tests.setEnvironmentVariable("ZIG", b.graph.zig_exe);
    test_step.dependOn(&chat_drafts_tests.step);
    vps_test_step.dependOn(&chat_drafts_tests.step);
    const chat_switch_tests = b.addSystemCommand(&.{ "node", "--test", "tools/chat-switch.test.js", "tools/chat-shell-override.test.js" });
    chat_switch_tests.setEnvironmentVariable("ZIG", b.graph.zig_exe);
    test_step.dependOn(&chat_switch_tests.step);
    vps_test_step.dependOn(&chat_switch_tests.step);
    const one_font_tests = b.addSystemCommand(&.{ "node", "--test", "tools/one-font.test.js", "tools/font-probe.test.js", "tools/chat-font-weight.test.js" });
    test_step.dependOn(&one_font_tests.step);
    vps_test_step.dependOn(&one_font_tests.step);
    const terminal_glyph_tests = b.addSystemCommand(&.{ "node", "--test", "tools/terminal-glyphs.test.js" });
    test_step.dependOn(&terminal_glyph_tests.step);
    vps_test_step.dependOn(&terminal_glyph_tests.step);
    const shell_font_migration_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/themes.zig"),
            .target = b.resolveTargetQuery(.{ .cpu_model = .baseline }),
            .optimize = .Debug,
        }),
        .filters = &.{ "IGSH-443", "IGSH-456" },
    });
    const run_shell_font_migration_tests = b.addRunArtifact(shell_font_migration_tests);
    test_step.dependOn(&run_shell_font_migration_tests.step);
    vps_test_step.dependOn(&run_shell_font_migration_tests.step);
    const console_font_tests = b.addSystemCommand(&.{ "node", "--test", "tools/console-font.test.js" });
    test_step.dependOn(&console_font_tests.step);
    vps_test_step.dependOn(&console_font_tests.step);
    const palette_rows_tests = b.addSystemCommand(&.{ "node", "--test", "tools/palette-rows.test.js" });
    test_step.dependOn(&palette_rows_tests.step);
    const close_all_browser_panes_tests = b.addSystemCommand(&.{ "node", "--test", "tools/close-all-browser-panes.test.js" });
    test_step.dependOn(&close_all_browser_panes_tests.step);
    const shortcuts_doc_tests = b.addSystemCommand(&.{ "node", "--test", "tools/shortcuts-doc.test.js" });
    test_step.dependOn(&shortcuts_doc_tests.step);
    const chat_table_tests = b.addSystemCommand(&.{ "node", "--test", "tools/chat-tables.test.js", "tools/igsh421-tables.test.js" });
    test_step.dependOn(&chat_table_tests.step);
    vps_test_step.dependOn(&chat_table_tests.step);
    const chat_rich_tests = b.addSystemCommand(&.{ "node", "--test", "tools/chat-rich.test.js" });
    test_step.dependOn(&chat_rich_tests.step);
    test_step.dependOn(&chat_view_gaps_tests.step);
    const chat_autocomplete_tests = b.addSystemCommand(&.{ "node", "--test", "tools/chat-autocomplete.test.js" });
    test_step.dependOn(&chat_autocomplete_tests.step);
    const bridge_tests = b.addTest(.{ .root_module = bridge_exe.root_module });
    const run_bridge_tests = b.addRunArtifact(bridge_tests);
    test_step.dependOn(&run_bridge_tests.step);
    b.step("test-bridge", "Run browser bridge unit tests").dependOn(&run_bridge_tests.step);
    const bridge_bad_args_tests = b.addSystemCommand(&.{ "node", "--test", "tools/bridge-bad-args.test.js" });
    bridge_bad_args_tests.step.dependOn(&bridge_install.step);
    bridge_bad_args_tests.setEnvironmentVariable("BRIDGE_EXE", b.getInstallPath(.bin, "zigshell-bridge.exe"));
    test_step.dependOn(&bridge_bad_args_tests.step);
    const zsb_help_tests = b.addSystemCommand(&.{ "node", "--test", "tools/zsb-help.test.js" });
    zsb_help_tests.step.dependOn(&bridge_install.step);
    zsb_help_tests.setEnvironmentVariable("BRIDGE_EXE", b.getInstallPath(.bin, "zigshell-bridge.exe"));
    test_step.dependOn(&zsb_help_tests.step);
    const zsb_help_dispatch_tests = b.addSystemCommand(&.{ "node", "--test", "tools/zsb-help-dispatch.test.js" });
    test_step.dependOn(&zsb_help_dispatch_tests.step);
    const tmux_identity_tests = b.addTest(.{ .root_module = b.createModule(.{
        .root_source_file = b.path("src/tmux_identity.zig"),
        .target = target,
        .optimize = optimize,
    }) });
    test_step.dependOn(&b.addRunArtifact(tmux_identity_tests).step);
    const zsb_who_tests = b.addSystemCommand(&.{ "node", "--test", "tools/zsb-who.test.js" });
    test_step.dependOn(&zsb_who_tests.step);
    const zsb_selftest_tests = b.addSystemCommand(&.{ "node", "--test", "tools/zsb-selftest.test.js", "tools/zsb-selftest-docs.test.js" });
    vps_test_step.dependOn(&zsb_selftest_tests.step);
    const bridge_routing_tests = b.addSystemCommand(&.{ "node", "--test", "extension/bridge-routing.test.js" });
    test_step.dependOn(&bridge_routing_tests.step);
    const bridge_profile_tests = b.addSystemCommand(&.{ "node", "--test", "tools/bridge-profile-pipes.test.js" });
    bridge_profile_tests.step.dependOn(&bridge_install.step);
    bridge_profile_tests.setEnvironmentVariable("BRIDGE_EXE", b.getInstallPath(.bin, "zigshell-bridge.exe"));
    test_step.dependOn(&bridge_profile_tests.step);
    const browser_profile_isolation_tests = b.addSystemCommand(&.{ "node", "--test", "tools/browser-profile-isolation.test.js" });
    test_step.dependOn(&browser_profile_isolation_tests.step);
    const browser_engine_selection_tests = b.addSystemCommand(&.{ "node", "--test", "tools/browser-engine-selection.test.js" });
    test_step.dependOn(&browser_engine_selection_tests.step);
    const zsb_session_isolation_tests = b.addSystemCommand(&.{ "node", "--test", "tools/zsb-session-isolation.test.js" });
    test_step.dependOn(&zsb_session_isolation_tests.step);
    const browser_theme_sync_tests = b.addSystemCommand(&.{ "node", "--test", "tools/browser-theme-sync.test.js" });
    test_step.dependOn(&browser_theme_sync_tests.step);
    const skills_and_sync_login_tests = b.addSystemCommand(&.{ "node", "--test", "tools/skills-and-sync-login.test.js" });
    test_step.dependOn(&skills_and_sync_login_tests.step);
    const system_theme_follow_tests = b.addSystemCommand(&.{ "node", "--test", "tools/system-theme-follow.test.js" });
    test_step.dependOn(&system_theme_follow_tests.step);
    const search_selection_tests = b.addSystemCommand(&.{ "node", "--test", "tools/search-selection.test.js" });
    test_step.dependOn(&search_selection_tests.step);
    const ctrl_t_palette_tests = b.addSystemCommand(&.{ "node", "--test", "tools/ctrl-t-palette-usage.test.js" });
    test_step.dependOn(&ctrl_t_palette_tests.step);
    const sidebar_drag_pin_tests = b.addSystemCommand(&.{ "node", "--test", "tools/sidebar-drag-pin.test.js" });
    test_step.dependOn(&sidebar_drag_pin_tests.step);
    const session_lock_tests = b.addSystemCommand(&.{ "node", "--test", "tools/session-lock.test.js" });
    test_step.dependOn(&session_lock_tests.step);
    const agent_recognition_tests = b.addSystemCommand(&.{ "node", "--test", "tools/agent-recognition.test.js" });
    test_step.dependOn(&agent_recognition_tests.step);
    const capacity_guardian_tests = b.addSystemCommand(&.{ "node", "--test", "tools/capacity-guardian.test.js" });
    test_step.dependOn(&capacity_guardian_tests.step);
    const ai_pace_sidebar_tests = b.addSystemCommand(&.{ "node", "--test", "tools/ai-pace-sidebar.test.js" });
    test_step.dependOn(&ai_pace_sidebar_tests.step);
    const kimi_usage_tests = b.addSystemCommand(&.{ "python", "-m", "unittest", "tools/usage-telemetry/test_kimi_usage.py" });
    test_step.dependOn(&kimi_usage_tests.step);
    const notification_adapter_tests = b.addSystemCommand(&.{ "python3", "-m", "unittest", "discover", "-s", "tools/agent-notifications", "-p", "test_*.py" });
    vps_test_step.dependOn(&notification_adapter_tests.step);
    const multi_monitor_movement_tests = b.addSystemCommand(&.{ "node", "--test", "tools/multi-monitor-movement.test.js" });
    test_step.dependOn(&multi_monitor_movement_tests.step);
    const blue_dot_persistence_tests = b.addSystemCommand(&.{ "node", "--test", "tools/blue-dot-persistence.test.js" });
    test_step.dependOn(&blue_dot_persistence_tests.step);
    const hibernate_hook_recovery_tests = b.addSystemCommand(&.{ "node", "--test", "tools/hibernate-hook-recovery.test.js" });
    test_step.dependOn(&hibernate_hook_recovery_tests.step);
    const ssh_reconnect_tests = b.addSystemCommand(&.{ "node", "--test", "tools/ssh-clock-standby.test.js", "tools/ssh-reconnect.test.js" });
    ssh_reconnect_tests.setEnvironmentVariable("ZIG", b.graph.zig_exe);
    test_step.dependOn(&ssh_reconnect_tests.step);
    vps_test_step.dependOn(&ssh_reconnect_tests.step);
    const screenshot_pipeline_tests = b.addSystemCommand(&.{ "node", "--test", "tools/screenshot-pipeline.test.js", "tools/screenshot-caret.test.js", "extension/screenshot-shortcut.test.js", "tools/issue-509-screenshot-system-menu.test.js", "tools/issue-493-tab-url-shortcut.test.js" });
    test_step.dependOn(&screenshot_pipeline_tests.step);
    const paste_focus_tests = b.addSystemCommand(&.{ "node", "--test", "tools/paste-focus.test.js" });
    test_step.dependOn(&paste_focus_tests.step);
    const shell_focus_tests = b.addSystemCommand(&.{ "node", "--test", "tools/shell-focus.test.js" });
    test_step.dependOn(&shell_focus_tests.step);
    const console_font_lifecycle_tests = b.addSystemCommand(&.{ "node", "--test", "tools/console-font-lifecycle.test.js" });
    console_font_lifecycle_tests.setEnvironmentVariable("ZIG", b.graph.zig_exe);
    test_step.dependOn(&console_font_lifecycle_tests.step);
    vps_test_step.dependOn(&console_font_lifecycle_tests.step);
    const window_flicker_tests = b.addSystemCommand(&.{ "node", "--test", "tools/window-flicker.test.js" });
    window_flicker_tests.setEnvironmentVariable("ZIG", b.graph.zig_exe);
    test_step.dependOn(&window_flicker_tests.step);
    vps_test_step.dependOn(&window_flicker_tests.step);
    const chat_view_console_visibility_tests = b.addSystemCommand(&.{ "node", "--test", "tools/chat-view-console-visibility.test.js", "tools/chat-view-console-return.test.js", "tools/full-width-chat.test.js" });
    chat_view_console_visibility_tests.setEnvironmentVariable("ZIG", b.graph.zig_exe);
    test_step.dependOn(&chat_view_console_visibility_tests.step);
    const zsb_interaction_tests = b.addSystemCommand(&.{ "node", "--test", "tools/zsb-interaction.test.js", "tools/zsb-recovery.test.js" });
    test_step.dependOn(&zsb_interaction_tests.step);
    const zsb_session_open_tests = b.addSystemCommand(&.{ "node", "--test", "tools/zsb-session-open.test.js" });
    test_step.dependOn(&zsb_session_open_tests.step);
    vps_test_step.dependOn(&zsb_session_open_tests.step);
    const zsb_reply_tests = b.addSystemCommand(&.{ "node", "--test", "tools/vps-multiprompt-browser.test.js" });
    vps_test_step.dependOn(&zsb_reply_tests.step);
    const snippet_form_input_tests = b.addSystemCommand(&.{ "node", "--test", "tools/snippet-form-input.test.js" });
    test_step.dependOn(&snippet_form_input_tests.step);
    const console_url_copy_tests = b.addSystemCommand(&.{ "node", "--test", "tools/console-url-copy.test.js" });
    test_step.dependOn(&console_url_copy_tests.step);
    const inbox_undo_shortcut_tests = b.addSystemCommand(&.{ "node", "--test", "tools/inbox-undo-shortcut.test.js" });
    test_step.dependOn(&inbox_undo_shortcut_tests.step);
    const windows_shortcut_passthrough_tests = b.addSystemCommand(&.{ "node", "--test", "tools/windows-shortcut-passthrough.test.js" });
    test_step.dependOn(&windows_shortcut_passthrough_tests.step);
    const inbox_reduction_search_tests = b.addSystemCommand(&.{ "node", "--test", "tools/inbox-reduction-search.test.js" });
    test_step.dependOn(&inbox_reduction_search_tests.step);
    const dictation_paste_tests = b.addSystemCommand(&.{ "node", "--test", "tools/dictation-paste.test.js" });
    test_step.dependOn(&dictation_paste_tests.step);
    const session_state_bucket_tests = b.addSystemCommand(&.{ "node", "--test", "tools/session-state-buckets.test.js" });
    test_step.dependOn(&session_state_bucket_tests.step);
    const other_workspace_invariant_tests = b.addSystemCommand(&.{ "node", "--test", "tools/other-workspace-invariant.test.js" });
    test_step.dependOn(&other_workspace_invariant_tests.step);
    const zig_copy_tests = b.addSystemCommand(&.{ "node", "--test", "tools/zig-copy.test.js" });
    test_step.dependOn(&zig_copy_tests.step);
    vps_test_step.dependOn(&zig_copy_tests.step);
    const test_wiring_tests = b.addSystemCommand(&.{ "node", "--test", "tools/test-wiring.test.js", "tools/heavy-guard.test.js" });
    test_step.dependOn(&test_wiring_tests.step);
    vps_test_step.dependOn(&test_wiring_tests.step);
    const bridge_version_heal_tests = b.addSystemCommand(&.{ "node", "--test", "tools/bridge-version-heal.test.js", "tools/zsb-extension-reload.test.js" });
    bridge_version_heal_tests.setEnvironmentVariable("ZIG_EXE", b.graph.zig_exe);
    test_step.dependOn(&bridge_version_heal_tests.step);
    vps_test_step.dependOn(&bridge_version_heal_tests.step);
    const chat_drop_tests = b.addSystemCommand(&.{ "node", "--test", "tools/chat-drop.test.js", "tools/chat-double-click.test.js", "tools/ssh-upload-reliability.test.js" });
    chat_drop_tests.setEnvironmentVariable("ZIG", b.graph.zig_exe);
    test_step.dependOn(&chat_drop_tests.step);
    vps_test_step.dependOn(&chat_drop_tests.step);
    const crash_reports_tests = b.addSystemCommand(&.{ "node", "--test", "tools/crash-reports.test.js" });
    vps_test_step.dependOn(&crash_reports_tests.step);
    const server_tool_tests = b.addSystemCommand(&.{
        "node",                                   "--test",                              "--test-concurrency=4",
        "tools/app-source.test.js",               "tools/browser-fixed-layout.test.js",  "tools/browser-overlay.test.js",
        "tools/browser-pane-hibernation.test.js", "tools/chat-cache-bound.test.js",      "tools/chat-correctness.test.js",
        "tools/chat-history-reader.test.js",      "tools/chat-reset.test.js",            "tools/chat-tables.test.js",
        "tools/chat-transcript-history.test.js",  "tools/chat_injected.test.js",         "tools/crash-report.test.js",
        "tools/debug-log.test.js",                "tools/favorites.test.js",             "tools/focus-guard.test.js",
        "tools/issue-513-idle-front.test.js",      "tools/idle-cpu.test.js",                 "tools/inbox-eta.test.js",             "tools/inbox-exclude.test.js",
        "tools/power-saver.test.js",              "tools/sidebar-custom-groups.test.js", "tools/token-ladder-panel.test.js",
        "tools/unarchive-semantics.test.js",      "tools/update-card.test.js",           "tools/zsb-active-tab.test.js",
        "tools/zsb-explicit-tab.test.js",         "tools/zsb-pane-binding.test.js",      "extension/focus-guard.test.js",
    });
    server_tool_tests.setEnvironmentVariable("ZIG", b.graph.zig_exe);
    server_tool_tests.setEnvironmentVariable("ZIG_EXE", b.graph.zig_exe);
    vps_test_step.dependOn(&server_tool_tests.step);
    const wine_step = b.step("test-wine", "Run the Wine window tests; build with -Dtarget=x86_64-windows-gnu");
    const wine_tests = b.addSystemCommand(&.{ "node", "--test", "--test-concurrency=1", "tools/live-test-window.test.mjs", "tools/second-launch.test.mjs", "tools/chat-reply.test.mjs", "tools/chat-select.test.mjs" });
    wine_tests.step.dependOn(b.getInstallStep());
    wine_step.dependOn(&wine_tests.step);

    const test_groups = [_]*std.Build.Step{
        b.step("test-group-1", "Run desktop, telemetry and compiler-backed integration tests"),
        b.step("test-group-2", "Run Chat View regression and CPU fixtures"),
        b.step("test-group-3", "Run portable modules, source regressions and SSH fixtures"),
        b.step("test-group-4", "Run sync protocol and desktop interaction fixtures"),
    };
    for (test_step.dependencies.items) |dependency| {
        const group: usize = if (dependency == &run_exe_tests.step or dependency == &run_usage_telemetry_tests.step or
            dependency == &chat_switch_tests.step or dependency == &frequent_integration_tests.step or
            dependency == &chat_drop_tests.step or dependency == &reply_quote_tests.step or
            dependency == &chat_skill_tab_tests.step or dependency == &bridge_version_heal_tests.step)
            0
        else if (dependency == &chat_view_gaps_tests.step or dependency == &run_chat_perf_tests.step or dependency == &chat_cpu_regression.step)
            1
        else if (dependency == &run_sync_protocol_tests.step or dependency == &version_stamp_tests.step or
            dependency == &launch_regression.step or dependency == &chat_table_tests.step or
            dependency == &screenshot_pipeline_tests.step or dependency == &chat_view_console_visibility_tests.step or
            dependency == &zsb_interaction_tests.step)
            3
        else
            2;
        test_groups[group].dependOn(dependency);
    }
    test_step.dependencies.clearRetainingCapacity();
    const selected_group = b.option(u8, "test-group", "Run one desktop test group (1-4)");
    if (selected_group) |group| {
        if (group < 1 or group > test_groups.len) @panic("test-group must be between 1 and 4");
        test_step.dependOn(test_groups[group - 1]);
    } else {
        for (test_groups) |group| test_step.dependOn(group);
    }

    const vps_groups = [_]*std.Build.Step{
        b.step("test-vps-group-1", "Run Chat View, server and compiler-backed integration fixtures"),
        b.step("test-vps-group-2", "Run portable server modules and source regressions"),
    };
    for (vps_test_step.dependencies.items) |dependency| {
        const group: usize = if (dependency == &chat_view_gaps_tests.step or dependency == &run_chat_perf_tests.step or
            dependency == &server_tool_tests.step or dependency == &ssh_reconnect_tests.step or dependency == &chat_switch_tests.step or
            dependency == &frequent_integration_tests.step or dependency == &chat_drop_tests.step or
            dependency == &reply_quote_tests.step or dependency == &chat_skill_tab_tests.step or dependency == &bridge_version_heal_tests.step)
            0
        else
            1;
        vps_groups[group].dependOn(dependency);
    }
    vps_test_step.dependencies.clearRetainingCapacity();
    const selected_vps_group = b.option(u8, "test-vps-group", "Run one server test group (1-2)");
    if (selected_vps_group) |group| {
        if (group < 1 or group > vps_groups.len) @panic("test-vps-group must be between 1 and 2");
        vps_test_step.dependOn(vps_groups[group - 1]);
    } else {
        for (vps_groups) |group| vps_test_step.dependOn(group);
    }
}
