/// An independently-loading subsystem that the loading screen waits on.
///
/// Adding a phase is deliberately cheap: declare it here with a weight and
/// have the owning system report against it. Nothing else needs touching —
/// [LoadingProgress] normalises by the total weight, so weights do **not**
/// have to be rebalanced to keep summing to 1.
///
/// The weight is the share of the bar a phase occupies, relative to the
/// others. It should track roughly how long the phase actually takes, so the
/// bar advances at a believable rate rather than stalling on the slow one.
enum LoadingPhase {
  /// Compiling `beach.frag` and standing up the render loop.
  ///
  /// The heavy one. A fragment shader of this size is not free to compile,
  /// and it is the only thing between a black page and a sea.
  shader(weight: 3),

  /// Fetching and decoding the cues.
  ///
  /// Light, and deliberately still a phase: the four cards play a rising
  /// scale as they land, and a scale whose first note is still downloading
  /// plays as three notes and a gap.
  audio(weight: 1),

  /// Drawing the finished scene once, behind the curtain.
  ///
  /// A shader's pipeline is built the first time it is *drawn*, not when it
  /// is loaded — so without this the cost lands on the frame the visitor
  /// arrives on, which is the one frame they are watching.
  priming(weight: 0.5);

  const LoadingPhase({required this.weight});

  /// Relative share of the overall bar. Must be positive.
  final double weight;
}
