import 'package:dio/dio.dart';

import 'app_http_client.dart';

final class _Call<T> {
  final token = CancelToken();
  late Future<T> result;
  int waiters = 0;
}

/// Bounded in-memory cache. Cancelling one caller never cancels other waiters.
final class RequestCache<T> {
  RequestCache({this.ttl = const Duration(minutes: 5), this.capacity = 64});
  final Duration ttl;
  final int capacity;
  final _values = <String, ({T value, DateTime expires})>{};
  final _pending = <String, _Call<T>>{};

  Future<T> get(
    String key,
    Future<T> Function(CancelToken) fetch, {
    CancelToken? cancelToken,
  }) async {
    cancelToken?.throwIfCancellationRequested();
    final cached = _values[key];
    if (cached != null && DateTime.now().isBefore(cached.expires)) {
      return cached.value;
    }
    var call = _pending[key];
    if (call == null || call.token.isCancelled) {
      call = _Call<T>();
      final current = call;
      _pending[key] = current;
      current.result = (() async {
        try {
          final value = await fetch(current.token);
          current.token.throwIfCancellationRequested();
          if (_values.length >= capacity) _values.remove(_values.keys.first);
          _values[key] = (value: value, expires: DateTime.now().add(ttl));
          return value;
        } finally {
          if (identical(_pending[key], current)) _pending.remove(key);
        }
      })();
    }
    call.waiters++;
    try {
      return await (cancelToken == null
          ? call.result
          : Future.any<T>([
              call.result,
              cancelToken.whenCancel.then<T>((error) => throw error),
            ]));
    } finally {
      call.waiters--;
      if (call.waiters == 0 && identical(_pending[key], call)) {
        call.token.cancel();
      }
    }
  }

  void clear({String prefix = ''}) {
    _values.removeWhere((key, _) => key.startsWith(prefix));
    for (final key
        in _pending.keys.where((key) => key.startsWith(prefix)).toList()) {
      _pending.remove(key)?.token.cancel();
    }
  }
}
