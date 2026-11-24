const MODES_THAT_ASK = new Set(['auto', 'default', 'acceptEdits']);

const TOOL_WORDS = {
  Bash: 'run a command',
  Edit: 'change a file',
  Write: 'write a file',
  NotebookEdit: 'change a notebook',
  WebFetch: 'fetch a web page'
};

const BLOCKED_BY_AUTO_MODE = 'automode-blocked';

function rows(transcript) {
  const parsed = [];
  for (const line of String(transcript || '').split('\n')) {
    if (!line.trim()) continue;
    try {
      const row = JSON.parse(line);
      if (row && typeof row === 'object') parsed.push(row);
    } catch {
      continue;
    }
  }
  return parsed;
}

function blocks(row) {
  const content = row && row.message && row.message.content;
  return Array.isArray(content) ? content : [];
}

function mode(parsed) {
  let value = '';
  for (const row of parsed) if (row.type === 'permission-mode' && typeof row.permissionMode === 'string') value = row.permissionMode;
  return value;
}

function answered(parsed) {
  const ids = new Set();
  for (const row of parsed) {
    if (row.type !== 'user') continue;
    for (const block of blocks(row)) if (block.type === 'tool_result' && block.tool_use_id) ids.add(block.tool_use_id);
  }
  return ids;
}

function detailOf(input) {
  if (!input || typeof input !== 'object') return '';
  for (const key of ['command', 'description', 'file_path', 'path', 'query', 'pattern']) {
    const value = input[key];
    if (typeof value === 'string' && value.trim()) return value.trim().replace(/\s+/g, ' ');
  }
  return '';
}

function whyWords(value) {
  if (value === 'auto') return 'the auto mode safety check wants your yes before it runs';
  if (value === 'acceptEdits') return 'this chat runs in accept edits mode and this step is outside it';
  return 'this chat asks before every step';
}

function blockedBy(parsed) {
  const blocked = new Map();
  for (const row of parsed) {
    if (row.toolDenialKind !== BLOCKED_BY_AUTO_MODE) continue;
    for (const block of blocks(row)) {
      if (block.type === 'tool_result' && block.tool_use_id) blocked.set(block.tool_use_id, row);
    }
  }
  return blocked;
}

function openRequests(chats) {
  const found = [];
  for (const chat of Array.isArray(chats) ? chats : []) {
    const parsed = rows(chat.transcript);
    const current = mode(parsed);
    if (!MODES_THAT_ASK.has(current)) continue;
    const done = answered(parsed);
    let last = null;
    for (const row of parsed) {
      if (row.type !== 'assistant') continue;
      for (const block of blocks(row)) {
        if (block.type !== 'tool_use' || !block.id || done.has(block.id)) continue;
        last = { row, block };
      }
    }
    if (!last) continue;
    found.push({
      chat: String(chat.id || ''),
      title: String(chat.title || chat.id || 'this chat'),
      host: String(chat.host || ''),
      tool: String(last.block.name || ''),
      toolUseId: String(last.block.id),
      detail: detailOf(last.block.input),
      mode: current,
      why: `It is waiting for your yes because ${whyWords(current)}.`,
      askedAt: String(last.row.timestamp || '')
    });
  }
  return found.sort((a, b) => String(b.askedAt).localeCompare(String(a.askedAt)) || a.chat.localeCompare(b.chat));
}

function blockedRequests(chats) {
  const found = [];
  for (const chat of Array.isArray(chats) ? chats : []) {
    const parsed = rows(chat.transcript);
    if (mode(parsed) !== 'auto') continue;
    const steer = new Map();
    for (const row of parsed) {
      if (row.type !== 'assistant') continue;
      for (const block of blocks(row)) {
        if (block.type === 'tool_use' && block.id) steer.set(block.id, { row, block });
      }
    }
    for (const [id, row] of blockedBy(parsed)) {
      const step = steer.get(id);
      if (!step) continue;
      const category = row.permissionDecision && row.permissionDecision.classifierCategory;
      found.push({
        chat: String(chat.id || ''),
        title: String(chat.title || chat.id || 'this chat'),
        host: String(chat.host || ''),
        tool: String(step.block.name || ''),
        toolUseId: id,
        detail: detailOf(step.block.input),
        mode: 'auto',
        why: `The auto mode safety check refused this step${category ? ` for ${String(category).replace(/_/g, ' ')}` : ''}.`,
        askedAt: String(step.row.timestamp || '')
      });
    }
  }
  return found.sort((a, b) => String(b.askedAt).localeCompare(String(a.askedAt)) || a.chat.localeCompare(b.chat));
}

function describeRequest(request) {
  const tool = request && request.tool;
  const words = TOOL_WORDS[tool] || (tool ? `use ${tool}` : 'do a step');
  return `${request.title} wants to ${words}. ${request.why}`;
}

module.exports = { openRequests, blockedRequests, describeRequest, MODES_THAT_ASK };
