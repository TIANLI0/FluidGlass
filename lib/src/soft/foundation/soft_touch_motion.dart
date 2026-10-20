import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'soft_motion.dart';
import 'soft_programs.dart';
import 'soft_spot_light.dart';
import 'soft_squircle.dart';
import 'soft_theme.dart';

/// The touch-motion parameters: how far a pressed surface follows the
/// finger, how much it stretches, how much it sinks and how it springs back.
@immutable
class SoftTouchMotionSpec {
  const SoftTouchMotionSpec({
    this.deadZonePx = 5,
    this.maxStretchDistance = 28,
    this.rubberCurveRatio = 0.05,
    this.maxDeformRubberDistance = 150,
    this.deformRubberCurveRatio = 0.55,
    this.maxScale = 1.2,
    this.k1 = 350000,
    this.k2 = 15,
    this.pressScaleMin = 0.85,
    this.pressScaleMax = 0.97,
    this.pressMinAreaWidth = 20,
    this.pressMaxAreaWidth = 150,
    this.pressAspectActivationThreshold = 2,
    this.pressAspectExtremeRatio = 15,
    this.pressAspectBaseScale = 0.85,
    this.pressAspectExtremeScale = 1,
    this.handUpSmallAreaRefWidth = 56,
    this.handUpLargeAreaRefWidth = 100,
    this.handUpBaseResponse = 0.42,
    this.handUpBaseBounce = 0.65,
    this.handUpLargeAreaResponse = 0.45,
    this.handUpLargeAreaBounce = 0.65,
    this.handUpMaxInitialVelocity = 1000,
    this.handUpBounceGain = 1,
  });

  /// The finger travel, in physical pixels, before the surface follows.
  final double deadZonePx;

  /// The most the surface translates, in logical pixels.
  final double maxStretchDistance;
  final double rubberCurveRatio;

  /// The finger travel over which the stretch saturates.
  final double maxDeformRubberDistance;
  final double deformRubberCurveRatio;

  /// The largest stretch of a small surface.
  final double maxScale;
  final int k1;
  final int k2;

  /// The sink of the smallest and the largest surfaces.
  final double pressScaleMin;
  final double pressScaleMax;

  /// The side lengths (of a square of the same area) between which the sink
  /// interpolates.
  final double pressMinAreaWidth;
  final double pressMaxAreaWidth;

  /// Above this aspect ratio a surface is a "candy" (a long capsule): its
  /// sink blends towards none, and it uses the softer candy springs.
  final double pressAspectActivationThreshold;
  final double pressAspectExtremeRatio;
  final double pressAspectBaseScale;
  final double pressAspectExtremeScale;
  final double handUpSmallAreaRefWidth;
  final double handUpLargeAreaRefWidth;
  final double handUpBaseResponse;
  final double handUpBaseBounce;
  final double handUpLargeAreaResponse;
  final double handUpLargeAreaBounce;
  final double handUpMaxInitialVelocity;
  final double handUpBounceGain;

  /// Following the finger: (0.15, 0.15).
  static final SpringDescription dragSpring = softSpring(
    damping: 0.85,
    response: 0.15,
  );
  static final SpringDescription pressSpring = softSpring(
    damping: 1,
    response: 0.25,
  );
  static final SpringDescription releaseSpring = softSpring(
    damping: 0.4,
    response: 0.5,
  );
  static final SpringDescription candyPressSpring = softSpring(
    damping: 1,
    response: 0.3,
  );
  static final SpringDescription candyReleaseSpring = softSpring(
    damping: 0.5,
    response: 0.5,
  );

  /// The sink target of a [width] × [height] surface (logical pixels).
  double pressScale(double width, double height) {
    if (width <= 0 || height <= 0) return 1;
    final double minArea = pressMinAreaWidth * pressMinAreaWidth;
    final double maxArea = pressMaxAreaWidth * pressMaxAreaWidth;
    final double area = (width * height).clamp(minArea, maxArea);
    final double areaProgress = (area - minArea) / (maxArea - minArea);
    final double areaCurve = softCubicBezier(areaProgress, 0, 0, 0, 1);
    final double areaScale =
        pressScaleMin + (pressScaleMax - pressScaleMin) * areaCurve;
    final double aspect = math.max(width / height, height / width);
    if (aspect <= pressAspectActivationThreshold) return areaScale;
    final double aspectProgress =
        ((aspect - pressAspectActivationThreshold) /
                (pressAspectExtremeRatio - pressAspectActivationThreshold))
            .clamp(0.0, 1.0);
    final double aspectCurve = softCubicBezier(aspectProgress, 0, 0, 0, 1);
    final double aspectScale =
        pressAspectBaseScale +
        (pressAspectExtremeScale - pressAspectBaseScale) * aspectCurve;
    return ((areaScale + aspectScale) / 2).clamp(0.4, 1.0);
  }

  /// Whether a [width] × [height] surface is a candy.
  bool isCandy(double width, double height) =>
      width > 0 &&
      height > 0 &&
      math.max(width / height, height / width) > pressAspectActivationThreshold;

  /// The largest stretch of a surface of [widthPx] × [heightPx] physical
  /// pixels: big and elongated surfaces stretch less.
  double scaleWithK(double widthPx, double heightPx) {
    final int area = (widthPx * heightPx).toInt();
    final double maxSide = math.max(widthPx, heightPx);
    final double minSide = math.min(widthPx, heightPx);
    if (area <= 38416 || minSide == 0) return maxScale;
    final double decay = math.min(
      (k2 / 1000) * ((maxSide / minSide) - 1) +
          (k1 / 1000000) * math.log(area / 38416),
      1.0,
    );
    return math.max((maxScale - 1.03) * (1 - decay) + 1.03, 1.03);
  }
}

/// The scale pair of a stretch.
@immutable
class _Deform {
  const _Deform(this.x, this.y);

  final double x;
  final double y;
}

_Deform _directionScale(
  double distance,
  double curveRatio,
  double maxDistance,
  double maxScale, {
  required bool horizontal,
}) {
  if (distance <= 0 || maxDistance <= 0) return const _Deform(1, 1);
  final double expanded =
      1 +
      (SoftRubberBand.apply(distance, curveRatio, maxDistance) / maxDistance) *
          (maxScale - 1);
  final double compressed = expanded > 0 ? 1 / expanded : 1;
  return horizontal
      ? _Deform(expanded, compressed)
      : _Deform(compressed, expanded);
}

/// The area-conserving stretch for a drag of (dx, dy), blended in log space
/// when both axes move.
_Deform _deformation(
  double dx,
  double dy,
  SoftTouchMotionSpec spec,
  double widthPx,
  double heightPx,
) {
  final double maxScale = spec.scaleWithK(widthPx, heightPx);
  final double maxDistance = spec.maxDeformRubberDistance;
  final _Deform x = _directionScale(
    dx.abs(),
    spec.deformRubberCurveRatio,
    maxDistance,
    maxScale,
    horizontal: true,
  );
  final _Deform y = _directionScale(
    dy.abs(),
    spec.deformRubberCurveRatio,
    maxDistance,
    maxScale,
    horizontal: false,
  );
  final double total = dx.abs() + dy.abs();
  if (total <= 0) return const _Deform(1, 1);
  if (dy.abs() <= 0) return x;
  if (dx.abs() <= 0) return y;
  final double wx = dx.abs() / total;
  final double wy = dy.abs() / total;
  return _Deform(
    math.exp(math.log(x.x) * wx + math.log(y.x) * wy),
    math.exp(math.log(x.y) * wx + math.log(y.y) * wy),
  );
}

/// (response, bounce, initial velocity) of the hand-up spring.
@immutable
class _HandUp {
  const _HandUp(this.response, this.bounce, this.velocity);

  final double response;
  final double bounce;
  final double velocity;

  SpringDescription get spring =>
      softSpring(damping: 1 - bounce, response: response);
}

_HandUp _resolveHandUp(
  SoftTouchMotionSpec spec,
  Size size,
  double pan,
  double totalDistance,
  double previousVelocity,
) {
  final double area = size.width * size.height;
  final double smallArea =
      spec.handUpSmallAreaRefWidth * spec.handUpSmallAreaRefWidth;
  final double largeArea =
      spec.handUpLargeAreaRefWidth * spec.handUpLargeAreaRefWidth;
  final double areaFraction =
      (area <= 0 ||
          size.width <= 0 ||
          size.height <= 0 ||
          largeArea <= smallArea)
      ? 0
      : ((area - smallArea) / (largeArea - smallArea)).clamp(0.0, 1.0);
  final double blend = softCubicBezier(
    areaFraction,
    0.55026454,
    0,
    0.8915344,
    0.18783069,
  );
  final double response =
      spec.handUpBaseResponse +
      (spec.handUpLargeAreaResponse - spec.handUpBaseResponse) * blend;
  final double configuredBounce =
      spec.handUpBaseBounce +
      (spec.handUpLargeAreaBounce - spec.handUpBaseBounce) * blend;
  final double max = spec.handUpMaxInitialVelocity;
  final double initialVelocity = (max <= 0 || totalDistance <= 0)
      ? 0
      : ((pan.abs() / totalDistance) * previousVelocity).clamp(-max, max);
  final double velocityBounce = max <= 0
      ? 0
      : math.min(initialVelocity.abs() / max, 1.0) * spec.handUpBounceGain;
  final double bounce = math.min(
    math.max(
      velocityBounce.abs(),
      (configuredBounce * spec.handUpBounceGain).abs(),
    ),
    1.0,
  );
  return _HandUp(response, bounce, initialVelocity);
}

/// Makes [child] a pressable surface the way the reference's components are:
/// it sinks by an amount chosen from its size, follows the finger with a
/// rubber band and stretches along the drag, springs back with a bounce when
/// released, and — with [light] — lights up under the finger.
///
/// It only *watches* the pointer: it never enters the gesture arena, so the
/// widget it wraps keeps its own taps and semantics, and a list it sits in
/// still scrolls. When an enclosing scrollable starts moving, the press is
/// released as if the finger had lifted.
///
/// [color], when given, is filled behind [child] in the [borderRadius]
/// silhouette, and the light is drawn over that fill but under [child]; that
/// order — surface, light, content — is the reference's.
class SoftTouchMotion extends StatefulWidget {
  const SoftTouchMotion({
    super.key,
    required this.child,
    this.enabled = true,
    this.borderRadius,
    this.color,
    this.light,
    this.pressScale = true,
    this.followFinger = true,
    this.spec = const SoftTouchMotionSpec(),
    this.onPressedChanged,
    this.state,
    this.background,
  });

  /// A surface drawn behind the light — a frosted panel, say — that moves
  /// with the press. The order is the reference's: surface, light, content.
  final Widget? background;

  /// Publishes the current transform, for things drawn outside this widget
  /// that have to ride along with it — a shadow, a merged silhouette.
  final SoftTouchMotionState? state;

  final Widget child;
  final bool enabled;

  /// The silhouette the fill and the light are clipped to.
  final BorderRadius? borderRadius;

  /// The surface fill behind [child].
  final Color? color;

  /// The spotlight preset; no light when null.
  final SoftSpotLightParams? light;

  /// Whether the surface sinks while pressed.
  final bool pressScale;

  /// Whether the surface follows and stretches with the finger.
  final bool followFinger;

  final SoftTouchMotionSpec spec;

  /// Called when the press starts and ends.
  final ValueChanged<bool>? onPressedChanged;

  @override
  State<SoftTouchMotion> createState() => _SoftTouchMotionState();
}

/// The transform a [SoftTouchMotion] is applying: its translation and its
/// scale about the centre (stretch and sink combined).
class SoftTouchMotionState extends ChangeNotifier {
  Offset _translation = Offset.zero;
  double _scaleX = 1;
  double _scaleY = 1;
  bool _pressed = false;

  Offset get translation => _translation;
  double get scaleX => _scaleX;
  double get scaleY => _scaleY;
  bool get pressed => _pressed;

  void _set(Offset translation, double scaleX, double scaleY, bool pressed) {
    if (translation == _translation &&
        scaleX == _scaleX &&
        scaleY == _scaleY &&
        pressed == _pressed) {
      return;
    }
    _translation = translation;
    _scaleX = scaleX;
    _scaleY = scaleY;
    _pressed = pressed;
    notifyListeners();
  }
}

class _SoftTouchMotionState extends State<SoftTouchMotion>
    with TickerProviderStateMixin {
  @override
  void initState() {
    super.initState();
    _repaint.addListener(_publish);
  }

  void _publish() {
    final SoftTouchMotionState? state = widget.state;
    if (state == null) return;
    final double target = widget.pressScale
        ? widget.spec.pressScale(_size.width, _size.height)
        : 1.0;
    final double pressScale = 1 - (1 - target) * _press.value;
    state._set(
      Offset(_tx.value, _ty.value),
      _sx.value + pressScale - 1,
      _sy.value + pressScale - 1,
      _pointer != null,
    );
  }

  late final SoftSpring _tx = SoftSpring(vsync: this);
  late final SoftSpring _ty = SoftSpring(vsync: this);
  late final SoftSpring _sx = SoftSpring(vsync: this, value: 1);
  late final SoftSpring _sy = SoftSpring(vsync: this, value: 1);
  late final SoftSpring _press = SoftSpring(vsync: this);
  late final SoftSpring _lightX = SoftSpring(vsync: this, value: 0.5);
  late final SoftSpring _lightY = SoftSpring(vsync: this, value: 0.5);
  late final SoftSpring _lightProgress = SoftSpring(vsync: this);
  late final Listenable _repaint = Listenable.merge(<Listenable>[
    _tx,
    _ty,
    _sx,
    _sy,
    _press,
    _lightX,
    _lightY,
    _lightProgress,
    SoftPrograms.instance,
  ]);

  int? _pointer;
  Offset _start = Offset.zero;
  Offset _rubberRest = Offset.zero;
  Offset _deformRest = Offset.zero;
  bool _dragging = false;
  bool _extinguishing = false;
  VelocityTracker? _tracker;
  ScrollPosition? _scroll;
  Size _size = Size.zero;

  @override
  void didUpdateWidget(SoftTouchMotion oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled && oldWidget.enabled) {
      _detachScroll();
      _pointer = null;
      _tx.snapTo(0);
      _ty.snapTo(0);
      _sx.snapTo(1);
      _sy.snapTo(1);
      _press.snapTo(0);
      _lightProgress.snapTo(0);
    }
  }

  @override
  void dispose() {
    _repaint.removeListener(_publish);
    _detachScroll();
    for (final SoftSpring s in <SoftSpring>[
      _tx,
      _ty,
      _sx,
      _sy,
      _press,
      _lightX,
      _lightY,
      _lightProgress,
    ]) {
      s.dispose();
    }
    super.dispose();
  }

  Widget _withBackground(Widget content) {
    final Widget? background = widget.background;
    if (background == null) return content;
    return Stack(
      fit: StackFit.passthrough,
      children: <Widget>[
        Positioned.fill(child: background),
        content,
      ],
    );
  }

  bool get _candy => widget.spec.isCandy(_size.width, _size.height);

  double get _dpr => MediaQuery.maybeDevicePixelRatioOf(context) ?? 1;

  void _updateLight(Offset local) {
    final double x = local.dx / math.max(_size.width, 1);
    final double y = local.dy / math.max(_size.height, 1);
    if (_lightProgress.value == 0) {
      _lightX.snapTo(x);
      _lightY.snapTo(y);
    } else {
      _lightX.animateTo(x, SoftMotion.lightMove, threshold: 1e-4);
      _lightY.animateTo(y, SoftMotion.lightMove, threshold: 1e-4);
    }
  }

  void _attachScroll() {
    final ScrollPosition? position = Scrollable.maybeOf(context)?.position;
    if (position == _scroll) return;
    _detachScroll();
    _scroll = position;
    _scroll?.isScrollingNotifier.addListener(_onScrolling);
  }

  void _detachScroll() {
    _scroll?.isScrollingNotifier.removeListener(_onScrolling);
    _scroll = null;
  }

  void _onScrolling() {
    if (_scroll?.isScrollingNotifier.value ?? false) _release(Offset.zero);
  }

  void _down(PointerDownEvent event) {
    if (!widget.enabled || _pointer != null) return;
    _pointer = event.pointer;
    _attachScroll();
    final SoftTouchMotionSpec spec = widget.spec;
    _start = event.localPosition;
    _rubberRest = Offset(
      SoftRubberBand.inverse(
        _tx.value,
        spec.rubberCurveRatio,
        spec.maxStretchDistance,
      ),
      SoftRubberBand.inverse(
        _ty.value,
        spec.rubberCurveRatio,
        spec.maxStretchDistance,
      ),
    );
    final double deformDistance = spec.maxDeformRubberDistance;
    final double deformRange = math.max(
      spec.scaleWithK(_size.width * _dpr, _size.height * _dpr) - 1,
      0.001,
    );
    _deformRest = Offset(
      SoftRubberBand.inverse(
        math.min((_sx.value - 1) / deformRange, 1.0) * deformDistance,
        spec.deformRubberCurveRatio,
        deformDistance,
      ),
      SoftRubberBand.inverse(
        math.min((_sy.value - 1) / deformRange, 1.0) * deformDistance,
        spec.deformRubberCurveRatio,
        deformDistance,
      ),
    );
    _tracker = VelocityTracker.withKind(event.kind)
      ..addPosition(event.timeStamp, event.localPosition);
    _dragging = false;
    _extinguishing = false;
    _updateLight(event.localPosition);
    _lightProgress.animateTo(1, SoftMotion.lightGlow);
    _press.animateTo(
      1,
      _candy
          ? SoftTouchMotionSpec.candyPressSpring
          : SoftTouchMotionSpec.pressSpring,
    );
    widget.onPressedChanged?.call(true);
  }

  void _move(PointerMoveEvent event) {
    if (event.pointer != _pointer) return;
    _tracker?.addPosition(event.timeStamp, event.localPosition);
    _updateLight(event.localPosition);
    if (!widget.followFinger) return;
    final SoftTouchMotionSpec spec = widget.spec;
    final double deadZone = spec.deadZonePx / _dpr;
    final double dx = event.localPosition.dx - _start.dx;
    final double dy = event.localPosition.dy - _start.dy;
    if (!_dragging && (dx.abs() >= deadZone || dy.abs() >= deadZone)) {
      _dragging = true;
    }
    if (!_dragging) return;
    final _Deform deform = _deformation(
      dx + _deformRest.dx,
      dy + _deformRest.dy,
      spec,
      _size.width * _dpr,
      _size.height * _dpr,
    );
    _tx.animateTo(
      SoftRubberBand.apply(
        dx + _rubberRest.dx,
        spec.rubberCurveRatio,
        spec.maxStretchDistance,
      ),
      SoftTouchMotionSpec.dragSpring,
      threshold: 0.01,
    );
    _ty.animateTo(
      SoftRubberBand.apply(
        dy + _rubberRest.dy,
        spec.rubberCurveRatio,
        spec.maxStretchDistance,
      ),
      SoftTouchMotionSpec.dragSpring,
      threshold: 0.01,
    );
    _sx.animateTo(deform.x, SoftTouchMotionSpec.dragSpring, threshold: 0.0005);
    _sy.animateTo(deform.y, SoftTouchMotionSpec.dragSpring, threshold: 0.0005);
  }

  void _up(PointerEvent event) {
    if (event.pointer != _pointer) return;
    _tracker?.addPosition(event.timeStamp, event.localPosition);
    _updateLight(event.localPosition);
    final Velocity velocity = _tracker?.getVelocity() ?? Velocity.zero;
    // The reference reads its tracker in px/ms and scales it by 0.3.
    _release(velocity.pixelsPerSecond * 0.3 / 1000);
  }

  void _release(Offset velocity) {
    if (_pointer == null) return;
    _pointer = null;
    _detachScroll();
    final SoftTouchMotionSpec spec = widget.spec;
    _extinguishing = true;
    _lightProgress.animateTo(0, SoftMotion.lightExtinguish);
    _press.animateTo(
      0,
      _candy
          ? SoftTouchMotionSpec.candyReleaseSpring
          : SoftTouchMotionSpec.releaseSpring,
    );
    final double total = spec.maxStretchDistance;
    final _HandUp hx = _resolveHandUp(
      spec,
      _size,
      _tx.value,
      total,
      velocity.dx,
    );
    final _HandUp hy = _resolveHandUp(
      spec,
      _size,
      _ty.value,
      total,
      velocity.dy,
    );
    final _HandUp dxUp = _resolveHandUp(
      spec,
      _size,
      (_sx.value - 1).abs(),
      total,
      velocity.dx,
    );
    final _HandUp dyUp = _resolveHandUp(
      spec,
      _size,
      (_sy.value - 1).abs(),
      total,
      velocity.dy,
    );
    _tx.animateTo(0, hx.spring, velocity: hx.velocity, threshold: 0.01);
    _ty.animateTo(0, hy.spring, velocity: hy.velocity, threshold: 0.01);
    _sx.animateTo(1, dxUp.spring, velocity: dxUp.velocity, threshold: 0.0005);
    _sy.animateTo(1, dyUp.spring, velocity: dyUp.velocity, threshold: 0.0005);
    widget.onPressedChanged?.call(false);
  }

  @override
  Widget build(BuildContext context) {
    final SoftThemeData theme = SoftTheme.of(context);
    final double dpr = _dpr;
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _down,
      onPointerMove: _move,
      onPointerUp: _up,
      onPointerCancel: (PointerCancelEvent e) {
        if (e.pointer == _pointer) _release(Offset.zero);
      },
      child: _SizeReporter(
        onSize: (Size s) => _size = s,
        child: AnimatedBuilder(
          animation: _repaint,
          builder: (BuildContext context, Widget? child) {
            final double target = widget.pressScale
                ? widget.spec.pressScale(_size.width, _size.height)
                : 1.0;
            final double pressScale = 1 - (1 - target) * _press.value;
            final double scaleX = _sx.value + pressScale - 1;
            final double scaleY = _sy.value + pressScale - 1;
            return Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..translateByDouble(_tx.value, _ty.value, 0, 1)
                ..scaleByDouble(scaleX, scaleY, 1, 1),
              child: child,
            );
          },
          child: _withBackground(
            CustomPaint(
              painter: _SurfacePainter(
                repaint: _repaint,
                state: this,
                color: widget.color,
                radius: widget.borderRadius,
                smooth: theme.smoothCorners,
                light: widget.enabled ? widget.light : null,
                dpr: dpr,
              ),
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}

class _SurfacePainter extends CustomPainter {
  _SurfacePainter({
    required Listenable repaint,
    required this.state,
    required this.color,
    required this.radius,
    required this.smooth,
    required this.light,
    required this.dpr,
  }) : super(repaint: repaint);

  final _SoftTouchMotionState state;
  final Color? color;
  final BorderRadius? radius;
  final bool smooth;
  final SoftSpotLightParams? light;
  final double dpr;

  @override
  void paint(Canvas canvas, Size size) {
    final Path? clip = radius == null
        ? null
        : softSquirclePath(Offset.zero & size, radius!, smooth: smooth);
    final Color? fill = color;
    if (fill != null && fill.a > 0) {
      final Paint paint = Paint()..color = fill;
      if (clip != null) {
        canvas.drawPath(clip, paint);
      } else {
        canvas.drawRect(Offset.zero & size, paint);
      }
    }
    final SoftSpotLightParams? params = light;
    final double progress = state._lightProgress.value;
    if (params == null || progress <= 0.0005) return;
    paintSoftSpotLight(
      canvas,
      size,
      position: Offset(state._lightX.value, state._lightY.value),
      radiusPx: softSpotLightRadius(
        params,
        progress,
        extinguishing: state._extinguishing,
      ),
      intensity: params.endIntensity * progress,
      params: params,
      devicePixelRatio: dpr,
      clip: clip,
    );
  }

  @override
  bool shouldRepaint(_SurfacePainter old) =>
      old.color != color ||
      old.radius != radius ||
      old.smooth != smooth ||
      old.light != light ||
      old.dpr != dpr;
}

/// Reports its laid-out size without a frame of delay.
class _SizeReporter extends SingleChildRenderObjectWidget {
  const _SizeReporter({required this.onSize, super.child});

  final ValueChanged<Size> onSize;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderSizeReporter(onSize);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderSizeReporter renderObject,
  ) {
    renderObject.onSize = onSize;
  }
}

class _RenderSizeReporter extends RenderProxyBox {
  _RenderSizeReporter(this.onSize);

  ValueChanged<Size> onSize;

  @override
  void performLayout() {
    super.performLayout();
    onSize(size);
  }
}
