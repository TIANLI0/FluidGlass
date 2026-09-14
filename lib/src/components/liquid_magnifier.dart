import 'package:flutter/material.dart';

import '../../fluid_glass.dart';

/// A loupe: a piece of glass that samples what is behind it, scaled up about
/// its own centre.
///
/// The magnification is not an effect layered on the glass — it is *where the
/// glass samples from*. The backdrop is drawn through a scaled canvas before
/// the lens and the rim run over it, so the refraction at the edge bends
/// already-magnified pixels and the loupe reads as a solid piece of glass
/// rather than a picture-in-picture with a border.
///
/// Two things are the caller's:
///
/// - **The [backdrop]**, as everywhere in this package. A loupe usually wants
///   more than one layer under it — the page, plus whatever floats over it that
///   should be magnified too (a text cursor, a selection handle) — which is
///   what [CombinedBackdrop] is for. [nativeBackdrop] cannot be used here: the
///   compositor filters what is behind the element, and there is no way to ask
///   it to sample somewhere else.
/// - **Where it sits.** This widget does not position or drag itself; wrap it
///   in whatever moves it. [focalOffset] then says what it looks *at* relative
///   to where it is — a text loupe sits above the finger and looks down at the
///   line under it, so the reader's own hand is not covering the thing being
///   magnified.
class LiquidMagnifier extends StatelessWidget {
  const LiquidMagnifier({
    super.key,
    required this.backdrop,
    this.size = const Size(128, 96),
    this.magnification = 1.5,
    this.focalOffset = const Offset(0, 80),
    this.shape = const Capsule(),
    this.refractionHeight = 8,
    this.refractionAmount = 24,
    this.depthEffect = true,
    this.chromaticAberration = true,
    this.innerShadow,
    this.child,
  }) : assert(magnification > 0, 'Magnification must be positive.');

  /// What the glass samples. See the class doc — [nativeBackdrop] cannot work
  /// here, and [CombinedBackdrop] is usually what a loupe wants.
  final Backdrop backdrop;

  /// The size of the loupe itself. Ignored when [child] sizes itself.
  final Size size;

  /// How far the sampled pixels are scaled up, about the loupe's centre.
  final double magnification;

  /// What the loupe looks at, in logical pixels from its own centre, before
  /// magnification.
  ///
  /// The default looks 80 below itself: the loupe floats above the point of
  /// interest so a finger on that point does not cover it. Pass [Offset.zero]
  /// for a loupe that magnifies exactly what it covers.
  final Offset focalOffset;

  final RoundedRectangularShape shape;

  final double refractionHeight;
  final double refractionAmount;

  /// Reads as a thicker piece of glass — on by default here, unlike on a flat
  /// panel: a loupe is meant to look like a lens.
  final bool depthEffect;

  /// Splits the sample into seven wavelengths for a prism fringe at the rim.
  final bool chromaticAberration;

  /// Drawn inside the rim. Gives the loupe its thickness where it meets the
  /// page; `GlassInnerShadow(radius: 16)` is a good starting point.
  final GlassInnerShadow? innerShadow;

  /// Drawn over the magnified pixels — a measurement reticle, a caption. Most
  /// loupes have none.
  final Widget? child;

  void _drawMagnified(
    BackdropDrawContext context,
    void Function() drawBackdrop,
  ) {
    final Canvas canvas = context.canvas;
    final double cx = context.size.width / 2;
    final double cy = context.size.height / 2;
    canvas
      ..save()
      ..translate(cx, cy)
      ..scale(magnification, magnification)
      ..translate(-cx, -cy)
      // Negated: moving the sampled picture up is what brings what lies below
      // into view.
      ..translate(-focalOffset.dx, -focalOffset.dy);
    drawBackdrop();
    canvas.restore();
  }

  @override
  Widget build(BuildContext context) {
    final GlassInnerShadow? shadow = innerShadow;
    return DrawBackdrop(
      backdrop: backdrop,
      shape: () => shape,
      effects: (BackdropEffectScope scope) => scope.lens(
        refractionHeight,
        refractionAmount,
        depthEffect: depthEffect,
        chromaticAberration: chromaticAberration,
      ),
      innerShadow: shadow == null ? null : () => shadow,
      onDrawBackdrop: _drawMagnified,
      child: child ?? SizedBox(width: size.width, height: size.height),
    );
  }
}
