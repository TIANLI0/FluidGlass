import 'package:flutter/widgets.dart';

import '../internal/shader_programs.dart';

/// How much of the liquid-glass look a glass element is allowed to draw.
///
/// The refraction is the expensive part: a fragment shader that runs over the
/// element's whole padded texture every frame it changes. On a device that
/// cannot hold its frame budget with that in the chain, the honest thing is to
/// drop it and keep the blur — the result still reads as a translucent surface,
/// it just stops bending what is behind it.
///
/// There are deliberately only two: the refraction is either on or off. A
/// middle rung that kept the shaded rim without the lens was tried and removed
/// — it made the decision three-way for no visible benefit and gave the
/// classifier somewhere to sit instead of committing either way.
///
/// Tiers are ordered cheapest last, so they can be compared: `index` rises as
/// the element gets simpler.
///
/// Resolution order for any one element, first match winning:
///
///  1. `DrawBackdrop.quality`, when the call site pins a tier — for a hero
///     element that should stay liquid whatever else degrades.
///  2. The nearest enclosing [GlassQualityScope].
///  3. [GlassDeviceTier.instance], which classifies the device once, before the
///     first frame.
///
/// Whatever is chosen is then clamped by what the backend can actually do:
/// without runtime shaders — a Skia build, or web — nothing above [plain] is
/// reachable, because the refraction and the shaded rim are both shaders.
enum GlassQuality {
  /// Liquid glass: refraction, the shaded rim, blur, tint and shadow.
  ///
  /// What the library exists to draw.
  liquid,

  /// A plain Gaussian blur behind the tint, with a flat rim.
  ///
  /// No fragment shaders at all — neither the lens nor the shaded rim. Whatever
  /// [HighlightStyle] the element asked for is drawn as its flat colour, which
  /// is also what any element falls back to on a backend without runtime
  /// shaders. Still a translucent surface with a shadow and an edge; it just
  /// stops bending what is behind it.
  ///
  /// It does not *sample* the backdrop either. Where the backdrop is content
  /// already painted behind the element, the effect chain is handed to the
  /// compositor as a [BackdropFilterLayer] — Flutter's own `BackdropFilter` —
  /// so there is no capture of the source at all, which is the whole cost of a
  /// live backdrop. See `Backdrop.isPaintedBehindConsumer`.
  plain;

  /// Whether this tier may run fragment programs at all.
  ///
  /// [plain] means none: not the lens, not the rim's directional shading, not
  /// the glow under a finger. Each of those has a flat fallback, which is also
  /// what every element falls back to on a backend without runtime shaders — so
  /// the cheap tier and the incapable backend draw the same thing, and there is
  /// only one appearance to check.
  bool get hasShaders => this == GlassQuality.liquid;

  /// Whether this tier draws the refraction.
  bool get hasRefraction => hasShaders;

  /// Whether this tier shades the rim with a fragment program rather than
  /// filling it with a flat colour.
  ///
  /// Coincides with [hasRefraction] while there are only two tiers; kept
  /// separate because the rim painter and the effect chain are asking different
  /// questions of the same answer.
  bool get hasShadedRim => hasShaders;

  /// The cheaper of the two tiers.
  GlassQuality atMost(GlassQuality ceiling) =>
      index >= ceiling.index ? this : ceiling;

  /// One step cheaper, or null at the bottom.
  GlassQuality? get next =>
      index + 1 < GlassQuality.values.length
          ? GlassQuality.values[index + 1]
          : null;

  /// One step richer, or null at the top.
  GlassQuality? get previous =>
      index > 0 ? GlassQuality.values[index - 1] : null;

  /// The richest tier this backend can actually draw.
  ///
  /// [ui.ImageFilter.shader] needs Impeller, and both the refraction and the
  /// shaded rim go through it, so a backend without it is pinned to [plain]
  /// however fast it is.
  static GlassQuality get ceiling =>
      isRuntimeShaderSupported() ? GlassQuality.liquid : GlassQuality.plain;
}

/// Pins a [GlassQuality] for a subtree.
///
/// Use it to opt a screen out of the device classification — a settings toggle
/// offering "reduce visual effects", say — or to hold a showcase screen at
/// [GlassQuality.liquid] while the rest of the app is free to degrade.
///
/// ```dart
/// GlassQualityScope(
///   quality: reduceEffects ? GlassQuality.plain : GlassQuality.liquid,
///   child: child,
/// )
/// ```
class GlassQualityScope extends InheritedWidget {
  const GlassQualityScope({
    super.key,
    required this.quality,
    required super.child,
  });

  final GlassQuality quality;

  /// The tier pinned by the nearest enclosing scope, or null when none is.
  ///
  /// Null means "let the governor decide", which is not the same as
  /// [GlassQuality.liquid].
  static GlassQuality? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<GlassQualityScope>()
        ?.quality;
  }

  @override
  bool updateShouldNotify(GlassQualityScope oldWidget) =>
      oldWidget.quality != quality;
}
