import 'package:flutter/material.dart';
import 'package:sea_scene/domain/models/loading_progress.dart';
import 'package:sea_scene/domain/style/colors.dart';
import 'package:sea_scene/domain/style/strings.dart';
import 'package:sea_scene/domain/style/text_styles.dart';

/// The curtain, and the readout under it.
///
/// The portfolio's loading screen carries its mark through this; there is no
/// mark here, and putting one in would be borrowing an identity the scene does
/// not have. What the curtain opens onto is the sea itself — which is the
/// whole reason the wait is worth watching rather than skipping.
///
/// It stays in the tree through the exit rather than being swapped out: the
/// column is centred, so a child that stops occupying space shortens it and
/// snaps the readout downward mid-reveal.
class LoadingScreen extends StatelessWidget {
  const LoadingScreen({
    required this.progress,
    required this.isReady,
    this.exit = 0,
    this.onEnter,
    super.key,
  });

  final LoadingProgress progress;

  /// Whether everything is loaded and the curtain is only waiting to be asked.
  final bool isReady;

  /// How far the curtain has opened, `0`..`1`.
  final double exit;

  /// Called when the visitor accepts the invitation.
  final VoidCallback? onEnter;

  @override
  Widget build(BuildContext context) {
    // Lifts away and clears early, so it is gone before the sea is fully
    // uncovered rather than fading over it.
    final lift = Curves.easeIn.transform((exit / 0.4).clamp(0.0, 1.0));

    return GestureDetector(
      // Opaque and full-bleed, because the invitation is the whole screen
      // rather than the words in the middle of it — a visitor told to tap
      // should not have to find a target.
      behavior: HitTestBehavior.opaque,
      onTap: isReady ? onEnter : null,
      child: Center(
        child: Transform.translate(
          offset: Offset(0, -8 * lift),
          child: Opacity(
            opacity: (1 - lift).clamp(0.0, 1.0),
            child: isReady
                ? _Invitation(text: context.strings.tapToEnter)
                : _Readout(progress: progress.value),
          ),
        ),
      ),
    );
  }
}

/// The word, and the figure that moves.
///
/// Two styles rather than one: the label is fixed and the figure is the only
/// thing on this screen that changes, so it is set apart and given tabular
/// figures — without them the readout jitters as digits swap and drags the
/// label around with it.
class _Readout extends StatelessWidget {
  const _Readout({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final type = context.typography;

    // Only the alpha is animated, brightening as the load completes. Face,
    // size and spacing come from the theme.
    final ink = context.colors.loadingText.withValues(
      alpha: 0.35 + progress * 0.35,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          strings.loadingLabel,
          style: type.loading.copyWith(color: ink),
        ),
        const SizedBox(height: 8),
        Text(
          strings.loadingPercent(progress),
          style: type.loadingReadout.copyWith(color: ink),
        ),
      ],
    );
  }
}

/// What the curtain says once it is only waiting to be asked.
///
/// The bar is gone by this point rather than sitting at a hundred per cent:
/// a full bar is a statement about the past, and what the screen needs to say
/// now is what to do next.
class _Invitation extends StatelessWidget {
  const _Invitation({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: context.typography.enter.copyWith(
        color: context.colors.loadingText,
      ),
    );
  }
}
