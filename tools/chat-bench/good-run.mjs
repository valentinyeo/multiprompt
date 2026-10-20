export function goodRun() {
  const tabs = ['none', 'pending', 'docked'].map((browser, index) => ({ index, browser, sid: `claude-${index}`, file: '/fixture' }));
  return { errors: [], fixtures: { tabs }, samples: Array.from({ length: 60 }, (_, i) => ({ measured: true, idle: true, phase: 'warm', timeMs: (i + 1) * 1000, elapsedMs: 1000, cpu: 2, rssBytes: 1048576 })),
    switches: ['cold', 'warm'].flatMap(phase => tabs.map(tab => ({ phase, index: tab.index, firstPaintMs: 20, contentPaintMs: 20, screenshot: 'capture.png', nonEmpty: true, geometry: { browser_foreign: true, browser_live: true }, foreignBrowsersOnScreen: tab.browser === 'docked' ? 1 : 0, geometryInside: true, headerInk: true, composerInk: true, earlyContent: true }))),
    restarted: true, appends: [{}], readerResponses: tabs.map(t => ({ sid: t.sid, ok: true, hasLive: true })) };
}
