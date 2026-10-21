import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import '../../backdrop.dart';
import '../../backdrop_effect_scope.dart';
import '../../draw_backdrop.dart';
import '../../effects/blur.dart';
import '../../effects/custom_effect.dart';
import '../../quality/glass_device_tier.dart';
import '../../quality/glass_quality.dart';
import '../../shapes/rounded_rectangular_shape.dart';
import 'soft_glass.dart';
import 'soft_programs.dart';
import 'soft_squircle.dart';
import 'soft_theme.dart';

/// One silhouette in a [SoftMetaBallSurface]: a rounded box centred at
/// [center], scaled about its centre, in the surface's coordinates.
@immutable
class SoftMetaBallParticle {
  const SoftMetaBallParticle({
    required this.center,
    required this.size,
    double? cornerRadius,
    this.scaleX = 1,
    this.scaleY = 1,
    this.alpha = 1,
  }) : _cornerRadius = cornerRadius;

  final Offset center;
  final Size size;
  final double? _cornerRadius;
  final double scaleX;
  final double scaleY;
  final double alpha;

  /// Half the shorter side by default: a capsule, or a circle.
  double get cornerRadius => _cornerRadius ?? size.shortestSide / 2;

  /// The box as drawn, with its scale applied.
  Rect get rect => Rect.fromCenter(
    center: center,
    width: size.width * scaleX,
    height: size.height * scaleY,
  );

  /// The drawn outline.
  Path get path => softSquirclePath(
    rect,
    BorderRadius.circular(
      math.min(cornerRadius * math.min(scaleX, scaleY), rect.shortestSide / 2),
    ),
    smooth: false,
  );

  @override
  bool operator ==(Object other) =>
      other is SoftMetaBallParticle &&
      other.center == center &&
      other.size == size &&
      other._cornerRadius == _cornerRadius &&
      other.scaleX == scaleX &&
      other.scaleY == scaleY &&
      other.alpha == alpha;

  @override
  int get hashCode =>
      Object.hash(center, size, _cornerRadius, scaleX, scaleY, alpha);
}

/// A rim profile: two lines along the perimeter — a near one and a far one,
/// each a band inside the outline — that fade in and out along the
/// perimeter.
@immutable
class SoftEdgeStyle {
  const SoftEdgeStyle({
    required this.lineSize,
    required this.lineNear,
    required this.lineFar,
    required this.lineAlpha,
    required this.lineFade,
    this.angle = 0,
    this.para1 = 4,
    this.para2 = 0.8,
  });

  final List<double> lineSize;
  final List<double> lineNear;
  final List<double> lineFar;
  final List<double> lineAlpha;
  final List<double> lineFade;
  final double angle;
  final double para1;
  final double para2;

  /// The capsule rim.
  static const SoftEdgeStyle capsule = SoftEdgeStyle(
    lineSize: <double>[400, 100],
    lineNear: <double>[2, 6],
    lineFar: <double>[2, 3],
    lineAlpha: <double>[0.7, 1],
    lineFade: <double>[0.2, 0.4, 0.15, 0.35],
  );

  /// The compact icon-button rim.
  static const SoftEdgeStyle iconButton = SoftEdgeStyle(
    lineSize: <double>[160, 160],
    lineNear: <double>[2, 6],
    lineFar: <double>[2, 3],
    lineAlpha: <double>[0.7, 1],
    lineFade: <double>[0.06, 0.4, 0.01, 0.28],
  );

  /// The large panel rim.
  static const SoftEdgeStyle panel = SoftEdgeStyle(
    lineSize: <double>[600, 200],
    lineNear: <double>[2, 8],
    lineFar: <double>[2, 2],
    lineAlpha: <double>[0.7, 0.6],
    lineFade: <double>[0.18, 0.35, 0.25, 0.25],
  );

  /// The near/far bands (device px, already accumulated) and the fade
  /// fractions for a [widthPx] × [heightPx] shape.
  (List<double> line, List<double> fade) resolve(
    double widthPx,
    double heightPx, {
    required double lineWidthPx,
    required double density,
  }) {
    final double factor = math.max(1.0, density) * 0.34;
    final double nearX = lineNear[0];
    final double nearY = lineNear[1];
    final double farX = lineFar[0];
    final double farY = lineFar[1];
    final double sizeX = math.max(1.0, widthPx) / factor;
    final double sizeY = math.max(1.0, heightPx) / factor;
    final double baseW = math.max(lineSize[0], 1.0);
    final double baseH = math.max(lineSize[1], 1.0);
    final double divisor = math.max(math.max(nearX + nearY, farX + farY), 1e-4);
    final double lineFactor =
        (lineWidthPx > 0 ? lineWidthPx : divisor) / divisor;
    final double n0 = math.max(nearX * lineFactor, 2.0);
    final double n1 = math.max(nearY * lineFactor, 2.0) + n0;
    final double f0 = math.max(farX * lineFactor, 2.0);
    final double f1 = math.max(farY * lineFactor, 2.0) + f0;
    final List<double> fade = List<double>.filled(4, 0);
    _fadeForSize(lineFade[0], lineFade[1], baseW, baseH, sizeX, sizeY, fade, 0);
    _fadeForSize(lineFade[2], lineFade[3], baseW, baseH, sizeX, sizeY, fade, 2);
    fade[1] += fade[0];
    fade[3] += fade[2];
    return (<double>[n0, n1, f0, f1], fade);
  }

  static void _fadeForSize(
    double baseFadeX,
    double baseFadeY,
    double baseW,
    double baseH,
    double w,
    double h,
    List<double> out,
    int offset,
  ) {
    final double basePerimeter = (baseH + baseW) * 2;
    final double perimeter = (h + w) * 2;
    final double fadeSum = baseFadeX + baseFadeY;
    final double faded = fadeSum * basePerimeter;
    if (faded > baseW) {
      final double farFade = baseFadeY * basePerimeter;
      out[offset] = (((faded - baseW) + w) - farFade) / perimeter;
      out[offset + 1] = farFade / perimeter;
      return;
    }
    final double remaining = baseW - faded;
    if (fadeSum <= 0) {
      out[offset] = baseFadeX;
      out[offset + 1] = baseFadeY;
    } else {
      final double fraction = (w - remaining) / perimeter;
      out[offset] = (baseFadeX * fraction) / fadeSum;
      out[offset + 1] = (baseFadeY * fraction) / fadeSum;
    }
  }
}

/// A shadow cast by each particle, outside its outline only.
@immutable
class SoftParticleShadow {
  const SoftParticleShadow({
    this.color = const Color(0x1E000000),
    this.blurRadius = 6,
    this.offset = const Offset(0, 2),
  });

  final Color color;
  final double blurRadius;
  final Offset offset;
}

/// The caustic profile of a particle: how far below it the light reaches and
/// how wide its band is.
@immutable
class SoftCausticProfile {
  const SoftCausticProfile(this.bottomOffset, this.sdfWidth);

  final double bottomOffset;
  final double sdfWidth;

  static const SoftCausticProfile bar = SoftCausticProfile(4.899994, 10.399994);
  static const SoftCausticProfile accessory = SoftCausticProfile(11.199982, 20);
  static const SoftCausticProfile toolbar = SoftCausticProfile(
    4.899994,
    9.22998,
  );
}

/// The merged-silhouette defaults.
abstract final class SoftMetaBallDefaults {
  /// How far apart two silhouettes start reaching for each other.
  static const double extension = 4;
  static const double extensionFactorX = 1.5;
  static const double extensionFactorY = 2;

  /// The most silhouettes one surface merges.
  static const int maxParticles = 4;

  /// Room the surface keeps around its particles for a press to move them.
  static const double paintOutset = 40;
}

/// Several silhouettes drawn as one frosted body.
///
/// The backdrop behind them is blurred and tinted with [color] at
/// [containerAlpha]; the silhouettes are joined by a smooth minimum, so two
/// of them that come close grow a neck and melt into each other. The rim is
/// lit with [edgeStyle] at [rimAlpha]. Each particle casts [shadow] and, with
/// [causticColor], a caustic band below it.
///
/// The merging needs a captured [backdrop] (a [LayerBackdrop]) and a device
/// whose glass tier runs fragment programs; elsewhere the particles are
/// drawn as separate frosted shapes over the compositor's blur.
class SoftMetaBallSurface extends StatelessWidget {
  const SoftMetaBallSurface({
    super.key,
    required this.particles,
    this.backdrop,
    this.color,
    this.containerAlpha = SoftGlassDefaults.containerAlpha,
    this.blurRadius = SoftGlassDefaults.blurRadius,
    this.rimAlpha,
    this.rimBottomScale = 1,
    this.edgeStyle = SoftEdgeStyle.capsule,
    this.shadow = const SoftParticleShadow(),
    this.causticColor = const Color(0x42FFFFFF),
    this.causticProfiles,
    this.quality,
    this.repaint,
    this.layers,
    this.blur = true,
    this.extension = SoftMetaBallDefaults.extension,
    this.extensionFactorX = SoftMetaBallDefaults.extensionFactorX,
    this.extensionFactorY = SoftMetaBallDefaults.extensionFactorY,
  });

  /// Whether the body is frosted. False draws each shape opaque in [color]
  /// and merges nothing.
  final bool blur;
  final double extension, extensionFactorX, extensionFactorY;

  /// Tint layers that replace [color] at [containerAlpha] over the blur, as
  /// [SoftGlass.layers] does on a single surface: the floating bar's own
  /// material, so a capsule looks the same whether round views melt into
  /// it or not.
  final List<SoftBlendLayer>? layers;

  final List<SoftMetaBallParticle> particles;

  /// The captured content to blur. Without one the shapes are not merged.
  final Backdrop? backdrop;

  /// The tint; the theme's `bar` colour by default.
  final Color? color;
  final double containerAlpha;

  /// The blur radius (sigma = 0.45 · radius).
  final double blurRadius;

  /// The rim's strength: 0.25 on the light theme, 0.8 on the dark one by
  /// default.
  final double? rimAlpha;

  /// How much of the rim's lower half is drawn.
  final double rimBottomScale;
  final SoftEdgeStyle edgeStyle;
  final SoftParticleShadow? shadow;

  /// The caustic light below the shapes; none when null.
  final Color? causticColor;

  /// The caustic profile per particle; squares use the accessory profile and
  /// anything else the bar profile by default.
  final List<SoftCausticProfile>? causticProfiles;

  /// Pins the glass tier for this surface.
  final GlassQuality? quality;

  /// Repaints the surface when it fires, for particles that move without a
  /// rebuild.
  final Listenable? repaint;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge(<Listenable>[
        SoftPrograms.instance,
        GlassDeviceTier.instance,
      ]),
      builder: _build,
    );
  }

  Widget _build(BuildContext context, Widget? _) {
    final SoftThemeData theme = SoftTheme.of(context);
    final Color tint = color ?? theme.colors.bar;
    final double rim = rimAlpha ?? (theme.isDark ? 0.8 : 0.25);
    final GlassDeviceTier tier = GlassDeviceTier.instance;
    final GlassQuality? pinned = quality;
    final GlassQuality resolved = pinned == null
        ? tier.quality
        : pinned.atMost(tier.ceiling);
    final ui.FragmentProgram? program = resolved.hasShaders
        ? SoftPrograms.instance.metaBall
        : null;
    final Backdrop? source = blur ? backdrop : null;
    final List<SoftMetaBallParticle> shown = particles
        .take(SoftMetaBallDefaults.maxParticles)
        .toList();
    final List<SoftCausticProfile> profiles = <SoftCausticProfile>[
      for (int i = 0; i < shown.length; i++)
        causticProfiles != null && i < causticProfiles!.length
            ? causticProfiles![i]
            : (shown[i].size.width == shown[i].size.height
                  ? SoftCausticProfile.accessory
                  : SoftCausticProfile.bar),
    ];
    final Widget behind = IgnorePointer(
      child: CustomPaint(
        size: Size.infinite,
        painter: _BehindPainter(
          particles: shown,
          profiles: profiles,
          shadow: shadow,
          caustic: causticColor,
          background: theme.colors.background,
          dpr: MediaQuery.devicePixelRatioOf(context),
          repaint: Listenable.merge(<Listenable?>[
            repaint,
            SoftPrograms.instance,
          ]),
        ),
      ),
    );
    if (blur && source == null && program != null && shown.isNotEmpty) {
      return Stack(
        fit: StackFit.passthrough,
        children: <Widget>[
          Positioned.fill(child: behind),
          Positioned.fill(
            child: CustomPaint(
              painter: _OpaqueMetaPainter(
                program: program,
                particles: shown,
                tint: tint,
                dpr: MediaQuery.devicePixelRatioOf(context),
                rim: rim,
                rimBottomScale: rimBottomScale,
                style: edgeStyle,
                extension: extension,
                factorX: extensionFactorX,
                factorY: extensionFactorY,
              ),
            ),
          ),
        ],
      );
    }
    if (!blur || program == null || shown.isEmpty) {
      // MetaBallSurface.kt's non-shader branch is one opaque canvas. Painting
      // translucent glass once per particle incorrectly exposes hidden cells.
      return Stack(
        fit: StackFit.passthrough,
        children: <Widget>[
          Positioned.fill(child: behind),
          Positioned.fill(
            child: CustomPaint(painter: _UnmergedOpaquePainter(shown, tint)),
          ),
        ],
      );
    }
    Rect bounds = shown.first.rect;
    for (final SoftMetaBallParticle p in shown.skip(1)) {
      bounds = bounds.expandToInclude(p.rect);
    }
    bounds = bounds.inflate(extension * 4 + 2);
    final double dpr = MediaQuery.devicePixelRatioOf(context);
    final double sigma = SoftGlassDefaults.sigmaOf(blurRadius);
    // The effect scope's blur takes a radius and converts it the platform
    // way; hand it the radius that lands on the sigma the reference uses.
    final double scopeRadius = math.max(
      0.0,
      (sigma * dpr - 0.5) / (0.57735 * dpr),
    );
    return Stack(
      clipBehavior: Clip.none,
      fit: StackFit.passthrough,
      children: <Widget>[
        Positioned.fill(child: behind),
        Positioned.fromRect(
          rect: bounds,
          child: IgnorePointer(
            child: DrawBackdrop.plain(
              backdrop: source!,
              shape: () => const Rectangle(),
              isolateSurface: false,
              receivesLight: false,
              quality: resolved,
              repaint: repaint,
              effects: (BackdropEffectScope scope) {
                if (scopeRadius > 0) scope.blur(scopeRadius);
                scope.fragmentShaderEffect('SoftMetaBall', program, (
                  ui.FragmentShader shader,
                  BackdropEffectGeometry geometry,
                ) {
                  _configure(
                    shader,
                    geometry,
                    bounds.topLeft,
                    shown,
                    dpr: dpr,
                    tint: tint,
                    containerAlpha: containerAlpha,
                    rimAlpha: rim,
                    rimBottomScale: rimBottomScale,
                    style: edgeStyle,
                    layers: layers,
                    extension: extension,
                    factorX: extensionFactorX,
                    factorY: extensionFactorY,
                  );
                });
              },
              child: const SizedBox.expand(),
            ),
          ),
        ),
      ],
    );
  }
}

void _configure(
  ui.FragmentShader shader,
  BackdropEffectGeometry geometry,
  Offset origin,
  List<SoftMetaBallParticle> particles, {
  required double dpr,
  required Color tint,
  required double containerAlpha,
  required double rimAlpha,
  required double rimBottomScale,
  required SoftEdgeStyle style,
  List<SoftBlendLayer>? layers,
  double extension = SoftMetaBallDefaults.extension,
  double factorX = SoftMetaBallDefaults.extensionFactorX,
  double factorY = SoftMetaBallDefaults.extensionFactorY,
}) {
  int i = 0;
  void put(double v) => shader.setFloat(i++, v);
  // Floats 0..1 are uTextureSize, which the engine overwrites.
  put(0);
  put(0);
  put(geometry.layerSize.width);
  put(geometry.layerSize.height);
  put(geometry.offset.dx);
  put(geometry.offset.dy);
  put(dpr);
  for (int slot = 0; slot < SoftMetaBallDefaults.maxParticles; slot++) {
    final SoftMetaBallParticle? p = slot < particles.length
        ? particles[slot]
        : null;
    if (p == null) {
      for (int k = 0; k < 16; k++) {
        put(0);
      }
      continue;
    }
    final Offset c = (p.center - origin) * dpr;
    final double w = p.size.width * dpr;
    final double h = p.size.height * dpr;
    put(c.dx);
    put(c.dy);
    put(w / 2);
    put(h / 2);
    put(p.cornerRadius * dpr);
    put(p.scaleX);
    put(p.scaleY);
    put(p.alpha.clamp(0.0, 1.0));
    final (List<double> line, List<double> fade) = style.resolve(
      w,
      h,
      lineWidthPx: 2.5 * dpr,
      density: dpr,
    );
    line.forEach(put);
    fade.forEach(put);
  }
  put(particles.length.toDouble());
  // A whole number of pixels, at least one, as the reference sizes it.
  put(math.max(1.0, (extension * dpr).roundToDouble()));
  put(factorX);
  put(factorY);
  put(style.lineAlpha[0] * rimAlpha);
  put(style.lineAlpha[1] * rimAlpha);
  put(style.para1);
  put(style.para2);
  put(style.angle);
  put(tint.r);
  put(tint.g);
  put(tint.b);
  put(tint.a * containerAlpha);
  put(1);
  put(1);
  put(1);
  put(1);
  put(rimBottomScale);
  double mode(BlendMode m) => switch (m) {
    BlendMode.colorDodge => 1,
    BlendMode.luminosity => 2,
    BlendMode.overlay => 3,
    _ => 0,
  };
  final List<SoftBlendLayer> tints = layers ?? const <SoftBlendLayer>[];
  for (int k = 0; k < 2; k++) {
    final SoftBlendLayer? layer = k < tints.length ? tints[k] : null;
    put(layer?.color.r ?? 0);
    put(layer?.color.g ?? 0);
    put(layer?.color.b ?? 0);
    put(layer?.color.a ?? 0);
  }
  for (int k = 0; k < 2; k++) {
    put(k < tints.length ? mode(tints[k].blendMode) : 0);
  }
  put(tints.length.clamp(0, 2).toDouble());
}

final Expando<ui.FragmentShader> _causticShaders = Expando<ui.FragmentShader>();
final Expando<ui.FragmentShader> _edgeShaders = Expando<ui.FragmentShader>();

/// Paints the lit edge of a single capsule over `Offset.zero & size`: the
/// [style] rim at [alpha] (0.25 on the light theme, 0.8 on the dark one for
/// a bar), a [lineWidth]-wide white line laid over the surface. The merged
/// body of [SoftMetaBallSurface] lights its rim the same way.
void paintSoftCapsuleEdge(
  Canvas canvas,
  Size size, {
  required double cornerRadius,
  required double alpha,
  required double devicePixelRatio,
  SoftEdgeStyle style = SoftEdgeStyle.capsule,
  double lineWidth = 2.5,
  Color color = const Color(0xFFFFFFFF),
}) {
  if (alpha <= 0 || size.isEmpty) return;
  final ui.FragmentProgram? program = SoftPrograms.instance.capsuleEdge;
  if (program == null) return;
  final ui.FragmentShader shader = _edgeShaders[program] ??= program
      .fragmentShader();
  final double dpr = devicePixelRatio;
  final (List<double> line, List<double> fade) = style.resolve(
    size.width * dpr,
    size.height * dpr,
    lineWidthPx: lineWidth * dpr,
    density: dpr,
  );
  int i = 0;
  void put(double v) => shader.setFloat(i++, v);
  put(size.width);
  put(size.height);
  put(dpr);
  put(cornerRadius);
  line.forEach(put);
  fade.forEach(put);
  put(style.lineAlpha[0] * alpha);
  put(style.lineAlpha[1] * alpha);
  put(style.para1);
  put(style.para2);
  put(style.angle);
  put(color.r);
  put(color.g);
  put(color.b);
  put(color.a);
  canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
}

/// Paints the caustic light below a shape of [size] centred on [center] and
/// scaled about it: a faint band of [color] under its lower edge, dimmed
/// over a light [background]. The band's dimensions are snapped to whole
/// device pixels, as the reference lays them out.
void paintSoftCaustic(
  Canvas canvas, {
  required Offset center,
  required Size size,
  required double cornerRadius,
  required SoftCausticProfile profile,
  required Color color,
  required Color background,
  required double devicePixelRatio,
  double scaleX = 1,
  double scaleY = 1,
  double alpha = 1,
}) {
  if (alpha <= 0 || size.isEmpty) return;
  final ui.FragmentProgram? program = SoftPrograms.instance.caustic;
  if (program == null) return;
  final ui.FragmentShader shader = _causticShaders[program] ??= program
      .fragmentShader();
  final double dpr = math.max(devicePixelRatio, 1);
  final Size half = Size(size.width / 2, size.height / 2);
  final double bottom = (profile.bottomOffset * dpr).floorToDouble() / dpr;
  final double sdf = (profile.sdfWidth * dpr).floorToDouble() / dpr;
  shader
    ..setFloat(0, half.width)
    ..setFloat(1, half.height)
    ..setFloat(2, cornerRadius * 1.41421356)
    ..setFloat(3, bottom)
    ..setFloat(4, sdf)
    ..setFloat(5, color.r)
    ..setFloat(6, color.g)
    ..setFloat(7, color.b)
    ..setFloat(8, color.a * alpha)
    ..setFloat(9, background.r)
    ..setFloat(10, background.g)
    ..setFloat(11, background.b);
  canvas.save();
  canvas.translate(center.dx, center.dy);
  canvas.scale(scaleX, scaleY);
  canvas.translate(-half.width, -half.height);
  canvas.drawRect(
    Rect.fromLTWH(0, 0, half.width * 2, half.height * 2 + bottom),
    Paint()
      ..shader = shader
      ..blendMode = BlendMode.plus,
  );
  canvas.restore();
}

/// The shadows and caustic bands, drawn outside the particles only: the
/// frosted body covers whatever falls inside them, and the body samples a
/// backdrop that does not contain them.
class _BehindPainter extends CustomPainter {
  _BehindPainter({
    required this.particles,
    required this.profiles,
    required this.shadow,
    required this.caustic,
    required this.background,
    required this.dpr,
    super.repaint,
  });

  final List<SoftMetaBallParticle> particles;
  final List<SoftCausticProfile> profiles;
  final SoftParticleShadow? shadow;
  final Color? caustic;
  final Color background;
  final double dpr;

  @override
  void paint(Canvas canvas, Size size) {
    if (particles.isEmpty) return;
    final Path union = Path();
    for (final SoftMetaBallParticle p in particles) {
      if (p.alpha > 0) union.addPath(p.path, Offset.zero);
    }
    canvas.save();
    final Rect everything = Rect.fromLTWH(-4000, -4000, 8000, 8000);
    canvas.clipPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(everything),
        union,
      ),
    );
    final SoftParticleShadow? s = shadow;
    if (s != null) {
      for (final SoftMetaBallParticle p in particles) {
        if (p.alpha <= 0) continue;
        canvas.drawPath(
          p.path.shift(s.offset),
          Paint()
            ..color = s.color.withValues(alpha: s.color.a * p.alpha)
            ..maskFilter = MaskFilter.blur(
              BlurStyle.normal,
              s.blurRadius * 0.57735 + 0.5,
            ),
        );
      }
    }
    final Color? light = caustic;
    if (light != null) {
      for (int i = 0; i < particles.length; i++) {
        final SoftMetaBallParticle p = particles[i];
        paintSoftCaustic(
          canvas,
          center: p.center,
          size: p.size,
          cornerRadius: p.cornerRadius,
          profile: profiles[i],
          color: light,
          background: background,
          devicePixelRatio: dpr,
          scaleX: p.scaleX,
          scaleY: p.scaleY,
          alpha: p.alpha,
        );
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_BehindPainter old) =>
      !_listEquals(old.particles, particles) ||
      old.shadow != shadow ||
      old.caustic != caustic ||
      old.background != background ||
      old.dpr != dpr;
}

bool _listEquals<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (int i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

// Like MetaBallSurface.kt, the opaque branch still evaluates the merged SDF.
// A shared white sampler lets the same program draw it without a backdrop.
ui.Image? _opaqueMetaSampler;
final Expando<ui.FragmentShader> _opaqueMetaShaders =
    Expando<ui.FragmentShader>();

class _OpaqueMetaPainter extends CustomPainter {
  _OpaqueMetaPainter({
    required this.program,
    required this.particles,
    required this.tint,
    required this.dpr,
    required this.rim,
    required this.rimBottomScale,
    required this.style,
    required this.extension,
    required this.factorX,
    required this.factorY,
  });
  final ui.FragmentProgram program;
  final List<SoftMetaBallParticle> particles;
  final Color tint;
  final double dpr, rim, rimBottomScale, extension, factorX, factorY;
  final SoftEdgeStyle style;
  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    if (_opaqueMetaSampler == null) {
      final ui.PictureRecorder recorder = ui.PictureRecorder();
      Canvas(recorder).drawRect(
        const Rect.fromLTWH(0, 0, 1, 1),
        Paint()..color = const Color(0xFFFFFFFF),
      );
      final ui.Picture picture = recorder.endRecording();
      _opaqueMetaSampler = picture.toImageSync(1, 1);
      picture.dispose();
    }
    final ui.FragmentShader shader = _opaqueMetaShaders[program] ??= program
        .fragmentShader();
    _configure(
      shader,
      BackdropEffectGeometry(size: size, padding: 0),
      Offset.zero,
      particles,
      dpr: dpr,
      tint: tint,
      containerAlpha: 1,
      rimAlpha: rim,
      rimBottomScale: rimBottomScale,
      style: style,
      extension: extension,
      factorX: factorX,
      factorY: factorY,
    );
    shader
      ..setFloat(0, size.width)
      ..setFloat(1, size.height)
      ..setImageSampler(0, _opaqueMetaSampler!);
    canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
  }

  @override
  bool shouldRepaint(_OpaqueMetaPainter old) =>
      old.particles != particles ||
      old.tint != tint ||
      old.dpr != dpr ||
      old.rim != rim ||
      old.rimBottomScale != rimBottomScale ||
      old.style != style ||
      old.extension != extension ||
      old.factorX != factorX ||
      old.factorY != factorY;
}

class _UnmergedOpaquePainter extends CustomPainter {
  const _UnmergedOpaquePainter(this.particles, this.color);
  final List<SoftMetaBallParticle> particles;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint();
    for (final SoftMetaBallParticle particle in particles) {
      paint.color = color.withValues(
        alpha: color.a * particle.alpha.clamp(0, 1),
      );
      canvas.drawPath(particle.path, paint);
    }
  }

  @override
  bool shouldRepaint(_UnmergedOpaquePainter old) =>
      old.particles != particles || old.color != color;
}
