// Generates placeholder PNG icons (accent green with a white "L") using only Node built-ins.
import { deflateSync } from 'node:zlib'
import { writeFileSync } from 'node:fs'

const GREEN = [0x2e, 0x7d, 0x32]
const WHITE = [255, 255, 255]

const crcTable = Array.from({ length: 256 }, (_, n) => {
  let c = n
  for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1
  return c >>> 0
})
const crc32 = (buf) => {
  let c = 0xffffffff
  for (const b of buf) c = crcTable[(c ^ b) & 0xff] ^ (c >>> 8)
  return (c ^ 0xffffffff) >>> 0
}
const chunk = (type, data) => {
  const len = Buffer.alloc(4)
  len.writeUInt32BE(data.length)
  const body = Buffer.concat([Buffer.from(type), data])
  const crc = Buffer.alloc(4)
  crc.writeUInt32BE(crc32(body))
  return Buffer.concat([len, body, crc])
}

function png(size) {
  const stem = { x0: 0.3, x1: 0.44, y0: 0.22, y1: 0.78 }
  const foot = { x0: 0.3, x1: 0.7, y0: 0.64, y1: 0.78 }
  const inside = (r, x, y) => x >= r.x0 && x < r.x1 && y >= r.y0 && y < r.y1
  const row = size * 3 + 1
  const raw = Buffer.alloc(row * size)
  for (let y = 0; y < size; y++) {
    raw[y * row] = 0
    for (let x = 0; x < size; x++) {
      const fx = x / size
      const fy = y / size
      const c = inside(stem, fx, fy) || inside(foot, fx, fy) ? WHITE : GREEN
      raw.set(c, y * row + 1 + x * 3)
    }
  }
  const ihdr = Buffer.alloc(13)
  ihdr.writeUInt32BE(size, 0)
  ihdr.writeUInt32BE(size, 4)
  ihdr[8] = 8
  ihdr[9] = 2
  return Buffer.concat([
    Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
    chunk('IHDR', ihdr),
    chunk('IDAT', deflateSync(raw)),
    chunk('IEND', Buffer.alloc(0)),
  ])
}

const out = { 'icon-192.png': 192, 'icon-512.png': 512, 'apple-touch-icon.png': 180, 'favicon.png': 48 }
for (const [name, size] of Object.entries(out)) writeFileSync(new URL(`../public/${name}`, import.meta.url), png(size))
console.log('Icons written to public/')
