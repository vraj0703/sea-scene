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
import 'package:sea_scene/presentation/bloc/scene_bloc.dart';
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

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<SceneBloc>();
    final audio = context.audio;
    final title = context.strings.title;

    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        // Built once and kept. Rebuilding a `GameWidget` tears the loop down
        // and starts it again, which for a scene whose every wave is a
        // function of elapsed time means the sea jumps back to flat.
        GameWidget.controlled(
          gameFactory: () =>
              BeachGame(queuer: bloc, audio: audio, title: title),
        ),

        BlocBuilder<SceneBloc, SceneState>(
          builder: (context, state) {
            final isLoading = state.isLoading;

            return TweenAnimationBuilder<double>(
              // 0 = closed, 1 = fully open. On the first build the tween has
              // no `begin`, so it settles on 0 without animating — the scene
              // starts covered, which is what we want.
              tween: Tween<double>(end: isLoading ? 0.0 : 1.0),
              duration: reveal,
              curve: Curves.easeInOut,
              onEnd: () {
                if (!isLoading) bloc.queue(event: const RevealCompleted());
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

        // Over the sea and over the curtain's own space, but only once there
        // is something to stand on.
        BlocBuilder<SceneBloc, SceneState>(
          buildWhen: (previous, current) =>
              _arrived(previous) != _arrived(current),
          builder: (context, state) =>
              BeachCardsLayer(arrived: _arrived(state)),
        ),
      ],
    );
  }

  static bool _arrived(SceneState state) => state is Beach && state.hasArrived;
}
