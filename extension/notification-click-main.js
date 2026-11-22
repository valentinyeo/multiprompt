if (!globalThis.__multipromptNotificationClickBridgeInstalled) {
  globalThis.__multipromptNotificationClickBridgeInstalled = true;

  navigator.serviceWorker?.addEventListener("message", (event) => {
    const payload = event?.data;
    if (payload?.isFirebaseMessaging !== true) return;
    if (payload?.messageType !== "notification-clicked") return;

    const rawUrl = payload?.fcmOptions?.link || payload?.notification?.click_action;
    let url;
    try {
      url = new URL(rawUrl, window.location.href);
    } catch (_) {
      return;
    }
    if (!/^https?:$/.test(url.protocol) || url.origin !== window.location.origin) return;

    window.postMessage({
      source: "multiprompt-notification-main",
      type: "multiprompt:webNotificationClick",
      url: url.href,
    }, window.location.origin);
  });
}
