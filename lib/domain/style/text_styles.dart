import 'package:flutter/material.dart';

/// Every text style the scene uses.
///
/// The faces are the portfolio's, used for the same jobs they do there, so the
/// three sites read as one hand rather than three.
abstract class AppTypography {
  /// The word on the loading screen, and the figure beside it.
  TextStyle get loading;
  TextStyle get loadingReadout;

  /// What the curtain says once it is only waiting to be asked.
  TextStyle get enter;

  /// A card's name, what it says, and what it offers.
  TextStyle get cardTitle;
  TextStyle get cardBody;
  TextStyle get cardAction;
}

class DefaultAppTypography implements AppTypography {
  const DefaultAppTypography();

  /// The portfolio's loading label, unchanged: a mono face at wide tracking,
  /// so the word reads as a machine reporting rather than as a caption.
  @override
  TextStyle get loading => const TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.bold,
    letterSpacing: 10,
    fontFamily: 'MonoLoading',
  );

  /// A different mono from the label, and tracked the same.
  ///
  /// Both are the portfolio's choices and both are deliberate: the figure is
  /// the only thing on the screen that changes, so giving it a face of its own
  /// is what stops it reading as part of the label. Tabular figures on top,
  /// or the readout jitters as digits swap and drags the label with it.
  @override
  TextStyle get loadingReadout => const TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.normal,
    letterSpacing: 10,
    fontFamily: 'AzeretMono',
    fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
  );

  /// The invitation, at the portfolio's own size and tracking for the same
  /// line.
  @override
  TextStyle get enter => const TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.normal,
    letterSpacing: 6,
    fontFamily: 'Apertura',
  );

  /// Apertura, which is what the portfolio sets its own contact menu in — the
  /// nearest thing it has to these cards.
  @override
  TextStyle get cardTitle => const TextStyle(
    fontSize: 21,
    letterSpacing: 1.2,
    fontWeight: FontWeight.w600,
    fontFamily: 'Apertura',
  );

  /// Margot, which is what the portfolio sets anything meant to be read as a
  /// sentence rather than as a signal.
  @override
  TextStyle get cardBody => const TextStyle(
    fontSize: 13,
    height: 1.45,
    fontWeight: FontWeight.w400,
    fontFamily: 'Margot',
  );

  @override
  TextStyle get cardAction => const TextStyle(
    fontSize: 13,
    letterSpacing: 1.4,
    fontWeight: FontWeight.w600,
    fontFamily: 'Apertura',
  );
}

class AppTypographyExtension extends ThemeExtension<AppTypographyExtension> {
  const AppTypographyExtension({required this.typography});

  /// Named `typography`, never `type`.
  ///
  /// `ThemeExtension.type` is the key Flutter files extensions under, so a
  /// field of that name silently overrides it — and the lookup then keys on a
  /// typography object rather than on the extension's own type, which means
  /// `Theme.of(context).extension<AppTypographyExtension>()` finds nothing.
  /// The analyzer catches it as a style warning; it is a broken theme.
  final AppTypography typography;

  @override
  AppTypographyExtension copyWith({AppTypography? typography}) =>
      AppTypographyExtension(typography: typography ?? this.typography);

  @override
  AppTypographyExtension lerp(
    ThemeExtension<AppTypographyExtension>? other,
    double t,
  ) {
    if (other is! AppTypographyExtension) return this;
    return t < 0.5 ? this : other;
  }
}

extension TypographyX on BuildContext {
  AppTypography get typography =>
      Theme.of(this).extension<AppTypographyExtension>()?.typography ??
      const DefaultAppTypography();
}
