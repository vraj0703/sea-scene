import 'package:flutter/material.dart';

/// A custom clipper that creates a "curtain opening" effect.
///
/// It draws two rectangles that retract from the center of the screen
/// towards the top and bottom edges as `revealProgress` goes from 0.0 to 1.0.
class CurtainClipper extends CustomClipper<Path> {
  final double revealProgress;

  CurtainClipper({required this.revealProgress});

  @override
  Path getClip(Size size) {
    final path = Path();
    final center = size.height / 2;
    // The height of the opening slit, grows with progress.
    final openHeight = size.height * revealProgress;

    // Top curtain part
    path.addRect(Rect.fromLTWH(0, 0, size.width, center - openHeight / 2));

    // Bottom curtain part
    path.addRect(
      Rect.fromLTWH(
        0,
        center + openHeight / 2,
        size.width,
        center - openHeight / 2,
      ),
    );

    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) {
    oldClipper as CurtainClipper;
    // Reclip whenever the progress changes to drive the animation.
    return oldClipper.revealProgress != revealProgress;
  }
}
