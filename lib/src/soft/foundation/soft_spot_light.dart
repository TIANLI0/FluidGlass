import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import 'soft_programs.dart';

/// One preset of the press spotlight.
///
/// [startRadius], [endRadius] and [lightHeight] are raw physical pixels, as
/// in the reference presets; [paintSoftSpotLight] divides them by the device
/// pixel ratio.
@immutable
class SoftSpotLightParams {
  const SoftSpotLightParams({
    required this.blendMode,
    required this.startIntensity,
    required this.endIntensity,
    required this.startRadius,
    required this.endRadius,
    required this.lightHeight,
    required this.ambientStrength,
    required this.diffuseStrength,
    required this.ditherN,
    required this.noise,
  });

  final BlendMode blendMode;
  final double startIntensity;
  final double endIntensity;
  final double startRadius;
  final double endRadius;
  final double lightHeight;
  final double ambientStrength;
  final double diffuseStrength;
  final double ditherN;
  final double noise;

  SoftSpotLightParams copyWith({BlendMode? blendMode, double? endIntensity}) {
    return SoftSpotLightParams(
      blendMode: blendMode ?? this.blendMode,
      startIntensity: startIntensity,
      endIntensity: endIntensity ?? this.endIntensity,
      startRadius: startRadius,
      endRadius: endRadius,
      lightHeight: lightHeight,
      ambientStrength: ambientStrength,
      diffuseStrength: diffuseStrength,
      ditherN: ditherN,
      noise: noise,
    );
  }

  /// Popups.
  static const SoftSpotLightParams translucentLarge1Light = SoftSpotLightParams(
    blendMode: BlendMode.overlay,
    startIntensity: 0,
    endIntensity: 0.6,
    startRadius: 100,
    endRadius: 800,
    lightHeight: 200,
    ambientStrength: 0.4,
    diffuseStrength: 0.4,
    ditherN: 0,
    noise: 0.08,
  );
  static const SoftSpotLightParams translucentLarge1Dark = SoftSpotLightParams(
    blendMode: BlendMode.overlay,
    startIntensity: 0,
    endIntensity: 0.1,
    startRadius: 100,
    endRadius: 800,
    lightHeight: 200,
    ambientStrength: 0.4,
    diffuseStrength: 0.4,
    ditherN: 0,
    noise: 0.08,
  );

  static const SoftSpotLightParams capsule1Light = SoftSpotLightParams(
    blendMode: BlendMode.overlay,
    startIntensity: 0,
    endIntensity: 1,
    startRadius: 100,
    endRadius: 400,
    lightHeight: 80,
    ambientStrength: 0.1,
    diffuseStrength: 0.5,
    ditherN: 0,
    noise: 0,
  );
  static const SoftSpotLightParams capsule1Dark = capsule1Light;

  /// The default for buttons and other capsules.
  static const SoftSpotLightParams capsule2Light = SoftSpotLightParams(
    blendMode: BlendMode.overlay,
    startIntensity: 0,
    endIntensity: 1,
    startRadius: 100,
    endRadius: 500,
    lightHeight: 200,
    ambientStrength: 0.4,
    diffuseStrength: 0.4,
    ditherN: 1,
    noise: 0.3,
  );
  static const SoftSpotLightParams capsule2Dark = SoftSpotLightParams(
    blendMode: BlendMode.plus,
    startIntensity: 0,
    endIntensity: 0.15,
    startRadius: 100,
    endRadius: 500,
    lightHeight: 200,
    ambientStrength: 0.4,
    diffuseStrength: 0.4,
    ditherN: 0,
    noise: 0.1,
  );

  /// The floating bottom navigation capsule.
  static const SoftSpotLightParams opaqueMedium2Light = SoftSpotLightParams(
    blendMode: BlendMode.overlay,
    startIntensity: 0,
    endIntensity: 1,
    startRadius: 100,
    endRadius: 500,
    lightHeight: 200,
    ambientStrength: 0.4,
    diffuseStrength: 0.4,
    ditherN: 0,
    noise: 0.08,
  );
  static const SoftSpotLightParams opaqueMedium2Dark = SoftSpotLightParams(
    blendMode: BlendMode.plus,
    startIntensity: 0,
    endIntensity: 0.15,
    startRadius: 100,
    endRadius: 500,
    lightHeight: 200,
    ambientStrength: 0.4,
    diffuseStrength: 0.4,
    ditherN: 0,
    noise: 0.08,
  );

  static const SoftSpotLightParams circle1Light = SoftSpotLightParams(
    blendMode: BlendMode.plus,
    startIntensity: 0,
    endIntensity: 0.2,
    startRadius: 100,
    endRadius: 600,
    lightHeight: 200,
    ambientStrength: 0.1,
    diffuseStrength: 0.5,
    ditherN: 0,
    noise: 0,
  );
  static const SoftSpotLightParams circle1Dark = circle1Light;

  static const SoftSpotLightParams roundRect1Light = SoftSpotLightParams(
    blendMode: BlendMode.plus,
    startIntensity: 0,
    endIntensity: 1.3,
    startRadius: 100,
    endRadius: 600,
    lightHeight: 120,
    ambientStrength: 0.2,
    diffuseStrength: 0.2,
    ditherN: 1,
    noise: 0.08,
  );
  static const SoftSpotLightParams roundRect1Dark = SoftSpotLightParams(
    blendMode: BlendMode.plus,
    startIntensity: 0,
    endIntensity: 0.4,
    startRadius: 0,
    endRadius: 600,
    lightHeight: 100,
    ambientStrength: 0.1,
    diffuseStrength: 0.5,
    ditherN: 1,
    noise: 0.02,
  );

  static const SoftSpotLightParams chipTabLight = SoftSpotLightParams(
    blendMode: BlendMode.plus,
    startIntensity: 0,
    endIntensity: 0.2,
    startRadius: 100,
    endRadius: 600,
    lightHeight: 200,
    ambientStrength: 0.1,
    diffuseStrength: 0.5,
    ditherN: 0,
    noise: 0,
  );
  static const SoftSpotLightParams chipTabDark = SoftSpotLightParams(
    blendMode: BlendMode.srcOver,
    startIntensity: 0,
    endIntensity: 0.3,
    startRadius: 100,
    endRadius: 600,
    lightHeight: 200,
    ambientStrength: 0.1,
    diffuseStrength: 0.5,
    ditherN: 0,
    noise: 0,
  );

  static SoftSpotLightParams translucentLarge1(bool dark) =>
      dark ? translucentLarge1Dark : translucentLarge1Light;
  static SoftSpotLightParams capsule1(bool dark) =>
      dark ? capsule1Dark : capsule1Light;
  static SoftSpotLightParams capsule2(bool dark) =>
      dark ? capsule2Dark : capsule2Light;
  static SoftSpotLightParams opaqueMedium2(bool dark) =>
      dark ? opaqueMedium2Dark : opaqueMedium2Light;
  static SoftSpotLightParams circle1(bool dark) =>
      dark ? circle1Dark : circle1Light;
  static SoftSpotLightParams roundRect1(bool dark) =>
      dark ? roundRect1Dark : roundRect1Light;
  static SoftSpotLightParams chipTab(bool dark) =>
      dark ? chipTabDark : chipTabLight;
}

/// The light's radius (raw px) at [progress]; while [extinguishing] it
/// overshoots towards `2 · endRadius` as it fades, the way the original
/// lerps its extinguish radius.
double softSpotLightRadius(
  SoftSpotLightParams params,
  double progress, {
  required bool extinguishing,
}) {
  final double t = progress.clamp(0.0, 1.0);
  final double radius =
      params.startRadius + (params.endRadius - params.startRadius) * t;
  if (!extinguishing) return radius;
  return radius + (params.endRadius * 2 - params.startRadius) * (1 - t);
}

final Expando<ui.FragmentShader> _spotLightShaders =
    Expando<ui.FragmentShader>();

/// Paints the spotlight over `Offset.zero & size`.
///
/// [position] is normalised to [size] and may leave 0–1; [radiusPx] is the
/// raw-pixel radius (see [softSpotLightRadius]); [intensity] multiplies the
/// light. [clip], when given, bounds the light to the owner's silhouette.
void paintSoftSpotLight(
  Canvas canvas,
  Size size, {
  required Offset position,
  required double radiusPx,
  required double intensity,
  required SoftSpotLightParams params,
  required double devicePixelRatio,
  Path? clip,
  Color lightColor = const Color(0xFFFFFFFF),
}) {
  if (intensity <= 0 || radiusPx <= 0 || size.isEmpty) return;
  final double dpr = devicePixelRatio <= 0 ? 1 : devicePixelRatio;
  final double radius = radiusPx / dpr;
  final Offset centre = Offset(
    position.dx * size.width,
    position.dy * size.height,
  );
  final ui.FragmentProgram? program = SoftPrograms.instance.spotLight;
  canvas.save();
  if (clip != null) {
    canvas.clipPath(clip);
  } else {
    canvas.clipRect(Offset.zero & size);
  }
  if (program == null) {
    // No runtime shaders: a soft white radial glow of the same reach.
    canvas.drawCircle(
      centre,
      radius,
      Paint()
        ..blendMode = params.blendMode
        ..shader = ui.Gradient.radial(centre, radius, <Color>[
          lightColor.withValues(alpha: (0.35 * intensity).clamp(0.0, 1.0)),
          lightColor.withValues(alpha: 0),
        ]),
    );
    canvas.restore();
    return;
  }
  final ui.FragmentShader shader = _spotLightShaders[program] ??= program
      .fragmentShader();
  shader
    ..setFloat(0, centre.dx)
    ..setFloat(1, centre.dy)
    ..setFloat(2, radius)
    ..setFloat(3, intensity)
    ..setFloat(4, lightColor.r)
    ..setFloat(5, lightColor.g)
    ..setFloat(6, lightColor.b)
    ..setFloat(7, params.ambientStrength)
    ..setFloat(8, params.diffuseStrength)
    ..setFloat(9, params.lightHeight / dpr)
    ..setFloat(10, params.noise)
    ..setFloat(11, params.ditherN);
  canvas.drawRect(
    Offset.zero & size,
    Paint()
      ..shader = shader
      ..blendMode = params.blendMode,
  );
  canvas.restore();
}
