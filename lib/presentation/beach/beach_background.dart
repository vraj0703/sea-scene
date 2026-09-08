import 'dart:ui';

import 'package:flame/components.dart';
import 'package:sea_scene/domain/beach/beach_config.dart';
import 'package:sea_scene/presentation/beach/beach_weather.dart';

/// The sea, the sky and everything in them, drawn by `beach.frag`.
///
/// One rectangle and one shader. Every wave, cloud, bird and reflection in the
/// scene is a fragment of it — there is no geometry here, so what looks like a
/// world is eighteen numbers and a sampler, set once a frame.
///
/// The numbers are named in [BeachUniform] rather than written as indices at
/// the call site. That is not decoration: the previous site set eighteen bare
/// slots in a row, and a shader whose uniforms are addressed by position is a
/// contract that cannot be checked by reading either half alone.
class BeachBackground extends PositionComponent {
  BeachBackground({required this.shader, super.size});

  final FragmentShader shader;

  /// The weather, which the shader reads but does not decide.
  final Lightning lightning = Lightning();
  final Birds birds = Birds();
  final Ripple ripple = Ripple();

  /// Seconds since the scene opened.
  ///
  /// Its own accumulator rather than a wall clock: the whole sea is a function
  /// of this, so it has to advance with the frames that draw it. A tab left in
  /// the background would otherwise come back with the sea jumped forward.
  double _time = 0;

  /// How visible the scene is, `0`..`1`.
  double opacity = 0;

  /// How far through the scene the visitor has come. The shader turns the sky
  /// with it.
  double _progress = 0;

  /// What the water is mirroring.
  ///
  /// The cards, photographed where they stand. The shader samples this in
  /// *screen space*, so whatever is in it appears in the water at the place
  /// it occupies on screen — which is why the picture has to come from the
  /// cards themselves rather than being drawn a second time here.
  ///
  /// The name is deliberately not in it. It was, and a title reflected
  /// through a bloom that lightning multiplies by twenty is a smear lying on
  /// the sea rather than a reflection of anything.
  Image? _reflection;

  /// The shader needs a sampler bound on every draw — an unbound one is
  /// undefined behaviour, not an empty one — so a single pixel stands in
  /// until the plate has been painted.
  Image? _blank;

  /// Where the horizon is, in logical pixels.
  double _waterY = 0;

  double get waterY => _waterY;
  double get time => _time;

  /// Whether the water has anything to mirror yet.
  bool get hasReflection => _reflection != null;

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    final recorder = PictureRecorder();
    Canvas(recorder);
    _blank = await recorder.endRecording().toImage(1, 1);
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    this.size = size;
  }

  @override
  void update(double dt) {
    super.update(dt);

    _time += dt;
    lightning.update(dt);
    birds.update(dt);
    ripple.update(dt);

    // The flock answers the sky rather than the other way round, and it is
    // done here rather than at the strike so a flash that decays across
    // several frames goes on unsettling them for as long as it is visible.
    birds.startle(lightning.intensity);
  }

  /// Rings the water at [where], in this component's own space.
  void splash(Vector2 where) => ripple.strike(Offset(where.x, where.y));

  /// Sets the horizon, in logical pixels.
  void setWaterLevel(double y) => _waterY = y;

  void setProgress(double progress) => _progress = progress.clamp(0.0, 1.0);

  /// Hands the water a new picture to mirror.
  ///
  /// The previous one is released here rather than by the caller: this is the
  /// only thing that knows when the shader has stopped sampling it. Released
  /// *after* the swap, never before — freeing what the next draw is about to
  /// read leaves a frame sampling nothing.
  void reflect(Image image) {
    final previous = _reflection;
    _reflection = image;
    if (!identical(previous, image)) previous?.dispose();
  }

  @override
  void render(Canvas canvas) {
    final sampler = _reflection ?? _blank;

    // Nothing to bind means nothing safe to draw. It happens for exactly one
    // frame, between mounting and `onLoad` finishing.
    if (sampler == null) return;

    final pixelRatio = size.x <= 0 ? 1.0 : (canvasSize?.x ?? size.x) / size.x;

    shader
      ..setFloat(BeachUniform.width, size.x)
      ..setFloat(BeachUniform.height, size.y)
      ..setFloat(BeachUniform.time, _time)
      ..setFloat(BeachUniform.textY, 0)
      ..setFloat(BeachUniform.waterY, _waterY)
      ..setFloat(BeachUniform.textOpacity, BeachConfig.reflectionStrength)
      ..setFloat(BeachUniform.textScale, 1)
      ..setFloat(BeachUniform.textWidth, sampler.width.toDouble())
      ..setFloat(BeachUniform.textHeight, sampler.height.toDouble())
      ..setFloat(BeachUniform.textX, 0)
      ..setFloat(BeachUniform.pixelRatio, pixelRatio)
      ..setFloat(BeachUniform.opacity, opacity)
      ..setFloat(BeachUniform.lightning, lightning.intensity)
      ..setFloat(BeachUniform.panic, birds.panic)
      ..setFloat(BeachUniform.rippleX, ripple.origin.dx)
      ..setFloat(BeachUniform.rippleY, ripple.origin.dy)
      ..setFloat(BeachUniform.rippleTime, ripple.age)
      ..setFloat(BeachUniform.scrollProgress, _progress)
      ..setImageSampler(BeachUniform.reflection, sampler);

    canvas.drawRect(size.toRect(), Paint()..shader = shader);
  }

  /// The surface's own pixel size, when the component is mounted in a game.
  ///
  /// Null off a game, which is how a test renders this without standing one
  /// up — the pixel ratio then falls back to 1 and the sea is drawn in
  /// logical pixels.
  Vector2? get canvasSize => isMounted ? findGame()?.canvasSize : null;
}
