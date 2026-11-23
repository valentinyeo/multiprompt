import fs from 'node:fs';

const decisions = JSON.parse(fs.readFileSync(new URL('./decisions.json', import.meta.url), 'utf8'));

export const title = 'Switch AI keeps one live chat';
export function state(v) {
  if (v.switching) return 'Switch in progress';
  if (!v.startOk && !v.aiRunning) return 'Old AI off, new AI failed to start';
  if (v.liveCount > 1) return 'Two live chats on the same address';
  if (v.duplicate) return 'Message shown twice';
  if (v.lost) return 'Marker message lost';
  if (!v.identityOk) return 'Name, picture or address changed';
  if (!v.historyOk && !v.switching) return 'Earlier history unreadable';
  if (v.busy) return 'Chat busy';
  return 'One live chat on ' + v.provider;
}
export const step = a => ({
  SetBusy: 'The chat starts a turn',
  ClearBusy: 'The turn finishes',
  RequestSwitch: decisions.RefuseBusy ? 'You ask to switch AI' : 'You ask to switch AI while busy',
  SendDuringSwitch: 'You send while the switch runs',
  MarkStartFail: 'The new AI fails to start',
  AbortSwitch: 'The host abandons the switch and keeps the old AI',
  CommitSwitch: 'The host moves the chat to the new AI and stops the old one',
  Restart: 'The app or host restarts',
  LoseMessage: 'A marker message disappears',
  ShowTwice: 'The marker appears twice',
  Done: 'No visible change'
})[a] || a;