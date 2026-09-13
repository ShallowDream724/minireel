const defaultUserAgent =
    'Mozilla/5.0 (Linux; Android 15) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/131.0.0.0 Mobile Safari/537.36';

/// Addresses come from the supplied source configuration, never the adapter.
final class SourceConfig {
  const SourceConfig({
    required this.baseUrl,
    required this.playbackEndpoint,
    required this.referer,
    required this.mediaReferer,
    this.enabled = true,
    this.userAgent = defaultUserAgent,
    this.maxPages = 20,
    this.pageSize = 24,
    this.timeoutSeconds = 12,
    this.retries = 3,
  });

  factory SourceConfig.fromJson(Map<String, dynamic> json) {
    const baseOverride = String.fromEnvironment('MINIREEL_BASE_URL');
    const playbackOverride = String.fromEnvironment(
      'MINIREEL_PLAYBACK_ENDPOINT',
    );
    final base = baseOverride.isNotEmpty
        ? baseOverride
        : json['baseUrl'] as String;
    return SourceConfig(
      baseUrl: Uri.parse(base),
      playbackEndpoint: Uri.parse(
        playbackOverride.isNotEmpty
            ? playbackOverride
            : json['playbackEndpoint'] as String,
      ),
      referer: baseOverride.isNotEmpty ? '$base/' : json['referer'] as String,
      mediaReferer: json['mediaReferer'] as String? ?? '$base/',
      enabled: json['enabled'] != false,
      userAgent: (json['userAgent'] as String?)?.isNotEmpty == true
          ? json['userAgent'] as String
          : defaultUserAgent,
      maxPages: ((json['maxPages'] as num?)?.toInt() ?? 20).clamp(1, 100),
      pageSize: ((json['pageSize'] as num?)?.toInt() ?? 24).clamp(1, 200),
      timeoutSeconds: ((json['timeoutSeconds'] as num?)?.toInt() ?? 12).clamp(
        3,
        60,
      ),
      retries: ((json['retries'] as num?)?.toInt() ?? 3).clamp(1, 5),
    );
  }

  final Uri baseUrl;
  final Uri playbackEndpoint;
  final String referer;
  final String mediaReferer;
  final bool enabled;
  final String userAgent;
  final int maxPages;
  final int pageSize;
  final int timeoutSeconds;
  final int retries;

  Map<String, String> get headers => {
    'User-Agent': userAgent,
    'Referer': referer,
    'Accept-Language': 'zh-CN,zh;q=0.9',
  };

  /// Mirrors the Go media proxy headers, including byte-range-friendly transfer.
  Map<String, String> playbackHeaders({String? mediaReferer}) {
    final ref = mediaReferer ?? referer;
    final origin = Uri.tryParse(ref);
    return {
      ...headers,
      'Referer': ref,
      'Accept-Encoding': 'identity',
      if (origin != null && origin.hasAuthority) 'Origin': origin.origin,
    };
  }
}
