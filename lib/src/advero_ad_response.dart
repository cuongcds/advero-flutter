/// Parsed response of `GET /ads/serve/{placementCode}`.
///
/// Only constructed when the response is a well-formed 200 with the fields
/// this SDK needs to render something — any other shape (204, network error,
/// malformed JSON, missing fields) is treated as "nothing to show" by the
/// caller, never as this type.
class AdveroAdResponse {
  final String creativeUrl;
  final String clickUrl;
  final String? impressionToken;
  final bool placeholder;

  const AdveroAdResponse({
    required this.creativeUrl,
    required this.clickUrl,
    this.impressionToken,
    this.placeholder = false,
  });

  /// Returns `null` if [json] doesn't have the minimum required fields —
  /// callers treat that the same as "no ad" rather than throwing.
  static AdveroAdResponse? tryParse(Map<String, dynamic> json) {
    final creativeUrl = json['creative_url'];
    final clickUrl = json['click_url'];
    if (creativeUrl is! String || creativeUrl.isEmpty) return null;
    if (clickUrl is! String || clickUrl.isEmpty) return null;

    return AdveroAdResponse(
      creativeUrl: creativeUrl,
      clickUrl: clickUrl,
      impressionToken: json['impression_token'] is String
          ? json['impression_token'] as String
          : null,
      placeholder: json['placeholder'] == true,
    );
  }
}
