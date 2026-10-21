import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../../foundation/soft_motion.dart';
import '../../foundation/soft_pressable.dart';
import '../../foundation/soft_theme.dart';
import 'soft_text_action.dart';

/// How long a snackbar stays before it dismisses itself.
@immutable
class SoftSnackbarDuration {
  const SoftSnackbarDuration._(this.duration);

  /// A custom duration; must be positive.
  const SoftSnackbarDuration.custom(Duration this.duration);

  /// 4 s.
  static const SoftSnackbarDuration short = SoftSnackbarDuration._(
    Duration(milliseconds: 4000),
  );

  /// 10 s.
  static const SoftSnackbarDuration long = SoftSnackbarDuration._(
    Duration(milliseconds: 10000),
  );

  /// Until dismissed.
  static const SoftSnackbarDuration indefinite = SoftSnackbarDuration._(null);

  /// The time on screen; null for [indefinite].
  final Duration? duration;

  @override
  bool operator ==(Object other) =>
      other is SoftSnackbarDuration && other.duration == duration;

  @override
  int get hashCode => duration.hashCode;
}

/// How a snackbar ended.
enum SoftSnackbarResult {
  /// It timed out, was swiped away or closed.
  dismissed,

  /// Its action was tapped.
  actionPerformed,
}

/// What a snackbar shows.
@immutable
class SoftSnackbarVisuals {
  const SoftSnackbarVisuals({
    required this.message,
    this.actionLabel,
    this.withDismissAction = false,
    this.duration = SoftSnackbarDuration.short,
  });

  final String message;

  /// The action's label; no action when null or empty.
  final String? actionLabel;

  /// Whether a close glyph trails the snackbar.
  final bool withDismissAction;
  final SoftSnackbarDuration duration;
}

/// One snackbar in a [SoftSnackbarHostState]'s queue.
class SoftSnackbarData {
  SoftSnackbarData._(this._host, this.visuals);

  final SoftSnackbarHostState _host;
  final SoftSnackbarVisuals visuals;
  final Completer<SoftSnackbarResult> _result = Completer<SoftSnackbarResult>();
  bool _visible = true;

  /// False once dismissed, while it animates out.
  bool get isVisible => _visible;

  /// Dismisses the snackbar.
  void dismiss() => _complete(SoftSnackbarResult.dismissed);

  /// Reports the action and dismisses the snackbar.
  void performAction() => _complete(SoftSnackbarResult.actionPerformed);

  void _complete(SoftSnackbarResult result) {
    if (_result.isCompleted) return;
    _result.complete(result);
    _visible = false;
    _host._changed();
  }
}

/// The queue of a [SoftSnackbarHost].
///
/// Every snackbar shown stays until it times out or is dismissed; several can
/// be on screen at once, the newest at the bottom.
class SoftSnackbarHostState extends ChangeNotifier {
  // Newest first.
  final List<SoftSnackbarData> _entries = <SoftSnackbarData>[];
  bool _disposed = false;

  /// Every snackbar on screen, newest first, including those animating out.
  List<SoftSnackbarData> get snackbars =>
      List<SoftSnackbarData>.unmodifiable(_entries);

  /// The newest snackbar still shown.
  SoftSnackbarData? get newestSnackbarData {
    for (final SoftSnackbarData data in _entries) {
      if (data._visible) return data;
    }
    return null;
  }

  /// The oldest snackbar still shown.
  SoftSnackbarData? get oldestSnackbarData {
    for (final SoftSnackbarData data in _entries.reversed) {
      if (data._visible) return data;
    }
    return null;
  }

  /// Shows a snackbar and completes when it is gone.
  Future<SoftSnackbarResult> showSnackbar({
    required String message,
    String? actionLabel,
    bool withDismissAction = false,
    SoftSnackbarDuration duration = SoftSnackbarDuration.short,
  }) {
    final SoftSnackbarData data = SoftSnackbarData._(
      this,
      SoftSnackbarVisuals(
        message: message,
        actionLabel: actionLabel,
        withDismissAction: withDismissAction,
        duration: duration,
      ),
    );
    _entries.insert(0, data);
    _changed();
    return data._result.future;
  }

  void _remove(SoftSnackbarData data) {
    if (_entries.remove(data)) _changed();
  }

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

/// Builds the snackbar of a [SoftSnackbarData]; [SoftSnackbar] by default.
typedef SoftSnackbarBuilder =
    Widget Function(BuildContext context, SoftSnackbarData data);

/// The snackbar defaults.
abstract final class SoftSnackbarDefaults {
  /// The corner radius once the message wraps.
  static const double cornerRadius = 16;

  /// The corner radius of a single-line message.
  static const double singleLineCornerRadius = 24;

  /// The padding inside the snackbar; the end becomes [actionEndMargin]
  /// when the action trails it.
  static const EdgeInsetsDirectional insideMargin =
      EdgeInsetsDirectional.symmetric(horizontal: 16, vertical: 10);

  /// The leading icon's box.
  static const double iconSize = 30;

  /// The end padding when the action is the last element.
  static const double actionEndMargin = 4;

  /// The icon's top and bottom clearance.
  static const double iconVerticalMargin = 16;

  /// The gap after the icon.
  static const double iconSpacing = 16;

  /// The gap before the action's press area.
  static const double actionSpacing = 16;

  /// The margin around the snackbar inside the host.
  static const EdgeInsets outerMargin = EdgeInsets.symmetric(
    horizontal: 16,
    vertical: 4,
  );

  /// The host's bottom padding; with [outerMargin] the snackbar sits 32
  /// above the bottom.
  static const double hostBottomPadding = 28;

  /// The shadow: blur 26, black at 14 %, 4 down.
  static const BoxShadow shadow = BoxShadow(
    color: Color(0x24000000),
    blurRadius: 26,
    offset: Offset(0, 4),
  );

  /// Entering: (0.3, 0).
  static final SpringDescription showSpring = softSpringStiffness(
    damping: 1,
    stiffness: 438.65,
  );

  /// Leaving: (0.25, 0).
  static final SpringDescription dismissSpring = softSpringStiffness(
    damping: 1,
    stiffness: 631.65,
  );

  /// The scale a snackbar enters from and leaves to.
  static const double hiddenScale = 0.8;

  /// The swipe's settle spring.
  static final SpringDescription swipeSpring = softSpringStiffness(
    damping: 1,
    stiffness: 1500,
  );

  /// The fling speed that dismisses regardless of distance.
  static const double swipeVelocityThreshold = 125;

  /// Siblings sliding into their new slots.
  static final SpringDescription placementSpring = softSpringStiffness(
    damping: 1,
    stiffness: 400,
  );

  /// Message and action: body 2 at medium weight.
  static TextStyle textStyle(SoftThemeData theme) =>
      theme.textStyles.body2.copyWith(fontWeight: FontWeight.w500);
}

/// Shows the snackbars of [state] stacked at the bottom of its box, newest
/// at the bottom.
///
/// Each one fades and scales in from 0.8 and out to 0.8 on critically damped
/// springs; the others slide to their new slots. With [canSwipeToDismiss] a
/// sideways swipe past half its width (or a fling) throws it off.
///
/// The host lets touches through wherever no snackbar is.
class SoftSnackbarHost extends StatefulWidget {
  const SoftSnackbarHost({
    super.key,
    required this.state,
    this.canSwipeToDismiss = true,
    this.builder,
  });

  final SoftSnackbarHostState state;
  final bool canSwipeToDismiss;

  /// Builds each snackbar; a plain [SoftSnackbar] by default.
  final SoftSnackbarBuilder? builder;

  @override
  State<SoftSnackbarHost> createState() => _SoftSnackbarHostState();
}

class _SoftSnackbarHostState extends State<SoftSnackbarHost> {
  @override
  void initState() {
    super.initState();
    widget.state.addListener(_changed);
  }

  @override
  void didUpdateWidget(SoftSnackbarHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state != widget.state) {
      oldWidget.state.removeListener(_changed);
      widget.state.addListener(_changed);
    }
  }

  @override
  void dispose() {
    widget.state.removeListener(_changed);
    super.dispose();
  }

  void _changed() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final List<SoftSnackbarData> entries = widget.state._entries;
    // Oldest first, so the newest paints last, on top of a sibling sliding
    // past it.
    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.only(
          bottom: SoftSnackbarDefaults.hostBottomPadding,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (final SoftSnackbarData data in entries.reversed)
              _SnackbarItem(
                key: ObjectKey(data),
                data: data,
                visible: data._visible,
                canSwipe: widget.canSwipeToDismiss,
                builder: widget.builder,
                onExited: widget.state._remove,
              ),
          ],
        ),
      ),
    );
  }
}

class _SnackbarItem extends StatefulWidget {
  const _SnackbarItem({
    super.key,
    required this.data,
    required this.visible,
    required this.canSwipe,
    required this.builder,
    required this.onExited,
  });

  final SoftSnackbarData data;
  final bool visible;
  final bool canSwipe;
  final SoftSnackbarBuilder? builder;
  final ValueChanged<SoftSnackbarData> onExited;

  @override
  State<_SnackbarItem> createState() => _SnackbarItemState();
}

class _SnackbarItemState extends State<_SnackbarItem>
    with TickerProviderStateMixin {
  late final SoftSpring _shown = SoftSpring(vsync: this);
  late final SoftSpring _swipe = SoftSpring(vsync: this);
  late final AnimationController _placement = AnimationController.unbounded(
    vsync: this,
  );
  Timer? _timer;
  bool _timerStarted = false;
  double _width = 0;

  @override
  void initState() {
    super.initState();
    _shown.animateTo(1, SoftSnackbarDefaults.showSpring);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_timerStarted) return;
    _timerStarted = true;
    final SoftSnackbarVisuals visuals = widget.data.visuals;
    final Duration? duration = visuals.duration.duration;
    final bool hasAction = visuals.actionLabel?.isNotEmpty ?? false;
    // A screen reader user gets as long as they need to reach the action.
    final bool accessible =
        MediaQuery.maybeAccessibleNavigationOf(context) ?? false;
    if (duration == null || (accessible && hasAction)) return;
    _timer = Timer(duration, widget.data.dismiss);
  }

  @override
  void didUpdateWidget(_SnackbarItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.visible && !widget.visible) _exit();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _shown.dispose();
    _swipe.dispose();
    _placement.dispose();
    super.dispose();
  }

  Future<void> _exit() async {
    _timer?.cancel();
    await _shown.animateTo(0, SoftSnackbarDefaults.dismissSpring);
    if (mounted && !widget.visible) widget.onExited(widget.data);
  }

  bool get _swipeEnabled => widget.visible && widget.canSwipe;

  void _onDragStart(DragStartDetails details) {
    _width = context.size?.width ?? 0;
    _swipe.stop();
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (_width <= 0) return;
    _swipe.snapTo(
      (_swipe.value + details.primaryDelta!).clamp(-_width, _width),
    );
  }

  Future<void> _onDragEnd(DragEndDetails details) async {
    if (_width <= 0) return;
    final double offset = _swipe.value;
    final double velocity = details.primaryVelocity ?? 0;
    const List<double> unit = <double>[-1, 0, 1];
    final List<double> anchors = <double>[
      for (final double a in unit) a * _width,
    ];
    double target;
    if (velocity.abs() >= SoftSnackbarDefaults.swipeVelocityThreshold) {
      // The nearest anchor in the fling's direction.
      target = velocity > 0
          ? anchors.firstWhere((double a) => a >= offset, orElse: () => _width)
          : anchors.lastWhere((double a) => a <= offset, orElse: () => -_width);
    } else {
      // Past half way to the next anchor goes there.
      target = anchors.reduce(
        (double a, double b) =>
            (a - offset).abs() <= (b - offset).abs() ? a : b,
      );
    }
    await _swipe.animateTo(
      target,
      SoftSnackbarDefaults.swipeSpring,
      velocity: velocity,
      threshold: 0.5,
    );
    if (mounted && target != 0 && _swipe.value == target) {
      widget.data.dismiss();
    }
  }

  @override
  Widget build(BuildContext context) {
    final Widget snackbar =
        widget.builder?.call(context, widget.data) ??
        SoftSnackbar(data: widget.data);
    Widget result = AnimatedBuilder(
      animation: Listenable.merge(<Listenable>[_shown, _swipe]),
      builder: (BuildContext context, Widget? child) {
        final double shown = _shown.value.clamp(0.0, 1.0);
        const double hidden = SoftSnackbarDefaults.hiddenScale;
        return Transform.translate(
          offset: Offset(_swipe.value, 0),
          child: Opacity(
            opacity: shown,
            child: Transform.scale(
              scale: hidden + (1 - hidden) * shown,
              child: child,
            ),
          ),
        );
      },
      child: snackbar,
    );
    result = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragStart: _swipeEnabled ? _onDragStart : null,
      onHorizontalDragUpdate: _swipeEnabled ? _onDragUpdate : null,
      onHorizontalDragEnd: _swipeEnabled ? _onDragEnd : null,
      dragStartBehavior: DragStartBehavior.down,
      child: result,
    );
    return _SlideToSlot(
      controller: _placement,
      enabled: widget.visible,
      child: result,
    );
  }
}

/// Slides its child from where it was painted last frame to its new slot on
/// [SoftSnackbarDefaults.placementSpring] whenever the layout moves it.
class _SlideToSlot extends SingleChildRenderObjectWidget {
  const _SlideToSlot({
    required this.controller,
    required this.enabled,
    required super.child,
  });

  final AnimationController controller;
  final bool enabled;

  @override
  _RenderSlideToSlot createRenderObject(BuildContext context) =>
      _RenderSlideToSlot(controller: controller, enabled: enabled);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderSlideToSlot renderObject,
  ) {
    renderObject.enabled = enabled;
  }
}

class _RenderSlideToSlot extends RenderProxyBox {
  _RenderSlideToSlot({required this.controller, required this.enabled});

  final AnimationController controller;
  bool enabled;

  /// Where the child was painted last frame, in layer coordinates.
  double? _lastShownY;
  double? _lastSlotY;
  double _pending = 0;
  bool _hasPending = false;

  double get _delta => _hasPending ? _pending : controller.value;

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    controller.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    controller.removeListener(markNeedsPaint);
    super.detach();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final double? lastSlot = _lastSlotY;
    final double? lastShown = _lastShownY;
    if (enabled &&
        lastSlot != null &&
        lastShown != null &&
        (offset.dy - lastSlot).abs() > 0.01) {
      // The slot moved: keep painting where it was and spring from there.
      _pending = lastShown - offset.dy;
      _hasPending = true;
      final double velocity = controller.velocity;
      final double from = _pending;
      SchedulerBinding.instance.addPostFrameCallback((Duration _) {
        if (!attached) return;
        _hasPending = false;
        controller.value = from;
        controller.animateWith(
          SpringSimulation(
            SoftSnackbarDefaults.placementSpring,
            from,
            0,
            velocity,
            tolerance: const Tolerance(distance: 0.5, velocity: 5),
            snapToEnd: true,
          ),
        );
      });
    }
    final double delta = _delta;
    _lastSlotY = offset.dy;
    _lastShownY = offset.dy + delta;
    super.paint(context, offset.translate(0, delta));
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    return result.addWithPaintOffset(
      offset: Offset(0, _delta),
      position: position,
      hitTest: (BoxHitTestResult result, Offset transformed) =>
          super.hitTestChildren(result, position: transformed),
    );
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    transform.translateByDouble(0, _delta, 0, 1);
  }
}

/// A snackbar: the message, an optional leading [icon], an optional accent
/// action and an optional close glyph on the theme's
/// `surfaceContainerHighest`, with a soft shadow.
///
/// A single-line message gets the capsule-like 24 corners, a wrapped one
/// 16. Taps on the snackbar do not reach what is under it.
class SoftSnackbar extends StatefulWidget {
  const SoftSnackbar({
    super.key,
    required this.data,
    this.icon,
    this.cornerRadius = SoftSnackbarDefaults.cornerRadius,
    this.singleLineCornerRadius = SoftSnackbarDefaults.singleLineCornerRadius,
    this.containerColor,
    this.contentColor,
    this.actionColor,
    this.dismissActionColor,
    this.insideMargin = SoftSnackbarDefaults.insideMargin,
    this.dismissSemanticLabel,
  });

  final SoftSnackbarData data;

  /// Laid out in a 30 box before the message.
  final Widget? icon;
  final double cornerRadius;
  final double singleLineCornerRadius;

  /// `surfaceContainerHighest` by default.
  final Color? containerColor;

  /// `onSurfaceContainer` by default.
  final Color? contentColor;

  /// `primary` by default.
  final Color? actionColor;

  /// `onSurfaceVariantActions` by default.
  final Color? dismissActionColor;
  final EdgeInsetsDirectional insideMargin;

  /// The close glyph's label for screen readers.
  final String? dismissSemanticLabel;

  @override
  State<SoftSnackbar> createState() => _SoftSnackbarState();
}

class _SoftSnackbarState extends State<SoftSnackbar> {
  final ValueNotifier<bool> _singleLine = ValueNotifier<bool>(true);

  @override
  void dispose() {
    _singleLine.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final SoftThemeData theme = SoftTheme.of(context);
    final SoftSnackbarVisuals visuals = widget.data.visuals;
    final TextStyle style = SoftSnackbarDefaults.textStyle(theme);
    final Color content =
        widget.contentColor ?? theme.colors.onSurfaceContainer;
    final String? action = (visuals.actionLabel?.isEmpty ?? true)
        ? null
        : visuals.actionLabel;
    final bool actionTrailing = action != null && !visuals.withDismissAction;
    final EdgeInsetsDirectional margin = widget.insideMargin;

    final List<Widget> row = <Widget>[
      if (widget.icon != null)
        Padding(
          padding: EdgeInsetsDirectional.only(
            top: math.max(
              0,
              SoftSnackbarDefaults.iconVerticalMargin - margin.top,
            ),
            bottom: math.max(
              0,
              SoftSnackbarDefaults.iconVerticalMargin - margin.bottom,
            ),
            end: SoftSnackbarDefaults.iconSpacing,
          ),
          child: SizedBox.square(
            dimension: SoftSnackbarDefaults.iconSize,
            child: Center(child: widget.icon),
          ),
        ),
      Flexible(
        child: _LineProbe(
          style: style,
          onSingleLine: (bool value) => _singleLine.value = value,
          child: Text(visuals.message, style: style.copyWith(color: content)),
        ),
      ),
      if (action != null)
        Padding(
          padding: const EdgeInsetsDirectional.only(
            start: SoftSnackbarDefaults.actionSpacing,
          ),
          child: SoftTextAction(
            label: action,
            maxLines: 2,
            style: style.copyWith(
              color: widget.actionColor ?? theme.colors.primary,
            ),
            onTap: widget.data.performAction,
          ),
        ),
      if (visuals.withDismissAction)
        Padding(
          padding: const EdgeInsetsDirectional.only(start: 8),
          child: Semantics(
            label: widget.dismissSemanticLabel,
            child: SoftPressable(
              onTap: widget.data.dismiss,
              borderRadius: BorderRadius.circular(12),
              child: CustomPaint(
                size: const Size.square(24),
                painter: _ClearGlyphPainter(
                  widget.dismissActionColor ??
                      theme.colors.onSurfaceVariantActions,
                ),
              ),
            ),
          ),
        ),
    ];

    return Semantics(
      container: true,
      liveRegion: true,
      child: Padding(
        padding: SoftSnackbarDefaults.outerMargin,
        child: CustomPaint(
          painter: _SnackbarSurfacePainter(
            singleLine: _singleLine,
            color:
                widget.containerColor ?? theme.colors.surfaceContainerHighest,
            radius: widget.cornerRadius,
            singleLineRadius: widget.singleLineCornerRadius,
          ),
          child: Padding(
            padding: margin.copyWith(
              end: actionTrailing
                  ? SoftSnackbarDefaults.actionEndMargin
                  : margin.end,
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: row),
          ),
        ),
      ),
    );
  }
}

/// Reports whether its text child laid out on one line.
class _LineProbe extends SingleChildRenderObjectWidget {
  const _LineProbe({
    required this.style,
    required this.onSingleLine,
    required super.child,
  });

  final TextStyle style;
  final ValueChanged<bool> onSingleLine;

  @override
  _RenderLineProbe createRenderObject(BuildContext context) => _RenderLineProbe(
    style: style,
    scaler: MediaQuery.maybeTextScalerOf(context) ?? TextScaler.noScaling,
    onSingleLine: onSingleLine,
  );

  @override
  void updateRenderObject(BuildContext context, _RenderLineProbe renderObject) {
    renderObject
      ..style = style
      ..scaler = MediaQuery.maybeTextScalerOf(context) ?? TextScaler.noScaling
      ..onSingleLine = onSingleLine;
  }
}

class _RenderLineProbe extends RenderProxyBox {
  _RenderLineProbe({
    required TextStyle style,
    required TextScaler scaler,
    required this.onSingleLine,
  }) : _style = style,
       _scaler = scaler;

  TextStyle _style;
  set style(TextStyle value) {
    if (value == _style) return;
    _style = value;
    _lineHeight = null;
    markNeedsLayout();
  }

  TextScaler _scaler;
  set scaler(TextScaler value) {
    if (value == _scaler) return;
    _scaler = value;
    _lineHeight = null;
    markNeedsLayout();
  }

  ValueChanged<bool> onSingleLine;
  double? _lineHeight;

  double get _oneLine {
    final double? cached = _lineHeight;
    if (cached != null) return cached;
    final TextPainter painter = TextPainter(
      text: TextSpan(text: ' ', style: _style),
      textScaler: _scaler,
      textDirection: TextDirection.ltr,
    )..layout();
    final double height = painter.height;
    painter.dispose();
    return _lineHeight = height;
  }

  @override
  void performLayout() {
    super.performLayout();
    onSingleLine(size.height < _oneLine * 1.5);
  }
}

class _SnackbarSurfacePainter extends CustomPainter {
  _SnackbarSurfacePainter({
    required this.singleLine,
    required this.color,
    required this.radius,
    required this.singleLineRadius,
  }) : super(repaint: singleLine);

  final ValueNotifier<bool> singleLine;
  final Color color;
  final double radius;
  final double singleLineRadius;

  @override
  void paint(Canvas canvas, Size size) {
    final double r = singleLine.value ? singleLineRadius : radius;
    final RRect shape = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(math.min(r, size.shortestSide / 2)),
    );
    const BoxShadow shadow = SoftSnackbarDefaults.shadow;
    canvas.drawRRect(shape.shift(shadow.offset), shadow.toPaint());
    canvas.drawRRect(shape, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_SnackbarSurfacePainter old) =>
      old.singleLine != singleLine ||
      old.color != color ||
      old.radius != radius ||
      old.singleLineRadius != singleLineRadius;
}

/// The reference's clear glyph tinted with [color]: a faint disc and a
/// cross, on a 68 grid.
class _ClearGlyphPainter extends CustomPainter {
  const _ClearGlyphPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final double s = size.shortestSide / 68;
    canvas.save();
    canvas.scale(s);
    final double alpha = color.a;
    canvas.drawCircle(
      const Offset(34, 34),
      32,
      Paint()..color = color.withValues(alpha: alpha * 0.06),
    );
    final Path cross = Path()
      ..moveTo(44.6066, 27.8492)
      ..cubicTo(45.7782, 26.6777, 45.7782, 24.7782, 44.6066, 23.6066)
      ..cubicTo(43.435, 22.435, 41.5355, 22.435, 40.364, 23.6066)
      ..lineTo(34, 29.9706)
      ..lineTo(27.636, 23.6066)
      ..cubicTo(26.4645, 22.435, 24.565, 22.435, 23.3934, 23.6066)
      ..cubicTo(22.2218, 24.7782, 22.2218, 26.6777, 23.3934, 27.8492)
      ..lineTo(29.7574, 34.2132)
      ..lineTo(23.3934, 40.5772)
      ..cubicTo(22.2218, 41.7487, 22.2218, 43.6482, 23.3934, 44.8198)
      ..cubicTo(24.565, 45.9914, 26.4645, 45.9914, 27.636, 44.8198)
      ..lineTo(34, 38.4558)
      ..lineTo(40.364, 44.8198)
      ..cubicTo(41.5355, 45.9914, 43.435, 45.9914, 44.6066, 44.8198)
      ..cubicTo(45.7782, 43.6482, 45.7782, 41.7487, 44.6066, 40.5772)
      ..lineTo(38.2426, 34.2132)
      ..lineTo(44.6066, 27.8492)
      ..close();
    canvas.drawPath(
      cross,
      Paint()..color = color.withValues(alpha: alpha * 0.3),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ClearGlyphPainter old) => old.color != color;
}

final Expando<SoftSnackbarHostState> _overlayHosts =
    Expando<SoftSnackbarHostState>();

/// The snackbar host of the nearest [Overlay], above the bottom safe area.
///
/// The overlay gets one [SoftSnackbarHost] the first time it is asked for;
/// [showSoftSnackbar] shows its snackbars there.
SoftSnackbarHostState softOverlaySnackbarHost(BuildContext context) {
  final OverlayState overlay = Overlay.of(context);
  final SoftSnackbarHostState? existing = _overlayHosts[overlay];
  if (existing != null) return existing;
  final SoftSnackbarHostState created = SoftSnackbarHostState();
  _overlayHosts[overlay] = created;
  overlay.insert(
    OverlayEntry(
      builder: (BuildContext context) => SafeArea(
        top: false,
        left: false,
        right: false,
        child: SoftSnackbarHost(state: created),
      ),
    ),
  );
  return created;
}

/// Shows a snackbar at the bottom of the nearest [Overlay] (see
/// [softOverlaySnackbarHost]) and completes when it is gone.
///
/// To place the snackbars yourself, put a [SoftSnackbarHost] in the page and
/// call [SoftSnackbarHostState.showSnackbar].
Future<SoftSnackbarResult> showSoftSnackbar(
  BuildContext context, {
  required String message,
  String? actionLabel,
  bool withDismissAction = false,
  SoftSnackbarDuration duration = SoftSnackbarDuration.short,
}) {
  return softOverlaySnackbarHost(context).showSnackbar(
    message: message,
    actionLabel: actionLabel,
    withDismissAction: withDismissAction,
    duration: duration,
  );
}
