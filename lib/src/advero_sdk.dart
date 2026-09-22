/// Global SDK configuration.
///
/// No default/hardcoded backend domain: the ad-serving base URL must always
/// be supplied explicitly by the integrator via [AdveroSDK.init].
class AdveroSDK {
  AdveroSDK._();

  static String? _baseUrl;

  /// Base URL of the Advero ad-serving endpoint, with a trailing slash
  /// stripped, or `null` if [init] hasn't been called yet.
  static String? get baseUrl => _baseUrl;

  /// Call once, e.g. in `main()` before `runApp()`.
  ///
  /// Throws [ArgumentError] if [baseUrl] is missing/empty — this is an
  /// integration mistake meant to be caught during development, not silently
  /// swallowed like ad-serving failures at runtime.
  static void init({required String baseUrl}) {
    if (baseUrl.trim().isEmpty) {
      throw ArgumentError.value(
        baseUrl,
        'baseUrl',
        'AdveroSDK.init: "baseUrl" is required (no default is provided — '
            'pass the Advero ad-serving endpoint for your account).',
      );
    }
    _baseUrl = baseUrl.replaceFirst(RegExp(r'/+$'), '');
  }
}
