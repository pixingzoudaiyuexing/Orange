class SecureResponse {
  final int status;
  final Map<String, String> headers;
  final Object? body;
  final String requestId;

  const SecureResponse({
    required this.status,
    required this.headers,
    required this.body,
    required this.requestId,
  });

  factory SecureResponse.fromJson(
    Map<String, dynamic> json, {
    required String requestId,
  }) {
    final rawHeaders = json['headers'];
    return SecureResponse(
      status: json['status'] as int,
      headers: rawHeaders is Map
          ? rawHeaders.map((key, value) => MapEntry('$key', '$value'))
          : const {},
      body: json['body'],
      requestId: requestId,
    );
  }

  bool get isSuccess => status >= 200 && status < 300;
}
