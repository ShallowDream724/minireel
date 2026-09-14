import 'dart:convert';
import 'dart:typed_data';

import 'package:pointycastle/digests/md5.dart';

/// Sign the exact encoded query and UTF-8 body sent on the wire.
Map<String, String> signHongguoRequest(Uri uri, String body, DateTime now) {
  final payload = Uint8List(20);
  final hash = MD5Digest().process(Uint8List.fromList(utf8.encode(body)));
  payload.setRange(
    0,
    4,
    MD5Digest().process(Uint8List.fromList(utf8.encode(uri.query))),
  );
  payload.setRange(4, 8, hash);
  payload.setRange(12, 16, [0, 6, 11, 28]);
  final seconds = now.millisecondsSinceEpoch ~/ 1000;
  ByteData.sublistView(payload).setUint32(16, seconds);
  const key = [
    0x44,
    0xb9,
    0xb9,
    0xd9,
    0xa4,
    0xae,
    0xf9,
    0xfc,
    0xa4,
    0x93,
    0xaa,
    0x75,
    0x7c,
    0xa3,
    0xc2,
    0xc4,
    0xa4,
    0x96,
    0x93,
    0x8f,
  ];
  for (var i = 0; i < 20; i++) {
    payload[i] ^= key[i];
  }
  for (var i = 0; i < 20; i++) {
    final mixed =
        (((payload[i] << 4) | (payload[i] >> 4)) & 255) ^ payload[(i + 1) % 20];
    var reversed = 0;
    for (var bit = 0; bit < 8; bit++) {
      reversed = (reversed << 1) | ((mixed >> bit) & 1);
    }
    payload[i] = reversed ^ 255 ^ 20;
  }
  String hex(List<int> bytes) =>
      bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return {
    'X-Khronos': '$seconds',
    'X-Gorgon': hex([0x84, 4, 0x40, 0x1c, 0, 0, ...payload]),
    'X-SS-STUB': hex(hash).toUpperCase(),
    'X-SS-Req-Ticket': '${now.millisecondsSinceEpoch}',
  };
}
