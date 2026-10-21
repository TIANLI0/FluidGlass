import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/physics.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../../foundation/soft_colors.dart';
import '../../foundation/soft_motion.dart';
import '../../foundation/soft_squircle.dart';
import '../../foundation/soft_theme.dart';

/// The bottom sheet's metrics, colours and springs.
abstract final class SoftBottomSheetDefaults {
  /// The top corners; the bottom ones are square.
  static const double cornerRadius = 20;

  /// No cap beyond the responsive grid width (see [panelMaxWidth]).
  static const double maxWidth = double.infinity;

  /// The horizontal margin outside the surface (width; the height is unused).
  static const Size outsideMargin = Size.zero;

  /// The horizontal padding inside the surface (width, each side) and its
  /// bottom padding (height).
  static const Size insideMargin = Size(24, 0);

  /// The drag strip at the top of the sheet.
  static const double dragAreaHeight = 24;

  /// The drag bar.
  static const Size dragBarSize = Size(36, 4);

  /// The rounded press background faded in behind the bar.
  static const Size dragPressSize = Size(70, 20);
  static const double dragPressRadius = 16;

  /// The press background's offset from the strip's top.
  static const double dragPressTop = 4;

  /// The press background's fade, both ways.
  static const Duration dragPressDuration = Duration(milliseconds: 200);
  static const Cubic dragPressCurve = Cubic(0.33, 0, 0.67, 1);

  /// The title row's padding above and below.
  static const double titleTopPadding = 6;
  static const double titleBottomPadding = 12;

  /// The peek height the slide spring's travel is normalised against.
  static const double peekHeight = 82;

  /// A release farther down than this dismisses, unless flung back up.
  static const double dismissDistance = 150;

  /// A release faster than this (logical pixels per second) dismisses.
  static const double dismissVelocity = 800;

  /// How much of the finger travel an over-pull follows: upwards always,
  /// downwards when dismissing is not allowed.
  static const double overPullResistance = 0.1;

  /// The spring a released sheet returns to rest with: (0.4, 0.15).
  static final SpringDescription settleSpring = softSpring(
    damping: 0.85,
    response: 0.4,
  );

  /// The fill: the theme's `background`.
  static Color backgroundColor(SoftColors colors) => colors.background;

  /// The drag bar: `onSurfaceVariantSummary` at 20 %.
  static Color dragHandleColor(SoftColors colors) =>
      colors.onSurfaceVariantSummary.withValues(alpha: 0.2);

  /// The drag strip's press background: the theme's state layer at its
  /// press alpha.
  static Color dragPressColor(SoftColors colors) =>
      colors.stateLayer.withValues(alpha: colors.pressAlpha);

  /// The slide in and out: critically damped, its response interpolated
  /// from 0.25 s towards 0.45 s (in) or 0.4 s (out) by how far the sheet
  /// travels, `(travel - peek) / (container - peek)`.
  static SpringDescription slideSpring({
    required bool entering,
    required double travel,
    required double container,
  }) {
    final double base = entering ? 0.45 : 0.4;
    final double denominator = container - peekHeight;
    final double fraction = denominator > 0
        ? ((travel - peekHeight) / denominator).clamp(0.0, 1.0)
        : 1.0;
    return softSpring(damping: 1, response: 0.25 + (base - 0.25) * fraction);
  }

  /// The responsive grid width of a panel in a [window]: the full width
  /// below 600, otherwise six columns of the 8-column (margin 24, gutter 8)
  /// or 12-column (margin 40, gutter 12) grid.
  static double panelMaxWidth(Size window) {
    final double width = window.width;
    final double height = window.height;
    if (width < 600) return double.infinity;
    final bool eightColumns =
        width < 840 ||
        height < 480 ||
        (height >= 900 && height > width && width < 960);
    return eightColumns
        ? (width - 2 * 24 - 7 * 8) / 8 * 6 + 5 * 8
        : (width - 2 * 40 - 11 * 12) / 12 * 6 + 5 * 12;
  }
}

/// Gives the content of a bottom sheet a way to ask for it to close.
///
/// Every sheet provides one above its actions and content.
class SoftBottomSheetScope extends InheritedWidget {
  const SoftBottomSheetScope._({required this.dismiss, required super.child});

  /// Asks the sheet to close: pops a sheet from [showSoftBottomSheet], or
  /// calls a [SoftBottomSheet]'s `onDismissRequest`.
  final VoidCallback dismiss;

  /// The nearest sheet's dismiss request, if any.
  static VoidCallback? dismissOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<SoftBottomSheetScope>()?.dismiss;

  @override
  bool updateShouldNotify(SoftBottomSheetScope oldWidget) =>
      oldWidget.dismiss != dismiss;
}

/// Shows a bottom sheet over the whole navigator and returns the value it
/// is popped with.
///
/// The sheet wraps its content up to the screen height minus the top
/// inset, under a drag handle and an optional row of [title] between a
/// [startAction] and an [endAction]. It slides in on a critically damped
/// spring; dragging the handle — or a vertical scroll view in the content,
/// once it reaches its top — moves it, and a release past 150 or faster
/// than 800 per second sends it off screen. Pulling it up stretches it at a
/// tenth of the finger travel. A tap outside, a back press or a drag closes
/// it while [allowDismiss] is true; [SoftBottomSheetScope.dismissOf] closes
/// it from inside.
///
/// The keyboard pushes the surface up when [defaultWindowInsetsPadding] is
/// on. The bottom system inset is left to the content, as in the reference.
///
/// Scrollable content should size to its content (a [SingleChildScrollView]
/// or a shrink-wrapped list) so the sheet only grows as tall as needed.
Future<T?> showSoftBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  String? title,
  Widget? startAction,
  Widget? endAction,
  Color? backgroundColor,
  bool enableWindowDim = true,
  double cornerRadius = SoftBottomSheetDefaults.cornerRadius,
  double sheetMaxWidth = SoftBottomSheetDefaults.maxWidth,
  Size outsideMargin = SoftBottomSheetDefaults.outsideMargin,
  Size insideMargin = SoftBottomSheetDefaults.insideMargin,
  bool defaultWindowInsetsPadding = true,
  Color? dragHandleColor,
  bool allowDismiss = true,
  bool enableNestedScroll = true,
  bool useRootNavigator = true,
  String? barrierLabel,
  RouteSettings? routeSettings,
}) {
  final _SheetConfig config = _SheetConfig(
    theme: SoftTheme.of(context),
    content: builder,
    title: title,
    startAction: startAction,
    endAction: endAction,
    backgroundColor: backgroundColor,
    enableWindowDim: enableWindowDim,
    cornerRadius: cornerRadius,
    sheetMaxWidth: sheetMaxWidth,
    outsideMargin: outsideMargin,
    insideMargin: insideMargin,
    defaultWindowInsetsPadding: defaultWindowInsetsPadding,
    dragHandleColor: dragHandleColor,
    allowDismiss: allowDismiss,
    enableNestedScroll: enableNestedScroll,
    barrierLabel: barrierLabel,
    onDismissRequest: null,
  );
  return Navigator.of(context, rootNavigator: useRootNavigator).push<T>(
    _SoftBottomSheetRoute<T>(
      config: config,
      selfDismiss: true,
      settings: routeSettings,
    ),
  );
}

/// A bottom sheet shown while [show] is true — the declarative form of
/// [showSoftBottomSheet], with the same look and gestures.
///
/// It takes no room where it is placed. A tap outside, a back press or a
/// drag calls [onDismissRequest] (while [allowDismiss] is true); the owner
/// sets [show] to false, the sheet slides out, and [onDismissFinished]
/// follows once it is gone. Parameters may change while it is open.
class SoftBottomSheet extends StatefulWidget {
  const SoftBottomSheet({
    super.key,
    required this.show,
    required this.child,
    this.title,
    this.startAction,
    this.endAction,
    this.onDismissRequest,
    this.onDismissFinished,
    this.backgroundColor,
    this.enableWindowDim = true,
    this.cornerRadius = SoftBottomSheetDefaults.cornerRadius,
    this.sheetMaxWidth = SoftBottomSheetDefaults.maxWidth,
    this.outsideMargin = SoftBottomSheetDefaults.outsideMargin,
    this.insideMargin = SoftBottomSheetDefaults.insideMargin,
    this.defaultWindowInsetsPadding = true,
    this.dragHandleColor,
    this.allowDismiss = true,
    this.enableNestedScroll = true,
    this.useRootNavigator = true,
    this.barrierLabel,
  });

  final bool show;

  /// The content, below the handle and the title row.
  final Widget child;
  final String? title;

  /// Shown at the start of the title row, e.g. a close button.
  final Widget? startAction;

  /// Shown at the end of the title row, e.g. a confirm button.
  final Widget? endAction;
  final VoidCallback? onDismissRequest;

  /// Called when the slide out completes; not when [show] turns true again
  /// before it does.
  final VoidCallback? onDismissFinished;

  /// The fill; the theme's `background` by default.
  final Color? backgroundColor;

  /// Whether the window behind is dimmed with the theme's `windowDimming`.
  final bool enableWindowDim;
  final double cornerRadius;

  /// A cap on top of the responsive grid width.
  final double sheetMaxWidth;
  final Size outsideMargin;
  final Size insideMargin;

  /// Whether the keyboard pushes the surface up.
  final bool defaultWindowInsetsPadding;
  final Color? dragHandleColor;

  /// Whether a tap outside, a back press or a drag may dismiss.
  final bool allowDismiss;

  /// Whether a vertical scroll view in the content drags the sheet once it
  /// is at its top, and hands a pulled sheet back before scrolling.
  final bool enableNestedScroll;

  /// Shows over the root navigator (the whole screen) or the nearest one.
  final bool useRootNavigator;

  /// The semantic label of the area outside the sheet.
  final String? barrierLabel;

  @override
  State<SoftBottomSheet> createState() => _SoftBottomSheetState();
}

class _SoftBottomSheetState extends State<SoftBottomSheet> {
  _SoftBottomSheetRoute<void>? _route;
  late SoftThemeData _theme;
  double _lastHeight = 0;
  bool _syncScheduled = false;

  @override
  void dispose() {
    final _SoftBottomSheetRoute<void>? route = _route;
    _route = null;
    if (route != null) {
      // The navigator cannot change while the tree is being finalised.
      SchedulerBinding.instance.addPostFrameCallback((_) => route.hide());
    }
    super.dispose();
  }

  _SheetConfig _config() => _SheetConfig(
    theme: _theme,
    content: (_) => widget.child,
    title: widget.title,
    startAction: widget.startAction,
    endAction: widget.endAction,
    backgroundColor: widget.backgroundColor,
    enableWindowDim: widget.enableWindowDim,
    cornerRadius: widget.cornerRadius,
    sheetMaxWidth: widget.sheetMaxWidth,
    outsideMargin: widget.outsideMargin,
    insideMargin: widget.insideMargin,
    defaultWindowInsetsPadding: widget.defaultWindowInsetsPadding,
    dragHandleColor: widget.dragHandleColor,
    allowDismiss: widget.allowDismiss,
    enableNestedScroll: widget.enableNestedScroll,
    barrierLabel: widget.barrierLabel,
    onDismissRequest: widget.onDismissRequest,
  );

  void _scheduleSync() {
    if (_syncScheduled) return;
    if (!widget.show && _route == null) return;
    _syncScheduled = true;
    // The route lives in a navigator outside this subtree, which cannot be
    // marked dirty during this build.
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _syncScheduled = false;
      if (mounted) _sync();
    });
    SchedulerBinding.instance.ensureVisualUpdate();
  }

  void _sync() {
    final _SoftBottomSheetRoute<void>? route = _route;
    if (widget.show) {
      if (route != null && route.isActive) {
        route.config.value = _config();
        return;
      }
      _push();
      return;
    }
    if (route == null) return;
    _route = null;
    _lastHeight = route.sheet.sheetHeight;
    route.config.value = _config();
    route.hide();
  }

  void _push() {
    final _SoftBottomSheetRoute<void> route = _SoftBottomSheetRoute<void>(
      config: _config(),
      selfDismiss: false,
      initialSheetHeight: _lastHeight,
    );
    _route = route;
    Navigator.of(context, rootNavigator: widget.useRootNavigator).push(route);
    route.popped.then((_) {
      // Popped by someone else: let the owner catch up.
      if (!mounted || _route != route) return;
      _route = null;
      _lastHeight = route.sheet.sheetHeight;
      widget.onDismissRequest?.call();
    });
    route.completed.then((_) {
      if (mounted && _route == null) widget.onDismissFinished?.call();
    });
  }

  @override
  Widget build(BuildContext context) {
    _theme = SoftTheme.of(context);
    _scheduleSync();
    return const SizedBox.shrink();
  }
}

/// Everything a sheet is drawn from; replaced whole when its owner rebuilds.
@immutable
class _SheetConfig {
  const _SheetConfig({
    required this.theme,
    required this.content,
    required this.title,
    required this.startAction,
    required this.endAction,
    required this.backgroundColor,
    required this.enableWindowDim,
    required this.cornerRadius,
    required this.sheetMaxWidth,
    required this.outsideMargin,
    required this.insideMargin,
    required this.defaultWindowInsetsPadding,
    required this.dragHandleColor,
    required this.allowDismiss,
    required this.enableNestedScroll,
    required this.barrierLabel,
    required this.onDismissRequest,
  });

  final SoftThemeData theme;
  final WidgetBuilder content;
  final String? title;
  final Widget? startAction;
  final Widget? endAction;
  final Color? backgroundColor;
  final bool enableWindowDim;
  final double cornerRadius;
  final double sheetMaxWidth;
  final Size outsideMargin;
  final Size insideMargin;
  final bool defaultWindowInsetsPadding;
  final Color? dragHandleColor;
  final bool allowDismiss;
  final bool enableNestedScroll;
  final String? barrierLabel;
  final VoidCallback? onDismissRequest;
}

/// The sheet's drag state: its offset from rest (positive is down), its
/// last measured height and the settle in flight.
class _SheetController {
  _SheetController({
    required TickerProvider vsync,
    required this.route,
    required this.sheetHeight,
  }) : drag = SoftSpring(vsync: vsync);

  final _SoftBottomSheetRoute<dynamic> route;

  /// The drag offset in logical pixels.
  final SoftSpring drag;

  /// The sheet's height, recorded while the keyboard is closed.
  double sheetHeight;
  double windowHeight = 0;
  bool reduceMotion = false;
  bool settling = false;
  int _generation = 0;

  _SheetConfig get config => route.config.value;

  double get offset => drag.value;

  /// The dim fades out as a dismissible sheet is pulled down.
  double get dimAlpha {
    final double o = drag.value;
    if (o <= 0 || !config.allowDismiss) return 1;
    final double threshold = sheetHeight > 0 ? sheetHeight : 500;
    return 1 - (o / threshold).clamp(0.0, 1.0);
  }

  /// Applies [delta] of finger travel with the over-pull resistance.
  double resisted(double current, double delta) {
    const double k = SoftBottomSheetDefaults.overPullResistance;
    final double next = current + delta;
    if (next < 0) return math.min(current + delta * k, 0);
    if (!config.allowDismiss) {
      return math.max(current + (delta > 0 ? delta * k : delta), 0);
    }
    return next;
  }

  void cancelSettle() {
    if (!settling) return;
    _generation++;
    settling = false;
    drag.stop();
  }

  void snap(double value) {
    cancelSettle();
    drag.snapTo(value);
  }

  void dragBy(double delta) => snap(resisted(drag.value, delta));

  /// Releases the sheet at [velocity] (logical pixels per second, positive
  /// downwards): off screen past the thresholds, back to rest otherwise.
  Future<void> settle(double velocity) async {
    final int generation = ++_generation;
    settling = true;
    final double current = drag.value;
    final bool allow = config.allowDismiss;
    const double v = SoftBottomSheetDefaults.dismissVelocity;
    final bool dismiss =
        allow &&
        (velocity > v ||
            (current > SoftBottomSheetDefaults.dismissDistance &&
                velocity > -v));
    try {
      if (dismiss) {
        if (current >= windowHeight) {
          route.requestDismiss();
        } else {
          await dismissOffScreen(velocity);
        }
      } else if (reduceMotion) {
        drag.snapTo(0);
      } else {
        await drag
            .animateTo(
              0,
              SoftBottomSheetDefaults.settleSpring,
              velocity: !allow && velocity > 0 ? 0 : velocity,
              threshold: 0.01,
            )
            .orCancel;
      }
    } on TickerCanceled {
      // Interrupted by a new drag.
    } finally {
      if (generation == _generation) settling = false;
    }
  }

  /// Sends the sheet down with the slide-out spring and asks to dismiss as
  /// soon as it has left its own height.
  Future<void> dismissOffScreen(double velocity) async {
    final double height = sheetHeight;
    if (reduceMotion) {
      drag.snapTo(windowHeight);
      route.requestDismiss();
      return;
    }
    final Completer<bool> left = Completer<bool>();
    void check() {
      if (height > 0 && drag.value >= height && !left.isCompleted) {
        left.complete(true);
      }
    }

    drag.addListener(check);
    drag
        .animateTo(
          windowHeight,
          SoftBottomSheetDefaults.slideSpring(
            entering: false,
            travel: height > 0 ? height : windowHeight,
            container: windowHeight,
          ),
          velocity: velocity,
          threshold: 0.01,
        )
        .orCancel
        .then(
          (_) {
            if (!left.isCompleted) left.complete(true);
          },
          onError: (Object _) {
            if (!left.isCompleted) left.complete(false);
          },
        );
    final bool gone = await left.future;
    drag.removeListener(check);
    if (!gone) return;
    drag.stop();
    route.requestDismiss();
  }

  /// A back press: off screen and dismissed, when allowed.
  void back() {
    if (!config.allowDismiss) return;
    final int generation = ++_generation;
    settling = true;
    dismissOffScreen(0).whenComplete(() {
      if (generation == _generation) settling = false;
    });
  }

  void dispose() {
    _generation++;
    drag.dispose();
  }
}

class _SoftBottomSheetRoute<T> extends PopupRoute<T> {
  _SoftBottomSheetRoute({
    required _SheetConfig config,
    required this.selfDismiss,
    double initialSheetHeight = 0,
    super.settings,
  }) : config = ValueNotifier<_SheetConfig>(config),
       _initialSheetHeight = initialSheetHeight;

  final ValueNotifier<_SheetConfig> config;

  /// Whether a dismiss request pops the route itself (no owner to ask).
  final bool selfDismiss;
  final double _initialSheetHeight;
  late final _SheetController sheet;

  @override
  Color? get barrierColor => null;

  @override
  bool get barrierDismissible => false;

  @override
  String? get barrierLabel => null;

  /// Nominal: the springs of [createSimulation] drive the transition.
  @override
  Duration get transitionDuration => const Duration(milliseconds: 450);

  @override
  void install() {
    sheet = _SheetController(
      vsync: navigator!,
      route: this,
      sheetHeight: _initialSheetHeight,
    );
    super.install();
  }

  @override
  Simulation? createSimulation({required bool forward}) {
    final AnimationController c = controller!;
    final MediaQueryData? media = navigator?.context
        .getInheritedWidgetOfExactType<MediaQuery>()
        ?.data;
    final double target = forward ? 1 : 0;
    // A sheet already dragged off screen is simply gone.
    if ((media?.disableAnimations ?? false) || (!forward && sheet.offset > 0)) {
      return _DoneSimulation(target);
    }
    final double container = media?.size.height ?? sheet.windowHeight;
    final double travel = sheet.sheetHeight > 0 ? sheet.sheetHeight : container;
    return SpringSimulation(
      SoftBottomSheetDefaults.slideSpring(
        entering: forward,
        travel: travel,
        container: container,
      ),
      c.value,
      target,
      c.velocity,
      tolerance: const Tolerance(distance: 0.0001, velocity: 0.001),
      snapToEnd: true,
    );
  }

  void requestDismiss() {
    if (selfDismiss) {
      hide();
    } else {
      config.value.onDismissRequest?.call();
    }
  }

  /// Slides the sheet out and removes it.
  void hide([T? result]) {
    final NavigatorState? nav = navigator;
    if (nav == null || !isActive) return;
    if (isCurrent) {
      nav.pop<T>(result);
    } else {
      nav.removeRoute(this, result);
    }
  }

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return ValueListenableBuilder<_SheetConfig>(
      valueListenable: config,
      builder: (BuildContext context, _SheetConfig value, Widget? _) =>
          _SheetView(route: this, config: value, progress: animation),
    );
  }

  @override
  void dispose() {
    sheet.dispose();
    config.dispose();
    super.dispose();
  }
}

class _DoneSimulation extends Simulation {
  _DoneSimulation(this.target);

  final double target;

  @override
  double x(double time) => target;

  @override
  double dx(double time) => 0;

  @override
  bool isDone(double time) => true;
}

class _SheetView extends StatelessWidget {
  const _SheetView({
    required this.route,
    required this.config,
    required this.progress,
  });

  final _SoftBottomSheetRoute<dynamic> route;
  final _SheetConfig config;
  final Animation<double> progress;

  @override
  Widget build(BuildContext context) {
    final SoftThemeData theme = config.theme;
    final SoftColors colors = theme.colors;
    final _SheetController sheet = route.sheet;
    final Size window = MediaQuery.sizeOf(context);
    final double topInset = MediaQuery.paddingOf(context).top;
    sheet.windowHeight = window.height;
    sheet.reduceMotion = softReduceMotion(context);
    final Color background =
        config.backgroundColor ??
        SoftBottomSheetDefaults.backgroundColor(colors);
    final double maxWidth = math.min(
      config.sheetMaxWidth,
      SoftBottomSheetDefaults.panelMaxWidth(window),
    );
    final SoftSquircleBorder border = SoftSquircleBorder(
      radius: BorderRadius.vertical(top: Radius.circular(config.cornerRadius)),
      smooth: theme.smoothCorners,
    );

    Widget content = Builder(builder: config.content);
    if (config.enableNestedScroll) {
      final ScrollBehavior behavior = ScrollConfiguration.of(context);
      content = ScrollConfiguration(
        behavior: behavior.copyWith(
          physics: _SheetScrollPhysics(
            sheet,
            parent: behavior.getScrollPhysics(context),
          ),
        ),
        child: content,
      );
    }

    Widget body = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _DragHandle(
          sheet: sheet,
          color:
              config.dragHandleColor ??
              SoftBottomSheetDefaults.dragHandleColor(colors),
          pressColor: SoftBottomSheetDefaults.dragPressColor(colors),
        ),
        _TitleRow(
          title: config.title,
          startAction: config.startAction,
          endAction: config.endAction,
          style: theme.textStyles.main.copyWith(
            fontSize: theme.textStyles.title4.fontSize,
            fontWeight: FontWeight.w500,
            color: colors.onSurface,
          ),
        ),
        Flexible(child: content),
      ],
    );
    body = Padding(
      padding: EdgeInsets.only(
        left: config.insideMargin.width,
        right: config.insideMargin.width,
        bottom: config.insideMargin.height,
      ),
      child: body,
    );
    body = DecoratedBox(
      decoration: ShapeDecoration(color: background, shape: border),
      child: ClipPath(
        clipper: ShapeBorderClipper(shape: border),
        child: body,
      ),
    );
    body = Padding(
      padding: EdgeInsets.symmetric(horizontal: config.outsideMargin.width),
      child: body,
    );
    body = _KeyboardPadding(
      enabled: config.defaultWindowInsetsPadding,
      child: body,
    );
    body = ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: math.max(0, window.height - topInset),
      ),
      child: body,
    );
    body = _SlideScope(
      sheet: sheet,
      progress: progress,
      fill: background,
      inset: config.outsideMargin.width,
      child: RepaintBoundary(
        child: Semantics(
          container: true,
          explicitChildNodes: true,
          child: body,
        ),
      ),
    );

    final VoidCallback? onBarrierTap = config.allowDismiss
        ? route.requestDismiss
        : null;
    Widget barrier = RepaintBoundary(
      child: CustomPaint(
        size: Size.infinite,
        painter: _DimPainter(
          progress: progress,
          sheet: sheet,
          color: config.enableWindowDim
              ? colors.windowDimming
              : const Color(0x00000000),
        ),
      ),
    );
    barrier = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onBarrierTap,
      excludeFromSemantics: true,
      child: barrier,
    );
    if (onBarrierTap != null) {
      barrier = Semantics(
        label: config.barrierLabel,
        onTap: onBarrierTap,
        child: barrier,
      );
    }

    return SoftTheme(
      data: theme,
      child: DefaultTextStyle(
        style: theme.textStyles.main.copyWith(color: colors.onBackground),
        child: SoftBottomSheetScope._(
          dismiss: route.requestDismiss,
          child: PopScope<Object?>(
            canPop: false,
            onPopInvokedWithResult: (bool didPop, Object? _) {
              if (!didPop) sheet.back();
            },
            child: Stack(
              children: <Widget>[
                Positioned.fill(child: barrier),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxWidth),
                    child: body,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Lifts the sheet above the keyboard; only this padding rebuilds while the
/// keyboard animates.
class _KeyboardPadding extends StatelessWidget {
  const _KeyboardPadding({required this.enabled, required this.child});

  final bool enabled;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: child,
    );
  }
}

/// Records the sheet's height only while the keyboard is closed, so the
/// keyboard padding never shifts the slide or the dim threshold.
class _SlideScope extends StatelessWidget {
  const _SlideScope({
    required this.sheet,
    required this.progress,
    required this.fill,
    required this.inset,
    required this.child,
  });

  final _SheetController sheet;
  final Animation<double> progress;
  final Color fill;
  final double inset;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return _SheetSlide(
      sheet: sheet,
      progress: progress,
      fill: fill,
      inset: inset,
      recordHeight: MediaQuery.viewInsetsOf(context).bottom == 0,
      child: child,
    );
  }
}

/// Paints its child moved down by the unrevealed part of the slide plus the
/// drag offset, and fills the gap an upward over-pull opens beneath it.
/// Paint only: neither drives a layout or a build.
class _SheetSlide extends SingleChildRenderObjectWidget {
  const _SheetSlide({
    required this.sheet,
    required this.progress,
    required this.fill,
    required this.inset,
    required this.recordHeight,
    super.child,
  });

  final _SheetController sheet;
  final Animation<double> progress;
  final Color fill;
  final double inset;
  final bool recordHeight;

  @override
  _RenderSheetSlide createRenderObject(BuildContext context) =>
      _RenderSheetSlide(
        sheet: sheet,
        progress: progress,
        fill: fill,
        inset: inset,
        recordHeight: recordHeight,
      );

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderSheetSlide renderObject,
  ) {
    renderObject
      ..progress = progress
      ..fill = fill
      ..inset = inset
      ..recordHeight = recordHeight;
  }
}

class _RenderSheetSlide extends RenderProxyBox {
  _RenderSheetSlide({
    required this.sheet,
    required Animation<double> progress,
    required Color fill,
    required double inset,
    required this.recordHeight,
  }) : _progress = progress,
       _fill = fill,
       _inset = inset;

  final _SheetController sheet;
  bool recordHeight;

  Animation<double> _progress;
  set progress(Animation<double> value) {
    if (value == _progress) return;
    if (attached) _progress.removeListener(markNeedsPaint);
    _progress = value;
    if (attached) _progress.addListener(markNeedsPaint);
    markNeedsPaint();
  }

  Color _fill;
  set fill(Color value) {
    if (value == _fill) return;
    _fill = value;
    markNeedsPaint();
  }

  double _inset;
  set inset(double value) {
    if (value == _inset) return;
    _inset = value;
    markNeedsPaint();
  }

  double get _dy {
    final double base = sheet.sheetHeight > 0
        ? sheet.sheetHeight
        : sheet.windowHeight;
    return base * (1 - _progress.value) + sheet.drag.value;
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _progress.addListener(markNeedsPaint);
    sheet.drag.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    _progress.removeListener(markNeedsPaint);
    sheet.drag.removeListener(markNeedsPaint);
    super.detach();
  }

  @override
  void performLayout() {
    final RenderBox? child = this.child;
    if (child == null) {
      size = constraints.smallest;
      return;
    }
    child.layout(
      constraints.tighten(width: constraints.maxWidth),
      parentUsesSize: true,
    );
    size = constraints.constrain(child.size);
    if (recordHeight) sheet.sheetHeight = size.height;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final RenderBox? child = this.child;
    if (child == null) return;
    final double drag = sheet.drag.value;
    if (drag < 0) {
      context.canvas.drawRect(
        Rect.fromLTRB(
          offset.dx + _inset,
          offset.dy + size.height + drag - 1,
          offset.dx + size.width - _inset,
          offset.dy + size.height,
        ),
        Paint()..color = _fill,
      );
    }
    context.paintChild(child, offset + Offset(0, _dy));
  }

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    final double dy = _dy;
    if (!(Offset.zero & size).contains(position - Offset(0, dy))) return false;
    final RenderBox? child = this.child;
    if (child != null) {
      result.addWithPaintOffset(
        offset: Offset(0, dy),
        position: position,
        hitTest: (BoxHitTestResult result, Offset transformed) =>
            child.hitTest(result, position: transformed),
      );
    }
    // The whole sheet, margins included, keeps taps from the barrier.
    result.add(BoxHitTestEntry(this, position));
    return true;
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    transform.translateByDouble(0, _dy, 0, 1);
  }
}

class _DimPainter extends CustomPainter {
  _DimPainter({
    required this.progress,
    required this.sheet,
    required this.color,
  }) : super(repaint: Listenable.merge(<Listenable>[progress, sheet.drag]));

  final Animation<double> progress;
  final _SheetController sheet;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final double alpha = color.a * sheet.dimAlpha * progress.value;
    if (alpha <= 0) return;
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = color.withValues(alpha: alpha),
    );
  }

  @override
  bool shouldRepaint(_DimPainter old) =>
      old.color != color || old.progress != progress || old.sheet != sheet;
}

/// The drag strip: a fixed bar over a rounded press background that fades
/// in while the strip is touched. Dragging it moves the sheet.
class _DragHandle extends StatefulWidget {
  const _DragHandle({
    required this.sheet,
    required this.color,
    required this.pressColor,
  });

  final _SheetController sheet;
  final Color color;
  final Color pressColor;

  @override
  State<_DragHandle> createState() => _DragHandleState();
}

class _DragHandleState extends State<_DragHandle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _press = AnimationController(
    vsync: this,
    duration: SoftBottomSheetDefaults.dragPressDuration,
  );
  late final Animation<double> _pressCurve = CurvedAnimation(
    parent: _press,
    curve: SoftBottomSheetDefaults.dragPressCurve,
  );

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  void _down() => _press.forward();

  void _up() => _press.reverse();

  @override
  Widget build(BuildContext context) {
    final _SheetController sheet = widget.sheet;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Listener(
        onPointerDown: (_) => _down(),
        onPointerUp: (_) => _up(),
        onPointerCancel: (_) => _up(),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          excludeFromSemantics: true,
          onVerticalDragStart: (_) => _down(),
          onVerticalDragUpdate: (DragUpdateDetails d) =>
              sheet.dragBy(d.delta.dy),
          onVerticalDragEnd: (DragEndDetails d) {
            _up();
            sheet.settle(d.velocity.pixelsPerSecond.dy);
          },
          onVerticalDragCancel: () {
            _up();
            sheet.settle(0);
          },
          child: SizedBox(
            height: SoftBottomSheetDefaults.dragAreaHeight,
            width: double.infinity,
            child: CustomPaint(
              painter: _HandlePainter(
                press: _pressCurve,
                color: widget.color,
                pressColor: widget.pressColor,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HandlePainter extends CustomPainter {
  _HandlePainter({
    required this.press,
    required this.color,
    required this.pressColor,
  }) : super(repaint: press);

  final Animation<double> press;
  final Color color;
  final Color pressColor;

  @override
  void paint(Canvas canvas, Size size) {
    const double top = SoftBottomSheetDefaults.dragPressTop;
    final Offset centre = Offset(size.width / 2, top + (size.height - top) / 2);
    final double t = press.value;
    if (t > 0) {
      const Size s = SoftBottomSheetDefaults.dragPressSize;
      final Rect rect = Rect.fromCenter(
        center: centre,
        width: s.width,
        height: s.height,
      );
      final double r = math.min(
        SoftBottomSheetDefaults.dragPressRadius,
        s.shortestSide / 2,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(r)),
        Paint()..color = pressColor.withValues(alpha: pressColor.a * t),
      );
    }
    const Size bar = SoftBottomSheetDefaults.dragBarSize;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: centre, width: bar.width, height: bar.height),
        Radius.circular(bar.height / 2),
      ),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(_HandlePainter old) =>
      old.press != press || old.color != color || old.pressColor != pressColor;
}

/// The title centred between the start and end actions, 6 above and 12
/// below.
class _TitleRow extends StatelessWidget {
  const _TitleRow({
    required this.title,
    required this.startAction,
    required this.endAction,
    required this.style,
  });

  final String? title;
  final Widget? startAction;
  final Widget? endAction;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final String? t = title;
    return Padding(
      padding: const EdgeInsets.only(
        top: SoftBottomSheetDefaults.titleTopPadding,
        bottom: SoftBottomSheetDefaults.titleBottomPadding,
      ),
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          const SizedBox(width: double.infinity),
          if (startAction != null)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: startAction,
            ),
          if (t != null)
            Align(
              child: Semantics(
                header: true,
                child: Text(t, textAlign: TextAlign.center, style: style),
              ),
            ),
          if (endAction != null)
            Align(alignment: AlignmentDirectional.centerEnd, child: endAction),
        ],
      ),
    );
  }
}

/// Routes a vertical scroll view's drags into the sheet: a pulled-down
/// sheet is restored before the content scrolls up, a downward drag past
/// the content's top pulls the sheet, and a release with the sheet pulled
/// settles it instead of flinging the content.
class _SheetScrollPhysics extends ScrollPhysics {
  const _SheetScrollPhysics(this.sheet, {super.parent});

  final _SheetController sheet;

  @override
  _SheetScrollPhysics applyTo(ScrollPhysics? ancestor) =>
      _SheetScrollPhysics(sheet, parent: buildParent(ancestor));

  bool _owns(ScrollMetrics position) =>
      position.axisDirection == AxisDirection.down;

  @override
  bool shouldAcceptUserOffset(ScrollMetrics position) =>
      _owns(position) || super.shouldAcceptUserOffset(position);

  @override
  double applyPhysicsToUserOffset(ScrollMetrics position, double offset) {
    if (!_owns(position)) {
      return super.applyPhysicsToUserOffset(position, offset);
    }
    sheet.cancelSettle();
    final double current = sheet.offset;
    if (offset < 0 && current > 0) {
      final double next = math.max(0.0, sheet.resisted(current, offset));
      sheet.snap(next);
      final double rest = offset + (current - next);
      return rest == 0 ? 0 : super.applyPhysicsToUserOffset(position, rest);
    }
    if (offset > 0 && sheet.config.allowDismiss) {
      final double room = math.max(
        0.0,
        position.pixels - position.minScrollExtent,
      );
      final double toSheet = offset - math.min(offset, room);
      if (toSheet > 0) {
        sheet.dragBy(toSheet);
        if (sheet.offset > sheet.windowHeight) sheet.settle(0);
        final double scrolled = offset - toSheet;
        return scrolled == 0
            ? 0
            : super.applyPhysicsToUserOffset(position, scrolled);
      }
    }
    return super.applyPhysicsToUserOffset(position, offset);
  }

  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) {
    if (_owns(position) && !sheet.settling && sheet.offset > 0) {
      // Scroll velocity is positive towards the end; the sheet's downwards.
      sheet.settle(-velocity);
      return null;
    }
    return super.createBallisticSimulation(position, velocity);
  }
}
