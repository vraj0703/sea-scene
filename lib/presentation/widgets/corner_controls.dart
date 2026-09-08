import 'package:flutter/material.dart';
import 'package:sea_scene/domain/audio/app_audio.dart';
import 'package:sea_scene/domain/beach/entry_sequence.dart';

/// How far the two corner pieces sit from their edges, and how large the mark
/// is drawn.
///
/// One set of numbers for both, because they are a pair holding the top of the
/// screen between them — a mark that sat at a different inset from the control
/// opposite would read as two unrelated things that happened to land near the
/// same corners.
abstract final class CornerLayout {
  static const double margin = 28;
  static const double mark = 34;

  /// Smallest square that can be pressed.
  ///
  /// What is drawn and what is pressed are allowed to differ; the target grows
  /// outward from the glyph so the drawing stays on the line the margin sets.
  static const double target = 48;
}

/// The mark, top left.
///
/// The same artwork the portfolio draws — pure black with the shape in its
/// alpha — so it has to be tinted to be seen at all against a dark sky. White
/// here rather than the portfolio's gold: this scene has its own light, and a
/// gold mark on a sunset reads as part of the sunset.
class CornerMark extends StatefulWidget {
  const CornerMark({required this.shown, super.key});

  /// Whether the scene has arrived. The mark opens the scale.
  final bool shown;

  static const String artwork = 'assets/images/logo.png';

  /// Its place in the sequence: first, before the name and the cards.
  static const int order = 0;

  @override
  State<CornerMark> createState() => _CornerMarkState();
}

/// Stateful for the same reason every other arrival is: the note has to sound
/// once, at its turn, and a build is not a place to make a noise.
class _CornerMarkState extends State<CornerMark> {
  bool _arriving = false;
  bool _here = false;

  @override
  void initState() {
    super.initState();
    _arrive();
  }

  @override
  void didUpdateWidget(CornerMark old) {
    super.didUpdateWidget(old);
    if (widget.shown && !old.shown) _arrive();
  }

  void _arrive() {
    if (_arriving || !widget.shown) return;
    _arriving = true;

    Future<void>.delayed(EntrySequence.delayFor(CornerMark.order), () {
      if (!mounted || _here) return;
      _here = true;
      context.audio.play(EntrySequence.noteFor(CornerMark.order));
      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: CornerLayout.margin,
      left: CornerLayout.margin,
      child: IgnorePointer(
        child: AnimatedOpacity(
          opacity: _here ? 0.9 : 0,
          duration: EntrySequence.settle,
          curve: Curves.easeOut,
          child: Image.asset(
            CornerMark.artwork,
            height: CornerLayout.mark,
            color: Colors.white,
            filterQuality: FilterQuality.medium,
          ),
        ),
      ),
    );
  }
}

/// The sound switch, top right.
///
/// Stateful for one reason, and it is the reason the rule allows: muting is a
/// fact about the audio backend rather than about this widget, and something
/// has to ask it again after the press. Nothing else here outlives a frame.
class SoundSwitch extends StatefulWidget {
  const SoundSwitch({super.key});

  @override
  State<SoundSwitch> createState() => _SoundSwitchState();
}

class _SoundSwitchState extends State<SoundSwitch> {
  void _toggle() {
    final audio = context.audio;
    final silencing = !audio.isMuted;

    // The confirmation plays *before* the silence, and not at all on the way
    // back — a click swallowed by the thing it is confirming leaves the press
    // feeling unregistered.
    if (!silencing) audio.play(AudioCue.drop);

    audio.setMuted(silencing);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final muted = context.audio.isMuted;

    return Positioned(
      top: CornerLayout.margin,
      right: CornerLayout.margin,
      child: Semantics(
        button: true,
        // Says what pressing it will do, not what the switch currently is: a
        // control labelled with its own state reads as a description until
        // somebody presses it to find out.
        label: muted ? 'Turn sound on' : 'Turn sound off',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _toggle,
          child: SizedBox(
            width: CornerLayout.target,
            height: CornerLayout.target,
            child: Center(
              child: Icon(
                // The mark shows the outcome too, so the picture and the
                // label cannot contradict each other.
                muted ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                size: CornerLayout.mark - 6,
                color: Colors.white.withValues(alpha: muted ? 0.55 : 0.9),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
