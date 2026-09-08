import 'dart:math' as math;


import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sea_scene/data/audio/flame_app_audio.dart';
import 'package:sea_scene/domain/beach/beach_cards.dart';
import 'package:sea_scene/presentation/beach/beach_cards_layer.dart';
import 'package:sea_scene/domain/audio/app_audio.dart';
import 'package:sea_scene/domain/beach/beach_config.dart';
import 'package:sea_scene/domain/beach/entry_sequence.dart';
import 'package:sea_scene/presentation/beach/beach_weather.dart';
import 'package:sea_scene/presentation/beach/reflection_capture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('what the water mirrors', () {
    test('is captured small, and not every frame', () {
      // Both numbers are load-bearing and both were in the previous site.
      // Water is blurry and slow, so a reflection that lags by half a second
      // is indistinguishable from one that does not — and a full-resolution
      // readback every frame is a screen-sized copy sixty times a second for
      // a picture the shader is about to tear apart anyway.
      expect(ReflectionCapture.scale, lessThan(1));
      expect(ReflectionCapture.scale, greaterThan(0));
      expect(
        ReflectionCapture.interval,
        greaterThanOrEqualTo(const Duration(milliseconds: 250)),
      );
    });
  });

  group('the scene arrives as a scale', () {
    test('six things, in order, each with its own note', () {
      // The mark, the name, then the four cards. Six arrivals and six notes,
      // and the order is the point — four cards landing together would play
      // as a chord, and a chord says nothing about sequence.
      expect(EntrySequence.notes, hasLength(6));
      expect(EntrySequence.notes.first, AudioCue.mark);
      expect(EntrySequence.notes[1], AudioCue.title);
      expect(
        EntrySequence.notes.toSet(),
        hasLength(6),
        reason: 'two arrivals share a note, so the scale repeats itself',
      );
    });

    test('and the cards come after the mark and the name', () {
      expect(EntrySequence.firstCard, 2);
      expect(
        EntrySequence.notes.sublist(EntrySequence.firstCard),
        <AudioCue>[
          AudioCue.cardOne,
          AudioCue.cardTwo,
          AudioCue.cardThree,
          AudioCue.cardFour,
        ],
      );
    });

    test('each waiting behind the one before it', () {
      // Nothing arrives at the same moment as anything else, or the scale is
      // a chord.
      final delays = <Duration>[
        for (var i = 0; i < EntrySequence.notes.length; i++)
          EntrySequence.delayFor(i),
      ];

      expect(delays.first, Duration.zero);
      for (var i = 1; i < delays.length; i++) {
        expect(delays[i], greaterThan(delays[i - 1]));
      }
    });
  });

  group('the horizon is a place, not a proportion', () {
    test('and the cards stand above it, or nothing is reflected', () {
      // The shader mirrors what is *above* the waterline and nothing else, so
      // where the cards stand is not a composition choice — it decides
      // whether they have a reflection at all. They were below it, and the
      // water had nothing over it to show.
      //
      // `Alignment` y runs -1 at the top to 1 at the bottom; the horizon is a
      // fraction of the height. Converted to the same scale, the group has to
      // sit above it.
      final cardsAt = (BeachCardsLayer.standY + 1) / 2;
      expect(
        cardsAt,
        lessThan(BeachConfig.horizonFraction),
        reason: 'the cards are standing in the sea',
      );

      // And clear of it, not touching: the bottom of a card at the waterline
      // reflects into itself.
      expect(BeachConfig.horizonFraction - cardsAt, greaterThan(0.05));
    });

    test('it is given to the shader in pixels', () {
      // `beach.frag` compares a fragment's own y against `uWaterY` and then
      // divides by it. Handed a fraction it reads every pixel as infinitely
      // deep, clamps, and reflects nothing at all — the sea looks right and
      // mirrors nothing, which is exactly the bug this rule prevents.
      expect(BeachConfig.horizonFor(720), 720 * BeachConfig.horizonFraction);
      expect(BeachConfig.horizonFor(720), greaterThan(1));
    });
  });

  group('the storm behaves like weather', () {
    test('a strike is refused if the last one was too recent', () {
      // Without this a run of high rolls produces a strobe rather than a
      // storm, and the sound stacks on itself into noise.
      final lightning = Lightning();
      final at = DateTime(2026);

      expect(lightning.strike(at: at), isNotNull);
      expect(
        lightning.strike(at: at.add(const Duration(milliseconds: 100))),
        isNull,
      );
      expect(
        lightning.strike(at: at.add(const Duration(seconds: 1))),
        isNotNull,
      );
    });

    test('and strikes close together build on each other', () {
      // A storm that arrives in bursts is a storm; one that fires at a
      // constant strength is a lamp on a timer.
      final lightning = Lightning();
      var at = DateTime(2026);

      final first = lightning.strike(at: at)!;
      at = at.add(const Duration(seconds: 1));
      final second = lightning.strike(at: at)!;

      expect(second, greaterThan(first));
    });

    test('a flash fades rather than being switched off', () {
      final lightning = Lightning();
      lightning.strike();
      expect(lightning.intensity, 1);

      lightning.update(0.2);
      expect(lightning.intensity, lessThan(1));
      expect(lightning.intensity, greaterThan(0));

      lightning.update(5);
      expect(lightning.intensity, 0);
    });

    test('and the roll closes on the flash as the storm gathers', () {
      // The gap between the two *is* how far away the storm reads as being.
      expect(
        Lightning.rollLag(1),
        lessThan(Lightning.rollLag(0)),
      );
      expect(Lightning.rollLag(0), BeachConfig.rollLagFar);
      expect(Lightning.rollLag(1), BeachConfig.rollLagNear);
    });
  });

  group('the flock', () {
    test('is startled at once and settles slowly', () {
      // The asymmetry is what makes a flock read as alive: fear is immediate
      // and calm is gradual, never the other way round.
      final birds = Birds();
      birds.startle(0.5);

      final spiked = birds.panic;
      expect(spiked, greaterThan(0));

      birds.update(0.1);
      expect(birds.panic, lessThan(spiked));
      expect(birds.panic, greaterThan(0));
    });

    test('and a weaker fright does not calm them', () {
      final birds = Birds();
      birds.startle(1);
      final high = birds.panic;

      birds.startle(0.1);
      expect(birds.panic, high);
    });
  });

  group('the water remembers being struck', () {
    test('a ripple runs and then stops', () {
      final ripple = Ripple();
      expect(ripple.isRunning, isFalse);

      ripple.strike(const Offset(100, 200));
      expect(ripple.isRunning, isTrue);
      expect(ripple.origin, const Offset(100, 200));

      ripple.update(BeachConfig.rippleLife + 0.1);
      expect(
        ripple.isRunning,
        isFalse,
        reason: 'the water never went still again',
      );
    });

    test('and reports its absence the way the shader expects', () {
      // `beach.frag` tests `uRippleTime >= 0.0`, so "no ripple" has to be a
      // negative age rather than zero — zero is a ripple that has just begun.
      expect(Ripple().age, lessThan(0));
    });
  });

  group('the sky flashes on its own', () {
    test('within the interval it advertises', () {
      final storm = AmbientStorm(random: math.Random(7));

      var waited = 0.0;
      while (!storm.update(1 / 60)) {
        waited += 1 / 60;
        expect(
          waited,
          lessThan(BeachConfig.ambientStrikeMax + 1),
          reason: 'the sky went quiet for longer than it promises to',
        );
      }

      expect(waited, greaterThan(BeachConfig.ambientStrikeMin - 1));
    });
  });

  group('the hallway has depth', () {
    test('the inner pair stand back, the outer pair stand near', () {
      // Not a smaller box — a translation in z under a perspective matrix, so
      // the far pair foreshorten rather than merely shrink. Flattened, the
      // four collided at the shoulders.
      final stand = BeachCardsLayer.stand;
      expect(stand, hasLength(4));
      expect(stand.first.back, 0);
      expect(stand[1].back, greaterThan(0));
      expect(stand[2].back, greaterThan(0));
      expect(stand.last.back, 0);
      expect(BeachCardsLayer.perspective, greaterThan(0));
    });

    test('and they lean in from both sides', () {
      final stand = BeachCardsLayer.stand;
      expect(stand.first.across, lessThan(0));
      expect(stand.last.across, greaterThan(0));
      expect(
        stand.first.turn,
        -stand.last.turn,
        reason: 'the hallway is not symmetrical',
      );
    });
  });

  group('the cards', () {
    test('are four, and each says what it offers', () {
      expect(BeachCards.all, hasLength(4));
      for (final card in BeachCards.all) {
        expect(card.title, isNotEmpty);
        expect(card.action, isNotEmpty);

        // A drawn sprite, not an emoji. These are reflected, and an emoji is
        // rendered by the platform's own font at whatever size it likes — the
        // same glyph would come back different above the water and below it.
        expect(card.icon, startsWith('assets/images/'));
      }
    });

    test('and only the ones with somewhere to go claim to lead there', () {
      // The resume has no file yet. A card that offers to open something and
      // then does nothing is worse than one that says it is not ready.
      final resume = BeachCards.all.first;
      expect(resume.title, 'Resume');
      expect(resume.leadsSomewhere, isFalse);

      for (final card in BeachCards.all.skip(1)) {
        expect(card.leadsSomewhere, isTrue, reason: '${card.title} leads nowhere');
      }
    });
  });

  group('every cue can actually be heard', () {
    test('names a file, and that file is shipped', () {
      // The failure this catches is silent and total: a cue whose file is
      // missing does not merely lose its own sound — warming the cache walks
      // the list, and one absent file used to abort the rest of it. Two had
      // been pruned from the folder while still named here, and the whole
      // scene went quiet.
      for (final cue in AudioCue.values) {
        final file = FlameAppAudio.fileFor(cue);
        expect(file, isNotNull, reason: '$cue has no sound behind it');

        expect(
          File('assets/audio/$file').existsSync(),
          isTrue,
          reason: '$cue names $file, which is not in assets/audio',
        );
      }
    });

    test('at a volume somebody chose', () {
      for (final cue in AudioCue.values) {
        final volume = FlameAppAudio.volumeFor(cue);
        expect(volume, isNotNull, reason: '$cue has no volume');
        expect(volume, greaterThan(0), reason: '$cue is silent');
        expect(volume, lessThanOrEqualTo(1), reason: '$cue clips');
      }
    });
  });
}
