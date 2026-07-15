// Regenerate the raster app-icon assets from resources/icon.svg.
//
//   npm run icons
//
// Produces:
//   resources/icon.png   512x512 PNG  (Linux / README)
//   resources/icon.ico   Windows multi-size ICO
//   resources/icon.icns  macOS multi-size ICNS
//
// Requires the `sharp` and `png-to-ico` devDependencies.

import sharp from 'sharp';
import pngToIco from 'png-to-ico';
import { readFileSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const RES = join(dirname(fileURLToPath(import.meta.url)), '..', 'resources');
const svg = readFileSync(join(RES, 'icon.svg'));

// Render the SVG once per size we need.
const SIZES = [16, 32, 64, 128, 256, 512, 1024];
const png = {};
for (const size of SIZES) {
  png[size] = await sharp(svg, { density: 384 })
    .resize(size, size, { fit: 'contain', background: { r: 0, g: 0, b: 0, alpha: 0 } })
    .png()
    .toBuffer();
}

// Main app / README icon.
writeFileSync(join(RES, 'icon.png'), png[512]);

// Windows ICO (multiple sizes embedded).
const ico = await pngToIco([png[16], png[32], png[64], png[128], png[256]]);
writeFileSync(join(RES, 'icon.ico'), ico);

// macOS ICNS: embed PNGs under the standard OSType codes.
const ICNS_TYPES = [
  ['icp4', 16],
  ['icp5', 32],
  ['ic07', 128],
  ['ic08', 256],
  ['ic09', 512],
  ['ic10', 1024], // 512@2x
  ['ic11', 32], // 16@2x
  ['ic12', 64], // 32@2x
  ['ic13', 256], // 128@2x
  ['ic14', 512], // 256@2x
];
const chunks = [];
for (const [type, size] of ICNS_TYPES) {
  const data = png[size];
  const header = Buffer.alloc(8);
  header.write(type, 0, 'ascii');
  header.writeUInt32BE(data.length + 8, 4);
  chunks.push(header, data);
}
const body = Buffer.concat(chunks);
const fileHeader = Buffer.alloc(8);
fileHeader.write('icns', 0, 'ascii');
fileHeader.writeUInt32BE(body.length + 8, 4);
writeFileSync(join(RES, 'icon.icns'), Buffer.concat([fileHeader, body]));

console.log('Generated resources/icon.png, resources/icon.ico, resources/icon.icns');
