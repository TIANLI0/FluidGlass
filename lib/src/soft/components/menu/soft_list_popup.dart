import 'dart:math' as math;

import 'package:flutter/physics.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../../foundation/soft_glass.dart';
import '../../foundation/soft_motion.dart';
import '../../foundation/soft_spot_light.dart';
import '../../foundation/soft_theme.dart';
import '../../foundation/soft_touch_motion.dart';
import 'soft_popup_list.dart';
import 'soft_popup_position.dart';

/// The list popup's metrics, colours and motion.
abstract final class SoftListPopupDefaults {
  /// The popup's default minimum width.
  static const double minWidth = SoftPopupListDefaults.minWidth;

  /// The popup's maximum width.
  static const double maxWidth = SoftPopupListDefaults.maxWidth;

  /// The height floor of the popup.
  static const double minPopupHeight = 50;

  /// The clearance kept below the status bar.
  static const double topBarrier = 16;

  /// The clearance kept above the navigation bar.
  static const double bottomBarrier = 32;

  /// The panel's corner radius.
  static const double cornerRadius = 28;

  /// The panel's blur radius, in physical pixels.
  static const double blurRadiusPx = 160;

  /// The panel's fill in the light theme (opaque without glass).
  static const Color surfaceLight = Color(0xFFFFFFFF);

  /// The panel's fill in the dark theme.
  static const Color surfaceDark = Color(0xFF333333);

  /// The glass tints: a luminosity layer, then an overlay layer.
  static const List<SoftBlendLayer> glassLayersLight = <SoftBlendLayer>[
    SoftBlendLayer(Color(0x99CDCDCD), BlendMode.luminosity),
    SoftBlendLayer(Color(0xBFEEEEEE), BlendMode.overlay),
  ];

  /// The dark theme's glass tints.
  static const List<SoftBlendLayer> glassLayersDark = <SoftBlendLayer>[
    SoftBlendLayer(Color(0x99262626), BlendMode.luminosity),
    SoftBlendLayer(Color(0x99262626), BlendMode.overlay),
  ];

  /// The panel's drop shadow: the spot shadow of a panel lifted 180 under a
  /// light 10000 away, black at 48/255.
  static const BoxShadow shadow = BoxShadow(
    color: Color(0x30000000),
    blurRadius: 36.66,
    offset: Offset(0, 3.67),
  );

  /// The path parameter flying in: (0.29, damping 0.935).
  static final SpringDescription pathEnter = softSpring(
    damping: 0.935,
    response: 0.29,
  );

  /// The path parameter flying back: (0.26, critically damped).
  static final SpringDescription pathExit = softSpring(
    damping: 1,
    response: 0.26,
  );

  /// The scale growing: (0.4, damping 0.9).
  static final SpringDescription scaleEnter = softSpring(
    damping: 0.9,
    response: 0.4,
  );

  /// The scale shrinking: (0.21, critically damped).
  static final SpringDescription scaleExit = softSpring(
    damping: 1,
    response: 0.21,
  );

  /// The opacity in: (0.27, critically damped).
  static final SpringDescription alphaEnter = softSpring(
    damping: 1,
    response: 0.27,
  );

  /// The opacity out: (0.23, critically damped); its settling decides when
  /// the popup goes away.
  static final SpringDescription alphaExit = softSpring(
    damping: 1,
    response: 0.23,
  );

  /// The window lingers this long after the content has faded.
  static const Duration windowExitDuration = Duration(milliseconds: 200);

  /// The background dim fading in.
  static const Duration dimEnterDuration = Duration(milliseconds: 300);

  /// The background dim fading out.
  static const Duration dimExitDuration = Duration(milliseconds: 150);

  /// How long a closing popup stays mounted: the opacity spring settling
  /// from fully shown, plus [windowExitDuration].
  static final Duration exitDuration =
      _settleTime(alphaExit, 1, 0, 0.001) + windowExitDuration;

  static Duration _settleTime(
    SpringDescription spring,
    double from,
    double to,
    double threshold,
  ) {
    final SpringSimulation simulation = SpringSimulation(
      spring,
      from,
      to,
      0,
      tolerance: Tolerance(distance: threshold, velocity: threshold * 10),
    );
    int ms = 0;
    while (ms < 5000 && !simulation.isDone(ms / 1000)) {
      ms++;
    }
    return Duration(milliseconds: ms);
  }
}

/// Shows [builder]'s content — usually a [SoftListPopupColumn] — in a popup
/// anchored to the widget of [context] (or [anchorRect], in global
/// coordinates).
///
/// The popup is placed by [positioner] inside the safe area (16 below the
/// status bar, 32 above the navigation bar), at least [minWidth] wide and at
/// most [maxHeight] (or the safe area) tall; a taller list scrolls. With a
/// [touchPoint] (global) the anchor collapses to that point and the popup
/// opens at the finger.
///
/// It flies in from the anchor along a sagging arc while it scales up from
/// nothing and fades in, each on its own spring, and reverses on the way
/// out. The panel is frosted glass (an opaque fill with [glass] false) with
/// a light under the finger. Tapping outside or going back dismisses it;
/// [dimBackground] dims the page behind it, which the reference's dropdowns
/// do not. The returned future completes with the value the popup was
/// popped with; [onDismissFinished] runs once the exit has finished.
Future<T?> showSoftListPopup<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  Rect? anchorRect,
  Offset? touchPoint,
  SoftPopupPositioner positioner = SoftPopupPositioner.dropdown,
  SoftPopupAlign alignment = SoftPopupAlign.start,
  bool dimBackground = false,
  double? maxHeight,
  double minWidth = SoftListPopupDefaults.minWidth,
  bool glass = true,
  SoftPopupGravityMotion gravity = SoftPopupGravityMotion.standard,
  bool useRootNavigator = true,
  String? barrierLabel,
  VoidCallback? onDismissFinished,
}) {
  final NavigatorState navigator = Navigator.of(
    context,
    rootNavigator: useRootNavigator,
  );
  final RenderBox overlay =
      navigator.overlay!.context.findRenderObject()! as RenderBox;
  Rect anchor;
  if (anchorRect != null) {
    anchor = Rect.fromPoints(
      overlay.globalToLocal(anchorRect.topLeft),
      overlay.globalToLocal(anchorRect.bottomRight),
    );
  } else {
    final RenderBox box = context.findRenderObject()! as RenderBox;
    anchor = MatrixUtils.transformRect(
      box.getTransformTo(overlay),
      Offset.zero & box.size,
    );
  }
  if (touchPoint != null) {
    final Offset p = overlay.globalToLocal(touchPoint);
    anchor = Rect.fromLTWH(p.dx, p.dy, 0, 0);
  }
  final _SoftListPopupRoute<T> route = _SoftListPopupRoute<T>(
    builder: builder,
    anchor: anchor,
    positioner: positioner,
    alignment: alignment,
    dimBackground: dimBackground,
    maxHeight: maxHeight,
    minWidth: minWidth,
    glass: glass,
    gravity: gravity,
    reduceMotion: softReduceMotion(context),
    theme: SoftTheme.of(context),
    textDirection: Directionality.maybeOf(context) ?? TextDirection.ltr,
    textStyle: DefaultTextStyle.of(context),
    barrierLabel: barrierLabel,
  );
  if (onDismissFinished != null) {
    route.completed.then((_) => onDismissFinished());
  }
  return navigator.push<T>(route);
}

/// Closes the list popup [context] belongs to, completing it with [result].
/// Does nothing outside a popup or once it is already closing.
void dismissSoftListPopup<T>(BuildContext context, [T? result]) {
  final ModalRoute<Object?>? route = ModalRoute.of(context);
  if (route is! _SoftListPopupRoute || !route.isActive) return;
  if (route.isCurrent) {
    route.navigator!.pop<T>(result);
  } else {
    route.navigator!.removeRoute(route, result);
  }
}

class _SoftListPopupRoute<T> extends PopupRoute<T> {
  _SoftListPopupRoute({
    required this.builder,
    required this.anchor,
    required this.positioner,
    required this.alignment,
    required this.dimBackground,
    required this.maxHeight,
    required this.minWidth,
    required this.glass,
    required this.gravity,
    required this.reduceMotion,
    required this.theme,
    required this.textDirection,
    required this.textStyle,
    this.barrierLabel,
  });

  final WidgetBuilder builder;
  final Rect anchor;
  final SoftPopupPositioner positioner;
  final SoftPopupAlign alignment;
  final bool dimBackground;
  final double? maxHeight;
  final double minWidth;
  final bool glass;
  final SoftPopupGravityMotion gravity;
  final bool reduceMotion;
  final SoftThemeData theme;
  final TextDirection textDirection;
  final DefaultTextStyle textStyle;

  @override
  final String? barrierLabel;

  // The popup draws its own dim on its own timing; the barrier only catches
  // the outside tap.
  @override
  Color? get barrierColor => null;

  @override
  bool get barrierDismissible => true;

  @override
  Duration get transitionDuration =>
      reduceMotion ? Duration.zero : SoftListPopupDefaults.dimEnterDuration;

  @override
  Duration get reverseTransitionDuration =>
      reduceMotion ? Duration.zero : SoftListPopupDefaults.exitDuration;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return SoftTheme(
      data: theme,
      child: Directionality(
        textDirection: textDirection,
        child: DefaultTextStyle(
          style: textStyle.style,
          textAlign: textStyle.textAlign,
          softWrap: textStyle.softWrap,
          overflow: textStyle.overflow,
          maxLines: textStyle.maxLines,
          textWidthBasis: textStyle.textWidthBasis,
          textHeightBehavior: textStyle.textHeightBehavior,
          child: _SoftListPopupPage(route: this),
        ),
      ),
    );
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => child;
}

class _SoftListPopupPage extends StatefulWidget {
  const _SoftListPopupPage({required this.route});

  final _SoftListPopupRoute<Object?> route;

  @override
  State<_SoftListPopupPage> createState() => _SoftListPopupPageState();
}

class _SoftListPopupPageState extends State<_SoftListPopupPage>
    with TickerProviderStateMixin {
  late final SoftSpring _path = SoftSpring(vsync: this);
  late final SoftSpring _scale = SoftSpring(vsync: this);
  late final SoftSpring _alpha = SoftSpring(vsync: this);
  late final SoftSpring _dim = SoftSpring(vsync: this);
  Animation<double>? _routeAnimation;
  bool _exiting = false;

  @override
  void initState() {
    super.initState();
    _routeAnimation = widget.route.animation?..addStatusListener(_onStatus);
    _enter();
  }

  @override
  void dispose() {
    _routeAnimation?.removeStatusListener(_onStatus);
    _path.dispose();
    _scale.dispose();
    _alpha.dispose();
    _dim.dispose();
    super.dispose();
  }

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.reverse) {
      _exit();
    } else if (status == AnimationStatus.forward && _exiting) {
      _enter();
    }
  }

  void _enter() {
    _exiting = false;
    if (widget.route.reduceMotion) {
      _path.snapTo(1);
      _scale.snapTo(1);
      _alpha.snapTo(1);
      _dim.snapTo(1);
      return;
    }
    _path.animateTo(1, SoftListPopupDefaults.pathEnter);
    _scale.animateTo(1, SoftListPopupDefaults.scaleEnter);
    _alpha.animateTo(1, SoftListPopupDefaults.alphaEnter);
    if (widget.route.dimBackground) {
      _dim.animateCurve(
        1,
        duration: SoftListPopupDefaults.dimEnterDuration,
        curve: SoftMotion.sinOut,
      );
    }
  }

  void _exit() {
    _exiting = true;
    if (widget.route.reduceMotion) {
      _path.snapTo(0);
      _scale.snapTo(0);
      _alpha.snapTo(0);
      _dim.snapTo(0);
      return;
    }
    _path.animateTo(0, SoftListPopupDefaults.pathExit);
    _scale.animateTo(0, SoftListPopupDefaults.scaleExit);
    _alpha.animateTo(0, SoftListPopupDefaults.alphaExit);
    if (widget.route.dimBackground) {
      _dim.animateCurve(
        0,
        duration: SoftListPopupDefaults.dimExitDuration,
        curve: SoftMotion.sinOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final _SoftListPopupRoute<Object?> route = widget.route;
    final SoftThemeData theme = SoftTheme.of(context);
    final MediaQueryData? media = MediaQuery.maybeOf(context);
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        if (route.dimBackground)
          IgnorePointer(
            child: RepaintBoundary(
              child: CustomPaint(
                painter: _DimPainter(_dim, theme.colors.windowDimming),
              ),
            ),
          ),
        _PopupPlacement(
          anchor: route.anchor,
          positioner: route.positioner,
          alignment: route.alignment,
          maxHeight: route.maxHeight,
          minWidth: route.minWidth,
          padding: media?.viewPadding ?? EdgeInsets.zero,
          textDirection: Directionality.of(context),
          gravity: route.gravity,
          devicePixelRatio: media?.devicePixelRatio ?? 1,
          path: _path,
          scale: _scale,
          alpha: _alpha,
          child: RepaintBoundary(
            child: _SoftPopupPanel(
              glass: route.glass,
              child: Builder(builder: route.builder),
            ),
          ),
        ),
      ],
    );
  }
}

class _DimPainter extends CustomPainter {
  _DimPainter(this.progress, this.color) : super(repaint: progress);

  final SoftSpring progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final double t = progress.value.clamp(0.0, 1.0);
    if (t <= 0) return;
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = color.withValues(alpha: color.a * t),
    );
  }

  @override
  bool shouldRepaint(_DimPainter old) =>
      old.progress != progress || old.color != color;
}

/// The popup panel: frosted glass (or an opaque fill) with the reference's
/// shadow, rim and finger light, following the finger without sinking.
class _SoftPopupPanel extends StatelessWidget {
  const _SoftPopupPanel({required this.glass, required this.child});

  final bool glass;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final SoftThemeData theme = SoftTheme.of(context);
    final bool dark = theme.isDark;
    final double dpr = MediaQuery.maybeDevicePixelRatioOf(context) ?? 1;
    final BorderRadius radius = BorderRadius.circular(
      SoftListPopupDefaults.cornerRadius,
    );
    return SoftTouchMotion(
      pressScale: false,
      borderRadius: radius,
      light: glass ? SoftSpotLightParams.translucentLarge1(dark) : null,
      background: SoftGlass(
        borderRadius: radius,
        color: dark
            ? SoftListPopupDefaults.surfaceDark
            : SoftListPopupDefaults.surfaceLight,
        layers: glass
            ? (dark
                  ? SoftListPopupDefaults.glassLayersDark
                  : SoftListPopupDefaults.glassLayersLight)
            : null,
        blur: glass,
        blurRadius: SoftListPopupDefaults.blurRadiusPx / dpr,
        size: SoftGlassSize.panel,
        shadows: const <BoxShadow>[SoftListPopupDefaults.shadow],
      ),
      child: child,
    );
  }
}

/// Lays the popup out against its anchor and applies the fly-in: the panel
/// scales about the anchor's x (clamped into the panel) on the edge facing
/// the anchor, travels along the gravity arc and fades as one group.
class _PopupPlacement extends SingleChildRenderObjectWidget {
  const _PopupPlacement({
    required this.anchor,
    required this.positioner,
    required this.alignment,
    required this.maxHeight,
    required this.minWidth,
    required this.padding,
    required this.textDirection,
    required this.gravity,
    required this.devicePixelRatio,
    required this.path,
    required this.scale,
    required this.alpha,
    required super.child,
  });

  final Rect anchor;
  final SoftPopupPositioner positioner;
  final SoftPopupAlign alignment;
  final double? maxHeight;
  final double minWidth;
  final EdgeInsets padding;
  final TextDirection textDirection;
  final SoftPopupGravityMotion gravity;
  final double devicePixelRatio;
  final SoftSpring path;
  final SoftSpring scale;
  final SoftSpring alpha;

  @override
  _RenderPopupPlacement createRenderObject(BuildContext context) =>
      _RenderPopupPlacement(
        anchor: anchor,
        positioner: positioner,
        alignment: alignment,
        maxHeight: maxHeight,
        minWidth: minWidth,
        padding: padding,
        textDirection: textDirection,
        gravity: gravity,
        devicePixelRatio: devicePixelRatio,
        path: path,
        scale: scale,
        alpha: alpha,
      );

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderPopupPlacement renderObject,
  ) {
    renderObject
      ..anchor = anchor
      ..positioner = positioner
      ..alignment = alignment
      ..maxHeight = maxHeight
      ..minWidth = minWidth
      ..padding = padding
      ..textDirection = textDirection
      ..gravity = gravity
      ..devicePixelRatio = devicePixelRatio;
  }
}

class _RenderPopupPlacement extends RenderBox
    with RenderObjectWithChildMixin<RenderBox> {
  _RenderPopupPlacement({
    required Rect anchor,
    required SoftPopupPositioner positioner,
    required SoftPopupAlign alignment,
    required double? maxHeight,
    required double minWidth,
    required EdgeInsets padding,
    required TextDirection textDirection,
    required SoftPopupGravityMotion gravity,
    required double devicePixelRatio,
    required this.path,
    required this.scale,
    required this.alpha,
  }) : _anchor = anchor,
       _positioner = positioner,
       _alignment = alignment,
       _maxHeight = maxHeight,
       _minWidth = minWidth,
       _padding = padding,
       _textDirection = textDirection,
       _gravity = gravity,
       _devicePixelRatio = devicePixelRatio;

  final SoftSpring path;
  final SoftSpring scale;
  final SoftSpring alpha;

  Rect _anchor;
  set anchor(Rect v) {
    if (v == _anchor) return;
    _anchor = v;
    markNeedsLayout();
  }

  SoftPopupPositioner _positioner;
  set positioner(SoftPopupPositioner v) {
    if (v == _positioner) return;
    _positioner = v;
    markNeedsLayout();
  }

  SoftPopupAlign _alignment;
  set alignment(SoftPopupAlign v) {
    if (v == _alignment) return;
    _alignment = v;
    markNeedsLayout();
  }

  double? _maxHeight;
  set maxHeight(double? v) {
    if (v == _maxHeight) return;
    _maxHeight = v;
    markNeedsLayout();
  }

  double _minWidth;
  set minWidth(double v) {
    if (v == _minWidth) return;
    _minWidth = v;
    markNeedsLayout();
  }

  EdgeInsets _padding;
  set padding(EdgeInsets v) {
    if (v == _padding) return;
    _padding = v;
    markNeedsLayout();
  }

  TextDirection _textDirection;
  set textDirection(TextDirection v) {
    if (v == _textDirection) return;
    _textDirection = v;
    markNeedsLayout();
  }

  SoftPopupGravityMotion _gravity;
  set gravity(SoftPopupGravityMotion v) {
    if (v == _gravity) return;
    _gravity = v;
    markNeedsLayout();
  }

  double _devicePixelRatio;
  set devicePixelRatio(double v) {
    if (v == _devicePixelRatio) return;
    _devicePixelRatio = v;
    markNeedsLayout();
  }

  /// The panel's resting top-left corner.
  Offset _offset = Offset.zero;

  /// The scale pivot, as fractions of the panel.
  double _pivotX = 0;
  double _pivotY = 0;
  SoftGravityPath _arc = SoftGravityPath.none;

  final LayerHandle<OpacityLayer> _opacityLayer = LayerHandle<OpacityLayer>();
  final LayerHandle<TransformLayer> _transformLayer =
      LayerHandle<TransformLayer>();

  @override
  bool get isRepaintBoundary => true;

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    path.addListener(markNeedsPaint);
    scale.addListener(markNeedsPaint);
    alpha.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    path.removeListener(markNeedsPaint);
    scale.removeListener(markNeedsPaint);
    alpha.removeListener(markNeedsPaint);
    super.detach();
  }

  @override
  void dispose() {
    _opacityLayer.layer = null;
    _transformLayer.layer = null;
    super.dispose();
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) => constraints.biggest;

  @override
  void performLayout() {
    size = constraints.biggest;
    final RenderBox? panel = child;
    if (panel == null) return;
    final Rect window = Rect.fromLTRB(
      _padding.left,
      _padding.top + SoftListPopupDefaults.topBarrier,
      size.width - _padding.right,
      size.height - _padding.bottom - SoftListPopupDefaults.bottomBarrier,
    );
    final EdgeInsets margin = _positioner.margins;
    const double minHeight = SoftListPopupDefaults.minPopupHeight;
    final double available = math.max(
      window.height - margin.vertical,
      minHeight,
    );
    final double? cap = _maxHeight;
    final double maxHeight = cap == null
        ? available
        : cap.clamp(minHeight, available);
    panel.layout(
      BoxConstraints(
        minWidth: math.min(_minWidth, size.width),
        maxWidth: size.width,
        minHeight: math.min(minHeight, maxHeight),
        maxHeight: maxHeight,
      ),
      parentUsesSize: true,
    );
    final Size popup = panel.size;
    _offset = _positioner.position(
      anchor: _anchor,
      window: window,
      textDirection: _textDirection,
      popupSize: popup,
      margin: margin,
      alignment: _alignment,
    );
    final double popupCentreY = _offset.dy + popup.height / 2;
    final bool showBelow = popupCentreY > _anchor.center.dy;
    // The pivot's x is the anchor's centre clamped into the panel; its y is
    // the edge facing the anchor.
    _pivotX = popup.width <= 0
        ? 0
        : ((_anchor.center.dx - _offset.dx) / popup.width).clamp(0.0, 1.0);
    _pivotY = showBelow ? 0 : 1;
    final double dpr = _devicePixelRatio <= 0 ? 1 : _devicePixelRatio;
    final double edge = _gravity.pathAnchorEdgeOffsetY / dpr;
    final Offset pathAnchor = Offset(
      _anchor.center.dx,
      showBelow ? _anchor.bottom + edge : _anchor.top - edge,
    );
    final Offset menuCentre = _offset + popup.center(Offset.zero);
    _arc = SoftGravityPath.between(
      pathAnchor - menuCentre,
      Offset.zero,
      dMin: _gravity.gravityDistanceMinPx / dpr,
      dMax: _gravity.gravityDistanceMaxPx / dpr,
      gMax: _gravity.gravityArcMaxPx / dpr,
      p1T: _gravity.p1T,
      p2T: _gravity.p2T,
    );
  }

  /// The panel's transform: scale about the pivot, then the arc's offset
  /// with the pivot compensated so the panel starts at the anchor.
  Matrix4 _transform() {
    final Size popup = child?.size ?? Size.zero;
    final double s = scale.value;
    final Offset p = _arc.pointAt(path.value);
    final double pivotX = _pivotX * popup.width;
    final double pivotY = _pivotY * popup.height;
    final double tx =
        _offset.dx +
        p.dx +
        popup.width * (0.5 - _pivotX) * (1 - s) +
        pivotX * (1 - s);
    final double ty =
        _offset.dy +
        p.dy +
        popup.height * (0.5 - _pivotY) * (1 - s) +
        pivotY * (1 - s);
    return Matrix4.diagonal3Values(s, s, 1)..setTranslationRaw(tx, ty, 0);
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    transform.multiply(_transform());
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final RenderBox? panel = child;
    final double a = alpha.value.clamp(0.0, 1.0);
    if (panel == null || a <= 0 || scale.value <= 0) {
      _opacityLayer.layer = null;
      _transformLayer.layer = null;
      return;
    }
    final Matrix4 transform = _transform();
    void paintPanel(PaintingContext context, Offset offset) {
      _transformLayer.layer = context.pushTransform(
        needsCompositing,
        offset,
        transform,
        (PaintingContext context, Offset offset) =>
            context.paintChild(panel, offset),
        oldLayer: _transformLayer.layer,
      );
    }

    if (a >= 1) {
      _opacityLayer.layer = null;
      paintPanel(context, offset);
    } else {
      _opacityLayer.layer = context.pushOpacity(
        offset,
        (a * 255).round(),
        paintPanel,
        oldLayer: _opacityLayer.layer,
      );
    }
  }

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (hitTestChildren(result, position: position)) {
      result.add(BoxHitTestEntry(this, position));
      return true;
    }
    return false;
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    final RenderBox? panel = child;
    if (panel == null || alpha.value <= 0 || scale.value <= 0) return false;
    return result.addWithPaintTransform(
      transform: _transform(),
      position: position,
      hitTest: (BoxHitTestResult result, Offset position) =>
          panel.hitTest(result, position: position),
    );
  }
}
