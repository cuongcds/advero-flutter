/// Parsed response of `GET /ads/serve/{placementCode}`.
///
/// Only constructed when the response is a well-formed 200 with the fields
/// this SDK needs to render something — any other shape (204, network error,
/// malformed JSON, missing fields) is treated as "nothing to show" by the
/// caller, never as this type.
class AdveroAdResponse {
  final String creativeUrl;
  final String clickUrl;

  /// `null` for the house placeholder response.
  final String? impressionToken;
  final bool placeholder;

  /// Signed URL the viewable-impression beacon is POSTed to; `null` for the
  /// house placeholder response.
  final String? viewUrl;

  /// Fraction of the ad (0–1) that must be in view to count as viewable.
  final double viewRatio;

  /// How long (ms) that fraction must stay in view without interruption.
  final int viewMs;

  const AdveroAdResponse({
    required this.creativeUrl,
    required this.clickUrl,
    this.impressionToken,
    this.placeholder = false,
    this.viewUrl,
    this.viewRatio = 0.5,
    this.viewMs = 1000,
  });

  /// Returns `null` if [json] doesn't have the minimum required fields —
  /// callers treat that the same as "no ad" rather than throwing.
  static AdveroAdResponse? tryParse(Map<String, dynamic> json) {
    final creativeUrl = json['creative_url'];
    final clickUrl = json['click_url'];
    if (creativeUrl is! String || creativeUrl.isEmpty) return null;
    if (clickUrl is! String || clickUrl.isEmpty) return null;

    final viewUrl = json['view_url'];
    final viewRatio = json['view_ratio'];
    final viewMs = json['view_ms'];

    return AdveroAdResponse(
      creativeUrl: creativeUrl,
      clickUrl: clickUrl,
      impressionToken: json['impression_token'] is String
          ? json['impression_token'] as String
          : null,
      placeholder: json['placeholder'] == true,
      viewUrl: viewUrl is String && viewUrl.isNotEmpty ? viewUrl : null,
      viewRatio: viewRatio is num ? viewRatio.toDouble() : 0.5,
      viewMs: viewMs is num ? viewMs.toInt() : 1000,
    );
  }
}
