import 'dart:convert';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

import '../../../core/errors/app_exception.dart';

/// Byte-for-byte port of api-example/internal/app/provider_hongguo_playback.go.
/// The upstream protocol supplies per-episode content keys; none are persisted.
final class HongguoPlaybackCodec {
  const HongguoPlaybackCodec();

  Uint8List decodeResponse(String body) {
    final text = body.trim();
    if (!text.startsWith('v2.')) return Uint8List.fromList(utf8.encode(text));
    final parts = text.split('.');
    if (parts.length != 3 || parts[1].length <= 4 || parts[1].length > 1028) {
      throw _invalid('播放响应密钥无效');
    }
    final encoded = _hex(parts[1].substring(4));
    if (encoded.length < 32) throw _invalid('播放响应密钥无效');
    const mask = [
      104,
      64,
      70,
      166,
      190,
      168,
      143,
      130,
      225,
      254,
      251,
      217,
      196,
      34,
      45,
      60,
      29,
      20,
      103,
      105,
    ];
    final material = Uint8List(encoded.length);
    for (var index = 0; index < encoded.length; index++) {
      final previous = index > 0 ? encoded[index - 1] : 109;
      final slot = index % mask.length;
      final salt = mask[slot] ^ ((90 + 13 * slot) & 255) ^ 85;
      final shifted = (encoded[index] + 215 - 11 * index) & 255;
      final rotated = ((shifted << 3) | (shifted >> 5)) & 255;
      material[index] = previous ^ salt ^ rotated;
    }
    final ciphertext = _base64(parts[2]);
    if (ciphertext.isEmpty || ciphertext.length % 16 != 0) {
      throw _invalid('加密播放响应无效');
    }
    final cipher = CBCBlockCipher(AESEngine())
      ..init(
        false,
        ParametersWithIV(
          KeyParameter(material.sublist(0, 16)),
          material.sublist(16, 32),
        ),
      );
    final plain = Uint8List(ciphertext.length);
    for (var offset = 0; offset < ciphertext.length; offset += 16) {
      cipher.processBlock(ciphertext, offset, plain, offset);
    }
    final padding = plain.last;
    if (padding < 1 ||
        padding > 16 ||
        padding > plain.length ||
        plain.skip(plain.length - padding).any((byte) => byte != padding)) {
      throw _invalid('播放响应解码失败');
    }
    return plain.sublist(0, plain.length - padding);
  }

  Uint8List decodeContentKey(String value) {
    if (value.length > 1024) throw _invalid('媒体密钥数据过长');
    final raw = _base64(value);
    if (raw.length < 3) throw _invalid('媒体密钥编码无效');
    final tagLength = (raw[0] ^ raw[1] ^ raw[2]) - 48;
    final contentLength = raw.length - tagLength - 1;
    if (tagLength < 1 || contentLength < 33 || contentLength >= raw.length) {
      throw _invalid('媒体密钥结构无效');
    }
    final seed =
        raw[raw.length - tagLength - 2] ^ raw[raw.length - tagLength - 1];
    final tag = String.fromCharCodes(
      List.generate(
        tagLength,
        (index) => raw[raw.length - tagLength + index] ^ seed,
      ),
    );
    if (tag == 'app_v2' || tag == 'web_v2') {
      throw _invalid('这个视频的播放格式暂不支持');
    }
    final decoded = Uint8List(contentLength);
    var previousEven = 250;
    var previousOdd = 85;
    for (var index = 0; index < contentLength; index++) {
      final current = raw[index + 1];
      final previous = index.isEven ? previousEven : previousOdd;
      if (index.isEven) {
        previousEven = current;
      } else {
        previousOdd = current;
      }
      var bits = index;
      var ones = 0;
      while (bits > 0) {
        ones += bits & 1;
        bits >>= 1;
      }
      decoded[index] = ((previous ^ current) - 21 - ones) & 255;
    }
    final padding = int.tryParse(String.fromCharCode(decoded[0]), radix: 36);
    if (padding == null || contentLength - padding - 1 != 32) {
      throw _invalid('媒体密钥内容无效');
    }
    final key = _hex(String.fromCharCodes(decoded.sublist(1, 33)));
    if (key.length != 16) throw _invalid('媒体密钥长度无效');
    return key;
  }

  Uint8List _base64(String value) {
    try {
      return base64.decode(base64.normalize(value.trim()));
    } on FormatException {
      throw _invalid('播放数据编码无效');
    }
  }

  Uint8List _hex(String value) {
    if (value.length.isOdd || !RegExp(r'^[a-fA-F0-9]+$').hasMatch(value)) {
      throw _invalid('播放数据编码无效');
    }
    return Uint8List.fromList([
      for (var i = 0; i < value.length; i += 2)
        int.parse(value.substring(i, i + 2), radix: 16),
    ]);
  }

  AppException _invalid(String message) =>
      AppException(message, kind: FailureKind.parsing);
}
