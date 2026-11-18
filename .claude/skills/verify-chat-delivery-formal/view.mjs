import fs from 'node:fs';

const decisions = JSON.parse(fs.readFileSync(new URL('./decisions.json', import.meta.url), 'utf8'));

export const title = 'One sent message, delayed receipt';
export function state(v) {
  const notSent = v.pending && (v.state === 'not_sent' ? decisions.ShowNotSent : v.state === 'delivered' ? decisions.ShowDelivered : v.age && decisions.ShowQueuedOld);
  if (v.state === 'empty') return 'Nothing sent';
  if (v.transcript && v.pending) return 'Two visible copies';
  if (v.transcript) return 'Shown once from chat';
  if (v.host === 'accepted' && notSent) return 'Accepted, marked Not sent';
  if (notSent) return 'Marked Not sent, no receipt';
  if (v.host === 'accepted') return 'Accepted, echo pending';
  if (v.written) return 'Sending';
  return 'Waiting to send';
}
export const step = a => ({Send:'You send a message', Submit:'The app starts sending', HostReceives:'The host stores it', HostAccepts:'The agent accepts it', Receipt:'The app receives the receipt', Disconnect:'Connection drops', Reconnect:'Connection returns', Wait:'Ten minutes pass', Resume:'You restart the app', Echo:'The saved chat arrives', Retry:'You send again', Done:'No visible change'})[a] || a;
