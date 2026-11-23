const fields = ['host', 'user', 'workspace', 'group', 'position', 'kind', 'sid', 'pinned', 'archived', 'waiting', 'closed', 'visible', 'hidden_reason', 'tmux', 'name'];
const text = (value, max, empty = false) => typeof value === 'string' && (empty || value.length > 0) && value.length <= max && !/[\p{Cc}\p{Cs}]/u.test(value);

export function validTabState(state, tab) {
  return state && typeof state === 'object' && !Array.isArray(state) && Object.keys(state).sort().join(',') === [...fields].sort().join(',') &&
    text(state.host, 255) && text(state.user, 32, true) && text(state.workspace, 31) &&
    (state.group === null || text(state.group, 64)) && Number.isInteger(state.position) && state.position >= 0 && state.position < 256 &&
    ['chat', 'shell'].includes(state.kind) && (state.sid === null || text(state.sid, 39)) &&
    ['pinned', 'archived', 'waiting', 'closed', 'visible'].every(field => typeof state[field] === 'boolean') &&
    !(state.archived && state.waiting) && (state.hidden_reason === null || text(state.hidden_reason, 64)) &&
    state.tmux === tab.tmux_session;
}

export function projectTabState(tab, position) {
  if (!tab.tab_state) return;
  tab.tab_state = { ...tab.tab_state, name: tab.name, workspace: tab.workspace, group: tab.group || null, position: tab.tab_state.closed || tab.tab_state.archived ? tab.tab_state.position : position };
}
