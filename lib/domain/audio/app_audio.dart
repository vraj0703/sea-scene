import 'package:flutter/material.dart';

/// The sounds the beach can make.
///
/// Cues are named for the moment they mark, not for the file behind them, so
/// swapping the sound for a beat never touches a call site. The same contract
/// the portfolio uses, with the beach's own vocabulary in it.
///
/// The four cards are a rising scale on purpose — the previous site gave them
/// `re`, `mi`, `fa`, `si` against the title's `do`. Turning over the row is
/// meant to sound like playing it, so the cues keep their order rather than
/// being one "card" sound repeated.
enum AudioCue {
  /// The title arriving out of the water.
  arrival,

  /// Each card settling into the sand, in the order they land.
  cardOne,
  cardTwo,
  cardThree,
  cardFour,

  /// A card turning over. Fired at the halfway point of the flip, where the
  /// edge is toward the viewer and there is nothing to look at.
  flip,

  /// A card being followed out to wherever it points.
  follow,

  /// The strike itself, and the roll that answers it a moment later.
  ///
  /// Two cues rather than one because they are two events: the flash is
  /// instant and the roll arrives after a delay that depends on how close the
  /// storm has come.
  thunderCrack,
  thunderRoll,

  /// The sea itself, running under everything for as long as the scene is up.
  ///
  /// Looped rather than fired. It is the one sound that is not an event: a
  /// beach with no sound between thunderclaps is a photograph, and a bed that
  /// has to be re-triggered is a bed with seams in it.
  sea,

  /// A drop striking the water, and the ring it leaves.
  drop,
}

/// How long the file behind each cue runs.
///
/// Data rather than a comment, because timings are derived from it: a sound
/// that runs materially longer or shorter than the motion it accompanies reads
/// as a fault even when both are fine alone. Exhaustive on purpose — a new cue
/// will not compile until its length has been measured, which is the only
/// reliable moment to do it.
extension AudioCueLength on AudioCue {
  Duration get length => switch (this) {
    AudioCue.arrival => const Duration(milliseconds: 1800),
    AudioCue.cardOne => const Duration(milliseconds: 1800),
    AudioCue.cardTwo => const Duration(milliseconds: 1800),
    AudioCue.cardThree => const Duration(milliseconds: 1800),
    AudioCue.cardFour => const Duration(milliseconds: 1800),
    AudioCue.flip => const Duration(milliseconds: 900),
    AudioCue.follow => const Duration(milliseconds: 1800),
    AudioCue.thunderCrack => const Duration(milliseconds: 2400),
    AudioCue.thunderRoll => const Duration(milliseconds: 4000),
    AudioCue.sea => const Duration(milliseconds: 3000),
    AudioCue.drop => const Duration(milliseconds: 900),
  };
}

/// Contract for the app's sound.
///
/// The scene depends on this rather than on an audio package, so the backend
/// can change — or be stubbed out entirely in tests — without touching
/// anything that makes a sound.
///
/// Implementations must treat playback as **best-effort**. A missing file, a
/// codec the platform dislikes, or a browser refusing to play before the
/// visitor has interacted are all ordinary conditions, and none of them are
/// worth interrupting the scene for. Sound is weather here; the beach runs
/// silently rather than not at all.
abstract class AppAudio {
  /// Warms the cache so the first cue is not late.
  Future<void> preload();

  /// Plays [cue], if sound is on and the asset is available.
  void play(AudioCue cue, {double? volume});

  /// Holds [cue] under the scene at [level], `0`..`1`.
  ///
  /// Zero stops it. Anything else starts it if it is not already running and
  /// otherwise just moves the fader — so a caller can push the sea up as the
  /// storm gathers without knowing whether it has begun.
  ///
  /// Its own verb rather than `play(loop: true)`: a bed and a cue are
  /// different things. One marks a moment and ends; the other is the room,
  /// and the only question anybody asks of it is how loud.
  Future<void> bed(AudioCue cue, double level);

  /// Silences everything without unloading it.
  void setMuted(bool muted);

  bool get isMuted;

  /// Releases players and cached data.
  Future<void> dispose();
}

/// Puts [AppAudio] in the theme, so a widget reaches it the same way it
/// reaches colour and type.
class AppAudioExtension extends ThemeExtension<AppAudioExtension> {
  const AppAudioExtension({required this.audio});

  final AppAudio audio;

  @override
  AppAudioExtension copyWith({AppAudio? audio}) =>
      AppAudioExtension(audio: audio ?? this.audio);

  @override
  AppAudioExtension lerp(ThemeExtension<AppAudioExtension>? other, double t) {
    if (other is! AppAudioExtension) return this;
    // Audio does not lerp; the current one is kept until the swap.
    return t < 0.5 ? this : other;
  }
}

extension AudioX on BuildContext {
  AppAudio get audio =>
      Theme.of(this).extension<AppAudioExtension>()?.audio ??
      const SilentAudio();
}

/// An [AppAudio] that does nothing.
///
/// The fallback when no extension is installed, which is the normal case in a
/// widget test — rendering part of the scene should not require standing up an
/// audio backend. Public and `const` so a test can pass it deliberately rather
/// than relying on the fallback by accident.
class SilentAudio implements AppAudio {
  const SilentAudio();

  @override
  Future<void> preload() async {}
  @override
  void play(AudioCue cue, {double? volume}) {}
  @override
  Future<void> bed(AudioCue cue, double level) async {}
  @override
  void setMuted(bool muted) {}
  @override
  bool get isMuted => false;
  @override
  Future<void> dispose() async {}
}
