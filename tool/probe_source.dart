import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';

import 'package:minireel/core/config/source_config.dart';
import 'package:minireel/core/errors/app_exception.dart';
import 'package:minireel/core/network/app_http_client.dart';
import 'package:minireel/data/sources/hongguo/hongguo_adapter.dart';
import 'package:minireel/domain/models/drama.dart';

/// Read-only live probe. Never prints media addresses, response payloads or keys.
Future<void> main(List<String> arguments) async {
  final raw =
      jsonDecode(await File('assets/config/sources.json').readAsString())
          as Map<String, dynamic>;
  final config = SourceConfig.fromJson(
    raw['sources']['hongguo'] as Map<String, dynamic>,
  );
  final client = AppHttpClient(config);
  try {
    final adapter = HongguoAdapter(
      config,
      arguments.contains('--fallback') ? _FallbackProbeClient(client) : client,
    );
    final dramas = await adapter.fetchCatalog(DramaChannel.real, 1);
    stdout.writeln('Catalog: ${dramas.length} dramas');
    final detail = await adapter.fetchDetail(dramas.first);
    stdout.writeln(
      'Detail: ${detail.drama.title} / ${detail.episodes.length} episodes',
    );
    for (final episode in [
      detail.episodes.first,
      if (detail.episodes.length > 1) detail.episodes[1],
    ]) {
      final options = await adapter.resolvePlayback(detail.drama, episode);
      stdout.writeln(
        'Episode ${episode.index}: ${options.sources.map((s) => '${s.kind.name} ${s.quality}').join(', ')}',
      );
    }
  } finally {
    client.close();
  }
}

final class _FallbackProbeClient implements TextClient {
  const _FallbackProbeClient(this.client);
  final TextClient client;
  @override
  Future<String> getText(
    Uri uri, {
    Map<String, String>? headers,
    CancelToken? cancelToken,
  }) {
    if (uri.path.startsWith('/player/')) {
      throw const AppException('Exercise fallback path');
    }
    return client.getText(uri, headers: headers, cancelToken: cancelToken);
  }
}
