import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Photographs whatever it wraps, so the water has something to mirror.
///
/// The previous site did this with a `ReflectionManager` that re-rendered its
/// targets into a picture; this is the same idea where the cards actually live
/// — a `RepaintBoundary` already keeps them on their own layer, so capturing
/// it costs a read rather than a second render pass.
///
/// Two things are load-bearing and were in the original for the same reasons:
///
/// **It is throttled.** Half a second between captures. Water is blurry and
/// slow, so a reflection that lags is indistinguishable from one that does
/// not; a capture every frame would be a full-screen readback on the raster
/// thread sixty times a second, for a picture nobody can tell apart.
///
/// **It is captured small.** Half resolution. The shader tears the image
/// apart with a perspective warp and a jitter before anyone sees it, so detail
/// spent here is detail thrown away — and a readback costs what its pixels
/// cost.
class ReflectionCapture extends StatefulWidget {
  const ReflectionCapture({
    required this.child,
    required this.onCaptured,
    this.enabled = true,
    super.key,
  });

  final Widget child;

  /// Handed each new photograph. The receiver owns it from that moment — this
  /// keeps no reference and will not free it.
  final void Function(ui.Image) onCaptured;

  /// Whether there is anything worth photographing yet.
  final bool enabled;

  static const Duration interval = Duration(milliseconds: 500);
  static const double scale = 0.5;

  @override
  State<ReflectionCapture> createState() => _ReflectionCaptureState();
}

class _ReflectionCaptureState extends State<ReflectionCapture> {
  final GlobalKey _boundary = GlobalKey();

  Timer? _shutter;

  /// Whether a capture is already in flight.
  ///
  /// A readback can take longer than the interval on a slow frame, and two
  /// overlapping ones would queue behind each other until the timer had run
  /// further ahead than the pictures it was asking for.
  bool _capturing = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void didUpdateWidget(ReflectionCapture old) {
    super.didUpdateWidget(old);
    if (widget.enabled != old.enabled) _start();
  }

  @override
  void dispose() {
    _shutter?.cancel();
    super.dispose();
  }

  void _start() {
    _shutter?.cancel();
    if (!widget.enabled) return;
    _shutter = Timer.periodic(ReflectionCapture.interval, (_) => _capture());
  }

  Future<void> _capture() async {
    if (_capturing || !mounted) return;

    final object = _boundary.currentContext?.findRenderObject();
    if (object is! RenderRepaintBoundary) return;

    // Nothing has been laid out yet, or the boundary is mid-layout. Asking
    // for its image now throws rather than returning an empty one.
    if (object.debugNeedsPaint) return;

    _capturing = true;
    try {
      final image = await object.toImage(pixelRatio: ReflectionCapture.scale);
      if (!mounted) {
        image.dispose();
        return;
      }
      widget.onCaptured(image);
    } catch (_) {
      // A capture that fails is a frame the water reflects the previous
      // picture instead. Not worth interrupting the scene for.
    } finally {
      _capturing = false;
    }
  }

  @override
  Widget build(BuildContext context) =>
      RepaintBoundary(key: _boundary, child: widget.child);
}
