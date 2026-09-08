import 'package:flutter/foundation.dart';

import 'loading_phase.dart';

/// Immutable snapshot of how far each [LoadingPhase] has got.
///
/// Lives in the scene state, so it must be a value: two snapshots reporting
/// the same figures compare equal, which is what stops the bloc emitting
/// states that would rebuild the UI for no visible change.
///
/// Two properties are deliberate:
///
///  * **Normalised.** [value] divides by the total weight of all phases, so
///    weights never have to sum to 1 and a new phase can be added without
///    touching the existing ones.
///  * **Monotonic.** [advance] ignores a report below a phase's high-water
///    mark. A bar that retreats reads as a bug, and out-of-order reports from
///    concurrent loaders are otherwise easy to produce.
@immutable
class LoadingProgress {
  const LoadingProgress([
    Map<LoadingPhase, double> reported = const <LoadingPhase, double>{},
  ]) : _reported = reported;

  /// Nothing reported yet. Const, so it can be a freezed `@Default`.
  static const LoadingProgress empty = LoadingProgress();

  /// Every phase done.
  ///
  /// Used while the reveal plays: the scene has already left `loading`, but
  /// the curtain is still fading and its bar should read 100% rather than
  /// snapping back to nothing.
  static final LoadingProgress complete = LoadingProgress(
    <LoadingPhase, double>{for (final phase in LoadingPhase.values) phase: 1.0},
  );

  final Map<LoadingPhase, double> _reported;

  /// Total weight across every declared phase. Never zero — the enum always
  /// has at least one member — but guarded anyway so a future refactor that
  /// empties it degrades to "already done" rather than dividing by zero.
  static double get _totalWeight =>
      LoadingPhase.values.fold<double>(0, (sum, p) => sum + p.weight);

  /// How far [phase] has reported, in `0..1`.
  double of(LoadingPhase phase) => _reported[phase] ?? 0;

  /// Weighted, normalised progress across all phases, in `0..1`.
  double get value {
    final total = _totalWeight;
    if (total <= 0) return 1;

    var done = 0.0;
    for (final phase in LoadingPhase.values) {
      done += of(phase) * phase.weight;
    }
    return (done / total).clamp(0.0, 1.0);
  }

  /// True only when every declared phase has fully reported.
  ///
  /// Checked per phase rather than against [value], so floating-point drift
  /// in the weighted sum can never gate the transition out of loading.
  bool get isComplete =>
      LoadingPhase.values.every((phase) => of(phase) >= 1.0);

  /// Returns a snapshot with [phase] moved to [value], clamped to `0..1`.
  ///
  /// Returns `this` unchanged when the report would not advance the phase,
  /// so callers can cheaply skip a redundant emit.
  LoadingProgress advance(LoadingPhase phase, double value) {
    final clamped = value.clamp(0.0, 1.0);
    if (clamped <= of(phase)) return this;

    return LoadingProgress(<LoadingPhase, double>{
      ..._reported,
      phase: clamped,
    });
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LoadingProgress &&
          mapEquals(_reported, other._reported);

  @override
  int get hashCode => Object.hashAllUnordered(
    _reported.entries.map((e) => Object.hash(e.key, e.value)),
  );

  @override
  String toString() =>
      'LoadingProgress(${(value * 100).toStringAsFixed(0)}%, $_reported)';
}
