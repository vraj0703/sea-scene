import 'package:sea_scene/domain/audio/app_audio.dart';

/// The order the scene assembles itself in, and the note each part sounds.
///
/// Six things arrive — the mark, the name, then the four cards — and they
/// arrive one after another rather than together, because the sequence is
/// meant to be *heard* as a scale. Four cards landing at once would play as a
/// chord, and a chord says nothing about order.
///
/// Kept here rather than in the widgets that ring, so the whole tune can be
/// read in one place. Each part looks up its own place in it.
abstract final class EntrySequence {
  /// Everything that arrives, in order.
  static const List<AudioCue> notes = <AudioCue>[
    AudioCue.mark,
    AudioCue.title,
    AudioCue.cardOne,
    AudioCue.cardTwo,
    AudioCue.cardThree,
    AudioCue.cardFour,
  ];

  /// How long each waits behind the one before it.
  ///
  /// Long enough to be told apart, short enough that the last card is not
  /// still arriving after the visitor has started reading the first.
  static const Duration stagger = Duration(milliseconds: 280);

  /// How long one part takes to settle once its turn comes.
  static const Duration settle = Duration(milliseconds: 700);

  /// When the part at [index] arrives, measured from the curtain opening.
  static Duration delayFor(int index) => stagger * index;

  /// What the part at [index] sounds.
  static AudioCue noteFor(int index) => notes[index];

  /// Where the cards start in the sequence — after the mark and the name.
  static const int firstCard = 2;
}
