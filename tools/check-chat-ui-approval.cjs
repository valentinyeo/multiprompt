const pureUI = /^(?:chat_(?:render|style|code|diff|image|options|permission|find_ui|scrollbar|table_measure|float|skill|composer_text|markdown|capture)|sidebar|drawing|window_layout|themes|dwrite_text|smooth|bot_avatar|bot_photo|room_view|update_card|ui_words|telemetry_panel|fonts|font_probe|message_menu)(?:[._/]|$)/i;
const mixedUI = /^(?:chat_session|main|app_state|chat_composer|composer|capacity|archive|inbox|usage_card)(?:[._/]|$)/i;
const uiSymbol = /(?:draw|paint|render|layout|sidebar|composer|chat[_A-Z]*(?:view|ui|style|color|font|width|height|rect|pixel|scroll|block|capture)|cache|tailFor|classification|\b(?:rect|font|color|colour|pixel|dpi|invalidate|redraw|hwnd)\b)/i;
const policy = /^(?:tools\/check-chat-ui-approval\.cjs|\.github\/workflows\/[^/]*(?:chat-ui-approval|chat-guard)[^/]*\.ya?ml)$/i;
const newUI = /(?:^|[_/.-])(?:sidebar|render|drawing|draw|paint|layout|ui)(?:[_/.-]|$)/i;

function protectedFile(file) {
  if (!file || typeof file.filename !== 'string' || !['added', 'modified', 'removed', 'renamed', 'copied', 'changed'].includes(file.status)) throw new Error('invalid file');
  const names = [file.filename, ...(file.previous_filename ? [file.previous_filename] : [])];
  if ((file.status === 'renamed' || file.status === 'copied') && typeof file.previous_filename !== 'string') throw new Error('invalid rename');
  if (names.some(name => policy.test(name))) return file.status !== 'added';
  const source = names.filter(name => /^src\//i.test(name)).map(name => name.slice(4));
  if (source.some(name => pureUI.test(name))) return true;
  const newSource = source.length > 0 && ['added', 'renamed', 'copied'].includes(file.status);
  if (newSource && source.some(name => newUI.test(name))) return true;
  if (!newSource && !source.some(name => mixedUI.test(name))) return false;
  if (typeof file.patch !== 'string' || !Number.isSafeInteger(file.changes) || file.changes < 1 || file.patch.length > 1000000) return true;
  const lines = file.patch.split('\n');
  const changed = lines.filter(line => /^[+-]/.test(line));
  if (!lines.some(line => /^@@ -\d/.test(line)) || changed.length !== file.changes) return true;
  return lines.some(line => (/^(?:@@|[+-])/.test(line) && uiSymbol.test(line)));
}

function textLines(text) {
  if (typeof text !== 'string' || text.length > 100000) throw new Error('invalid text');
  const stack = [];
  let output = '';
  const tokens = text.replace(/\r\n/g, '\n').split(/(<[^>]*>)/g);
  for (const token of tokens) {
    if (!token.startsWith('<')) {
      if (token.includes('<') || token.includes('>') && !/^\s*>/.test(token)) throw new Error('invalid markup');
      if (!stack.some(item => item.hidden)) output += token;
      continue;
    }
    const match = /^<\s*(\/?)\s*([a-z][a-z0-9]*)([^>]*)>$/i.exec(token);
    if (!match) throw new Error('invalid markup');
    const [, closing, rawTag, attrs] = match;
    const tag = rawTag.toLowerCase();
    if (!/^(?:p|div|span|strong|b|em|i|s|del|a|ul|ol|li|br|h[1-6]|blockquote|pre|code|script|style|template)$/.test(tag)) throw new Error('unsupported markup');
    if (closing) {
      if (stack.pop()?.tag !== tag) throw new Error('invalid markup');
    } else if (tag !== 'br') {
      const hidden = /^(?:blockquote|pre|code|script|style|template)$/.test(tag) || /(?:\bhidden\b|aria-hidden\s*=\s*["']?true|display\s*:\s*none|visibility\s*:\s*hidden)/i.test(attrs);
      stack.push({ tag, hidden });
    }
    if (/^(?:p|div|li|br|h[1-6]|blockquote|pre|code|script|style|template)$/.test(tag)) output += '\n';
  }
  if (stack.length) throw new Error('invalid markup');
  output = output.replace(/&(#x[0-9a-f]+|#\d+|amp|lt|gt|quot|apos|nbsp);/gi, (_, entity) => {
    const named = { amp: '&', lt: '<', gt: '>', quot: '"', apos: "'", nbsp: ' ' };
    if (entity[0] !== '#') return named[entity.toLowerCase()];
    const value = entity[1].toLowerCase() === 'x' ? parseInt(entity.slice(2), 16) : Number(entity.slice(1));
    if (!Number.isInteger(value) || value < 1 || value > 0x10ffff || value >= 0xd800 && value <= 0xdfff) throw new Error('invalid entity');
    return String.fromCodePoint(value);
  });
  let fenced = false;
  return output.split('\n').map(line => {
    if (/^\s*(?:```|~~~)/.test(line)) { fenced = !fenced; return ''; }
    if (fenced || /^(?:\s*>| {4}|\t)/.test(line)) return '';
    return line.replace(/`[^`]*`/g, '').replace(/[*_~]/g, '').trim();
  }).filter(Boolean);
}

function decision(text) {
  let result = null;
  for (const line of textLines(text)) {
    if (/^(?:no|nope|not approved|rejected|reject|declined)\b|\b(?:do|does|did|will|would|can|could|should|must|am|is|are|have|has)\s+not\b|\b(?:don't|doesn't|can't|cannot|won't|shouldn't)\b/i.test(line)) return false;
    else if (/^(?:yes|yep|approved|go ahead|👍|\+1)(?=$|[\s,.!])/iu.test(line)) {
      result = !/(?:\b(?:not|never|no|unless|if|but|until|however|pending|conditional|except|maybe|provided|only|without)\b|\b(?:don't|doesn't|can't|cannot|won't|shouldn't)\b|\?)/i.test(line);
    } else if (result === true && /^(?:if|unless|but|until|however|pending|provided|only if)\b|\?/i.test(line)) result = false;
  }
  return result;
}

function humanComment(comment) {
  if (!comment || comment.creatorId !== 6 || comment.creator?.id !== 6 || comment.agent || comment.agent_display_name || comment.creator.agent || comment.creator.agent_display_name) return false;
  if (comment.editedAt != null || comment.editedBy != null) {
    const editor = comment.editedBy;
    if (!comment.editedAt || !editor || editor.userId !== 6 || editor.agentId !== null || editor.isAgent === true) return false;
  }
  return true;
}

function normalize(text) {
  return textLines(text).join('\n');
}

async function ticketApproved(number, commentId, api) {
  const query = `ticket_number=IGSH-${number}`;
  const result = await api(`/tasks?${query}`);
  if (result?.success !== true || !Array.isArray(result.tasks) || result.tasks.length !== 1) throw new Error('invalid task');
  const task = result.tasks[0];
  if (!task || task.boardId !== 2060 || typeof task.description !== 'string' || (task.uniqueIndex != null && String(task.uniqueIndex) !== number) || (task.ticketNumber != null && task.ticketNumber !== `IGSH-${number}`)) throw new Error('invalid task');
  let cursor = null;
  const seen = new Set();
  const decisions = [];
  const selected = [];
  do {
    const page = await api(`/comments?${query}${cursor ? `&cursor=${encodeURIComponent(cursor)}` : ''}`);
    if (page?.success !== true || !Array.isArray(page.comments) || page.comments.length > 1000 || (page.nextCursor != null && typeof page.nextCursor !== 'string') || (page.has_more === true && !page.nextCursor)) throw new Error('invalid comments');
    for (const comment of page.comments) {
      if (commentId && comment?.id != null && String(comment.id) === commentId) selected.push(comment);
      if (!humanComment(comment)) continue;
      const value = decision(comment.text);
      if (value !== null) decisions.push({ value, time: Date.parse(comment.editedAt || comment.createdAt) });
    }
    cursor = page.nextCursor || null;
    if (cursor && (seen.has(cursor) || seen.size >= 100)) throw new Error('incomplete comments');
    if (cursor) seen.add(cursor);
  } while (cursor);
  if (commentId && (selected.length !== 1 || !humanComment(selected[0]) || decision(selected[0].text) !== true)) return false;
  const descriptionDecision = decision(task.description);
  if (descriptionDecision !== null) {
    let owned = task.createdBy?.id === 6 && !task.createdBy.agent && typeof task.createdAt === 'string' && task.createdAt && task.createdAt === task.updatedAt;
    if (!owned) {
      const history = await api(`/tasks/description-versions?${query}`);
      if (!Array.isArray(history?.versions) || history.versions.some(v => !v || !Number.isSafeInteger(v.version) || typeof v.content !== 'string')) throw new Error('invalid versions');
      const versions = [...history.versions].sort((a, b) => b.version - a.version);
      if (versions.length > 1 && versions[0].version === versions[1].version) throw new Error('invalid versions');
      const latest = versions[0];
      owned = latest && latest.author_id === 6 && latest.agent_id === null && normalize(latest.content) === normalize(task.description);
    }
    if (owned) decisions.push({ value: descriptionDecision, time: Date.parse(task.updatedAt) });
  }
  if (!decisions.length) return false;
  if (decisions.length > 1) {
    if (decisions.some(item => !Number.isFinite(item.time))) return false;
    decisions.sort((a, b) => b.time - a.time);
    if (decisions[0].time === decisions[1].time) return false;
  }
  return decisions[0].value;
}

function approvalFields(body) {
  const fields = [];
  const hidden = [];
  let fence = null;
  for (const line of body.replace(/\r\n/g, '\n').split('\n')) {
    let visible = '';
    const tokens = line.split(/(<!--|-->|<\/?(?:blockquote|pre|code|script|style)\b[^>]*>)/i);
    for (const token of tokens) {
      if (hidden.at(-1) === 'comment') {
        if (token === '-->') hidden.pop();
      } else if (token === '<!--') hidden.push('comment');
      else if (/^<(?:blockquote|pre|code|script|style)\b/i.test(token)) hidden.push(/^<([a-z]+)/i.exec(token)[1].toLowerCase());
      else if (/^<\/(?:blockquote|pre|code|script|style)\b/i.test(token)) {
        if (hidden.pop() !== /^<\/([a-z]+)/i.exec(token)[1].toLowerCase()) throw new Error('invalid quote');
      } else if (!hidden.length) visible += token;
    }
    const delimiter = /^ {0,3}(`{3,}|~{3,})/.exec(visible);
    if (delimiter) {
      if (!fence) fence = delimiter[1];
      else if (delimiter[1][0] === fence[0] && delimiter[1].length >= fence.length && /^\s*$/.test(visible.slice(delimiter[0].length))) fence = null;
      continue;
    }
    if (fence || /^(?: {4}|\t| {0,3}>)/.test(visible)) continue;
    const match = /^ {0,3}UI approval:[ \t]*(.*?)[ \t]*$/i.exec(visible);
    if (match) fields.push(match[1]);
  }
  return fields;
}

async function evaluate({ body, files, boardApi, changedFiles }) {
  try {
    if (typeof body !== 'string' || !Array.isArray(files) || files.length > 3000 || (changedFiles !== undefined && (!Number.isSafeInteger(changedFiles) || changedFiles !== files.length))) return false;
    const protectedChange = files.map(protectedFile).some(Boolean);
    if (!protectedChange) return true;
    const fields = approvalFields(body);
    if (fields.length !== 1 || typeof boardApi !== 'function') return false;
    const urls = fields[0].split(/[\s,]+/).filter(Boolean);
    if (!urls.length || urls.length > 5) return false;
    let approved = false;
    for (const url of urls) {
      const match = /^https:\/\/app\.hypertask\.ai\/detail\/project-2060\/([1-9]\d*)(?:#comment-([1-9]\d*))?$/.exec(url);
      if (!match) return false;
      const valid = await ticketApproved(match[1], match[2], boardApi);
      if (match[2] && !valid) return false;
      approved ||= valid;
    }
    return approved;
  } catch { return false; }
}

async function checkApproval({ pr, githubApi, boardApi, ...input }) {
  if (!githubApi) return evaluate({ boardApi, ...input });
  try {
    if (!pr || !Number.isSafeInteger(pr.changed_files) || pr.changed_files < 0 || pr.changed_files > 3000 || (pr.body !== null && typeof pr.body !== 'string')) return false;
    const files = [];
    for (let page = 1; page <= 31; page++) {
      const batch = await githubApi(page);
      if (!Array.isArray(batch) || batch.length > 100) return false;
      files.push(...batch);
      if (batch.length < 100) return evaluate({ body: pr.body ?? '', files, changedFiles: pr.changed_files, boardApi });
    }
    return false;
  } catch { return false; }
}

async function main({ env = process.env, fetchApi = fetch, log = console.log } = {}) {
  const { GITHUB_REPOSITORY: repo, GH_TOKEN: token, PR_NUMBER: number, HYPERTASK_AGENT_TOKEN: boardToken } = env;
  if (!/^[\w.-]+\/[\w.-]+$/.test(repo || '') || !token || !/^[1-9]\d*$/.test(number || '')) throw new Error('configuration');
  const request = async (url, options = {}) => {
    const response = await fetchApi(url, { ...options, signal: AbortSignal.timeout(30000) });
    if (!response.ok) throw new Error('request failed');
    return response.json();
  };
  const headers = { Authorization: `Bearer ${token}`, Accept: 'application/vnd.github+json', 'X-GitHub-Api-Version': '2022-11-28' };
  const base = `https://api.github.com/repos/${repo}`;
  const status = (sha, state, description) => request(`${base}/statuses/${sha}`, { method: 'POST', headers: { ...headers, 'Content-Type': 'application/json' }, body: JSON.stringify({ state, context: 'chat-ui-approval', description }) });
  const eventHead = env.PR_HEAD_SHA;
  if (eventHead && !/^[a-f0-9]{40}$/.test(eventHead)) throw new Error('invalid event head');
  if (eventHead) await status(eventHead, 'pending', 'Checking UI approval');
  const pr = await request(`${base}/pulls/${number}`, { headers });
  if (!/^[a-f0-9]{40}$/.test(pr?.head?.sha || '')) throw new Error('invalid head');
  if (pr.head.sha !== eventHead) await status(pr.head.sha, 'pending', 'Checking UI approval');
  let passed = false;
  try {
    const boardApi = boardToken ? path => request(`https://api.hypertask.ai/api/mcp${path}`, { headers: { Authorization: `Bearer ${boardToken}` } }) : null;
    const githubApi = page => request(`${base}/pulls/${number}/files?per_page=100&page=${page}`, { headers });
    passed = await checkApproval({ pr, githubApi, boardApi });
  } catch { passed = false; }
  await status(pr.head.sha, passed ? 'success' : 'failure', passed ? 'Approval check passed' : 'Add UI approval: ticket URL with authenticated owner approval');
  log(passed ? 'Chat UI approval check passed' : 'Chat UI approval check failed. Add UI approval: ticket URL with authenticated owner approval.');
  return passed;
}

module.exports = { evaluate, checkApproval, main };
if (require.main === module) main().then(passed => { if (!passed) process.exitCode = 1; }).catch(() => { console.error('Chat UI approval check failed'); process.exitCode = 1; });
