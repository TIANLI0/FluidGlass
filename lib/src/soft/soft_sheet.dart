import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import 'soft_frosted.dart';
import 'soft_motion.dart';
import 'soft_theme.dart';

/// Shows a bottom sheet on a translucent, blurred panel with 32 top corners
/// and a 36 × 4 drag handle.
///
/// It rises on a critically damped spring whose response grows with the
/// sheet's height (0.25 for a short sheet up to 0.45 for a full one; closing
/// 0.18 → 0.37), the scrim following the same spring. Dragging it down past
/// half way, or flinging it down faster than 500 / s, dismisses it; dragging
/// up stretches it like a rubber band (half the distance, at most 28).
///
/// [builder] supplies the content; [title] adds a centred 18 medium title row
/// under the handle. Returns what the sheet is popped with.
Future<T?> showSoftSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  String? title,
  bool isDismissible = true,
}) {
  final SoftThemeData theme = SoftTheme.of(context);
  return Navigator.of(context, rootNavigator: true).push<T>(
    _SheetRoute<T>(
      theme: theme,
      builder: builder,
      title: title,
      isDismissible: isDismissible,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    ),
  );
}

class _SheetRoute<T> extends PopupRoute<T> {
  _SheetRoute({
    required this.theme,
    required this.builder,
    required this.title,
    required this.isDismissible,
    required this.barrierLabel,
  });

  final SoftThemeData theme;
  final WidgetBuilder builder;
  final String? title;
  final bool isDismissible;

  @override
  final String? barrierLabel;

  // The sheet draws its own scrim and runs its own springs.
  @override
  Color? get barrierColor => null;

  @override
  bool get barrierDismissible => false;

  @override
  Duration get transitionDuration => Duration.zero;

  @override
  Duration get reverseTransitionDuration => Duration.zero;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) => SoftTheme(
    data: theme,
    child: _Sheet<T>(
      builder: builder,
      title: title,
      isDismissible: isDismissible,
    ),
  );
}

class _Sheet<T> extends StatefulWidget {
  const _Sheet({
    required this.builder,
    required this.title,
    required this.isDismissible,
  });

  final WidgetBuilder builder;
  final String? title;
  final bool isDismissible;

  @override
  State<_Sheet<T>> createState() => _SheetState<T>();
}

class _SheetState<T> extends State<_Sheet<T>>
    with SingleTickerProviderStateMixin {
  /// How far the sheet has risen, in logical pixels (0 = hidden).
  late final AnimationController _rise = AnimationController.unbounded(
    vsync: this,
  );
  final GlobalKey _panelKey = GlobalKey();
  double _height = 0;
  double _available = 0;
  bool _closing = false;
  Object? _result;

  bool get _reduce => softReduceMotion(context);

  double get _fraction =>
      _available <= 0 ? 0 : (_height / _available).clamp(0.0, 1.0);

  SpringDescription _openSpring() =>
      softSpring(0.25 + (0.45 - 0.25) * _fraction);

  SpringDescription _closeSpring() =>
      softSpring(0.18 + (0.37 - 0.18) * _fraction);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _measureAndOpen());
  }

  void _measureAndOpen() {
    if (!mounted) return;
    final RenderBox? box =
        _panelKey.currentContext?.findRenderObject() as RenderBox?;
    _height = box?.size.height ?? 0;
    _rise.springTo(_height, _openSpring(), reduceMotion: _reduce);
  }

  Future<void> _close([Object? result]) async {
    if (_closing) return;
    _closing = true;
    _result = result;
    await _rise.springTo(0, _closeSpring(), reduceMotion: _reduce);
    if (mounted) Navigator.of(context).pop(_result as T?);
  }

  /// Where the finger has taken the sheet, before the rubber band above the
  /// fully open position is applied.
  double _raw = 0;

  void _dragStart(DragStartDetails d) {
    _raw = _rise.value;
    _rise.stop();
  }

  void _dragUpdate(DragUpdateDetails d) {
    if (_closing) return;
    _raw -= d.delta.dy;
    _rise.value = _raw <= _height
        ? _raw
        : _height + math.min(28, (_raw - _height) * 0.5);
  }

  void _dragEnd(DragEndDetails d) {
    if (_closing) return;
    final double vy = d.velocity.pixelsPerSecond.dy;
    final bool dismiss =
        widget.isDismissible && (vy > 500 || _rise.value < _height / 2);
    if (dismiss) {
      _close();
      return;
    }
    _rise.animateWith(
      SpringSimulation(softSpring(0.4), _rise.value, _height, -vy),
    );
  }

  @override
  void dispose() {
    _rise.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final SoftThemeData theme = SoftTheme.of(context);
    final MediaQueryData media = MediaQuery.of(context);
    _available = media.size.height - media.viewPadding.top - 40;
    final double width = math.min(540, media.size.width);
    final Widget panel = KeyedSubtree(
      key: _panelKey,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: _available, maxWidth: width),
        child: SoftFrosted(
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(32),
              bottom: Radius.circular(28),
            ),
          ),
          tint: theme.backgroundElevated.withValues(
            alpha: theme.isDark ? 0.78 : 0.84,
          ),
          sigma: 36,
          child: Material(
            type: MaterialType.transparency,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onVerticalDragStart: _dragStart,
                  onVerticalDragUpdate: _dragUpdate,
                  onVerticalDragEnd: _dragEnd,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const SizedBox(height: 12),
                      Container(
                        width: 36,
                        height: 4,
                        decoration: ShapeDecoration(
                          color: theme.controls,
                          shape: const StadiumBorder(),
                        ),
                      ),
                      if (widget.title != null)
                        ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 52),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
                            child: Center(
                              child: Text(
                                widget.title!,
                                maxLines: 2,
                                textAlign: TextAlign.center,
                                style: theme.text(18, weight: FontWeight.w600),
                              ),
                            ),
                          ),
                        )
                      else
                        const SizedBox(height: 12),
                    ],
                  ),
                ),
                Flexible(
                  child: _SheetScope(
                    close: _close,
                    child: Padding(
                      padding: EdgeInsets.only(
                        bottom: media.viewPadding.bottom,
                      ),
                      child: Builder(builder: widget.builder),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    return PopScope<T>(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, T? result) {
        if (!didPop) _close(result);
      },
      child: AnimatedBuilder(
        animation: _rise,
        builder: (BuildContext context, Widget? child) {
          final double visible = _height <= 0
              ? 0
              : (_rise.value / _height).clamp(0.0, 1.0);
          return Stack(
            children: <Widget>[
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: widget.isDismissible ? _close : null,
                  child: ColoredBox(
                    color: theme.scrim.withValues(
                      alpha: theme.scrim.a * visible,
                    ),
                  ),
                ),
              ),
              Positioned(
                left: (media.size.width - width) / 2,
                width: width,
                bottom: (_height <= 0 ? -10000 : _rise.value - _height),
                child: child!,
              ),
            ],
          );
        },
        child: panel,
      ),
    );
  }
}

/// Lets sheet content close its sheet with the rising-and-falling animation.
class _SheetScope extends InheritedWidget {
  const _SheetScope({required this.close, required super.child});

  final Future<void> Function([Object? result]) close;

  @override
  bool updateShouldNotify(_SheetScope oldWidget) => false;
}

/// Closes the nearest soft sheet (animating it down) with [result].
Future<void> closeSoftSheet(BuildContext context, [Object? result]) async {
  final _SheetScope? scope = context
      .getInheritedWidgetOfExactType<_SheetScope>();
  if (scope != null) {
    await scope.close(result);
  } else {
    Navigator.of(context).pop(result);
  }
}
