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
function wsl.exe {
    if ($args -contains '--exec') { $args[-1] }
    else { $args[-1] -replace '\\', '' }
}
$values = @()
foreach ($name in @('start.ps1', 'drive.ps1')) {
    $tokens = $null
    $errors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile((Join-Path $env:VERIFY_SERVER_CHAT_ROOT ('tools/verify-server-chat/' + $name)), [ref]$tokens, [ref]$errors)
    $calls = $ast.FindAll({ param($node) $node -is [System.Management.Automation.Language.CommandAst] -and $node.GetCommandName() -eq 'wsl.exe' -and @($node.CommandElements | Where-Object { $_.Extent.Text -eq 'wslpath' }).Count -eq 1 }, $true)
    foreach ($call in $calls) { $values += & ([scriptblock]::Create($call.Extent.Text)) }
}
ConvertTo-Json -InputObject $values -Compress
"""
        env = dict(os.environ, VERIFY_SERVER_CHAT_ROOT=str(ROOT))
        paths = json.loads(subprocess.check_output([shell, '-NoProfile', '-Command', command], env=env, text=True))
        self.assertEqual(paths, [r'D:\a path\multiprompt', r'D:\key path\id_ed25519.pub', r'D:\a path\multiprompt', r'D:\evidence path'])


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

    def test_startup_preserves_full_stderr_and_uses_the_process_exit_code(self):
        shell = shutil.which('pwsh') or shutil.which('powershell')
        if shell is None:
            self.skipTest('PowerShell is installed by the Windows verification runner')
        command = r"""
$ErrorActionPreference = 'Stop'
$Evidence = $env:VERIFY_TEST_EVIDENCE
$background = if ($env:VERIFY_TEST_EXIT -eq '0') { "import subprocess; subprocess.Popen([sys.executable, '-c', 'import time; time.sleep(8)'], stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL);" } else { '' }
$startArguments = "-c `"import sys; $background print('seed stdout'); print('traceback line 1\ntraceback line 2', file=sys.stderr); sys.exit($env:VERIFY_TEST_EXIT)`""
function Get-Command { @{ Source = $env:VERIFY_TEST_PYTHON } }
$tokens = $null
$errors = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile((Join-Path $env:VERIFY_SERVER_CHAT_ROOT 'tools/verify-server-chat/start.ps1'), [ref]$tokens, [ref]$errors)
$launch = $ast.Find({ param($node) $node -is [System.Management.Automation.Language.AssignmentStatementAst] -and $node.Left.Extent.Text -eq '$linuxStart' }, $true)
$check = $ast.Find({ param($node) $node -is [System.Management.Automation.Language.IfStatementAst] -and $node.Extent.Text.StartsWith('if ($linuxStart.ExitCode') }, $true)
if ($null -eq $launch -or $null -eq $check) { throw 'Startup must capture the native process and check its exit code' }
$source = Get-Content (Join-Path $env:VERIFY_SERVER_CHAT_ROOT 'tools/verify-server-chat/start.ps1') -Raw
. ([scriptblock]::Create($source.Substring($launch.Extent.StartOffset, $check.Extent.EndOffset - $launch.Extent.StartOffset)))
"""
        for exit_code in (0, 1):
            with self.subTest(exit_code=exit_code), tempfile.TemporaryDirectory(prefix='server chat launch ') as evidence:
                env = dict(os.environ, VERIFY_SERVER_CHAT_ROOT=str(ROOT), VERIFY_TEST_PYTHON=sys.executable, VERIFY_TEST_EXIT=str(exit_code), VERIFY_TEST_EVIDENCE=evidence)
                try:
                    result = subprocess.run([shell, '-NoProfile', '-Command', command], env=env, text=True, capture_output=True, timeout=6)
                except subprocess.TimeoutExpired:
                    self.fail('Startup waited for the background server instead of only its launcher')
                self.assertEqual(result.returncode == 0, exit_code == 0, result.stderr)
                self.assertEqual((Path(evidence) / 'server-start.stdout.log').read_text().strip(), 'seed stdout')
                self.assertEqual((Path(evidence) / 'server-start.stderr.log').read_text().splitlines(), ['traceback line 1', 'traceback line 2'])


if __name__ == '__main__':
    unittest.main()
