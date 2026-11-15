function boundary(text, pos) {
  if (pos === 0) return true;
  const c = text.charCodeAt(pos - 1);
  return c === 32 || c === 9 || c === 10 || c === 13;
}

function sessionId(text) {
  if (text.length < 1 || text.length > 64) return false;
  let hyphen = false;
  for (let i = 0; i < text.length; i += 1) {
    const c = text[i];
    if (c === '-') hyphen = true;
    else if (!/[A-Za-z0-9_.:]/.test(c)) return false;
  }
  return hyphen;
}

function sessionLinkFrom(text, pos, allowSpaces) {
  if (pos >= text.length) return null;
  let i = pos;
  if (text[i] === '@') {
    i += 1;
    if (i >= text.length) return null;
  }
  if ('{ \t\n\r'.includes(text[i])) return null;
  const nameStart = i;
  while (i < text.length && i - pos <= 192) {
    const c = text[i];
    if (c === '\n' || c === '\r') return null;
    if (c === ' ' || c === '\t') {
      if (!allowSpaces) return null;
      i += 1;
      continue;
    }
    if (c === '{') break;
    i += 1;
  }
  if (i >= text.length || text[i] !== '{' || i === nameStart || text[i - 1] === ' ' || text[i - 1] === '\t') return null;
  let j = i + 1;
  while (j < text.length && text[j] !== '}' && j - i <= 65) j += 1;
  if (j >= text.length || text[j] !== '}' || !sessionId(text.slice(i + 1, j))) return null;
  return { nameStart, nameEnd: i, targetStart: i + 1, targetEnd: j, end: j + 1 };
}

function lineSessionLink(text, pos) {
  let s = pos;
  while (s > 0 && text[s - 1] !== '\n' && text[s - 1] !== '\r') {
    if (text[s - 1] !== ' ' && text[s - 1] !== '\t') return null;
    s -= 1;
  }
  const link = sessionLinkFrom(text, pos, true);
  if (!link) return null;
  let k = link.end;
  while (k < text.length && (text[k] === ' ' || text[k] === '\t')) k += 1;
  if (k < text.length && text[k] !== '\n' && text[k] !== '\r') return null;
  return link;
}

function sessionLinkAt(text, pos) {
  if (pos >= text.length || !boundary(text, pos)) return null;
  if (text[pos] === '@') return sessionLinkFrom(text, pos, true);
  return lineSessionLink(text, pos) || sessionLinkFrom(text, pos, false);
}

function sessionLinks(text) {
  const spans = [];
  let i = 0;
  while (i < text.length) {
    const link = sessionLinkAt(text, i);
    if (!link) {
      i += 1;
      continue;
    }
    spans.push({ name: text.slice(link.nameStart, link.nameEnd), tmux: text.slice(link.targetStart, link.targetEnd) });
    i = link.end;
  }
  return spans;
}

module.exports = { sessionLinks };
