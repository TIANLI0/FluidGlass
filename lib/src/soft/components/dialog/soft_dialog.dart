import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../foundation/soft_colors.dart';
import '../../foundation/soft_motion.dart';
import '../../foundation/soft_squircle.dart';
import '../../foundation/soft_theme.dart';

/// The dialog defaults.
abstract final class SoftDialogDefaults {
  /// 19 smooth corners.
  static const double cornerRadius = 19;

  /// The widest a panel grows on tablets and desktops.
  static const double maxWidth = 392;

  /// The space around the panel: `width` on both sides, `height` below it.
  /// Above it the panel keeps clear of the status bar.
  static const Size outsideMargin = Size(16, 32);

  /// The built-in texts' margins: `width` on both sides of the title and
  /// the summary, `height` above the title. The content slot is not padded,
  /// so a button bar spans the panel edge to edge.
  static const Size insideMargin = Size(24, 24);

  /// A window at least this wide (and [largeScreenMinHeight] tall) centres
  /// the dialog instead of anchoring it to the bottom.
  static const double largeScreenMinWidth = 840;

  /// See [largeScreenMinWidth].
  static const double largeScreenMinHeight = 480;

  /// A centred panel is at most this fraction of the window height.
  static const double centeredMaxHeightFraction = 2 / 3;

  /// Entering, both presentations.
  static const Duration enterDuration = Duration(milliseconds: 250);

  /// Leaving a bottom-anchored dialog (it slides out).
  static const Duration bottomExitDuration = Duration(milliseconds: 250);

  /// Leaving a centred dialog (it fades out).
  static const Duration centerExitDuration = Duration(milliseconds: 150);

  /// The entering curve.
  static const Cubic enterCurve = Cubic(0.3, 0, 0.1, 1);

  /// The leaving curve.
  static const Cubic exitCurve = Cubic(0.3, 0, 1, 1);

  /// The scale a centred panel enters from.
  static const double enterScale = 0.8;

  /// How far a back gesture shrinks a centred panel.
  static const double backGestureScale = 0.2;

  /// How long a cancelled back gesture takes to settle back, per stage.
  static const Duration backResetDuration = Duration(milliseconds: 150);

  /// The title and summary line height, as a multiple of the font size.
  static const double lineHeight = 1.29;

  /// The gap below the title.
  static const double titleMarginBottom = 6;

  /// The summary's vertical padding while the title and the summary each
  /// fit on one line.
  static const double summaryPaddingVertical = 18;

  /// The summary's vertical padding once either of them wraps.
  static const double summaryPaddingVerticalTall = 8;

  /// Whether a window of [size] gets the centred presentation.
  static bool isLargeScreen(Size size) =>
      size.width >= largeScreenMinWidth && size.height >= largeScreenMinHeight;

  /// The title colour: `onBackground`.
  static Color titleColor(SoftColors colors) => colors.onBackground;

  /// The summary colour: `onBackground`, the same as the title.
  static Color summaryColor(SoftColors colors) => colors.onBackground;

  /// The panel colour: `background`.
  static Color backgroundColor(SoftColors colors) => colors.background;
}

/// Shows a dialog: a panel with an optional [title] and [summary] and the
/// content [builder] builds below them.
///
/// On a phone the panel is anchored to the bottom of the screen and slides
/// up by its own height (250 ms); it slides out to the bottom of the window.
/// On a window at least 840 × 480 — or with [largeScreen] true — it is
/// centred, scales from 0.8 while fading in (250 ms) and fades out (150 ms).
/// The window dims behind it on the same curves.
///
/// With [dismissible], a tap outside the panel, the back button and the
/// back gesture (which shrinks or lowers the panel as it is dragged) pop the
/// dialog with a null result. Content pops it with `Navigator.pop`.
///
/// The panel keeps clear of the keyboard and the system bars, and never
/// grows wider than [maxWidth]. With a [summary] the summary scrolls when the
/// panel runs out of height; without one the content is given the remaining
/// height instead.
Future<T?> showSoftDialog<T>({
  required BuildContext context,
  WidgetBuilder? builder,
  String? title,
  String? summary,
  Color? titleColor,
  Color? summaryColor,
  Color? backgroundColor,
  bool dismissible = true,
  bool enableWindowDim = true,
  bool? largeScreen,
  double maxWidth = SoftDialogDefaults.maxWidth,
  double? cornerRadius,
  Size outsideMargin = SoftDialogDefaults.outsideMargin,
  Size insideMargin = SoftDialogDefaults.insideMargin,
  bool defaultWindowInsetsPadding = true,
  bool useRootNavigator = true,
  RouteSettings? routeSettings,
  String? barrierLabel,
  VoidCallback? onDismissFinished,
}) {
  final SoftDialogRoute<T> route = SoftDialogRoute<T>(
    builder: builder,
    title: title,
    summary: summary,
    titleColor: titleColor,
    summaryColor: summaryColor,
    backgroundColor: backgroundColor,
    dismissible: dismissible,
    enableWindowDim: enableWindowDim,
    largeScreen: largeScreen,
    maxWidth: maxWidth,
    cornerRadius: cornerRadius,
    outsideMargin: outsideMargin,
    insideMargin: insideMargin,
    defaultWindowInsetsPadding: defaultWindowInsetsPadding,
    barrierLabel: barrierLabel,
    settings: routeSettings,
  );
  return pushSoftDialogRoute<T>(
    context,
    route,
    useRootNavigator: useRootNavigator,
    onDismissFinished: onDismissFinished,
  );
}

/// Pushes [route] and calls [onDismissFinished] once its exit animation has
/// finished.
Future<T?> pushSoftDialogRoute<T>(
  BuildContext context,
  SoftDialogRoute<T> route, {
  bool useRootNavigator = true,
  VoidCallback? onDismissFinished,
}) {
  final Future<T?> result = Navigator.of(
    context,
    rootNavigator: useRootNavigator,
  ).push<T>(route);
  if (onDismissFinished != null) {
    route.completed.then((_) => onDismissFinished());
  }
  return result;
}

/// The route behind [showSoftDialog] and the other soft dialogs.
///
/// It draws its own dimming, handles taps outside the panel and the back
/// gesture, and animates the panel itself, so the route's own animation
/// only times its arrival and removal.
class SoftDialogRoute<T> extends PopupRoute<T> {
  SoftDialogRoute({
    this.builder,
    this.title,
    this.summary,
    this.titleColor,
    this.summaryColor,
    this.backgroundColor,
    this.dismissible = true,
    this.enableWindowDim = true,
    this.largeScreen,
    this.maxWidth = SoftDialogDefaults.maxWidth,
    this.cornerRadius,
    this.outsideMargin = SoftDialogDefaults.outsideMargin,
    this.insideMargin = SoftDialogDefaults.insideMargin,
    this.defaultWindowInsetsPadding = true,
    this.fillWidth = true,
    String? barrierLabel,
    super.settings,
  }) : _barrierLabel = barrierLabel;

  /// Builds the content below the title and the summary.
  final WidgetBuilder? builder;
  final String? title;
  final String? summary;
  final Color? titleColor;
  final Color? summaryColor;
  final Color? backgroundColor;

  /// Whether a tap outside, the back button and the back gesture pop it.
  final bool dismissible;

  /// Whether the window dims behind the panel.
  final bool enableWindowDim;

  /// Forces the centred (true) or bottom-anchored (false) presentation;
  /// null picks by window size.
  final bool? largeScreen;
  final double maxWidth;

  /// [SoftDialogDefaults.cornerRadius] when null.
  final double? cornerRadius;
  final Size outsideMargin;
  final Size insideMargin;

  /// Whether the panel keeps clear of the keyboard and the navigation bar.
  final bool defaultWindowInsetsPadding;

  /// Whether the panel takes the full width it is allowed; when false it
  /// wraps its content (the loading and progress cards).
  final bool fillWidth;

  final String? _barrierLabel;

  /// Whether the dialog was last laid out centred; picks the exit duration.
  bool _centered = false;

  /// Set once the route starts popping, so a second tap during the exit
  /// does not pop the route below.
  bool _dismissing = false;

  @override
  Color? get barrierColor => null;

  // Taps outside the panel are handled by the dialog itself.
  @override
  bool get barrierDismissible => false;

  @override
  String? get barrierLabel => _barrierLabel;

  @override
  Duration get transitionDuration => SoftDialogDefaults.enterDuration;

  @override
  Duration get reverseTransitionDuration => _centered
      ? SoftDialogDefaults.centerExitDuration
      : SoftDialogDefaults.bottomExitDuration;

  @override
  RoutePopDisposition get popDisposition =>
      dismissible ? super.popDisposition : RoutePopDisposition.doNotPop;

  @override
  bool didPop(T? result) {
    // The exit duration depends on the presentation, which is only known
    // once the dialog has been laid out.
    _dismissing = true;
    controller?.reverseDuration = reverseTransitionDuration;
    return super.didPop(result);
  }

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return _SoftDialogShell(
      route: this,
      child: SoftDialogPanel(
        title: title,
        summary: summary,
        titleColor: titleColor,
        summaryColor: summaryColor,
        backgroundColor: backgroundColor,
        cornerRadius: cornerRadius ?? SoftDialogDefaults.cornerRadius,
        insideMargin: insideMargin,
        fillWidth: fillWidth,
        child: builder == null ? null : Builder(builder: builder!),
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

/// Pops the dialog route [context] is in, if that is a [SoftDialogRoute] that
/// is still on its navigator.
void dismissSoftDialog<T>(BuildContext context, [T? result]) {
  final ModalRoute<Object?>? route = ModalRoute.of(context);
  if (route is! SoftDialogRoute || !route.isActive || route._dismissing) {
    return;
  }
  final NavigatorState? navigator = route.navigator;
  if (navigator == null) return;
  if (route.isCurrent) {
    navigator.pop<T>(result);
  } else {
    navigator.removeRoute(route, result);
  }
}

/// Dims the window, catches taps outside the panel, follows the back
/// gesture and animates the panel in and out.
class _SoftDialogShell extends StatefulWidget {
  const _SoftDialogShell({required this.route, required this.child});

  final SoftDialogRoute<dynamic> route;
  final Widget child;

  @override
  State<_SoftDialogShell> createState() => _SoftDialogShellState();
}

class _SoftDialogShellState extends State<_SoftDialogShell>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  /// The eased enter / exit progress: 0 hidden, 1 shown.
  late final AnimationController _progress = AnimationController(vsync: this);

  /// The back gesture's progress.
  late final AnimationController _back = AnimationController(vsync: this);

  /// The dimming's own alpha, lowered by the back gesture.
  late final AnimationController _dimAlpha = AnimationController(
    vsync: this,
    value: 1,
  );

  late final Listenable _panelMotion = Listenable.merge(<Listenable>[
    _progress,
    _back,
  ]);

  Animation<double>? _routeAnimation;
  bool _showing = true;
  bool _gesture = false;

  SoftDialogRoute<dynamic> get _route => widget.route;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _routeAnimation = _route.animation?..addStatusListener(_onRouteStatus);
    _progress.animateTo(
      1,
      duration: SoftDialogDefaults.enterDuration,
      curve: SoftDialogDefaults.enterCurve,
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _routeAnimation?.removeStatusListener(_onRouteStatus);
    _progress.dispose();
    _back.dispose();
    _dimAlpha.dispose();
    super.dispose();
  }

  void _onRouteStatus(AnimationStatus status) {
    if (status != AnimationStatus.reverse || !_showing) return;
    _showing = false;
    _progress.animateTo(
      0,
      duration: _route.reverseTransitionDuration,
      curve: SoftDialogDefaults.exitCurve,
    );
  }

  void _requestDismiss() {
    if (!_route.dismissible || !_showing) return;
    dismissSoftDialog<Object?>(context);
  }

  // Predictive back.

  @override
  bool handleStartBackGesture(PredictiveBackEvent backEvent) {
    if (!_route.isCurrent ||
        !_route.dismissible ||
        !_showing ||
        _route.animation?.status != AnimationStatus.completed) {
      return false;
    }
    _gesture = true;
    _back.stop();
    _dimAlpha.stop();
    _followGesture(backEvent.progress);
    return true;
  }

  @override
  void handleUpdateBackGestureProgress(PredictiveBackEvent backEvent) {
    if (_gesture) _followGesture(backEvent.progress);
  }

  @override
  void handleCommitBackGesture() {
    if (!_gesture) return;
    _gesture = false;
    // The panel leaves from wherever the gesture left it.
    _requestDismiss();
  }

  @override
  void handleCancelBackGesture() {
    if (!_gesture) return;
    _gesture = false;
    _resetGesture();
  }

  void _followGesture(double progress) {
    _back.value = progress;
    _dimAlpha.value = 1 - progress;
  }

  Future<void> _resetGesture() async {
    await _back.animateTo(
      0,
      duration: SoftDialogDefaults.backResetDuration,
      curve: Curves.fastOutSlowIn,
    );
    if (!mounted || _gesture) return;
    await _dimAlpha.animateTo(
      1,
      duration: SoftDialogDefaults.backResetDuration,
      curve: Curves.fastOutSlowIn,
    );
  }

  @override
  Widget build(BuildContext context) {
    final SoftThemeData theme = SoftTheme.of(context);
    final SoftDialogRoute<dynamic> route = _route;
    final Size window = MediaQuery.sizeOf(context);
    final EdgeInsets padding = MediaQuery.paddingOf(context);
    final EdgeInsets viewPadding = MediaQuery.viewPaddingOf(context);
    final EdgeInsets viewInsets = MediaQuery.viewInsetsOf(context);
    final bool reduceMotion = softReduceMotion(context);
    final bool centered =
        route.largeScreen ?? SoftDialogDefaults.isLargeScreen(window);
    route._centered = centered;

    // Keyboard and navigation bar; the status bar is avoided either way.
    final EdgeInsets insets = route.defaultWindowInsetsPadding
        ? EdgeInsets.only(
            left: padding.left,
            right: padding.right,
            bottom: viewInsets.bottom + padding.bottom,
          )
        : EdgeInsets.zero;
    final double horizontal = route.outsideMargin.width;
    final EdgeInsets outer = EdgeInsets.fromLTRB(
      insets.left + horizontal,
      padding.top,
      insets.right + horizontal,
      insets.bottom + route.outsideMargin.height,
    );
    // How far below its resting place the panel starts sliding in, and how
    // far the back gesture can push it: down to the screen edge.
    final double slideBottom = centered
        ? 0
        : viewPadding.bottom + route.outsideMargin.height;

    final Widget panel = AnimatedBuilder(
      animation: _panelMotion,
      child: widget.child,
      builder: (BuildContext context, Widget? child) {
        final double p = _progress.value;
        final double back = _back.value;
        if (centered) {
          final double enter = _showing && !reduceMotion
              ? SoftDialogDefaults.enterScale +
                    (1 - SoftDialogDefaults.enterScale) * p
              : 1;
          return Opacity(
            opacity: p.clamp(0.0, 1.0),
            child: Transform.scale(
              scale: enter * (1 - SoftDialogDefaults.backGestureScale * back),
              child: child,
            ),
          );
        }
        double fraction = back;
        double pixels = back * slideBottom;
        if (!reduceMotion) {
          if (_showing) {
            fraction += 1 - p;
            pixels += (1 - p) * slideBottom;
          } else {
            pixels += (1 - p) * window.height;
          }
        }
        return Opacity(
          opacity: reduceMotion ? p.clamp(0.0, 1.0) : 1,
          child: Transform.translate(
            offset: Offset(0, pixels),
            child: FractionalTranslation(
              translation: Offset(0, fraction),
              child: child,
            ),
          ),
        );
      },
    );

    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        Semantics(
          label: route.dismissible ? route.barrierLabel : null,
          onTap: route.dismissible ? _requestDismiss : null,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: route.dismissible ? _requestDismiss : null,
            child: route.enableWindowDim
                ? CustomPaint(
                    painter: _DimPainter(
                      color: theme.colors.windowDimming,
                      progress: _progress,
                      alpha: _dimAlpha,
                    ),
                  )
                : const SizedBox.expand(),
          ),
        ),
        Padding(
          padding: outer,
          child: Align(
            alignment: centered ? Alignment.center : Alignment.bottomCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: route.maxWidth,
                maxHeight: centered
                    ? window.height *
                          SoftDialogDefaults.centeredMaxHeightFraction
                    : double.infinity,
              ),
              child: panel,
            ),
          ),
        ),
      ],
    );
  }
}

class _DimPainter extends CustomPainter {
  _DimPainter({
    required this.color,
    required this.progress,
    required this.alpha,
  }) : super(repaint: Listenable.merge(<Listenable>[progress, alpha]));

  final Color color;
  final Animation<double> progress;
  final Animation<double> alpha;

  @override
  void paint(Canvas canvas, Size size) {
    final double a =
        color.a * progress.value.clamp(0.0, 1.0) * alpha.value.clamp(0.0, 1.0);
    if (a <= 0) return;
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = color.withValues(alpha: a),
    );
  }

  @override
  bool shouldRepaint(_DimPainter old) =>
      old.color != color || old.progress != progress || old.alpha != alpha;
}

/// The dialog panel: a smooth-cornered surface holding an optional [title]
/// (18 medium, centred) and [summary] (14, centred on one line and
/// start-aligned once it wraps) over [child].
///
/// The summary's vertical padding drops from 18 to 8 once the title or the
/// summary wraps. [showSoftDialog] builds one; it is public for previews
/// and custom routes.
class SoftDialogPanel extends StatelessWidget {
  const SoftDialogPanel({
    super.key,
    this.title,
    this.summary,
    this.titleColor,
    this.summaryColor,
    this.backgroundColor,
    this.cornerRadius = SoftDialogDefaults.cornerRadius,
    this.insideMargin = SoftDialogDefaults.insideMargin,
    this.fillWidth = true,
    this.child,
  });

  final String? title;
  final String? summary;
  final Color? titleColor;
  final Color? summaryColor;
  final Color? backgroundColor;
  final double cornerRadius;
  final Size insideMargin;

  /// Whether the panel takes the full width it is allowed.
  final bool fillWidth;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final SoftThemeData theme = SoftTheme.of(context);
    final SoftColors colors = theme.colors;
    final SoftSquircleBorder shape = SoftSquircleBorder(
      radius: BorderRadius.circular(cornerRadius),
      smooth: theme.smoothCorners,
    );
    final bool hasText = title != null || summary != null;
    final Widget body = hasText
        ? LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) =>
                _column(context, theme, colors, constraints.maxWidth),
          )
        : _column(context, theme, colors, 0);
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: backgroundColor ?? SoftDialogDefaults.backgroundColor(colors),
        shape: shape,
      ),
      child: ClipPath(
        clipper: ShapeBorderClipper(shape: shape),
        child: body,
      ),
    );
  }

  Widget _column(
    BuildContext context,
    SoftThemeData theme,
    SoftColors colors,
    double width,
  ) {
    final List<Widget> children = <Widget>[];
    final String? t = title;
    final String? s = summary;
    if (t != null || s != null) {
      final TextStyle base = DefaultTextStyle.of(context).style;
      final TextStyle titleStyle = base.merge(
        theme.textStyles.title4.copyWith(
          fontWeight: FontWeight.w500,
          height: SoftDialogDefaults.lineHeight,
          color: titleColor ?? SoftDialogDefaults.titleColor(colors),
        ),
      );
      final TextStyle summaryStyle = base.merge(
        theme.textStyles.body2.copyWith(
          height: SoftDialogDefaults.lineHeight,
          color: summaryColor ?? SoftDialogDefaults.summaryColor(colors),
        ),
      );
      final double textWidth = math.max(0, width - insideMargin.width * 2);
      final bool titleWraps =
          t != null && _wraps(context, t, titleStyle, textWidth);
      final bool summaryWraps =
          s != null && _wraps(context, s, summaryStyle, textWidth);
      if (t != null) {
        children.add(
          Padding(
            padding: EdgeInsets.fromLTRB(
              insideMargin.width,
              insideMargin.height,
              insideMargin.width,
              SoftDialogDefaults.titleMarginBottom,
            ),
            child: Semantics(
              header: true,
              namesRoute: true,
              child: Text(t, style: titleStyle, textAlign: TextAlign.center),
            ),
          ),
        );
      }
      if (s != null) {
        children.add(
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: insideMargin.width,
                vertical: titleWraps || summaryWraps
                    ? SoftDialogDefaults.summaryPaddingVerticalTall
                    : SoftDialogDefaults.summaryPaddingVertical,
              ),
              child: Text(
                s,
                style: summaryStyle,
                textAlign: summaryWraps ? TextAlign.start : TextAlign.center,
              ),
            ),
          ),
        );
      }
    }
    final Widget? content = child;
    if (content != null) {
      children.add(s == null ? Flexible(child: content) : content);
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: fillWidth
          ? CrossAxisAlignment.stretch
          : CrossAxisAlignment.center,
      children: children,
    );
  }

  static bool _wraps(
    BuildContext context,
    String text,
    TextStyle style,
    double width,
  ) {
    if (width <= 0) return false;
    final TextPainter painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      locale: Localizations.maybeLocaleOf(context),
    )..layout(maxWidth: width);
    final bool wraps = painter.computeLineMetrics().length > 1;
    painter.dispose();
    return wraps;
  }
}
