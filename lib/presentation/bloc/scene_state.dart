part of 'scene_bloc.dart';

sealed class SceneState {
  const SceneState();

  /// Whether the curtain is still down.
  bool get isLoading => this is Loading;
}

class Loading extends SceneState {
  const Loading({this.progress = LoadingProgress.empty});

  final LoadingProgress progress;
}

/// The beach, with the screen to itself.
class Beach extends SceneState {
  const Beach({this.hasArrived = false});

  /// Whether the reveal has finished.
  ///
  /// The title and the cards wait on this rather than on the state alone: the
  /// curtain takes time to open, and a card that lands behind it has landed
  /// where nobody saw it.
  final bool hasArrived;
}
