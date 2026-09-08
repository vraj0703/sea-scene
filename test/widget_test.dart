import 'package:flutter_test/flutter_test.dart';
import 'package:sea_scene/domain/beach/beach_cards.dart';

void main() {
  test('there are four cards, and each says what it offers', () {
    expect(BeachCards.all, hasLength(4));

    for (final card in BeachCards.all) {
      expect(card.title, isNotEmpty);
      expect(card.action, isNotEmpty);
    }
  });
}
