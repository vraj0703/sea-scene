import 'dart:ui' as ui;

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sea_scene/data/di/injection.dart';
import 'package:sea_scene/domain/audio/app_audio.dart';
import 'package:sea_scene/domain/models/loading_progress.dart';
import 'package:sea_scene/domain/style/colors.dart';
import 'package:sea_scene/domain/style/strings.dart';
import 'package:sea_scene/presentation/beach/beach_cards_layer.dart';
import 'package:sea_scene/presentation/beach/beach_game.dart';
import 'package:sea_scene/presentation/beach/reflection_capture.dart';
import 'package:sea_scene/presentation/beach/title_banner.dart';
import 'package:sea_scene/presentation/bloc/scene_bloc.dart';
import 'package:sea_scene/presentation/widgets/corner_controls.dart';
import 'package:sea_scene/presentation/widgets/curtain_clipper.dart';
import 'package:sea_scene/presentation/widgets/loading_screen.dart';

/// Provides the scene's state machine and hosts the scene itself.
class SeaScene extends StatelessWidget {
  const SeaScene({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<SceneBloc>(
      // Resolved through the container rather than constructed here, so the
      // bloc's dependencies can grow without this widget knowing.
      create: (_) => locate<SceneBloc>(),
      child: const Scaffold(body: SceneView()),
    );
  }
}

class SceneView extends StatefulWidget {
  const SceneView({super.key});

  @override
  State<SceneView> createState() => _SceneViewState();
}

class _SceneViewState extends State<SceneView> {
  /// How long the curtain takes to open.
  static const Duration reveal = Duration(milliseconds: 1400);

  /// Where the cursor is, for anything that answers it.
  ///
  /// A notifier rather than state, so moving the mouse repaints the one thing
  /// that cares — the name's highlight — instead of rebuilding a tree that
  /// holds a running game.
  final ValueNotifier<Offset?> _pointer = ValueNotifier<Offset?>(null);

  /// Held so the cards can reach the sky.
  ///
  /// The storm no longer runs on its own, so the only thing that can make it
  /// strike is a press — and a press happens in the widget tree while the
  /// weather lives in the game. This is the one wire between them.
  BeachGame? _game;

  @override
  void dispose() {
    _pointer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<SceneBloc>();
    final audio = context.audio;
    final title = context.strings.title;

    return MouseRegion(
      // Watching, not intercepting: `opaque: false` and no handlers that
      // consume, so the cards below still get their own enters and exits.
      opaque: false,
      onHover: (event) => _pointer.value = event.localPosition,
      onExit: (_) => _pointer.value = null,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          // Built once and kept. Rebuilding a `GameWidget` tears the loop down
          // and starts it again, which for a scene whose every wave is a
          // function of elapsed time means the sea jumps back to flat.
          GameWidget.controlled(
            // The instance is kept, not just built. Everything the widget
            // tree does *to* the scene goes through it — the sky answering a
            // hover, the water taking a photograph of the cards — and without
            // this it is null, so both fail silently: no thunder, and every
            // captured reflection thrown away on arrival.
            gameFactory: () {
              final game = BeachGame(queuer: bloc, audio: audio, title: title);
              _game = game;
              return game;
            },
          ),

          BlocBuilder<SceneBloc, SceneState>(
            builder: (context, state) {
              final covered = state.isCovered;

              return TweenAnimationBuilder<double>(
                // 0 = closed, 1 = fully open. On the first build the tween has
                // no `begin`, so it settles on 0 without animating — the scene
                // starts covered, which is what we want.
                tween: Tween<double>(end: covered ? 0.0 : 1.0),
                duration: reveal,
                curve: Curves.easeInOut,
                onEnd: () {
                  if (!covered) bloc.queue(event: const RevealCompleted());
                },
                builder: (context, open, _) {
                  return Stack(
                    fit: StackFit.expand,
                    children: <Widget>[
                      ClipPath(
                        clipper: CurtainClipper(revealProgress: open),
                        child: ColoredBox(color: context.colors.curtain),
                      ),

                      // Leaves *with* the curtain rather than popping out a
                      // frame before it starts. Once fully open it is gone
                      // entirely, costing nothing.
                      if (open < 1)
                        LoadingScreen(
                          exit: open,
                          // Once loaded, the invitation stands until the
                          // curtain is gone. Keyed on `Ready` alone it flipped
                          // back to "LOADING... 100%" the moment the visitor
                          // tapped, so the last thing they saw on the way in
                          // was a bar telling them about the past.
                          isReady: state is! Loading,
                          onEnter: () =>
                              bloc.queue(event: const EntryRequested()),
                          progress: state is Loading
                              ? state.progress
                              : LoadingProgress.complete,
                        ),
                    ],
                  );
                },
              );
            },
          ),

          // The name, and the cards under it. Both over the sea, and the cards
          // inside a boundary so the water can photograph them — the shader
          // mirrors whatever that picture holds, which is why the name is
          // outside it: a title through the water's bloom is a smear, not a
          // reflection.
          BlocBuilder<SceneBloc, SceneState>(
            buildWhen: (previous, current) =>
                _arrived(previous) != _arrived(current),
            builder: (context, state) {
              final arrived = _arrived(state);

              return Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  TitleBanner(text: title, shown: arrived, pointer: _pointer),
                  ReflectionCapture(
                    enabled: arrived,
                    onCaptured: (image) => _reflect(image),
                    child: BeachCardsLayer(
                      arrived: arrived,
                      // Guarded, because the cards exist before the game has
                      // finished loading — a press in that window has no sky to
                      // answer it yet.
                      onStruck: () => _game?.strike(),
                    ),
                  ),
                ],
              );
            },
          ),

          // The pair holding the top of the screen: whose beach this is, and
          // whether it makes a sound. The mark arrives with the scene and opens
          // the scale; the switch is always there, because a visitor reaching
          // for silence should not have to wait for an animation.
          BlocBuilder<SceneBloc, SceneState>(
            buildWhen: (previous, current) =>
                _arrived(previous) != _arrived(current),
            builder: (context, state) => CornerMark(shown: _arrived(state)),
          ),
          const SoundSwitch(),
        ],
      ),
    );
  }

  /// Passes a photograph of the cards to the water.
  ///
  /// The image is released here when there is no game to take it, so the
  /// captures made while the scene is still coming up do not pile up.
  void _reflect(ui.Image image) {
    final game = _game;
    if (game == null) {
      image.dispose();
      return;
    }
    game.reflect(image);
  }

  static bool _arrived(SceneState state) => state is Beach && state.hasArrived;
}
