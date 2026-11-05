let config;
try { config = JSON.parse(process.env.PHOTO_PROOF_CREDENTIAL); } catch { throw new Error('Invalid proof credential'); }
for (const name of ['account_id', 'desktop_device_id', 'android_device_id', 'desktop_refresh_token', 'android_refresh_token']) {
  const value = config[name];
  if (typeof value !== 'string' || !value || /[\r\n]/.test(value)) throw new Error('Invalid proof credential');
  console.log(`::add-mask::${value.replaceAll('%', '%25')}`);
}
