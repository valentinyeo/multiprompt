import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

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
        with tempfile.TemporaryDirectory() as home:
            program = ROOT / 'tools/verify-server-chat/provider.py'
            script = 'import os,runpy,sys; sys.argv=sys.argv[1:]; home=sys.argv.pop(1); os.environ.update(HOME=home,USERPROFILE=home); runpy.run_path(sys.argv[0],run_name="__main__")'
            requests = [dict(type='user', uuid=f'user-{index}', message=dict(content=[dict(type='text', text=text)])) for index, text in enumerate(('windows send proof', '/clear', 'windows after clear'))]
            result = subprocess.run([sys.executable, '-c', script, str(program), home, '--session-id', 'a1b2c3d4-2567-4000-8000-000000002567'], input=''.join(json.dumps(row) + '\n' for row in requests), text=True, capture_output=True, check=True, cwd=home)
            events = [json.loads(line) for line in result.stdout.splitlines()]
            self.assertEqual(events[0]['subtype'], 'init')
            self.assertEqual([row['message']['content'][0]['text'] for row in events if row['type'] == 'assistant'], ['Server received: ' + request['message']['content'][0]['text'] for request in requests])
            receipts = [json.loads(line) for line in (Path(home) / 'provider-input.jsonl').read_text().splitlines()]
            self.assertEqual([row['text'] for row in receipts], ['windows send proof', '/clear', 'windows after clear'])
            self.assertEqual(len(list((Path(home) / '.claude/projects').glob('*/*.jsonl'))), 1)


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
        script = 'require("node:child_process").execFileSync=()=>JSON.stringify({streams:[{codec_type:"video",nb_frames:"20"}],format:{duration:"2"}});process.argv=["node",process.argv[1],process.argv[2],process.argv[3]];require(process.argv[1]);'
        with tempfile.TemporaryDirectory() as folder:
            evidence = Path(folder)
            for name, text in {'open-copied.txt': 'Server received: server seed Synthetic chat 00 answer 1199.', 'send-copied.txt': 'Server received: windows send proof', 'fresh-copied.txt': 'Synthetic chat 00 answer 1199.', 'replacement-copied.txt': 'Server received: fresh replacement seed', 'replacement-reply-copied.txt': 'Server received: after fresh replacement', 'ssh-preflight.txt': 'Linux tmux Python', 'sshd.log': 'Accepted publickey for mpverify'}.items():
                (evidence / name).write_text(text)
            for name in ('send.png', 'fresh-after.png', 'replacement-fresh-start.png', 'replacement-after.png'):
                (evidence / name).write_bytes(b'x' * 1001)
            for fault in ('none', 'missing handover', 'old host alive', 'wrong native receipt', 'cleanup failed'):
                values = copy.deepcopy(files)
                if fault == 'missing handover':
                    values['fresh-after.json']['inputs'] = []
                elif fault == 'old host alive':
                    values['replacement-after.json']['hosts'][0]['alive'] = True
                elif fault == 'wrong native receipt':
                    values['replacement-after.json']['inputs'][0]['sid'] = 'old-context'
                elif fault == 'cleanup failed':
                    values['result.json']['cleanupError'] = 'cleanup unavailable'
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


if __name__ == '__main__':
    unittest.main()
