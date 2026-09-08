import 'package:flutter/material.dart';

/// Every colour the scene uses, in one place.
///
/// The same arrangement the portfolio has: an interface, one implementation,
/// and a theme extension — so a widget reads colour the way it reads type, and
/// nothing paints with a literal.
abstract class AppColors {
  /// The ground painted before the shader exists.
  ///
  /// A page shows white until the first frame, and the beach opens on a dark
  /// sky. Without a matching ground the scene arrives as a flash of the wrong
  /// colour, which no in-app animation can fix — the app is not running yet.
  Color get backdrop;

  /// The curtain the loading screen draws over everything.
  Color get curtain;

  /// The readout under it, and the figure that moves.
  Color get loadingText;

  /// What a card is made of, and the ink on it.
  Color get cardGround;
  Color get cardInk;
  Color get cardInkSoft;
}

class DefaultAppColors implements AppColors {
  const DefaultAppColors();

  /// Matched to `web/index.html`. If one changes, so does the other: a
  /// mismatch shows as a flash of the wrong dark on the first frame.
  @override
  Color get backdrop => const Color(0xFF061018);

  @override
  Color get curtain => backdrop;

  @override
  Color get loadingText => const Color(0xFFBFD4DE);

  /// Glass on a wet beach: enough ground to read against a moving sea,
  /// little enough that the sea is still visible through it.
  @override
  Color get cardGround => const Color(0xFF0B1A24);

  @override
  Color get cardInk => const Color(0xFFEFF6F9);

  @override
  Color get cardInkSoft => const Color(0xFFA9C0CC);
}

class AppColorsExtension extends ThemeExtension<AppColorsExtension> {
  const AppColorsExtension({required this.colors});

  final AppColors colors;

  @override
  AppColorsExtension copyWith({AppColors? colors}) =>
      AppColorsExtension(colors: colors ?? this.colors);

  @override
  AppColorsExtension lerp(ThemeExtension<AppColorsExtension>? other, double t) {
    if (other is! AppColorsExtension) return this;
    return t < 0.5 ? this : other;
  }
}

extension ColorsX on BuildContext {
  AppColors get colors =>
      Theme.of(this).extension<AppColorsExtension>()?.colors ??
      const DefaultAppColors();
}
