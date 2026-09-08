import 'dart:async';
import 'dart:ui';

import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:sea_scene/domain/audio/app_audio.dart';
import 'package:sea_scene/domain/beach/beach_config.dart';
import 'package:sea_scene/domain/interfaces/queuer.dart';
import 'package:sea_scene/domain/models/loading_phase.dart';
import 'package:sea_scene/presentation/beach/beach_background.dart';
import 'package:sea_scene/presentation/beach/beach_weather.dart';
import 'package:sea_scene/presentation/beach/title_plate.dart';
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

  final AmbientStorm _storm = AmbientStorm();

  /// How many frames have been drawn since the scene was assembled.
  ///
  /// The priming phase waits on this. A shader's pipeline is compiled the
  /// first time it is *drawn*, not when it is loaded, so a bar that completed
  /// on load would hand the compile to the frame the visitor arrives on.
  int _drawn = 0;
  static const int primingFrames = 5;

  bool _primed = false;

  /// The name currently on the plate, so a resize can be told from a rebuild.
  Future<void>? _painting;

  /// How gathered the storm is, `0`..`1`.
  ///
  /// Nothing drives it upward yet — the previous site tied it to scroll — so
  /// it sits at a steady drizzle. It is a field rather than a constant because
  /// every part of the storm already reads from it: the bed's level, the
  /// strike's force, and how far behind the flash the roll arrives.
  double gathering = 0.35;

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    final program = await FragmentProgram.fromAsset(
      'assets/shaders/beach.frag',
    );
    _report(LoadingPhase.shader, 1);

    background = BeachBackground(shader: program.fragmentShader(), size: size)
      ..opacity = 1
      ..setWaterLevel(BeachConfig.horizonFor(size.y));
    await add(background);

    _paintTitle();

    // Not awaited against the bar's own completion — the cues are small and
    // the phase is reported when they land, whenever that is.
    unawaited(_warmAudio());
  }

  Future<void> _warmAudio() async {
    await audio.preload();
    _report(LoadingPhase.audio, 1);

    // The sea comes up with the scene and stays. Held under everything for
    // as long as the beach is on screen, which is what stops the gaps between
    // thunderclaps sounding like a photograph.
    await audio.bed(AudioCue.sea, _seaLevel);
  }

  /// How loud the sea runs, for how gathered the storm is.
  ///
  /// Never silent and never at the top: a bed that reaches full is a bed that
  /// has nowhere left to go when the weather turns.
  double get _seaLevel => 0.35 + gathering * 0.45;

  /// Repaints the name for the current viewport.
  ///
  /// Guarded against overlapping work: a drag-resize delivers a resize a
  /// frame, and each one rasterises type. Without this the second painting
  /// would race the first and whichever finished last would win, which is not
  /// necessarily the one that matches the window.
  void _paintTitle() {
    if (_painting != null) return;

    final viewport = Size(size.x, size.y);
    if (viewport.isEmpty) return;

    _painting = TitlePlate.paint(
      text: title,
      size: viewport,
      waterY: BeachConfig.horizonFor(viewport.height),
    ).then((plate) {
      _painting = null;

      // The window may have moved on while the type was being drawn. Rather
      // than show a plate cut for a viewport that no longer exists, throw it
      // away and paint the one that does.
      if (!plate.fits(Size(size.x, size.y))) {
        plate.dispose();
        _paintTitle();
        return;
      }

      background.showTitle(plate);
    });
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    if (!isLoaded) return;

    background.setWaterLevel(BeachConfig.horizonFor(size.y));
    _paintTitle();
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

    if (_storm.update(dt)) _flash();
  }

  /// A strike, with its roll following at a distance.
  ///
  /// The gap between the two is how far away the storm reads as being, so the
  /// roll is scheduled rather than played with the flash — sound is slower
  /// than light, and a thunderclap that arrives with the light is a lamp.
  void _flash() {
    final force = background.lightning.strike();
    if (force == null) return;

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
