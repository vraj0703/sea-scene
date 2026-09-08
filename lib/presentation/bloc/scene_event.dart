part of 'scene_bloc.dart';

sealed class SceneEvent {
  const SceneEvent();
}

/// A subsystem reporting how far along it is.
class LoadingProgressed extends SceneEvent {
  const LoadingProgressed({required this.phase, required this.value});

  final LoadingPhase phase;
  final double value;
}

/// The visitor has asked to come in.
class EntryRequested extends SceneEvent {
  const EntryRequested();
}

/// The curtain is fully open and the beach has the screen.
///
/// Its own event rather than a timer, because what follows it — the title
/// rising, then the cards landing — has to begin when the scene is actually
/// visible, not when something guessed it would be.
class RevealCompleted extends SceneEvent {
  const RevealCompleted();
}
