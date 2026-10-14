import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/rendering.dart';

/// Screen-space rect of [box], or `null` when it isn't laid out/attached.
Rect? _globalRect(RenderBox box) {
  if (!box.attached || !box.hasSize) return null;
  return MatrixUtils.transformRect(
      box.getTransformTo(null), Offset.zero & box.size);
}

/// Fraction (0–1) of [box] that is actually visible: not scrolled out of, or
/// clipped by, an ancestor, and inside [screen].
double visibleFraction(RenderBox box, Size screen) {
  final rect = _globalRect(box);
  if (rect == null || rect.isEmpty) return 0;

  var visible = rect.intersect(Offset.zero & screen);
  RenderObject child = box;
  RenderObject? parent = box.parent;
  while (parent != null && !visible.isEmpty) {
    final clip = parent.describeApproximatePaintClip(child);
    if (clip != null) {
      visible = visible.intersect(
        MatrixUtils.transformRect(parent.getTransformTo(null), clip),
      );
    }
    child = parent;
    parent = parent.parent;
  }
  if (visible.isEmpty) return 0;
  return (visible.width * visible.height) / (rect.width * rect.height);
}

/// Whether [box] lies within [margin] logical pixels of [screen]
/// (ignores ancestor clipping — a not-yet-visible item is exactly what we want).
bool nearViewport(RenderBox box, Size screen, double margin) {
  if (!box.attached || !box.hasSize) return false;
  final origin =
      MatrixUtils.transformPoint(box.getTransformTo(null), Offset.zero);
  final rect = Rect.fromLTWH(
    origin.dx,
    origin.dy,
    math.max(box.size.width, 1),
    math.max(box.size.height, 1),
  );
  return (Offset.zero & screen).inflate(margin).overlaps(rect);
}

/// Reports a viewable impression: once the ad has been at least [needRatio]
/// in view for [needMs] without interruption (while the app is in the
/// foreground), [onViewable] fires exactly once with the continuous time and
/// the smallest visible percentage seen during it. The server re-checks every
/// number.
class AdveroViewTracker {
  final double Function() visibleRatio;
  final bool Function() isForeground;
  final double needRatio;
  final int needMs;
  final void Function(int ms, int ratio) onViewable;

  Timer? _timer;
  final Stopwatch _clock = Stopwatch()..start();
  int? _startedMs;
  double _intervalMin = 1;

  AdveroViewTracker({
    required this.visibleRatio,
    required this.isForeground,
    required this.needRatio,
    required this.needMs,
    required this.onViewable,
  });

  void start() {
    _timer ??=
        Timer.periodic(const Duration(milliseconds: 100), (_) => _tick());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  void _reset() {
    _startedMs = null;
    _intervalMin = 1;
  }

  void _tick() {
    final ratio = isForeground() ? visibleRatio() : 0.0;
    if (ratio < needRatio) {
      _reset();
      return;
    }
    final now = _clock.elapsedMilliseconds;
    _intervalMin = math.min(_intervalMin, ratio);
    final started = _startedMs ??= now;
    if (now - started >= needMs) {
      final seen = (_intervalMin * 100).floor();
      stop();
      onViewable(now - started, seen);
    }
  }
}
