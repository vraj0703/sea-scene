import 'package:flutter/material.dart';

/// Every text style the scene uses.
abstract class AppTypography {
  /// The word under the loading mark, and the figure beside it.
  TextStyle get loading;
  TextStyle get loadingReadout;

  /// A card's name, what it says, and what it offers.
  TextStyle get cardTitle;
  TextStyle get cardBody;
  TextStyle get cardAction;
}

class DefaultAppTypography implements AppTypography {
  const DefaultAppTypography();

  @override
  TextStyle get loading =>
      const TextStyle(fontSize: 16, letterSpacing: 6, fontWeight: FontWeight.w300);

  /// The figure is the only thing on the loading screen that changes, so it
  /// is set apart — and tabular, or the readout jitters as digits swap.
  @override
  TextStyle get loadingReadout => const TextStyle(
    fontSize: 16,
    letterSpacing: 4,
    fontWeight: FontWeight.w500,
    fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
  );

  @override
  TextStyle get cardTitle =>
      const TextStyle(fontSize: 22, letterSpacing: 1.2, fontWeight: FontWeight.w600);

  @override
  TextStyle get cardBody =>
      const TextStyle(fontSize: 13, height: 1.45, fontWeight: FontWeight.w400);

  @override
  TextStyle get cardAction =>
      const TextStyle(fontSize: 13, letterSpacing: 1.4, fontWeight: FontWeight.w600);
}

class AppTypographyExtension extends ThemeExtension<AppTypographyExtension> {
  const AppTypographyExtension({required this.typography});

  /// Named `typography`, never `type`.
  ///
  /// `ThemeExtension.type` is the key Flutter files extensions under, so a
  /// field of that name silently overrides it — and the lookup then keys on
  /// a typography object rather than on the extension's own type, which means
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
