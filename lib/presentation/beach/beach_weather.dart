import 'dart:math' as math;
import 'dart:ui';

import 'package:sea_scene/domain/beach/beach_config.dart';

/// How bright the last strike still is.
///
/// A flash is instant and the *decay* is what makes it a flash rather than a
/// light being switched on, so this holds a value that only ever falls on its
/// own and is pushed back up from outside.
///
/// Pure, and deliberately not a component: what a storm does over time is a
/// rule, and a rule that needs a render loop to be exercised cannot be tested
/// without one. The previous site had this inside a Flame component with a
/// game reference, and its behaviour could only be checked by looking at it.
class Lightning {
  double _intensity = 0;

  /// The last flash, `0`..`1`.
  double get intensity => _intensity;

  DateTime _lastStrike = DateTime.fromMillisecondsSinceEpoch(0);
  int _inARow = 0;

  /// Fades the flash. Call once a frame.
  void update(double dt) {
    _intensity = (_intensity - dt * BeachConfig.lightningDecay).clamp(0.0, 1.0);
  }

  /// Whether a strike is allowed now, and how hard it lands if so.
  ///
  /// Returns null when the strike is refused. Throttling matters more than it
  /// looks: without it a run of high rolls produces a strobe rather than a
  /// storm, and the sound stacks on itself into noise.
  ///
  /// Strikes close together build on each other. A storm that arrives in
  /// bursts is a storm; one that fires at a constant strength is a lamp on a
  /// timer.
  double? strike({DateTime? at}) {
    final now = at ?? DateTime.now();
    final since = now.difference(_lastStrike);

    if (since < BeachConfig.strikeThrottle) return null;

    _inARow = since.inSeconds < 3 ? _inARow + 1 : 0;
    _lastStrike = now;
    _intensity = 1;

    return 1 + _inARow * 0.2;
  }

  /// How long the roll should lag this flash.
  ///
  /// Sound is slower than light, and that gap is the whole of how far away a
  /// storm reads as being — so it closes as the storm gathers. At full
  /// strength the roll is nearly on top of the flash.
  static Duration rollLag(double gathering) {
    final t = gathering.clamp(0.0, 1.0);
    return Duration(
      milliseconds: lerpDouble(
        BeachConfig.rollLagFar.inMilliseconds.toDouble(),
        BeachConfig.rollLagNear.inMilliseconds.toDouble(),
        t,
      )!.round(),
    );
  }
}

/// How startled the birds are.
///
/// Spikes the instant something frightens them and settles slowly afterwards,
/// which is the asymmetry that makes a flock read as alive: fear is immediate
/// and calm is gradual, never the other way round.
class Birds {
  double _panic = 0;

  double get panic => _panic;

  void update(double dt) {
    _panic = lerpDouble(_panic, 0, (dt * BeachConfig.panicDecay).clamp(0.0, 1.0))!;
  }

  /// Startles them, if this is worse than whatever already has.
  ///
  /// Never *reduces* the panic — a second, weaker flash does not calm a flock
  /// that is already up.
  void startle(double lightningIntensity) {
    final spike = (2 * lightningIntensity).clamp(0.0, 1.0);
    if (spike > _panic) _panic = spike;
  }
}

/// A ring spreading from wherever something struck the water.
///
/// Holds its own age rather than a start time, so it advances with the frame
/// clock and stops when the scene does — a wall clock would keep the ripple
/// running through a backgrounded tab and reappear finished.
class Ripple {
  Offset _origin = Offset.zero;

  /// Negative while there is nothing to draw. The shader reads it directly,
  /// and this is the sentinel it understands.
  double _age = -999;

  Offset get origin => _origin;
  double get age => _age;
  bool get isRunning => _age >= 0;

  void update(double dt) {
    if (_age < 0) return;
    _age += dt;
    if (_age > BeachConfig.rippleLife) _age = -999;
  }

  void strike(Offset where) {
    _origin = where;
    _age = 0;
  }
}

/// Whether an ambient strike is due.
///
/// The storm has to do something when nothing is driving it, or a visitor who
/// simply stands still is looking at a photograph. Its own class so the
/// interval can be checked without waiting out fifteen seconds of real time.
class AmbientStorm {
  AmbientStorm({math.Random? random}) : _random = random ?? math.Random();

  final math.Random _random;

  double _waited = 0;
  double _due = BeachConfig.ambientStrikeMin;

  /// Advances the clock and says whether the sky should flash.
  bool update(double dt) {
    _waited += dt;
    if (_waited < _due) return false;

    _waited = 0;
    _due =
        BeachConfig.ambientStrikeMin +
        _random.nextDouble() *
            (BeachConfig.ambientStrikeMax - BeachConfig.ambientStrikeMin);
    return true;
  }
}
