import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import 'soft_programs.dart';
import 'soft_squircle.dart';
import 'soft_theme.dart';

/// A directional light of the glass rim.
@immutable
class SoftRimLight {
  const SoftRimLight(this.x, this.y, this.z, this.intensity);

  final double x;
  final double y;
  final double z;
  final double intensity;
}

/// The lit rim of a glass surface: a faint stroke along the silhouette and
/// two directional lights bevelling the band just inside it.
@immutable
class SoftGlassRim {
  const SoftGlassRim({
    this.color = const Color(0x0DFFFFFF),
    this.innerBlurRadius = 2.8,
    this.primaryLight = const SoftRimLight(0.5, 0.5, -0.5, 0.4),
    this.secondaryLight = const SoftRimLight(0.5, 0.8, -0.5, 0.25),
    this.width = 0.8,
    this.alpha = 1,
  });

  /// The stroke colour; its alpha scales the stroke.
  final Color color;

  /// The depth of the bevel the lights shade, in logical pixels.
  final double innerBlurRadius;
  final SoftRimLight primaryLight;
  final SoftRimLight secondaryLight;

  /// The stroke band width.
  final double width;

  /// The overall opacity.
  final double alpha;

  static const SoftGlassRim bigLight = SoftGlassRim(
    innerBlurRadius: 3.5,
    primaryLight: SoftRimLight(0.5, 0.5, -0.5, 0.3),
    secondaryLight: SoftRimLight(0.5, 0.6, -0.5, 0.2),
  );
  static const SoftGlassRim middleLight = SoftGlassRim();
  static const SoftGlassRim smallLight = SoftGlassRim(
    innerBlurRadius: 2.6,
    primaryLight: SoftRimLight(0.5, 0.5, -0.5, 0.6),
    secondaryLight: SoftRimLight(0.5, 0.95, -0.5, 0.35),
  );
  static const SoftGlassRim panelLight = SoftGlassRim(
    innerBlurRadius: 3.5,
    primaryLight: SoftRimLight(0.5, 0.5, -0.5, 0.3),
    secondaryLight: SoftRimLight(0.5, 1, -0.5, 0.16),
  );
  static const SoftGlassRim bigDark = SoftGlassRim(
    innerBlurRadius: 1.7,
    primaryLight: SoftRimLight(0.5, 0.5, -0.5, 0.4),
    secondaryLight: SoftRimLight(0.5, 0.6, -0.5, 0.25),
  );
  static const SoftGlassRim middleDark = SoftGlassRim(
    color: Color(0x0FFFFFFF),
    innerBlurRadius: 2,
    primaryLight: SoftRimLight(0.5, 0.5, -0.5, 0.5),
    secondaryLight: SoftRimLight(0.5, 0.8, -0.5, 0.25),
  );
  static const SoftGlassRim smallDark = SoftGlassRim(
    color: Color(0x14FFFFFF),
    innerBlurRadius: 2.3,
    primaryLight: SoftRimLight(0.5, 0.5, -0.5, 0.6),
    secondaryLight: SoftRimLight(0.5, 0.95, -0.36, 0.25),
  );
  static const SoftGlassRim panelDark = SoftGlassRim(
    innerBlurRadius: 1.7,
    primaryLight: SoftRimLight(0.5, 0.5, -0.5, 0.4),
    secondaryLight: SoftRimLight(0.5, 1, -0.5, 0.21),
  );

  /// The preset for a [size] class in the light or dark theme.
  static SoftGlassRim of(SoftGlassSize size, {required bool dark}) {
    switch (size) {
      case SoftGlassSize.small:
        return dark ? smallDark : smallLight;
      case SoftGlassSize.medium:
        return dark ? middleDark : middleLight;
      case SoftGlassSize.large:
        return dark ? bigDark : bigLight;
      case SoftGlassSize.panel:
        return dark ? panelDark : panelLight;
    }
  }
}

/// The size class of a glass surface, choosing its rim.
enum SoftGlassSize {
  /// Chips, small buttons.
  small,

  /// Bars, cards, popups.
  medium,

  /// Full-width sheets and dialogs.
  large,

  /// A popup panel: lit along the bottom edge as well.
  panel,
}

/// One tint layer of a glass surface: [color] painted over the blurred
/// backdrop with [blendMode].
@immutable
class SoftBlendLayer {
  const SoftBlendLayer(this.color, [this.blendMode = BlendMode.srcOver]);

  final Color color;
  final BlendMode blendMode;

  @override
  bool operator ==(Object other) =>
      other is SoftBlendLayer &&
      other.color == color &&
      other.blendMode == blendMode;

  @override
  int get hashCode => Object.hash(color, blendMode);
}

/// The glass surface defaults.
abstract final class SoftGlassDefaults {
  /// The blur radius, in logical pixels.
  static const double blurRadius = 25;

  /// The alpha of the container colour over the blur.
  static const double containerAlpha = 0.8;

  /// A blur radius as a Gaussian sigma: the reference's texture blur takes
  /// `sigma = 0.45 · radius`.
  static double sigmaOf(double radius) => radius <= 0 ? 0 : radius * 0.45;
}

final Expando<ui.FragmentShader> _rimShaders = Expando<ui.FragmentShader>();

/// Paints [rim] over `Offset.zero & size` for a surface whose corners are
/// [radius].
void paintSoftGlassRim(
  Canvas canvas,
  Size size,
  BorderRadius radius,
  SoftGlassRim rim, {
  bool smooth = true,
}) {
  if (rim.width <= 0 || rim.alpha <= 0 || size.isEmpty) return;
  final ui.FragmentProgram? program = SoftPrograms.instance.bloomStroke;
  if (program == null) return;
  final ui.FragmentShader shader = _rimShaders[program] ??= program
      .fragmentShader();
  final double halfW = size.width / 2;
  final double halfH = size.height / 2;
  final double maxRadius = size.shortestSide / 2;
  double r(Radius c) => math.min(c.x, maxRadius);
  int i = 0;
  void f(double v) => shader.setFloat(i++, v);
  f(halfW);
  f(halfH);
  f(halfW.floorToDouble());
  f(halfH.floorToDouble());
  f(r(radius.topLeft));
  f(r(radius.topRight));
  f(r(radius.bottomLeft));
  f(r(radius.bottomRight));
  f(smooth ? 2.5 : 2.0);
  f(math.min(rim.width, maxRadius));
  f(rim.innerBlurRadius);
  f(rim.alpha);
  f(rim.color.r);
  f(rim.color.g);
  f(rim.color.b);
  f(rim.color.a);
  final List<double> axes = <double>[];
  for (final SoftRimLight light in <SoftRimLight>[
    rim.primaryLight,
    rim.secondaryLight,
  ]) {
    final double dx = light.x - 0.5;
    final double dy = light.y - 0.7;
    final double dz = light.z;
    final double len = math.max(math.sqrt(dx * dx + dy * dy + dz * dz), 1e-6);
    final double nx = dx / len;
    final double ny = dy / len;
    f(nx);
    f(ny);
    f(dz / len);
    f(1);
    f(1);
    f(1);
    f(light.intensity);
    final double xyLen = math.sqrt(nx * nx + ny * ny);
    if (xyLen > 1e-3) {
      axes
        ..add(nx / xyLen)
        ..add(ny / xyLen);
    } else {
      axes
        ..add(0)
        ..add(axes.isEmpty ? -1 : 1);
    }
  }
  axes.forEach(f);
  canvas.drawRect(
    Offset.zero & size,
    Paint()
      ..shader = shader
      ..blendMode = BlendMode.plus,
  );
}

/// A frosted glass surface: the content behind it blurred, a translucent
/// [color] laid over the blur, a lit rim along the outline, and [child] on
/// top.
///
/// With [blur] false it is an opaque fill of [color] with no rim — the
/// fallback the reference uses where there is nothing to blur.
class SoftGlass extends StatelessWidget {
  const SoftGlass({
    super.key,
    required this.borderRadius,
    this.color,
    this.containerAlpha = SoftGlassDefaults.containerAlpha,
    this.blurRadius = SoftGlassDefaults.blurRadius,
    this.size = SoftGlassSize.medium,
    this.rim,
    this.blur = true,
    this.shadows,
    this.layers,
    this.child,
  });

  /// Tint layers that replace the single [color] tint over the blur — a
  /// colour-dodge then a luminosity layer keep the backdrop's hue and only
  /// remap its lightness.
  final List<SoftBlendLayer>? layers;

  final BorderRadius borderRadius;

  /// The container colour; the theme's `bar` colour when null.
  final Color? color;

  /// The alpha [color] is laid over the blur at (multiplied with its own).
  final double containerAlpha;

  /// The blur radius in logical pixels.
  final double blurRadius;

  /// Chooses the rim preset when [rim] is null.
  final SoftGlassSize size;

  /// Overrides the rim; pass a rim with `alpha: 0` for none.
  final SoftGlassRim? rim;

  /// Whether to blur what is behind; false paints [color] opaque.
  final bool blur;

  /// Shadows cast outside the outline.
  final List<BoxShadow>? shadows;

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final List<SoftBlendLayer>? tints = layers;
    final bool advanced =
        blur &&
        tints != null &&
        tints.any((SoftBlendLayer l) => l.blendMode != BlendMode.srcOver);
    if (!advanced) return _build(context, null);
    // The blend program loads asynchronously; rebuild when it arrives.
    return ListenableBuilder(
      listenable: SoftPrograms.instance,
      builder: (BuildContext context, _) {
        final ui.FragmentProgram? program = SoftPrograms.instance.blendTint;
        return _build(
          context,
          program != null && ui.ImageFilter.isShaderFilterSupported
              ? program
              : null,
        );
      },
    );
  }

  /// [blendProgram], when given, blends the tint layers into the blurred
  /// backdrop inside the filter. Painting colour-dodge or luminosity layers
  /// over a `BackdropFilter` instead asks the backend for advanced blends
  /// against the backdrop — which on some GLES configurations blanks the
  /// whole frame, not just the panel.
  Widget _build(BuildContext context, ui.FragmentProgram? blendProgram) {
    final SoftThemeData theme = SoftTheme.of(context);
    final bool smooth = theme.smoothCorners;
    final Color base = color ?? theme.colors.bar;
    final SoftGlassRim effectiveRim =
        rim ?? SoftGlassRim.of(size, dark: theme.isDark);
    final ShapeBorder shape = SoftSquircleBorder(
      radius: borderRadius,
      smooth: smooth,
    );
    final List<SoftBlendLayer>? tints = layers;
    final bool advanced =
        tints != null &&
        tints.any((SoftBlendLayer l) => l.blendMode != BlendMode.srcOver);
    final List<SoftBlendLayer> painted;
    if (!blur) {
      painted = <SoftBlendLayer>[SoftBlendLayer(base)];
    } else if (tints != null && !advanced) {
      painted = tints;
    } else if (tints != null && blendProgram != null) {
      painted = const <SoftBlendLayer>[];
    } else {
      // No way to blend the layers safely: a plain translucent tint.
      painted = <SoftBlendLayer>[
        SoftBlendLayer(base.withValues(alpha: base.a * containerAlpha)),
      ];
    }
    Widget content = CustomPaint(
      painter: _GlassFillPainter(layers: painted),
      foregroundPainter: blur
          ? _GlassRimPainter(
              radius: borderRadius,
              rim: effectiveRim,
              smooth: smooth,
            )
          : null,
      child: child,
    );
    if (blur) {
      final double sigma = SoftGlassDefaults.sigmaOf(blurRadius);
      ui.ImageFilter filter = ui.ImageFilter.blur(
        sigmaX: sigma,
        sigmaY: sigma,
        tileMode: TileMode.mirror,
      );
      if (tints != null && advanced && blendProgram != null) {
        filter = ui.ImageFilter.compose(
          outer: ui.ImageFilter.shader(_blendShader(blendProgram, tints)),
          inner: filter,
        );
      }
      content = BackdropFilter(filter: filter, child: content);
    }
    content = ClipPath(
      clipper: ShapeBorderClipper(shape: shape),
      child: content,
    );
    final List<BoxShadow>? s = shadows;
    if (s != null && s.isNotEmpty) {
      content = DecoratedBox(
        decoration: ShapeDecoration(shape: shape, shadows: s),
        child: content,
      );
    }
    return content;
  }
}

ui.FragmentShader _blendShader(
  ui.FragmentProgram program,
  List<SoftBlendLayer> layers,
) {
  double mode(BlendMode m) => switch (m) {
    BlendMode.colorDodge => 1,
    BlendMode.luminosity => 2,
    BlendMode.overlay => 3,
    _ => 0,
  };
  final ui.FragmentShader shader = program.fragmentShader();
  int i = 0;
  void put(double v) => shader.setFloat(i++, v);
  // Floats 0..1 are uTextureSize, which the engine overwrites.
  put(0);
  put(0);
  for (int k = 0; k < 2; k++) {
    final SoftBlendLayer? layer = k < layers.length ? layers[k] : null;
    put(layer?.color.r ?? 0);
    put(layer?.color.g ?? 0);
    put(layer?.color.b ?? 0);
    put(layer?.color.a ?? 0);
    put(layer == null ? 0 : mode(layer.blendMode));
  }
  put(layers.length.clamp(0, 2).toDouble());
  return shader;
}

class _GlassFillPainter extends CustomPainter {
  const _GlassFillPainter({required this.layers});

  final List<SoftBlendLayer> layers;

  @override
  void paint(Canvas canvas, Size size) {
    for (final SoftBlendLayer layer in layers) {
      canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..color = layer.color
          ..blendMode = layer.blendMode,
      );
    }
  }

  @override
  bool shouldRepaint(_GlassFillPainter old) {
    if (old.layers.length != layers.length) return true;
    for (int i = 0; i < layers.length; i++) {
      if (old.layers[i] != layers[i]) return true;
    }
    return false;
  }
}

class _GlassRimPainter extends CustomPainter {
  _GlassRimPainter({
    required this.radius,
    required this.rim,
    required this.smooth,
  }) : super(repaint: SoftPrograms.instance);

  final BorderRadius radius;
  final SoftGlassRim rim;
  final bool smooth;

  @override
  void paint(Canvas canvas, Size size) {
    paintSoftGlassRim(canvas, size, radius, rim, smooth: smooth);
  }

  @override
  bool shouldRepaint(_GlassRimPainter old) =>
      old.radius != radius || old.rim != rim || old.smooth != smooth;
}
