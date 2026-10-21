// Makes the Android launcher icons and the web icons from the owner's logo
// (step 7.8). No package: only Node's own zlib and fs.
//
// The logo is an ellipse (about 3 : 2) on a transparent background. It is
// never stretched: each icon places it, centred and scaled down, on a
// square canvas. Downscaling averages the covered source area with
// premultiplied alpha, so the ellipse edge stays clean. The PNGs are
// written without any metadata chunk.
//
// Usage (from the repository root):
//   node tool/make_icons.mjs --import <logo.png>
//     Copies the logo into tool/icon_source/logo.png, re-encoded without
//     metadata (no colour profile, no text chunks). The original file is
//     only read.
//   node tool/make_icons.mjs
//     Writes every icon of OUTPUTS from tool/icon_source/logo.png.

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import zlib from 'node:zlib';

export const ROOT = path.join(path.dirname(fileURLToPath(import.meta.url)), '..');
export const SOURCE = 'tool/icon_source/logo.png';

/// The fill of the owner's logo ellipse. It is NOT the app theme colour
/// (#673AB7): a background of the logo's own colour hides the ellipse edge
/// in the adaptive and maskable icons. android/.../values/colors.xml has
/// the same value.
export const LOGO_FILL = '#623CA5';

/// The share of the canvas width the ellipse takes.
/// - adaptive: the Android adaptive foreground (owner's decision, 66 %);
///   the car stays inside the safe circle of 66 of 108 dp.
/// - full: legacy Android and web "any" icons, a small margin.
/// - maskable: web maskable icons; the car stays inside the 40 % circle.
export const SCALE = { adaptive: 0.66, full: 0.94, maskable: 0.8 };

const res = 'android/app/src/main/res';
const densities = [
  ['mdpi', 48, 108],
  ['hdpi', 72, 162],
  ['xhdpi', 96, 216],
  ['xxhdpi', 144, 324],
  ['xxxhdpi', 192, 432],
];

/// Every icon: its path, its size in px, the ellipse share and the
/// background (null: transparent).
export const OUTPUTS = [
  ...densities.flatMap(([density, legacy, foreground]) => [
    {
      file: `${res}/mipmap-${density}/ic_launcher.png`,
      size: legacy,
      scale: SCALE.full,
      background: null,
    },
    {
      file: `${res}/mipmap-${density}/ic_launcher_foreground.png`,
      size: foreground,
      scale: SCALE.adaptive,
      background: null,
    },
  ]),
  { file: 'web/favicon.png', size: 32, scale: SCALE.full, background: null },
  { file: 'web/icons/Icon-192.png', size: 192, scale: SCALE.full, background: null },
  { file: 'web/icons/Icon-512.png', size: 512, scale: SCALE.full, background: null },
  {
    file: 'web/icons/Icon-maskable-192.png',
    size: 192,
    scale: SCALE.maskable,
    background: LOGO_FILL,
  },
  {
    file: 'web/icons/Icon-maskable-512.png',
    size: 512,
    scale: SCALE.maskable,
    background: LOGO_FILL,
  },
];

const SIGNATURE = Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);

/// The chunk types of a PNG, in order.
export function chunkTypes(buffer) {
  const types = [];
  for (let at = 8; at < buffer.length; ) {
    const length = buffer.readUInt32BE(at);
    types.push(buffer.toString('latin1', at + 4, at + 8));
    at += 12 + length;
  }
  return types;
}

/// Decodes an 8-bit RGBA or RGB PNG without interlacing into
/// { width, height, data } with 4 bytes (RGBA) per pixel.
export function decodePng(buffer) {
  if (!buffer.subarray(0, 8).equals(SIGNATURE)) throw new Error('Not a PNG.');
  let header;
  const parts = [];
  for (let at = 8; at < buffer.length; ) {
    const length = buffer.readUInt32BE(at);
    const type = buffer.toString('latin1', at + 4, at + 8);
    const body = buffer.subarray(at + 8, at + 8 + length);
    if (type === 'IHDR') header = body;
    if (type === 'IDAT') parts.push(body);
    at += 12 + length;
  }
  const width = header.readUInt32BE(0);
  const height = header.readUInt32BE(4);
  const [depth, colourType] = [header[8], header[9]];
  if (depth !== 8 || ![2, 6].includes(colourType) || header[12] !== 0) {
    throw new Error('Only 8-bit RGB or RGBA PNGs without interlacing.');
  }
  const channels = colourType === 6 ? 4 : 3;
  const stride = width * channels;
  const raw = zlib.inflateSync(Buffer.concat(parts));
  const rows = Buffer.alloc(stride * height);
  for (let y = 0; y < height; y++) {
    const filter = raw[y * (stride + 1)];
    for (let x = 0; x < stride; x++) {
      const left = x >= channels ? rows[y * stride + x - channels] : 0;
      const up = y > 0 ? rows[(y - 1) * stride + x] : 0;
      const corner = x >= channels && y > 0
        ? rows[(y - 1) * stride + x - channels]
        : 0;
      const value = raw[y * (stride + 1) + 1 + x];
      rows[y * stride + x] =
        (value + predict(filter, left, up, corner)) & 0xff;
    }
  }
  const data = Buffer.alloc(width * height * 4);
  for (let i = 0; i < width * height; i++) {
    for (let c = 0; c < 3; c++) data[i * 4 + c] = rows[i * channels + c];
    data[i * 4 + 3] = channels === 4 ? rows[i * 4 + 3] : 255;
  }
  return { width, height, data };
}

function predict(filter, left, up, corner) {
  switch (filter) {
    case 0:
      return 0;
    case 1:
      return left;
    case 2:
      return up;
    case 3:
      return (left + up) >> 1;
    case 4: {
      const p = left + up - corner;
      const [pa, pb, pc] = [p - left, p - up, p - corner].map(Math.abs);
      return pa <= pb && pa <= pc ? left : pb <= pc ? up : corner;
    }
    default:
      throw new Error(`Unknown PNG filter ${filter}.`);
  }
}

/// Encodes { width, height, data } (RGBA) as a PNG with only IHDR, IDAT
/// and IEND. Each row uses the filter with the smallest sum (a common
/// heuristic).
export function encodePng({ width, height, data }) {
  const stride = width * 4;
  const raw = Buffer.alloc((stride + 1) * height);
  for (let y = 0; y < height; y++) {
    let best;
    for (const filter of [0, 1, 2, 4]) {
      const line = Buffer.alloc(stride + 1);
      line[0] = filter;
      let sum = 0;
      for (let x = 0; x < stride; x++) {
        const left = x >= 4 ? data[y * stride + x - 4] : 0;
        const up = y > 0 ? data[(y - 1) * stride + x] : 0;
        const corner = x >= 4 && y > 0 ? data[(y - 1) * stride + x - 4] : 0;
        const value =
          (data[y * stride + x] - predict(filter, left, up, corner)) & 0xff;
        line[x + 1] = value;
        sum += value < 128 ? value : 256 - value;
      }
      if (!best || sum < best.sum) best = { line, sum };
    }
    best.line.copy(raw, y * (stride + 1));
  }
  const header = Buffer.alloc(13);
  header.writeUInt32BE(width, 0);
  header.writeUInt32BE(height, 4);
  header.set([8, 6, 0, 0, 0], 8);
  return Buffer.concat([
    SIGNATURE,
    chunk('IHDR', header),
    chunk('IDAT', zlib.deflateSync(raw, { level: 9 })),
    chunk('IEND', Buffer.alloc(0)),
  ]);
}

function chunk(type, body) {
  const out = Buffer.alloc(12 + body.length);
  out.writeUInt32BE(body.length, 0);
  out.write(type, 4, 'latin1');
  body.copy(out, 8);
  out.writeUInt32BE(zlib.crc32(out.subarray(4, 8 + body.length)), 8 + body.length);
  return out;
}

/// For each target index along one axis: the source indices it covers and
/// their weights (the covered share; the weights add up to 1).
function areaWeights(sourceLength, targetLength) {
  const step = sourceLength / targetLength;
  return Array.from({ length: targetLength }, (_, i) => {
    const [from, to] = [i * step, (i + 1) * step];
    const taps = [];
    for (let s = Math.floor(from); s < Math.min(Math.ceil(to), sourceLength); s++) {
      const covered = Math.min(to, s + 1) - Math.max(from, s);
      if (covered > 0) taps.push([s, covered / step]);
    }
    return taps;
  });
}

/// Scales [image] down to [width] x [height] by area averaging, with
/// premultiplied alpha. Never scales up.
export function downscale(image, width, height) {
  if (width > image.width || height > image.height) {
    throw new Error('The icons never scale the logo up.');
  }
  const { width: sw, height: sh, data } = image;
  const pre = new Float64Array(sw * sh * 4);
  for (let i = 0; i < sw * sh; i++) {
    const alpha = data[i * 4 + 3] / 255;
    for (let c = 0; c < 3; c++) pre[i * 4 + c] = data[i * 4 + c] * alpha;
    pre[i * 4 + 3] = alpha;
  }
  const across = areaWeights(sw, width);
  const middle = new Float64Array(width * sh * 4);
  for (let y = 0; y < sh; y++) {
    for (let x = 0; x < width; x++) {
      for (const [s, w] of across[x]) {
        for (let c = 0; c < 4; c++) {
          middle[(y * width + x) * 4 + c] += pre[(y * sw + s) * 4 + c] * w;
        }
      }
    }
  }
  const down = areaWeights(sh, height);
  const out = Buffer.alloc(width * height * 4);
  for (let y = 0; y < height; y++) {
    for (let x = 0; x < width; x++) {
      const sum = [0, 0, 0, 0];
      for (const [s, w] of down[y]) {
        for (let c = 0; c < 4; c++) sum[c] += middle[(s * width + x) * 4 + c] * w;
      }
      const i = (y * width + x) * 4;
      out[i + 3] = Math.round(sum[3] * 255);
      for (let c = 0; c < 3; c++) {
        out[i + c] = sum[3] > 0 ? clamp(Math.round(sum[c] / sum[3])) : 0;
      }
    }
  }
  return { width, height, data: out };
}

function clamp(value) {
  return Math.max(0, Math.min(255, value));
}

function rgb(hex) {
  return [1, 3, 5].map((at) => parseInt(hex.slice(at, at + 2), 16));
}

/// The logo centred on a square [size] canvas, [scale] of its width, on
/// [background] (a "#RRGGBB" colour) or on transparency (null).
export function makeIcon(logo, { size, scale, background }) {
  const width = Math.round(size * scale);
  const height = Math.round((width * logo.height) / logo.width);
  const small = downscale(logo, width, height);
  const [left, top] = [(size - width) >> 1, (size - height) >> 1];
  const data = Buffer.alloc(size * size * 4);
  const fill = background ? rgb(background) : null;
  for (let i = 0; fill && i < size * size; i++) {
    data.set([...fill, 255], i * 4);
  }
  for (let y = 0; y < height; y++) {
    for (let x = 0; x < width; x++) {
      const from = (y * width + x) * 4;
      const to = ((top + y) * size + left + x) * 4;
      const alpha = small.data[from + 3] / 255;
      if (!fill) {
        small.data.copy(data, to, from, from + 4);
        continue;
      }
      for (let c = 0; c < 3; c++) {
        data[to + c] = Math.round(
          small.data[from + c] * alpha + fill[c] * (1 - alpha),
        );
      }
    }
  }
  return { width: size, height: size, data };
}

function main(argv) {
  const at = argv.indexOf('--import');
  if (at >= 0) {
    const logo = decodePng(fs.readFileSync(argv[at + 1]));
    fs.mkdirSync(path.join(ROOT, path.dirname(SOURCE)), { recursive: true });
    fs.writeFileSync(path.join(ROOT, SOURCE), encodePng(logo));
    console.log(`${SOURCE}: ${logo.width} x ${logo.height}, no metadata`);
    return 0;
  }
  const logo = decodePng(fs.readFileSync(path.join(ROOT, SOURCE)));
  for (const output of OUTPUTS) {
    const png = encodePng(makeIcon(logo, output));
    fs.writeFileSync(path.join(ROOT, output.file), png);
    console.log(`${output.file}  ${output.size}px  ${png.length} bytes`);
  }
  return 0;
}

if (import.meta.url === pathToFileURL(process.argv[1] ?? '').href) {
  process.exit(main(process.argv.slice(2)));
}
