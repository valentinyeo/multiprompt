import hashlib
import json
import os
from pathlib import Path
import runpy
import shutil
import sqlite3
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
                reader = dict(claude_project_folder=lambda cwd: 'server-chat', host_cli=Mock(return_value=dict(status='enabled')), host_paths=Mock(return_value=dict(config=Path(home) / 'config.json')), host_read=Mock(return_value={}), host_write=Mock(), host_start=Mock(return_value=dict(status='started')), message_events_page=events, host_send=Mock(side_effect=send))
                def load(path, **kwargs):
                    return reader if str(path).endswith('src/chat_history_reader.py') else execute(path, **kwargs)
                with patch('runpy.run_path', side_effect=load), patch('subprocess.run'), patch('time.sleep'), patch.object(Path, 'home', return_value=Path(home)), patch.object(sys, 'argv', [str(seed), str(ROOT)]):
                    if will_be_ready:
                        execute(str(seed))
                        reader['host_send'].assert_called_once()
                    else:
                        with self.assertRaisesRegex(RuntimeError, 'provider.*ready'):
                            execute(str(seed))
                        reader['host_send'].assert_not_called()

    def test_server_seed_installs_long_history_before_starting_host(self):
        with tempfile.TemporaryDirectory() as home:
            home = Path(home)
            sid = 'a1b2c3d4-2567-4000-8000-000000002567'
            with patch.dict(os.environ, HOME=str(home), USERPROFILE=str(home)):
                reader = runpy.run_path(str(ROOT / 'src/chat_history_reader.py'))
            transcript = home / '.claude/projects' / reader['claude_project_folder'](str(home)) / (sid + '.jsonl')
            real_run = subprocess.run
            execute = runpy.run_path
            def enable(*args):
                self.assertTrue(transcript.is_file(), 'The server chat must have long history before its host starts')
                self.assertEqual(len(transcript.read_text().splitlines()), 2400)
                return dict(status='enabled')
            def send(*args):
                request = dict(type='user', message=dict(content='server seed'))
                real_run([sys.executable, str(ROOT / 'tools/verify-server-chat/provider.py'), '--resume', sid], input=json.dumps(request) + '\n', env=dict(os.environ, HOME=str(home), USERPROFILE=str(home)), cwd=home, text=True, capture_output=True, check=True)
                return dict(status='sent')
            harness = dict(reader, host_cli=Mock(side_effect=enable), host_read=Mock(return_value={}), host_write=Mock(), host_start=Mock(return_value=dict(status='started')), message_events_page=Mock(return_value=dict(events=[dict(event=dict(kind='host.status', payload=dict(state='ready')))])), host_send=Mock(side_effect=send))
            def load(path, *args, **kwargs):
                return harness if Path(path) == ROOT / 'src/chat_history_reader.py' else execute(path, *args, **kwargs)
            seed = ROOT / 'tools/verify-server-chat/seed.py'
            with patch('runpy.run_path', side_effect=load), patch('subprocess.run'), patch.object(Path, 'home', return_value=home), patch.object(sys, 'argv', [str(seed), str(ROOT)]):
                execute(str(seed))
            rows = [json.loads(line) for line in transcript.read_text().splitlines()]
            self.assertEqual(len(rows), 2402, 'The provider must append its reply without replacing the long chat')
            self.assertIn('Synthetic chat 00 answer 1199.', rows[2399]['message']['content'][0]['text'])
            self.assertIn('| Check |', rows[1]['message']['content'][0]['text'])
            self.assertIn('```python', rows[1]['message']['content'][0]['text'])
            self.assertEqual(rows[0]['message']['content'][1]['type'], 'image')
            manifest = json.loads((home / 'server-chat-fixture.json').read_text())
            self.assertEqual(manifest['messages'], 2400)
            self.assertEqual(manifest['sid'], sid)
            self.assertTrue(manifest['synthetic'])
            prefix = b'\n'.join(transcript.read_bytes().splitlines()[:2400]) + b'\n'
            self.assertEqual(manifest['sha256'], hashlib.sha256(prefix).hexdigest())
            wire = reader['response'](dict(id=7, codex=False, sid=sid, tmux='', cwd=str(home), cached_sid='', inode=0, offset=0))
            self.assertIn('Synthetic chat 00 answer 1199', wire)
            self.assertIn('Server received: server seed', wire)
            store = home / '.local/state/multiprompt/shared-messages/store.sqlite3'
            store.parent.mkdir(parents=True, exist_ok=True)
            with sqlite3.connect(store) as db:
                for table in ('message_chats', 'message_resets', 'shared_messages'):
                    db.execute('CREATE TABLE ' + table + ' (id TEXT)')
            before = transcript.read_bytes()
            snapshot = json.loads(subprocess.check_output([sys.executable, str(ROOT / 'tools/verify-server-chat/snapshot.py')], env=dict(os.environ, HOME=str(home), USERPROFILE=str(home)), text=True))
            self.assertEqual(snapshot['fixture']['transcriptMessages'], 2402)
            self.assertEqual(snapshot['fixture']['sha256'], manifest['sha256'])
            self.assertEqual(transcript.read_bytes(), before)

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
