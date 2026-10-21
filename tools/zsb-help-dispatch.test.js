const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');

const source = fs.readFileSync(process.env.ZSB_HELP_SOURCE || path.join(__dirname, '..', 'src/bridge.zig'), 'utf8');
const main = source.slice(source.indexOf('pub fn main('), source.indexOf('const usage_text ='));

test('shared help dispatch precedes targeting, profile validation and every command handler', () => {
  const guard = main.indexOf('return commandHelp(command)');
  assert.ok(guard >= 0, 'Missing shared local command help dispatch');
  const probe = main.slice(main.indexOf('var help_args = args;'), guard);
  assert.match(probe, /help_args\.next\(\)/);
  assert.match(probe, /std\.mem\.eql\(u8, arg, "--help"\)/);
  assert.match(probe, /std\.mem\.eql\(u8, arg, "-h"\)/);
  for (const operation of ['resolveWindowFromEnv(allocator)', 'runProfileClone(', 'const profile_env =', 'isolatedPipeName(', 'runNativeHost(', 'sendOpenBrowserNotify(', 'sendBrowserRequest(']) {
    assert.ok(main.indexOf(operation) > guard, `${operation} must follow local help dispatch`);
  }
  const nested = main.slice(guard, main.indexOf('resolveWindowFromEnv(allocator)'));
  assert.match(nested, /command, "tab".*arg, "close"/);
  assert.match(nested, /command, "tabs".*arg, "--close"/);
  assert.match(nested, /flag, "--help".*flag, "-h"/);
});

test('local command help reuses command syntax and includes CDP examples', () => {
  const help = source.slice(source.indexOf('fn commandHelp('), source.indexOf('fn badArgs('));
  assert.match(help, /commandLookup\(command\)/);
  assert.match(help, /splitScalar\(u8, usage_text/);
  assert.match(help, /cdp <method> \[params-json\]/);
  assert.match(help, /Examples:/);
  assert.match(help, /Page\.enable/);
  assert.match(help, /Runtime\.evaluate.*expression/);
  assert.doesNotMatch(help, /sendBrowserRequest|runNativeHost|resolveWindowFromEnv|CreateFile/);
});

test('native help sweep shares the shard that installs the bridge executable', () => {
  const root = path.resolve(__dirname, '..');
  const build = fs.readFileSync(path.join(root, 'build.zig'), 'utf8');
  const workflow = fs.readFileSync(path.join(root, '.github/workflows/test.yml'), 'utf8');
  assert.match(build, /bridge_bad_args_tests\.step\.dependOn\(&bridge_install\.step\)/);
  const routing = build.slice(build.indexOf('for (test_step.dependencies.items)'), build.indexOf('test_step.dependencies.clearRetainingCapacity()'));
  assert.doesNotMatch(routing, /dependency == &bridge_bad_args_tests\.step/);
  assert.match(routing, /else\s*2;\s*test_groups\[group\]\.dependOn\(dependency\)/);
  assert.match(workflow, /name: Sweep real zsb\.exe command help\n\s*if: [^\n]*matrix\.group == 3\n\s*run: node --test tools\/zsb-help\.test\.js/);
});
