export function shellSurfaceClass(uiaTree) {
  if (!Array.isArray(uiaTree)) return null;
  const hit = uiaTree.find(node => node.class === 'MPTerminal' || node.class === 'ConsoleWindowClass');
  return hit?.class ?? null;
}

export function visibleReadPlan(surfaceClass, region) {
  if (surfaceClass === 'ConsoleWindowClass') return 'console-document';
  if (surfaceClass === 'MPTerminal' && region === 'prompt') return 'prompt-line-copy';
  return 'pane-copy';
}

export function containsNeedle(text, needle) {
  return typeof text === 'string' && text.includes(needle);
}

export function visiblePasteDetected({ surfaceClass, region, visibleText, marker }) {
  const plan = visibleReadPlan(surfaceClass, region);
  if (plan === 'console-document' || plan === 'prompt-line-copy') {
    return containsNeedle(visibleText, marker);
  }
  return containsNeedle(visibleText, marker);
}

export function scrollIndex(text) {
  const found = [...text.matchAll(/SOFTSCROLL-(\d{3})/g)];
  if (!found.length) return -1;
  let lowest = 9999;
  for (const match of found) {
    const value = Number(match[1]);
    if (value < lowest) lowest = value;
  }
  return lowest;
}

export function scrollMovedEnough(beforeText, afterText, required = 100) {
  const before = scrollIndex(beforeText);
  const after = scrollIndex(afterText);
  if (before < 0 || after < 0) return { ok: false, before, after, scrolled: 0, required };
  const scrolled = before - after;
  return { ok: scrolled >= required, before, after, scrolled, required };
}