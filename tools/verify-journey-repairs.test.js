const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { execFileSync } = require('node:child_process');
const test = require('node:test');

const root = path.resolve(__dirname, '..');
const read = file => fs.readFileSync(path.join(root, file), 'utf8');

function run(script) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'journey-repair-'));
  try {
    const file = path.join(dir, 'check.ps1');
    fs.writeFileSync(file, `$ErrorActionPreference='Stop'\n${script}`);
    return execFileSync(process.env.PWSH || 'powershell.exe', ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', file], {
      cwd: root, encoding: 'utf8', timeout: 30000,
    });
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
}

const extract = `
function Import-Function([string]$Path, [string]$Name) {
    $tokens=$null; $errors=$null
    $ast=[Management.Automation.Language.Parser]::ParseFile((Join-Path $pwd $Path), [ref]$tokens, [ref]$errors)
    if ($errors.Count) { throw ($errors | Out-String) }
    $found=$ast.Find({param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -ceq $Name}, $true)
    if (!$found) { throw "Missing function $Name" }
    . ([scriptblock]::Create($found.Extent.Text.Replace('function '+$Name, 'function global:'+$Name)))
}
`;

test('bot photo close-tab query selects the current archive-chat action', () => {
  const source = read('tools/verify-bot-photo/drive.ps1');
  assert.match(source, /Query 'close tab' '7110'/);
  assert.match(read('src/command_palette.zig'), /\.target = SEARCH_TABCTX_ARCHIVE/);
  assert.match(read('src/app_state.zig'), /SEARCH_TABCTX_ARCHIVE: usize = 7110/);
});

test('actual 24px palette crop passes the edge oracle while its aliased control fails', { skip: process.platform !== 'win32' }, () => {
  assert.match(run(`${extract}
Add-Type -AssemblyName System.Drawing
Import-Function 'tools/verify-bot-photo/drive.ps1' 'Edge-Blends'
$bitmap=[Drawing.Bitmap]::new((Join-Path $pwd 'tools/fixtures/SOFT-2567/palette-avatar.png'))
try {
    $photo=$bitmap.GetPixel(7,7); $back=$bitmap.GetPixel(0,0)
    $threshold=[Math]::Max(4,[int]($bitmap.Width/8))
    $smooth=Edge-Blends $bitmap $photo $back
    if ($smooth -lt $threshold) { throw "Smooth circle rejected: $smooth < $threshold" }
    for ($y=0; $y -lt $bitmap.Height; $y++) {
        for ($x=0; $x -lt $bitmap.Width; $x++) {
            $pixel=$bitmap.GetPixel($x,$y)
            $nearPhoto=[Math]::Pow($pixel.R-$photo.R,2)+[Math]::Pow($pixel.G-$photo.G,2)+[Math]::Pow($pixel.B-$photo.B,2)
            $nearBack=[Math]::Pow($pixel.R-$back.R,2)+[Math]::Pow($pixel.G-$back.G,2)+[Math]::Pow($pixel.B-$back.B,2)
            $bitmap.SetPixel($x,$y,$(if ($nearPhoto -lt $nearBack) { $photo } else { $back }))
        }
    }
    $aliased=Edge-Blends $bitmap $photo $back
    if ($aliased -ne 0) { throw "Aliased control accepted: $aliased" }
    'EDGE_OK'
} finally { $bitmap.Dispose() }
`), /EDGE_OK/);
});

test('context menu uses the latest target geometry after another tab closes, retaining ordered-action rejection', { skip: process.platform !== 'win32' && !process.env.PWSH }, () => {
  assert.match(run(`${extract}
Import-Function 'tools/verify-session-actions/drive.ps1' 'Context'
Add-Type 'using System; public static class ChatDeliveryDesktop { public static int X,Y; public static void RightClickClient(IntPtr h,uint p,int x,int y) { X=x; Y=y; } }'
$main=[IntPtr]1; $app=@{Id=2}
$trace="[sidebar-avatar] target=1 face=0 color=0\n[bots] face=0 color=0 rect=20,229,56,265\n[photo-proof] expanded target=1 rect=20,229,56,265\n[photo-proof] expanded target=1 rect=20,171,56,207\n[photo-proof] expanded target=2 rect=20,300,56,336\n"
$ordered=$true
function Focus {}
function Log { $trace }
function Wait-For($Name,$Check) {
    if ($Name -eq 'seven ordered context actions') {
        $script:trace += $(if ($ordered) { '[palette] rows chars=0 count=7 ids=7113 7104 7195 7198 7196 7110 7112' } else { '[palette] rows chars=0 count=7 ids=7113 7104 7195 7198 7196 7112 7110' })+"\n"
    }
    $value=& $Check
    if (!$value) { throw "Timed out: $Name" }
    return $value
}
Context 1
if ([ChatDeliveryDesktop]::X -ne 38 -or [ChatDeliveryDesktop]::Y -ne 189) { throw 'Clicked stale or wrong tab bounds' }
$ordered=$false
$rejected=$false
try { Context 1 } catch { if ($_.Exception.Message -ne 'Timed out: seven ordered context actions') { throw }; $rejected=$true }
if (!$rejected) { throw 'Reordered context actions accepted' }
'CONTEXT_OK'
`), /CONTEXT_OK/);
});

test('server group diagnostics redact generated credentials and retain the actual failure', { skip: process.platform !== 'win32' && !process.env.PWSH }, () => {
  assert.match(run(`${extract}
Import-Function '.claude/skills/verify-multiprompt/control-feature-server-open-group.ps1' 'Protect-ServerGroupText'
$privateValues=@('fixture-refresh-token','fixture-pfx-password')
$text=Protect-ServerGroupText 'Desktop process exited: fixture-refresh-token fixture-pfx-password Bearer unknown-token mpk_generated'
foreach ($secret in @('fixture-refresh-token','fixture-pfx-password','unknown-token','mpk_generated')) { if ($text.Contains($secret)) { throw 'Credential leaked' } }
if (!$text.Contains('Desktop process exited:')) { throw 'Actual exception discarded' }
'SANITIZED_OK'
`), /SANITIZED_OK/);
});


test('group readiness accepts mixed local and remote tabs, but rejects missing, wrong and duplicate imports', { skip: process.platform !== 'win32' && !process.env.PWSH }, () => {
  assert.match(run(`${extract}
Set-StrictMode -Version Latest
Import-Function '.claude/skills/verify-multiprompt/control-feature-server-open-group.ps1' 'Test-ServerGroupReady'
foreach ($spec in @(
    @{tabs=@(@{kind='cmd'},@{tmux_session='mp-runner-1';group_id=7});ok=$true},
    @{tabs=@(@{kind='cmd'},@{tmux_session='mp-runner-1'});ok=$false},
    @{tabs=@(@{kind='cmd'},@{tmux_session='mp-runner-1';group_id=8});ok=$false},
    @{tabs=@(@{tmux_session='other';group_id=7});ok=$false},
    @{tabs=@(@{tmux_session='mp-runner-1';group_id=7},@{tmux_session='mp-runner-1';group_id=7});ok=$false}
)) {
    $state=@{groups=@(@{name='Runners';id=7});tabs=$spec.tabs}|ConvertTo-Json -Depth 6|ConvertFrom-Json
    if ((Test-ServerGroupReady $state) -ne $spec.ok) { throw 'Wrong grouped import readiness' }
}
'GROUP_READY_OK'
`), /GROUP_READY_OK/);
});

test('shortcut input accepts its embedded console after restore but never a foreign foreground root', { skip: process.platform !== 'win32' && !process.env.PWSH }, () => {
  assert.match(run(`${extract}
Import-Function 'tools/verify-session-actions/drive.ps1' 'Press'
Add-Type @'
using System;
public static class ChatDeliveryDesktop {
    public static IntPtr Foreground=new IntPtr(1);
    public static IntPtr GetForegroundWindow() { return Foreground; }
    public static uint Owner(IntPtr h) { return 9; }
    public static string Class(IntPtr h) { return "ZigShell"; }
}
public static class VerifyNative {
    public static int Target, Actions, Held;
    public static IntPtr GetAncestor(IntPtr h,int kind) { return h.ToInt64()==2?new IntPtr(1):h; }
    public static void KeyDown(int k) { Held=k; ChatDeliveryDesktop.Foreground=new IntPtr(Target); }
    public static void KeyUp(int k) { Held=0; }
    public static bool IsDown(int k) { return Held==k; }
    public static void Chord(int[] keys) { Actions++; }
}
'@
$main=[IntPtr]1; $app=@{Id=9;HasExited=$false}
$actions=[Collections.Generic.List[object]]::new()
function Focus { throw 'Unexpected focus repair' }
function Wait-For($name,$check) { if (!(& $check)) { throw $name }; $true }
foreach ($target in @(2,3)) {
    [ChatDeliveryDesktop]::Foreground=[IntPtr]1
    [VerifyNative]::Target=$target; [VerifyNative]::Actions=0
    $rejected=$false
    try { Press @(0x11,0x57) } catch {
        if ($_.Exception.Message -ne 'Owned foreground changed while holding modifiers') { throw }
        $rejected=$true
    }
    if ($rejected -ne ($target -eq 3) -or [VerifyNative]::Actions -ne $(if ($target -eq 2) { 1 } else { 0 }) -or [VerifyNative]::Held -ne 0) { throw 'Wrong foreground ownership or modifier cleanup' }
}
'OWNED_SHORTCUT_OK'
`), /OWNED_SHORTCUT_OK/);
});


test('chat rectangle reuse compares file revisions independently of live overlay revisions', () => {
  const source = read('src/chat_session.zig');
  const decode = source.indexOf('const previous_file_revision = app_state.g_chat_last_hash ^ (g_chat_live_drawn_revision *%');
  const changed = source.indexOf('g_chat_live_drawn_revision = live_revision;', decode);
  assert.ok(decode >= 0 && changed > decode, 'decode the old file revision before replacing its live revision');
  assert.match(source, /history.revision == previous_file_revision or entry\.\?\.history.revision == previous_file_revision \+% 1/);
  assert.match(source, /if \(entry\.\?\.history.revision == previous_file_revision\) entry\.\?\.history.last_block else entry\.\?\.history.changed_from/);
  assert.match(source, /app_state.g_chat_last_hash = 0;\s+g_chat_live_drawn_revision = 0;/);
  assert.match(source, /voiceRefreshTranscriptCache\(true\);\s+try std.testing.expect\(app_state.g_chat_layout_reuse \+ 8 >= app_state.g_chat_block_count\)/);
});

test('opening anchor does not override bottom follow after initial history is ready', () => {
  const source = read('src/chat_session.zig');
  const held = [...source.matchAll(/if \(([^\n]*)\) app_state.g_chat_scroll_y = chat_history.openScroll/g)];
  assert.equal(held.length, 2);
  for (const match of held) assert.equal(match[1], 'app_state.g_chat_read_hold and !app_state.g_chat_read_open_ready');
  assert.match(source, /for \(3\.\.5\) \|turn\|/);
  assert.match(source, /expectEqual\(app_state.g_chat_content_h - 600, app_state.g_chat_scroll_y\)/);
});


test('context journey expects the current shared action IDs in their exact production order', () => {
  const state = read('src/app_state.zig');
  const table = read('src/command_palette.zig').split('pub const chat_actions =')[1].split('pub fn chatActionLabel')[0];
  const targets = [...table.matchAll(/\.target = (?:app_state\.)?(SEARCH_\w+)/g)].map(match => {
    const value = state.match(new RegExp(`pub const ${match[1]}: usize = (\\d+);`));
    assert.ok(value, match[1]);
    return Number(value[1]);
  });
  assert.equal(targets.length, 7);
  assert.ok(read('tools/verify-session-actions/drive.ps1').includes(`count=7 ids=${targets.join(' ')}`));
});

test('server group owns launch: its dispatch returns without overwriting evidence and propagates failure', { skip: process.platform !== 'win32' && !process.env.PWSH }, () => {
  const source = read('.claude/skills/verify-multiprompt/control.ps1');
  const clause = source.match(/        'server-open-group' \{[^]*?\n        \}/)?.[0];
  assert.ok(clause, 'dedicated group dispatch exists');
  const delegated = clause.replace(". (Join-Path $PSScriptRoot 'control-feature-server-open-group.ps1')", "$script:visits++; if ($fail) { throw 'delegated failure' }; $script:receipt='passed'");
  assert.notEqual(delegated, clause);
  assert.match(run(`
$Feature='server-open-group'; $visits=0; $receipt=$null
foreach ($fail in @($false,$true)) {
    $rejected=$false
    try {
        & { switch ($Feature) { ${delegated} }; throw 'generic launch overwrote evidence' }
    } catch {
        if ($_.Exception.Message -ne 'delegated failure') { throw }
        $rejected=$true
    }
    if ($rejected -ne $fail) { throw 'Incorrect delegated error result' }
}
if ($visits -ne 2 -or $receipt -ne 'passed') { throw 'Dedicated evidence was not retained' }
'GROUP_DISPATCH_OK'
`), /GROUP_DISPATCH_OK/);
});
