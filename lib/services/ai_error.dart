/// Why an online AI request failed, in a form we can show to the user.
enum AiErrorKind {
  noKey,
  invalidKey,
  denied,
  region,
  quota,
  model,
  timeout,
  network,
  server,
  other
}

class AiError implements Exception {
  final AiErrorKind kind;
  final String provider; // Gemini / OpenAI / Claude
  final String detail; // raw message (short)
  AiError(this.kind, this.provider, this.detail);

  /// Classify an HTTP error response from any provider.
  factory AiError.fromHttp(String provider, int status, String body) {
    final b = body.toLowerCase();
    final short = body.length > 300 ? body.substring(0, 300) : body;
    AiErrorKind k;
    if (b.contains('location is not supported') ||
        b.contains('unsupported_country') ||
        b.contains('country, region, or territory') ||
        b.contains('region not supported') ||
        b.contains('request not allowed')) {
      k = AiErrorKind.region;
    } else if (b.contains('api_key_invalid') ||
        b.contains('api key not valid') ||
        b.contains('invalid_api_key') ||
        b.contains('incorrect api key') ||
        b.contains('invalid x-api-key') ||
        b.contains('authentication_error') ||
        b.contains('reported as leaked') ||
        b.contains('service_disabled') ||
        b.contains('has not been used in project') ||
        status == 401) {
      k = AiErrorKind.invalidKey;
    } else if (status == 429 ||
        b.contains('quota') ||
        b.contains('resource_exhausted') ||
        b.contains('insufficient_quota') ||
        b.contains('credit balance')) {
      k = AiErrorKind.quota;
    } else if (status == 404 || b.contains('not found for api version')) {
      k = AiErrorKind.model;
    } else if (status == 403) {
      // key is accepted but the request is refused (network, VPN, region...)
      k = AiErrorKind.denied;
    } else if (status >= 500) {
      k = AiErrorKind.server;
    } else {
      k = AiErrorKind.other;
    }
    // keep just the human message from Google/OpenAI/Anthropic JSON errors
    final m = RegExp(r'"message"\s*:\s*"([^"]{1,200})').firstMatch(body);
    return AiError(k, provider, '$status ${m?.group(1) ?? short}');
  }

  /// Higher = more useful to show (a region block beats "model not found").
  int get priority => switch (kind) {
        AiErrorKind.region => 9,
        AiErrorKind.denied => 8,
        AiErrorKind.invalidKey => 7,
        AiErrorKind.quota => 6,
        AiErrorKind.timeout => 5,
        AiErrorKind.network => 4,
        AiErrorKind.server => 3,
        AiErrorKind.other => 2,
        AiErrorKind.model => 1,
        AiErrorKind.noKey => 0,
      };

  String get key => 'ai_err_${kind.name}';

  @override
  String toString() => '$provider: $kind $detail';
}
