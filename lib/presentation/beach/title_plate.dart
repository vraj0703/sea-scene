import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

/// The name, drawn once into an image the size of the screen.
///
/// One picture serves twice: it is drawn over the sea *and* handed to the
/// shader as the thing the water reflects. That is not an optimisation — it is
/// the only way the two can agree. `beach.frag` samples the reflection in
/// screen space, so whatever is in the sampler appears in the water at the
/// place it occupies in the image; a title drawn by one path and reflected
/// from another would drift apart the moment either moved.
///
/// Rebuilt only when the viewport changes. Rasterising type is not free, and
/// nothing about the name moves between resizes.
class TitlePlate {
  TitlePlate._(this.image, this.size, this.baseline);

  /// The plate itself — transparent everywhere but the name.
  final ui.Image image;

  /// The viewport it was drawn for, in logical pixels.
  final Size size;

  /// Where the name sits, so the sea can be told to stay below it.
  final double baseline;

  /// Draws [text] for a viewport of [size].
  ///
  /// [waterY] is the horizon, in logical pixels. The name is set above it —
  /// a title that crosses the waterline is reflected into itself, which reads
  /// as a rendering fault rather than a reflection.
  static Future<TitlePlate> paint({
    required String text,
    required Size size,
    required double waterY,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);

    // Sized from the viewport rather than fixed, so the name holds its share
    // of the horizon on a phone and on a desktop alike.
    final fontSize = (size.width * 0.085).clamp(28.0, 96.0);

    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: fontSize,
          letterSpacing: fontSize * 0.14,
          fontWeight: FontWeight.w300,
          // White, and left white on purpose. The shader grades what it
          // samples — a cool water tint, a fresnel falloff and a bloom that
          // lightning multiplies — so a colour chosen here would be graded
          // twice and arrive somewhere nobody picked.
          color: const Color(0xFFFFFFFF),
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: size.width);

    // Standing clear of the water, not on it. The gap is what gives the
    // reflection somewhere to begin.
    final baseline = waterY - painter.height - size.height * 0.06;

    painter.paint(
      canvas,
      Offset((size.width - painter.width) / 2, baseline),
    );

    final image = await recorder.endRecording().toImage(
      size.width.round(),
      size.height.round(),
    );

    return TitlePlate._(image, size, baseline);
  }

  /// Whether this plate still fits [viewport].
  bool fits(Size viewport) =>
      (size.width - viewport.width).abs() < 1 &&
      (size.height - viewport.height).abs() < 1;

  void dispose() => image.dispose();
}
