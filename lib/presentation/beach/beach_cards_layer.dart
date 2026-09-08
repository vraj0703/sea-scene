import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:sea_scene/domain/audio/app_audio.dart';
import 'package:sea_scene/domain/beach/beach_cards.dart';
import 'package:sea_scene/domain/beach/entry_sequence.dart';
import 'package:sea_scene/domain/style/text_styles.dart';
import 'package:url_launcher/url_launcher.dart';

/// The four cards, standing in the water.
///
/// Laid out as the previous site laid them: a hallway rather than a row. The
/// outer pair sit wide and turned in, the inner pair closer and barely turned,
/// so the four make a corridor the eye walks down toward the ship instead of a
/// strip across the bottom of the screen.
///
/// They are glass, not panels — a six-per-cent white fill under a ten-per-cent
/// border. That is the whole of the design, and it only works because the sea
/// is moving behind it: a card opaque enough to read comfortably would be a
/// card the beach has to be looked at around.
class BeachCardsLayer extends StatelessWidget {
  const BeachCardsLayer({
    required this.arrived,
    required this.onStruck,
    super.key,
  });

  /// Whether the curtain has finished opening.
  ///
  /// The cards wait on this rather than on the stage alone: the reveal takes
  /// time, and a card that lands behind the curtain has landed where nobody
  /// saw it.
  final bool arrived;

  /// Answers a press with weather.
  final VoidCallback onStruck;

  /// Where each card stands, how far it is turned, and how far back it is.
  ///
  /// `across` is a share of the screen's width from the middle and `turn` is
  /// in radians, both carried over from the previous site. `back` is this
  /// version's stand-in for the z it cannot use: the old cards were placed in
  /// a 3D hallway with the inner pair pushed 280 units away, and the flat
  /// arrangement without it simply overlapped — four cards at one distance,
  /// leaning, colliding at the shoulders.
  ///
  /// Distance is drawn here rather than projected: the further pair are
  /// smaller and stand a little higher, which is what depth looks like from a
  /// fixed viewpoint.
  static const List<({double across, double turn, double back})> stand =
      <({double across, double turn, double back})>[
        (across: -0.38, turn: 0.4, back: 0),
        (across: -0.18, turn: 0.2, back: 1),
        (across: 0.18, turn: -0.2, back: 1),
        (across: 0.38, turn: -0.4, back: 0),
      ];

  /// How far back a card one step away stands, and how high that puts it.
  ///
  /// The previous site pushed the inner pair 280 units into the scene and let
  /// the projection do the rest. This does the same thing rather than faking
  /// it with a smaller box: the card is translated in z under a perspective
  /// matrix, so it foreshortens the way the outer pair do when *they* turn —
  /// a scaled-down card is a small card, not a distant one.
  static const double backZ = 280;
  static const double backLift = 0.16;

  /// How strong the projection is. The reciprocal of the distance from the
  /// eye to the screen, which is the only number a perspective matrix needs.
  static const double perspective = 0.0012;

  /// Where the group stands, as an `Alignment` y.
  ///
  /// Four tenths down the screen, which is the previous site's own placement
  /// and — with the waterline at six tenths — puts the whole group above the
  /// water where it can be reflected.
  static const double standY = -0.2;

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    final width = (screen.width * 0.20).clamp(180.0, 250.0);
    final height = screen.height * 0.40;

    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        for (var i = 0; i < BeachCards.all.length; i++)
          Align(
            // Placed by fraction rather than by pixel offset, so the hallway
            // holds its shape as the window changes.
            // Standing on the beach, above the waterline. The shader only
            // reflects what is above it, so a card any lower is a card the
            // water cannot see.
            alignment: Alignment(
              stand[i].across * 2,
              standY - stand[i].back * backLift,
            ),
            child: SizedBox(
              width: width,
              height: height,
              child: _Card(
                card: BeachCards.all[i],
                // The cards are the back half of the scale — the mark and the
                // name ring first.
                note: EntrySequence.noteFor(EntrySequence.firstCard + i),
                delay: EntrySequence.delayFor(EntrySequence.firstCard + i),
                arrived: arrived,
                onStruck: onStruck,
                turn: stand[i].turn,
                back: stand[i].back,
                // The two on the left carry their icon in the far corner and
                // their name in the near one; the two on the right mirror it,
                // so the group reads outward from the middle.
                mirrored: i >= 2,
              ),
            ),
          ),
      ],
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
    required this.onStruck,
    required this.turn,
    required this.back,
    required this.mirrored,
  });

  final BeachCard card;
  final AudioCue note;
  final Duration delay;
  final bool arrived;
  final VoidCallback onStruck;

  /// How far the card is turned, and how far back it stands.
  final double turn;
  final double back;

  final bool mirrored;

  @override
  State<_Card> createState() => _CardState();
}

class _CardState extends State<_Card> with SingleTickerProviderStateMixin {
  late final AnimationController _flip = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  );

  bool _landed = false;
  bool _sounded = false;

  @override
  void initState() {
    super.initState();
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
  /// already standing in the water.
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

  /// Sounds the card's own note again.
  ///
  /// The same note it arrived on, and nothing else. A card had a separate
  /// whoosh for the flip, which meant hovering across the row played two
  /// unrelated sounds at once — the scale it belongs to, and a wind noise
  /// that belongs to nothing. The row is an instrument; touching a key should
  /// sound that key.
  void _ring() => context.audio.play(widget.note);

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

  void _press() {
    // On a touch screen there is no hover, so a press has to do both jobs:
    // turn the card over — with the same answer from the sky a hover gets —
    // and follow it once it is over.
    if (_flip.value < 0.5) {
      _ring();
      widget.onStruck();
      _flip.forward();
      return;
    }
    _follow();
  }

  @override
  Widget build(BuildContext context) {
    final shown = _sounded;

    // The hit region sits *outside* the perspective transform, deliberately.
    //
    // A matrix with a perspective row is not affine, and Flutter cannot
    // reliably invert one to work out where a pointer landed — so a
    // `MouseRegion` underneath it never sees an enter, and the hover did
    // nothing at all. The previous site hit exactly this and gave up on the
    // framework's routing, hand-rolling its own hit test against the cards.
    //
    // This keeps the framework's routing and moves the geometry instead: the
    // region is the card's untransformed rectangle, and only what is drawn
    // inside it leans away.
    return MouseRegion(
      // Hovering *is* the interaction on a pointer: the card turns over, the
      // note sounds, the flock scatters and the sky answers. The previous
      // site fired all four here and left the press for following the link.
      onEnter: (_) {
        _flip.forward();
        _ring();
        widget.onStruck();
      },
      onExit: (_) => _flip.reverse(),
      child: GestureDetector(
        onTap: _press,
        child: Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, BeachCardsLayer.perspective)
            // Pushed away first, then turned, so the turn happens at the
            // distance the card actually stands at.
            ..translateByDouble(0, 0, widget.back * BeachCardsLayer.backZ, 1)
            ..rotateY(widget.turn),
          child: AnimatedSlide(
            // Rises out of the water rather than fading in place.
            offset: shown ? Offset.zero : const Offset(0, 0.35),
            duration: EntrySequence.settle,
            curve: Curves.easeOutCubic,
            child: AnimatedOpacity(
              opacity: shown ? 1 : 0,
              duration: EntrySequence.settle,
              child: AnimatedBuilder(
                animation: _flip,
                builder: (context, _) => _Face(
                  card: widget.card,
                  turn: _flip.value,
                  mirrored: widget.mirrored,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One side of a card, and the turn between them.
class _Face extends StatelessWidget {
  const _Face({required this.card, required this.turn, required this.mirrored});

  final BeachCard card;

  /// `0` face-up, `1` face-down.
  final double turn;

  final bool mirrored;

  /// The glass, exactly as the previous site mixed it.
  ///
  /// Six per cent white under a ten per cent border. It looks impossibly faint
  /// written down and is right on a moving sea — the card is a pane held up to
  /// the weather, and most of what makes it legible is the border catching the
  /// light rather than the fill.
  static const double fill = 0.06;
  static const double edge = 0.1;

  @override
  Widget build(BuildContext context) {
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
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: fill),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.white.withValues(alpha: edge)),
        ),
        child: Transform(
          alignment: Alignment.center,
          // The back is drawn on a face already turned away, so without this
          // its text reads mirrored.
          transform: Matrix4.identity()..rotateY(showsBack ? math.pi : 0),
          child: showsBack
              ? _Back(card: card, type: type)
              : _Front(card: card, type: type, mirrored: mirrored),
        ),
      ),
    );
  }
}

class _Front extends StatelessWidget {
  const _Front({
    required this.card,
    required this.type,
    required this.mirrored,
  });

  final BeachCard card;
  final AppTypography type;
  final bool mirrored;

  @override
  Widget build(BuildContext context) {
    // Icon in the far corner, name in the near one — mirrored on the right of
    // the hallway, so the group reads outward from the middle rather than all
    // leaning the same way.
    final corner = mirrored ? CrossAxisAlignment.start : CrossAxisAlignment.end;

    return Column(
      crossAxisAlignment: corner,
      children: <Widget>[
        Image.asset(card.icon, height: 56, filterQuality: FilterQuality.medium),
        const Spacer(),
        Text(
          card.title,
          textAlign: mirrored ? TextAlign.left : TextAlign.right,
          style: type.cardTitle.copyWith(color: Colors.white),
        ),
      ],
    );
  }
}

class _Back extends StatelessWidget {
  const _Back({required this.card, required this.type});

  final BeachCard card;
  final AppTypography type;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Expanded(
          child: Center(
            child: Text(
              card.description,
              textAlign: TextAlign.center,
              style: type.cardBody.copyWith(
                color: Colors.white.withValues(alpha: 0.82),
              ),
            ),
          ),
        ),
        Text(
          // A card with nowhere to go says so, rather than offering something
          // that will not happen.
          card.leadsSomewhere ? card.action : 'Coming soon',
          textAlign: TextAlign.center,
          style: type.cardAction.copyWith(
            color: card.leadsSomewhere
                ? card.accent
                : Colors.white.withValues(alpha: 0.5),
          ),
        ),
      ],
    );
  }
}
