const fs = require('node:fs');
const path = require('node:path');

const root = path.resolve(__dirname, '..');

function sourceText(overrides, file) {
  if (overrides && overrides[file]) return overrides[file];
  return fs.readFileSync(path.join(root, 'src', file), 'utf8');
}

function pick(text, pattern, what) {
  const match = text.match(pattern);
  if (!match) throw new Error(`usage icon geometry: ${what} changed in the app source`);
  return match;
}

function functionBody(text, name) {
  const start = text.indexOf(`pub fn ${name}(`);
  if (start < 0) throw new Error(`usage icon geometry: ${name} is missing from the app source`);
  const next = text.indexOf('\npub fn ', start + 1);
  const nested = text.indexOf('\nfn ', start + 1);
  const limits = [next, nested, text.length].filter(end => end > start);
  return text.slice(start, Math.min(...limits));
}

function usageIconGeometry(overrides) {
  const capacity = sourceText(overrides, 'capacity.zig');
  const usageCard = sourceText(overrides, 'usage_card.zig');

  const rect = pick(
    functionBody(capacity, 'sidebarStickyCardRect'),
    /return \.\{ \.left = uiScaled\((-?\d+)\), \.top = @max\(0, client\.bottom - uiScaled\((\d+)\)\), \.right = uiScaled\((-?\d+)\), \.bottom = client\.bottom - uiScaled\((\d+)\) \};/,
    'the expanded sidebar status icon rect',
  );
  const left = Number(rect[1]);
  const topInset = Number(rect[2]);
  const right = Number(rect[3]);
  const bottomInset = Number(rect[4]);

  const footer = functionBody(usageCard, 'paintSidebarFooter');
  const fill = pick(footer, /smooth\.fillEllipse\(dc, rect, RGB\((\d+), (\d+), (\d+)\)\);/, 'the status icon fill').slice(1, 4).map(Number);
  const centre = pick(
    footer,
    /const cx: f64 = @floatFromInt\(rect\.left \+ px\((\d+)\)\);\s*const cy: f64 = @floatFromInt\(rect\.top \+ px\((\d+)\)\);/,
    'the status icon gauge centre',
  );
  const radius = Number(pick(footer, /const radius: f64 = @floatFromInt\(px\((\d+)\)\);/, 'the status icon gauge radius')[1]);
  const track = pick(footer, /strokePolyline\(&points, RGB\((\d+), (\d+), (\d+)\), @floatFromInt\(px\((\d+)\)\)\);/, 'the status icon gauge track');
  const dot = pick(
    footer,
    /smooth\.fillEllipse\(dc, \.\{ \.left = rect\.left \+ px\((\d+)\), \.top = rect\.top \+ px\((\d+)\), \.right = rect\.left \+ px\((\d+)\), \.bottom = rect\.top \+ px\((\d+)\) \}/,
    'the status icon usage dot',
  );

  const width = right - left;
  const height = topInset - bottomInset;
  if (width !== height) throw new Error(`usage icon geometry: the sidebar status icon is ${width}x${height}, not a disc`);

  const panel = pick(usageCard, /smooth\.fillRoundRect\(dc, \.\{ \.left = card\.left \+ 1, \.top = card\.top \+ 1, \.right = card\.right - 1, \.bottom = card\.bottom - 1 \}, px\(15\), RGB\((\d+), (\d+), (\d+)\)\);/, 'the usage card panel').slice(1, 4).map(Number);
  const cardTrack = pick(usageCard, /smooth\.fillRoundRect\(dc, bar, px\(3\), RGB\((\d+), (\d+), (\d+)\)\);/, 'the usage card quota track').slice(1, 4).map(Number);
  const label = pick(usageCard, /text\(dc, "AI SUBSCRIPTIONS", [^\n]*RGB\((\d+), (\d+), (\d+)\)/, 'the usage card label ink').slice(1, 4).map(Number);
  const title = pick(usageCard, /CreateWindowExW\(0, L\("MultiPromptUsageCard"\), L\("([^"]+)"\)/, 'the usage card window title')[1];
  const cardWidth = Number(pick(usageCard, /const width = @max\(1, @min\(px\((\d+)\), client\.right - client\.left - px\(\d+\)\)\)/, 'the usage card width')[1]);
  const cardGap = Number(pick(usageCard, /const bottom = @max\(client\.top \+ px\(\d+\), pill\.top - px\((\d+)\)\)/, 'the usage card gap above the icon')[1]);

  return {
    icon: {
      left,
      right,
      topInset,
      bottomInset,
      width,
      height,
      centerX: left + width / 2,
      centerYInset: (topInset + bottomInset) / 2,
    },
    paint: {
      fill,
      track: track.slice(1, 4).map(Number),
      stroke: Number(track[4]),
      arc: { centerX: Number(centre[1]), centerY: Number(centre[2]), radius },
      dot: { left: Number(dot[1]), top: Number(dot[2]), right: Number(dot[3]), bottom: Number(dot[4]) },
    },
    card: { panel, track: cardTrack, label, title, maxWidth: cardWidth, gap: cardGap },
  };
}

module.exports = { usageIconGeometry };

if (require.main === module) process.stdout.write(`${JSON.stringify(usageIconGeometry())}\n`);
