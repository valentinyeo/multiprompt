const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { spawnSync } = require('node:child_process');

const root = process.env.CHAT_REGRESSION_SOURCE_ROOT || path.resolve(__dirname, '..');

function runReader(program) {
  const source = fs.readFileSync(path.join(root, 'src/chat_history_reader.py'), 'utf8');
  const script = String.raw`
import json, subprocess, tempfile, types
from pathlib import Path

outer = {}
exec(compile(${JSON.stringify(source)}, 'reader', 'exec'), outer)

class Pane:
    def __init__(self, height):
        self.height = height
        self.manual = False
        self.box = ''
        self.calls = []
        self.buffers = {}
        self.sent = []

    def screen(self):
        rows = ['older reply line', '─' * 40, '❯ ' + self.box, '─' * 40, '  ? for shortcuts']
        return '\n'.join(rows[-self.height:]) + '\n'

    def run(self, argv, input=None, **kwargs):
        assert argv[0] == 'tmux', argv
        self.calls.append(argv[1])
        op = argv[1]
        out = ''
        if op == 'display-message':
            out = str(self.height) + '\n'
        elif op == 'resize-window':
            self.height = int(argv[argv.index('-y') + 1])
            self.manual = True
        elif op == 'set-option':
            self.manual = False
        elif op == 'capture-pane':
            out = self.screen()
        elif op == 'load-buffer':
            self.buffers[argv[argv.index('-b') + 1]] = input.decode('utf-8')
        elif op == 'paste-buffer':
            self.box = self.buffers[argv[argv.index('-b') + 1]]
        elif op == 'send-keys':
            if argv[-1] == 'Enter' and self.box:
                self.sent.append(self.box)
                self.box = ''
            elif argv[-1] == 'C-u':
                self.box = ''
        elif op in ('delete-buffer', 'list-panes'):
            pass
        else:
            raise AssertionError('unexpected tmux call ' + op)
        return types.SimpleNamespace(returncode=0, stdout=out, stderr='')

def reader(home, pane):
    runtime = {}
    exec(compile(outer['READER_SOURCE'], 'runtime', 'exec'), runtime)
    runtime['HOME'] = Path(home)
    fake = types.SimpleNamespace(run=pane.run, SubprocessError=subprocess.SubprocessError, CalledProcessError=subprocess.CalledProcessError, TimeoutExpired=subprocess.TimeoutExpired)
    runtime['subprocess'] = fake
    runtime['time'] = types.SimpleNamespace(time=runtime['time'].time, sleep=lambda seconds: None, monotonic=runtime['time'].monotonic)
    runtime['resolve_tmux_agent'] = lambda *args, **kwargs: ('synthetic-session', Path(home) / 'synthetic.jsonl')
    return runtime

${program}
`;
  return spawnSync('python3', ['-'], { input: script, encoding: 'utf8', timeout: 30000 });
}

test('IGSH-1923 a plain tmux chat squeezed to one row still receives the message', () => {
  const result = runReader(String.raw`
with tempfile.TemporaryDirectory() as home:
    pane = Pane(1)
    r = reader(home, pane)
    text = 'build me a landing page'
    sent = r['send_response_preserve_draft'](dict(tmux='synthetic-chat', sid='synthetic-session', text=text))
    print(json.dumps(dict(result=sent, delivered=pane.sent, height=pane.height, manual=pane.manual, calls=pane.calls)))
`);
  assert.equal(result.status, 0, result.stderr + result.stdout);
  const outcome = JSON.parse(result.stdout.trim().split('\n').pop());
  assert.deepEqual(outcome.result, { status: 'sent', reason: null }, JSON.stringify(outcome));
  assert.deepEqual(outcome.delivered, ['build me a landing page']);
  assert.ok(outcome.calls.indexOf('resize-window') >= 0 && outcome.calls.indexOf('resize-window') < outcome.calls.indexOf('paste-buffer'), outcome.calls.join(','));
  assert.equal(outcome.manual, false, 'the window goes back to following its attached clients');
});

test('IGSH-1923 a chat at a normal height is never resized', () => {
  const result = runReader(String.raw`
with tempfile.TemporaryDirectory() as home:
    pane = Pane(30)
    r = reader(home, pane)
    sent = r['send_response_preserve_draft'](dict(tmux='synthetic-chat', sid='synthetic-session', text='hello there'))
    print(json.dumps(dict(result=sent, delivered=pane.sent, calls=pane.calls)))
`);
  assert.equal(result.status, 0, result.stderr + result.stdout);
  const outcome = JSON.parse(result.stdout.trim().split('\n').pop());
  assert.equal(outcome.result.status, 'sent', JSON.stringify(outcome));
  assert.deepEqual(outcome.delivered, ['hello there']);
  assert.ok(!outcome.calls.includes('resize-window'));
  assert.ok(!outcome.calls.includes('set-option'));
});
