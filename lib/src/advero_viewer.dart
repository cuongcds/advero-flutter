/// Optional signal about the person using the app, signed by the publisher's
/// SERVER — never sign it in the app, the property's signal secret must not
/// ship inside it.
///
/// `token = HMAC_SHA256_hex("<placementCode>|<age>|<gender>|<expires>", signalSecret)`
/// with `age` / `gender` as empty strings when omitted. [expires] is a unix
/// timestamp (seconds) at most one hour ahead. An invalid or expired signal is
/// ignored by the server.
class AdveroViewer {
  final int? age;

  /// `'male'` or `'female'`.
  final String? gender;
  final int expires;
  final String token;

  const AdveroViewer({
    this.age,
    this.gender,
    required this.expires,
    required this.token,
  });

  /// Query parameters understood by `GET /ads/serve/{placementCode}`.
  Map<String, String> toQuery() => {
        'va': age?.toString() ?? '',
        'vg': gender ?? '',
        'vexp': expires.toString(),
        'vt': token,
      };
}
