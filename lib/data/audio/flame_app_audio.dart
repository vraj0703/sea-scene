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
  static const Map<AudioCue, String> _files = <AudioCue, String>{
    AudioCue.arrival: 'do.mp3',
    AudioCue.cardOne: 're.mp3',
    AudioCue.cardTwo: 'mi.mp3',
    AudioCue.cardThree: 'fa.mp3',
    AudioCue.cardFour: 'si.mp3',
    AudioCue.flip: 'whoosh.mp3',
    AudioCue.follow: 'sol.mp3',
    AudioCue.thunderCrack: 'thunder_crack.mp3',
    AudioCue.thunderRoll: 'thunder_roll.mp3',
    AudioCue.sea: 'rumble.mp3',
    AudioCue.drop: 'waterdrop.mp3',
  };

  static const Map<AudioCue, double> _volumes = <AudioCue, double>{
    AudioCue.arrival: 0.5,
    AudioCue.cardOne: 0.45,
    AudioCue.cardTwo: 0.45,
    AudioCue.cardThree: 0.45,
    AudioCue.cardFour: 0.45,
    // Under the note it accompanies. The flip is the sound of the card
    // moving, not the sound of the card arriving.
    AudioCue.flip: 0.3,
    AudioCue.follow: 0.5,
    // Weather sits above everything else on purpose: a strike that is politely
    // quiet is not a strike.
    AudioCue.thunderCrack: 0.7,
    AudioCue.thunderRoll: 0.55,
    AudioCue.sea: 0.35,
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

  /// The bed, once it is running, and how loud it was asked to be.
  ///
  /// The level is remembered separately from the player because muting must
  /// not lose it: silence is a fader at zero, and unmuting has to put it back
  /// where the scene left it rather than at some default.
  AudioPlayer? _bedPlayer;
  AudioCue? _bedCue;
  double _bedLevel = 0;

  @override
  bool get isMuted => _muted;

  @override
  Future<void> preload() async {
    if (_preloaded) return;
    _preloaded = true;

    try {
      await FlameAudio.audioCache.loadAll(_files.values.toList());
    } catch (error, stack) {
      // Not fatal: the first play simply fetches instead.
      _report('preload failed', error, stack);
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
  Future<void> bed(AudioCue cue, double level) async {
    final wanted = level.clamp(0.0, 1.0);
    _bedCue = cue;
    _bedLevel = wanted;

    final file = _files[cue];
    if (file == null) return;

    try {
      if (wanted <= 0) {
        await _bedPlayer?.stop();
        _bedPlayer = null;
        return;
      }

      // Started at silence and faded up, never started at the level asked
      // for: a loop that begins at full volume begins with a click, and the
      // one sound the visitor never chose to hear should not announce itself.
      _bedPlayer ??= await FlameAudio.loop(file, volume: 0);
      await _bedPlayer?.setVolume(_muted ? 0 : wanted * (_volumes[cue] ?? 1));
    } catch (error, stack) {
      _report('bed $file failed', error, stack);
      _bedPlayer = null;
    }
  }

  @override
  void setMuted(bool muted) {
    _muted = muted;

    // The bed is the only sound that outlives the moment it started, so it is
    // the only one muting has to reach into. Everything else simply stops
    // being fired.
    final cue = _bedCue;
    if (cue == null) return;
    unawaited(bed(cue, _bedLevel));
  }

  @override
  Future<void> dispose() async {
    try {
      await _bedPlayer?.stop();
      _bedPlayer = null;
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
