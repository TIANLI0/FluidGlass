import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// A translucent surface over a gaussian blur of whatever is behind it.
///
/// Plain compositor blur — no refraction, no sampling of a captured page, no
/// shader — so it costs one blur pass and works on every device. The tint is
/// kept light ([SoftThemeData.frostTint] is mostly transparent) so the
/// content behind reads through: the surface is a veil, not a panel.
class SoftFrosted extends StatelessWidget {
  const SoftFrosted({
    super.key,
    required this.child,
    required this.shape,
    required this.tint,
    this.sigma = 20,
    this.shadows = const <BoxShadow>[],
    this.border,
  });

  final Widget child;
  final ShapeBorder shape;

  /// The colour laid over the blur.
  final Color tint;

  /// Blur strength (standard deviation, logical pixels).
  final double sigma;
  final List<BoxShadow> shadows;

  /// A hairline round the edge, drawn over the surface.
  final BorderSide? border;

  @override
  Widget build(BuildContext context) {
    final ShapeBorder edge = border == null
        ? shape
        : (shape is OutlinedBorder
              ? (shape as OutlinedBorder).copyWith(side: border)
              : shape);
    return DecoratedBox(
      // The shadow sits outside the clip, so it is drawn here, not inside.
      decoration: ShapeDecoration(shape: shape, shadows: shadows),
      child: ClipPath(
        clipper: ShapeBorderClipper(shape: shape),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(
            sigmaX: sigma,
            sigmaY: sigma,
            tileMode: TileMode.clamp,
          ),
          child: DecoratedBox(
            decoration: ShapeDecoration(color: tint, shape: edge),
            child: child,
          ),
        ),
      ),
    );
  }
}
