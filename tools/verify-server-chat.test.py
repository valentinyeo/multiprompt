import json
import os
import runpy
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import Mock, patch

ROOT = Path(__file__).resolve().parents[1]


class ProviderTest(unittest.TestCase):
    def setUp(self):
        available = json.loads(subprocess.check_output(['node', '-e', 'console.log(JSON.stringify(require("./tools/verify-features.cjs").discoverFeatures().available))'], cwd=ROOT, text=True))
        self.assertIn('server-chat', available, 'Windows verification must offer the real SSH server journey')
        self.assertIn('server-chat-fresh-start', available, 'Windows verification must offer the ended-owner replacement journey')

    def test_server_fixture_selects_its_three_journeys(self):
        selected = json.loads(subprocess.check_output(['node', '-e', 'console.log(JSON.stringify(require("./tools/touched-journeys.cjs").touchedJourneys(["tools/verify-server-chat/snapshot.py"])))'], cwd=ROOT, text=True))
        self.assertEqual(selected, dict(features=['server-chat', 'server-chat-busy', 'server-chat-fresh-start'], unmapped=[]))

    def test_round_trip_and_clear_reach_the_provider_once(self):
        for cwd, folder in [('/home/mpverify', '-home-mpverify'), (r'D:\a\multiprompt\multiprompt', 'D--a-multiprompt-multiprompt'), (r'\\runner\share\work', '--runner-share-work')]:
            with self.subTest(cwd=cwd), tempfile.TemporaryDirectory() as home:
                program = ROOT / 'tools/verify-server-chat/provider.py'
                script = 'import os,pathlib,runpy,sys; sys.argv=sys.argv[1:]; home=sys.argv.pop(1); cwd=sys.argv.pop(1); os.environ.update(HOME=home,USERPROFILE=home); pathlib.Path.cwd=classmethod(lambda cls: pathlib.PureWindowsPath(cwd) if "\\\\" in cwd else pathlib.PurePosixPath(cwd)); runpy.run_path(sys.argv[0],run_name="__main__")'
                requests = [dict(type='user', uuid=f'user-{index}', message=dict(content=[dict(type='text', text=text)])) for index, text in enumerate(('windows send proof', '/clear', 'windows after clear'))]
                result = subprocess.run([sys.executable, '-c', script, str(program), home, cwd, '--session-id', 'a1b2c3d4-2567-4000-8000-000000002567'], input=''.join(json.dumps(row) + '\n' for row in requests), text=True, capture_output=True, check=True, cwd=home)
                events = [json.loads(line) for line in result.stdout.splitlines()]
                self.assertEqual(events[0]['subtype'], 'init')
                self.assertEqual([row['message']['content'][0]['text'] for row in events if row['type'] == 'assistant'], ['Server received: ' + request['message']['content'][0]['text'] for request in requests])
                receipts = [json.loads(line) for line in (Path(home) / 'provider-input.jsonl').read_text().splitlines()]
                self.assertEqual([row['text'] for row in receipts], ['windows send proof', '/clear', 'windows after clear'])
                transcripts = list((Path(home) / '.claude/projects').glob('*/*.jsonl'))
                self.assertEqual(len(transcripts), 1)
                self.assertEqual(transcripts[0].parent.name, folder)

    def test_busy_provider_accepts_control_without_a_second_turn_and_records_cancelled_input(self):
        with tempfile.TemporaryDirectory() as home:
            program = ROOT / 'tools/verify-server-chat/provider.py'
            script = 'import os,runpy,sys; sys.argv=sys.argv[1:]; home=sys.argv.pop(1); os.environ.update(HOME=home,USERPROFILE=home); runpy.run_path(sys.argv[0],run_name="__main__")'
            requests = [dict(type='user', message=dict(content=[dict(type='text', text=text)])) for text in ('busy server turn', 'follow-up during busy turn')]
            requests.append(dict(type='control_request', request_id='stop-proof', request=dict(subtype='interrupt', cancel_queued=True)))
            result = subprocess.run([sys.executable, '-c', script, str(program), home, '--session-id', 'busy-fixture'], input=''.join(json.dumps(row) + '\n' for row in requests), text=True, capture_output=True, check=True, cwd=home)
            events = [json.loads(line) for line in result.stdout.splitlines()]
            self.assertEqual([row['subtype'] for row in events if row['type'] == 'result'], ['error_during_execution'])
            self.assertEqual(json.loads((Path(home) / 'provider-state.json').read_text())['busy'], False)
            self.assertEqual(len((Path(home) / 'provider-input.jsonl').read_text().splitlines()), 1)
            self.assertEqual(json.loads((Path(home) / 'provider-control.jsonl').read_text())['request']['subtype'], 'interrupt')
            self.assertEqual(json.loads((Path(home) / 'provider-discarded.jsonl').read_text()), requests[1])

    def test_large_seed_preserves_the_selected_session(self):
        import runpy
        seed = runpy.run_path(str(ROOT / '.claude/skills/verify-multiprompt/seed-profile.py'))
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            settings = root / 'roaming/ZigShell'
            settings.mkdir(parents=True)
            selected = '{"tabs":[{"name":"runner chat"}]}\n'
            (settings / 'session.json').write_text(selected)
            manifest = seed['seed'](root, root / 'home')
            self.assertEqual((manifest['sessions'], manifest['messages'], manifest['longChats']), (64, 19872, 8))
            self.assertEqual((settings / 'session.json').read_text(), selected)
            self.assertEqual(len(list(seed['source_rows'](0, 'busy-fixture'))), 2400)


    def test_fresh_start_evidence_requires_matching_lifecycle_and_delivery_proof(self):
        import copy
        old, new = 'old-public', 'new-public'
        resume = dict(sid='fresh-context', pid=2, text='You are the same chat after a fresh start. Read the handover.')
        live = dict(sid=new, native_session='replacement-context', pid=100, alive=True, tmux='live-ci')
        cases = [dict(name=name, passed=True) for name in ('open', 'send', 'fresh-start-rotates', 'replacement-follows', 'replacement-send')]
        files = {
            'result.json': dict(status='passed', feature='server-chat-fresh-start', cases=cases, cleanup=dict(activeAfterStop=0), keyRemoved=True, videoExit=0),
            'fixture-manifest.json': dict(sessions=64, longChats=8, messages=19872),
            'send-server.json': dict(inputs=[dict(text='windows send proof')]),
            'fresh-before.json': dict(provider=dict(pid=1), hosts=[dict(sid=old, native_session='old-context')]),
            'fresh-after.json': dict(provider=dict(pid=2), hosts=[dict(sid=old, native_session='fresh-context', alive=True, freshPhase=None)], inputs=[resume]),
            'replacement.json': dict(old=old, new=new, oldHostGone=True, tmux='live-ci'),
            'replacement-before.json': dict(inputs=[dict(sid=new, text='fresh replacement seed')]),
            'replacement-after.json': dict(hosts=[dict(sid=old, alive=False), live], provider=dict(pid=3), inputs=[dict(text='after fresh replacement', sid='replacement-context', pid=3)]),
            'fresh-tab-after.json': dict(tabs=[dict(name='Runner server chat', tmux_session='live-ci', csid=new)]),
            'actions.json': [dict(input='Enter: fresh start of this chat')] * 2 + [dict(input='replace ended host through production CLI in the same tmux pane')],
            'key-acl.json': dict(protected=True, owner='runner', rules=[dict(sid='runner')]),
            'doctor.json': dict(sha256='abc'), 'build.json': dict(sha256='abc'),
        }
        files['server-start.stdout.log'] = dict(kernel='microsoft-standard-WSL2', blockedWriter='SQLITE_BUSY', integrity='ok', writes=2)
        for name in ('ssh-keygen', 'driver-repo-path', 'start-repo-path', 'public-key-path', 'server-start', 'ssh-keyscan', 'ssh-preflight', 'profile-seed', 'evidence-path', 'server-stop', 'wsl-terminate', 'replacement-start'):
            files[name + '.exit-code.txt'] = 0
            files[name + '.stderr.log'] = ''
        script = 'require("node:child_process").spawnSync=()=>({status:0,stdout:JSON.stringify({streams:[{codec_type:"video",nb_frames:"20"}],format:{duration:"2"}}),stderr:""});process.argv=["node",process.argv[1],process.argv[2],process.argv[3]];require(process.argv[1]);'
        with tempfile.TemporaryDirectory() as folder:
            evidence = Path(folder)
            for name, text in {'open-copied.txt': 'Server received: server seed Synthetic chat 00 answer 1199.', 'send-copied.txt': 'Server received: windows send proof', 'fresh-copied.txt': 'Synthetic chat 00 answer 1199.', 'replacement-copied.txt': 'Server received: fresh replacement seed', 'replacement-reply-copied.txt': 'Server received: after fresh replacement', 'ssh-preflight.txt': 'Linux tmux Python', 'sshd.log': 'Accepted publickey for mpverify'}.items():
                (evidence / name).write_text(text)
            for name in ('send.png', 'fresh-after.png', 'replacement-fresh-start.png', 'replacement-after.png'):
                (evidence / name).write_bytes(b'x' * 1001)
            for fault in ('none', 'missing handover', 'old host alive', 'wrong native receipt', 'cleanup failed', 'native failed', 'lock exclusion missing'):
                values = copy.deepcopy(files)
                if fault == 'missing handover':
                    values['fresh-after.json']['inputs'] = []
                elif fault == 'old host alive':
                    values['replacement-after.json']['hosts'][0]['alive'] = True
                elif fault == 'wrong native receipt':
                    values['replacement-after.json']['inputs'][0]['sid'] = 'old-context'
                elif fault == 'cleanup failed':
                    values['result.json']['cleanupError'] = 'cleanup unavailable'
                elif fault == 'native failed':
                    values['server-start.exit-code.txt'] = 7
                elif fault == 'lock exclusion missing':
                    values['server-start.stdout.log']['blockedWriter'] = 'SQLITE_OK'
                for name, value in values.items():
                    (evidence / name).write_text(json.dumps(value))
                result = subprocess.run(['node', '-e', script, str(ROOT / 'tools/verify-server-chat/check-evidence.cjs'), str(evidence)], capture_output=True, text=True)
                with self.subTest(fault=fault):
                    self.assertEqual(result.returncode == 0, fault == 'none', result.stderr)
            values = copy.deepcopy(files)
            values['result.json']['status'] = 'failed'
            for case in values['result.json']['cases']:
                if case['name'].startswith('replacement-'):
                    case['passed'] = False
            values['replacement-after.json']['inputs'] = []
            values['fresh-tab-after.json']['tabs'][0]['csid'] = old
            (evidence / 'replacement-copied.txt').write_text('The old conversation is still selected')
            for name, value in values.items():
                (evidence / name).write_text(json.dumps(value))
            command = ['node', '-e', script, str(ROOT / 'tools/verify-server-chat/check-evidence.cjs'), str(evidence), '--repro']
            result = subprocess.run(command, capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            values['fresh-tab-after.json']['tabs'][0]['csid'] = new
            (evidence / 'fresh-tab-after.json').write_text(json.dumps(values['fresh-tab-after.json']))
            self.assertNotEqual(subprocess.run(command, capture_output=True).returncode, 0)
            values = copy.deepcopy(files)
            values['result.json']['feature'] = 'server-chat'
            values['result.json']['cases'] = [dict(name=name, passed=True) for name in ('open', 'send', 'clear', 'after-clear')]
            for name in ('fixture-manifest.json', 'profile-seed.exit-code.txt'):
                values.pop(name)
                (evidence / name).unlink()
            for name, text in [('clear', '/clear '), ('after-clear', 'windows after clear')]:
                values[name + '-server.json'] = dict(inputs=[dict(text=text)])
                (evidence / (name + '-copied.txt')).write_text('Server received: ' + text)
                (evidence / (name + '.png')).write_bytes(b'x' * 1001)
            for name, value in values.items():
                (evidence / name).write_text(json.dumps(value))
            (evidence / 'open-copied.txt').write_text('Server received: server seed')
            ordinary = command[:-1]
            result = subprocess.run(ordinary, capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            (evidence / 'clear-server.json').write_text(json.dumps(dict(inputs=[dict(text='/clear')])))
            self.assertNotEqual(subprocess.run(ordinary, capture_output=True).returncode, 0)

    def test_wsl_path_arguments_survive_the_windows_shell_boundary(self):
        shell = shutil.which('pwsh') or shutil.which('powershell')
        if shell is None:
            self.skipTest('PowerShell is installed by the Windows verification runner')
        command = r"""
$env:GITHUB_WORKSPACE = 'D:\a path\multiprompt'
$key = 'D:\key path\id_ed25519'
$Evidence = 'D:\evidence path'
function Invoke-ServerNative($FilePath, $Arguments, $Evidence, $Name) {
    if ($Arguments -contains '--exec') { $Arguments[-1] }
    else { $Arguments[-1] -replace '\\', '' }
}
$values = @()
foreach ($name in @('start.ps1', 'drive.ps1')) {
    $tokens = $null
    $errors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile((Join-Path $env:VERIFY_SERVER_CHAT_ROOT ('tools/verify-server-chat/' + $name)), [ref]$tokens, [ref]$errors)
    if ($errors.Count -ne 0) { throw (($errors | ForEach-Object { $_.Message }) -join '; ') }
    $calls = $ast.FindAll({ param($node) $node -is [System.Management.Automation.Language.CommandAst] -and $node.GetCommandName() -eq 'Invoke-ServerNative' -and $node.Extent.Text -match 'wslpath' }, $true)
    foreach ($call in $calls) { $values += & ([scriptblock]::Create($call.Extent.Text)) }
}
ConvertTo-Json -InputObject $values -Compress
"""
        env = dict(os.environ, VERIFY_SERVER_CHAT_ROOT=str(ROOT))
        paths = json.loads(subprocess.check_output([shell, '-NoProfile', '-Command', command], env=env, text=True))
        self.assertEqual(paths, [r'D:\a path\multiprompt', r'D:\key path\id_ed25519.pub', r'D:\a path\multiprompt', r'D:\evidence path'])


    def test_busy_follow_up_does_not_interrupt_and_fresh_start_query_matches_its_label(self):
        shell = shutil.which('pwsh') or shutil.which('powershell')
        if shell is None:
            self.skipTest('PowerShell is installed by the Windows verification runner')
        command = r"""
$ErrorActionPreference = 'Stop'
Add-Type 'public static class ChatDeliveryDesktop { public static string Value = ""; public static System.IntPtr Composer(System.IntPtr main) { return main; } public static bool FocusOwnedWindow(System.IntPtr main, int pid, System.IntPtr composer) { return true; } public static string Text(System.IntPtr composer) { return Value; } }'
$main = [IntPtr]1
$app = [pscustomobject]@{ Id = 1 }
$script:keys = [Collections.Generic.List[int]]::new()
$script:paletteOpen = $false
$script:log = ''
$script:query = ''
function Log-Text { $script:log }
function Wait-For($Name, $Check) { $value = & $Check; if (-not $value) { throw "Missing fixture condition: $Name" }; $value }
function Press($Keys, $Label) {
    foreach ($key in $Keys) { $script:keys.Add($key) }
    if ($Keys -contains 0x4B) { $script:paletteOpen = $true; $script:log += '[palette] ready chars=0 count=1 target=6498' }
    if ($Keys -contains 0x0D) { [ChatDeliveryDesktop]::Value = ''; $script:paletteOpen = $false }
}
function Type-Text($Text) {
    [ChatDeliveryDesktop]::Value = $Text
    if ($script:paletteOpen) {
        $script:query = $Text
        $target = if ('Chat View: Fresh start'.IndexOf($Text, [StringComparison]::OrdinalIgnoreCase) -ge 0) { 6498 } else { 0 }
        $script:log += "[palette] ready chars=$($Text.Length) count=1 target=$target"
    }
}
$tokens = $null
$errors = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile((Join-Path $env:VERIFY_SERVER_CHAT_ROOT 'tools/verify-server-chat/drive.ps1'), [ref]$tokens, [ref]$errors)
if ($errors.Count) { throw ($errors | Out-String) }
foreach ($name in @('Send-Line', 'Fresh-Chat')) {
    $function = $ast.Find({ param($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq $name }, $true)
    . ([scriptblock]::Create($function.Extent.Text))
}
Send-Line 'ordinary message'
$ordinary = $script:keys.ToArray()
$script:keys.Clear()
Send-Line 'follow-up during busy turn' -DuringTurn
$during = $script:keys.ToArray()
$freshError = $null
try { Fresh-Chat } catch { $freshError = $_.ToString() }
@{ ordinary=$ordinary; during=$during; query=$script:query; freshError=$freshError } | ConvertTo-Json -Compress
"""
        result = subprocess.run([shell, '-NoProfile', '-Command', command], env=dict(os.environ, VERIFY_SERVER_CHAT_ROOT=str(ROOT)), capture_output=True, text=True, check=True)
        observed = json.loads(result.stdout)
        self.assertEqual(observed['ordinary'], [27, 13])
        self.assertEqual(observed['during'], [13], 'Escape would interrupt the busy turn before the real Stop click')
        self.assertIsNone(observed['freshError'])
        self.assertEqual(observed['query'], 'fresh start')

    def test_failed_server_journeys_run_the_strict_reproduction_checker(self):
        import textwrap
        shell = shutil.which('pwsh') or shutil.which('powershell')
        if shell is None:
            self.skipTest('PowerShell is installed by the Windows verification runner')
        workflow = (ROOT / '.github/workflows/verify.yml').read_text()
        step = workflow.split('      - name: Check real server chat evidence\n')[1].split('      - name: Save paired session views')[0]
        self.assertIn('if: always() && !cancelled()', step)
        script = textwrap.dedent(step.split('        run: |\n')[1])
        for feature, status, repro in [('server-chat-busy', 'failed', True), ('server-chat-fresh-start', 'failed', True), ('server-chat-busy', 'passed', False), ('server-chat', 'failed', False)]:
            with self.subTest(feature=feature, status=status), tempfile.TemporaryDirectory() as folder:
                root = Path(folder)
                native = root / 'tools/verify-server-chat/native.ps1'
                native.parent.mkdir(parents=True)
                native.write_text("function Invoke-ServerNative($FilePath, $Arguments, $Evidence, $Name) { [IO.File]::WriteAllText((Join-Path $Evidence 'invocation.json'), (@{ file=$FilePath; arguments=$Arguments; name=$Name } | ConvertTo-Json)) }")
                evidence = root / 'evidence'
                evidence.mkdir()
                (evidence / 'result.json').write_text(json.dumps(dict(feature=feature, status=status)))
                subprocess.run([shell, '-NoProfile', '-Command', script], cwd=root, capture_output=True, text=True, check=True)
                invocation = json.loads((evidence / 'invocation.json').read_text())
                self.assertEqual(invocation['file'], 'node')
                self.assertEqual(invocation['arguments'], ['tools/verify-server-chat/check-evidence.cjs', 'evidence'] + (['--repro'] if repro else []))
                self.assertEqual(invocation['name'], 'check-evidence-repro' if repro else 'check-evidence')

    @unittest.skipIf(os.name == 'nt', 'The lock preflight runs inside the Linux server')
    def test_server_sqlite_lock_preflight(self):
        workflow = (ROOT / '.github/workflows/verify.yml').read_text()
        self.assertIn("wsl-version: '2'", workflow, 'Concurrent SQLite writers require the WSL2 kernel, not WSL1 lock emulation')
        with tempfile.TemporaryDirectory() as home:
            result = subprocess.run([sys.executable, str(ROOT / 'tools/verify-server-chat/check-locks.py')], env=dict(os.environ, HOME=home), text=True, capture_output=True, check=True)
            proof = json.loads(result.stdout)
            self.assertEqual(proof['blockedWriter'], 'SQLITE_BUSY')
            self.assertEqual(proof['integrity'], 'ok')
            self.assertEqual(proof['writes'], 2)
            self.assertEqual(list(Path(home).iterdir()), [])

    def test_seed_waits_for_persisted_provider_readiness(self):
        execute = runpy.run_path
        source_rows = execute(str(ROOT / '.claude/skills/verify-multiprompt/seed-profile.py'))['source_rows']
        for name, large in (('seed.py', False), ('seed.py', True), ('replace-chat.py', False)):
            seed = ROOT / 'tools/verify-server-chat' / name
            for will_be_ready in (True, False):
                with self.subTest(program=name, large=large, ready=will_be_ready), tempfile.TemporaryDirectory() as home:
                    transcript = Path(home) / '.claude/projects/fixture/sid.jsonl'
                    transcript.parent.mkdir(parents=True)
                    transcript.write_text('Server received: server seed')
                    (Path(home) / 'server-seed.json').write_text(json.dumps(dict(runtime=str(ROOT))))
                    observed = []
                    def events(*args):
                        observed.append('poll')
                        if will_be_ready and len(observed) > 1:
                            observed.append('ready')
                            return dict(events=[dict(seq=2, event=dict(kind='host.status', payload=dict(state='ready')))])
                        return dict(events=[])
                    def send(provider, sid, text, tmux):
                        self.assertIn('ready', observed, 'The seed was sent before provider readiness')
                        (Path(home) / 'provider-input.jsonl').write_text(json.dumps(dict(sid=sid, text=text)) + '\n')
                        return dict(status='sent')
                    def cli(argv):
                        return dict(status=dict(enable='enabled', disable='disabled', start='started')[argv[0]])
                    reader = dict(host_cli=Mock(side_effect=cli), host_paths=Mock(return_value=dict(config=Path(home) / 'config.json')), host_session_state=Mock(return_value=dict(pid=0)), host_read=Mock(return_value={}), host_write=Mock(), host_start=Mock(return_value=dict(status='started')), message_events_page=events, host_send=Mock(side_effect=send), source_rows=Mock(side_effect=source_rows))
                    with patch('runpy.run_path', return_value=reader), patch('subprocess.run'), patch('time.sleep'), patch.object(Path, 'home', return_value=Path(home)), patch.object(sys, 'argv', [str(seed), str(ROOT), str(ROOT)] + (['--large'] if large else [])):
                        if will_be_ready:
                            execute(str(seed))
                            reader['host_send'].assert_called_once()
                        else:
                            with self.assertRaisesRegex(RuntimeError, 'provider.*ready'):
                                execute(str(seed))
                            reader['host_send'].assert_not_called()
                    if name == 'seed.py':
                        metadata = json.loads((Path(home) / 'server-seed.json').read_text())
                        self.assertEqual(metadata['messages'], 2400 if large else 0)
                        self.assertEqual(metadata['runtime'], str(ROOT))

    def test_native_commands_preserve_stderr_and_check_exit_codes(self):
        shell = shutil.which('pwsh') or shutil.which('powershell')
        if shell is None:
            self.skipTest('PowerShell is installed by the Windows verification runner')
        command = r"""
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true
. (Join-Path $env:VERIFY_SERVER_CHAT_ROOT 'tools/verify-server-chat/native.ps1')
$output = Invoke-ServerNative -FilePath $env:VERIFY_TEST_PYTHON -Arguments @($env:VERIFY_TEST_PROGRAM, 'a path', '', 'embedded"quote', 'trailing\', $env:VERIFY_TEST_EXIT) -Evidence $env:VERIFY_TEST_EVIDENCE -Name 'native'
if ($ErrorActionPreference -ne 'Stop') { throw 'Native execution changed PowerShell error policy' }
$output
"""
        for exit_code in (0, 7):
            with self.subTest(exit_code=exit_code), tempfile.TemporaryDirectory(prefix='server chat launch ') as evidence:
                program = Path(evidence) / 'native child.py'
                program.write_text("import json,subprocess,sys; subprocess.Popen([sys.executable,'-c','import time; time.sleep(8)'],stdin=subprocess.DEVNULL,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL); print(json.dumps(sys.argv[1:-1])); print('# 127.0.0.1:2222 SSH-2.0-OpenSSH',file=sys.stderr); print('traceback line 2',file=sys.stderr); sys.exit(int(sys.argv[-1]))")
                env = dict(os.environ, VERIFY_SERVER_CHAT_ROOT=str(ROOT), VERIFY_TEST_PYTHON=sys.executable, VERIFY_TEST_PROGRAM=str(program), VERIFY_TEST_EXIT=str(exit_code), VERIFY_TEST_EVIDENCE=evidence)
                try:
                    result = subprocess.run([shell, '-NoProfile', '-Command', command], env=env, text=True, capture_output=True, timeout=6)
                except subprocess.TimeoutExpired:
                    self.fail('Native execution waited for a background descendant instead of only its launcher')
                self.assertEqual(result.returncode == 0, exit_code == 0, result.stderr)
                self.assertEqual(json.loads((Path(evidence) / 'native.stdout.log').read_text()), ['a path', '', 'embedded"quote', 'trailing\\'])
                self.assertEqual((Path(evidence) / 'native.stderr.log').read_text().splitlines(), ['# 127.0.0.1:2222 SSH-2.0-OpenSSH', 'traceback line 2'])
                self.assertEqual((Path(evidence) / 'native.exit-code.txt').read_text().strip(), str(exit_code))
                if exit_code:
                    self.assertIn('exited 7', result.stderr)
                else:
                    self.assertEqual(json.loads(result.stdout), ['a path', '', 'embedded"quote', 'trailing\\'])

    def test_wsl_switches_remain_unquoted_on_the_native_command_line(self):
        shell = shutil.which('pwsh') or shutil.which('powershell')
        if shell is None:
            self.skipTest('PowerShell is installed by the Windows verification runner')
        command = r"""
$ErrorActionPreference = 'Stop'
. (Join-Path $env:VERIFY_SERVER_CHAT_ROOT 'tools/verify-server-chat/native.ps1')
function Get-Command { @{ Source = 'wsl.exe' } }
function Start-Process($FilePath, $ArgumentList, $RedirectStandardOutput, $RedirectStandardError, [switch]$NoNewWindow, [switch]$PassThru) {
    [IO.File]::WriteAllText($RedirectStandardOutput, '')
    [IO.File]::WriteAllText($RedirectStandardError, '')
    $process = [pscustomobject]@{ Handle = 1; ExitCode = 0 }
    $process | Add-Member -MemberType ScriptMethod -Name WaitForExit -Value {}
    $process | Add-Member -MemberType ScriptMethod -Name Dispose -Value {}
    return $process
}
[void](Invoke-ServerNative -FilePath wsl.exe -Arguments @('-d', 'Ubuntu-24.04', '-u', 'root', '--exec', 'wslpath', '-a', 'D:\a path\multiprompt') -Evidence $env:VERIFY_TEST_EVIDENCE -Name 'path')
[void](Invoke-ServerNative -FilePath wsl.exe -Arguments @('--terminate', 'Ubuntu-24.04') -Evidence $env:VERIFY_TEST_EVIDENCE -Name 'terminate')
"""
        with tempfile.TemporaryDirectory() as evidence:
            subprocess.run([shell, '-NoProfile', '-Command', command], env=dict(os.environ, VERIFY_SERVER_CHAT_ROOT=str(ROOT), VERIFY_TEST_EVIDENCE=evidence), check=True, text=True, capture_output=True)
            self.assertEqual((Path(evidence) / 'path.command-line.txt').read_text(), '-d Ubuntu-24.04 -u root --exec wslpath -a "D:\\a path\\multiprompt"')
            self.assertEqual((Path(evidence) / 'terminate.command-line.txt').read_text(), '--terminate Ubuntu-24.04')

    def test_native_commands_cannot_bypass_the_shared_boundary(self):
        shell = shutil.which('pwsh') or shutil.which('powershell')
        if shell is None:
            self.skipTest('PowerShell is installed by the Windows verification runner')
        command = r"""
$ErrorActionPreference = 'Stop'
foreach ($path in Get-ChildItem (Join-Path $env:VERIFY_SERVER_CHAT_ROOT 'tools/verify-server-chat/*.ps1')) {
    $tokens = $null
    $errors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($path.FullName, [ref]$tokens, [ref]$errors)
    if ($errors.Count) { throw ($errors | Out-String) }
    $blocks = @($ast.FindAll({ param($node) $node -is [System.Management.Automation.Language.ParameterAst] -and $node.StaticType -eq [scriptblock] }, $true) | ForEach-Object { $_.Name.Extent.Text })
    foreach ($call in $ast.FindAll({ param($node) $node -is [System.Management.Automation.Language.CommandAst] }, $true)) {
        $name = $call.GetCommandName()
        $scriptCall = $call.CommandElements[0].Extent.Text -match '\.ps1["'']?$'
        if (($call.InvocationOperator -eq 'Ampersand' -and -not $scriptCall -and $call.CommandElements[0].Extent.Text -notin $blocks) -or $name -match '(?i)(\.exe$|^python[0-9]*$|^ssh|^ffmpeg|^ffprobe|^wsl$)' -or ($name -eq 'Start-Process' -and $path.Name -ne 'native.ps1')) {
            throw "$($path.Name):$($call.Extent.StartLineNumber): Use Invoke-ServerNative for native commands so exit codes decide success and stderr reaches evidence"
        }
    }
}
"""
        result = subprocess.run([shell, '-NoProfile', '-Command', command], env=dict(os.environ, VERIFY_SERVER_CHAT_ROOT=str(ROOT)), text=True, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stderr)


if __name__ == '__main__':
    unittest.main()
