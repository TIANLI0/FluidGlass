// Derived from coui17 basic/PullToRefresh.kt, Apache-2.0.
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../foundation/soft_motion.dart';
import '../../foundation/soft_theme.dart';

enum SoftRefreshPhase { idle, pulling, armed, refreshing, complete }

/// A refresh header that follows scroll overscroll without taking horizontal
/// gestures. Supply an AlwaysScrollableScrollPhysics for short lists.
/// [onRefresh] must finish when loading finishes; repeated requests coalesce.
class SoftPullToRefresh extends StatefulWidget {
  const SoftPullToRefresh({
    super.key,
    required this.onRefresh,
    required this.child,
    this.enabled = true,
    this.triggerDistance,
    this.edgeOffset = 0,
    this.color,
    this.pullLabel = 'Pull down to refresh',
    this.releaseLabel = 'Release to refresh',
    this.refreshingLabel = 'Refreshing…',
    this.completeLabel = 'Refreshed',
    this.onError,
    this.haptics = true,
    this.notificationPredicate = defaultScrollNotificationPredicate,
  }) : assert(triggerDistance == null || triggerDistance > 0),
       assert(edgeOffset >= 0);

  final Future<void> Function() onRefresh;
  final Widget child;
  final bool enabled;
  final bool haptics;
  final double? triggerDistance;
  final double edgeOffset;
  final Color? color;
  final String pullLabel, releaseLabel, refreshingLabel, completeLabel;
  final void Function(Object error, StackTrace stack)? onError;
  final ScrollNotificationPredicate notificationPredicate;

  @override
  State<SoftPullToRefresh> createState() => SoftPullToRefreshState();
}

class SoftPullToRefreshState extends State<SoftPullToRefresh>
    with TickerProviderStateMixin {
  late final AnimationController _offset = AnimationController.unbounded(
    vsync: this,
  );
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 1),
  );
  late final AnimationController _complete = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 200),
  );
  SoftRefreshPhase _phase = SoftRefreshPhase.idle;
  SoftRefreshPhase get phase => _phase;
  Future<void>? _operation;
  double _drag = 0;
  bool _bouncing = false;
  bool _settlingForRefresh = false;
  bool _pointerDown = false;
  final Set<int> _pointers = <int>{};
  bool _reduce = false;
  double get _threshold =>
      widget.triggerDistance ?? MediaQuery.sizeOf(context).height / 24;
  double get _dragRange =>
      math.max(MediaQuery.sizeOf(context).height, _threshold * 4);

  void _setPhase(SoftRefreshPhase phase) {
    if (phase == _phase) return;
    if (phase == SoftRefreshPhase.armed && widget.haptics) {
      HapticFeedback.mediumImpact();
    }
    setState(() => _phase = phase);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduce = softReduceMotion(context);
    if (_reduce) {
      _spin.stop();
      _offset.value = _phase == SoftRefreshPhase.refreshing ? _threshold : 0;
    } else if (_phase == SoftRefreshPhase.refreshing && !_spin.isAnimating) {
      _spin.repeat();
    }
  }

  @override
  void didUpdateWidget(SoftPullToRefresh oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled && _phase != SoftRefreshPhase.refreshing) {
      _drag = 0;
      _offset.value = 0;
      _phase = SoftRefreshPhase.idle;
    }
  }

  Future<void> _settle(double value) async {
    if (_reduce) {
      _offset.value = value;
    } else {
      await _offset
          .animateWith(
            _ReferenceRefreshSpring(
              _offset.value,
              value,
              1 / MediaQuery.devicePixelRatioOf(context),
            ),
          )
          .orCancel;
      if (mounted) _offset.value = value;
    }
  }

  void _pull(double delta) {
    if (!widget.enabled || !_pointerDown || _operation != null) return;
    _drag = math.max(0, _drag + delta);
    // The reference normalizes finger travel by the full viewport height.
    // The 1/6 factor belongs to the trigger calculation, not this range.
    final double range = _dragRange;
    final double distance = SoftRubberBand.dampingDistance(
      _drag / math.max(range, 1),
      range,
    );
    _offset.value = distance;
    _setPhase(
      distance >= _threshold
          ? SoftRefreshPhase.armed
          : (distance > 0 ? SoftRefreshPhase.pulling : SoftRefreshPhase.idle),
    );
  }

  bool _onScroll(ScrollNotification notification) {
    if (!widget.notificationPredicate(notification) ||
        notification.metrics.axis != Axis.vertical) {
      return false;
    }
    if (notification is OverscrollNotification &&
        notification.dragDetails != null &&
        notification.overscroll < 0) {
      _pull(-notification.overscroll);
    } else if (notification is ScrollUpdateNotification &&
        notification.dragDetails != null) {
      if (notification.metrics.pixels < notification.metrics.minScrollExtent) {
        _bouncing = true;
        _pull(-(notification.scrollDelta ?? 0));
      } else if (_drag > 0 && (notification.scrollDelta ?? 0) > 0) {
        _pull(-(notification.scrollDelta ?? 0));
      }
    }
    return false;
  }

  void _release({bool cancelled = false}) {
    _pointerDown = false;
    _drag = 0;
    if (_operation != null) return;
    if (!cancelled && _phase == SoftRefreshPhase.armed) {
      unawaited(show());
      return;
    }
    _setPhase(SoftRefreshPhase.idle);
    unawaited(_settle(0).catchError((Object _) {}));
  }

  /// Starts a refresh programmatically. A second call returns the same work.
  Future<void> show() {
    if (!mounted || !widget.enabled) return Future<void>.value();
    return _operation ??= _refresh();
  }

  Future<void> _refresh() async {
    _settlingForRefresh = true;
    try {
      await _settle(_threshold);
      if (!mounted || _pointerDown) return;
      _settlingForRefresh = false;
      _setPhase(SoftRefreshPhase.refreshing);
      if (!_reduce) _spin.repeat();
      await widget.onRefresh();
      if (!mounted) return;
      _spin.stop();
      _complete.value = 0;
      _setPhase(SoftRefreshPhase.complete);
      if (!_reduce) {
        unawaited(_complete.forward());
        await Future<void>.delayed(const Duration(milliseconds: 200));
      }
    } on TickerCanceled {
      // A caught rebound or disposal cancels the pending refresh.
    } catch (error, stack) {
      if (mounted) {
        if (widget.onError != null) {
          widget.onError!(error, stack);
        } else {
          FlutterError.reportError(
            FlutterErrorDetails(
              exception: error,
              stack: stack,
              library: 'fluid_glass',
              context: ErrorDescription('while refreshing a SoftPullToRefresh'),
            ),
          );
        }
      }
    } finally {
      _operation = null;
      if (mounted) {
        _spin.stop();
        if (_pointerDown && _settlingForRefresh) {
          _setPhase(
            _offset.value >= _threshold
                ? SoftRefreshPhase.armed
                : SoftRefreshPhase.pulling,
          );
        } else {
          _setPhase(SoftRefreshPhase.idle);
          unawaited(_settle(0).catchError((Object _) {}));
        }
      }
    }
  }

  @override
  void dispose() {
    _offset.dispose();
    _spin.dispose();
    _complete.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final SoftThemeData theme = SoftTheme.of(context);
    final String label = switch (_phase) {
      SoftRefreshPhase.armed => widget.releaseLabel,
      SoftRefreshPhase.refreshing => widget.refreshingLabel,
      SoftRefreshPhase.complete => widget.completeLabel,
      _ => widget.pullLabel,
    };
    final Color color = widget.color ?? theme.colors.primary;
    return NotificationListener<ScrollNotification>(
      onNotification: _onScroll,
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (PointerDownEvent event) {
          _pointers.add(event.pointer);
          _pointerDown = true;
          if ((_operation == null || _settlingForRefresh) &&
              _pointers.length == 1) {
            // Catch a rebound at its current position without a visual jump.
            final double normalized = (_offset.value / _dragRange).clamp(
              0,
              1 / 3,
            );
            _drag = _dragRange * (1 - math.pow(1 - 3 * normalized, 1 / 3));
            _offset.stop();
            _bouncing = false;
          }
        },
        onPointerUp: (PointerUpEvent event) {
          _pointers.remove(event.pointer);
          if (_pointers.isEmpty) _release();
        },
        onPointerCancel: (PointerCancelEvent event) {
          _pointers.remove(event.pointer);
          if (_pointers.isEmpty) _release(cancelled: true);
        },
        child: ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(overscroll: false),
          child: AnimatedBuilder(
            animation: Listenable.merge(<Listenable>[_offset, _complete]),
            child: widget.child,
            builder: (BuildContext context, Widget? child) {
              final double progress = (_offset.value / _threshold).clamp(0, 1);
              final double finish = const Cubic(
                0,
                0,
                0,
                0.37,
              ).transform(_complete.value);
              final double stretch = _phase == SoftRefreshPhase.armed
                  ? math.max(0, _offset.value - _threshold)
                  : 0;
              final double factor = switch (_phase) {
                SoftRefreshPhase.pulling || SoftRefreshPhase.idle => progress,
                SoftRefreshPhase.armed || SoftRefreshPhase.refreshing => 1,
                SoftRefreshPhase.complete => 1 - finish,
              };
              final double height = 55 * factor + stretch;
              final double alpha = switch (_phase) {
                SoftRefreshPhase.pulling =>
                  progress > 0.6 ? (progress - 0.5) * 2 : 0,
                SoftRefreshPhase.armed || SoftRefreshPhase.refreshing => 1,
                SoftRefreshPhase.complete => (1 - finish * 1.95).clamp(0, 1),
                SoftRefreshPhase.idle => 0,
              };
              return Stack(
                clipBehavior: Clip.hardEdge,
                children: <Widget>[
                  Positioned(
                    top: widget.edgeOffset,
                    left: 0,
                    right: 0,
                    height: height,
                    child: ClipRect(
                      child: OverflowBox(
                        minHeight: math.max(55, height),
                        maxHeight: math.max(55, height),
                        alignment: Alignment.topCenter,
                        child: Semantics(
                          excludeSemantics: true,
                          liveRegion: _phase == SoftRefreshPhase.complete,
                          label: alpha > 0 ? label : '',
                          child: Column(
                            children: <Widget>[
                              SizedBox(
                                height: 19 * factor + stretch,
                                child: OverflowBox(
                                  minHeight: 19 + stretch,
                                  maxHeight: 19 + stretch,
                                  alignment: Alignment.topCenter,
                                  child: RepaintBoundary(
                                    child: CustomPaint(
                                      size: Size(19, 19 + stretch),
                                      painter: _RefreshPainter(
                                        _spin,
                                        color,
                                        _phase,
                                        progress,
                                        stretch,
                                        finish,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Opacity(
                                opacity: alpha,
                                child: Text(
                                  label,
                                  style: theme.textStyles.body2.copyWith(
                                    color: color,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Transform.translate(
                    offset: Offset(0, _bouncing ? 0 : height),
                    child: child,
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

// The reference: ring -> stretched capsule -> orbiting inner dot -> fading ring.
class _RefreshPainter extends CustomPainter {
  _RefreshPainter(
    this.spin,
    this.color,
    this.phase,
    this.progress,
    this.stretch,
    this.finish,
  ) : super(repaint: spin);
  final Animation<double> spin;
  final Color color;
  final SoftRefreshPhase phase;
  final double progress, stretch, finish;
  @override
  void paint(Canvas canvas, Size size) {
    if (phase == SoftRefreshPhase.idle) return;
    const double radius = 19 / 2, stroke = 19 / 11;
    const Offset center = Offset(19 / 2, 19 / 1.8);
    final Paint paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    switch (phase) {
      case SoftRefreshPhase.pulling:
        paint.color = color.withValues(
          alpha: color.a * math.max(0, progress - 0.2),
        );
        canvas.drawCircle(center, radius, paint);
      case SoftRefreshPhase.armed:
        final Offset bottom = center + Offset(0, stretch);
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius),
          math.pi,
          math.pi,
          false,
          paint,
        );
        canvas.drawArc(
          Rect.fromCircle(center: bottom, radius: radius),
          0,
          math.pi,
          false,
          paint,
        );
        for (final double x in <double>[-radius, radius]) {
          canvas.drawLine(center + Offset(x, 0), bottom + Offset(x, 0), paint);
        }
      case SoftRefreshPhase.refreshing:
        canvas.drawCircle(center, radius, paint);
        final double angle = spin.value * 2 * math.pi;
        final double orbit = radius - 2 * stroke;
        canvas.drawCircle(
          center + Offset(math.cos(angle), math.sin(angle)) * orbit,
          stroke,
          paint..style = PaintingStyle.fill,
        );
      case SoftRefreshPhase.complete:
        final double r = radius * math.max(0.9, 1 - finish);
        paint.color = color.withValues(
          alpha: color.a * math.max(0, 0.65 - finish),
        );
        canvas.drawCircle(
          Offset(center.dx, center.dy - radius - stroke + r),
          r,
          paint,
        );
      case SoftRefreshPhase.idle:
        break;
    }
  }

  @override
  bool shouldRepaint(_RefreshPainter old) =>
      old.color != color ||
      old.phase != phase ||
      old.progress != progress ||
      old.stretch != stretch ||
      old.finish != finish;
}

/// SpringUtils.kt's semi-implicit Euler step, retaining its 1..16ms clamp,
/// period 0.4, critical damping and one-device-pixel settle threshold.
class _ReferenceRefreshSpring extends Simulation {
  _ReferenceRefreshSpring(this.position, this.target, this.threshold)
    : initial = position;
  double position, velocity = 0, _time = 0;
  final double target, threshold, initial;
  bool _done = false;
  void _advance(double time) {
    if (_done || time <= _time) return;
    final double dt = (time - _time).clamp(0.001, 0.016);
    _time = time;
    final double frequency = 2 * math.pi / 0.4;
    velocity =
        velocity * (1 - 2 * frequency * dt) +
        frequency * frequency * (target - position) * dt;
    position += dt * velocity;
    if ((initial < target && position > target) ||
        (initial > target && position < target) ||
        (position - target).abs() < threshold) {
      position = target;
      velocity = 0;
      _done = true;
    }
  }

  @override
  double x(double time) {
    _advance(time);
    return position;
  }

  @override
  double dx(double time) {
    _advance(time);
    return velocity;
  }

  @override
  bool isDone(double time) {
    _advance(time);
    return _done;
  }
}
