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
    const stable_opts = b.addOptions();
    stable_opts.addOption(bool, "is_dev", false);
    exe.root_module.addOptions("build_config", stable_opts);

    b.installArtifact(exe);

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

    const test_step = b.step("test", "Run tests");
    const vps_test_step = b.step("test-vps", "Run tests for the Linux server tools");
    if (b.graph.host.result.os.tag != .windows) test_step.dependOn(vps_test_step);
    test_step.dependOn(&b.addSystemCommand(&.{ "node", "--test", "tools/portable-paths.test.js" }).step);
    const root_images_tests = b.addSystemCommand(&.{ "node", "--test", "tools/root-images.test.js" });
    test_step.dependOn(&root_images_tests.step);
    vps_test_step.dependOn(&root_images_tests.step);
    const chat_perf_tests = b.addTest(.{ .root_module = b.createModule(.{
        .root_source_file = b.path("src/chat_perf_test.zig"),
        .target = b.graph.host,
        .optimize = .ReleaseFast,
    }) });
    const run_chat_perf_tests = b.addRunArtifact(chat_perf_tests);
    b.step("test-chat-perf", "Run native Chat View CPU and 50 MB history regressions").dependOn(&run_chat_perf_tests.step);
    test_step.dependOn(&run_chat_perf_tests.step);
    const chat_cpu_regression = b.addSystemCommand(&.{ "node", "--test", "tools/chat-cpu.test.js" });
    test_step.dependOn(&chat_cpu_regression.step);
    test_step.dependOn(&run_mod_tests.step);
    test_step.dependOn(&run_exe_tests.step);
    test_step.dependOn(&run_usage_telemetry_tests.step);
    const usage_mode_regression = b.addSystemCommand(&.{ "node", "--test", "tools/usage_telemetry_single_exe.test.js" });
    test_step.dependOn(&usage_mode_regression.step);
    const usage_mode_tests = b.addTest(.{ .root_module = b.createModule(.{
        .root_source_file = b.path("src/usage_telemetry_mode.zig"),
        .target = target,
        .optimize = .Debug,
    }) });
    test_step.dependOn(&b.addRunArtifact(usage_mode_tests).step);
    const session_layout_tests = b.addTest(.{ .root_module = b.createModule(.{
        .root_source_file = b.path("src/session_layout.zig"),
        .target = target,
        .optimize = .Debug,
    }) });
    test_step.dependOn(&b.addRunArtifact(session_layout_tests).step);
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
    test_step.dependOn(&b.addRunArtifact(sync_protocol_tests).step);
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
    for ([_][]const u8{ "src/chat_markdown.zig", "src/chat_transcript.zig", "src/chat_switch.zig", "src/chat_history.zig", "src/chat_style.zig", "src/chat_code.zig", "src/chat_echo.zig", "src/chat_image.zig", "src/chat_image_insert.zig" }) |file| {
        const tests = b.addTest(.{ .root_module = b.createModule(.{
            .root_source_file = b.path(file),
            .target = target,
            .optimize = .Debug,
        }) });
        const run = b.addRunArtifact(tests);
        if (previous_chat_run) |previous| run.step.dependOn(previous);
        previous_chat_run = &run.step;
        test_step.dependOn(&run.step);
    }
    const chat_switch_tests = b.addSystemCommand(&.{ "node", "--test", "tools/chat-switch.test.js" });
    test_step.dependOn(&chat_switch_tests.step);
    const palette_rows_tests = b.addSystemCommand(&.{ "node", "--test", "tools/palette-rows.test.js" });
    test_step.dependOn(&palette_rows_tests.step);
    const shortcuts_doc_tests = b.addSystemCommand(&.{ "node", "--test", "tools/shortcuts-doc.test.js" });
    test_step.dependOn(&shortcuts_doc_tests.step);
    const chat_rich_tests = b.addSystemCommand(&.{ "node", "--test", "tools/chat-rich.test.js" });
    test_step.dependOn(&chat_rich_tests.step);
    const chat_autocomplete_tests = b.addSystemCommand(&.{ "node", "--test", "tools/chat-autocomplete.test.js" });
    test_step.dependOn(&chat_autocomplete_tests.step);
    const bridge_tests = b.addTest(.{ .root_module = bridge_exe.root_module });
    const run_bridge_tests = b.addRunArtifact(bridge_tests);
    test_step.dependOn(&run_bridge_tests.step);
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
    const screenshot_pipeline_tests = b.addSystemCommand(&.{ "node", "--test", "tools/screenshot-pipeline.test.js", "tools/screenshot-caret.test.js", "extension/screenshot-shortcut.test.js" });
    test_step.dependOn(&screenshot_pipeline_tests.step);
    const zsb_interaction_tests = b.addSystemCommand(&.{ "node", "--test", "tools/zsb-interaction.test.js", "tools/zsb-recovery.test.js" });
    test_step.dependOn(&zsb_interaction_tests.step);
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
}
