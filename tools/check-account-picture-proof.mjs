import fs from 'node:fs';

try {
  if (process.argv.length !== 4) throw new Error('Expected desktop and phone receipts');
  const desktop = JSON.parse(fs.readFileSync(process.argv[2], 'utf8').replace(/^\uFEFF/, ''));
  const phone = JSON.parse(fs.readFileSync(process.argv[3], 'utf8').replace(/^\uFEFF/, ''));
  if (desktop.status !== 'passed' || desktop.cleanup !== 0 || phone.status !== 'passed') throw new Error('Both real app journeys must pass');
  if (!Number.isSafeInteger(desktop.photo_revision) || desktop.photo_revision < 1 || !/^[0-9a-f]{64}$/.test(desktop.account_picture_sha256 || '') || !/^[0-9a-f]{64}$/.test(desktop.app_sha256 || '')) throw new Error('Desktop account picture evidence missing');
  const times = [desktop.uploaded_at, phone.rendered_at];
  if (times.some(value => typeof value !== 'string' || !/(?:Z|[+-]\d{2}:\d{2})$/.test(value) || !Number.isFinite(Date.parse(value)))) throw new Error('UTC timestamps required');
  const seconds = (Date.parse(times[1]) - Date.parse(times[0])) / 1000;
  if (seconds < 0 || seconds > 60) throw new Error('Picture propagation outside the 0–60 second window');
  console.log(JSON.stringify({ status: 'passed', seconds, photo_revision: desktop.photo_revision }));
} catch (error) {
  console.error(error.message);
  process.exitCode = 1;
}
