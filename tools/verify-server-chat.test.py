from contextlib import redirect_stdout
import hashlib
import io
import json
import os
from pathlib import Path
import runpy
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
    $calls = $ast.FindAll({ param($node) $node -is [System.Management.Automation.Language.CommandAst] -and $node.GetCommandName() -eq 'Invoke-ServerNative' -and $node.Extent.Text -match 'wslpath' }, $true)
    foreach ($call in $calls) { $values += & ([scriptblock]::Create($call.Extent.Text)) }
}
ConvertTo-Json -InputObject $values -Compress
"""
        env = dict(os.environ, VERIFY_SERVER_CHAT_ROOT=str(ROOT))
        paths = json.loads(subprocess.check_output([shell, '-NoProfile', '-Command', command], env=env, text=True))
        self.assertEqual(paths, [r'D:\a path\multiprompt', r'D:\key path\id_ed25519.pub', r'D:\a path\multiprompt', r'D:\evidence path'])


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
        seed = ROOT / 'tools/verify-server-chat/seed.py'
        execute = runpy.run_path
        for will_be_ready in (True, False):
            with self.subTest(ready=will_be_ready), tempfile.TemporaryDirectory() as home:
                transcript = Path(home) / '.claude/projects/fixture/sid.jsonl'
                transcript.parent.mkdir(parents=True)
                transcript.write_text('Server received: server seed')
                observed = []
                def events(*args):
                    observed.append('poll')
                    if will_be_ready and len(observed) > 1:
                        observed.append('ready')
                        return dict(events=[dict(seq=2, event=dict(kind='host.status', payload=dict(state='ready')))])
                    return dict(events=[])
                def send(*args):
                    self.assertIn('ready', observed, 'The seed was sent before provider readiness')
                    return dict(status='sent')
                reader = dict(host_cli=Mock(return_value=dict(status='enabled')), host_paths=Mock(return_value=dict(config=Path(home) / 'config.json')), host_read=Mock(return_value={}), host_write=Mock(), host_start=Mock(return_value=dict(status='started')), message_events_page=events, host_send=Mock(side_effect=send))
                with patch('runpy.run_path', return_value=reader), patch('subprocess.run'), patch('time.sleep'), patch.object(Path, 'home', return_value=Path(home)), patch.object(sys, 'argv', [str(seed), str(ROOT)]):
                    if will_be_ready:
                        execute(str(seed))
                        reader['host_send'].assert_called_once()
                    else:
                        with self.assertRaisesRegex(RuntimeError, 'provider.*ready'):
                            execute(str(seed))
                        reader['host_send'].assert_not_called()

    def test_replay_seeds_the_actual_provider_transcript_before_starting_the_host(self):
        execute = runpy.run_path
        with tempfile.TemporaryDirectory() as home:
            seeded = []
            def enable(*args):
                transcripts = list((Path(home) / '.claude/projects').glob('*/*.jsonl'))
                self.assertEqual(len(transcripts), 1)
                data = transcripts[0].read_bytes()
                rows = [json.loads(line) for line in data.splitlines()]
                self.assertEqual(len(rows), 2400)
                self.assertEqual(rows[0]['sessionId'], args[0][2])
                self.assertEqual(rows[-1]['message']['content'][0]['text'].splitlines()[0], 'Synthetic chat 00 answer 1199.')
                self.assertTrue(any(block['type'] == 'image' for row in rows for block in row['message']['content']))
                seeded.append(hashlib.sha256(data).hexdigest())
                return dict(status='enabled')
            def send(*args):
                transcript = next((Path(home) / '.claude/projects').glob('*/*.jsonl'))
                with transcript.open('a', encoding='utf-8') as stream:
                    stream.write(json.dumps(dict(text='Server received: server seed')) + '\n')
                return dict(status='sent')
            reader = dict(host_cli=Mock(side_effect=enable), host_paths=Mock(return_value=dict(config=Path(home) / 'config.json')), host_read=Mock(return_value={}), host_write=Mock(), host_start=Mock(return_value=dict(status='started')), message_events_page=Mock(return_value=dict(events=[dict(event=dict(kind='host.status', payload=dict(state='ready')))])), host_send=Mock(side_effect=send))
            def load(path, **kwargs):
                return reader if Path(path) == ROOT / 'src/chat_history_reader.py' else execute(path, **kwargs)
            output = io.StringIO()
            seed = ROOT / 'tools/verify-server-chat/seed.py'
            with patch('runpy.run_path', side_effect=load), patch('subprocess.run'), patch.object(Path, 'home', return_value=Path(home)), patch.object(sys, 'argv', [str(seed), str(ROOT), 'chat-position-replay']), redirect_stdout(output):
                execute(str(seed))
            proof = json.loads(output.getvalue())['fixture']
            self.assertEqual(proof['messages'], 2400)
            self.assertEqual(proof['rounds'], 1200)
            self.assertEqual(proof['sha256'], seeded[0])
            self.assertEqual(proof['generatorRevision'], '60b28893a6b3468c2cf63804c590d5e2978c878d')
            reader['host_send'].assert_called_once()

    def test_replay_loads_every_history_page_before_observation(self):
        shell = shutil.which('pwsh') or shutil.which('powershell')
        if shell is None:
            self.skipTest('PowerShell is installed by the Windows verification runner')
        command = r"""
$ErrorActionPreference = 'Stop'
Add-Type 'public static class ChatDeliveryDesktop { public static bool FocusOwnedWindow(System.IntPtr main, uint pid, System.IntPtr view) { return main.ToInt64() == 10 && pid == 42 && view.ToInt64() == 11; } }'
$main = [IntPtr]::new(10)
$app = [pscustomobject]@{Id=42}
$script:homes = 0
$script:ends = 0
$pages = @($env:VERIFY_HISTORY_PAGES -split ',' | ForEach-Object { [int]$_ })
function Transcript-Window { [IntPtr]::new(11) }
function Copy-Chat($Name) {
    $pairs = $pages[[Math]::Min($script:homes, $pages.Count - 1)]
    (@(for ($i = 1200 - $pairs; $i -lt 1200; $i++) { 'Synthetic chat 00 question {0:D4}. Synthetic chat 00 answer {0:D4}.' -f $i }) -join "`n")
}
function Press($Keys, $Label) {
    if ($Keys[0] -eq 0x24) { $script:homes++ }
    elseif ($Keys[0] -eq 0x23) { $script:ends++ }
    else { throw 'Unexpected history-loading input' }
}
function Wait-For($Name, [scriptblock]$Check, $Seconds) {
    if ($Seconds -le 0) { throw 'History loading must have a deadline' }
    for ($i=0; $i -lt 3; $i++) { $value = & $Check; if ($value) { return $value } }
    throw "Timed out: $Name"
}
$tokens=$null; $errors=$null
$ast = [System.Management.Automation.Language.Parser]::ParseFile((Join-Path $env:VERIFY_SERVER_CHAT_ROOT 'tools/verify-server-chat/drive.ps1'), [ref]$tokens, [ref]$errors)
$helper = $ast.FindAll({param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq 'Copy-LongChat'}, $true)
if ($helper.Count -gt 1) { throw 'Expected one history-loading entry point' }
if ($helper.Count -eq 1) { . ([scriptblock]::Create($helper[0].Extent.Text)) }
$assignment = $ast.FindAll({param($n) $n -is [System.Management.Automation.Language.AssignmentStatementAst] -and $n.Left.Extent.Text -eq '$opened'}, $true)
if ($assignment.Count -ne 1) { throw 'Expected the real server open receipt' }
. ([scriptblock]::Create($assignment[0].Extent.Text))
@{questions=[regex]::Matches($opened, 'Synthetic chat 00 question \d{4}\.').Count; answers=[regex]::Matches($opened, 'Synthetic chat 00 answer \d{4}\.').Count; homes=$script:homes; ends=$script:ends} | ConvertTo-Json -Compress
"""
        for replay, pages, expected in [('1', '1200', (1200, 0, 1)), ('1', '430,860,1200', (1200, 2, 1)), ('1', '430', None), ('', '430', (430, 0, 0))]:
            with self.subTest(replay=replay, pages=pages):
                result = subprocess.run([shell, '-NoProfile', '-Command', command], env=dict(os.environ, VERIFY_SERVER_CHAT_ROOT=str(ROOT), CHAT_POSITION_REPLAY=replay, VERIFY_HISTORY_PAGES=pages), text=True, capture_output=True)
                if expected is None:
                    self.assertNotEqual(result.returncode, 0)
                    self.assertIn('Timed out:', result.stderr)
                else:
                    self.assertEqual(result.returncode, 0, result.stderr)
                    proof = json.loads(result.stdout)
                    self.assertEqual((proof['questions'], proof['homes'], proof['ends']), expected)
                    self.assertEqual(proof['answers'], expected[0])

    def test_stable_observations_do_not_require_another_paint(self):
        shell = shutil.which('pwsh') or shutil.which('powershell')
        if shell is None:
            self.skipTest('PowerShell is installed by the Windows verification runner')
        command = r"""
$ErrorActionPreference = 'Stop'
Add-Type 'public static class ChatDeliveryDesktop { public static ulong GetTickCount64() { return 100; } }'
$phases = [Collections.Generic.List[object]]::new()
$positionShell = 2
function Doctor {}
function Save {}
function Shot {}
function Wait-For {}
$tokens=$null; $errors=$null
$ast = [System.Management.Automation.Language.Parser]::ParseFile((Join-Path $env:VERIFY_SERVER_CHAT_ROOT 'tools/verify-server-chat/position.ps1'), [ref]$tokens, [ref]$errors)
$helper = $ast.Find({param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq 'Observe-ServerPosition'}, $true)
. ([scriptblock]::Create($helper.Extent.Text))
Observe-ServerPosition 'activate-long-open' 'stable' {} 0
Observe-ServerPosition 'idle-long-open' 'stable' {} 0
Observe-ServerPosition 'scroll-old-history' 'user-scroll' {} 0
Observe-ServerPosition 'real-send' 'send' {} 0
$phases.ToArray() | ConvertTo-Json -Compress
"""
        phases = json.loads(subprocess.check_output([shell, '-NoProfile', '-Command', command], env=dict(os.environ, VERIFY_SERVER_CHAT_ROOT=str(ROOT)), text=True))
        self.assertEqual([phase['requirePaint'] for phase in phases], [False, False, True, True])
        self.assertTrue(all(phase['repro'] and phase['shell'] == 2 for phase in phases))

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
