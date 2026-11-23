export function isDriverTypableChar(ch) {
  const cp = ch.codePointAt(0);
  if (cp === 0x09 || cp === 0x0a || cp === 0x0d) return true;
  if (cp >= 0x20 && cp <= 0x7e) return true;
  return false;
}

export function driverTypableViolations(text) {
  return [...text].filter(ch => !isDriverTypableChar(ch));
}

export function assertDriverTypable(label, text) {
  const bad = driverTypableViolations(text);
  if (bad.length) {
    const detail = bad.map(ch => `${ch} (U+${ch.codePointAt(0).toString(16).toUpperCase()})`).join(', ');
    throw new Error(`${label} contains unmappable characters: ${detail}`);
  }
}