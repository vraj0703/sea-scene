/// Where each of the beach shader's inputs lives, and what it means.
///
/// `beach.frag` takes its uniforms by index, so every one of these numbers is
/// a contract with the shader source rather than a preference. They are named
/// here for the same reason the shader names them in a comment: a bare
/// `setFloat(13, x)` at a call site is unreadable and unverifiable, and the
/// previous site had eighteen of them in a row.
///
/// The order below is the order in `assets/shaders/beach.frag`. If that file
/// is edited, this is the other half of the edit.
abstract final class BeachUniform {
  /// Viewport, in logical pixels. Slots 0 and 1.
  static const int width = 0;
  static const int height = 1;

  /// Seconds since the scene opened. Drives every wave, cloud and bird.
  static const int time = 2;

  /// The reflected title's placement and shape. The shader mirrors whatever
  /// is in the sampler into the water, and needs to know where it sat.
  static const int textY = 3;
  static const int textOpacity = 5;
  static const int textScale = 6;
  static const int textWidth = 7;
  static const int textHeight = 8;
  static const int textX = 9;

  /// Where the water begins, as a fraction of the viewport's height.
  static const int waterY = 4;

  /// Device pixel ratio, so the sampler is read in the space it was drawn in.
  static const int pixelRatio = 10;

  /// The whole scene's opacity, for fading the beach in and out.
  static const int opacity = 11;

  /// How bright the last strike still is, `0`..`1`, decaying every frame.
  static const int lightning = 12;

  /// How startled the birds are. Spikes with lightning and settles after it.
  static const int panic = 13;

  /// A ring spreading from where something struck the water. Slots 14 and 15
  /// are the origin; [rippleTime] is its age, negative when there is none.
  static const int rippleX = 14;
  static const int rippleY = 15;
  static const int rippleTime = 16;

  /// How far through the scene the visitor has come, which the shader uses to
  /// turn the sky.
  static const int scrollProgress = 17;

  /// The reflection texture, in the shader's only sampler slot.
  static const int reflection = 0;
}

/// How the beach behaves, as opposed to how it is drawn.
abstract final class BeachConfig {
  /// Where the horizon sits, as a fraction of the viewport height.
  ///
  /// A fraction here, but the shader wants it in **logical pixels** — it
  /// compares the fragment's own y against `uWaterY` and then divides by it
  /// to find how deep the fragment is. Handed a fraction it reads every
  /// pixel on the screen as infinitely deep, clamps, and returns no
  /// reflection at all: the sea looks right and mirrors nothing. Convert
  /// before setting it.
  static const double horizonFraction = 0.45;

  /// The horizon in logical pixels, for a viewport [height] tall.
  static double horizonFor(double height) => height * horizonFraction;

  /// How strongly the water carries the name.
  ///
  /// The shader over-exposes what it reflects — `bloom` starts at five and
  /// lightning multiplies it by twenty — because a reflection that merely
  /// matches the thing above it reads as a copy rather than as light on
  /// water. White type through that is a smear, not a mirror, so the
  /// reflection is dimmed here rather than the title being dimmed on screen:
  /// this is the one number that separates the two, which is what
  /// `uTextOpacity` is for.
  static const double reflectionStrength = 0.22;

  /// How fast a strike fades, in units of intensity a second.
  ///
  /// A flash is instant and the decay is what makes it a flash rather than a
  /// light being switched on. Carried over from the previous site.
  static const double lightningDecay = 1.2;

  /// The shortest gap between two strikes.
  ///
  /// Without it a run of high probability rolls produces a strobe rather than
  /// a storm.
  static const Duration strikeThrottle = Duration(milliseconds: 250);

  /// How long a ripple lives before the water is still again.
  static const double rippleLife = 2;

  /// How quickly the birds settle once nothing has startled them.
  static const double panicDecay = 1.5;

  /// The gap between ambient strikes when nothing else is driving the storm.
  static const double ambientStrikeMin = 6;
  static const double ambientStrikeMax = 15;

  /// How far the roll lags the flash, at the two ends of the storm.
  ///
  /// Sound is slower than light, and the delay is the whole of how far away a
  /// storm reads as being. At full intensity it is nearly on top of you.
  static const Duration rollLagFar = Duration(seconds: 3);
  static const Duration rollLagNear = Duration(milliseconds: 100);
}
