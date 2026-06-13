enum RemoteConfigErrorCode {
  network,
  invalidUrl,
  invalidJson,
  invalidSignature,
  expired,
  rollbackRejected,
  dangerousField,
  cacheRead,
  cacheWrite,
  noRemoteConfig,
}

class RemoteConfigException implements Exception {
  final RemoteConfigErrorCode code;
  final String message;

  const RemoteConfigException(this.code, this.message);

  @override
  String toString() => 'RemoteConfigException($code, $message)';
}

class RemoteConfigResult<T> {
  final T? value;
  final RemoteConfigException? error;
  final String source;

  const RemoteConfigResult._({
    required this.value,
    required this.error,
    required this.source,
  });

  factory RemoteConfigResult.success(T value, String source) {
    return RemoteConfigResult._(
      value: value,
      error: null,
      source: source,
    );
  }

  factory RemoteConfigResult.failure(
    RemoteConfigException error,
    String source,
  ) {
    return RemoteConfigResult._(
      value: null,
      error: error,
      source: source,
    );
  }

  bool get isSuccess => error == null;
}
