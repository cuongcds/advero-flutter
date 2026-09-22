import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import 'advero_ad_response.dart';
import 'advero_sdk.dart';

/// Displays one Advero ad slot for [placementCode].
///
/// Fetches the creative on [initState] and renders it as a tappable image.
/// No eligible ad (HTTP 204), a network error, or a malformed response all
/// collapse to the same outcome — an empty widget — since none of these are
/// integration bugs, just "nothing to show right now".
class AdveroAdView extends StatefulWidget {
  /// The placement's opaque code, copied as-is from the Advero dashboard.
  final String placementCode;

  /// When there's no eligible advertiser creative, the API returns a house
  /// placeholder ("Advertise here") instead of leaving the slot empty.
  /// Defaults to true; pass false to render nothing in that case instead.
  final bool showPlaceholder;

  /// Called once a real (non-placeholder-only) ad has been fetched and is
  /// about to be shown.
  final VoidCallback? onAdLoaded;

  /// Called when there is nothing to display (204, error, or a placeholder
  /// suppressed by [showPlaceholder] = false).
  final VoidCallback? onEmpty;

  AdveroAdView({
    super.key,
    required this.placementCode,
    this.showPlaceholder = true,
    this.onAdLoaded,
    this.onEmpty,
  }) {
    if (placementCode.trim().isEmpty) {
      throw ArgumentError.value(
        placementCode,
        'placementCode',
        'AdveroAdView: "placementCode" is required.',
      );
    }
  }

  @override
  State<AdveroAdView> createState() => _AdveroAdViewState();
}

class _AdveroAdViewState extends State<AdveroAdView> {
  AdveroAdResponse? _ad;

  @override
  void initState() {
    super.initState();
    _fetchAd();
  }

  @override
  void didUpdateWidget(covariant AdveroAdView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.placementCode != widget.placementCode) {
      setState(() => _ad = null);
      _fetchAd();
    }
  }

  Future<void> _fetchAd() async {
    final baseUrl = AdveroSDK.baseUrl;
    if (baseUrl == null) {
      throw StateError(
        'AdveroAdView: call AdveroSDK.init(baseUrl: ...) before using AdveroAdView.',
      );
    }

    final uri = Uri.parse(
      '$baseUrl/ads/serve/${Uri.encodeComponent(widget.placementCode)}',
    );

    http.Response response;
    try {
      response = await http.get(uri);
    } catch (_) {
      _reportEmpty();
      return; // network error — no ad, no throw
    }

    if (response.statusCode == 204 || response.statusCode >= 300) {
      _reportEmpty();
      return; // no eligible ad — normal, not an error
    }

    Map<String, dynamic>? json;
    try {
      json = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      _reportEmpty();
      return;
    }

    final ad = AdveroAdResponse.tryParse(json);
    if (ad == null) {
      _reportEmpty();
      return;
    }

    if (ad.placeholder && !widget.showPlaceholder) {
      _reportEmpty();
      return;
    }

    if (!mounted) return;
    setState(() => _ad = ad);
    widget.onAdLoaded?.call();
  }

  void _reportEmpty() {
    widget.onEmpty?.call();
  }

  Future<void> _handleTap() async {
    final ad = _ad;
    if (ad == null) return;
    final uri = Uri.parse(ad.clickUrl);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final ad = _ad;
    if (ad == null) {
      // Loading, or nothing to show — an empty ad slot is normal, never an
      // error placeholder.
      return const SizedBox.shrink();
    }

    return GestureDetector(
      onTap: _handleTap,
      child: Image.network(
        ad.creativeUrl,
        // A broken creative URL should also collapse to empty rather than
        // showing Flutter's default broken-image icon.
        errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
      ),
    );
  }
}
