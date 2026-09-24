import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:fluid_glass/fluid_glass.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../utils/lorem_ipsum.dart';

/// Velocity blur: the glass smears what it shows along the direction it is
/// moving — or the direction the page under it is moving — and clears as it
/// comes to rest.
///
/// It is the engine's own Gaussian with a different sigma per axis, so it is
/// the same filter the glass already runs, not an extra pass; and it only
/// changes while something is in motion, which is when frames are being drawn
/// anyway. The switch at the bottom turns it off for comparison.
class LabVelocityBlurContent extends StatefulWidget {
  const LabVelocityBlurContent({super.key});

  @override
  State<LabVelocityBlurContent> createState() => _LabVelocityBlurContentState();
}

class _LabVelocityBlurContentState extends State<LabVelocityBlurContent>
    with TickerProviderStateMixin {
  final LayerBackdrop _backdrop = LayerBackdrop();

  late final _VelocityBlur _headerBlur = _VelocityBlur(this);
  late final _VelocityBlur _puckBlur = _VelocityBlur(this);

  bool _enabled = true;

  // Scroll velocity, measured from the notifications themselves. A clock of
  // its own rather than the frame timestamp: a drag's updates arrive from
  // pointer events, outside any frame, where there is no frame timestamp.
  final Stopwatch _clock = Stopwatch()..start();
  Duration? _lastScrollAt;
  double _pendingDelta = 0;
  double _scrollVelocity = 0;
  Timer? _scrollIdle;

  // The puck.
  static const Size _puckSize = Size(124, 124);
  final ValueNotifier<Offset> _puck = ValueNotifier<Offset>(Offset.zero);
  bool _puckPlaced = false;
  Offset _puckVelocity = Offset.zero;
  final VelocityTracker _tracker = VelocityTracker.withKind(
    PointerDeviceKind.touch,
  );
  late final Ticker _fling = createTicker(_flingTick);
  Duration _flingLast = Duration.zero;
  Rect _bounds = Rect.zero;

  @override
  void dispose() {
    _scrollIdle?.cancel();
    _fling.dispose();
    _headerBlur.dispose();
    _puckBlur.dispose();
    _puck.dispose();
    _backdrop.dispose();
    super.dispose();
  }

  bool _onScroll(ScrollNotification n) {
    if (n is ScrollUpdateNotification && n.scrollDelta != null) {
      final Duration now = _clock.elapsed;
      final Duration? last = _lastScrollAt;
      _pendingDelta += n.scrollDelta!;
      if (last == null) {
        _lastScrollAt = now;
        _pendingDelta = 0;
      } else if (now - last >= const Duration(milliseconds: 8)) {
        // Several pointer moves can land between two frames; measured one at
        // a time they give absurd speeds over a fraction of a millisecond.
        final double dt = (now - last).inMicroseconds / 1e6;
        final double v = _pendingDelta / dt;
        _lastScrollAt = now;
        _pendingDelta = 0;
        // Smoothed: a single frame's delta is noisy, and blur that flickers
        // with it reads as a rendering fault rather than as speed.
        _scrollVelocity = _scrollVelocity * 0.6 + v * 0.4;
        _headerBlur.follow(Offset(0, _scrollVelocity));
      }
      _scrollIdle?.cancel();
      _scrollIdle = Timer(const Duration(milliseconds: 70), _scrollStopped);
    } else if (n is ScrollEndNotification) {
      _scrollStopped();
    }
    return false;
  }

  void _scrollStopped() {
    _scrollVelocity = 0;
    _lastScrollAt = null;
    _pendingDelta = 0;
    _headerBlur.follow(Offset.zero);
  }

  void _panStart(DragStartDetails d) {
    _fling.stop();
    if (d.sourceTimeStamp != null) {
      _tracker.addPosition(d.sourceTimeStamp!, d.globalPosition);
    }
  }

  void _panUpdate(DragUpdateDetails d) {
    _puck.value = _clampToBounds(_puck.value + d.delta);
    if (d.sourceTimeStamp != null) {
      _tracker.addPosition(d.sourceTimeStamp!, d.globalPosition);
      _puckBlur.follow(_tracker.getVelocity().pixelsPerSecond);
    }
  }

  void _panEnd(DragEndDetails d) {
    _puckVelocity = d.velocity.pixelsPerSecond;
    _flingLast = Duration.zero;
    if (_puckVelocity.distance < 30) {
      _puckBlur.follow(Offset.zero);
      return;
    }
    _fling.start();
  }

  void _flingTick(Duration elapsed) {
    final double dt = ((elapsed - _flingLast).inMicroseconds / 1e6).clamp(
      0.0,
      1 / 30,
    );
    _flingLast = elapsed;
    if (dt == 0) return;
    // Exponential friction, and walls that give back most of what hits them.
    _puckVelocity *= math.exp(-2.4 * dt);
    Offset p = _puck.value + _puckVelocity * dt;
    double vx = _puckVelocity.dx;
    double vy = _puckVelocity.dy;
    if (p.dx < _bounds.left || p.dx > _bounds.right) {
      vx = -vx * 0.72;
      p = Offset(p.dx.clamp(_bounds.left, _bounds.right), p.dy);
    }
    if (p.dy < _bounds.top || p.dy > _bounds.bottom) {
      vy = -vy * 0.72;
      p = Offset(p.dx, p.dy.clamp(_bounds.top, _bounds.bottom));
    }
    _puckVelocity = Offset(vx, vy);
    _puck.value = p;
    _puckBlur.follow(_puckVelocity);
    if (_puckVelocity.distance < 18) {
      _fling.stop();
      _puckBlur.follow(Offset.zero);
    }
  }

  Offset _clampToBounds(Offset p) => Offset(
    p.dx.clamp(_bounds.left, _bounds.right),
    p.dy.clamp(_bounds.top, _bounds.bottom),
  );

  @override
  Widget build(BuildContext context) {
    final EdgeInsets safe = MediaQuery.paddingOf(context);
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final Size screen = constraints.biggest;
        _bounds = Rect.fromLTRB(
          8,
          safe.top + 8,
          screen.width - 8 - _puckSize.width,
          screen.height - safe.bottom - 8 - _puckSize.height,
        );
        if (!_puckPlaced) {
          _puckPlaced = true;
          _puck.value = Offset(
            screen.width - 24 - _puckSize.width,
            screen.height * 0.42,
          );
        }

        const double headerTop = 64;
        return Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            Positioned.fill(
              child: BackdropLayer(
                backdrop: _backdrop,
                child: NotificationListener<ScrollNotification>(
                  onNotification: _onScroll,
                  child: _Feed(top: safe.top + headerTop + 84),
                ),
              ),
            ),
            Positioned(
              left: 12,
              right: 12,
              top: safe.top + headerTop,
              height: 72,
              child: _BlurGlass(
                backdrop: _backdrop,
                blur: _headerBlur,
                enabled: _enabled,
                baseRadius: 6,
                shape: const RoundedRectangle(28),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Fling the feed',
                        style: TextStyle(
                          color: Color(0xFF111111),
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'This bar blurs along the scroll while it moves.',
                        style: TextStyle(
                          color: Color(0xAA111111),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            ValueListenableBuilder<Offset>(
              valueListenable: _puck,
              builder: (BuildContext context, Offset at, Widget? child) =>
                  Positioned(
                    left: at.dx,
                    top: at.dy,
                    width: _puckSize.width,
                    height: _puckSize.height,
                    child: child!,
                  ),
              child: GestureDetector(
                onPanStart: _panStart,
                onPanUpdate: _panUpdate,
                onPanEnd: _panEnd,
                child: _BlurGlass(
                  backdrop: _backdrop,
                  blur: _puckBlur,
                  enabled: _enabled,
                  baseRadius: 2,
                  shape: const RoundedRectangle(40),
                  child: const Center(
                    child: Text(
                      'Drag\nor fling',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFF111111),
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 12,
              right: 12,
              bottom: safe.bottom + 12,
              height: 64,
              child: LiquidPanel(
                backdrop: _backdrop,
                shape: const Capsule(),
                surfaceColor: const Color(0xFFFFFFFF).withValues(alpha: 0.6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  child: Row(
                    children: <Widget>[
                      const Expanded(
                        child: Text(
                          'Velocity blur',
                          style: TextStyle(
                            color: Color(0xFF111111),
                            fontSize: 16,
                          ),
                        ),
                      ),
                      LiquidToggle(
                        backdrop: _backdrop,
                        selected: _enabled,
                        onSelect: (bool v) => setState(() => _enabled = v),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Extra blur per axis, following a velocity through a stiff, critically
/// damped spring — quick enough to feel attached to the motion, smooth enough
/// that a noisy velocity estimate does not make the glass flicker.
class _VelocityBlur extends ChangeNotifier {
  _VelocityBlur(TickerProvider vsync)
    : x = SpringValue(vsync: vsync, value: 0, visibilityThreshold: 0.05),
      y = SpringValue(vsync: vsync, value: 0, visibilityThreshold: 0.05) {
    x.addListener(notifyListeners);
    y.addListener(notifyListeners);
  }

  final SpringValue x;
  final SpringValue y;

  /// Logical pixels of extra radius per logical pixel per second of speed.
  static const double gain = 1 / 75;

  /// The most any axis is smeared, in logical pixels of blur radius.
  static const double limit = 26;

  static final SpringDescription _spring = springOf(1.0, 700);

  void follow(Offset velocity) {
    final double tx = (velocity.dx.abs() * gain).clamp(0.0, limit);
    final double ty = (velocity.dy.abs() * gain).clamp(0.0, limit);
    if (x.targetValue != tx) x.animateTo(tx, _spring);
    if (y.targetValue != ty) y.animateTo(ty, _spring);
  }

  @override
  void dispose() {
    x.dispose();
    y.dispose();
    super.dispose();
  }
}

class _BlurGlass extends StatelessWidget {
  const _BlurGlass({
    required this.backdrop,
    required this.blur,
    required this.enabled,
    required this.baseRadius,
    required this.shape,
    required this.child,
  });

  final Backdrop backdrop;
  final _VelocityBlur blur;
  final bool enabled;
  final double baseRadius;
  final RoundedRectangularShape shape;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DrawBackdrop(
      backdrop: backdrop,
      shape: () => shape,
      effects: (BackdropEffectScope scope) {
        scope.vibrancy();
        final double rx = baseRadius + (enabled ? blur.x.value : 0);
        final double ry = baseRadius + (enabled ? blur.y.value : 0);
        // What `blur()` does, with a radius per axis: room to read past the
        // edge, since a colour filter already sits ahead of it in the chain.
        final double reach = math.max(rx, ry);
        if (reach > scope.padding) scope.padding = reach;
        scope.addImageFilter(
          ui.ImageFilter.blur(
            sigmaX: blurRadiusToSigma(
              rx,
              devicePixelRatio: scope.devicePixelRatio,
            ),
            sigmaY: blurRadiusToSigma(
              ry,
              devicePixelRatio: scope.devicePixelRatio,
            ),
          ),
        );
        scope.lens(16, 28);
      },
      onDrawSurface: (Canvas canvas, Size size) => canvas.drawRect(
        Offset.zero & size,
        Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: 0.35),
      ),
      isolateSurface: false,
      repaint: blur,
      child: child,
    );
  }
}

/// Something with edges to smear: headlines, colour blocks and body text.
class _Feed extends StatelessWidget {
  const _Feed({required this.top});

  final double top;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFF4F1EA),
      child: ListView.builder(
        padding: EdgeInsets.fromLTRB(16, top, 16, 120),
        itemCount: 40,
        itemBuilder: (BuildContext context, int i) {
          final Color hue = HSVColor.fromAHSV(
            1,
            (i * 47.0) % 360,
            0.62,
            0.92,
          ).toColor();
          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xFFFFFFFF),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 14,
                  children: <Widget>[
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: hue,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Center(
                        child: Text(
                          '${i + 1}',
                          style: const TextStyle(
                            color: Color(0xFFFFFFFF),
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        spacing: 4,
                        children: <Widget>[
                          Text(
                            'Story number ${i + 1}',
                            style: const TextStyle(
                              color: Color(0xFF111111),
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            kLoremIpsum,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF444444),
                              fontSize: 13,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
