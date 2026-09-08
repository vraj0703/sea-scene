import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:sea_scene/data/di/injection.dart';
import 'package:sea_scene/data/shaders/shader_library.dart';
import 'package:sea_scene/domain/audio/app_audio.dart';
import 'package:sea_scene/domain/beach/entry_sequence.dart';

/// The name across the horizon, finished in metal.
///
/// Carried over from the previous site down to the numbers: ModrntUrban at 72,
/// bold, a point and a half of letter-spacing, and `metallic_text.frag` set as
/// the *foreground paint* of the type rather than drawn behind it. That last
/// part is the whole effect — the shader fills the glyphs, so the highlight
/// rakes across the letterforms instead of sitting in a box behind them.
///
/// A widget rather than a plate baked into an image, because the finish moves:
/// the shader takes a clock, and a rasterised title would be one frame of it
/// held still forever.
class TitleBanner extends StatefulWidget {
  const TitleBanner({
    required this.text,
    required this.shown,
    required this.pointer,
    super.key,
  });

  final String text;

  /// Where the cursor is, in logical pixels, or null when it has never been
  /// anywhere — a touch screen, or a page nobody has moved over yet.
  final ValueListenable<Offset?> pointer;

  /// Whether the scene has arrived. The name rises with the cards.
  final bool shown;

  /// The previous site's own type, unchanged.
  static const double fontSize = 72;
  static const double letterSpacing = 1.5;
  static const String family = 'ModrntUrban';

  /// What the metal is made of before the light hits it.
  static const Color base = Color(0xFFBFC7CC);

  /// Its place in the sequence: second, after the mark and before the cards.
  static const int order = 1;

  /// How fast the highlight chases the cursor, per second.
  ///
  /// Two speeds, as the previous site had: quick while the light is far from
  /// where it is wanted, slower as it closes. A single rate either lags
  /// across a big move or twitches on a small one.
  static const double chaseFar = 6;
  static const double chaseNear = 3;

  /// Where the two speeds change over, in logical pixels.
  static const double nearDistance = 100;

  /// Where the name sits, as a share of the height from the top.
  ///
  /// Measured from the top rather than up from the waterline, and that change
  /// is the point: the cards now stand *above* the water so they can be
  /// reflected, which put them between the horizon and the name. Anything
  /// positioned by its distance from the waterline lands in the middle of
  /// them. The name is above the whole group instead.
  static const double fromTop = 0.06;

  @override
  State<TitleBanner> createState() => _TitleBannerState();
}

class _TitleBannerState extends State<TitleBanner>
    with SingleTickerProviderStateMixin {
  /// Drives the highlight. Unbounded on purpose — the finish never settles.
  late final Ticker _clock = createTicker(_tick)..start();

  double _elapsed = 0;
  double _last = 0;

  bool _arriving = false;
  bool _here = false;

  /// Where the highlight actually is, as opposed to where the cursor is.
  ///
  /// The light follows rather than teleports — that lag is most of what makes
  /// the finish read as a reflection on metal rather than as a spotlight
  /// glued to the pointer.
  Offset? _light;

  void _tick(Duration elapsed) {
    final now = elapsed.inMicroseconds / 1e6;
    final dt = (now - _last).clamp(0.0, 1 / 30);
    _last = now;

    _chase(dt);
    setState(() => _elapsed = now);
  }

  /// Eases the highlight toward the cursor.
  void _chase(double dt) {
    final target = widget.pointer.value;
    if (target == null) return;

    final here = _light;
    if (here == null) {
      // First sighting: no chase to run, the light simply is where it is.
      _light = target;
      return;
    }

    final away = (target - here).distance;
    final speed = away > TitleBanner.nearDistance
        ? TitleBanner.chaseFar
        : TitleBanner.chaseNear;

    // Framerate-independent easing: the same fraction of the remaining gap
    // per second however long the frame took.
    final t = 1 - math.exp(-speed * dt);
    _light = Offset.lerp(here, target, t);
  }

  @override
  void initState() {
    super.initState();
    _arrive();
  }

  @override
  void didUpdateWidget(TitleBanner old) {
    super.didUpdateWidget(old);
    if (widget.shown && !old.shown) _arrive();
  }

  /// Comes in on its turn in the scale, second.
  void _arrive() {
    if (_arriving || !widget.shown) return;
    _arriving = true;

    Future<void>.delayed(EntrySequence.delayFor(TitleBanner.order), () {
      if (!mounted || _here) return;
      _here = true;
      context.audio.play(EntrySequence.noteFor(TitleBanner.order));
      setState(() {});
    });
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final program = locate<ShaderLibrary>().metallic;

    // Nothing to fill the letters with yet. The name waits rather than
    // appearing flat and then changing its finish a frame later.
    if (program == null) return const SizedBox.shrink();

    final screen = MediaQuery.sizeOf(context);

    return Positioned(
      left: 0,
      right: 0,
      // Sitting on the horizon, which is where the previous site put it: the
      // name is the thing the sea is behind, not a caption above it.
      top: screen.height * TitleBanner.fromTop,
      child: IgnorePointer(
        child: AnimatedOpacity(
          opacity: _here ? 1 : 0,
          duration: EntrySequence.settle,
          curve: Curves.easeOut,
          child: CustomPaint(
            size: Size(screen.width, BeachBannerMetrics.height),
            painter: _MetalType(
              text: widget.text,
              program: program,
              seconds: _elapsed,
              // Relative to the banner, because the shader is told the
              // glyphs' own box — a light in screen coordinates would sit a
              // banner's height off.
              light: _light == null
                  ? null
                  : _light! - Offset(0, screen.height * TitleBanner.fromTop),
            ),
          ),
        ),
      ),
    );
  }
}

/// How tall the banner reserves, so the layout does not have to lay out type
/// to find out.
abstract final class BeachBannerMetrics {
  static const double height = TitleBanner.fontSize * 1.4;
}

class _MetalType extends CustomPainter {
  _MetalType({
    required this.text,
    required this.program,
    required this.seconds,
    required this.light,
  });

  final String text;
  final ui.FragmentProgram program;
  final double seconds;

  /// Where the highlight sits, in the banner's own space. Null before the
  /// pointer has been anywhere.
  final Offset? light;

  @override
  void paint(Canvas canvas, Size size) {
    final shader = program.fragmentShader();

    // Where the light is, and where it goes when nobody has moved a pointer.
    //
    // The cursor drives it — that is the whole effect, and it is how the
    // previous site did it: the highlight is a reflection, so it has to
    // answer the viewer rather than run on a clock of its own. The sweep
    // below is only the fallback for a touch screen, where there is no
    // cursor to answer.
    final at =
        light ??
        Offset(
          size.width * (0.5 + 0.35 * math.sin(seconds * 0.6)),
          size.height * 0.25,
        );

    shader
      ..setFloat(0, size.width)
      ..setFloat(1, size.height)
      ..setFloat(2, 0)
      ..setFloat(3, 0)
      ..setFloat(4, seconds)
      ..setFloat(5, TitleBanner.base.r)
      ..setFloat(6, TitleBanner.base.g)
      ..setFloat(7, TitleBanner.base.b)
      ..setFloat(8, 1)
      ..setFloat(9, at.dx)
      ..setFloat(10, at.dy);

    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: TitleBanner.family,
          fontSize: TitleBanner.fontSize,
          fontWeight: FontWeight.bold,
          letterSpacing: TitleBanner.letterSpacing,
          // The shader *is* the ink. Set as a foreground paint it fills the
          // glyphs; behind them it would be a lit rectangle with text on it.
          foreground: Paint()..shader = shader,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: size.width);

    painter.paint(canvas, Offset((size.width - painter.width) / 2, 0));
  }

  @override
  bool shouldRepaint(_MetalType old) =>
      old.seconds != seconds || old.text != text || old.light != light;
}
