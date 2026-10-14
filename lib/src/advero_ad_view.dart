import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import 'advero_ad_response.dart';
import 'advero_sdk.dart';
import 'advero_view_tracker.dart';
import 'advero_viewer.dart';

const _badgeLabel = 'Ads by Advero';
const _badgeIconPath = '/assets/images/favicons/favicon_white.png';
const _badgeIconSize = 12.0;
const _badgePadding = 3.0;
const _badgeBackground = Color(0xFF0F172A);
const _lazyMargin = 200.0;

/// Displays one Advero ad slot for [placementCode].
///
/// Fetches the creative on [initState] and renders it as a tappable image.
/// No eligible ad (HTTP 204), a network error, or a malformed response all
/// collapse to the same outcome — an empty widget — since none of these are
/// integration bugs, just "nothing to show right now".
///
/// Advertiser creatives carry a small Advero icon in the top-right corner;
/// tapping it opens the Advero home page and is not an ad click. Every
/// advertiser ad is also measured, and a single beacon reports the viewable
/// impression once enough of it has been visible for long enough.
class AdveroAdView extends StatefulWidget {
  /// The placement's opaque code, copied as-is from the Advero dashboard.
  final String placementCode;

  /// When there's no eligible advertiser creative, the API returns a house
  /// placeholder ("Advertise here") instead of leaving the slot empty.
  /// Defaults to true; pass false to render nothing in that case instead.
  final bool showPlaceholder;

  /// When true, the ad is only requested once the slot is about to scroll
  /// into view, so ads that are never reached are never served.
  final bool lazy;

  /// Optional signal about the user, signed by your server (see [AdveroViewer]).
  final AdveroViewer? viewer;

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
    this.lazy = false,
    this.viewer,
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

class _AdveroAdViewState extends State<AdveroAdView>
    with WidgetsBindingObserver {
  AdveroAdResponse? _ad;
  AdveroViewTracker? _tracker;
  Timer? _lazyTimer;
  bool _foreground = true;

  /// Bumped on every (re)load and on dispose, so stale async work bails out.
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _fetchAd();
  }

  @override
  void didUpdateWidget(covariant AdveroAdView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.placementCode != widget.placementCode) {
      _cancelWork();
      setState(() => _ad = null);
      _fetchAd();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cancelWork();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
  }

  void _cancelWork() {
    _generation++;
    _lazyTimer?.cancel();
    _lazyTimer = null;
    _tracker?.stop();
    _tracker = null;
  }

  RenderBox? get _box {
    final object = context.findRenderObject();
    return object is RenderBox ? object : null;
  }

  /// Completes once the slot is within [_lazyMargin] of the screen.
  Future<void> _whenNearViewport(int generation) {
    final completer = Completer<void>();
    void check() {
      if (generation != _generation || !mounted) {
        _lazyTimer?.cancel();
        return;
      }
      final box = _box;
      if (box != null &&
          nearViewport(box, MediaQuery.of(context).size, _lazyMargin)) {
        _lazyTimer?.cancel();
        completer.complete();
      }
    }

    _lazyTimer =
        Timer.periodic(const Duration(milliseconds: 100), (_) => check());
    return completer.future;
  }

  Future<void> _fetchAd() async {
    final baseUrl = AdveroSDK.baseUrl;
    if (baseUrl == null) {
      throw StateError(
        'AdveroAdView: call AdveroSDK.init(baseUrl: ...) before using AdveroAdView.',
      );
    }

    final generation = ++_generation;

    if (widget.lazy) {
      // Wait until the first layout so the slot has a position on screen.
      await WidgetsBinding.instance.endOfFrame;
      if (generation != _generation || !mounted) return;
      await _whenNearViewport(generation);
      if (generation != _generation || !mounted) return;
    }

    var uri = Uri.parse(
      '$baseUrl/ads/serve/${Uri.encodeComponent(widget.placementCode)}',
    );
    final viewer = widget.viewer;
    if (viewer != null && viewer.token.isNotEmpty && viewer.expires > 0) {
      uri = uri.replace(queryParameters: viewer.toQuery());
    }

    http.Response response;
    try {
      response = await http.get(uri);
    } catch (_) {
      _reportEmpty(generation);
      return; // network error — no ad, no throw
    }

    if (response.statusCode == 204 || response.statusCode >= 300) {
      _reportEmpty(generation);
      return; // no eligible ad — normal, not an error
    }

    Map<String, dynamic>? json;
    try {
      json = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      _reportEmpty(generation);
      return;
    }

    final ad = AdveroAdResponse.tryParse(json);
    if (ad == null) {
      _reportEmpty(generation);
      return;
    }

    if (ad.placeholder && !widget.showPlaceholder) {
      _reportEmpty(generation);
      return;
    }

    if (generation != _generation || !mounted) return;
    setState(() => _ad = ad);
    widget.onAdLoaded?.call();
    if (!ad.placeholder) {
      _trackView(ad, generation);
    }
  }

  void _trackView(AdveroAdResponse ad, int generation) {
    final viewUrl = ad.viewUrl;
    if (viewUrl == null) return;
    final tracker = AdveroViewTracker(
      // Zero until the image has loaded and the widget has a size.
      visibleRatio: () {
        final box = _box;
        return box == null
            ? 0
            : visibleFraction(box, MediaQuery.of(context).size);
      },
      isForeground: () => _foreground,
      needRatio: ad.viewRatio,
      needMs: ad.viewMs,
      onViewable: (ms, ratio) => _sendViewBeacon(viewUrl, ms, ratio),
    );
    _tracker = tracker;
    tracker.start();
  }

  Future<void> _sendViewBeacon(String viewUrl, int ms, int ratio) async {
    try {
      await http.post(
        Uri.parse(viewUrl),
        headers: const {'Content-Type': 'text/plain'},
        body: jsonEncode({'ms': ms, 'ratio': ratio}),
      );
    } catch (_) {
      // Best effort — a lost beacon just means this impression is not counted as viewable.
    }
  }

  void _reportEmpty(int generation) {
    if (generation != _generation) return;
    widget.onEmpty?.call();
  }

  Future<void> _open(String url) async {
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final ad = _ad;
    if (ad == null) {
      // Loading, or nothing to show — an empty ad slot is normal, never an
      // error placeholder.
      return const SizedBox.shrink();
    }

    final image = GestureDetector(
      onTap: () => _open(ad.clickUrl),
      child: Image.network(
        ad.creativeUrl,
        // A broken creative URL should also collapse to empty rather than
        // showing Flutter's default broken-image icon.
        errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
      ),
    );

    // The house placeholder is not an advertiser's ad, so it carries no disclosure.
    if (ad.placeholder) return image;

    final baseUrl = AdveroSDK.baseUrl!;
    return Stack(
      children: [
        image,
        Positioned(
          top: 0,
          right: 0,
          child: _AdveroBadge(
            iconUrl: baseUrl + _badgeIconPath,
            onTap: () => _open(baseUrl),
          ),
        ),
      ],
    );
  }
}

/// The "Ads by Advero" disclosure. Sits beside the creative's tap target, so
/// using it is never an ad click.
class _AdveroBadge extends StatelessWidget {
  final String iconUrl;
  final VoidCallback onTap;

  const _AdveroBadge({required this.iconUrl, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: _badgeLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Opacity(
          opacity: 0.5,
          child: Container(
            padding: const EdgeInsets.all(_badgePadding),
            decoration: BoxDecoration(
              color: _badgeBackground,
              border: Border.all(color: const Color(0x59FFFFFF)),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(3),
              ),
            ),
            child: Image.network(
              iconUrl,
              width: _badgeIconSize,
              height: _badgeIconSize,
              errorBuilder: (context, error, stackTrace) => const SizedBox(
                width: _badgeIconSize,
                height: _badgeIconSize,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
