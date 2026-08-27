import 'package:flutter/material.dart';

import '../../fluid_glass.dart';

/// The standard liquid-glass surface, usable on its own: vibrancy, blur and
/// refraction over a backdrop, a container tint, a highlight rim and a drop
/// shadow.
///
/// This is the panel a `LiquidMenu` opens into, split out so the same look can
/// host anything — a popover, a card, a toolbar, a sheet.
///
/// [reveal] is read at paint time and ramps the *glassness* in: refraction
/// depth, rim and shadow all follow it, so an appearing panel reads as glass
/// thickening into place rather than a picture fading in. Give [repaint]
/// whatever drives it. A panel that is simply there needs neither.
class LiquidPanel extends StatelessWidget {
  const LiquidPanel({
    super.key,
    required this.backdrop,
    this.shape = const RoundedRectangle(26),
    this.reveal,
    this.repaint,
    this.surfaceColor,
    this.blurRadius = 8,
    this.refractionHeight = 20,
    this.refractionAmount = 28,
    this.showHighlight = true,
    this.showShadow = true,
    this.layerBlock,
    required this.child,
  });

  /// What the glass refracts.
  final Backdrop backdrop;

  final RoundedRectangularShape shape;

  /// 0..1, evaluated during paint. Null means fully revealed.
  final double Function()? reveal;

  /// Repaints the panel when it notifies; pass the animation behind [reveal].
  final Listenable? repaint;

  /// The tint over the refracted backdrop. Defaults to the catalog's
  /// container colour for the current brightness.
  final Color? surfaceColor;

  final double blurRadius;
  final double refractionHeight;
  final double refractionAmount;

  final bool showHighlight;
  final bool showShadow;

  /// An extra transform — a menu uses this to grow the panel out of its
  /// anchor. The backdrop is counter-transformed automatically.
  final GlassLayerBlock? layerBlock;

  final Widget child;

  double _revealNow() {
    final double Function()? reveal = this.reveal;
    if (reveal == null) return 1.0;
    return reveal().clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final bool isLight = Theme.of(context).brightness == Brightness.light;
    final Color container = surfaceColor ??
        (isLight
            ? const Color(0xFFFAFAFA).withValues(alpha: 0.4)
            : const Color(0xFF121212).withValues(alpha: 0.4));

    return DrawBackdrop(
      backdrop: backdrop,
      shape: () => shape,
      effects: (BackdropEffectScope scope) {
        final double r = _revealNow();
        scope
          ..vibrancy()
          ..blur(blurRadius)
          ..lens(refractionHeight * r, refractionAmount * r);
      },
      highlight: showHighlight
          ? () => Highlight.standard.copyWith(alpha: _revealNow())
          : null,
      shadow: showShadow
          ? () => GlassShadow.standard.copyWith(alpha: _revealNow())
          : null,
      layerBlock: layerBlock,
      onDrawSurface: (Canvas canvas, Size size) => canvas.drawRect(
        Offset.zero & size,
        Paint()..color = container,
      ),
      // Src-over only, so the isolating save-layer would be pure cost.
      isolateSurface: false,
      repaint: repaint,
      child: child,
    );
  }
}
