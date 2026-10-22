const HOST = "com.zigshell.bridge";
const PROTECTED_WINDOWS_KEY = "zigshellProtectedWindows";
const PROTECTED_WINDOW_META_KEY = "multipromptProtectedWindowMetaV1";
const ZSB_TARGET_TABS_KEY = "multipromptZsbTargetTabsV1";
const EXTERNAL_ESCAPE_WINDOW_KEY = "multipromptExternalEscapeWindowV1";
const ROUTING_AUDIT_KEY = "multipromptRoutingAuditV1";
const ROUTING_AUDIT_LIMIT = 200;
const SCREENSHOT_AUDIT_KEY = "multipromptScreenshotAuditV1";
const SCREENSHOT_AUDIT_LIMIT = 100;
const ISOLATED_PROFILE_CONTAINS_ALL_TABS = true;
const BROWSER_THEME_PREFIX = "multiprompt browser theme - ";
const BROWSER_THEME_LABELS = Object.freeze({
  dark: "Dark",
  mid: "Mid",
  light: "Light",
  amoled: "AMOLED",
  edgegray: "Edge Grey",
  multiprompt: "multiprompt",
  devblue: "Dev Blue",
});
let browserThemeRestartToken = null;
const EXTERNAL_WINDOW_BOUNDS = { left: 90, top: 90, width: 1400, height: 900 };

let port;
const debuggedTabs = new Set();
const cdpOperationChains = new Map();
const cdpSessionCancels = new Map();
const screenshotCdpDetachTimers = new Map();
const screenshotCdpDetachInFlight = new Map();
const screenshotCdpPageEnabledTabs = new Set();
const focusEmulatedTabs = new Set();
const consoleEntriesByTab = new Map();
const consoleCaptureTabs = new Set();
const CONSOLE_ENTRY_LIMIT = 500;
let protectedWindowIds = new Set();
let protectedWindowIdsLoaded = false;
let protectedWindowIdsLoadPromise;
let protectedWindowIdsSaveTimer;
const protectedWindowMeta = new Map();
let routingAuditWriteChain = Promise.resolve();
let screenshotAuditWriteChain = Promise.resolve();
let screenshotTransactionChain = Promise.resolve();
const pendingZigShellCreates = [];
const suspectExternalTabCreates = new Map();
const committedTopFrameNavigations = new Map();
const pageCreatedNavigationTargets = new Map();
const zsbTargetTabsByWindow = new Map();
const agentNavigateTabs = new Map();
const userOwnedTabs = new Set();
const protectedWindowFocusAt = new Map();
const browserDropGestures = new Map();
let externalEscapeWindowId = null;
let focusedBrowserWindowId = chrome.windows.WINDOW_ID_NONE;
const SUSPECT_EXTERNAL_TAB_MS = 2500;
const EXTERNAL_TAB_DEFLECT_GRACE_MS = 1200;
const PROTECTED_FOCUS_SETTLED_MS = 650;
const BROWSER_DROP_GESTURE_MS = 1800;
const SHOT_URL_MENU_ID = "take-tab-screenshot-link";
const pendingHostReplies = new Map();
const SCREENSHOT_CDP_IDLE_DETACH_MS = 1500;
const EXTENSION_RELOAD_ATTEMPTS_KEY = "multipromptExtensionReloadAttemptsV1";
const EXTENSION_RELOAD_GUARD_MS = 10 * 60 * 1000;
const EXTENSION_OUTDATED_ERROR = "extension outdated, reload it in chrome://extensions";
let nativeBridgeVersion = null;
let extensionOutdated = false;
let bridgeVersionCheckChain = Promise.resolve();
let extensionReloadTimer;

function connect() {
  if (port) return port;

  const connectedPort = chrome.runtime.connectNative(HOST);
  port = connectedPort;

  connectedPort.onMessage.addListener((message) => {
    console.log("multiprompt browser bridge:", message);
    bridgeVersionCheckChain = bridgeVersionCheckChain.then(async () => {
      await checkBridgeVersion(message);
      if (routePendingHostReply(message)) return;
      handleHostMessage(message);
    }).catch((error) => {
      console.warn("multiprompt extension version check failed:", error?.message || error);
      if (!routePendingHostReply(message)) {
        sendResponse(message, { ok: false, error: extensionOutdated ? EXTENSION_OUTDATED_ERROR : String(error) });
      }
    });
  });

  connectedPort.onDisconnect.addListener(() => {
    if (port !== connectedPort) return;
    console.warn("multiprompt browser bridge disconnected:", chrome.runtime.lastError?.message);
    port = undefined;
    rejectPendingHostReplies(chrome.runtime.lastError?.message || "native host disconnected");
  });

  return port;
}

chrome.alarms.create("zs-keepalive", { periodInMinutes: 0.4 });

chrome.alarms.onAlarm.addListener((alarm) => {
  if (alarm.name !== "zs-keepalive") return;
  connect().postMessage({ id: crypto.randomUUID(), method: "ping" });
});

chrome.action.onClicked.addListener((tab) => {
  if (!Number.isInteger(tab?.windowId)) return;
  return shotUrl(tab.windowId, true).catch((error) => {
    console.warn("multiprompt screenshot button failed:", error?.message || error);
  });
});

chrome.runtime.onStartup.addListener(() => {
  connect();
  if (!isEdgeBrowser()) reloadCurrentBrowserTheme().catch(() => {});
});
chrome.runtime.onInstalled.addListener(() => {
  connect();
  if (!isEdgeBrowser()) reloadCurrentBrowserTheme().catch(() => {});
  installContextMenus();
});
chrome.debugger.onDetach.addListener((source) => {
  if (!Number.isInteger(source.tabId)) return;
  debuggedTabs.delete(source.tabId);
  screenshotCdpPageEnabledTabs.delete(source.tabId);
  clearScreenshotCdpDetachTimer(source.tabId);
});
chrome.debugger.onEvent.addListener((source, method, params) => {
  const tabId = source?.tabId;
  if (!Number.isInteger(tabId) || !consoleCaptureTabs.has(tabId)) return;
  const entries = consoleEntriesByTab.get(tabId) || [];
  const normalized = normalizeConsoleEvent(method, params);
  if (!normalized) return;
  entries.push(normalized);
  if (entries.length > CONSOLE_ENTRY_LIMIT) entries.splice(0, entries.length - CONSOLE_ENTRY_LIMIT);
  consoleEntriesByTab.set(tabId, entries);
});
chrome.runtime.onMessage.addListener((message, sender, sendResponse) => {
  if (message?.type === "multiprompt:isProtectedWindow") {
    loadProtectedWindows().then(() => {
      sendResponse({ protected: protectedWindowIds.has(sender?.tab?.windowId) });
    }).catch(() => sendResponse({ protected: false }));
    return true;
  }
  if (message?.type === "multiprompt:webNotificationClick") {
    handleWebNotificationClick(message, sender).then((result) => {
      sendResponse({ ok: true, result });
    }).catch((error) => {
      sendResponse({ ok: false, error: error?.message || String(error) });
    });
    return true;
  }
  return false;
});
chrome.windows.onRemoved.addListener((windowId) => {
  if (externalEscapeWindowId === windowId) {
    externalEscapeWindowId = null;
    chrome.storage.local.remove(EXTERNAL_ESCAPE_WINDOW_KEY).catch(() => {});
  }
  for (const [tabId, record] of agentNavigateTabs) {
    if (record.windowId === windowId) agentNavigateTabs.delete(tabId);
  }
  protectedWindowFocusAt.delete(windowId);
  if (focusedBrowserWindowId === windowId) focusedBrowserWindowId = chrome.windows.WINDOW_ID_NONE;
  if (!protectedWindowIds.has(windowId)) return;
  protectedWindowIds.delete(windowId);
  protectedWindowMeta.delete(windowId);
  zsbTargetTabsByWindow.delete(windowId);
  scheduleProtectedWindowSave();
  recordRoutingAudit("protected_window_closed", { windowId }).catch(() => {});
});
chrome.windows.onFocusChanged.addListener((windowId) => {
  const observedAt = Date.now();
  focusedBrowserWindowId = Number.isInteger(windowId)
    ? windowId
    : chrome.windows.WINDOW_ID_NONE;
  if (focusedBrowserWindowId === chrome.windows.WINDOW_ID_NONE) return;
  loadProtectedWindows().then(() => {
    if (focusedBrowserWindowId === windowId && protectedWindowIds.has(windowId)) {
      protectedWindowFocusAt.set(windowId, observedAt);
    }
  }).catch(() => {});
});
chrome.tabs.onCreated.addListener((tab) => {
  const observedAt = Date.now();
  handlePossibleExternalTab(tab, observedAt).catch((error) => {
    console.warn("multiprompt external-tab guard failed:", error?.message || error);
  });
});
chrome.webNavigation.onCommitted.addListener((details) => {
  if (details.frameId !== 0) return;
  const record = agentNavigateTabs.get(details.tabId);
  const qualifiers = details.transitionQualifiers || [];
  const explicitUserNavigation = qualifiers.includes("from_address_bar") || qualifiers.includes("forward_back");
  if (record && !explicitUserNavigation &&
      !["form_submit", "auto_bookmark", "keyword", "keyword_generated", "reload"].includes(details.transitionType) &&
      (record.pendingUrls.has(canonicalUrl(details.url)) ||
       (record.pendingUrls.size > 0 && qualifiers.includes("server_redirect")))) {
    const committed = record.pendingUrls.has(canonicalUrl(details.url))
      ? canonicalUrl(details.url) : record.pendingUrls.values().next().value;
    record.pendingUrls.delete(committed);
    return;
  }
  if (explicitUserNavigation || (record &&
      ["link", "form_submit", "auto_bookmark", "keyword", "keyword_generated", "reload"].includes(details.transitionType))) {
    userOwnedTabs.add(details.tabId);
  }
  agentNavigateTabs.delete(details.tabId);
});
chrome.tabs.onRemoved.addListener((tabId) => {
  agentNavigateTabs.delete(tabId);
  userOwnedTabs.delete(tabId);
  suspectExternalTabCreates.delete(tabId);
  committedTopFrameNavigations.delete(tabId);
  pageCreatedNavigationTargets.delete(tabId);
  focusEmulatedTabs.delete(tabId);
  screenshotCdpPageEnabledTabs.delete(tabId);
  clearScreenshotCdpDetachTimer(tabId);
  for (const [windowId, targetTabId] of zsbTargetTabsByWindow) {
    if (targetTabId === tabId) {
      zsbTargetTabsByWindow.delete(windowId);
      scheduleProtectedWindowSave();
    }
  }
});
chrome.tabs.onActivated.addListener(async (activeInfo) => {
  if (!Number.isInteger(activeInfo?.windowId) || !Number.isInteger(activeInfo?.tabId)) return;
  userOwnedTabs.add(activeInfo.tabId);
  agentNavigateTabs.delete(activeInfo.tabId);
  await loadProtectedWindows();
  if (!protectedWindowIds.has(activeInfo.windowId)) return;
  const tab = await chrome.tabs.get(activeInfo.tabId).catch(() => null);
  if (!tab || tab.windowId !== activeInfo.windowId || isExtensionTab(tab) || isPaneBeaconTab(tab)) return;
  rememberZsbTargetTab(activeInfo.windowId, activeInfo.tabId);
});
chrome.contextMenus.onClicked.addListener((info, tab) => {
  if (info.menuItemId !== SHOT_URL_MENU_ID) return;
  const windowId = Number.isInteger(tab?.windowId) ? tab.windowId : null;
  if (windowId == null) return;
  return shotUrl(windowId, true).catch((error) => {
    console.warn("multiprompt shoturl failed:", error?.message || error);
  });
});
chrome.commands.onCommand.addListener((command) => {
  if (command !== "take-tab-screenshot" && command !== "take-tab-screenshot-ctrl") return;
  return chrome.windows.getLastFocused({ windowTypes: ["normal", "popup"] }).then((win) => {
    if (!Number.isInteger(win?.id)) throw new Error("no last-focused browser window");
    return shotUrl(win.id, true);
  }).catch((error) => {
    console.warn("multiprompt shoturl command failed:", error?.message || error);
  });
});

connect();
loadProtectedWindows().then(() => {
  for (const windowId of protectedWindowIds) notifyProtectedWindowTabs(windowId);
}).catch(() => {});

function scheduleExtensionReload() {
  if (extensionReloadTimer != null) return;
  extensionReloadTimer = setTimeout(() => chrome.runtime.reload(), 200);
}

async function checkBridgeVersion(message) {
  const reported = message?.bridgeVersion ?? message?.result?.bridgeVersion;
  if (typeof reported === "string" && /^\d+\.\d+\.\d+$/.test(reported)) {
    nativeBridgeVersion = reported;
  }
  extensionOutdated = nativeBridgeVersion != null && nativeBridgeVersion !== chrome.runtime.getManifest().version;
  if (!extensionOutdated || extensionReloadTimer != null) return;

  const stored = await chrome.storage.local.get(EXTENSION_RELOAD_ATTEMPTS_KEY);
  const attempts = stored[EXTENSION_RELOAD_ATTEMPTS_KEY] || {};
  const now = Date.now();
  const lastAttempt = attempts[nativeBridgeVersion];
  if (Number.isFinite(lastAttempt) && now - lastAttempt < EXTENSION_RELOAD_GUARD_MS) return;
  await chrome.storage.local.set({
    [EXTENSION_RELOAD_ATTEMPTS_KEY]: { ...attempts, [nativeBridgeVersion]: now },
  });
  if (message?.method !== "extensionReload") scheduleExtensionReload();
}

async function handleHostMessage(message) {
  if (!message?.method) return;

  const reloadPending = message.method === "extensionReload" && extensionReloadTimer != null;
  if (reloadPending) {
    clearTimeout(extensionReloadTimer);
    extensionReloadTimer = undefined;
  }
  try {
    if (extensionOutdated && message.method !== "extensionReload") console.warn(EXTENSION_OUTDATED_ERROR);
    const actionTimeoutMs = message.method === "screenshot" || message.method === "shoturl" ? 35000 : 15000;
    const result = await withTimeout(dispatch(message), actionTimeoutMs, `${message.method} timed out`);
    if (result?.error === "page_error") {
      sendResponse(message, { ok: false, error: "page_error", result });
      return;
    }
    sendResponse(message, { ok: true, result });
    if (message.method === "extensionReload" || (message.method === "reset" && result.reloadScheduled)) scheduleExtensionReload();
  } catch (error) {
    sendResponse(message, {
      ok: false,
      error: error?.message || String(error),
    });
    if (reloadPending) scheduleExtensionReload();
  }
}

async function dispatch(message) {
  if (message?.method !== "protectWindow") await rememberTargetWindow(message);
  switch (message.method) {
    case "ping":
      return { pong: true };
    case "protectWindow":
      return protectWindow(message);
    case "browserDropGesture":
      return browserDropGesture(message);
    case "routingAudit":
      return getRoutingAudit(message);
    case "navigate":
      return navigate(message);
    case "createPaneWindow":
      return createPaneWindow(message);
    case "back":
      return historyNav(message, false);
    case "forward":
      return historyNav(message, true);
    case "reload":
      return reloadAction(message);
    case "extensionReload":
      return { reloadScheduled: true };
    case "reset":
      return resetBridge(message);
    case "setTheme":
      return applyBrowserTheme(message);
    case "tabs":
      return listTabs(message);
    case "activeTab":
      return compactTab(await getTargetTab(message));
    case "frames":
      return framesAction(message);
    case "url":
      return urlAction(message);
    case "activate":
      return activateTab(message);
    case "closeTab":
      return closeTabAction(message);
    case "text":
      return textAction(message);
    case "links":
      return linksAction(message);
    case "snapshot":
      return getSnapshot(numberOr(message.limit, 2000), message);
    case "find":
      return findAction(message);
    case "click":
      return clickAction(message);
    case "type":
      return typeAction(message);
    case "insert":
      return insertAction(message);
    case "cursor":
      return cursorAction(message);
    case "eval":
      return evalAction(message);
    case "key":
      return keyAction(message);
    case "screenshot":
      return screenshot(message);
    case "console":
      return consoleAction(message);
    case "shoturl": {
      const wid = messageWindowId(message);
      if (wid == null) throw new Error("shoturl requires --window <id>");
      return shotUrl(wid, message.userInitiated === true);
    }
    case "cdp":
      return sendCdp(message);
    case "resolveWindow":
      return resolveWindow(message);
    default:
      throw new Error(`unknown method: ${message.method}`);
  }
}

async function rememberTargetWindow(message) {
  const wid = messageWindowId(message);
  if (wid == null) return;
  const record = await chrome.windows.get(wid).catch(() => null);
  if (!record || (record.type && record.type !== "normal")) throw new Error(paneWindowNotFoundMessage(wid));
  await markZigShellWindow(wid);
}

function messageWindowId(message) {
  return Number.isInteger(message?.windowId) && message.windowId > 0 ? message.windowId : null;
}

async function protectWindow(message) {
  const wid = messageWindowId(message);
  if (wid == null) throw new Error("protectWindow requires --window <id>");
  const record = await chrome.windows.get(wid).catch(() => null);
  if (!record || (record.type && record.type !== "normal")) throw new Error(paneWindowNotFoundMessage(wid));
  const shellId = Number.isInteger(message?.shellId) && message.shellId >= 0 ? message.shellId : null;
  await loadProtectedWindows();
  const ownerPid = Number.isInteger(message?.ownerPid) && message.ownerPid > 0 ? message.ownerPid : null;
  const owner = protectedWindowMeta.get(wid);
  if (shellId != null && owner?.shellId != null &&
      (owner.shellId !== shellId || (ownerPid != null && owner.ownerPid != null && owner.ownerPid !== ownerPid))) {
    throw new Error(`multiprompt browser window ${wid} already belongs to shell ${owner.shellId}`);
  }
  await markZigShellWindow(wid, { shellId, ownerPid: ownerPid ?? owner?.ownerPid, explicit: true });
  return { windowId: wid, shellId, protected: true };
}

const CURRENT_THEME_NAME = "multiprompt browser theme";
const CURRENT_THEME_HINT = "Load extension\\themes\\current once in chrome://extensions";

function isEdgeBrowser() {
  const ua = typeof navigator !== "undefined" ? String(navigator.userAgent || "") : "";
  return /\bEdg\//.test(ua);
}

async function reloadCurrentBrowserTheme() {
  const installed = await chrome.management.getAll();
  const target = installed.find((item) => item?.type === "theme" && item?.name === CURRENT_THEME_NAME);
  if (!target) return { themeInstalled: false, hint: CURRENT_THEME_HINT };
  return { themeInstalled: true, extensionId: target.id, reloaded: false, hint: "Click Update in chrome://extensions to apply" };
}

async function applyBrowserTheme(message) {
  const theme = typeof message?.theme === "string" ? message.theme.trim().toLowerCase() : "";
  const label = BROWSER_THEME_LABELS[theme];
  if (!label) throw new Error(`unsupported multiprompt browser theme: ${theme || "(empty)"}`);
  if (!isEdgeBrowser()) return { theme, applied: true, restartRequired: false, ...(await reloadCurrentBrowserTheme()) };

  const expectedName = `${BROWSER_THEME_PREFIX}${label}`;
  const installed = await chrome.management.getAll();
  const target = installed.find((item) => item?.type === "theme" && item?.name === expectedName);
  if (!target) {
    const restartScheduled = scheduleBrowserThemeRestart(theme);
    return { theme, applied: false, restartRequired: true, restartScheduled };
  }
  if (!target.enabled) await chrome.management.setEnabled(target.id, true);
  return { theme, extensionId: target.id, applied: !target.enabled, restartRequired: false };
}

function scheduleBrowserThemeRestart(theme) {
  if (browserThemeRestartToken != null) return false;
  browserThemeRestartToken = theme;
  setTimeout(async () => {
    try {
      const windows = await chrome.windows.getAll({ windowTypes: ["normal"] });
      await Promise.allSettled(windows.map((window) => chrome.windows.remove(window.id)));
    } finally {
      browserThemeRestartToken = null;
    }
  }, 250);
  return true;
}

async function browserDropGesture(message) {
  const windowId = messageWindowId(message);
  if (windowId == null) throw new Error("browserDropGesture requires --window <id>");
  await loadProtectedWindows();
  if (!protectedWindowIds.has(windowId)) throw new Error("browserDropGesture window is not protected");

  const gesture = {
    at: Date.now(),
    expires: Date.now() + BROWSER_DROP_GESTURE_MS,
    consumedTabId: null,
  };
  browserDropGestures.set(windowId, gesture);
  await recordRoutingAudit("browser_drop_gesture_observed", auditWindowDetails(windowId, {
    expiresAt: new Date(gesture.expires).toISOString(),
  }));

  const candidates = [...suspectExternalTabCreates.entries()]
    .filter(([, suspected]) =>
      suspected.windowId === windowId &&
      Math.abs(gesture.at - suspected.observedAt) <= BROWSER_DROP_GESTURE_MS)
    .sort((left, right) => right[1].observedAt - left[1].observedAt);
  for (const [tabId, suspected] of candidates) {
    if (suspected.commitClassificationPromise) {
      await suspected.commitClassificationPromise.catch(() => {});
    }
    if (gesture.consumedTabId != null) break;
    if (suspectExternalTabCreates.get(tabId) !== suspected) continue;
    const committed = suspected.committedNavigation;
    if (!isNativeDropBookmarkLinkCommit(committed)) continue;
    if (committed.bookmarkMatch !== true) {
      committed.bookmarkMatch = await isExactBrowserBookmark(
        committed.url,
        isServerRedirectedBookmarkLinkCommit(committed),
      );
    }
    if (committed.bookmarkMatch !== true) continue;
    applyNativeBookmarkDrop(committed, tabId);
    browserDropGestures.delete(windowId);
    await authorizeSuspectExternalTab(tabId, "native_bookmark_drop");
    gesture.consumedTabId = tabId;
    break;
  }

  setTimeout(() => {
    if (browserDropGestures.get(windowId) === gesture) browserDropGestures.delete(windowId);
  }, BROWSER_DROP_GESTURE_MS + 50);
  return { windowId, authorizedTabId: gesture.consumedTabId };
}

async function markZigShellWindow(windowId, metadata = {}) {
  await loadProtectedWindows();
  const shellId = Number.isInteger(metadata?.shellId) && metadata.shellId >= 0 ? metadata.shellId : null;
  const ownerPid = Number.isInteger(metadata?.ownerPid) && metadata.ownerPid > 0 ? metadata.ownerPid : null;
  if (shellId != null) {
    const previous = protectedWindowMeta.get(windowId);
    if (previous?.shellId !== shellId || (previous?.ownerPid ?? null) !== ownerPid) {
      for (const [tabId, record] of agentNavigateTabs) {
        if (record.windowId === windowId) agentNavigateTabs.delete(tabId);
      }
    }
    for (const [id, value] of protectedWindowMeta) {
      if (id !== windowId && value.shellId === shellId && (value.ownerPid ?? null) === ownerPid) {
        protectedWindowMeta.delete(id);
        for (const [tabId, record] of agentNavigateTabs) {
          if (record.windowId === id) agentNavigateTabs.delete(tabId);
        }
      }
    }
    protectedWindowMeta.set(windowId, {
      shellId,
      ownerPid,
      registeredAt: new Date().toISOString(),
    });
  }
  if (protectedWindowIds.has(windowId)) {
    await rememberCurrentProtectedFocusState(windowId);
    notifyProtectedWindowTabs(windowId);
    if (metadata?.explicit === true) {
      scheduleProtectedWindowSave();
      recordRoutingAudit("window_protection_refreshed", auditWindowDetails(windowId)).catch(() => {});
    }
    return;
  }
  protectedWindowIds.add(windowId);
  await rememberCurrentProtectedFocusState(windowId);
  notifyProtectedWindowTabs(windowId);
  scheduleProtectedWindowSave();
  recordRoutingAudit("window_protected", auditWindowDetails(windowId)).catch(() => {});
}

function notifyProtectedWindowTabs(windowId) {
  chrome.tabs.query({ windowId }).then((tabs) => {
    for (const tab of tabs) {
      if (!Number.isInteger(tab?.id)) continue;
      chrome.scripting.executeScript({
        target: { tabId: tab.id },
        files: ["notification-click-main.js"],
        world: "MAIN",
      }).catch(() => {});
      chrome.tabs.sendMessage(tab.id, { type: "multiprompt:protectWindow" }).catch(() => {
        chrome.scripting.executeScript({
          target: { tabId: tab.id },
          files: ["pane-click-guard.js"],
        }).catch(() => {});
      });
    }
  }).catch(() => {});
}

async function handleWebNotificationClick(message, sender) {
  const tab = sender?.tab;
  if (!Number.isInteger(tab?.id) || !Number.isInteger(tab?.windowId)) {
    return { handled: false, reason: "missing_sender_tab" };
  }

  await loadProtectedWindows();
  if (!protectedWindowIds.has(tab.windowId)) {
    return { handled: false, reason: "sender_not_protected" };
  }

  let source;
  let target;
  try {
    source = new URL(tab.url || "");
    target = new URL(message?.url || "", source.href);
  } catch (_) {
    return { handled: false, reason: "invalid_url" };
  }
  if (!/^https?:$/.test(target.protocol) || target.origin !== source.origin) {
    return { handled: false, reason: "cross_origin_url" };
  }

  const created = await chrome.tabs.create({
    windowId: tab.windowId,
    url: target.href,
    active: true,
  });
  await recordRoutingAudit("notification_target_opened_inside", auditWindowDetails(tab.windowId, {
    tabId: tab.id,
    url: target.href,
    destinationTabId: created?.id ?? null,
  }));
  return { handled: true, windowId: tab.windowId, tabId: created?.id ?? null, url: target.href };
}

function loadProtectedWindows() {
  if (protectedWindowIdsLoadPromise) return protectedWindowIdsLoadPromise;

  protectedWindowIdsLoadPromise = (async () => {
    try {
      const data = await chrome.storage.local.get([PROTECTED_WINDOWS_KEY, PROTECTED_WINDOW_META_KEY, ZSB_TARGET_TABS_KEY]);
      const saved = Array.isArray(data?.[PROTECTED_WINDOWS_KEY]) ? data[PROTECTED_WINDOWS_KEY] : [];
      for (const id of saved) {
        if (Number.isInteger(id) && id > 0) protectedWindowIds.add(id);
      }

      const savedTargets = data?.[ZSB_TARGET_TABS_KEY];
      if (savedTargets && typeof savedTargets === "object" && !Array.isArray(savedTargets)) {
        for (const [rawWindowId, tabId] of Object.entries(savedTargets)) {
          const windowId = Number(rawWindowId);
          if (protectedWindowIds.has(windowId) && Number.isInteger(tabId) && tabId > 0 && !zsbTargetTabsByWindow.has(windowId)) {
            zsbTargetTabsByWindow.set(windowId, tabId);
          }
        }
      }

      const savedMeta = data?.[PROTECTED_WINDOW_META_KEY];
      if (savedMeta && typeof savedMeta === "object" && !Array.isArray(savedMeta)) {
        for (const [rawWindowId, metadata] of Object.entries(savedMeta)) {
          const windowId = Number(rawWindowId);
          if (!Number.isInteger(windowId) || windowId <= 0 || !metadata || typeof metadata !== "object") continue;
          protectedWindowMeta.set(windowId, {
            shellId: Number.isInteger(metadata.shellId) && metadata.shellId >= 0 ? metadata.shellId : null,
            ownerPid: Number.isInteger(metadata.ownerPid) && metadata.ownerPid > 0 ? metadata.ownerPid : null,
            registeredAt: typeof metadata.registeredAt === "string" ? metadata.registeredAt : null,
          });
        }
      }
    } catch (error) {
      console.warn("multiprompt protected-window registry load failed:", error?.message || error);
    }

    protectedWindowIdsLoaded = true;
    await pruneProtectedWindows();
    await rememberCurrentProtectedFocusState();
    recordRoutingAudit("protection_registry_loaded", {
      protectedWindowCount: protectedWindowIds.size,
    }).catch(() => {});
  })();
  return protectedWindowIdsLoadPromise;
}

async function rememberCurrentProtectedFocusState(windowId = null) {
  let win = null;
  if (Number.isInteger(windowId)) {
    win = await chrome.windows.get(windowId).catch(() => null);
  } else {
    win = await chrome.windows.getLastFocused({ windowTypes: ["normal", "popup"] }).catch(() => null);
  }
  if (!Number.isInteger(win?.id) || win?.focused !== true || !protectedWindowIds.has(win.id)) return;
  focusedBrowserWindowId = win.id;
  if (!protectedWindowFocusAt.has(win.id)) protectedWindowFocusAt.set(win.id, Date.now());
}

function scheduleProtectedWindowSave() {
  if (protectedWindowIdsSaveTimer) clearTimeout(protectedWindowIdsSaveTimer);
  protectedWindowIdsSaveTimer = setTimeout(() => {
    protectedWindowIdsSaveTimer = undefined;
    const metadata = {};
    for (const [windowId, value] of protectedWindowMeta) metadata[windowId] = value;
    chrome.storage.local.set({
      [PROTECTED_WINDOWS_KEY]: [...protectedWindowIds],
      [PROTECTED_WINDOW_META_KEY]: metadata,
      [ZSB_TARGET_TABS_KEY]: Object.fromEntries(zsbTargetTabsByWindow),
    }).catch(() => {});
  }, 150);
}

async function pruneProtectedWindows() {
  const windows = await chrome.windows.getAll({ windowTypes: ["normal", "popup"] }).catch(() => []);
  const live = new Set(windows.map((win) => win.id).filter((id) => Number.isInteger(id)));
  let changed = false;
  for (const id of [...protectedWindowIds]) {
    if (!live.has(id)) {
      protectedWindowIds.delete(id);
      protectedWindowMeta.delete(id);
      zsbTargetTabsByWindow.delete(id);
      changed = true;
    }
  }
  if (changed) {
    scheduleProtectedWindowSave();
    recordRoutingAudit("protection_registry_pruned", {
      protectedWindowCount: protectedWindowIds.size,
    }).catch(() => {});
  }
}

function auditWindowDetails(windowId, details = {}) {
  const metadata = protectedWindowMeta.get(windowId);
  return {
    windowId,
    shellId: Number.isInteger(metadata?.shellId) ? metadata.shellId : null,
    ...details,
  };
}

function routingAuditEntry(event, details = {}) {
  return {
    at: new Date().toISOString(),
    event,
    ...details,
  };
}

function recordRoutingAudit(event, details = {}) {
  const entry = routingAuditEntry(event, details);
  console.log("multiprompt routing audit:", entry);
  routingAuditWriteChain = routingAuditWriteChain.then(async () => {
    const data = await chrome.storage.local.get(ROUTING_AUDIT_KEY).catch(() => ({}));
    const entries = Array.isArray(data?.[ROUTING_AUDIT_KEY]) ? data[ROUTING_AUDIT_KEY].slice() : [];
    entries.push(entry);
    if (entries.length > ROUTING_AUDIT_LIMIT) entries.splice(0, entries.length - ROUTING_AUDIT_LIMIT);
    await chrome.storage.local.set({ [ROUTING_AUDIT_KEY]: entries });
  }).catch((error) => {
    console.warn("multiprompt routing audit write failed:", error?.message || error);
  });
  return routingAuditWriteChain;
}

function recordScreenshotAudit(transactionId, stage, details = {}) {
  const entry = {
    at: new Date().toISOString(),
    transactionId,
    stage,
    ...details,
  };
  console.log("multiprompt screenshot audit:", entry);
  screenshotAuditWriteChain = screenshotAuditWriteChain.then(async () => {
    const data = await chrome.storage.local.get(SCREENSHOT_AUDIT_KEY).catch(() => ({}));
    const entries = Array.isArray(data?.[SCREENSHOT_AUDIT_KEY])
      ? data[SCREENSHOT_AUDIT_KEY].slice()
      : [];
    entries.push(entry);
    if (entries.length > SCREENSHOT_AUDIT_LIMIT) {
      entries.splice(0, entries.length - SCREENSHOT_AUDIT_LIMIT);
    }
    await chrome.storage.local.set({ [SCREENSHOT_AUDIT_KEY]: entries });
  }).catch((error) => {
    console.warn("multiprompt screenshot audit write failed:", error?.message || error);
  });
  return screenshotAuditWriteChain;
}

async function getRoutingAudit(message) {
  await routingAuditWriteChain;
  const requested = Number.isInteger(message?.limit) ? message.limit : 50;
  const limit = Math.max(1, Math.min(ROUTING_AUDIT_LIMIT, requested));
  const data = await chrome.storage.local.get(ROUTING_AUDIT_KEY).catch(() => ({}));
  const entries = Array.isArray(data?.[ROUTING_AUDIT_KEY]) ? data[ROUTING_AUDIT_KEY] : [];
  return {
    entries: entries.slice(-limit),
    protectedWindows: [...protectedWindowIds].map((windowId) => auditWindowDetails(windowId)),
  };
}

function rememberZigShellTabCreate(windowId, url) {
  if (!Number.isInteger(windowId) || !url) return;
  const now = Date.now();
  pendingZigShellCreates.push({
    windowId,
    url: canonicalUrl(url),
    expires: now + 5000,
  });
  while (pendingZigShellCreates.length > 24) pendingZigShellCreates.shift();
}

function consumeZigShellTabCreate(tab) {
  const url = canonicalUrl(tab.pendingUrl || tab.url || "");
  if (!url) return false;
  const now = Date.now();
  for (let i = pendingZigShellCreates.length - 1; i >= 0; i -= 1) {
    const pending = pendingZigShellCreates[i];
    if (pending.expires < now) {
      pendingZigShellCreates.splice(i, 1);
      continue;
    }
    if (pending.windowId === tab.windowId && pending.url === url) {
      pendingZigShellCreates.splice(i, 1);
      return true;
    }
  }
  return false;
}

async function handlePossibleExternalTab(tab, observedAt = Date.now()) {
  if (!tab?.id || !Number.isInteger(tab.windowId)) return;
  await loadProtectedWindows();
  const url = tab.pendingUrl || tab.url || "";
  if (!protectedWindowIds.has(tab.windowId)) {
    if (isExternalLaunchUrl(url)) {
      await recordRoutingAudit("external_tab_in_unprotected_window", {
        windowId: tab.windowId,
        tabId: tab.id,
        url,
      });
    }
    return;
  }
  if (ISOLATED_PROFILE_CONTAINS_ALL_TABS) {
    const reason = consumeZigShellTabCreate(tab)
      ? "multiprompt_navigation"
      : consumePageCreatedNavigationTarget(tab)
        ? "protected_page_target"
        : "isolated_profile_navigation";
    await recordRoutingAudit("tab_authorized", auditWindowDetails(tab.windowId, {
      tabId: tab.id,
      url,
      reason,
      finalizationReason: reason,
    }));
    return;
  }
  if (consumeZigShellTabCreate(tab)) {
    await recordRoutingAudit("tab_authorized", auditWindowDetails(tab.windowId, {
      tabId: tab.id,
      url,
      reason: "multiprompt_navigation",
    }));
    return;
  }
  if (consumePageCreatedNavigationTarget(tab)) {
    await recordRoutingAudit("tab_authorized", auditWindowDetails(tab.windowId, {
      tabId: tab.id,
      url,
      reason: "protected_page_target",
    }));
    return;
  }

  const suspected = rememberSuspectExternalTab(tab, EXTERNAL_TAB_DEFLECT_GRACE_MS, {
    observedAt,
    focusSettledBeforeCreate: protectedWindowHadSettledFocusBefore(tab.windowId, observedAt),
  });
  if (!suspected) return;
  await suspected.mutePromise;
  if (suspectExternalTabCreates.get(tab.id) !== suspected) return;
  await recordRoutingAudit("tab_quarantined", auditWindowDetails(tab.windowId, {
    tabId: tab.id,
    url,
    muted: suspected.mutedByGuard,
    openerTabId: Number.isInteger(tab.openerTabId) ? tab.openerTabId : null,
    focusSettledBeforeCreate: suspected.focusSettledBeforeCreate,
  }));
  if (suspected.committedNavigation) {
    const committed = suspected.committedNavigation;
    const classification = await classifyCommittedNavigation(suspected, committed);
    await recordRoutingAudit("tab_commit_observed", auditWindowDetails(suspected.windowId, {
      tabId: tab.id,
      url: committed.url,
      transitionType: committed.transitionType,
      transitionQualifiers: committed.transitionQualifiers,
      userNavigation: classification.userNavigation,
      bookmarkMatch: classification.bookmarkMatch,
      focusSettledBeforeCreate: suspected.focusSettledBeforeCreate,
      edgeBookmarkLink: classification.edgeBookmarkLink,
      nativeBookmarkDrop: classification.nativeBookmarkDrop,
      recoveredBeforeQuarantine: true,
    }));
    if (classification.userNavigation) {
      await authorizeSuspectExternalTab(tab.id, classification.authorizationReason);
      return;
    }
    scheduleSuspectExternalCheck(tab.id, suspected.deferUntil);
    return;
  }
  scheduleSuspectExternalCheck(tab.id, suspected.expires);
}

async function handlePossibleExternalTabUpdate(tabId, changeInfo, tab) {
  if (ISOLATED_PROFILE_CONTAINS_ALL_TABS) {
    await authorizeSuspectExternalTab(tabId, "isolated_profile_navigation");
    return;
  }
  const suspected = suspectExternalTabCreates.get(tabId);
  if (!suspected) return;
  if (suspected.commitClassificationPromise) {
    await suspected.commitClassificationPromise.catch(() => {});
    if (suspectExternalTabCreates.get(tabId) !== suspected) return;
  }
  if (!tab?.id || !Number.isInteger(tab.windowId) || tab.windowId !== suspected.windowId) {
    await authorizeSuspectExternalTab(tabId, "window_changed");
    return;
  }
  await loadProtectedWindows();
  if (!protectedWindowIds.has(tab.windowId)) {
    await authorizeSuspectExternalTab(tabId, "window_no_longer_protected");
    return;
  }
  if (consumeZigShellTabCreate(tab)) {
    await authorizeSuspectExternalTab(tabId, "multiprompt_navigation");
    return;
  }
  if (consumePageCreatedNavigationTarget(tab)) {
    await authorizeSuspectExternalTab(tabId, "protected_page_target");
    return;
  }

  const url = changeInfo.pendingUrl || changeInfo.url || tab.pendingUrl || tab.url || "";
  const now = Date.now();
  if (!isExternalLaunchUrl(url)) {
    if (suspected.deferUntil && now < suspected.deferUntil) {
      scheduleSuspectExternalCheck(tabId, suspected.deferUntil);
      return;
    }
    await authorizeSuspectExternalTab(tabId, suspected.committedNavigation
      ? "committed_internal_new_tab"
      : "blank_or_internal_new_tab");
    return;
  }

  if (suspected.committedNavigation) {
    if (suspected.committedNavigation.userNavigation === true) {
      await authorizeSuspectExternalTab(tabId,
        suspected.committedNavigation.authorizationReason || "user_navigation_commit");
      return;
    }
    if (suspected.deferUntil && now < suspected.deferUntil) {
      scheduleSuspectExternalCheck(tabId, suspected.deferUntil);
      return;
    }
    await deflectSuspectExternalTab(tab, url, "committed_non_user_navigation");
    return;
  }

  if (now < suspected.expires) {
    scheduleSuspectExternalCheck(tabId, suspected.expires);
    return;
  }
  await deflectSuspectExternalTab(tab, url, "missing_commit_timeout");
}

async function handleCommittedNavigation(details) {
  if (ISOLATED_PROFILE_CONTAINS_ALL_TABS) return;
  if (!details || details.frameId !== 0 || !Number.isInteger(details.tabId)) return;
  const committedNavigation = {
    transitionType: details.transitionType || "",
    transitionQualifiers: Array.isArray(details.transitionQualifiers)
      ? Array.from(details.transitionQualifiers)
      : [],
    url: details.url || "",
    committedAt: Date.now(),
    expires: Date.now() + 5000,
  };
  committedTopFrameNavigations.set(details.tabId, committedNavigation);
  setTimeout(() => {
    const current = committedTopFrameNavigations.get(details.tabId);
    if (current?.expires === committedNavigation.expires) {
      committedTopFrameNavigations.delete(details.tabId);
    }
  }, 5500);

  const suspected = suspectExternalTabCreates.get(details.tabId);
  if (!suspected) return;
  suspected.committedNavigation = committedNavigation;
  const classificationPromise = classifyCommittedNavigation(suspected, committedNavigation);
  suspected.commitClassificationPromise = classificationPromise;
  const classification = await classificationPromise;
  if (suspectExternalTabCreates.get(details.tabId) !== suspected) return;
  suspected.commitClassificationPromise = null;
  await recordRoutingAudit("tab_commit_observed", auditWindowDetails(suspected.windowId, {
    tabId: details.tabId,
    url: committedNavigation.url,
    transitionType: committedNavigation.transitionType,
    transitionQualifiers: committedNavigation.transitionQualifiers,
    userNavigation: classification.userNavigation,
    bookmarkMatch: classification.bookmarkMatch,
    focusSettledBeforeCreate: suspected.focusSettledBeforeCreate,
    edgeBookmarkLink: classification.edgeBookmarkLink,
    nativeBookmarkDrop: classification.nativeBookmarkDrop,
  }));
  if (classification.userNavigation) {
    await authorizeSuspectExternalTab(details.tabId, classification.authorizationReason);
    return;
  }
  if (Date.now() < suspected.deferUntil) {
    scheduleSuspectExternalCheck(details.tabId, suspected.deferUntil);
    return;
  }
  const tab = await chrome.tabs.get(details.tabId).catch(() => null);
  if (!tab) {
    await authorizeSuspectExternalTab(details.tabId, "tab_closed");
    return;
  }
  await handlePossibleExternalTabUpdate(details.tabId, {
    url: committedNavigation.url || tab.pendingUrl || tab.url || "",
  }, tab);
}

function isUserNavigationTransition(details) {
  const transitionType = details.transitionType || "";
  if (transitionType === "typed" || transitionType === "auto_bookmark" || transitionType === "keyword") return true;
  const qualifiers = Array.isArray(details.transitionQualifiers) ? details.transitionQualifiers : [];
  return qualifiers.includes("from_address_bar");
}

function scheduleSuspectExternalCheck(tabId, targetAt) {
  const suspected = suspectExternalTabCreates.get(tabId);
  if (!suspected || !Number.isFinite(targetAt)) return;
  if (suspected.checkScheduledAt && suspected.checkScheduledAt <= targetAt) return;
  if (suspected.checkTimer) clearTimeout(suspected.checkTimer);
  const delay = Math.max(0, targetAt - Date.now());
  suspected.checkScheduledAt = targetAt;
  suspected.checkTimer = setTimeout(() => {
    const current = suspectExternalTabCreates.get(tabId);
    if (!current || current.checkScheduledAt !== targetAt) return;
    current.checkScheduledAt = 0;
    current.checkTimer = null;
    chrome.tabs.get(tabId).then((tab) => {
      const url = tab.pendingUrl || tab.url || "";
      handlePossibleExternalTabUpdate(tabId, { url }, tab).catch((error) => {
        console.warn("multiprompt external-tab deferred guard failed:", error?.message || error);
      });
    }).catch(() => {
      authorizeSuspectExternalTab(tabId, "tab_closed").catch(() => {});
    });
  }, delay);
}

async function classifyCommittedNavigation(suspected, committedNavigation) {
  const explicitUserNavigation = isUserNavigationTransition(committedNavigation);
  let bookmarkMatch = null;
  let edgeBookmarkLink = false;
  let nativeBookmarkDrop = false;
  const unqualifiedBookmarkLink = isUnqualifiedBookmarkLinkCommit(committedNavigation);
  const redirectedBookmarkLink = isServerRedirectedBookmarkLinkCommit(committedNavigation);
  const dropAvailable = nativeBrowserDropAvailable(suspected);
  const bookmarkCandidate = isExternalLaunchUrl(committedNavigation.url) &&
    (unqualifiedBookmarkLink || (redirectedBookmarkLink && dropAvailable));
  if (bookmarkCandidate) {
    bookmarkMatch = await isExactBrowserBookmark(committedNavigation.url, redirectedBookmarkLink);
    nativeBookmarkDrop = bookmarkMatch && consumeNativeBrowserDrop(suspected);
    edgeBookmarkLink = bookmarkMatch &&
      ((unqualifiedBookmarkLink && suspected?.focusSettledBeforeCreate === true) || nativeBookmarkDrop);
  }
  const userNavigation = explicitUserNavigation || edgeBookmarkLink;
  const authorizationReason = nativeBookmarkDrop
    ? "native_bookmark_drop"
    : edgeBookmarkLink
    ? "edge_bookmark_link_commit"
    : "user_navigation_commit";
  committedNavigation.userNavigation = userNavigation;
  committedNavigation.authorizationReason = authorizationReason;
  committedNavigation.bookmarkMatch = bookmarkMatch;
  committedNavigation.edgeBookmarkLink = edgeBookmarkLink;
  committedNavigation.nativeBookmarkDrop = nativeBookmarkDrop;
  return {
    userNavigation,
    authorizationReason,
    bookmarkMatch,
    edgeBookmarkLink,
    nativeBookmarkDrop,
  };
}

function isUnqualifiedBookmarkLinkCommit(committedNavigation) {
  if (!committedNavigation || committedNavigation.transitionType !== "link") return false;
  const qualifiers = Array.isArray(committedNavigation.transitionQualifiers)
    ? committedNavigation.transitionQualifiers
    : [];
  return qualifiers.length === 0;
}

function isServerRedirectedBookmarkLinkCommit(committedNavigation) {
  if (!committedNavigation || committedNavigation.transitionType !== "link") return false;
  const qualifiers = Array.isArray(committedNavigation.transitionQualifiers)
    ? committedNavigation.transitionQualifiers
    : [];
  return qualifiers.length === 1 && qualifiers[0] === "server_redirect";
}

function isNativeDropBookmarkLinkCommit(committedNavigation) {
  return isUnqualifiedBookmarkLinkCommit(committedNavigation) ||
    isServerRedirectedBookmarkLinkCommit(committedNavigation);
}

function nativeBrowserDropAvailable(suspected) {
  if (!suspected || !Number.isInteger(suspected.windowId)) return false;
  const gesture = browserDropGestures.get(suspected.windowId);
  if (!gesture || gesture.expires < Date.now() ||
      Math.abs(gesture.at - suspected.observedAt) > BROWSER_DROP_GESTURE_MS) {
    if (gesture?.expires < Date.now()) browserDropGestures.delete(suspected.windowId);
    return false;
  }
  return true;
}

function consumeNativeBrowserDrop(suspected) {
  if (!nativeBrowserDropAvailable(suspected)) return false;
  const gesture = browserDropGestures.get(suspected.windowId);
  browserDropGestures.delete(suspected.windowId);
  gesture.consumedTabId = suspected.tabId;
  return true;
}

function applyNativeBookmarkDrop(committedNavigation, tabId) {
  committedNavigation.userNavigation = true;
  committedNavigation.authorizationReason = "native_bookmark_drop";
  committedNavigation.edgeBookmarkLink = true;
  committedNavigation.nativeBookmarkDrop = true;
  const gesture = browserDropGestures.get(
    [...suspectExternalTabCreates.entries()].find(([id]) => id === tabId)?.[1]?.windowId);
  if (gesture) gesture.consumedTabId = tabId;
}

async function isExactBrowserBookmark(url, allowTrailingSlashVariant = false) {
  const normalized = canonicalUrl(url);
  if (!normalized) return false;
  try {
    const candidates = [normalized];
    if (allowTrailingSlashVariant) {
      try {
        const parsed = new URL(normalized);
        if ((parsed.protocol === "http:" || parsed.protocol === "https:") && parsed.pathname !== "/") {
          parsed.pathname = parsed.pathname.endsWith("/")
            ? parsed.pathname.slice(0, -1)
            : `${parsed.pathname}/`;
          const variant = parsed.href;
          if (variant !== normalized) candidates.push(variant);
        }
      } catch (_) {}
    }
    for (const candidate of candidates) {
      const matches = await chrome.bookmarks.search({ url: candidate });
      if (Array.isArray(matches) && matches.some((bookmark) =>
        candidates.includes(canonicalUrl(bookmark?.url)))) return true;
    }
    return false;
  } catch (error) {
    recordRoutingAudit("bookmark_lookup_failed", {
      url: normalized,
      error: error?.message || String(error),
    }).catch(() => {});
    return false;
  }
}

async function reusableExternalEscapeWindowId() {
  if (!Number.isInteger(externalEscapeWindowId)) {
    const data = await chrome.storage.local.get(EXTERNAL_ESCAPE_WINDOW_KEY).catch(() => ({}));
    const saved = data?.[EXTERNAL_ESCAPE_WINDOW_KEY];
    if (Number.isInteger(saved)) externalEscapeWindowId = saved;
  }
  if (!Number.isInteger(externalEscapeWindowId)) return null;
  if (protectedWindowIds.has(externalEscapeWindowId)) {
    externalEscapeWindowId = null;
    await chrome.storage.local.remove(EXTERNAL_ESCAPE_WINDOW_KEY).catch(() => {});
    return null;
  }
  try {
    const win = await chrome.windows.get(externalEscapeWindowId);
    if (Number.isInteger(win?.id) && !protectedWindowIds.has(win.id)) return win.id;
  } catch (_) {}
  externalEscapeWindowId = null;
  await chrome.storage.local.remove(EXTERNAL_ESCAPE_WINDOW_KEY).catch(() => {});
  return null;
}

async function rememberExternalEscapeWindow(created) {
  if (Number.isInteger(created?.id) && !protectedWindowIds.has(created.id)) {
    externalEscapeWindowId = created.id;
    await chrome.storage.local.set({ [EXTERNAL_ESCAPE_WINDOW_KEY]: created.id });
  }
  return Number.isInteger(created?.id) ? created.id : null;
}

async function openExternalUrlInEscapeWindow(url) {
  const reusableWindowId = await reusableExternalEscapeWindowId();
  if (reusableWindowId != null) {
    await chrome.tabs.create({ windowId: reusableWindowId, url, active: true });
    const focused = await raiseExternalWindow(reusableWindowId);
    return { windowId: reusableWindowId, focused, reused: true };
  }
  const created = await chrome.windows.create({
    url,
    focused: false,
    ...EXTERNAL_WINDOW_BOUNDS,
  });
  const windowId = await rememberExternalEscapeWindow(created);
  const focused = windowId != null ? await raiseExternalWindow(windowId) : false;
  return { windowId, focused, reused: false };
}

async function moveExternalTabOutOfZigShell(tab) {
  const url = tab.pendingUrl || tab.url || "";
  const reusableWindowId = await reusableExternalEscapeWindowId();
  if (reusableWindowId != null) {
    await chrome.tabs.move(tab.id, { windowId: reusableWindowId, index: -1 });
    await chrome.tabs.update(tab.id, { active: true });
    const focused = await raiseExternalWindow(reusableWindowId);
    return { windowId: reusableWindowId, focused, movedOriginalTab: true, reused: true };
  }
  let created;
  let movedOriginalTab = true;
  try {
    created = await chrome.windows.create({ tabId: tab.id, focused: false, ...EXTERNAL_WINDOW_BOUNDS });
  } catch (error) {
    if (!isExternalLaunchUrl(url)) throw error;
    movedOriginalTab = false;
    created = await chrome.windows.create({ url, focused: false, ...EXTERNAL_WINDOW_BOUNDS });
    await chrome.tabs.remove(tab.id).catch(() => {});
  }
  const outWindowId = await rememberExternalEscapeWindow(created);
  const focused = outWindowId ? await raiseExternalWindow(outWindowId) : false;
  return { windowId: outWindowId ?? null, focused, movedOriginalTab, reused: false };
}

async function raiseExternalWindow(_windowId) {
  return false;
}

function isExternalLaunchUrl(url) {
  if (typeof url !== "string" || !url) return false;
  return /^(https?|file):/i.test(url);
}

async function protectedWindowIsFocused(windowId) {
  if (!Number.isInteger(windowId)) return false;
  try {
    const win = await chrome.windows.get(windowId);
    return win?.focused === true;
  } catch (_) {
    return false;
  }
}

function protectedWindowHadSettledFocusBefore(windowId, observedAt) {
  if (!Number.isInteger(windowId) || focusedBrowserWindowId !== windowId) return false;
  const focusedAt = protectedWindowFocusAt.get(windowId);
  if (!Number.isFinite(focusedAt) || !Number.isFinite(observedAt)) return false;
  return observedAt - focusedAt >= PROTECTED_FOCUS_SETTLED_MS;
}

function rememberSuspectExternalTab(tab, deferMs = 0, evidence = {}) {
  if (!tab?.id || !Number.isInteger(tab.windowId)) return null;
  const now = Date.now();
  const expires = now + SUSPECT_EXTERNAL_TAB_MS;
  const recentCommit = committedTopFrameNavigations.get(tab.id);
  const suspected = {
    tabId: tab.id,
    windowId: tab.windowId,
    expires,
    deferUntil: deferMs > 0 ? now + deferMs : 0,
    checkScheduledAt: 0,
    checkTimer: null,
    committedNavigation: recentCommit?.expires >= now ? recentCommit : null,
    observedAt: Number.isFinite(evidence.observedAt) ? evidence.observedAt : now,
    focusSettledBeforeCreate: evidence.focusSettledBeforeCreate === true,
    commitClassificationPromise: null,
    previousMuted: tab?.mutedInfo?.muted === true,
    mutedByGuard: false,
    mutePromise: Promise.resolve(),
  };
  suspectExternalTabCreates.set(tab.id, suspected);
  suspected.mutePromise = (async () => {
    if (suspected.previousMuted) return;
    try {
      await chrome.tabs.update(tab.id, { muted: true });
      suspected.mutedByGuard = true;
    } catch (error) {
      recordRoutingAudit("tab_quarantine_mute_failed", auditWindowDetails(tab.windowId, {
        tabId: tab.id,
        url: tab.pendingUrl || tab.url || "",
        error: error?.message || String(error),
      })).catch(() => {});
    }
  })();
  return suspected;
}

function suspectTransitionAudit(suspected, details = {}) {
  const committed = suspected?.committedNavigation;
  return {
    transitionType: committed?.transitionType || null,
    transitionQualifiers: Array.isArray(committed?.transitionQualifiers)
      ? committed.transitionQualifiers
      : [],
    bookmarkMatch: committed?.bookmarkMatch ?? null,
    focusSettledBeforeCreate: suspected?.focusSettledBeforeCreate === true,
    edgeBookmarkLink: committed?.edgeBookmarkLink === true,
    nativeBookmarkDrop: committed?.nativeBookmarkDrop === true,
    ...details,
  };
}

async function restoreSuspectMute(tabId, suspected) {
  await suspected.mutePromise;
  if (!suspected.mutedByGuard || suspected.previousMuted) return;
  await chrome.tabs.update(tabId, { muted: false }).catch(() => {});
}

async function authorizeSuspectExternalTab(tabId, reason) {
  const suspected = suspectExternalTabCreates.get(tabId);
  if (!suspected) return;
  await suspected.mutePromise;
  if (suspectExternalTabCreates.get(tabId) !== suspected) return;
  suspectExternalTabCreates.delete(tabId);
  if (suspected.checkTimer) clearTimeout(suspected.checkTimer);
  await restoreSuspectMute(tabId, suspected);
  const tab = await chrome.tabs.get(tabId).catch(() => null);
  await recordRoutingAudit("tab_authorized", auditWindowDetails(suspected.windowId, suspectTransitionAudit(suspected, {
    tabId,
    url: tab?.pendingUrl || tab?.url || "",
    reason,
    finalizationReason: reason,
  })));
}

async function deflectSuspectExternalTab(tab, url, finalizationReason) {
  const suspected = suspectExternalTabCreates.get(tab.id);
  if (!suspected) return;
  await suspected.mutePromise;
  if (suspectExternalTabCreates.get(tab.id) !== suspected) return;
  suspectExternalTabCreates.delete(tab.id);
  if (suspected.checkTimer) clearTimeout(suspected.checkTimer);

  recordRoutingAudit("external_tab_deflect_started", auditWindowDetails(tab.windowId, suspectTransitionAudit(suspected, {
    tabId: tab.id,
    url,
    finalizationReason,
  }))).catch(() => {});
  try {
    const result = await moveExternalTabOutOfZigShell(tab);
    if (result.movedOriginalTab) await restoreSuspectMute(tab.id, suspected);
    await recordRoutingAudit("external_tab_deflected", auditWindowDetails(tab.windowId, suspectTransitionAudit(suspected, {
      tabId: tab.id,
      url,
      finalizationReason,
      destinationWindowId: result.windowId,
      destinationFocused: result.focused,
      movedOriginalTab: result.movedOriginalTab,
      reusedDestination: result.reused,
    })));
  } catch (error) {
    await recordRoutingAudit("external_tab_deflect_failed", auditWindowDetails(tab.windowId, suspectTransitionAudit(suspected, {
      tabId: tab.id,
      url,
      finalizationReason,
      muted: suspected.mutedByGuard || suspected.previousMuted,
      error: error?.message || String(error),
    })));
    throw error;
  }
}

function canonicalUrl(url) {
  if (typeof url !== "string") return "";
  const trimmed = url.trim();
  if (!trimmed) return "";
  try {
    return new URL(trimmed).href;
  } catch (_) {
    return trimmed;
  }
}

function isUsableExternalWindow(win) {
  if (!win || win.state === "minimized") return false;
  if (!Number.isFinite(win.left) || !Number.isFinite(win.top)) return true;
  if (win.left < -8000 || win.top < -8000) return false;
  if (Number.isFinite(win.width) && win.width < 320) return false;
  if (Number.isFinite(win.height) && win.height < 240) return false;
  return true;
}

function sendResponse(request, response) {
  if (!request.replyPipe && !request.id) return;

  connect().postMessage({
    id: request.id ?? null,
    replyPipe: request.replyPipe,
    extensionVersion: chrome.runtime.getManifest().version,
    ...response,
  });
}

function installContextMenus() {
  chrome.contextMenus.removeAll(() => {
    chrome.contextMenus.create({
      id: SHOT_URL_MENU_ID,
      contexts: ["action"],
      title: "Take tab screenshot \u2192 link into shell",
    });
  });
}

function requestHostReply(method, fields = {}, timeoutMs = 10000) {
  const id = crypto.randomUUID();
  return new Promise((resolve, reject) => {
    const timer = setTimeout(() => {
      pendingHostReplies.delete(id);
      reject(new Error(`${method} timed out`));
    }, timeoutMs);
    pendingHostReplies.set(id, { resolve, reject, timer });
    try {
      connect().postMessage({ id, method, ...fields });
    } catch (error) {
      clearTimeout(timer);
      pendingHostReplies.delete(id);
      reject(error);
    }
  });
}

function routePendingHostReply(message) {
  const id = message?.id;
  if (typeof id !== "string" || !pendingHostReplies.has(id)) return false;
  const pending = pendingHostReplies.get(id);
  pendingHostReplies.delete(id);
  clearTimeout(pending.timer);
  if (message.ok === false || message.error) {
    pending.reject(new Error(message.error || "native host request failed"));
  } else {
    pending.resolve(message.result ?? message);
  }
  return true;
}

function rejectPendingHostReplies(reason) {
  for (const [id, pending] of pendingHostReplies) {
    clearTimeout(pending.timer);
    pending.reject(new Error(reason));
    pendingHostReplies.delete(id);
  }
}

async function navigate(message) {
  const url = normalizeUrl(message.url);
  if (!url) throw new Error("missing url");

  const wid = Number.isInteger(message?.windowId) ? message.windowId : null;
  if (wid == null) throw new Error("no multiprompt browser window bound for this session — open a pane (multiprompt-browser open / Alt+A) first; refusing to open a link in another window");
  const [activePaneTab] = await chrome.tabs.query({ active: true, windowId: wid }).catch(() => []);
  const activate = message?.activate === true;
  if (!activate && message?.newTab !== true) {
    const target = await getRememberedZsbTargetTab(wid);
    const provenance = target && agentNavigateTabs.get(target.id);
    if (provenance?.windowId === wid && !target.active && !userOwnedTabs.has(target.id)) {
      await acceptPendingDialog(target.id);
      const current = await chrome.tabs.get(target.id).catch(() => null);
      if (current?.windowId === wid && !current.active && agentNavigateTabs.get(target.id) === provenance &&
          zsbTargetTabsByWindow.get(wid) === target.id && !userOwnedTabs.has(target.id)) {
        provenance.pendingUrls.add(canonicalUrl(url));
        const loaded = await chrome.tabs.update(target.id, { url }).catch(() => null);
        if (loaded) {
          rememberZsbTargetTab(wid, loaded.id);
          return { tab: compactTab(loaded) };
        }
        agentNavigateTabs.delete(target.id);
      }
    }
  }
  const createOpts = { url, active: activate, windowId: wid };
  if (Number.isInteger(activePaneTab?.index)) createOpts.index = activePaneTab.index + 1;
  rememberZigShellTabCreate(wid, url);
  let tab = await chrome.tabs.create(createOpts);
  if (tab?.id && tab.windowId !== wid) {
    tab = await chrome.tabs.move(tab.id, { windowId: wid, index: createOpts.index ?? -1 });
    tab = Array.isArray(tab) ? tab[0] : tab;
    if (tab?.id && activate) tab = await chrome.tabs.update(tab.id, { active: true });
  }
  rememberZsbTargetTab(wid, tab?.id);
  if (tab?.id && !activate && !tab.active && !userOwnedTabs.has(tab.id)) {
    agentNavigateTabs.set(tab.id, { windowId: wid, pendingUrls: new Set([canonicalUrl(url)]) });
  }

  if (tab?.id) tab = await ensureBackgroundTabFocusEmulation(tab);
  return { tab: compactTab(tab) };
}

async function createPaneWindow(message) {
  const url = typeof message?.url === "string" ? message.url : "";
  if (!url.startsWith(PANE_BEACON_URL_PREFIX)) throw new Error("createPaneWindow only opens a pane launch placeholder");
  const options = { url, focused: false, type: message?.app === true ? "popup" : "normal" };
  for (const field of ["left", "top", "width", "height"]) {
    if (Number.isInteger(message?.[field])) options[field] = message[field];
  }
  const created = await chrome.windows.create(options);
  return { windowId: Number.isInteger(created?.id) ? created.id : null, focused: false };
}

async function historyNav(message, forward) {
  const tab = await getTargetTab(message);
  await acceptPendingDialog(tab.id);
  if (forward) {
    await chrome.tabs.goForward(tab.id);
  } else {
    await chrome.tabs.goBack(tab.id);
  }
  const updated = await chrome.tabs.get(tab.id).catch(() => tab);
  return { tab: compactTab(updated || tab) };
}

async function reloadAction(message) {
  const tab = await getTargetTab(message);
  await acceptPendingDialog(tab.id);
  await chrome.tabs.reload(tab.id);
  const updated = await chrome.tabs.get(tab.id).catch(() => tab);
  return { tab: compactTab(updated || tab) };
}

async function listTabs(message) {
  const wid = Number.isInteger(message?.windowId) ? message.windowId : null;
  if (wid == null) return { tabs: [] };
  const tabs = await chrome.tabs.query({ windowId: wid });
  if (tabs.length === 0) throw new Error(paneWindowNotFoundMessage(wid));
  const remembered = await getRememberedZsbTargetTab(wid);
  const target = remembered?.id ? remembered : paneContentTab(tabs);
  return {
    tabs: tabs.map((tab) => ({ ...compactTab(tab), target: tab.id === target?.id })),
  };
}

async function activateTab(message) {
  const wid = messageWindowId(message);
  if (wid == null) throw new Error("activate requires a multiprompt browser window");
  const tabId = Number(message?.tabId);
  if (!Number.isInteger(tabId) || tabId <= 0) throw new Error("activate requires a positive tabId");

  const existing = await chrome.tabs.get(tabId).catch(() => null);
  if (!existing?.id) throw new Error(`tab ${tabId} not found`);
  if (existing.windowId !== wid) {
    throw new Error(`tab ${tabId} does not belong to multiprompt browser window ${wid}; refusing cross-pane activation`);
  }

  if (message?.targetOnly === true) {
    rememberZsbTargetTab(wid, tabId);
    return { tab: compactTab(existing), targetOnly: true };
  }
  const tab = await chrome.tabs.update(tabId, { active: true });
  rememberZsbTargetTab(wid, tabId);
  return { tab: compactTab(tab) };
}

async function closeTabAction(message) {
  const wid = messageWindowId(message);
  if (wid == null) throw new Error("close-tab requires a multiprompt browser window");
  const tab = await resolveExplicitTargetTab(wid, message, true);
  const tabs = await chrome.tabs.query({ windowId: wid });
  if (tabs.length <= 1) throw new Error("refusing to close the last tab in a multiprompt browser pane");
  await acceptPendingDialog(tab.id);
  await chrome.tabs.remove(tab.id);
  return { closed: true, tab: compactTab(tab) };
}

async function urlAction(message) {
  const tab = await getTargetTab(message);
  return { url: tab.pendingUrl || tab.url || "", tab: compactTab(tab) };
}

async function getActiveTab() {
  const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });
  if (!tab?.id) throw new Error("no active tab");
  return tab;
}

const PANE_BEACON_URL_PREFIX = "data:text/html,<title>ZSPANE";

function isPaneBeaconTab(tab) {
  return typeof tab?.url === "string" && tab.url.startsWith(PANE_BEACON_URL_PREFIX);
}

function isExtensionTab(tab) {
  return [tab?.url, tab?.pendingUrl].some((url) => /^[a-z][a-z0-9+.-]*-extension:\/\//i.test(url || ""));
}

function paneContentTab(tabs) {
  const active = tabs.find((tab) => tab.active && !isExtensionTab(tab));
  if (active && !isPaneBeaconTab(active)) return active;
  const content = tabs.filter((tab) => !isPaneBeaconTab(tab) && !isExtensionTab(tab));
  if (content.length > 0) return content[content.length - 1];
  return active || null;
}

function paneWindowNotFoundMessage(windowId) {
  return `multiprompt session browser window ${windowId} not found (no active tab); refusing to touch another window`;
}

async function paneWindowShowsBeacon(windowId) {
  const [active] = await chrome.tabs.query({ active: true, windowId }).catch(() => []);
  return isPaneBeaconTab(active);
}

async function getTargetTab(message) {
  const wid = Number.isInteger(message?.windowId) ? message.windowId : null;
  if (wid == null) throw new Error("no multiprompt browser window bound for this session — open a pane first; refusing to touch another window");
  const explicit = await resolveExplicitTargetTab(wid, message, false);
  if (explicit?.id) {
    if (isExtensionTab(explicit)) throw new Error("refusing to automate an extension tab");
    return ensureBackgroundTabFocusEmulation(explicit);
  }
  const remembered = await getRememberedZsbTargetTab(wid);
  if (remembered?.id && !isPaneBeaconTab(remembered)) return ensureBackgroundTabFocusEmulation(remembered);
  const t = paneContentTab(await chrome.tabs.query({ windowId: wid }));
  if (t?.id) return ensureBackgroundTabFocusEmulation(t);
  throw new Error(paneWindowNotFoundMessage(wid));
}

async function resolveExplicitTargetTab(windowId, message, required) {
  const numeric = Number(message?.tabId);
  const raw = typeof message?.tab === "string" ? message.tab.trim() : "";
  if (!Number.isInteger(numeric) && !raw) {
    if (required) throw new Error("a tab id or title/URL match is required");
    return null;
  }

  const tabs = await chrome.tabs.query({ windowId });
  if (tabs.length === 0) throw new Error(paneWindowNotFoundMessage(windowId));
  if (Number.isInteger(numeric) && numeric > 0) {
    const tab = tabs.find((candidate) => candidate.id === numeric);
    if (!tab) throw new Error(`tab ${numeric} does not belong to multiprompt browser window ${windowId}`);
    return tab;
  }

  if (/^[0-9]+$/.test(raw)) {
    const id = Number(raw);
    const tab = tabs.find((candidate) => candidate.id === id);
    if (!tab) throw new Error(`tab ${id} does not belong to multiprompt browser window ${windowId}`);
    return tab;
  }

  const needle = raw.toLowerCase();
  const matches = tabs.filter((candidate) =>
    String(candidate.url || "").toLowerCase().includes(needle) ||
    String(candidate.title || "").toLowerCase().includes(needle));
  if (matches.length === 0) throw new Error(`no tab title or URL matches: ${raw}`);
  if (matches.length > 1) {
    const exact = matches.filter((candidate) =>
      String(candidate.url || "").toLowerCase() === needle ||
      String(candidate.title || "").toLowerCase() === needle);
    if (exact.length === 1) return exact[0];
    throw new Error(`tab match is ambiguous: ${raw} (${matches.map((candidate) => candidate.id).join(", ")})`);
  }
  return matches[0];
}

async function ensureBackgroundTabFocusEmulation(tab) {
  if (!tab?.id || tab.active || focusEmulatedTabs.has(tab.id)) return tab;
  try {
    await withCdpSession(tab.id, (debuggee) =>
      chrome.debugger.sendCommand(debuggee, "Emulation.setFocusEmulationEnabled", { enabled: true }));
    focusEmulatedTabs.add(tab.id);
  } catch (error) {
    console.warn(`multiprompt focus emulation failed for tab ${tab.id}:`, error?.message || error);
  }
  return chrome.tabs.get(tab.id).catch(() => tab);
}

function rememberZsbTargetTab(windowId, tabId) {
  if (!Number.isInteger(windowId) || !Number.isInteger(tabId)) return;
  zsbTargetTabsByWindow.set(windowId, tabId);
  scheduleProtectedWindowSave();
}

async function getRememberedZsbTargetTab(windowId) {
  await loadProtectedWindows();
  const tabId = zsbTargetTabsByWindow.get(windowId);
  if (!Number.isInteger(tabId)) return null;
  try {
    const tab = await chrome.tabs.get(tabId);
    if (tab?.windowId === windowId && !isExtensionTab(tab) && !isPaneBeaconTab(tab)) return tab;
  } catch (_) {}
  zsbTargetTabsByWindow.delete(windowId);
  scheduleProtectedWindowSave();
  return null;
}

async function getSnapshot(limit, message) {
  const tab = await getTargetTab(message);
  try {
    const frameResults = await runInAllFrames(tab.id, getCompactSnapshot, [limit]);
    const pages = frameResults.filter((entry) => entry.result && typeof entry.result === "object");
    const top = pages.find((entry) => entry.frameId === 0)?.result || pages[0]?.result || {};
    const textParts = pages.map((entry) => entry.result.text).filter(Boolean);
    const text = textParts.join("\n\n");
    const textLengths = pages.map((entry) => entry.result.textLength).filter((length) => length > 0);
    const totalLength = textLengths.reduce((sum, length) => sum + length, 0) + Math.max(0, textLengths.length - 1) * 2;
    const headings = pages.flatMap((entry) => (entry.result.headings || []).map((item) => ({
      ...item,
      frameId: entry.frameId,
      frameUrl: entry.result.url,
    })));
    const controls = pages.flatMap((entry) => (entry.result.controls || []).map((item) => ({
      ...item,
      frameId: entry.frameId,
      frameUrl: entry.result.url,
    })));
    return {
      tab: compactTab(tab),
      url: top.url || tab.url,
      title: top.title || tab.title,
      text: text.slice(0, limit),
      textLength: totalLength,
      total_length: totalLength,
      truncated: totalLength > limit,
      ...(totalLength > limit ? { hint: `use --limit ${totalLength} for more` } : {}),
      headings,
      controls,
      frames: pages.map((entry) => ({ frameId: entry.frameId, url: entry.result.url, title: entry.result.title })),
    };
  } catch (error) {
    if (isPageScriptingError(error)) return pageErrorResult(tab, error);
    throw error;
  }
}

async function runInActiveTab(func, args = [], message) {
  const tab = await getTargetTab(message);
  return runInTab(tab.id, func, args);
}

async function textAction(message) {
  const tab = await getTargetTab(message);
  try {
    const limit = numberOr(message.limit, 2000);
    const frameResults = await runInAllFrames(tab.id, getVisibleText, [limit]);
    const frames = frameResults.filter((entry) => entry.result && typeof entry.result === "object");
    const text = frames.map((entry) => entry.result.text).filter(Boolean).join("\n\n");
    const lengths = frames.map((entry) => entry.result.length).filter((length) => length > 0);
    const totalLength = lengths.reduce((sum, length) => sum + length, 0) + Math.max(0, lengths.length - 1) * 2;
    return {
      tab: compactTab(tab),
      url: frames.find((entry) => entry.frameId === 0)?.result?.url || tab.url,
      length: text.slice(0, limit).length,
      total_length: totalLength,
      text: text.slice(0, limit),
      truncated: totalLength > limit,
      ...(totalLength > limit ? { hint: `use --limit ${totalLength} for more` } : {}),
      frames: frames.map((entry) => ({ frameId: entry.frameId, url: entry.result.url, length: entry.result.length })),
    };
  } catch (error) {
    if (isPageScriptingError(error)) return pageErrorResult(tab, error);
    throw error;
  }
}

function errorText(error) {
  return error?.message || String(error);
}

function isPageScriptingError(error) {
  const msg = errorText(error).toLowerCase();
  return msg.includes("frame") ||
    msg.includes("error page") ||
    msg.includes("cannot access") ||
    msg.includes("cannot script") ||
    msg.includes("chrome://") ||
    msg.includes("edge://") ||
    msg.includes("chrome-error://") ||
    msg.includes("no tab with id") ||
    msg.includes("the tab was closed") ||
    msg.includes("extensions gallery cannot be scripted") ||
    msg.includes("scripting");
}

function pageErrorResult(tab, error) {
  return {
    error: "page_error",
    url: tab.url,
    pendingUrl: tab.pendingUrl,
    status: tab.status,
    message: errorText(error),
  };
}

async function framesAction(message) {
  const tab = await getTargetTab(message);
  const frames = await chrome.webNavigation.getAllFrames({ tabId: tab.id });
  return { tab: compactTab(tab), frames: (frames || []).map(({ frameId, parentFrameId, url }) => ({ frameId, parentFrameId, url })) };
}

async function evalAction(message) {
  const tab = await getTargetTab(message);
  const frameId = message.frameId ?? 0;
  if (!Number.isInteger(frameId) || frameId < 0) throw new Error("invalid frameId");
  if (frameId === 0 && /^data:/i.test(tab.url || "")) {
    return runInDataTab(tab.id, evalInPage, [stringOr(message.code, "")]);
  }
  const code = stringOr(message.code, "");
  const blockedByCsp = (error) => /unsafe-eval|content security policy|\bCSP\b/i.test(errorText(error));
  try {
    const [entry] = await chrome.scripting.executeScript({
      target: { tabId: tab.id, frameIds: [frameId] },
      world: "MAIN",
      func: evalInPage,
      args: [code],
    });
    if (!entry) throw new Error(`no evaluation result for frame ${frameId}`);
    if (entry?.error) throw new Error(entry.error.message || String(entry.error));
    if (typeof entry?.result !== "string" || !/^EvalError:/i.test(entry.result) || !blockedByCsp(entry.result)) {
      return entry?.result;
    }
  } catch (error) {
    if (!blockedByCsp(error)) throw error;
  }

  if (frameId !== 0) throw new Error(`eval in frame ${frameId} blocked by Content Security Policy`);
  return withCdpSession(tab.id, async (debuggee) => {
    const reply = await chrome.debugger.sendCommand(debuggee, "Runtime.evaluate", {
      expression: `(${evalInPage.toString()})(${JSON.stringify(code)}, () => { "use strict"; return (${code}); })`,
      returnByValue: true,
      awaitPromise: true,
    });
    if (reply.exceptionDetails) return reply.exceptionDetails.exception?.description || reply.exceptionDetails.text || "eval failed";
    return reply.result?.value;
  });
}

function isExtensionFrameAccessError(error) {
  return /Cannot access a chrome-extension:\/\/ URL of different extension/i.test(error?.message || String(error));
}

async function runInDataTab(tabId, func, args) {
  try {
    return await withCdpSession(tabId, async (debuggee) => {
      const reply = await chrome.debugger.sendCommand(debuggee, "Runtime.evaluate", {
        expression: `(${func.toString()})(...${JSON.stringify(args)})`,
        returnByValue: true,
        awaitPromise: true,
      });
      if (reply.exceptionDetails) throw new Error(reply.exceptionDetails.exception?.description || reply.exceptionDetails.text || "data page scripting failed");
      return reply.result?.value;
    });
  } catch (error) {
    if (!isExtensionFrameAccessError(error)) throw error;
  }
  const [entry] = await chrome.scripting.executeScript({ target: { tabId, frameIds: [0] }, func, args });
  if (entry?.error) throw new Error(entry.error.message || String(entry.error));
  return entry?.result;
}

async function runInTab(tabId, func, args = []) {
  const tab = await chrome.tabs.get(tabId);
  if (/^data:/i.test(tab.url || "")) return runInDataTab(tabId, func, args);
  const [entry] = await chrome.scripting.executeScript({
    target: { tabId },
    func,
    args,
  });
  if (entry?.error) throw new Error(entry.error.message || String(entry.error));
  return entry?.result;
}

async function runInFrame(tabId, frameId, func, args = []) {
  const tab = await chrome.tabs.get(tabId);
  if (frameId === 0 && /^data:/i.test(tab.url || "")) return runInDataTab(tabId, func, args);
  const [entry] = await chrome.scripting.executeScript({
    target: { tabId, frameIds: [frameId] },
    func,
    args,
  });
  if (entry?.error) throw new Error(entry.error.message || String(entry.error));
  return entry?.result;
}

async function runInAllFrames(tabId, func, args = []) {
  const frames = await chrome.webNavigation.getAllFrames({ tabId });
  const results = await Promise.all((frames || []).filter((frame) => !isExtensionTab(frame)).map(async (frame) => {
    try {
      return { frameId: frame.frameId, result: await runInFrame(tabId, frame.frameId, func, args) };
    } catch (error) {
      if (frame.frameId === 0) throw error;
      return { frameId: frame.frameId, error };
    }
  }));
  const completed = (results || [])
    .filter((entry) => !entry.error)
    .map((entry) => ({ frameId: Number(entry.frameId || 0), result: entry.result }));
  if (completed.length === 0) {
    const failed = (results || []).find((entry) => entry.error);
    if (failed) throw new Error(failed.error.message || String(failed.error));
  }
  return completed;
}


const CURSOR_DEFAULTS = {
  size: 22,
  color: "#111827",
  speedPxPerMs: 1.2,
  minDurationMs: 160,
  maxDurationMs: 700,
  zIndex: 2147483647,
};

function cursorOptionsFrom(message) {
  return {
    size: numberOr(message.size, CURSOR_DEFAULTS.size),
    color: stringOr(message.color, CURSOR_DEFAULTS.color),
    speedPxPerMs: CURSOR_DEFAULTS.speedPxPerMs,
    minDurationMs: CURSOR_DEFAULTS.minDurationMs,
    maxDurationMs: CURSOR_DEFAULTS.maxDurationMs,
    zIndex: CURSOR_DEFAULTS.zIndex,
  };
}

async function clickAction(message) {
  const tab = await getTargetTab(message);
  await runInTab(tab.id, installCursorApi, [cursorOptionsFrom(message)]).catch(() => {});
  const selector = stringOr(message.selector, "");
  let target = await locateSelectorAcrossFrames(tab.id, selector, false);
  const offset = await frameViewportOffset(tab.id, target.frameId);
  let reason = "frame coordinates unavailable";
  if (offset) {
    if (target.frameId !== 0) {
      target = { ...await runInFrame(tab.id, target.frameId, locateSelectorForTrustedInput, [selector, false, false, false]), frameId: target.frameId };
    }
    const x = Number(target.x) + Number(offset.x);
    const y = Number(target.y) + Number(offset.y);
    if (!Number.isFinite(x) || !Number.isFinite(y)) {
      throw new Error(`invalid cross-frame click coordinates: target=${JSON.stringify(target)} offset=${JSON.stringify(offset)}`);
    }
    let inputStarted = false;
    try {
      await withCdpSession(tab.id, (debuggee) => {
        inputStarted = true;
        return dispatchTrustedClick(debuggee, x, y);
      });
      return { clicked: true, trusted: true, selector, text: target.text, frameId: target.frameId, via: "cdp", x, y };
    } catch (error) {
      if (inputStarted || /timed out/i.test(errorText(error))) throw error;
      reason = `debugger unavailable: ${errorText(error)}`;
    }
  }
  const fallback = await runInFrame(tab.id, target.frameId, clickSelector, [selector]);
  return { ...fallback, trusted: false, frameId: target.frameId, via: "frame-dom-fallback", reason };
}

async function typeAction(message) {
  const tab = await getTargetTab(message);
  const selector = stringOr(message.selector, "");
  const text = stringOr(message.text, "");
  let target = null;
  if (selector) {
    await runInTab(tab.id, installCursorApi, [cursorOptionsFrom(message)]).catch(() => {});
    target = await locateSelectorAcrossFrames(tab.id, selector, true);
  } else {
    const focused = await runInTab(tab.id, getFocusedEditableTarget);
    if (!focused?.editable) throw new Error("type requires a focused editable or a CSS selector");
  }
  await withCdpSession(tab.id, async (debuggee) => {
    if (target) {
      const offset = await frameViewportOffset(tab.id, target.frameId);
      if (!offset) throw new Error(`cannot resolve viewport offset for frame ${target.frameId}`);
      await dispatchTrustedClick(debuggee, target.x + offset.x, target.y + offset.y);
      await dispatchSelectAll(debuggee);
    }
    if (message.keys === true) {
      await dispatchTrustedKeys(debuggee, text);
    } else {
      await dispatchTrustedText(debuggee, text);
    }
  });
  return { typed: true, trusted: true, mode: message.keys === true ? "keys" : "text", selector: selector || undefined, frameId: target?.frameId, length: text.length };
}

async function locateSelectorAcrossFrames(tabId, selector, requireEditable) {
  const target = await runInTab(tabId, locateSelectorForTrustedInput, [selector, requireEditable, true]);
  if (target?.found !== false && target?.x != null) {
    return { ...target, frameId: 0 };
  }
  const results = await runInAllFrames(tabId, locateSelectorForTrustedInput, [selector, requireEditable, true]);
  const matches = results.filter((entry) => entry.result?.found !== false && entry.result?.x != null);
  if (matches.length === 0) throw new Error(`selector not found: ${selector}`);
  if (matches.length > 1) throw new Error(`selector matches more than one frame: ${selector}`);
  return { ...matches[0].result, frameId: matches[0].frameId };
}

async function frameViewportOffset(tabId, frameId) {
  if (!Number.isInteger(frameId) || frameId === 0) return { x: 0, y: 0 };
  const frames = await chrome.webNavigation.getAllFrames({ tabId }).catch(() => []);
  const byId = new Map((frames || []).map((frame) => [frame.frameId, frame]));
  let current = byId.get(frameId);
  let x = 0;
  let y = 0;
  const visited = new Set();
  while (current && current.frameId !== 0) {
    if (visited.has(current.frameId)) return null;
    visited.add(current.frameId);
    const parent = byId.get(current.parentFrameId);
    if (!parent) return null;
    const token = crypto.randomUUID();
    let rect = null;
    try {
      await runInFrame(tabId, parent.frameId, locateChildFrameRect, [token, "listen"]);
      await runInFrame(tabId, current.frameId, signalParentFrame, [token]);
      rect = await runInFrame(tabId, parent.frameId, locateChildFrameRect, [token, "rect"]);
    } catch (_) {
      await runInFrame(tabId, parent.frameId, locateChildFrameRect, [token, "cancel"]).catch(() => {});
    }
    if (!rect) return null;
    x += rect.x;
    y += rect.y;
    current = parent;
  }
  return current?.frameId === 0 ? { x, y } : null;
}

async function insertAction(message) {
  const tab = await getTargetTab(message);
  const text = stringOr(message.text, "");
  await withCdpSession(tab.id, (debuggee) => dispatchTrustedText(debuggee, text));
  return { inserted: text.length, trusted: true };
}

async function dispatchTrustedText(debuggee, text) {
  const lines = text.split("\n");
  for (let i = 0; i < lines.length; i += 1) {
    if (lines[i].length > 0) {
      await chrome.debugger.sendCommand(debuggee, "Input.insertText", { text: lines[i] });
    }
    if (i < lines.length - 1) await dispatchEnter(debuggee);
  }
}

async function dispatchTrustedKeys(debuggee, text) {
  for (const character of text.replace(/\r\n?/g, "\n")) {
    if (character === "\n") {
      await dispatchEnter(debuggee);
      continue;
    }
    const common = printableKeyDescriptor(character);
    await chrome.debugger.sendCommand(debuggee, "Input.dispatchKeyEvent", {
      type: "keyDown", ...common, text: character, unmodifiedText: character,
    });
    await chrome.debugger.sendCommand(debuggee, "Input.dispatchKeyEvent", {
      type: "keyUp", ...common,
    });
  }
}

function printableKeyDescriptor(character) {
  const common = { key: character, modifiers: 0 };
  if (/^[a-zA-Z]$/.test(character)) {
    const upper = character.toUpperCase();
    return { ...common, code: `Key${upper}`, windowsVirtualKeyCode: upper.charCodeAt(0), modifiers: character === upper ? 8 : 0 };
  }
  if (/^[0-9]$/.test(character)) {
    return { ...common, code: `Digit${character}`, windowsVirtualKeyCode: character.charCodeAt(0) };
  }
  const punctuation = [
    ["-", "_", "Minus", 189], ["=", "+", "Equal", 187],
    ["[", "{", "BracketLeft", 219], ["]", "}", "BracketRight", 221],
    [";", ":", "Semicolon", 186], ["'", '"', "Quote", 222],
    [",", "<", "Comma", 188], [".", ">", "Period", 190],
    ["/", "?", "Slash", 191], ["\\", "|", "Backslash", 220],
    ["`", "~", "Backquote", 192], [" ", " ", "Space", 32],
  ];
  for (const [plain, shifted, code, windowsVirtualKeyCode] of punctuation) {
    if (character === plain || character === shifted) {
      return { ...common, code, windowsVirtualKeyCode, modifiers: character !== plain ? 8 : 0 };
    }
  }
  const shiftedDigit = ")!@#$%^&*(".indexOf(character);
  if (shiftedDigit >= 0) return { ...common, code: `Digit${shiftedDigit}`, windowsVirtualKeyCode: 48 + shiftedDigit, modifiers: 8 };
  return common;
}

async function linksAction(message) {
  const tab = await getTargetTab(message);
  const limit = numberOr(message.limit, 50);
  try {
    const frameResults = await runInAllFrames(tab.id, getLinks, [limit]);
    const links = frameResults.flatMap((entry) => (entry.result?.links || []).map((link) => ({
      ...link,
      frameId: entry.frameId,
      frameUrl: entry.result?.url,
    }))).slice(0, limit);
    const totalLength = frameResults.reduce((sum, entry) => sum + (entry.result?.count || 0), 0);
    return {
      tab: compactTab(tab), count: links.length, links,
      total_length: totalLength,
      truncated: totalLength > limit,
      ...(totalLength > limit ? { hint: `use --limit ${totalLength} for more` } : {}),
    };
  } catch (error) {
    if (isPageScriptingError(error)) return pageErrorResult(tab, error);
    throw error;
  }
}

async function findAction(message) {
  const tab = await getTargetTab(message);
  const query = stringOr(message.query, "");
  const limit = numberOr(message.limit, 20);
  try {
    const frameResults = await runInAllFrames(tab.id, findText, [query, limit]);
    const matches = frameResults.flatMap((entry) => (entry.result?.matches || []).map((match) => ({
      ...match,
      frameId: entry.frameId,
      frameUrl: entry.result?.url,
    }))).slice(0, limit);
    return { tab: compactTab(tab), query, count: matches.length, matches };
  } catch (error) {
    if (isPageScriptingError(error)) return pageErrorResult(tab, error);
    throw error;
  }
}

async function dispatchTrustedClick(debuggee, x, y) {
  const common = { x, y, button: "left", clickCount: 1 };
  await chrome.debugger.sendCommand(debuggee, "Input.dispatchMouseEvent", {
    type: "mouseMoved", x, y, button: "none", buttons: 0,
  });
  await chrome.debugger.sendCommand(debuggee, "Input.dispatchMouseEvent", {
    type: "mousePressed", ...common, buttons: 1,
  });
  await chrome.debugger.sendCommand(debuggee, "Input.dispatchMouseEvent", {
    type: "mouseReleased", ...common, buttons: 0,
  });
}

async function dispatchSelectAll(debuggee) {
  const common = {
    key: "a", code: "KeyA", windowsVirtualKeyCode: 65,
    nativeVirtualKeyCode: 65, modifiers: 2,
  };
  await chrome.debugger.sendCommand(debuggee, "Input.dispatchKeyEvent", { type: "rawKeyDown", ...common });
  await chrome.debugger.sendCommand(debuggee, "Input.dispatchKeyEvent", { type: "keyUp", ...common });
}

async function dispatchEnter(debuggee) {
  const base = {
    key: "Enter",
    code: "Enter",
    windowsVirtualKeyCode: 13,
    nativeVirtualKeyCode: 13,
  };
  await chrome.debugger.sendCommand(debuggee, "Input.dispatchKeyEvent", {
    type: "rawKeyDown",
    ...base,
  });
  await chrome.debugger.sendCommand(debuggee, "Input.dispatchKeyEvent", {
    type: "char",
    ...base,
    text: "\r",
    unmodifiedText: "\r",
  });
  await chrome.debugger.sendCommand(debuggee, "Input.dispatchKeyEvent", {
    type: "keyUp",
    ...base,
  });
}

async function cursorAction(message) {
  const tab = await getTargetTab(message);
  const action = stringOr(message.action, "on");
  const x = Number(message.x);
  const y = Number(message.y);
  if (action !== "off") {
    await runInTab(tab.id, installCursorApi, [cursorOptionsFrom(message)]).catch(() => {});
  }
  return runInTab(tab.id, cursorControl, [
    action,
    Number.isFinite(x) ? x : null,
    Number.isFinite(y) ? y : null,
  ]);
}

async function keyAction(message) {
  const tab = await getTargetTab(message);
  const keyEvent = parseKeyCombo(stringOr(message.combo, ""));
  return withCdpSession(tab.id, async (debuggee) => {
    const base = {
      key: keyEvent.key,
      code: keyEvent.code,
      windowsVirtualKeyCode: keyEvent.keyCode,
      nativeVirtualKeyCode: keyEvent.keyCode,
      modifiers: keyEvent.modifiers,
      autoRepeat: false,
      isKeypad: false,
    };
    await chrome.debugger.sendCommand(debuggee, "Input.dispatchKeyEvent", {
      type: "rawKeyDown",
      ...base,
      text: keyEvent.text,
      unmodifiedText: keyEvent.unmodifiedText,
    });
    await chrome.debugger.sendCommand(debuggee, "Input.dispatchKeyEvent", {
      type: "keyUp",
      ...base,
    });
    return {
      combo: keyEvent.combo,
      key: keyEvent.key,
      code: keyEvent.code,
      modifiers: keyEvent.modifierNames,
      via: "Input.dispatchKeyEvent",
    };
  });
}

function parseKeyCombo(combo) {
  const text = String(combo || "").trim();
  if (!text) throw new Error("missing key combo");

  const parts = text.split("+").map((part) => part.trim()).filter(Boolean);
  if (!parts.length) throw new Error("missing key combo");

  let alt = false;
  let ctrl = false;
  let meta = false;
  let shift = false;
  let keyPart = "";

  for (const part of parts) {
    const normalized = part.toLowerCase().replace(/\s+/g, "");
    if (normalized === "alt" || normalized === "option") {
      alt = true;
    } else if (normalized === "ctrl" || normalized === "control") {
      ctrl = true;
    } else if (normalized === "shift") {
      shift = true;
    } else if (normalized === "meta" || normalized === "cmd" || normalized === "command" || normalized === "win" || normalized === "windows" || normalized === "super") {
      meta = true;
    } else {
      if (keyPart) throw new Error(`multiple non-modifier keys in combo: ${combo}`);
      keyPart = part;
    }
  }

  if (!keyPart) throw new Error(`missing non-modifier key in combo: ${combo}`);

  const descriptor = keyDescriptor(keyPart, shift);
  const modifiers = (alt ? 1 : 0) | (ctrl ? 2 : 0) | (meta ? 4 : 0) | (shift ? 8 : 0);
  const hasShortcutModifier = alt || ctrl || meta;
  const modifierNames = [];
  if (alt) modifierNames.push("Alt");
  if (ctrl) modifierNames.push("Ctrl");
  if (meta) modifierNames.push("Meta");
  if (shift) modifierNames.push("Shift");

  return {
    combo: [...modifierNames, descriptor.label].join("+"),
    key: descriptor.key,
    code: descriptor.code,
    keyCode: descriptor.keyCode,
    modifiers,
    modifierNames,
    text: hasShortcutModifier ? "" : descriptor.text,
    unmodifiedText: hasShortcutModifier ? "" : descriptor.unmodifiedText,
  };
}

function keyDescriptor(raw, shift) {
  const key = String(raw || "").trim();
  const lower = key.toLowerCase();

  const named = {
    enter: ["Enter", "Enter", 13],
    return: ["Enter", "Enter", 13],
    esc: ["Escape", "Escape", 27],
    escape: ["Escape", "Escape", 27],
    tab: ["Tab", "Tab", 9],
    backspace: ["Backspace", "Backspace", 8],
    delete: ["Delete", "Delete", 46],
    del: ["Delete", "Delete", 46],
    insert: ["Insert", "Insert", 45],
    ins: ["Insert", "Insert", 45],
    home: ["Home", "Home", 36],
    end: ["End", "End", 35],
    pageup: ["PageUp", "PageUp", 33],
    pgup: ["PageUp", "PageUp", 33],
    pagedown: ["PageDown", "PageDown", 34],
    pgdn: ["PageDown", "PageDown", 34],
    space: [" ", "Space", 32],
    arrowup: ["ArrowUp", "ArrowUp", 38],
    up: ["ArrowUp", "ArrowUp", 38],
    arrowdown: ["ArrowDown", "ArrowDown", 40],
    down: ["ArrowDown", "ArrowDown", 40],
    arrowleft: ["ArrowLeft", "ArrowLeft", 37],
    left: ["ArrowLeft", "ArrowLeft", 37],
    arrowright: ["ArrowRight", "ArrowRight", 39],
    right: ["ArrowRight", "ArrowRight", 39],
  };
  if (named[lower]) {
    const [eventKey, code, keyCode] = named[lower];
    const text = eventKey === " " ? " " : "";
    return { label: code, key: eventKey, code, keyCode, text, unmodifiedText: text };
  }

  const fn = /^f([1-9]|1[0-9]|2[0-4])$/i.exec(key);
  if (fn) {
    const n = Number(fn[1]);
    return { label: `F${n}`, key: `F${n}`, code: `F${n}`, keyCode: 111 + n, text: "", unmodifiedText: "" };
  }

  if (/^[a-z]$/i.test(key)) {
    const upper = key.toUpperCase();
    const eventKey = shift ? upper : upper.toLowerCase();
    return {
      label: upper,
      key: eventKey,
      code: `Key${upper}`,
      keyCode: upper.charCodeAt(0),
      text: eventKey,
      unmodifiedText: upper.toLowerCase(),
    };
  }

  if (/^[0-9]$/.test(key)) {
    return {
      label: key,
      key,
      code: `Digit${key}`,
      keyCode: key.charCodeAt(0),
      text: key,
      unmodifiedText: key,
    };
  }

  const punctuation = {
    "-": ["-", "Minus", 189],
    "=": ["=", "Equal", 187],
    ",": [",", "Comma", 188],
    ".": [".", "Period", 190],
    "/": ["/", "Slash", 191],
    "`": ["`", "Backquote", 192],
    "[": ["[", "BracketLeft", 219],
    "]": ["]", "BracketRight", 221],
    "\\": ["\\", "Backslash", 220],
    ";": [";", "Semicolon", 186],
    "'": ["'", "Quote", 222],
  };
  if (punctuation[key]) {
    const [eventKey, code, keyCode] = punctuation[key];
    return { label: code, key: eventKey, code, keyCode, text: eventKey, unmodifiedText: eventKey };
  }

  throw new Error(`unsupported key combo: ${raw}`);
}

async function captureScreenshotResult(message) {
  const tab = await getTargetTab(message);
  let dataUrl;
  let via = "Page.captureScreenshot";
  try {
    const data = await captureScreenshotViaCdp(tab.id, 10000);
    dataUrl = `data:image/png;base64,${data}`;
  } catch (error) {
    if (!isExtensionFrameAccessError(error)) throw error;
    const [activeTab] = await chrome.tabs.query({ active: true, windowId: tab.windowId });
    try {
      if (activeTab?.id !== tab.id) await chrome.tabs.update(tab.id, { active: true });
      dataUrl = await chrome.tabs.captureVisibleTab(tab.windowId, { format: "png" });
      via = "chrome.tabs.captureVisibleTab";
    } finally {
      if (activeTab?.id && activeTab.id !== tab.id) {
        const [current] = await chrome.tabs.query({ active: true, windowId: tab.windowId }).catch(() => []);
        if (current?.id === tab.id) await chrome.tabs.update(activeTab.id, { active: true }).catch(() => {});
      }
    }
  }
  return {
    tab: compactTab(tab),
    dataUrl,
    bytesApprox: Math.ceil(dataUrl.slice(dataUrl.indexOf(",") + 1).length * 0.75),
    via,
  };
}

async function screenshot(message) {
  return captureScreenshotResult(message);
}

function shotUrl(windowId, userInitiated = false) {
  const transaction = screenshotTransactionChain
    .catch(() => {})
    .then(() => runShotUrlTransaction(windowId, userInitiated));
  screenshotTransactionChain = transaction.catch(() => {});
  return transaction;
}

async function runShotUrlTransaction(windowId, userInitiated) {
  if (!Number.isInteger(windowId) || windowId <= 0) {
    throw new Error("shoturl requires a multiprompt browser windowId");
  }

  const transactionId = `shot-${crypto.randomUUID()}`;
  recordScreenshotAudit(transactionId, "requested", { windowId, userInitiated });
  console.log("[paste-focus] screenshot requested", { windowId, userInitiated });

  try {
    await chrome.action.setBadgeText({ text: "..." }).catch(() => {});
    await chrome.action.setTitle({ title: "Taking screenshot..." }).catch(() => {});
    const result = await runShotUrlStages(windowId, transactionId, userInitiated);
    await screenshotAuditWriteChain;
    await chrome.action.setBadgeText({ text: "" }).catch(() => {});
    await chrome.action.setTitle({ title: "Take screenshot and paste link into shell" }).catch(() => {});
    return result;
  } catch (error) {
    recordScreenshotAudit(transactionId, "failed", {
      windowId,
      message: error?.message || String(error),
    });
    await screenshotAuditWriteChain;
    await showScreenshotFailure(error);
    throw error;
  }
}

async function runShotUrlStages(windowId, transactionId, userInitiated) {

  const [activeTab] = await chrome.tabs.query({ active: true, windowId });
  if (!Number.isInteger(activeTab?.id)) throw new Error(paneWindowNotFoundMessage(windowId));
  const capture = await captureScreenshotResult({ windowId, tabId: activeTab.id });
  if (capture?.error) throw new Error(`screenshot failed: ${capture.message || capture.error}`);
  if (typeof capture?.dataUrl !== "string" || !capture.dataUrl.startsWith("data:image/png;base64,")) {
    throw new Error("screenshot failed: PNG data URL missing");
  }
  recordScreenshotAudit(transactionId, "captured", {
    windowId,
    tabId: capture?.tab?.id,
    method: capture?.via,
  });

  const config = await requestHostReply("getUploadConfig");
  const secret = typeof config?.secret === "string" ? config.secret : "";
  const baseUrl = typeof config?.baseUrl === "string" ? config.baseUrl.replace(/\/+$/, "") : "";
  if (!secret || !baseUrl) throw new Error("screencast2 upload config missing");

  const uploadId = randomUploadId();
  const json = await uploadScreenshotWithRetry({
    baseUrl,
    secret,
    uploadId,
    png: dataUrlToBlob(capture.dataUrl),
    transactionId,
    windowId,
  });
  if (!json?.success || typeof json.url !== "string" || !json.url) {
    throw new Error("screencast2 upload did not return a URL");
  }
  recordScreenshotAudit(transactionId, "uploaded", { windowId, url: json.url });

  recordScreenshotAudit(transactionId, "paste_sent", { windowId, userInitiated });
  console.log("[paste-focus] screenshot paste sent", { windowId, userInitiated });
  const paste = await requestHostReply("pasteUrl", {
    windowId,
    url: json.url,
    transactionId,
    userInitiated,
  });
  if (paste?.sent !== true) throw new Error("multiprompt did not acknowledge screenshot URL delivery");
  recordScreenshotAudit(transactionId, "paste_acknowledged", { windowId });
  return { url: json.url, transactionId, pasteAcknowledged: true };
}

async function uploadScreenshotWithRetry({ baseUrl, secret, uploadId, png, transactionId, windowId }) {
  const maxAttempts = 2;
  for (let attempt = 1; attempt <= maxAttempts; attempt += 1) {
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), 15000);
    const form = new FormData();
    form.append("screenshot", png, `${uploadId}.png`);
    form.append("id", uploadId);
    recordScreenshotAudit(transactionId, "upload_started", { windowId, attempt });
    try {
      const response = await fetch(`${baseUrl}/api/upload-screenshot`, {
        method: "POST",
        headers: { Authorization: `Bearer ${secret}` },
        body: form,
        signal: controller.signal,
      });
      if (!response.ok) throw new Error(`screencast2 upload failed: HTTP ${response.status}`);
      return await response.json().catch(() => {
        throw new Error("screencast2 upload returned invalid JSON");
      });
    } catch (error) {
      if (attempt === maxAttempts) {
        if (error?.name === "AbortError") throw new Error("screencast2 upload timed out twice");
        throw error;
      }
      recordScreenshotAudit(transactionId, "upload_retry", {
        windowId,
        attempt,
        message: error?.name === "AbortError" ? "upload timed out" : (error?.message || String(error)),
      });
    } finally {
      clearTimeout(timer);
    }
  }
  throw new Error("screencast2 upload failed");
}

async function showScreenshotFailure(error) {
  await chrome.action.setBadgeBackgroundColor({ color: "#b91c1c" }).catch(() => {});
  await chrome.action.setBadgeText({ text: "!" }).catch(() => {});
  await chrome.action.setTitle({
    title: `Screenshot failed: ${error?.message || String(error)}. Click to try again.`,
  }).catch(() => {});
}

function randomUploadId() {
  const alphabet = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
  const bytes = new Uint8Array(5);
  crypto.getRandomValues(bytes);
  let id = "";
  for (const b of bytes) id += alphabet[b % alphabet.length];
  return id;
}

function dataUrlToBlob(dataUrl) {
  const comma = dataUrl.indexOf(",");
  if (comma < 0) throw new Error("invalid screenshot data URL");
  const binary = atob(dataUrl.slice(comma + 1));
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i += 1) bytes[i] = binary.charCodeAt(i);
  return new Blob([bytes], { type: "image/png" });
}

function withTimeout(promise, ms, label) {
  let timer;
  const timeout = new Promise((_, reject) => {
    timer = setTimeout(() => reject(new Error(label)), ms);
  });
  return Promise.race([
    Promise.resolve(promise).finally(() => clearTimeout(timer)),
    timeout,
  ]);
}

async function handleCreatedNavigationTarget(details) {
  if (ISOLATED_PROFILE_CONTAINS_ALL_TABS) return;
  if (!details || !Number.isInteger(details.sourceTabId) || !Number.isInteger(details.tabId)) return;
  await loadProtectedWindows();
  const source = await chrome.tabs.get(details.sourceTabId).catch(() => null);
  if (!source?.id || !protectedWindowIds.has(source.windowId)) return;

  const expires = Date.now() + 5000;
  pageCreatedNavigationTargets.set(details.tabId, { windowId: source.windowId, expires });
  await authorizeSuspectExternalTab(details.tabId, "protected_page_target");
  setTimeout(() => {
    const current = pageCreatedNavigationTargets.get(details.tabId);
    if (current?.expires === expires) pageCreatedNavigationTargets.delete(details.tabId);
  }, 5500);
}

function consumePageCreatedNavigationTarget(tab) {
  const approved = pageCreatedNavigationTargets.get(tab?.id);
  if (!approved) return false;
  if (approved.expires < Date.now()) {
    pageCreatedNavigationTargets.delete(tab.id);
    return false;
  }
  if (approved.windowId !== tab.windowId) return false;
  pageCreatedNavigationTargets.delete(tab.id);
  return true;
}

function clearScreenshotCdpDetachTimer(tabId) {
  const timer = screenshotCdpDetachTimers.get(tabId);
  if (timer !== undefined) clearTimeout(timer);
  screenshotCdpDetachTimers.delete(tabId);
}

function withCdpSession(tabId, operation) {
  if (cdpOperationChains.get(tabId)) {
    return Promise.reject(new Error("CDP session busy; run zsb reset to cancel the stuck command"));
  }
  let cancel;
  const cancelled = new Promise((_, reject) => { cancel = reject; });
  const current = Promise.resolve().then(async () => {
    clearScreenshotCdpDetachTimer(tabId);
    const debuggee = { tabId };
    const checkSession = () => {
      if (cdpOperationChains.get(tabId) !== current) throw new Error("CDP session reset; retry command");
    };
    try {
      const pendingDetach = screenshotCdpDetachInFlight.get(tabId);
      if (pendingDetach) await withTimeout(pendingDetach, 1000, "CDP detach timed out; run zsb reset");
      checkSession();
      if (debuggedTabs.has(tabId)) {
        await withTimeout(chrome.debugger.detach(debuggee), 1000, "CDP detach timed out; run zsb reset");
        debuggedTabs.delete(tabId);
        screenshotCdpPageEnabledTabs.delete(tabId);
      }
      checkSession();
      debuggedTabs.add(tabId);
      await withTimeout(chrome.debugger.attach(debuggee, "1.3"), 5000, "CDP attach timed out; run zsb reset");
      checkSession();
      await withTimeout(chrome.debugger.sendCommand(debuggee, "Emulation.setFocusEmulationEnabled", { enabled: true }), 2000, "CDP focus setup timed out; run zsb reset");
      checkSession();
      return await withTimeout(operation(debuggee), 10000, "CDP operation timed out; run zsb reset");
    } finally {
      if (cdpOperationChains.get(tabId) === current) {
        await withTimeout(chrome.debugger.detach(debuggee), 1000, "CDP detach timed out; run zsb reset");
        debuggedTabs.delete(tabId);
        screenshotCdpPageEnabledTabs.delete(tabId);
      }
    }
  });
  cdpOperationChains.set(tabId, current);
  cdpSessionCancels.set(tabId, cancel);
  return Promise.race([current, cancelled]).finally(() => {
    if (cdpOperationChains.get(tabId) === current) {
      cdpOperationChains.delete(tabId);
      cdpSessionCancels.delete(tabId);
    }
  });
}

async function resetBridge(message) {
  const windowId = messageWindowId(message);
  const tabs = await chrome.tabs.query(windowId == null ? {} : { windowId });
  let reloadScheduled = false;
  await Promise.all(tabs.map(async ({ id: tabId }) => {
    cdpSessionCancels.get(tabId)?.(new Error("CDP session reset; retry command"));
    cdpSessionCancels.delete(tabId);
    cdpOperationChains.delete(tabId);
    clearScreenshotCdpDetachTimer(tabId);
    screenshotCdpDetachInFlight.delete(tabId);
    await withTimeout(chrome.debugger.detach({ tabId }), 1000, "CDP reset detach timed out").catch((error) => {
      if (error?.message === "CDP reset detach timed out") reloadScheduled = true;
    });
    debuggedTabs.delete(tabId);
    screenshotCdpPageEnabledTabs.delete(tabId);
    focusEmulatedTabs.delete(tabId);
    consoleCaptureTabs.delete(tabId);
  }));
  const oldPort = port;
  port = undefined;
  oldPort?.disconnect();
  bridgeVersionCheckChain = Promise.resolve();
  connect();
  return { reset: true, windowId, tabs: tabs.length, reloadScheduled };
}

async function tryAcceptPendingDialog(debuggee) {
  await chrome.debugger.sendCommand(debuggee, "Page.handleJavaScriptDialog", { accept: true }).catch((error) => {
    if (isExtensionFrameAccessError(error)) throw error;
  });
}

async function acceptPendingDialog(tabId) {
  if (!Number.isInteger(tabId)) return;
  await withCdpSession(tabId, (debuggee) => tryAcceptPendingDialog(debuggee)).catch(() => {});
}

async function captureScreenshotViaCdp(tabId, timeoutMs = 10000) {
  const maxAttempts = 3;
  let lastError = null;
  for (let attempt = 1; attempt <= maxAttempts; attempt += 1) {
    try {
      return await withCdpSession(tabId, async (debuggee) => {
        await tryAcceptPendingDialog(debuggee);
        await withTimeout(
          chrome.debugger.sendCommand(debuggee, "Page.enable", {}),
          2000,
          "CDP Page.enable timed out",
        ).catch((error) => {
          if (isExtensionFrameAccessError(error)) throw error;
        });
        const result = await withTimeout(
          chrome.debugger.sendCommand(debuggee, "Page.captureScreenshot", {
            format: "png",
            fromSurface: true,
          }),
          timeoutMs,
          "CDP screenshot timed out",
        );
        if (typeof result?.data !== "string" || !result.data.startsWith("iVBOR")) {
          throw new Error("CDP screenshot returned invalid PNG data");
        }
        return result.data;
      });
    } catch (error) {
      if (isExtensionFrameAccessError(error)) throw error;
      lastError = error;
      if (attempt < maxAttempts) await new Promise((resolve) => setTimeout(resolve, attempt * 120));
    }
  }
  throw new Error(`CDP screenshot failed after ${maxAttempts} attempts: ${errorText(lastError)}`);
}

async function sendCdp(message) {
  const tabId = (await getTargetTab(message)).id;
  const cdpMethod = stringOr(message.cdpMethod, "");
  if (!cdpMethod) throw new Error("missing cdpMethod");

  return withCdpSession(tabId, (debuggee) =>
    chrome.debugger.sendCommand(debuggee, cdpMethod, message.params || {}));
}

async function consoleAction(message) {
  const tab = await getTargetTab(message);
  const limit = Math.max(1, Math.min(numberOr(message.limit, 50), CONSOLE_ENTRY_LIMIT));
  if (message?.clear === true) consoleEntriesByTab.set(tab.id, []);
  const entries = consoleEntriesByTab.get(tab.id) || [];
  consoleEntriesByTab.set(tab.id, entries);

  await withCdpSession(tab.id, async (debuggee) => {
    consoleCaptureTabs.add(tab.id);
    try {
      await chrome.debugger.sendCommand(debuggee, "Runtime.enable", {});
      await chrome.debugger.sendCommand(debuggee, "Log.enable", {});
      if (message?.clear === true) {
        await chrome.debugger.sendCommand(debuggee, "Runtime.discardConsoleEntries", {}).catch(() => {});
      } else {
        await new Promise((resolve) => setTimeout(resolve, 150));
      }
    } finally {
      consoleCaptureTabs.delete(tab.id);
    }
  });
  return {
    tab: compactTab(tab),
    entries: entries.slice(-limit),
    count: entries.length,
    cleared: message?.clear === true,
  };
}

function normalizeConsoleEvent(method, params) {
  if (method === "Runtime.consoleAPICalled") {
    const text = (params?.args || []).map((arg) => {
      if (Object.hasOwn(arg || {}, "value")) return String(arg.value);
      return String(arg?.description || arg?.unserializableValue || arg?.type || "");
    }).join(" ");
    return {
      source: "console",
      level: String(params?.type || "log"),
      timestamp: Number(params?.timestamp || Date.now()),
      text,
      url: params?.stackTrace?.callFrames?.[0]?.url || undefined,
      line: params?.stackTrace?.callFrames?.[0]?.lineNumber,
    };
  }
  if (method === "Log.entryAdded") {
    const entry = params?.entry || {};
    return {
      source: String(entry.source || "log"),
      level: String(entry.level || "info"),
      timestamp: Number(entry.timestamp || Date.now()),
      text: String(entry.text || ""),
      url: entry.url || undefined,
      line: entry.lineNumber,
    };
  }
  return null;
}

async function resolveWindow(message) {
  await loadProtectedWindows();
  const windows = await chrome.windows.getAll({ windowTypes: ["normal"] });
  const normalIds = new Set(windows.filter((win) => !win.type || win.type === "normal").map((win) => win.id));
  const tabs = (await chrome.tabs.query({})).filter((tab) => normalIds.has(tab.windowId) && !isExtensionTab(tab));
  const shellId = Number.isInteger(message?.shellId) && message.shellId >= 0 ? message.shellId : null;
  const ownerPid = Number.isInteger(message?.ownerPid) && message.ownerPid > 0 ? message.ownerPid : null;
  const match = typeof message?.match === "string" ? message.match : "";
  if (shellId != null && match) {
    const beacons = tabs.filter((tab) => {
      const owner = protectedWindowMeta.get(tab.windowId);
      return isPaneBeaconTab(tab) && tab.url.includes(`<title>${match}</title>`) &&
        (owner?.shellId == null || (owner.shellId === shellId && (ownerPid == null || owner.ownerPid === ownerPid)));
    });
    if (new Set(beacons.map((tab) => tab.windowId)).size > 1) throw new Error(`ambiguous window with tab url matching: ${match}`);
    if (beacons.length > 0) return { windowId: beacons[0].windowId, tab: compactTab(beacons[0]) };
  }
  if (shellId != null) {
    const owned = windows.filter((win) => normalIds.has(win.id) && protectedWindowMeta.get(win.id)?.shellId === shellId &&
      (ownerPid == null || protectedWindowMeta.get(win.id)?.ownerPid === ownerPid));
    if (owned.length > 1) throw new Error(`ambiguous multiprompt pane windows for shell ${shellId}`);
    if (owned.length === 1) {
      const tab = paneContentTab(tabs.filter((candidate) => candidate.windowId === owned[0].id));
      if (tab) return { windowId: owned[0].id, tab: compactTab(tab) };
    }
  }
  if (match) {
    const hits = shellId != null ? [] : tabs.filter((tab) => typeof tab.url === "string" && tab.url.includes(match));
    if (hits.length === 0) throw new Error(`no window with tab url matching: ${match}`);
    if (new Set(hits.map((tab) => tab.windowId)).size !== 1) throw new Error(`ambiguous window with tab url matching: ${match}`);
    return { windowId: hits[0].windowId, tab: compactTab(hits[0]) };
  }
  if (shellId != null) throw new Error(paneWindowNotFoundMessage(`for shell ${shellId}`));
  const focused = await chrome.tabs.query({ active: true, lastFocusedWindow: true });
  const tab = focused.find((candidate) => normalIds.has(candidate.windowId) && !isExtensionTab(candidate));
  if (!tab?.id) throw new Error("no focused pane window");
  return { windowId: tab.windowId, tab: compactTab(tab) };
}

function compactTab(tab) {
  if (!tab) return null;
  return {
    id: tab.id,
    windowId: tab.windowId,
    active: tab.active,
    title: tab.title,
    url: tab.url,
    status: tab.status,
  };
}

function normalizeUrl(value) {
  if (typeof value !== "string" || !value.trim()) return undefined;

  const url = value.trim();
  if (/^[a-z][a-z0-9+.-]*:/i.test(url)) return url;

  return `https://${url}`;
}

function numberOr(value, fallback) {
  const number = Number(value);
  return Number.isFinite(number) && number >= 0 ? number : fallback;
}

function stringOr(value, fallback) {
  return typeof value === "string" ? value : fallback;
}

function getVisibleText(limit) {
  const text = (document.body?.innerText || "").replace(/\s+\n/g, "\n").replace(/\n{3,}/g, "\n\n").trim();
  return {
    url: location.href,
    title: document.title,
    length: text.length,
    text: text.slice(0, limit),
    truncated: text.length > limit,
  };
}

function getLinks(limit) {
  const allLinks = Array.from(document.links)
    .map((link) => ({
      text: (link.innerText || link.textContent || "").trim().replace(/\s+/g, " ").slice(0, 120),
      href: link.href,
    }))
    .filter((link) => link.href);

  return {
    url: location.href,
    count: allLinks.length,
    links: allLinks.slice(0, limit),
  };
}

function getCompactSnapshot(limit) {
  function labelFor(element) {
    return (
      element.getAttribute("aria-label") ||
      element.getAttribute("title") ||
      element.getAttribute("placeholder") ||
      element.innerText ||
      element.textContent ||
      element.value ||
      ""
    ).trim().replace(/\s+/g, " ");
  }

  function esc(value) {
    if (globalThis.CSS?.escape) return CSS.escape(String(value));
    return String(value).replace(/[^a-zA-Z0-9_-]/g, (char) => `\\${char}`);
  }

  function selectorFor(element) {
    if (element.id) return `#${esc(element.id)}`;

    const testId = element.getAttribute("data-testid") || element.getAttribute("data-test") || element.getAttribute("data-cy");
    if (testId) return `[data-testid="${String(testId).replace(/\\/g, "\\\\").replace(/"/g, '\\"')}"]`;

    const name = element.getAttribute("name");
    if (name) return `${element.tagName.toLowerCase()}[name="${String(name).replace(/\\/g, "\\\\").replace(/"/g, '\\"')}"]`;

    const parts = [];
    let current = element;

    while (current && current.nodeType === Node.ELEMENT_NODE && current !== document.body && parts.length < 5) {
      let part = current.tagName.toLowerCase();
      const className = Array.from(current.classList || []).find((item) => /^[a-zA-Z_-][a-zA-Z0-9_-]{1,30}$/.test(item));
      if (className) part += `.${esc(className)}`;

      const parent = current.parentElement;
      if (parent) {
        const siblings = Array.from(parent.children).filter((child) => child.tagName === current.tagName);
        if (siblings.length > 1) part += `:nth-of-type(${siblings.indexOf(current) + 1})`;
      }

      parts.unshift(part);
      current = parent;
    }

    return parts.join(" > ") || element.tagName.toLowerCase();
  }

  const text = (document.body?.innerText || "").replace(/\s+\n/g, "\n").replace(/\n{3,}/g, "\n\n").trim();
  const headings = Array.from(document.querySelectorAll("h1,h2,h3"))
    .slice(0, 30)
    .map((el) => ({
      tag: el.tagName.toLowerCase(),
      text: (el.innerText || el.textContent || "").trim().replace(/\s+/g, " ").slice(0, 160),
    }))
    .filter((item) => item.text);
  function visible(element) {
    const style = getComputedStyle(element);
    const rect = element.getBoundingClientRect();
    return style.visibility !== "hidden" && style.display !== "none" && rect.width > 0 && rect.height > 0;
  }

  const controlQuery = [
    "button", "a", "input", "textarea", "select", "summary", "li",
    "[contenteditable='true']", "[onclick]", "[tabindex]:not([tabindex='-1'])",
    "[role='button']", "[role='link']", "[role='menuitem']", "[role='menuitemcheckbox']",
    "[role='menuitemradio']", "[role='option']", "[role='listitem']", "[role='checkbox']",
    "[role='radio']", "[role='tab']", "[role='switch']",
  ].join(",");
  const controls = Array.from(document.querySelectorAll(controlQuery))
    .filter(visible)
    .slice(0, 160)
    .map((el) => ({
      tag: el.tagName.toLowerCase(),
      role: el.getAttribute("role") || undefined,
      text: labelFor(el).slice(0, 120),
      selector: selectorFor(el),
    }))
    .filter((item) => item.text || item.selector);

  return {
    url: location.href,
    title: document.title,
    text: text.slice(0, limit),
    textLength: text.length,
    truncated: text.length > limit,
    headings,
    controls,
  };
}

function findText(query, limit) {
  if (!query) throw new Error("missing query");

  const text = document.body?.innerText || "";
  const haystack = text.toLowerCase();
  const needle = query.toLowerCase();
  const matches = [];
  let index = 0;

  while (matches.length < limit) {
    const found = haystack.indexOf(needle, index);
    if (found === -1) break;
    const start = Math.max(0, found - 80);
    const end = Math.min(text.length, found + query.length + 120);
    matches.push({
      index: found,
      snippet: text.slice(start, end).replace(/\s+/g, " ").trim(),
    });
    index = found + needle.length;
  }

  return {
    query,
    count: matches.length,
    matches,
  };
}

function installCursorApi(opts) {
  const ID = "__browser_cli_cursor__";
  const O = Object.assign(
    { size: 22, color: "#111827", speedPxPerMs: 1.2, minDurationMs: 160, maxDurationMs: 700, zIndex: 2147483647 },
    opts || {},
  );

  function applyPos(outer) {
    const x = Number(outer.dataset.x || 0);
    const y = Number(outer.dataset.y || 0);
    outer.style.transform = `translate3d(${x - 2}px, ${y - 2}px, 0)`;
  }

  function build() {
    let outer = document.getElementById(ID);
    if (outer) return outer;

    outer = document.createElement("div");
    outer.id = ID;
    outer.setAttribute("aria-hidden", "true");
    Object.assign(outer.style, {
      position: "fixed",
      left: "0",
      top: "0",
      pointerEvents: "none",
      zIndex: String(O.zIndex),
      transitionProperty: "transform",
      transitionTimingFunction: "cubic-bezier(0.65, 0, 0.35, 1)",
      transitionDuration: "0ms",
      willChange: "transform",
    });

    const size = Math.max(12, O.size);
    const arrow =
      '<svg xmlns="http://www.w3.org/2000/svg" width="32" height="32" viewBox="-1 -1 26 26">' +
      `<path fill="#fff" stroke="${O.color}" stroke-width="1.5" stroke-linejoin="round" ` +
      'd="m23.284 19.124l-6.866-6.895a.4.4 0 0 1-.118-.296a.43.43 0 0 1 .163-.282l4.439-3.077a1.48 1.48 0 0 0 .621-1.48a1.48 1.48 0 0 0-1.036-1.198L1.623.302a1.14 1.14 0 0 0-1.11.282A1.13 1.13 0 0 0 .29 1.649L5.928 20.44a1.48 1.48 0 0 0 1.183 1.035a1.48 1.48 0 0 0 1.48-.621l3.078-4.44a.37.37 0 0 1 .31-.118a.43.43 0 0 1 .296.104l6.91 6.91a1.48 1.48 0 0 0 2.087 0l2.086-2.086a1.48 1.48 0 0 0-.074-2.101"/></svg>';
    const inner = document.createElement("div");
    Object.assign(inner.style, {
      width: `${size}px`,
      height: `${size}px`,
      transitionProperty: "transform, opacity",
      transitionTimingFunction: "cubic-bezier(0.23, 1, 0.32, 1)",
      transitionDuration: "140ms",
      transformOrigin: "2px 2px",
      backgroundImage: `url("data:image/svg+xml,${encodeURIComponent(arrow)}")`,
      backgroundRepeat: "no-repeat",
      backgroundSize: "contain",
      backgroundPosition: "left top",
      filter: "drop-shadow(0 1px 2px rgba(0, 0, 0, 0.4))",
      opacity: "1",
    });
    outer.appendChild(inner);
    (document.documentElement || document.body).appendChild(outer);

    outer.dataset.x = String(Math.round(window.innerWidth / 2));
    outer.dataset.y = String(Math.round(window.innerHeight / 2));
    outer.dataset.haspos = "1";
    applyPos(outer);
    return outer;
  }

  const api = window.__browserCliCursor || {};
  api.options = O;
  api.enable = function () {
    window.__browserCliCursorDisabled = false;
    return build();
  };
  api.disable = function () {
    window.__browserCliCursorDisabled = true;
    const el = document.getElementById(ID);
    if (el) el.remove();
  };
  api.moveTo = function (x, y) {
    if (window.__browserCliCursorDisabled) return 0;
    const outer = build();
    const px = Number(outer.dataset.x || 0);
    const py = Number(outer.dataset.y || 0);
    const distance = Math.hypot(x - px, y - py);
    let durationMs = distance / O.speedPxPerMs;
    durationMs = Math.min(O.maxDurationMs, Math.max(O.minDurationMs, durationMs));
    outer.style.transitionDuration = `${Math.round(durationMs)}ms`;
    outer.dataset.x = String(Math.round(x));
    outer.dataset.y = String(Math.round(y));
    applyPos(outer);
    return Math.round(durationMs);
  };
  api.press = function (down) {
    if (window.__browserCliCursorDisabled) return;
    const outer = document.getElementById(ID);
    const inner = outer && outer.firstElementChild;
    if (!inner) return;
    inner.style.transitionDuration = "140ms";
    inner.style.transform = down ? "scale(0.88)" : "scale(1)";
  };
  window.__browserCliCursor = api;

  if (!window.__browserCliCursorDisabled) build();
  return { installed: true, disabled: !!window.__browserCliCursorDisabled };
}

async function cursorControl(action, x, y) {
  const cursor = window.__browserCliCursor;
  if (action === "off") {
    if (cursor) cursor.disable();
    return { cursor: "off" };
  }
  if (!cursor) return { cursor: action, error: "cursor not installed" };
  if (action === "on") {
    cursor.enable();
    return { cursor: "on" };
  }
  if (action === "move" && x != null && y != null) {
    const durationMs = cursor.moveTo(x, y);
    return { cursor: "move", x, y, durationMs };
  }
  if (action === "click" && x != null && y != null) {
    const durationMs = cursor.moveTo(x, y) || 0;
    await new Promise((resolve) => setTimeout(resolve, durationMs + 30));
    cursor.press(true);
    await new Promise((resolve) => setTimeout(resolve, 120));
    const target = document.elementFromPoint(x, y);
    if (target) target.click();
    cursor.press(false);
    return { cursor: "click", x, y, clicked: !!target };
  }
  return { cursor: action };
}

function getFocusedEditableTarget() {
  const element = document.activeElement;
  const editable = Boolean(element && (
    element.isContentEditable ||
    element instanceof HTMLInputElement ||
    element instanceof HTMLTextAreaElement
  ));
  return { editable, tag: element?.tagName?.toLowerCase() || "" };
}

async function locateSelectorForTrustedInput(selector, requireEditable, allowMissing = false, scroll = true) {
  if (!selector) throw new Error("missing selector");
  const element = document.querySelector(selector);
  if (!element) {
    if (allowMissing) return { found: false };
    throw new Error(`selector not found: ${selector}`);
  }
  if (requireEditable && !(
    element.isContentEditable ||
    element instanceof HTMLInputElement ||
    element instanceof HTMLTextAreaElement
  )) {
    throw new Error(`selector is not editable: ${selector}`);
  }

  if (scroll) element.scrollIntoView({ block: "center", inline: "center", behavior: "instant" });
  const rect = element.getBoundingClientRect();
  if (rect.width <= 0 || rect.height <= 0) throw new Error(`selector is not visible: ${selector}`);
  const x = Math.round(rect.left + rect.width / 2);
  const y = Math.round(rect.top + rect.height / 2);
  if (x < 0 || y < 0 || x > innerWidth || y > innerHeight) {
    throw new Error(`selector is outside the viewport: ${selector}`);
  }

  const text = (
    element.getAttribute("aria-label") ||
    element.getAttribute("title") ||
    element.getAttribute("placeholder") ||
    element.innerText ||
    element.textContent ||
    element.value ||
    ""
  ).trim().replace(/\s+/g, " ");
  return { found: true, x, y, text: text.slice(0, 160) };
}

async function locateChildFrameRect(token, action) {
  const key = `__zsbFrameRect_${token}`;
  if (action === "listen") {
    let finish;
    const promise = new Promise((resolve) => { finish = resolve; });
    const receive = (event) => {
      if (event.data?.zsbFrameToken !== token) return;
      const element = Array.from(document.querySelectorAll("iframe,frame"))
        .find((frame) => frame.contentWindow === event.source);
      if (element) finish(element);
    };
    const cleanup = () => {
      window.removeEventListener("message", receive);
      clearTimeout(timer);
      delete window[key];
      finish(null);
    };
    const timer = setTimeout(cleanup, 1500);
    window[key] = { promise, cleanup };
    window.addEventListener("message", receive);
    return true;
  }
  const pending = window[key];
  if (!pending) return null;
  try {
    if (action === "cancel") return null;
    const element = await pending.promise;
    if (!element?.isConnected) return null;
    element.scrollIntoView({ block: "center", inline: "center", behavior: "instant" });
    const rect = element.getBoundingClientRect();
    if (rect.width <= 0 || rect.height <= 0) return null;
    return { x: rect.left + element.clientLeft, y: rect.top + element.clientTop };
  } finally {
    pending.cleanup();
  }
}

function signalParentFrame(token) {
  window.parent.postMessage({ zsbFrameToken: token }, "*");
}

async function clickSelector(selector) {
  if (!selector) throw new Error("missing selector");
  const element = document.querySelector(selector);
  if (!element) throw new Error(`selector not found: ${selector}`);

  element.scrollIntoView({ block: "center", inline: "center", behavior: "instant" });
  const rect = element.getBoundingClientRect();
  if (rect.width <= 0 || rect.height <= 0) throw new Error(`selector is not visible: ${selector}`);
  const clientX = rect.left + rect.width / 2;
  const clientY = rect.top + rect.height / 2;
  const common = { bubbles: true, cancelable: true, composed: true, view: window, clientX, clientY, button: 0 };
  const pointer = { ...common, pointerId: 1, pointerType: "mouse", isPrimary: true };
  const cursor = window.__browserCliCursor;
  if (cursor && !window.__browserCliCursorDisabled) {
    const moveMs = cursor.moveTo(clientX, clientY) || 0;
    await new Promise((resolve) => setTimeout(resolve, moveMs + 30));
    cursor.press(true);
  }
  const pointerDown = element.dispatchEvent(new PointerEvent("pointerdown", { ...pointer, buttons: 1, pressure: 0.5 }));
  const mouseDown = pointerDown && element.dispatchEvent(new MouseEvent("mousedown", { ...common, buttons: 1 }));
  if (mouseDown) element.focus({ preventScroll: true });
  element.dispatchEvent(new PointerEvent("pointerup", { ...pointer, buttons: 0, pressure: 0 }));
  if (pointerDown) element.dispatchEvent(new MouseEvent("mouseup", { ...common, buttons: 0 }));
  element.dispatchEvent(new PointerEvent("click", { ...pointer, buttons: 0, detail: 1 }));
  if (cursor) cursor.press(false);

  const label = (
    element.getAttribute("aria-label") ||
    element.getAttribute("title") ||
    element.getAttribute("placeholder") ||
    element.innerText ||
    element.textContent ||
    element.value ||
    ""
  ).trim().replace(/\s+/g, " ");

  return {
    clicked: true,
    selector,
    text: label.slice(0, 160),
  };
}

async function typeSelector(selector, text) {
  if (!selector) throw new Error("missing selector");
  const element = document.querySelector(selector);
  if (!element) throw new Error(`selector not found: ${selector}`);

  element.scrollIntoView({ block: "center", inline: "center" });

  const cursor = window.__browserCliCursor;
  if (cursor && !window.__browserCliCursorDisabled) {
    const rect = element.getBoundingClientRect();
    const cx = Math.round(rect.left + rect.width / 2);
    const cy = Math.round(rect.top + rect.height / 2);
    const moveMs = cursor.moveTo(cx, cy) || 0;
    await new Promise((resolve) => setTimeout(resolve, moveMs + 30));
    cursor.press(true);
    await new Promise((resolve) => setTimeout(resolve, 100));
    cursor.press(false);
  }

  element.focus();

  if ("value" in element) {
    element.value = text;
    element.dispatchEvent(new InputEvent("input", { bubbles: true, inputType: "insertText", data: text }));
    element.dispatchEvent(new Event("change", { bubbles: true }));
  } else if (element.isContentEditable) {
    element.textContent = text;
    element.dispatchEvent(new InputEvent("input", { bubbles: true, inputType: "insertText", data: text }));
  } else {
    throw new Error(`selector is not typable: ${selector}`);
  }

  return {
    typed: true,
    selector,
    length: text.length,
  };
}

async function evalInPage(code, evaluate) {
  if (!code) throw new Error("missing code");

  function describe(value) {
    if (value instanceof Error) return `${value.name}: ${value.message}`;
    try {
      return String(value);
    } catch {
      return Object.prototype.toString.call(value);
    }
  }

  function serialize(value) {
    if (value == null || ["string", "number", "boolean"].includes(typeof value)) return value;
    if (typeof value === "undefined" || typeof value === "bigint" || typeof value === "symbol" || typeof value === "function") {
      return describe(value);
    }
    if (typeof Node !== "undefined" && value instanceof Node) return describe(value);

    try {
      const seen = new WeakSet();
      const json = JSON.stringify(value, (_key, inner) => {
        if (typeof inner === "bigint" || typeof inner === "symbol" || typeof inner === "function") return describe(inner);
        if (typeof inner === "undefined") return "undefined";
        if (inner && typeof inner === "object") {
          if (seen.has(inner)) return "[Circular]";
          seen.add(inner);
        }
        return inner;
      });
      if (json !== undefined) return JSON.parse(json);
    } catch {}

    return describe(value);
  }

  try {
    return serialize(await (evaluate ? evaluate() : Function(`"use strict"; return (${code});`)()));
  } catch (error) {
    return describe(error);
  }
}

function controlLabel(element) {
  return (
    element.getAttribute("aria-label") ||
    element.getAttribute("title") ||
    element.getAttribute("placeholder") ||
    element.innerText ||
    element.textContent ||
    element.value ||
    ""
  ).trim().replace(/\s+/g, " ");
}

function stableSelector(element) {
  if (element.id) return `#${cssEscape(element.id)}`;

  const testId = element.getAttribute("data-testid") || element.getAttribute("data-test") || element.getAttribute("data-cy");
  if (testId) return `[data-testid="${cssString(testId)}"]`;

  const name = element.getAttribute("name");
  if (name) return `${element.tagName.toLowerCase()}[name="${cssString(name)}"]`;

  const parts = [];
  let current = element;

  while (current && current.nodeType === Node.ELEMENT_NODE && current !== document.body && parts.length < 5) {
    let part = current.tagName.toLowerCase();
    const className = Array.from(current.classList || []).find((name) => /^[a-zA-Z_-][a-zA-Z0-9_-]{1,30}$/.test(name));
    if (className) part += `.${cssEscape(className)}`;

    const parent = current.parentElement;
    if (parent) {
      const siblings = Array.from(parent.children).filter((child) => child.tagName === current.tagName);
      if (siblings.length > 1) part += `:nth-of-type(${siblings.indexOf(current) + 1})`;
    }

    parts.unshift(part);
    current = parent;
  }

  return parts.join(" > ") || element.tagName.toLowerCase();
}

function cssEscape(value) {
  if (globalThis.CSS?.escape) return CSS.escape(String(value));
  return String(value).replace(/[^a-zA-Z0-9_-]/g, (char) => `\\${char}`);
}

function cssString(value) {
  return String(value).replace(/\\/g, "\\\\").replace(/"/g, '\\"');
}

function makeJsonSafe(value) {
  if (value == null || ["string", "number", "boolean"].includes(typeof value)) return value;

  try {
    return JSON.parse(JSON.stringify(value));
  } catch {
    return String(value);
  }
}
