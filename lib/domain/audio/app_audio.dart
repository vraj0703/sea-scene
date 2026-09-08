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
  /// The six things that arrive, in the order they arrive.
  ///
  /// A rising scale played by the scene assembling itself: the mark, the
  /// name, then the four cards. They are named for what arrives rather than
  /// for the note, so the scale can be re-voiced without touching a call
  /// site — see `EntrySequence` for the order and `FlameAppAudio` for which
  /// note each one currently sounds.
  mark,
  title,
  cardOne,
  cardTwo,
  cardThree,
  cardFour,

  /// A card being followed out to wherever it points.
  follow,

  /// The strike itself, and the roll that answers it a moment later.
  ///
  /// Two cues rather than one because they are two events: the flash is
  /// instant and the roll arrives after a delay that depends on how close the
  /// storm has come.
  thunderCrack,
  thunderRoll,

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
    AudioCue.mark => const Duration(milliseconds: 1800),
    AudioCue.title => const Duration(milliseconds: 1800),
    AudioCue.cardOne => const Duration(milliseconds: 1800),
    AudioCue.cardTwo => const Duration(milliseconds: 1800),
    AudioCue.cardThree => const Duration(milliseconds: 1800),
    AudioCue.cardFour => const Duration(milliseconds: 1800),
    AudioCue.follow => const Duration(milliseconds: 2000),
    AudioCue.thunderCrack => const Duration(milliseconds: 2400),
    AudioCue.thunderRoll => const Duration(milliseconds: 4000),
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
  void setMuted(bool muted) {}
  @override
  bool get isMuted => false;
  @override
  Future<void> dispose() async {}
}
