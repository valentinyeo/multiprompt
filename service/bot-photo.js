const encoder = new TextEncoder();

export async function remotePhotoKey(host, session) {
  const prefix = encoder.encode('ZigShell bot avatar v1\0remote\0');
  const name = encoder.encode(session.toLowerCase());
  const input = new Uint8Array(prefix.length + 1 + name.length);
  input.set(prefix);
  input[prefix.length] = host;
  input.set(name, prefix.length + 1);
  const digest = new Uint8Array(await crypto.subtle.digest('SHA-256', input));
  return Array.from(digest, byte => byte.toString(16).padStart(2, '0')).join('');
}

export function validPhotoPng(encoded) {
  if (typeof encoded !== 'string' || encoded.length > 87384 || !/^(?:[A-Za-z0-9+/]{4})*(?:[A-Za-z0-9+/]{2}==|[A-Za-z0-9+/]{3}=)?$/.test(encoded)) return false;
  let raw;
  try { raw = atob(encoded); } catch { return false; }
  if (raw.length > 65536 || raw.length < 45 || btoa(raw) !== encoded) return false;
  const bytes = Uint8Array.from(raw, c => c.charCodeAt(0));
  if (![137, 80, 78, 71, 13, 10, 26, 10].every((n, i) => bytes[i] === n)) return false;
  const view = new DataView(bytes.buffer);
  let offset = 8, first = true, imageData = false;
  while (offset + 12 <= bytes.length) {
    const length = view.getUint32(offset);
    if (length > bytes.length - offset - 12) return false;
    const type = String.fromCharCode(...bytes.subarray(offset + 4, offset + 8));
    let crc = 0xffffffff;
    for (let i = offset + 4; i < offset + 8 + length; i++) {
      crc ^= bytes[i];
      for (let j = 0; j < 8; j++) crc = (crc >>> 1) ^ (0xedb88320 & -(crc & 1));
    }
    if ((crc ^ 0xffffffff) >>> 0 !== view.getUint32(offset + 8 + length)) return false;
    if (first) {
      if (type !== 'IHDR' || length !== 13 || view.getUint32(offset + 8) < 1 || view.getUint32(offset + 8) > 256 || view.getUint32(offset + 12) < 1 || view.getUint32(offset + 12) > 256) return false;
      const depths = { 0: [1, 2, 4, 8, 16], 2: [8, 16], 3: [1, 2, 4, 8], 4: [8, 16], 6: [8, 16] };
      if (!depths[bytes[offset + 17]]?.includes(bytes[offset + 16]) || bytes[offset + 18] !== 0 || bytes[offset + 19] !== 0 || bytes[offset + 20] > 1) return false;
      first = false;
    } else if (type === 'IHDR') return false;
    if (type === 'IDAT') imageData = true;
    offset += length + 12;
    if (type === 'IEND') return length === 0 && imageData && offset === bytes.length;
  }
  return false;
}
