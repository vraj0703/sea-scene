import 'dart:async';

import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/foundation.dart';
import 'package:sea_scene/domain/audio/app_audio.dart';

/// [AppAudio] over `flame_audio`.
///
/// Every call is wrapped. A missing file, a codec the platform dislikes, a
/// browser refusing to play before the visitor has clicked anything — all
/// ordinary, and none of them worth an exception crossing a render loop.
class FlameAppAudio implements AppAudio {
  FlameAppAudio();

  @visibleForTesting
  static String? fileFor(AudioCue cue) => _files[cue];

  @visibleForTesting
  static double? volumeFor(AudioCue cue) => _volumes[cue];

  /// The four cards are a rising scale, and the title is the note under it.
  /// Naming them by their moment rather than their pitch is what lets the
  /// scale be re-voiced without touching a call site.
  /// The scale, in the order the scene plays it.
  ///
  /// `do re mi fa si sol` — the sequence asked for. Worth noting it is not
  /// quite an ascending scale: `si` is the seventh and `sol` the fifth, so the
  /// last two step *down*. That is a real musical choice rather than a slip,
  /// and it resolves downward at the end instead of running off the top; if
  /// the intent was to keep climbing, swapping these two lines is the whole
  /// of the change.
  static const Map<AudioCue, String> _files = <AudioCue, String>{
    AudioCue.mark: 'do.mp3',
    AudioCue.title: 're.mp3',
    AudioCue.cardOne: 'mi.mp3',
    AudioCue.cardTwo: 'fa.mp3',
    AudioCue.cardThree: 'si.mp3',
    AudioCue.cardFour: 'sol.mp3',
    AudioCue.follow: 'harp_enter.mp3',
    AudioCue.thunderCrack: 'thunder_crack.mp3',
    AudioCue.thunderRoll: 'thunder_roll.mp3',
    AudioCue.drop: 'waterdrop.mp3',
  };

  static const Map<AudioCue, double> _volumes = <AudioCue, double>{
    AudioCue.mark: 0.5,
    AudioCue.title: 0.5,
    AudioCue.cardOne: 0.45,
    AudioCue.cardTwo: 0.45,
    AudioCue.cardThree: 0.45,
    AudioCue.cardFour: 0.45,
    AudioCue.follow: 0.5,
    // Weather sits above everything else on purpose: a strike that is
    // politely quiet is not a strike.
    AudioCue.thunderCrack: 0.7,
    AudioCue.thunderRoll: 0.55,
    AudioCue.drop: 0.4,
  };

  /// Shortest gap between two plays of the *same* cue.
  ///
  /// Four cards landing together, or two strikes in the same breath, would
  /// otherwise stack the same file on itself and read as distortion.
  static const Duration retriggerGuard = Duration(milliseconds: 90);

  final Map<AudioCue, int> _lastPlayedMs = <AudioCue, int>{};
  final Stopwatch _clock = Stopwatch()..start();

  bool _muted = false;
  bool _preloaded = false;

  @override
  bool get isMuted => _muted;

  @override
  Future<void> preload() async {
    if (_preloaded) return;
    _preloaded = true;

    // One at a time, not `loadAll`.
    //
    // `loadAll` gives up on the first file it cannot fetch, so a single
    // missing asset takes every cue after it down with it — and the failure
    // is silent, because warming the cache is best-effort. Two files had been
    // pruned from the folder while still named here, and the whole scene went
    // quiet rather than losing two sounds.
    for (final file in _files.values) {
      try {
        await FlameAudio.audioCache.load(file);
      } catch (error, stack) {
        // Not fatal on its own: the first play of *this* cue simply fetches
        // instead, and every other cue is unaffected.
        _report('preload of $file failed', error, stack);
      }
    }
  }

  @override
  void play(AudioCue cue, {double? volume}) {
    if (_muted) return;

    final file = _files[cue];
    if (file == null) return;
    if (!admit(cue)) return;

    // Deliberately not awaited. A cue marks a moment in an animation, and
    // making the caller wait on the audio pipeline would couple the scene's
    // timing to how fast a file decodes.
    unawaited(_playSafely(file, volume ?? _volumes[cue] ?? 1));
  }

  /// Whether [cue] may sound now, recording the attempt if so.
  ///
  /// Separated from [play] so the guard can be tested for what it actually
  /// does. Folded in, it is unobservable without an audio backend.
  @visibleForTesting
  bool admit(AudioCue cue) {
    final now = _clock.elapsedMilliseconds;
    final last = _lastPlayedMs[cue];
    if (last != null && now - last < retriggerGuard.inMilliseconds) {
      return false;
    }
    _lastPlayedMs[cue] = now;
    return true;
  }

  Future<void> _playSafely(String file, double volume) async {
    try {
      await FlameAudio.play(file, volume: volume);
    } catch (error, stack) {
      _report('play $file failed', error, stack);
    }
  }

  @override
  void setMuted(bool muted) => _muted = muted;

  @override
  Future<void> dispose() async {
    try {
      FlameAudio.audioCache.clearAll();
    } catch (error, stack) {
      _report('dispose failed', error, stack);
    }
  }

  void _report(String message, Object error, StackTrace stack) {
    if (!kDebugMode) return;
    debugPrint('[audio] $message: $error');
  }
}
