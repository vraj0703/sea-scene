import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sea_scene/domain/interfaces/queuer.dart';
import 'package:sea_scene/domain/models/loading_phase.dart';
import 'package:sea_scene/domain/models/loading_progress.dart';

part 'scene_event.dart';
part 'scene_state.dart';

/// Owns the scene's lifecycle: loading, then the beach.
///
/// The same shape as the portfolio's, minus the stages it does not have.
/// Sealed states rather than generated ones — Dart 3 gives the exhaustiveness
/// `freezed` was there for, and one project should not need a code generator
/// to hold two states.
///
/// The UI is a pure function of this. Loading subsystems push progress in
/// through [Queuer] without knowing what else is loading or how the bar is
/// weighted.
class SceneBloc extends Bloc<SceneEvent, SceneState> implements Queuer {
  SceneBloc() : super(const Loading()) {
    on<LoadingProgressed>(_onLoadingProgressed);
    on<RevealCompleted>(_onRevealCompleted);
  }

  @override
  void queue({required SceneEvent event}) => add(event);

  FutureOr<void> _onLoadingProgressed(
    LoadingProgressed event,
    Emitter<SceneState> emit,
  ) {
    final current = state;

    // A report arriving after the curtain has lifted is a straggler from a
    // subsystem that finished behind the reveal. Harmless; dropped rather
    // than yanking the scene back to the loading screen.
    if (current is! Loading) return null;

    final next = current.progress.advance(event.phase, event.value);

    // `advance` hands back the same instance when a report does not move the
    // phase forward, so this skips a rebuild for redundant reports.
    if (identical(next, current.progress)) return null;

    emit(Loading(progress: next));

    if (next.isComplete) emit(const Beach());
  }

  FutureOr<void> _onRevealCompleted(
    RevealCompleted event,
    Emitter<SceneState> emit,
  ) {
    if (state is! Beach) return null;
    emit(const Beach(hasArrived: true));
  }
}
