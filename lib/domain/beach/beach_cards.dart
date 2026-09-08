import 'package:flutter/painting.dart';

/// One card washed up on the sand.
///
/// Immutable, and holding no behaviour: what a card *is* belongs here, what it
/// does belongs to the thing that draws it. The previous site kept a colour on
/// each because the four are meant to be told apart at a glance before any of
/// them is read.
class BeachCard {
  const BeachCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.action,
    required this.accent,
    this.url,
  });

  /// The card's mark, as an asset.
  ///
  /// A drawn sprite rather than an emoji, because these are reflected: the
  /// water samples whatever the cards drew, and an emoji is rendered by the
  /// platform's own font at whatever size it likes — the same glyph would come
  /// back different above the waterline and below it.
  final String icon;

  final String title;
  final String description;

  /// What the back of the card offers, once it has turned over.
  final String action;

  /// The card's own colour, used for its edge and its reflection.
  final Color accent;

  /// Where following it leads, or null while there is nowhere to go.
  ///
  /// The resume is deliberately null: the card turns over and reads, and the
  /// day the file exists it becomes a link without anything else changing.
  final String? url;

  bool get leadsSomewhere => url != null;
}

/// The four, in the order they land.
abstract final class BeachCards {
  static const List<BeachCard> all = <BeachCard>[
    BeachCard(
      icon: 'assets/images/bill.png',
      title: 'Resume',
      description:
          'Download my resume for a detailed overview of my experience, '
          'skills, and achievements.',
      action: 'Download Resume',
      accent: Color(0xFF00FFFF),
    ),
    BeachCard(
      icon: 'assets/images/linkedin.png',
      title: 'LinkedIn',
      description:
          'Connect with me on LinkedIn for professional updates, '
          'endorsements, and career insights.',
      action: 'Open LinkedIn',
      accent: Color(0xFF0A66C2),
      url: 'https://www.linkedin.com/in/vraj0703/',
    ),
    BeachCard(
      icon: 'assets/images/github.png',
      title: 'GitHub',
      description:
          'Explore my open-source contributions, side projects, and code '
          'experiments on GitHub.',
      action: 'View GitHub',
      accent: Color(0xFFFFFFFF),
      url: 'https://github.com/vraj0703',
    ),
    BeachCard(
      icon: 'assets/images/gmail.png',
      title: 'Email',
      description:
          'Reach out via email for collaborations, opportunities, or just to '
          'say hello.\n\nvraj0703@gmail.com',
      action: 'Send Email',
      accent: Color(0xFFEA4335),
      url: 'mailto:vraj0703@gmail.com',
    ),
  ];
}
