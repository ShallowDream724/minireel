// Synthetic vectors generated independently with Node's OpenSSL AES backend.
// No production response, video URL or content key is used here.
const crypto = require('node:crypto');
const fs = require('node:fs');
function keyVector(key, tag = 'sample') {
  const plain = Buffer.from('0' + key);
  const raw = Buffer.alloc(plain.length + tag.length + 1);
  let even = 250, odd = 85;
  for (let i = 0; i < plain.length; i++) {
    const previous = i % 2 ? odd : even;
    const ones = i.toString(2).replace(/0/g, '').length;
    const current = previous ^ ((plain[i] + 21 + ones) & 255);
    raw[i + 1] = current;
    if (i % 2) odd = current; else even = current;
  }
  raw[0] = (tag.length + 48) ^ raw[1] ^ raw[2];
  const seed = raw[plain.length - 1] ^ raw[plain.length];
  for (let i = 0; i < tag.length; i++) raw[plain.length + 1 + i] = tag.charCodeAt(i) ^ seed;
  return raw.toString('base64');
}
const key = '00112233445566778899aabbccddeeff';
const content = keyVector(key);
const response = JSON.stringify({parse: 0, jx: false, key_urls: [
  {name: '1080P', src: 'https://example.invalid/video.mp4', kid: '11223344556677889900aabbccddeeff', spade_a: content},
]});
const material = Buffer.from(Array.from({length:32}, (_, i) => i));
const mask = [104,64,70,166,190,168,143,130,225,254,251,217,196,34,45,60,29,20,103,105];
const encoded = Buffer.alloc(32);
for (let i = 0; i < 32; i++) {
  const salt = mask[i % 20] ^ ((90 + 13 * (i % 20)) & 255) ^ 85;
  const r = material[i] ^ (i ? encoded[i - 1] : 109) ^ salt;
  const shifted = ((r >>> 3) | (r << 5)) & 255;
  encoded[i] = (shifted - 215 + 11 * i) & 255;
}
const cipher = crypto.createCipheriv('aes-128-cbc', material.subarray(0,16), material.subarray(16));
const ciphertext = Buffer.concat([cipher.update(response, 'utf8'), cipher.final()]);
const vectors = {key, content, unsupportedContent: keyVector(key, 'web_v2'), response,
  wrapped: 'v2.0000' + encoded.toString('hex') + '.' + ciphertext.toString('base64')};
fs.mkdirSync('test/fixtures', {recursive: true});
fs.writeFileSync('test/fixtures/playback_codec.json', JSON.stringify(vectors, null, 2) + '\n');
console.log('Wrote synthetic protocol golden vectors.');
