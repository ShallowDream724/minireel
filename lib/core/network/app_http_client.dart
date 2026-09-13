import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../config/source_config.dart';
import '../errors/app_exception.dart';

extension CancelTokenCheck on CancelToken {
  void throwIfCancellationRequested() {
    if (isCancelled) throw cancelError!;
  }
}

abstract interface class TextClient {
  Future<String> getText(
    Uri uri, {
    Map<String, String>? headers,
    CancelToken? cancelToken,
  });
}

final class AppHttpClient implements TextClient {
  AppHttpClient(SourceConfig config, {Dio? dio})
    : _config = config,
      _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: Duration(seconds: config.timeoutSeconds),
              receiveTimeout: Duration(seconds: config.timeoutSeconds),
              sendTimeout: Duration(seconds: config.timeoutSeconds),
              headers: config.headers,
              followRedirects: true,
              maxRedirects: 5,
              responseType: ResponseType.stream,
              validateStatus: (status) => status != null,
            ),
          );

  final SourceConfig _config;
  final Dio _dio;
  static const maxBodyBytes = 20 * 1024 * 1024;

  @override
  Future<String> getText(
    Uri uri, {
    Map<String, String>? headers,
    CancelToken? cancelToken,
  }) async {
    for (var attempt = 0; attempt < _config.retries; attempt++) {
      cancelToken?.throwIfCancellationRequested();
      try {
        final response = await _dio.getUri<ResponseBody>(
          uri,
          options: Options(headers: headers, responseType: ResponseType.stream),
          cancelToken: cancelToken,
        );
        final body = response.data!;
        final bytes = BytesBuilder(copy: false);
        // Streaming the metadata bounds memory even with an absent/fake length.
        await for (final chunk in body.stream) {
          cancelToken?.throwIfCancellationRequested();
          if (bytes.length + chunk.length > maxBodyBytes) {
            throw const AppException('剧库响应过大，请稍后重试', kind: FailureKind.parsing);
          }
          bytes.add(chunk);
        }
        final text = utf8.decode(bytes.takeBytes(), allowMalformed: true);
        if (text.contains('cf-chl-') || text.contains('<title>Just a moment')) {
          throw const AppException('站点暂时要求浏览器验证，请稍后刷新');
        }
        final status = response.statusCode ?? 0;
        if (status >= 200 && status < 300) return text;
        final retryable = status == 408 || status == 429 || status >= 500;
        if (!retryable || attempt == _config.retries - 1) {
          throw AppException(
            status == 404 ? '暂时没有找到这部短剧' : '剧库暂时无法连接，请稍后重试',
            kind: FailureKind.network,
          );
        }
      } on DioException catch (error) {
        if (CancelToken.isCancel(error)) rethrow;
        if (attempt == _config.retries - 1) {
          throw const AppException(
            '网络连接较慢，请检查网络后重试',
            kind: FailureKind.network,
          );
        }
      }
      // Cancellation also interrupts retry backoff when switching episodes.
      final delay = Future<void>.delayed(
        Duration(milliseconds: 450 * (attempt + 1)),
      );
      if (cancelToken == null) {
        await delay;
      } else {
        await Future.any([delay, cancelToken.whenCancel]);
        cancelToken.throwIfCancellationRequested();
      }
    }
    throw const AppException('网络连接失败', kind: FailureKind.network);
  }

  void close() => _dio.close(force: true);
}
