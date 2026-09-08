import 'package:flutter/material.dart';

/// Every word the scene shows.
///
/// Copy lives here rather than at the point it is drawn, so the whole of what
/// the site says can be read in one file — and changed without opening a
/// widget.
abstract class AppStrings {
  String get loadingLabel;
  String loadingPercent(double progress);

  /// What the curtain says once there is something behind it worth opening.
  String get tapToEnter;

  /// The name written across the horizon, and mirrored in the water under it.
  String get title;
}

class DefaultAppStrings implements AppStrings {
  const DefaultAppStrings();

  @override
  String get loadingLabel => 'LOADING...';

  @override
  String get tapToEnter => 'TAP TO ENTER';

  /// Always three digits, so the readout does not change width as it counts
  /// and drag the label around with it.
  @override
  String loadingPercent(double progress) =>
      '${(progress.clamp(0.0, 1.0) * 100).round().toString().padLeft(3, '0')}%';

  @override
  String get title => 'Vishal Raj';
}

class AppStringsExtension extends ThemeExtension<AppStringsExtension> {
  const AppStringsExtension({required this.strings});

  final AppStrings strings;

  @override
  AppStringsExtension copyWith({AppStrings? strings}) =>
      AppStringsExtension(strings: strings ?? this.strings);

  @override
  AppStringsExtension lerp(ThemeExtension<AppStringsExtension>? other, double t) {
    if (other is! AppStringsExtension) return this;
    return t < 0.5 ? this : other;
  }
}

extension StringsX on BuildContext {
  AppStrings get strings =>
      Theme.of(this).extension<AppStringsExtension>()?.strings ??
      const DefaultAppStrings();
}
