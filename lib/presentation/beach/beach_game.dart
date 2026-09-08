import 'dart:async';
import 'dart:ui';

import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:sea_scene/domain/audio/app_audio.dart';
import 'package:sea_scene/domain/beach/beach_config.dart';
import 'package:sea_scene/data/di/injection.dart';
import 'package:sea_scene/data/shaders/shader_library.dart';
import 'package:sea_scene/domain/interfaces/queuer.dart';
import 'package:sea_scene/domain/models/loading_phase.dart';
import 'package:sea_scene/presentation/beach/beach_background.dart';
import 'package:sea_scene/presentation/beach/beach_weather.dart';
import 'package:sea_scene/presentation/bloc/scene_bloc.dart';

/// The beach, running.
///
/// Holds the one component that draws it, the storm that decides when the sky
/// flashes, and the reporting the loading screen waits on. The same division
/// the portfolio uses: the game owns the loop, the bloc owns the stage, and
/// neither reaches into the other except through [Queuer].
class BeachGame extends FlameGame with TapCallbacks {
  BeachGame({
    required this.queuer,
    required this.audio,
    required this.title,
  });

  /// Where loading progress and stage changes are reported.
  final Queuer queuer;

  /// Deliberately held rather than reached for: a Flame component has no
  /// `BuildContext`, so anything it needs from the app has to be handed to it.
  final AppAudio audio;

  late final BeachBackground background;

  /// How many frames have been drawn since the scene was assembled.
  ///
  /// The priming phase waits on this. A shader's pipeline is compiled the
  /// first time it is *drawn*, not when it is loaded, so a bar that completed
  /// on load would hand the compile to the frame the visitor arrives on.
  int _drawn = 0;
  static const int primingFrames = 5;

  bool _primed = false;

  /// How close the storm has come, `0`..`1`.
  ///
  /// Climbs a little with each card the visitor turns over, so the fourth
  /// answer is nearer than the first. It shapes both halves of a strike — how
  /// hard the crack lands and how soon the roll follows it — which is what
  /// makes the storm read as approaching rather than as a louder setting.
  double gathering = 0.3;

  /// How much closer each press brings it.
  static const double gatheringPerStrike = 0.12;

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // Both shaders, together: the name is drawn by a widget that has no game
    // to ask, so waiting for its program here is what lets the curtain cover
    // the compiling of both.
    final shaders = locate<ShaderLibrary>();
    await shaders.load();
    _report(LoadingPhase.shader, 1);

    background =
        BeachBackground(shader: shaders.beach!.fragmentShader(), size: size)
          ..opacity = 1
          ..setWaterLevel(BeachConfig.horizonFor(size.y));
    await add(background);

    // Not awaited against the bar's own completion — the cues are small and
    // the phase is reported when they land, whenever that is.
    unawaited(_warmAudio());
  }

  Future<void> _warmAudio() async {
    await audio.preload();
    _report(LoadingPhase.audio, 1);
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    if (!isLoaded) return;

    background.setWaterLevel(BeachConfig.horizonFor(size.y));
  }

  /// Hands the water a fresh photograph of the cards.
  void reflect(Image image) {
    if (!isLoaded) {
      // Nothing to give it to yet. Released rather than held, or the first
      // few captures leak until the scene catches up.
      image.dispose();
      return;
    }
    background.reflect(image);
  }

  @override
  void update(double dt) {
    super.update(dt);

    // Counted from the loop rather than a timer: what the bar is waiting for
    // is frames actually drawn, and a clock cannot tell a frame from a stall.
    if (!_primed) {
      _drawn++;
      _report(LoadingPhase.priming, _drawn / primingFrames);
      if (_drawn >= primingFrames) _primed = true;
    }

  }

  /// A strike, with its roll following at a distance.
  ///
  /// Fired by the cards and by nothing else. The sky used to flash on its own
  /// every six to fifteen seconds, which made the storm ambient — and ambient
  /// thunder is weather happening *to* the visitor rather than because of
  /// them. Tied to a press it becomes an answer: they turned a card over, and
  /// the sky replied.
  ///
  /// The gap between flash and roll is how far away the storm reads as being,
  /// so the roll is scheduled rather than played with the light. Sound is
  /// slower than light, and a thunderclap that arrives with the flash is a
  /// lamp rather than a storm.
  void strike() {
    final force = background.lightning.strike();
    if (force == null) return;

    gathering = (gathering + gatheringPerStrike).clamp(0.0, 1.0);

    // The crack carries the storm's distance in its level, and the roll
    // carries it in its lag. Both, because either alone reads as a volume
    // knob rather than as weather moving.
    audio.play(AudioCue.thunderCrack, volume: 0.7 * force.clamp(0.5, 1.2));

    Future<void>.delayed(Lightning.rollLag(gathering), () {
      // The scene may have gone in the meantime; a roll for a flash nobody
      // saw is a sound with nothing behind it.
      if (isMounted) {
        audio.play(AudioCue.thunderRoll, volume: 0.55 * gathering.clamp(0.4, 1));
      }
    });
  }

  /// The name written across the horizon.
  ///
  /// Handed in rather than read here. A Flame component has no
  /// `BuildContext`, so copy reaches it the same way colour does in the
  /// portfolio: from the widget that built it.
  final String title;

  /// Rings the water where the visitor touched it.
  @override
  void onTapDown(TapDownEvent event) {
    super.onTapDown(event);

    final where = event.localPosition;
    background.splash(where);

    // Only the water answers. A tap on the sky is a tap on a picture.
    if (where.y >= background.waterY) {
      audio.play(AudioCue.drop);
    }
  }

  void _report(LoadingPhase phase, double value) => queuer.queue(
    event: LoadingProgressed(phase: phase, value: value.clamp(0.0, 1.0)),
  );
}
