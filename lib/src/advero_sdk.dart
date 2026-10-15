import 'package:package_info_plus/package_info_plus.dart';

/// Global SDK configuration.
///
/// No default/hardcoded backend domain: the ad-serving base URL must always
/// be supplied explicitly by the integrator via [AdveroSDK.init].
class AdveroSDK {
  AdveroSDK._();

  static String? _baseUrl;
  static String? _appId;
  static Future<String?>? _detectedAppId;

  /// Base URL of the Advero ad-serving endpoint, with a trailing slash
  /// stripped, or `null` if [init] hasn't been called yet.
  static String? get baseUrl => _baseUrl;

  /// Call once, e.g. in `main()` before `runApp()`.
  ///
  /// [appId] overrides the app identifier sent with every ad request. By
  /// default the SDK uses the Android package name / iOS bundle ID.
  ///
  /// Throws [ArgumentError] if [baseUrl] is missing/empty — this is an
  /// integration mistake meant to be caught during development, not silently
  /// swallowed like ad-serving failures at runtime.
  static void init({required String baseUrl, String? appId}) {
    if (baseUrl.trim().isEmpty) {
      throw ArgumentError.value(
        baseUrl,
        'baseUrl',
        'AdveroSDK.init: "baseUrl" is required (no default is provided — '
            'pass the Advero ad-serving endpoint for your account).',
      );
    }
    _baseUrl = baseUrl.replaceFirst(RegExp(r'/+$'), '');
    final trimmedAppId = appId?.trim();
    _appId = (trimmedAppId == null || trimmedAppId.isEmpty) ? null : trimmedAppId;
  }

  /// The app identifier sent as the `app` request parameter: the [init]
  /// override, else the Android package name / iOS bundle ID. `null` when it
  /// cannot be determined (the server then serves only the placeholder).
  static Future<String?> resolveAppId() {
    final configured = _appId;
    if (configured != null) return Future.value(configured);
    return _detectedAppId ??= _detectAppId();
  }

  static Future<String?> _detectAppId() async {
    try {
      final info = await PackageInfo.fromPlatform();
      return info.packageName.isEmpty ? null : info.packageName;
    } catch (_) {
      return null;
    }
  }
}
