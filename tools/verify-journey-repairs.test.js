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
        $script:trace += $(if ($ordered) { '[palette] rows chars=0 count=7 ids=7113 7104 7195 7198 7196 7197 7112' } else { '[palette] rows chars=0 count=7 ids=7113 7104 7195 7198 7196 7112 7197' })+"\n"
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
