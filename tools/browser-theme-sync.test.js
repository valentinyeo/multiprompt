const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");

const root = path.resolve(__dirname, "..");
const app = require('./app-source').readAppSource();
const bridge = fs.readFileSync(path.join(root, "extension", "bridge.js"), "utf8");
const nativeHost = fs.readFileSync(path.join(root, "src", "bridge.zig"), "utf8");
const extensionManifest = JSON.parse(fs.readFileSync(path.join(root, "extension", "manifest.json"), "utf8"));
const tokens = ["dark", "mid", "light", "amoled", "edgegray", "multiprompt", "devblue"];

test("every app theme has a bundled Chromium theme package", () => {
  const expectedNames = {
    dark: "Dark",
    mid: "Mid",
    light: "Light",
    amoled: "AMOLED",
    edgegray: "Edge Grey",
    multiprompt: "multiprompt",
    devblue: "Dev Blue",
  };

  for (const token of tokens) {
    const manifestPath = path.join(root, "extension", "themes", token, "manifest.json");
    const manifest = JSON.parse(fs.readFileSync(manifestPath, "utf8"));
    assert.equal(manifest.manifest_version, 2);
    assert.equal(manifest.name, `multiprompt browser theme - ${expectedNames[token]}`);
    assert.ok(Array.isArray(manifest.theme.colors.frame));
    assert.ok(Array.isArray(manifest.theme.colors.toolbar));
    assert.ok(Array.isArray(manifest.theme.colors.tab_text));
  }
});

test("isolated browsers load theme packages and resynchronize only after a real theme change", () => {
  assert.match(app, /appendBrowserWideAscii\(params, pos, "\\\\themes\\\\"\)/);
  assert.match(app, /appendBrowserWideAscii\(params, pos, currentThemeToken\(\)\)/);
  assert.match(app, /--disable-background-mode/);
  assert.match(app, /fn saveGlobalTheme\(\) void \{\s+defer syncEdgeProfileTheme\(\);/);
  assert.match(app, /fn refreshSystemTheme[\s\S]{0,900}?syncEdgeProfileTheme\(\);/);
  const bindWindow = app.match(/fn bindBrowserWindowIdForShell[\s\S]*?\n\}/)?.[0] ?? "";
  assert.doesNotMatch(bindWindow, /syncEdgeProfileTheme\(\)/);
  assert.match(app, /"\\"\{s\}\\" theme \{s\}"/);
});

test("browser frame masks inherit the app theme instead of the legacy peach cover", () => {
  const frameColor = app.match(/fn browserEdgeMaskFrameColor\(\) DWORD \{([\s\S]*?)\n\}/)?.[1] ?? "";
  assert.doesNotMatch(frameColor, /RGB\(248, 204, 168\)/);
  assert.match(frameColor, /return themeSidebarBg\(\);/);
});

test("bridge protocol validates and activates only bundled browser themes", () => {
  assert.ok(extensionManifest.permissions.includes("management"));
  assert.match(bridge, /case "setTheme":\s+return applyBrowserTheme\(message\)/);
  assert.match(bridge, /item\?\.type === "theme" && item\?\.name === expectedName/);
  assert.match(bridge, /chrome\.management\.setEnabled\(target\.id, true\)/);
  assert.match(bridge, /scheduleBrowserThemeRestart\(theme\)/);
  assert.match(bridge, /chrome\.windows\.remove\(window\.id\)/);
  assert.match(nativeHost, /std\.mem\.eql\(u8, command, "theme"\)/);
  assert.match(nativeHost, /sendRequiredBrowserRequest\(allocator, "setTheme", fields\.items, 8\)/);
});

test("native bridge and extension advance together for theme sync", () => {
  assert.match(extensionManifest.version, /^1\.0\.\d+$/);
  assert.match(nativeHost, /const version = @import\("bridge_config"\)\.extension_version;/);
});
