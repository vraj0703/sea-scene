import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:sea_scene/domain/audio/app_audio.dart';
import 'package:sea_scene/domain/beach/beach_cards.dart';
import 'package:sea_scene/domain/style/colors.dart';
import 'package:sea_scene/domain/style/text_styles.dart';
import 'package:url_launcher/url_launcher.dart';

/// The four cards, washed up in order.
///
/// Flutter widgets over the Flame scene rather than components inside it —
/// the same split the portfolio uses for its contact menu. What is *drawn by a
/// shader* belongs in the game; what is read, hovered and pressed belongs in
/// the widget tree, where it gets hit-testing, semantics and text layout for
/// nothing.
class BeachCardsLayer extends StatelessWidget {
  const BeachCardsLayer({required this.arrived, super.key});

  /// Whether the curtain has finished opening.
  ///
  /// The cards wait on this rather than on the stage alone: the reveal takes
  /// time, and a card that lands behind the curtain has landed where nobody
  /// saw it.
  final bool arrived;

  /// How long each card waits behind the one before it.
  ///
  /// They land as a rising scale, and a scale is an interval as much as it is
  /// notes — four cards arriving together would play as one chord.
  static const Duration stagger = Duration(milliseconds: 260);

  /// How long one card takes to settle.
  static const Duration settle = Duration(milliseconds: 700);

  /// The notes, in the order the cards land.
  static const List<AudioCue> notes = <AudioCue>[
    AudioCue.cardOne,
    AudioCue.cardTwo,
    AudioCue.cardThree,
    AudioCue.cardFour,
  ];

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 48, left: 24, right: 24),
        child: Wrap(
          alignment: WrapAlignment.center,
          spacing: 18,
          runSpacing: 18,
          children: <Widget>[
            for (var i = 0; i < BeachCards.all.length; i++)
              _Card(
                card: BeachCards.all[i],
                note: notes[i],
                delay: stagger * i,
                arrived: arrived,
              ),
          ],
        ),
      ),
    );
  }
}

/// Stateful for the two things that outlive a frame: whether it has landed,
/// and whether it is turned over.
class _Card extends StatefulWidget {
  const _Card({
    required this.card,
    required this.note,
    required this.delay,
    required this.arrived,
  });

  final BeachCard card;
  final AudioCue note;
  final Duration delay;
  final bool arrived;

  @override
  State<_Card> createState() => _CardState();
}

class _CardState extends State<_Card> with SingleTickerProviderStateMixin {
  /// How far the card has turned, `0` face-up to `1` face-down.
  late final AnimationController _flip = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  )..addStatusListener(_onFlipSettled);

  bool _landed = false;
  bool _sounded = false;

  /// Whether the flip's sound has been played for the crossing in progress.
  ///
  /// The cue belongs at the *halfway* point, where the card is edge-on and
  /// there is nothing to look at — that is the moment the sound covers. Fired
  /// at the start it lands under a card that has not moved yet.
  bool _whooshed = false;

  @override
  void initState() {
    super.initState();
    _flip.addListener(_watchForHalfway);
    _land();
  }

  @override
  void didUpdateWidget(_Card old) {
    super.didUpdateWidget(old);
    if (widget.arrived && !old.arrived) _land();
  }

  @override
  void dispose() {
    _flip.dispose();
    super.dispose();
  }

  /// Brings the card in after its turn in the queue.
  ///
  /// Guarded, because the widget rebuilds for reasons that have nothing to do
  /// with arriving — a second landing would replay the note over a card
  /// already sitting on the sand.
  void _land() {
    if (_landed || !widget.arrived) return;
    _landed = true;

    Future<void>.delayed(widget.delay, () {
      if (!mounted || _sounded) return;
      _sounded = true;
      context.audio.play(widget.note);
      setState(() {});
    });
  }

  void _watchForHalfway() {
    final past = _flip.value >= 0.5;
    if (past == _whooshed) return;

    _whooshed = past;
    context.audio.play(AudioCue.flip);
  }

  void _onFlipSettled(AnimationStatus status) {
    // Re-armed at either end, so the next crossing sounds whichever way it
    // goes. Without this a card turned back over is silent.
    if (status == AnimationStatus.dismissed) _whooshed = false;
  }

  Future<void> _follow() async {
    final url = widget.card.url;

    // The resume has nowhere to go yet, and a card that does nothing when
    // pressed should not sound as though it did.
    if (url == null) return;

    context.audio.play(AudioCue.follow);
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final shown = _sounded;

    return MouseRegion(
      onEnter: (_) => _flip.forward(),
      onExit: (_) => _flip.reverse(),
      child: GestureDetector(
        onTap: () {
          // On a touch screen there is no hover, so a press has to do both
          // jobs: turn the card over, and follow it once it is over.
          if (_flip.value < 0.5) {
            _flip.forward();
            return;
          }
          _follow();
        },
        child: AnimatedSlide(
          // Rises out of the water rather than fading in place.
          offset: shown ? Offset.zero : const Offset(0, 0.35),
          duration: BeachCardsLayer.settle,
          curve: Curves.easeOutCubic,
          child: AnimatedOpacity(
            opacity: shown ? 1 : 0,
            duration: BeachCardsLayer.settle,
            child: AnimatedBuilder(
              animation: _flip,
              builder: (context, _) => _Face(card: widget.card, turn: _flip.value),
            ),
          ),
        ),
      ),
    );
  }
}

/// One side of a card, and the turn between them.
class _Face extends StatelessWidget {
  const _Face({required this.card, required this.turn});

  final BeachCard card;

  /// `0` face-up, `1` face-down.
  final double turn;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.typography;
    final showsBack = turn > 0.5;

    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()
        // A little perspective, or the turn is a horizontal squash rather
        // than a card standing on its edge.
        ..setEntry(3, 2, 0.0012)
        ..rotateY(turn * math.pi),
      child: Container(
        width: 240,
        height: 168,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: colors.cardGround.withValues(alpha: 0.82),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: card.accent.withValues(alpha: 0.55)),
        ),
        child: Transform(
          alignment: Alignment.center,
          // The back is drawn on a face already turned away, so without this
          // its text reads mirrored.
          transform: Matrix4.identity()..rotateY(showsBack ? math.pi : 0),
          child: showsBack
              ? _Back(card: card, type: type, colors: colors)
              : _Front(card: card, type: type, colors: colors),
        ),
      ),
    );
  }
}

class _Front extends StatelessWidget {
  const _Front({required this.card, required this.type, required this.colors});

  final BeachCard card;
  final AppTypography type;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Text(card.icon, style: const TextStyle(fontSize: 34)),
        const SizedBox(height: 12),
        Text(
          card.title,
          style: type.cardTitle.copyWith(color: colors.cardInk),
        ),
      ],
    );
  }
}

class _Back extends StatelessWidget {
  const _Back({required this.card, required this.type, required this.colors});

  final BeachCard card;
  final AppTypography type;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Expanded(
          child: Text(
            card.description,
            style: type.cardBody.copyWith(color: colors.cardInkSoft),
          ),
        ),
        Text(
          // A card with nowhere to go says so, rather than offering something
          // that will not happen.
          card.leadsSomewhere ? card.action : 'Coming soon',
          style: type.cardAction.copyWith(
            color: card.leadsSomewhere ? card.accent : colors.cardInkSoft,
          ),
        ),
      ],
    );
  }
}
