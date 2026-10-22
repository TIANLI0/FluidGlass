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
    this.compositor = false,
    this.extension = SoftMetaBallDefaults.extension,
    this.extensionFactorX = SoftMetaBallDefaults.extensionFactorX,
    this.extensionFactorY = SoftMetaBallDefaults.extensionFactorY,
  });

  /// Whether the body is frosted. False draws each shape opaque in [color]
  /// and merges nothing.
  final bool blur;

  /// Whether, without a [backdrop], the body is frosted by the compositor —
  /// a `BackdropFilter` clipped to the merged outline, as [SoftGlass] frosts
  /// a single surface — rather than painted opaque. The outline is traced
  /// on the CPU ([softMetaBallPath]) and its lit edge drawn over it, so the
  /// silhouettes still melt together with no page capture at all. With
  /// [blur] off the merged outline is filled opaque in [color].
  final bool compositor;
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

  /// The compositor route: the merged outline traced into a path, the
  /// compositor's blur clipped to it, the lit edge laid over it.
  ///
  /// A clip is all or nothing, so a silhouette that is fading cannot share
  /// the opaque outline: the opaque ones are merged into one body, and what
  /// the fading ones add to the merged outline is a second body drawn at
  /// their opacity.
  Widget _buildCompositor(
    BuildContext context,
    List<SoftMetaBallParticle> shown,
    List<SoftCausticProfile> profiles,
    Color tint,
    double rim,
  ) {
    final double dpr = MediaQuery.devicePixelRatioOf(context);
    Path trace(List<SoftMetaBallParticle> ps) => softMetaBallPath(
      ps,
      devicePixelRatio: dpr,
      extension: extension,
      extensionFactorX: extensionFactorX,
      extensionFactorY: extensionFactorY,
    );
    final List<SoftMetaBallParticle> live = <SoftMetaBallParticle>[
      for (final SoftMetaBallParticle p in shown)
        if (p.alpha > 0.001) p,
    ];
    List<SoftMetaBallParticle> solid = <SoftMetaBallParticle>[
      for (final SoftMetaBallParticle p in live)
        if (p.alpha >= 0.999) p,
    ];
    double fadeAlpha = 0;
    for (final SoftMetaBallParticle p in live) {
      if (p.alpha < 0.999) fadeAlpha = math.max(fadeAlpha, p.alpha);
    }
    double bodyAlpha = 1;
    if (solid.isEmpty) {
      // Everything is fading: one body at the strongest opacity.
      solid = live;
      bodyAlpha = fadeAlpha;
      fadeAlpha = 0;
    }
    final Path outline = trace(live);
    final Path body = solid.length == live.length ? outline : trace(solid);
    final Path? fading = fadeAlpha > 0
        ? Path.combine(PathOperation.difference, outline, body)
        : null;
    Widget frost(Path path) => SoftGlass(
      shape: _PathBorder(path),
      borderRadius: BorderRadius.zero,
      blur: blur,
      color: tint,
      containerAlpha: containerAlpha,
      blurRadius: blurRadius,
      layers: layers,
      rim: const SoftGlassRim(alpha: 0),
    );
    Widget bodyLayer = frost(body);
    if (bodyAlpha < 1) {
      bodyLayer = Opacity(opacity: bodyAlpha, child: bodyLayer);
    }
    return IgnorePointer(
      child: Stack(
        fit: StackFit.passthrough,
        clipBehavior: Clip.none,
        children: <Widget>[
          Positioned.fill(
            child: CustomPaint(
              painter: _BehindPainter(
                particles: shown,
                profiles: profiles,
                shadow: shadow,
                caustic: causticColor,
                background: SoftTheme.of(context).colors.background,
                dpr: dpr,
                outline: outline,
                repaint: Listenable.merge(<Listenable?>[
                  repaint,
                  SoftPrograms.instance,
                ]),
              ),
            ),
          ),
          Positioned.fill(child: bodyLayer),
          if (fading != null)
            Positioned.fill(
              child: Opacity(opacity: fadeAlpha, child: frost(fading)),
            ),
          Positioned.fill(
            child: CustomPaint(
              painter: _MergedEdgePainter(
                particles: shown,
                dpr: dpr,
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
      ),
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
    if (compositor && source == null && shown.isNotEmpty) {
      return _buildCompositor(context, shown, profiles, tint, rim);
    }
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
    this.outline,
    super.repaint,
  });

  /// The merged outline, when it is known; otherwise the particles' own.
  final Path? outline;
  final List<SoftMetaBallParticle> particles;
  final List<SoftCausticProfile> profiles;
  final SoftParticleShadow? shadow;
  final Color? caustic;
  final Color background;
  final double dpr;

  @override
  void paint(Canvas canvas, Size size) {
    if (particles.isEmpty) return;
    final Path union = outline ?? Path();
    if (outline == null) {
      for (final SoftMetaBallParticle p in particles) {
        if (p.alpha > 0) union.addPath(p.path, Offset.zero);
      }
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
      old.dpr != dpr ||
      old.outline != outline;
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

// ---------------------------------------------------------------------------
// The merged silhouette as a path, for a body the compositor frosts.
//
// The captured route above evaluates the union per fragment and samples a
// [LayerBackdrop]. A bar that blurs with the compositor instead (a
// `BackdropFilter`, no page capture) cannot hand the filter a per-pixel
// mask, so the same field is traced on the CPU into a [Path] and the
// compositor's blur is clipped to it; the lit edge is drawn over it by
// soft_meta_ball_edge.frag, which evaluates that same field per fragment.
// ---------------------------------------------------------------------------

/// The signed distance of the merged silhouette at a point, in logical
/// pixels: the union soft_meta_ball.frag evaluates, in the same order, with
/// the same direction-dependent reach.
class _MergedField {
  _MergedField(
    this.particles, {
    required double extension,
    required this.factorX,
    required this.factorY,
    required double devicePixelRatio,
  }) : reach =
           math.max(1.0, (extension * devicePixelRatio).roundToDouble()) /
           devicePixelRatio;

  final List<SoftMetaBallParticle> particles;

  /// The smoothing reach before the direction factor, in logical pixels.
  final double reach;
  final double factorX;
  final double factorY;

  /// The widest reach any pair can have.
  double get maxReach => reach * math.max(factorX, factorY);

  static double _box(double px, double py, double bx, double by, double r) {
    final double qx = px.abs() - bx + r;
    final double qy = py.abs() - by + r;
    final double ox = math.max(qx, 0.0);
    final double oy = math.max(qy, 0.0);
    return math.min(math.max(qx, qy), 0.0) + math.sqrt(ox * ox + oy * oy) - r;
  }

  double at(double x, double y) {
    double d = 1e6;
    double nx = 0;
    double ny = 0;
    bool has = false;
    for (final SoftMetaBallParticle p in particles) {
      final double sx = math.max(p.scaleX, 0.001);
      final double sy = math.max(p.scaleY, 0.001);
      final double hx = p.size.width / 2;
      final double hy = p.size.height / 2;
      final double di = _box(
        (x - p.center.dx) / sx,
        (y - p.center.dy) / sy,
        hx,
        hy,
        math.min(p.cornerRadius, math.min(hx, hy)),
      );
      if (!has) {
        d = di;
        nx = p.center.dx;
        ny = p.center.dy;
        has = true;
        continue;
      }
      final double dx = p.center.dx - nx;
      final double dy = p.center.dy - ny;
      final double len = math.sqrt(dx * dx + dy * dy);
      final double ux = len > 0.001 ? dx / len : 0.7071;
      final double uy = len > 0.001 ? dy / len : 0.7071;
      final double fx = factorX * ux;
      final double fy = factorY * uy;
      final double k = math.max(reach * math.sqrt(fx * fx + fy * fy), 1e-4);
      final double prev = d;
      final double h = (0.5 + 0.5 * (di - d) / k).clamp(0.0, 1.0);
      d = di + (d - di) * h - k * h * (1 - h);
      if (di < prev) {
        nx = p.center.dx;
        ny = p.center.dy;
      }
    }
    return d;
  }
}

/// Whether any two of [particles] come close enough for the union to bend
/// their outlines: overlapping, or nearer than the smoothing reach.
bool _interact(List<SoftMetaBallParticle> particles, double reach) {
  for (int i = 0; i < particles.length; i++) {
    for (int j = i + 1; j < particles.length; j++) {
      final Rect a = particles[i].rect;
      final Rect b = particles[j].rect;
      final double gx = math.max(
        0.0,
        math.max(a.left - b.right, b.left - a.right),
      );
      final double gy = math.max(
        0.0,
        math.max(a.top - b.bottom, b.top - a.bottom),
      );
      if (math.sqrt(gx * gx + gy * gy) < reach + 0.5) return true;
    }
  }
  return false;
}

/// The outline of [particles] merged as [SoftMetaBallSurface] merges them:
/// two rounded boxes that come within the smoothing reach of each other
/// grow a neck, and one that overlaps another bulges out of it smoothly.
///
/// Where no two of them are that close, this is just their outlines. Where
/// they are, the field is traced column by column: the silhouette of boxes
/// side by side is an interval in each column, so its top and bottom edges
/// are found by bisection — columns crowd towards the rounded ends, where
/// the outline turns vertical, so the caps stay round. It costs some tens of
/// thousands of distance evaluations per call; the bars only call it while a
/// round view is on its way in or out.
Path softMetaBallPath(
  List<SoftMetaBallParticle> particles, {
  required double devicePixelRatio,
  double extension = SoftMetaBallDefaults.extension,
  double extensionFactorX = SoftMetaBallDefaults.extensionFactorX,
  double extensionFactorY = SoftMetaBallDefaults.extensionFactorY,
  double step = 0.75,
}) {
  final Path path = Path();
  if (particles.isEmpty) return path;
  final _MergedField field = _MergedField(
    particles,
    extension: extension,
    factorX: extensionFactorX,
    factorY: extensionFactorY,
    devicePixelRatio: math.max(devicePixelRatio, 1),
  );
  if (particles.length == 1 || !_interact(particles, field.maxReach)) {
    for (final SoftMetaBallParticle p in particles) {
      final Rect r = p.rect;
      path.addRRect(
        RRect.fromRectAndRadius(
          r,
          Radius.circular(
            math.min(
              p.cornerRadius * math.min(p.scaleX, p.scaleY),
              r.shortestSide / 2,
            ),
          ),
        ),
      );
    }
    return path;
  }

  Rect bounds = particles.first.rect;
  for (final SoftMetaBallParticle p in particles.skip(1)) {
    bounds = bounds.expandToInclude(p.rect);
  }
  bounds = bounds.inflate(field.maxReach + 1);
  final List<double> rows = <double>[
    for (final SoftMetaBallParticle p in particles) p.center.dy,
  ];

  // The deepest of the particles' centre rows in a column, and its depth.
  (double, double) inner(double x) {
    double bestY = rows.first;
    double best = double.infinity;
    for (final double y in rows) {
      final double d = field.at(x, y);
      if (d < best) {
        best = d;
        bestY = y;
      }
    }
    return (bestY, best);
  }

  double edgeX(double outside, double inside) {
    double o = outside;
    double i = inside;
    for (int n = 0; n < 16; n++) {
      final double m = (o + i) / 2;
      if (inner(m).$2 < 0) {
        i = m;
      } else {
        o = m;
      }
    }
    return (o + i) / 2;
  }

  double edgeY(double x, double inside, double outside) {
    double i = inside;
    double o = outside;
    for (int n = 0; n < 16; n++) {
      final double m = (o + i) / 2;
      if (field.at(x, m) < 0) {
        i = m;
      } else {
        o = m;
      }
    }
    return (o + i) / 2;
  }

  // The runs of columns the silhouette covers.
  final List<(double, double)> runs = <(double, double)>[];
  double? runStart;
  double prevX = bounds.left;
  bool prevIn = false;
  for (double x = bounds.left; x <= bounds.right + step / 2; x += step) {
    final bool isIn = inner(x).$2 < 0;
    if (isIn && !prevIn) runStart = edgeX(prevX, x);
    if (!isIn && prevIn && runStart != null) {
      runs.add((runStart, edgeX(x, prevX)));
      runStart = null;
    }
    prevIn = isIn;
    prevX = x;
  }
  if (runStart != null) runs.add((runStart, prevX));

  final double reachY = bounds.height;
  for (final (double a, double b) in runs) {
    // Uniform columns, crowded towards either end along a quarter circle
    // so a round cap is sampled evenly by angle.
    final double cap = math.min(32.0, (b - a) / 2);
    const int capSteps = 20;
    final List<double> xs = <double>[
      for (int s = 1; s <= capSteps; s++)
        a + cap * (1 - math.cos(s / capSteps * math.pi / 2)),
      for (int s = 1; s <= capSteps; s++)
        b - cap * (1 - math.cos(s / capSteps * math.pi / 2)),
      for (double x = a + cap + step; x < b - cap; x += step) x,
    ]..sort();
    final List<Offset> top = <Offset>[];
    final List<Offset> bottom = <Offset>[];
    for (final double x in xs) {
      if (x <= a || x >= b) continue;
      final (double y, double d) = inner(x);
      if (d >= 0) continue;
      top.add(Offset(x, edgeY(x, y, y - reachY)));
      bottom.add(Offset(x, edgeY(x, y, y + reachY)));
    }
    path.moveTo(a, inner(a).$1);
    for (final Offset o in top) {
      path.lineTo(o.dx, o.dy);
    }
    path.lineTo(b, inner(b).$1);
    for (final Offset o in bottom.reversed) {
      path.lineTo(o.dx, o.dy);
    }
    path.close();
  }
  return path;
}

/// A [ShapeBorder] that is a fixed [path], in the box's own coordinates.
class _PathBorder extends ShapeBorder {
  const _PathBorder(this.path);

  final Path path;

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.zero;

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      path.shift(rect.topLeft);

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) =>
      path.shift(rect.topLeft);

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {}

  @override
  ShapeBorder scale(double t) => this;

  @override
  bool operator ==(Object other) =>
      other is _PathBorder && identical(other.path, path);

  @override
  int get hashCode => identityHashCode(path);
}

final Expando<ui.FragmentShader> _mergedEdgeShaders =
    Expando<ui.FragmentShader>();

/// The merged silhouette's lit edge: a white line over a body frosted by
/// the compositor.
class _MergedEdgePainter extends CustomPainter {
  _MergedEdgePainter({
    required this.particles,
    required this.dpr,
    required this.rim,
    required this.rimBottomScale,
    required this.style,
    required this.extension,
    required this.factorX,
    required this.factorY,
  }) : super(repaint: SoftPrograms.instance);

  final List<SoftMetaBallParticle> particles;
  final double dpr, rim, rimBottomScale, extension, factorX, factorY;
  final SoftEdgeStyle style;

  @override
  void paint(Canvas canvas, Size size) {
    if (rim <= 0 || particles.isEmpty) return;
    final ui.FragmentProgram? program = SoftPrograms.instance.metaBallEdge;
    if (program == null) return;
    final ui.FragmentShader shader = _mergedEdgeShaders[program] ??= program
        .fragmentShader();
    int i = 0;
    void put(double v) => shader.setFloat(i++, v);
    put(dpr);
    Rect bounds = particles.first.rect;
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
      bounds = bounds.expandToInclude(p.rect);
      final double w = p.size.width * dpr;
      final double h = p.size.height * dpr;
      put(p.center.dx * dpr);
      put(p.center.dy * dpr);
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
    put(math.max(1.0, (extension * dpr).roundToDouble()));
    put(factorX);
    put(factorY);
    put(style.lineAlpha[0] * rim);
    put(style.lineAlpha[1] * rim);
    put(style.para1);
    put(style.para2);
    put(style.angle);
    put(rimBottomScale);
    put(1);
    put(1);
    put(1);
    put(1);
    canvas.drawRect(bounds.inflate(2), Paint()..shader = shader);
  }

  @override
  bool shouldRepaint(_MergedEdgePainter old) =>
      !_listEquals(old.particles, particles) ||
      old.dpr != dpr ||
      old.rim != rim ||
      old.rimBottomScale != rimBottomScale ||
      old.style != style ||
      old.extension != extension ||
      old.factorX != factorX ||
      old.factorY != factorY;
}
