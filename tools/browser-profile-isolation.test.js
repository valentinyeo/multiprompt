const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");

const source = require('./app-source').readAppSource();
const bridgeSource = fs.readFileSync(path.join(__dirname, "..", "src", "bridge.zig"), "utf8");
const launchStart = source.indexOf("fn shellExecuteEdgeUrl(");
const launchEnd = source.indexOf("\nfn spawnBrowserCliHidden(", launchStart);
assert.notStrictEqual(launchStart, -1, "Edge launch function is missing");
assert.notStrictEqual(launchEnd, -1, "could not isolate Edge launch function");
const launch = source.slice(launchStart, launchEnd);

test("native Edge and Chrome panes use process boundaries from normal browsers and PWAs", () => {
  assert.match(source, /GetEnvironmentVariableA\("LOCALAPPDATA"[\s\S]{0,900}?\\\\EdgeUserData/,
    "multiprompt needs a dedicated local Edge user-data directory");
  assert.match(source, /GetEnvironmentVariableA\("LOCALAPPDATA"[\s\S]{0,900}?\\\\ChromeUserData/,
    "multiprompt needs a separate dedicated local Chrome user-data directory");
  assert.match(launch, /--user-data-dir=\\"/,
    "every native Edge launch must select the isolated user-data directory");
  assert.match(launch, /--profile-directory=/,
    "the pane profile must be selected inside the isolated user-data directory");
  assert.ok(launch.indexOf("--user-data-dir=") < launch.indexOf("--profile-directory="),
    "the process boundary must be established before selecting its internal profile");
});

test("each isolated full-browser profile retains extension support without becoming a notification client", () => {
  assert.match(launch, /--load-extension=\\"/,
    "the path-stable native bridge extension must bootstrap in the isolated profile");
  assert.match(launch, /--disable-notifications/,
    "the isolated pane profile must not register its own Windows web notifications");
  assert.match(launch, /--disable-background-mode/,
    "theme restarts must end the isolated Edge process after its last window closes");
  assert.doesNotMatch(launch, /CreateCoreWebView2|WebView2/,
    "profile isolation must keep the full Edge backend rather than switching to WebView2");
});

test("selected isolated Chromium and ordinary Edge cannot share the native command channel", () => {
  assert.match(source, /\\Documents\\\\GitHub\\\\zigshell\\\\extension/,
    "the isolated Edge process must load the repository extension copy");
  assert.doesNotMatch(source.slice(source.indexOf("fn defaultEdgeExtensionPath"), source.indexOf("fn loadEdgeExtensionPathConfig")),
    /zigshell-browser-pane/,
    "the isolated profile default must not reuse the ordinary Edge extension path");
  assert.match(bridgeSource, /const legacy_pipe_name = "\\\\\\\\\.\\\\pipe\\\\zigshell-browser"/,
    "ordinary Edge needs a compatibility-only pipe");
  assert.match(bridgeSource, /const isolated_pipe_name = "\\\\\\\\\.\\\\pipe\\\\multiprompt-browser-isolated"/,
    "multiprompt Edge or Chrome needs one private selected-engine command pipe");
  assert.match(bridgeSource, /CreateFileA\([\s\S]{0,120}?isolated_pipe_name/,
    "browser CLI commands must target only the isolated host");
  assert.match(bridgeSource, /runPipeServer,[\s\S]{0,120}?command_pipe_name/,
    "each native host must serve only the pipe selected by its extension origin");
});
