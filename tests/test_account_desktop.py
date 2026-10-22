from pathlib import Path
import re
import os
import subprocess
import sys
import unittest

ROOT = Path(__file__).resolve().parents[1]
MAIN = subprocess.check_output(['node', 'tools/app-source.js'], cwd=ROOT, encoding='utf-8')
JSON_READER = (ROOT / 'src/json_reader.zig').read_text(encoding='utf-8')
CLIENT = (ROOT / 'src/account_client.zig').read_text(encoding='utf-8')


def function(source, name):
    start = source.index('fn ' + name + '(')
    end = source.find('\nfn ', start + 3)
    return source[start:end if end >= 0 else len(source)]


def locked_spawn(source):
    spawn = function(source, 'spawnShellWithSession')
    return bool(re.search(r'\) bool \{\s*if \(g_account_locked\) return false;', spawn))


class AccountDesktop(unittest.TestCase):
    def test_issue_502_cached_paint_precedes_optimistic_account_startup(self):
        main = function(MAIN, 'main')
        deferred = function(MAIN, 'initializeDeferred')
        self.assertIn('launch_cache.restore();', main)
        self.assertNotIn('accountBootstrap(hwnd)', main)
        bootstrap_call = deferred.index('if (!accountBootstrap(hwnd)) {')
        for call in ('startStaleAltMouseHookThread();', 'CreateJobObjectW(', 'std.Thread.spawn(.{}, ensureUsageTelemetryCollector', 'SetParent(adopt_h', 'restoreSession();', 'restoreRegisteredWorkspaceWindows();'):
            self.assertLess(bootstrap_call, deferred.index(call), call)
        self.assertNotIn('maintainTunnelKeepers();', deferred)
        self.assertIn('if (launch_cache.pending) return 0;\n                maintainTunnelKeepers();', function(MAIN, 'wndProc'))
        bootstrap = function(MAIN, 'accountBootstrap')
        self.assertNotIn('while (g_account_locked)', bootstrap)
        self.assertLess(bootstrap.index('g_account_locked = false;'), bootstrap.index('startAccountJob(.{ .kind = .startup })'))
        claim = function(MAIN, 'accountClaim')
        self.assertIn('MULTIPROMPT_NO_LOGIN', claim)
        self.assertIn("len == 1 and env[0] == '1'", claim)
        reply = function(MAIN, 'handleLayoutReply')
        invalid = reply.split('if (reply.unauthorized) {', 1)[1].split('const bytes =', 1)[0]
        self.assertIn('if (reply.job.kind == .startup)', invalid)
        self.assertIn('accountLock();', invalid)

    def test_all_spawn_and_restore_paths_fail_closed_with_negative_control(self):
        self.assertTrue(locked_spawn(MAIN))
        self.assertFalse(locked_spawn(MAIN.replace('if (g_account_locked) return false;', 'if (false) return false;')))
        self.assertRegex(function(MAIN, 'restoreSession'), r'\) u32 \{\s*if \(g_account_locked\) return 0;')
        self.assertIn('account lock prevents restore and every shell spawn entry point', MAIN)

    def test_locked_input_and_paint_do_not_reach_sidebar_or_actions(self):
        proc = function(MAIN, 'wndProc')
        lock = proc.index('if (g_account_locked)')
        self.assertLess(lock, proc.index('switch (msg)', lock + 10))
        self.assertIn('paintAccountLock(hwnd)', proc[:proc.index('WM_SETTINGCHANGE')])
        self.assertIn('wp == 0x0D', proc[:proc.index('WM_SETTINGCHANGE')])
        self.assertIn('accountButtonRect(hwnd)', proc[:proc.index('WM_SETTINGCHANGE')])
        self.assertIn('else => return DefWindowProcW', proc[:proc.index('WM_SETTINGCHANGE')])
        self.assertNotIn('paintSidebar', function(MAIN, 'paintAccountLock'))
        self.assertIn('if (g_account_locked) return CallNextHookEx', function(MAIN, 'keyboardHookProc'))

    def test_loopback_state_pkce_and_default_browser(self):
        login = function(CLIENT, 'signIn')
        self.assertIn('127.0.0.1:{d}/callback', login)
        self.assertIn('generatePkce', login)
        self.assertIn('state.callback(callback.code, callback.state, callback.oauth_error, pkce.state)', login)
        self.assertIn('code_verifier = pkce.verifier', login)
        self.assertIn('ShellExecuteW(null, L("open")', login)
        self.assertIn('setsockopt(srv, 0xffff, ~@as(i32, 4)', login)
        self.assertIn('GetTickCount64() + 180000', login)
        self.assertIn('0x0100007f', CLIENT)
        self.assertNotIn('Cookie:', CLIENT)
        self.assertNotIn('client_secret', CLIENT)

    def test_dpapi_refresh_rotation_and_explicit_rejection(self):
        worker = function(MAIN, 'accountRequest')
        self.assertIn('readDpapiFile("account-device.dat"', worker)
        self.assertIn('writeDpapiFile("account-device.dat", response.bytes)', worker)
        self.assertIn('account_client.refresh(old)', worker)
        self.assertIn('account_state.invalidCredential(response.status, response.bytes)', worker)
        rejection = worker.split('if (response.status != 200) {', 1)[1].split('if (renewed)', 1)[0]
        self.assertNotIn('accountDeleteToken()', rejection)
        self.assertIn('sync_auth.protect', function(MAIN, 'writeDpapiFile'))
        self.assertIn('sync_auth.unprotect', function(MAIN, 'readDpapiFile'))
        self.assertIn('accountLock();', function(MAIN, 'handleLayoutReply'))

    def test_logout_clears_local_login_before_network_and_cannot_restore_it(self):
        logout = function(MAIN, 'accountSignOut')
        self.assertLess(logout.index('accountDeleteToken();'), logout.index('startAccountJob('))
        self.assertIn('.credential = credential', logout)
        self.assertIn('job.kind != .signout and !writeDpapiFile', function(MAIN, 'accountRequest'))
        self.assertIn('freeSecret(b)', function(MAIN, 'accountJobFree'))
        self.assertIn('accountDeleteToken();', function(MAIN, 'layoutSyncWorker'))

    def test_debounce_poll_conflict_and_durable_diff(self):
        save = function(MAIN, 'publishSessionLayout')
        self.assertIn('account_layout.publishNeeded(local, base.value, synced.value)', save)
        self.assertIn('session_layout.parse(arena.allocator(), g_account_base orelse return)', save)
        self.assertIn('TIMER_ACCOUNT_SAVE, 2000', save)
        self.assertIn('account-layout-pending.json', save)
        self.assertIn('writeFileAtomicW(path, pending)', save)
        self.assertIn('TIMER_ACCOUNT, 20000', function(MAIN, 'accountBootstrap'))
        self.assertIn('account_layout.rebase', function(MAIN, 'accountRequest'))
        self.assertIn('remote.status != 409', function(MAIN, 'accountRequest'))
        self.assertIn('account_layout.rebase', function(MAIN, 'handleLayoutReply'))
        self.assertIn('accountResumeJob(.startup)', MAIN)

    def test_reconciliation_deletes_only_owned_attachments_and_preserves_identity(self):
        apply = function(MAIN, 'applyServerLayout')
        self.assertIn('shells[i].sync_owned and shells[i].tmux_session_len > 0', apply)
        self.assertIn('closeShellRemember(i, false)', apply)
        self.assertIn('shell.sync_owned = true', apply)
        self.assertIn('std.unicode.utf8ToUtf16Le', apply)
        self.assertIn('g_ws_ids[wi] = old_ids[oi]', apply)
        self.assertIn('local_ids[local_cursor]', apply)
        self.assertLess(apply.index('g_restoring = old_restoring;', apply.index('switchToWorkspace(')), apply.index('saveSession();'))
        self.assertNotIn('killRemoteTmuxSession', apply)
        self.assertNotIn('kill-session', apply)
        close = function(MAIN, 'closeShellRemember')
        self.assertNotIn('killRemoteTmuxSession', close)
        self.assertIn('sync_owned', function(MAIN, 'saveSessionTo'))
        self.assertIn('json_reader.sessionTabs', function(MAIN, 'parseSessionTabs'))
        self.assertIn('\"sync_owned\"', JSON_READER)
        self.assertIn('@field(tab, key) = boolTrue(obj, key)', JSON_READER)

    def test_cloud_mode_cannot_publish_a_partial_sibling_window(self):
        mode = function(MAIN, 'toggleSingleWindowMode')
        self.assertLess(mode.index('if (!g_account_bypass)'), mode.index('leaveSingleWindowMode()'))
        spawn = function(MAIN, 'spawnNewWindowImpl')
        self.assertIn('if (!g_account_bypass or g_single_window)', spawn)
        self.assertLess(spawn.index('newWorkspace();'), spawn.index('CreateProcessW('))
        self.assertIn('g_account_locked or !g_account_bypass or g_single_window', function(MAIN, 'detachTabToNewWindow'))
        main = function(MAIN, 'initializeDeferred')
        bootstrap = main.index('if (!accountBootstrap(hwnd)) {')
        for flag in ('g_single_window = true;', 'g_adopt_hwnd = null;', 'g_empty_workspace = false;'):
            self.assertLess(main.index(flag, bootstrap), main.index('startStaleAltMouseHookThread();'))

    def test_one_process_owns_rotating_credentials_until_exit(self):
        bootstrap = function(MAIN, 'accountClaim')
        acquire = bootstrap.index('WaitForSingleObject(mutex, 0)')
        self.assertLess(bootstrap.index("len == 1 and env[0] == '1'"), acquire)
        self.assertIn('startAccountJob(.{ .kind = .startup })', function(MAIN, 'accountBootstrap'))
        self.assertIn('accountResumeJob(.startup)', function(MAIN, 'layoutSyncWorker'))
        main = function(MAIN, 'main')
        self.assertLess(main.index('accountClaim(hwnd)'), main.index('launch_cache.restore();'))
        self.assertIn('result != 0 and result != 0x80', bootstrap)
        self.assertIn('std.hash.Wyhash.hash(0, token_path)', bootstrap)
        self.assertIn('g_account_instance_mutex = mutex;', bootstrap)
        main = function(MAIN, 'main')
        self.assertIn('defer if (g_account_instance_mutex != null)', main)
        self.assertIn('ReleaseMutex(g_account_instance_mutex)', main)
        self.assertIn('CloseHandle(g_account_instance_mutex)', main)
        self.assertNotIn('ReleaseMutex', bootstrap)

    def test_respawn_is_locked_and_preserves_synchronized_provenance(self):
        respawn = function(MAIN, 'respawnShellInPlace')
        self.assertRegex(respawn, r'\) bool \{\s*if \(g_account_locked\) return false;')
        self.assertIn('const saved_sync_owned = shells[idx].sync_owned;', respawn)
        self.assertIn('.sync_owned = saved_sync_owned,', respawn)
        broken = respawn.replace('.sync_owned = saved_sync_owned,', '')
        self.assertNotIn('.sync_owned = saved_sync_owned,', broken)

    def test_ssh_save_publisher_is_removed_not_dual_written(self):
        self.assertNotIn('layoutSshExec', MAIN)
        self.assertNotIn('session_layout_sync', MAIN)
        self.assertNotIn('g_layout_pending', MAIN)
        self.assertIn('publishSessionLayout()', function(MAIN, 'saveSession'))

    def test_palette_help_and_wiki_use_the_same_commands(self):
        rows = MAIN.split('const SHORTCUT_ROWS =', 1)[1].split('\n};', 1)[0]
        docs = (ROOT / 'openwiki/operations/keyboard-shortcuts.md').read_text(encoding='utf-8')
        for label in ('Account: Sign Out', 'Account: Devices', 'Sync: Pull Now'):
            self.assertIn(label, rows)
            self.assertIn(label, docs)
            self.assertIn('L("' + label + '")', MAIN)
        self.assertIn('startAccountJob(.{ .kind = .devices })', MAIN)
        self.assertIn('accountSignOut();', MAIN)

    def test_offline_startup_and_enter_retry_without_browser(self):
        failure = function(MAIN, 'accountSyncFailed')
        self.assertIn('g_account_locked = false;', failure)
        self.assertIn('account_state.failure(g_account_bootstrapping, has_token, false)', failure)
        retry = function(MAIN, 'accountSignIn')
        self.assertLess(retry.index('g_account_has_token and !g_account_reauth'), retry.index('accountResumeJob(.startup)'))
        self.assertLess(retry.index('accountResumeJob(.startup)'), retry.index('accountResumeJob(.login)'))
        self.assertIn('accountResumeJob(.startup)', function(MAIN, 'pullSessionLayout'))
        self.assertNotIn('g_account_base == null', function(MAIN, 'publishSessionLayout'))

    def test_access_cache_precedes_refresh_and_reauth_never_locks_running_terminals(self):
        worker = function(MAIN, 'accountRequest')
        self.assertLess(worker.index('g_account_access.usable('), worker.index('account_client.refresh(old)'))
        self.assertIn('if (renewed) try g_account_access.remember', worker)
        reply = function(MAIN, 'handleLayoutReply')
        invalid = reply.split('if (reply.unauthorized) {', 1)[1].split('const bytes =', 1)[0]
        background = invalid.split('} else {', 1)[1]
        self.assertNotIn('accountLock()', background)
        self.assertIn('g_account_reauth = true;', invalid)
        self.assertIn('Sign in again:', invalid)
        self.assertIn('g_account_locked or g_account_reauth', MAIN)
        self.assertIn('g_account_reauth or g_cap_msg_until > now', MAIN)

    def test_cache_failure_never_blocks_unlock(self):
        prepare = function(MAIN, 'accountPrepareRestore')
        self.assertIn('if (sessionFileIsValid(bytes)) bytes else null', prepare)
        self.assertIn('account_layout.restoreCache', prepare)
        reply = function(MAIN, 'handleLayoutReply')
        failure = reply.split('accountPrepareRestore(to_apply) catch {', 1)[1].split('};', 1)[0]
        self.assertNotIn('return;', failure)
        self.assertNotIn('g_account_locked = was_locked;', reply)

    def test_manual_names_and_tmux_case_follow_source_device(self):
        self.assertIn('.manual = shell.name_source == .manual', function(MAIN, 'captureSessionLayout'))
        apply = function(MAIN, 'applyServerLayout')
        self.assertIn('shell.name_source = if (tab.manual) .manual else .semantic;', apply)
        self.assertIn('tmux_identity.same(s.tmux_host, s.tmux_session[0..s.tmux_session_len], tab.tmux_host, tab.tmux_session)', apply)
        self.assertIn('tmux_identity.same(', function(MAIN, 'findLocalTmuxTab'))

    def test_failure_stops_save_timer_and_only_poll_retries_with_backoff(self):
        self.assertIn('KillTimer(g_main_hwnd, TIMER_ACCOUNT_SAVE)', function(MAIN, 'accountSyncFailed'))
        self.assertIn('if (notify and !g_account_locked)', function(MAIN, 'accountSyncFailed'))
        self.assertIn('!g_account_retry.notified and !g_account_reauth', function(MAIN, 'publishSessionLayout'))
        self.assertIn('!g_account_retry.ready(GetTickCount64())', function(MAIN, 'pullSessionLayout'))
        self.assertIn('g_account_retry.succeeded()', function(MAIN, 'handleLayoutReply'))

    def test_error_callback_and_esc_release_signin_for_retry(self):
        login = function(CLIENT, 'signIn')
        self.assertIn('.denied =>', login)
        self.assertIn('return error.LoginDenied;', login)
        self.assertIn('cancel.load(.acquire)', login)
        self.assertIn('return error.Cancelled;', login)
        self.assertIn('if (wp == 0x1B) accountCancelSignIn();', function(MAIN, 'wndProc'))
        self.assertIn('accountCancelSignIn();', function(MAIN, 'keyboardHookProc'))
        self.assertIn('g_account_login_active = false;', function(MAIN, 'handleLayoutReply'))
        self.assertIn('if (reply.cancelled)', function(MAIN, 'handleLayoutReply'))

    def test_version_matches_window_titles(self):
        self.assertRegex(MAIN, r'const APP_VERSION = "[^"\n]+"')
        self.assertIn('L("multiprompt v" ++ APP_VERSION ++ " [DEV]")', MAIN)
        self.assertIn('L("multiprompt v" ++ APP_VERSION)', MAIN)

    def test_version_matches_latest_changelog(self):
        def version(source):
            match = re.search(r'const APP_VERSION = "(\d+\.\d+\.\d+)";', source)
            return match[1] if match else None
        current = version(MAIN)
        self.assertIsNotNone(current)
        changelog = (ROOT / 'src/changelog.zig').read_text(encoding='utf-8')
        latest = re.search(r'\.ver = "([^"]+)"', changelog)[1]
        self.assertEqual(current, latest)
        self.assertNotEqual(version(MAIN.replace(current, 'changed')), latest)


if __name__ == '__main__':
    if '--format' in sys.argv:
        subprocess.run([os.environ.get('ZIG', 'zig'), 'fmt', '--check', 'src/account_layout.zig', 'src/account_client.zig', 'src/account_state.zig', 'src/session_layout.zig', 'src/main.zig', 'build.zig'], cwd=ROOT, check=True)
        subprocess.run(['git', 'diff', '--check'], cwd=ROOT, check=True)
        print('Formatting and diff verified')
    else:
        result = unittest.TextTestRunner(verbosity=2).run(unittest.defaultTestLoader.loadTestsFromTestCase(AccountDesktop))
        if not result.wasSuccessful(): sys.exit(1)
        print('Desktop account contracts verified')
