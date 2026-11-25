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

    def test_pi_auth_adapter_converts_valid_oauth_and_fails_closed(self):
        import base64 as b64
        adapter = ROOT / 'tools/verify-server-chat/pi-auth-adapter.py'

        def make_jwt(payload):
            head = b64.urlsafe_b64encode(json.dumps({'alg': 'RS256'}).encode()).rstrip(b'=').decode()
            body = b64.urlsafe_b64encode(json.dumps(payload).encode()).rstrip(b'=').decode()
            return f'{head}.{body}.sigvalue'

        valid_jwt = make_jwt({'exp': 1900000000, 'https://api.openai.com/auth': {'chatgpt_account_id': 'acct-test-123'}})
        valid_input = json.dumps({
            'auth_mode': 'chatgpt',
            'OPENAI_API_KEY': None,
            'tokens': {
                'access_token': valid_jwt,
                'refresh_token': 'rt-secret-value-xyz',
                'account_id': 'acct-test-123',
            },
        })
        with tempfile.TemporaryDirectory() as tmp:
            pi_out = Path(tmp) / 'pi/auth.json'
            codex_out = Path(tmp) / 'codex/auth.json'
            run = subprocess.run(
                [sys.executable, str(adapter), '--pi-auth-out', str(pi_out), '--codex-auth-out', str(codex_out)],
                input=valid_input,
                text=True,
                capture_output=True,
                check=True,
            )
            self.assertNotIn('rt-secret-value-xyz', run.stdout + run.stderr)
            self.assertNotIn(valid_jwt, run.stdout + run.stderr)
            self.assertNotIn('acct-test-123', run.stdout + run.stderr)
            summary = json.loads(run.stdout)
            self.assertTrue(summary['ok'])
            self.assertEqual(summary['provider'], 'openai-codex')
            self.assertEqual(summary['type'], 'oauth')
            self.assertEqual(summary['expires_ms'], 1900000000000)
            written = json.loads(pi_out.read_text(encoding='utf-8'))
            self.assertEqual(written['openai-codex']['type'], 'oauth')
            self.assertEqual(written['openai-codex']['access'], valid_jwt)
            self.assertEqual(written['openai-codex']['refresh'], 'rt-secret-value-xyz')
            self.assertEqual(written['openai-codex']['expires'], 1900000000000)
            self.assertEqual(written['openai-codex']['accountId'], 'acct-test-123')
            if os.name != 'nt':
                self.assertEqual(os.stat(pi_out).st_mode & 0o777, 0o600)
                self.assertEqual(os.stat(codex_out).st_mode & 0o777, 0o600)
            bad_cases = [
                json.dumps({'OPENAI_API_KEY': 'sk-only'}),
                json.dumps({'auth_mode': 'apikey', 'tokens': {'access_token': valid_jwt, 'refresh_token': 'r'}}),
                json.dumps({'tokens': {'access_token': valid_jwt}}),
                json.dumps({'tokens': {'access_token': 'not-a-jwt', 'refresh_token': 'r'}}),
                json.dumps({'tokens': {'access_token': make_jwt({'exp': 1900000000}), 'refresh_token': 'r'}}),
                json.dumps({'tokens': {'access_token': valid_jwt, 'refresh_token': 'r', 'account_id': 'wrong-acct'}}),
                json.dumps({'tokens': {'access_token': make_jwt({'https://api.openai.com/auth': {'chatgpt_account_id': 'a'}}), 'refresh_token': 'r'}}),
            ]
            for index, bad in enumerate(bad_cases):
                with self.subTest(bad_case=index):
                    bad_out = Path(tmp) / f'bad-{index}/auth.json'
                    failed = subprocess.run(
                        [sys.executable, str(adapter), '--pi-auth-out', str(bad_out)],
                        input=bad,
                        text=True,
                        capture_output=True,
                    )
                    self.assertNotEqual(failed.returncode, 0)
                    self.assertFalse(bad_out.exists())


if __name__ == '__main__':
    unittest.main()
