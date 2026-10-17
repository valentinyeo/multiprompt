if (!globalThis.__multipromptPaneClickGuardV2Installed) {
globalThis.__multipromptPaneClickGuardV2Installed = true;

let multipromptProtectedPane;
const pendingNotificationClickUrls = [];

function setMultipromptProtectedPane(response) {
  multipromptProtectedPane = response?.protected === true;
  if (!multipromptProtectedPane) {
    pendingNotificationClickUrls.length = 0;
    return;
  }
  for (const url of pendingNotificationClickUrls.splice(0)) {
    sendNotificationClick(url);
  }
}

function sendNotificationClick(url) {
  chrome.runtime.sendMessage({
    type: "multiprompt:webNotificationClick",
    url,
  }, () => void chrome.runtime.lastError);
}

chrome.runtime.sendMessage({ type: "multiprompt:isProtectedWindow" }, (response) => {
  if (chrome.runtime.lastError) return;
  setMultipromptProtectedPane(response);
});

chrome.runtime.onMessage.addListener((message) => {
  if (message?.type === "multiprompt:protectWindow") {
    setMultipromptProtectedPane({ protected: true });
  }
});

window.addEventListener("message", (event) => {
  const payload = event?.data;
  if (event.source !== window) return;
  if (event.origin !== window.location.origin) return;
  if (payload?.source !== "multiprompt-notification-main") return;
  if (payload?.type !== "multiprompt:webNotificationClick") return;

  let url;
  try {
    url = new URL(payload.url, window.location.href);
  } catch (_) {
    return;
  }
  if (!/^https?:$/.test(url.protocol) || url.origin !== window.location.origin) return;

  if (multipromptProtectedPane === true) {
    sendNotificationClick(url.href);
  } else if (multipromptProtectedPane === undefined && pendingNotificationClickUrls.length < 4) {
    pendingNotificationClickUrls.push(url.href);
  }
}, false);

window.addEventListener("click", (event) => {
  if (multipromptProtectedPane !== true || !event.isTrusted || event.button !== 0) return;
  if (!event.altKey || event.ctrlKey || event.metaKey || event.shiftKey) return;

  const anchor = event.composedPath().find((node) => node instanceof HTMLAnchorElement);
  if (!anchor || anchor.hasAttribute("download")) return;
  const target = (anchor.getAttribute("target") || "").toLowerCase();
  if (target && target !== "_self" && target !== "_blank") return;

  let url;
  try {
    url = new URL(anchor.href, window.location.href);
  } catch (_) {
    return;
  }
  if (url.protocol !== "http:" && url.protocol !== "https:") return;

  event.preventDefault();
  event.stopImmediatePropagation();
  if (target === "_blank") {
    window.open(url.href, "_blank", "noopener");
  } else {
    window.location.assign(url.href);
  }
}, true);
}
