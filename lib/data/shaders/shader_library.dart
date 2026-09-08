import 'dart:ui';

/// Every shader the scene draws with, loaded once.
///
/// Held together rather than fetched where they are used, because two very
/// different things need them: the sea is drawn by a Flame component with no
/// widget tree above it, and the name is drawn by a widget with no game
/// beneath it. A single library both can reach keeps the compiling — which the
/// curtain waits on — in one place.
class ShaderLibrary {
  FragmentProgram? _beach;
  FragmentProgram? _metallic;

  /// The sea, the sky and everything in them.
  FragmentProgram? get beach => _beach;

  /// The finish on the name: a highlight raked across the glyphs.
  FragmentProgram? get metallic => _metallic;

  bool get isLoaded => _beach != null && _metallic != null;

  /// Compiles both. Safe to call twice; the second call is free.
  Future<void> load() async {
    if (isLoaded) return;

    _beach ??= await FragmentProgram.fromAsset('assets/shaders/beach.frag');
    _metallic ??= await FragmentProgram.fromAsset(
      'assets/shaders/metallic_text.frag',
    );
  }
}
