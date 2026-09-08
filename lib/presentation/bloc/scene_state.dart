part of 'scene_bloc.dart';

sealed class SceneState {
  const SceneState();

  /// Whether the curtain is still down.
  ///
  /// True for [Ready] as well as [Loading]: the bar being full is not the
  /// same as the visitor being in. The sea is behind a closed curtain in both
  /// stages, and everything that draws the curtain should treat them alike.
  bool get isCovered => this is Loading || this is Ready;
}

class Loading extends SceneState {
  const Loading({this.progress = LoadingProgress.empty});

  final LoadingProgress progress;
}

/// Everything is loaded, and the scene is waiting to be let in.
///
/// Its own stage rather than a flag on [Loading], because it is a different
/// thing: loading is something happening *to* the visitor, and this is a
/// question being asked of them. The curtain opening on its own the instant
/// the last byte arrived gave the sea away before anyone had chosen to look
/// — and on the web it also meant the first sound of the scene fired before
/// any gesture, which a browser will not play.
class Ready extends SceneState {
  const Ready();
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
