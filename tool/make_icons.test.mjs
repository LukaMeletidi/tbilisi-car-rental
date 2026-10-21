// Tests of tool/make_icons.mjs and of the icons it made (step 7.8).
// Run: node --test tool/make_icons.test.mjs

import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { test } from 'node:test';

import {
  LOGO_FILL,
  OUTPUTS,
  ROOT,
  SCALE,
  SOURCE,
  chunkTypes,
  decodePng,
  downscale,
  encodePng,
  makeIcon,
} from './make_icons.mjs';

const read = (file) => fs.readFileSync(path.join(ROOT, file));
const logo = decodePng(read(SOURCE));

/// A made-up image: [width] x [height], every pixel [rgba].
function solid(width, height, rgba) {
  const data = Buffer.alloc(width * height * 4);
  for (let i = 0; i < width * height; i++) data.set(rgba, i * 4);
  return { width, height, data };
}

const pixel = (image, x, y) =>
  [...image.data.subarray((y * image.width + x) * 4, (y * image.width + x) * 4 + 4)];

/// The car and the text: white, or the red rear light.
function isCarOrText(image, i) {
  const [r, g, b, a] = image.data.subarray(i * 4, i * 4 + 4);
  return a >= 128 && ((r > 180 && g > 180 && b > 180) || (r > 200 && g < 100));
}

/// The farthest car or text pixel from the centre, as a share of the size.
function farthestCarPixel(image) {
  let max = 0;
  const half = image.width / 2;
  for (let y = 0; y < image.height; y++) {
    for (let x = 0; x < image.width; x++) {
      if (!isCarOrText(image, y * image.width + x)) continue;
      max = Math.max(max, Math.hypot(x + 0.5 - half, y + 0.5 - half));
    }
  }
  return max / image.width;
}

/// The box of the pixels with alpha > 0.
function visibleBox(image) {
  let [minX, minY, maxX, maxY] = [Infinity, Infinity, -1, -1];
  for (let y = 0; y < image.height; y++) {
    for (let x = 0; x < image.width; x++) {
      if (image.data[(y * image.width + x) * 4 + 3] === 0) continue;
      [minX, minY] = [Math.min(minX, x), Math.min(minY, y)];
      [maxX, maxY] = [Math.max(maxX, x), Math.max(maxY, y)];
    }
  }
  return { width: maxX - minX + 1, height: maxY - minY + 1 };
}

test('encode and decode give back the same pixels', () => {
  const image = solid(5, 3, [10, 20, 30, 40]);
  image.data.set([255, 0, 128, 255], 7 * 4);
  const back = decodePng(encodePng(image));
  assert.equal(back.width, 5);
  assert.equal(back.height, 3);
  assert.deepEqual([...back.data], [...image.data]);
});

test('an encoded PNG has only IHDR, IDAT and IEND', () => {
  const png = encodePng(solid(2, 2, [1, 2, 3, 4]));
  assert.deepEqual(chunkTypes(png), ['IHDR', 'IDAT', 'IEND']);
});

test('decodePng refuses what it cannot read', () => {
  assert.throws(() => decodePng(Buffer.from('not a png')), /Not a PNG/);
  const png = encodePng(solid(1, 1, [0, 0, 0, 0]));
  png[24] = 16; // bit depth 16
  assert.throws(() => decodePng(png), /Only 8-bit/);
});

test('downscale keeps a solid colour and never scales up', () => {
  const small = downscale(solid(10, 6, [98, 60, 165, 255]), 4, 3);
  for (let i = 0; i < 12; i++) {
    assert.deepEqual(pixel(small, i % 4, Math.floor(i / 4)), [98, 60, 165, 255]);
  }
  assert.throws(() => downscale(solid(4, 4, [0, 0, 0, 0]), 5, 4), /never scale/);
});

test('downscale averages with premultiplied alpha (no dark edge)', () => {
  const image = solid(2, 1, [0, 0, 0, 0]);
  image.data.set([255, 255, 255, 255], 0);
  assert.deepEqual(pixel(downscale(image, 1, 1), 0, 0), [255, 255, 255, 128]);
});

test('the repo copy of the logo has no metadata and the expected shape', () => {
  assert.deepEqual(chunkTypes(read(SOURCE)), ['IHDR', 'IDAT', 'IEND']);
  assert.equal(logo.width, 1025);
  assert.equal(logo.height, 689);
  assert.equal(pixel(logo, 0, 0)[3], 0, 'transparent corner');
  assert.deepEqual(pixel(logo, 512, 30), [0x62, 0x3c, 0xa5, 255], 'the fill');
});

test('the logo fill constant matches colors.xml', () => {
  assert.equal(LOGO_FILL, '#623CA5');
  const xml = read('android/app/src/main/res/values/colors.xml').toString();
  assert.match(xml, /<color name="ic_launcher_background">#623CA5<\/color>/);
});

test('the adaptive icon XML names the background colour and foreground', () => {
  const xml = read(
    'android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml',
  ).toString();
  const drawable = (layer, name) => `<${layer} android:drawable="${name}"`;
  assert.ok(xml.includes(drawable('background', '@color/ic_launcher_background')));
  assert.ok(xml.includes(drawable('foreground', '@mipmap/ic_launcher_foreground')));
});

test('15 icons: 5 legacy, 5 adaptive foregrounds, 5 web', () => {
  assert.equal(OUTPUTS.length, 15);
  const legacy = OUTPUTS.filter((o) => o.file.endsWith('/ic_launcher.png'));
  assert.equal(legacy.length, 5);
  assert.equal(OUTPUTS.filter((o) => o.file.includes('_foreground')).length, 5);
  assert.equal(OUTPUTS.filter((o) => o.file.startsWith('web/')).length, 5);
});

for (const output of OUTPUTS) {
  test(`${output.file}: as the script makes it, no metadata`, () => {
    const png = read(output.file);
    assert.deepEqual(chunkTypes(png), ['IHDR', 'IDAT', 'IEND']);
    const image = decodePng(png);
    assert.equal(image.width, output.size);
    assert.equal(image.height, output.size);
    assert.deepEqual([...image.data], [...makeIcon(logo, output).data]);
  });
}

test('the adaptive foregrounds: transparent corners, car in the safe circle', () => {
  for (const output of OUTPUTS.filter((o) => o.file.includes('_foreground'))) {
    const image = decodePng(read(output.file));
    assert.equal(output.scale, SCALE.adaptive);
    assert.equal(pixel(image, 0, 0)[3], 0, output.file);
    // The safe circle of an adaptive icon: 66 dp across on 108 dp.
    assert.ok(farthestCarPixel(image) <= 33 / 108, output.file);
  }
});

test('the maskable icons: opaque, car in the 40 % circle', () => {
  for (const output of OUTPUTS.filter((o) => o.file.includes('maskable'))) {
    const image = decodePng(read(output.file));
    assert.equal(output.background, LOGO_FILL);
    for (let i = 0; i < image.width * image.height; i++) {
      assert.equal(image.data[i * 4 + 3], 255, output.file);
    }
    assert.deepEqual(pixel(image, 0, 0), [0x62, 0x3c, 0xa5, 255]);
    assert.ok(farthestCarPixel(image) <= 0.4, output.file);
  }
});

test('the legacy and web "any" icons: transparent corners', () => {
  for (const output of OUTPUTS.filter((o) => o.background === null)) {
    const image = decodePng(read(output.file));
    const last = image.width - 1;
    for (const [x, y] of [[0, 0], [last, 0], [0, last], [last, last]]) {
      assert.equal(pixel(image, x, y)[3], 0, output.file);
    }
  }
});

test('the ellipse is not stretched (Icon-512: within 1 %)', () => {
  const box = visibleBox(decodePng(read('web/icons/Icon-512.png')));
  const ratio = box.width / box.height;
  assert.ok(Math.abs(ratio / (logo.width / logo.height) - 1) < 0.01, `${ratio}`);
  assert.ok(Math.abs(box.width - 512 * SCALE.full) <= 1);
});
