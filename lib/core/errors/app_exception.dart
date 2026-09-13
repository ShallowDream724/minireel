enum FailureKind { network, unavailable, parsing, playback, cancelled, storage }

final class AppException implements Exception {
  const AppException(this.message, {this.kind = FailureKind.unavailable});

  final String message;
  final FailureKind kind;

  @override
  String toString() => message;
}

String readableError(Object error) =>
    error is AppException ? error.message : '暂时无法完成，请稍后重试';
