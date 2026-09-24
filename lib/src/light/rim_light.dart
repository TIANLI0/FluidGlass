import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../internal/rim_path.dart';
import '../shapes/rounded_rectangular_shape.dart';
import '../theme/liquid_glass_colors.dart';
import '../theme/liquid_glass_theme.dart';

/// What the light along an element's rim is saying.
enum RimLightState {
  /// Nothing. Whatever was lit fades out where it stands.
  idle,

  /// Light ran out of the finger round the outline and rests there.
  focused,

  /// A comet orbits the outline for as long as the work takes.
  loading,

  /// The outline fills clockwise from the top: it *is* the progress bar.
  progress,

  /// Light sweeps both ways round the outline and flares where the two fronts
  /// meet, then lets go.
  success,

  /// The same sweep in the colour of light itself rather than of success: an
  /// acknowledgement — "sent", "saved" — that claims nothing about how it
  /// turned out.
  sweep,

  /// Two warm pulses and a small shake — a "no", not an alarm.
  failure,
}

/// Drives the light along one element's rim.
///
/// The light is the element's state — loading, done, failed, focused, how far
/// along — so a control can say it without a spinner beside it, a toast over
/// it or a red label under it. Hand the controller to a [RimLight] around the
/// element.
///
/// **It costs frames only while something moves.** A comet orbiting, a sweep
/// travelling, a pulse decaying: the ticker runs. A settled state — focused,
/// or idle — stops it, and an element that is merely lit is painted once and
/// left alone.
class RimLightController extends ChangeNotifier {
  RimLightController({required TickerProvider vsync}) {
    _ticker = vsync.createTicker(_tick);
  }

  late final Ticker _ticker;

  RimLightState get state => _state;
  RimLightState _state = RimLightState.idle;

  /// The state being faded out while [state] is [RimLightState.idle].
  RimLightState get leaving => _leaving;
  RimLightState _leaving = RimLightState.idle;

  /// Seconds since the current state began.
  double get time => _time;
  double _time = 0;

  /// Where the current state's light starts, in the element's own
  /// coordinates, or null for the top centre.
  Offset? get origin => _origin;
  Offset? _origin;

  /// For a [RimLightState.success] entered straight out of
  /// [RimLightState.loading]: how far round the comet's head had got, as a
  /// fraction of a lap from the top centre — so the sweep leaves from where
  /// the light already is instead of jumping back to the top.
  double? get handoff => _handoff;
  double? _handoff;

  /// 0..1, for [RimLightState.progress].
  double get progress => _progress;
  double _progress = 0;

  /// 0..1: the fade a focused or loading light comes on and goes off with.
  double get presence => _presence;
  double _presence = 0;
  double _presenceFrom = 0;
  double _presenceTo = 0;
  double _presenceAt = 0;

  /// Set by [RimLight] from [MediaQueryData.disableAnimations].
  ///
  /// With motion reduced nothing travels: a loading rim glows steadily instead
  /// of orbiting (and stops its ticker once it has faded in), a success or
  /// failure is a glow that fades rather than a sweep or a pulse, and nothing
  /// shakes. Progress still fills — that is information, not decoration.
  bool reduceMotion = false;

  /// How long the orbiting comet takes per lap, in seconds.
  static const double lap = 1.35;

  /// How long a focus light takes to run from the finger round the outline.
  static const double gather = 0.42;

  /// The sweep of a success, and the whole of it including the flare.
  static const double successSweep = 0.52;
  static const double successDuration = 1.3;

  /// The whole of a failure.
  static const double failureDuration = 0.95;

  static const double _fade = 0.28;

  /// The comet's head, as a fraction of a lap, while loading.
  double get loadingPhase => _time / lap;

  /// The horizontal offset a failure shakes the element by, in logical pixels.
  double get shake {
    if (_state != RimLightState.failure || reduceMotion) return 0;
    const double settle = 0.55;
    if (_time >= settle) return 0;
    final double decay = 1 - _time / settle;
    return 7 * math.sin(2 * math.pi * 4.5 * _time) * decay * decay;
  }

  /// Light runs round the outline from [from] — where the finger landed, in
  /// the element's coordinates — and stays.
  void focus({Offset? from}) => _enter(RimLightState.focused, origin: from);

  /// A comet orbits until the next state is set.
  void load() => _enter(RimLightState.loading);

  /// Fills the outline to [value], 0..1.
  void setProgress(double value) {
    if (_state != RimLightState.progress) _enter(RimLightState.progress);
    final double v = value.clamp(0.0, 1.0);
    if (v == _progress) return;
    _progress = v;
    notifyListeners();
  }

  /// A success. Out of [RimLightState.loading] the sweep leaves from the
  /// comet's head; otherwise from [from], or the top centre.
  void succeed({Offset? from}) => _enter(
    RimLightState.success,
    origin: from,
    handoff: _state == RimLightState.loading ? loadingPhase % 1.0 : null,
  );

  /// An acknowledgement: the success sweep, in [LiquidGlassColors.glow].
  /// Out of [RimLightState.loading] it leaves from the comet's head, as
  /// [succeed] does; otherwise from [from], or the top centre.
  void sweep({Offset? from}) => _enter(
    RimLightState.sweep,
    origin: from,
    handoff: _state == RimLightState.loading && from == null
        ? loadingPhase % 1.0
        : null,
  );

  /// A failure.
  void fail() => _enter(RimLightState.failure);

  /// Puts the light out, fading from wherever it is.
  void clear() {
    if (_state == RimLightState.idle) return;
    _leaving = _state;
    _state = RimLightState.idle;
    _fadeTo(0);
    _start();
    notifyListeners();
  }

  void _enter(RimLightState state, {Offset? origin, double? handoff}) {
    _leaving = _state;
    _state = state;
    _origin = origin;
    _handoff = handoff;
    _time = 0;
    _base = null;
    if (state == RimLightState.focused ||
        state == RimLightState.loading ||
        state == RimLightState.progress) {
      if (state != RimLightState.progress) _progress = 0;
      _fadeTo(1);
    } else {
      _presence = 1;
      _presenceFrom = 1;
      _presenceTo = 1;
    }
    _start();
    notifyListeners();
  }

  void _fadeTo(double to) {
    _presenceFrom = _presence;
    _presenceTo = to;
    _presenceAt = _time;
  }

  /// The ticker's elapsed time at which [time] was zero.
  Duration? _base;

  void _start() {
    if (!_ticker.isActive) _ticker.start();
  }

  void _tick(Duration elapsed) {
    _base ??= elapsed - Duration(microseconds: (_time * 1e6).round());
    _time = (elapsed - _base!).inMicroseconds / 1e6;

    final double f = ((_time - _presenceAt) / _fade).clamp(0.0, 1.0);
    _presence = ui.lerpDouble(_presenceFrom, _presenceTo, _easeOutCubic(f))!;

    final bool done;
    switch (_state) {
      case RimLightState.idle:
        done = f >= 1;
        if (done) _leaving = RimLightState.idle;
      case RimLightState.focused:
        done = (_time >= gather || reduceMotion) && f >= 1;
      case RimLightState.loading:
        done = reduceMotion && f >= 1;
      case RimLightState.progress:
        done = f >= 1;
      case RimLightState.success:
      case RimLightState.sweep:
        done = _time >= successDuration;
      case RimLightState.failure:
        done = _time >= failureDuration;
    }
    if (done &&
        (_state == RimLightState.success ||
            _state == RimLightState.sweep ||
            _state == RimLightState.failure)) {
      _state = RimLightState.idle;
      _leaving = RimLightState.idle;
      _presence = 0;
    }
    notifyListeners();
    if (done) {
      _ticker.stop();
      _base = null;
    }
  }

  /// Whether the ticker is running — false whenever the light is settled.
  @visibleForTesting
  bool get isTicking => _ticker.isActive;

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }
}

/// Draws [controller]'s light along [shape]'s outline over [child], and
/// applies the shake a failure asks for.
///
/// The light is its own repaint boundary. It changes every frame while it
/// moves; the glass under it does not change at all, and on the sampled tier
/// a repaint of the glass is a fresh read of the backdrop. So the light
/// repaints and the glass stays exactly where the compositor left it.
///
/// Nothing here needs a fragment shader: it is strokes along extracted path
/// segments with a mask blur for the bloom, so it draws the same on every
/// tier and every backend. Colours come from [LiquidGlassTheme]:
/// [LiquidGlassColors.glow] for loading and progress, `accent` for focus,
/// `success` and `destructive` for the outcomes.
class RimLight extends StatelessWidget {
  const RimLight({
    super.key,
    required this.controller,
    required this.shape,
    this.colors,
    this.shake = true,
    this.blendMode = BlendMode.plus,
    required this.child,
  });

  final RimLightController controller;

  /// The outline the light runs along — the shape of the glass it lights.
  final RoundedRectangularShape shape;

  /// Overrides the theme's palette.
  final LiquidGlassColors? colors;

  /// Whether a failure shakes [child].
  ///
  /// Turn it off around glass that samples a live source: moving the element
  /// moves what it refracts every frame of the shake, for half a second of
  /// fresh reads, and the pulse already says "no" on its own.
  final bool shake;

  /// How the light is composited over [child].
  ///
  /// [BlendMode.plus] — the default — is light: it brightens what it lands
  /// on, and reads as a glow on glass and on anything dark. On a light, solid
  /// surface it reads as nothing at all, because white plus anything is still
  /// white. There, pass [BlendMode.srcOver] with a saturated colour, and the
  /// rim reads as coloured light instead of added light.
  final BlendMode blendMode;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    controller.reduceMotion =
        MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final LiquidGlassColors palette = colors ?? LiquidGlassTheme.of(context);
    final Widget lit = Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        child,
        Positioned.fill(
          child: IgnorePointer(
            child: RepaintBoundary(
              child: CustomPaint(
                painter: _RimLightPainter(
                  controller,
                  shape,
                  palette,
                  blendMode,
                ),
              ),
            ),
          ),
        ),
      ],
    );
    if (!shake) return lit;
    return AnimatedBuilder(
      animation: controller,
      child: lit,
      builder: (BuildContext context, Widget? child) {
        final double dx = controller.shake;
        if (dx == 0) return child!;
        return Transform.translate(offset: Offset(dx, 0), child: child);
      },
    );
  }
}

class _RimLightPainter extends CustomPainter {
  _RimLightPainter(this.controller, this.shape, this.colors, this.blendMode)
    : super(repaint: controller);

  final RimLightController controller;
  final RoundedRectangularShape shape;
  final LiquidGlassColors colors;
  final BlendMode blendMode;

  final RimPathCache _cache = RimPathCache();

  // Where a sweep leaves from is asked once per state, not once per frame.
  Offset? _originFor;
  RimPath? _originRim;
  double _originArc = 0;

  double _startOf(RimPath rim, Offset? origin) {
    if (origin == null) return rim.topCentre;
    if (origin != _originFor || !identical(rim, _originRim)) {
      _originFor = origin;
      _originRim = rim;
      _originArc = rim.nearest(origin);
    }
    return _originArc;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final RimPath rim = _cache.of(shape, size);
    final RimLightController c = controller;
    final double t = c.time;
    final bool still = c.reduceMotion;

    switch (c.state) {
      case RimLightState.idle:
        if (c.presence <= 0) return;
        switch (c.leaving) {
          case RimLightState.focused:
            _glow(canvas, rim, colors.accent, 0.75 * c.presence);
          case RimLightState.loading:
            _glow(canvas, rim, colors.glow, 0.3 * c.presence);
          case RimLightState.progress:
            _span(
              canvas,
              rim,
              rim.topCentre,
              rim.length * c.progress,
              colors.glow,
              c.presence,
            );
          case RimLightState.idle:
          case RimLightState.success:
          case RimLightState.sweep:
          case RimLightState.failure:
            break;
        }
      case RimLightState.focused:
        final double from = _startOf(rim, c.origin);
        if (still) {
          _glow(canvas, rim, colors.accent, 0.75 * c.presence);
        } else {
          _gather(
            canvas,
            rim,
            from,
            t / RimLightController.gather,
            colors.accent,
            c.presence,
            rest: 0.75,
          );
        }
      case RimLightState.loading:
        final double p = c.presence;
        if (still) {
          _glow(canvas, rim, colors.glow, 0.55 * p);
          return;
        }
        // A faint resting rim, so the path the comet runs along reads.
        _glow(canvas, rim, colors.glow, 0.18 * p);
        _comet(
          canvas,
          rim,
          rim.advance(rim.topCentre, rim.length * (c.loadingPhase % 1.0)),
          rim.length * 0.32,
          colors.glow,
          strength: p,
        );
      case RimLightState.progress:
        final double lit = rim.length * c.progress;
        _glow(canvas, rim, colors.glow, 0.12 * c.presence);
        _span(canvas, rim, rim.topCentre, lit, colors.glow, 0.85 * c.presence);
        if (!still && c.progress > 0 && c.progress < 1) {
          _comet(
            canvas,
            rim,
            rim.advance(rim.topCentre, lit),
            math.min(lit, rim.length * 0.12),
            colors.glow,
            strength: c.presence,
          );
        }
      case RimLightState.success:
      case RimLightState.sweep:
        final double? handoff = c.handoff;
        final double from = handoff != null
            ? rim.advance(rim.topCentre, rim.length * handoff)
            : _startOf(rim, c.origin);
        _success(
          canvas,
          rim,
          from,
          t,
          still,
          c.state == RimLightState.sweep ? colors.glow : colors.success,
        );
      case RimLightState.failure:
        _failure(canvas, rim, t, still);
    }
  }

  void _gather(
    Canvas canvas,
    RimPath rim,
    double from,
    double k0,
    Color color,
    double strength, {
    required double rest,
  }) {
    final double k = _easeOutCubic(k0);
    if (k >= 1) {
      _glow(canvas, rim, color, rest * strength);
      return;
    }
    final double half = rim.length / 2 * k;
    _span(
      canvas,
      rim,
      rim.advance(from, -half),
      half * 2,
      color,
      rest * strength,
    );
    _comet(
      canvas,
      rim,
      rim.advance(from, half),
      half * 0.6,
      color,
      strength: strength,
    );
    _comet(
      canvas,
      rim,
      rim.advance(from, -half),
      half * 0.6,
      color,
      clockwise: false,
      strength: strength,
    );
  }

  void _success(
    Canvas canvas,
    RimPath rim,
    double from,
    double t,
    bool still,
    Color color,
  ) {
    const double sweep = RimLightController.successSweep;
    if (still) {
      final double u = t / RimLightController.successDuration;
      final double s = 1 - _easeInOutSine(u);
      _glow(canvas, rim, color, s);
      _wash(canvas, rim, color, 0.12 * s);
      return;
    }
    if (t < sweep) {
      final double k = _easeOutCubic(t / sweep);
      final double half = rim.length / 2 * k;
      _span(canvas, rim, rim.advance(from, -half), half * 2, color, 0.8);
      _comet(canvas, rim, rim.advance(from, half), half * 0.5, color);
      _comet(
        canvas,
        rim,
        rim.advance(from, -half),
        half * 0.5,
        color,
        clockwise: false,
      );
      _wash(canvas, rim, color, 0.10 * k);
      return;
    }
    // The fronts have met: the whole rim flares once and lets go.
    final double u = (t - sweep) / (RimLightController.successDuration - sweep);
    final double flare = u < 0.18
        ? 0.8 + 0.2 * (u / 0.18)
        : 1.0 - _easeInOutSine((u - 0.18) / 0.82);
    _glow(canvas, rim, color, flare);
    _wash(canvas, rim, color, 0.14 * flare);
  }

  void _failure(Canvas canvas, RimPath rim, double t, bool still) {
    final Color color = colors.destructive;
    final double env = (1 - t / RimLightController.failureDuration).clamp(
      0.0,
      1.0,
    );
    final double s = still
        ? env
        : math
                  .pow(
                    math.sin(math.pi * (t / 0.42).clamp(0.0, 2.0)).abs(),
                    0.7,
                  )
                  .toDouble() *
              env;
    _glow(canvas, rim, color, s);
    _wash(canvas, rim, color, 0.12 * s);
  }

  // --- strokes ---------------------------------------------------------------

  Paint _core(Color color, double width) => Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..strokeCap = StrokeCap.round
    ..color = color
    ..blendMode = blendMode;

  Paint _bloom(Color color, double width, double sigma) => Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..strokeCap = StrokeCap.round
    ..color = color
    ..maskFilter = MaskFilter.blur(BlurStyle.normal, sigma)
    ..blendMode = blendMode;

  static Color _a(Color color, double k) =>
      color.withValues(alpha: (color.a * k).clamp(0.0, 1.0));

  /// The whole outline lit evenly: a soft bloom and a crisp core.
  void _glow(Canvas canvas, RimPath rim, Color color, double s) {
    if (s <= 0) return;
    canvas.drawPath(rim.path, _bloom(_a(color, 0.55 * s), 6, 4));
    canvas.drawPath(rim.path, _core(_a(color, s), 1.4));
  }

  /// A lit stretch of the outline, evenly bright.
  void _span(
    Canvas canvas,
    RimPath rim,
    double from,
    double distance,
    Color color,
    double s,
  ) {
    if (distance <= 0 || s <= 0) return;
    final Path span = rim.segment(from, distance);
    canvas.drawPath(span, _bloom(_a(color, 0.5 * s), 6, 4));
    canvas.drawPath(span, _core(_a(color, s), 1.6));
  }

  /// A comet: a bright head at [head] with a [tail] fading out behind it.
  ///
  /// **One stroke with the fade in its shader, not a stack of pieces.** The
  /// first version drew the tail as ten short strokes, each a step brighter
  /// and wider than the last, under two blurred blooms of different lengths.
  /// Standing still that reads as a gradient. Moving, every seam moves with
  /// it: round caps overlap and add up into beads, the bloom changes width in
  /// two hard steps, and the whole thing reads as a smeared mosaic running
  /// round the edge. Now the tail is a single path from its far end to the
  /// head, and how bright each point of it is comes from a sweep gradient
  /// around the shape's centre — continuous by construction, so there is no
  /// seam anywhere to crawl.
  ///
  /// A sweep gradient maps *angle* to colour, and on a convex outline the
  /// angle seen from the centre only ever increases along the rim, so the
  /// fade is monotonic along the tail whatever the shape. It is not uniform
  /// in arc length — a corner turns through more angle than a straight run of
  /// the same length — which the eye does not pick up in a fade.
  void _comet(
    Canvas canvas,
    RimPath rim,
    double head,
    double tail,
    Color color, {
    bool clockwise = true,
    double strength = 1,
  }) {
    if (strength <= 0 || tail <= 0) return;
    // The stretch the comet covers, in rim order (the order the angle grows).
    final double from = clockwise ? rim.advance(head, -tail) : head;
    final Path body = rim.segment(from, tail);
    final Offset centre = rim.size.center(Offset.zero);
    final double start = _angle(rim.pointAt(from), centre);
    double span = _angle(rim.pointAt(rim.advance(from, tail)), centre) - start;
    span %= 2 * math.pi;
    if (span <= 0) span += 2 * math.pi;

    canvas.drawPath(
      body,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.5)
        ..shader = _fade(
          centre,
          start,
          span,
          color,
          0.45 * strength,
          headAtEnd: clockwise,
        )
        ..blendMode = blendMode,
    );
    canvas.drawPath(
      body,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..shader = _fade(
          centre,
          start,
          span,
          color,
          strength,
          headAtEnd: clockwise,
        )
        ..blendMode = blendMode,
    );
    // The spark at the head: the one place the light is concentrated, which
    // is what makes it read as travelling rather than as a gradient shifting.
    final Offset at = rim.pointAt(head);
    canvas.drawCircle(
      at,
      5,
      Paint()
        ..color = _a(color, 0.55 * strength)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5)
        ..blendMode = blendMode,
    );
    // The white core only reads where light is added; laid over a light
    // surface it would be a white dot on white, so it takes the colour.
    canvas.drawCircle(
      at,
      1.6,
      Paint()
        ..color = blendMode == BlendMode.plus
            ? const Color(0xFFFFFFFF).withValues(alpha: 0.9 * strength)
            : _a(color, strength)
        ..blendMode = blendMode,
    );
  }

  static double _angle(Offset point, Offset centre) =>
      math.atan2(point.dy - centre.dy, point.dx - centre.dx);

  /// The tail's brightness as a sweep gradient: nothing at the far end,
  /// rising with the square of the distance travelled to full at the head —
  /// the same curve the stepped version approximated — then gone again a
  /// little past the head.
  ///
  /// The gradient covers the whole turn and is rotated to where the comet is,
  /// so the stops never straddle the angle where a sweep wraps. The stretch
  /// just past the head fades out rather than stopping dead: the bloom and
  /// the round cap reach a few pixels beyond the path, and a hard stop there
  /// would be a seam again. Everywhere outside the comet is transparent, which
  /// is what keeps the blurred spill behind the tail from catching the head's
  /// colour through the wrap.
  static Shader _fade(
    Offset centre,
    double start,
    double span,
    Color color,
    double strength, {
    required bool headAtEnd,
  }) {
    const double turn = 2 * math.pi;
    // How far past the head (in angle) the light takes to go out.
    const double lead = 0.3;
    const List<double> along = <double>[0, 0.25, 0.5, 0.75, 1];
    final Color clear = color.withValues(alpha: 0);
    Color at(double f) => _a(color, f * f * strength);
    final double usable = math.min(span, turn - lead * 2);
    final List<Color> colors;
    final List<double> stops;
    final double rotation;
    if (headAtEnd) {
      // 0 = the far end of the tail, `usable` = the head.
      rotation = start;
      colors = <Color>[for (final double f in along) at(f), clear, clear];
      stops = <double>[
        for (final double f in along) f * usable / turn,
        (usable + lead) / turn,
        1,
      ];
    } else {
      // The head is where the stretch starts; the light leads in from just
      // before it and the tail trails off in the direction the angle grows.
      rotation = start - lead;
      colors = <Color>[
        clear,
        for (final double f in along.reversed) at(f),
        clear,
      ];
      stops = <double>[
        0,
        for (final double f in along.reversed) (lead + (1 - f) * usable) / turn,
        1,
      ];
    }
    final double c = math.cos(rotation);
    final double s = math.sin(rotation);
    // Rotation about the centre, column-major.
    final Float64List matrix = Float64List.fromList(<double>[
      c, s, 0, 0, //
      -s, c, 0, 0, //
      0, 0, 1, 0, //
      centre.dx - c * centre.dx + s * centre.dy,
      centre.dy - s * centre.dx - c * centre.dy,
      0,
      1,
    ]);
    return ui.Gradient.sweep(
      centre,
      colors,
      stops,
      TileMode.clamp,
      0,
      turn,
      matrix,
    );
  }

  /// A faint wash over the face, clipped to it — the rim's light landing on
  /// the glass.
  void _wash(Canvas canvas, RimPath rim, Color color, double s) {
    if (s <= 0) return;
    final Offset c = rim.size.center(Offset.zero);
    final double r = rim.size.longestSide * 0.75;
    canvas.save();
    canvas.clipPath(rim.path);
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = ui.Gradient.radial(c, r, <Color>[
          _a(color, s),
          color.withValues(alpha: 0),
        ])
        ..blendMode = blendMode,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _RimLightPainter oldDelegate) =>
      oldDelegate.controller != controller ||
      oldDelegate.shape != shape ||
      oldDelegate.colors != colors ||
      oldDelegate.blendMode != blendMode;
}

double _easeOutCubic(double t) {
  final double u = 1 - t.clamp(0.0, 1.0);
  return 1 - u * u * u;
}

double _easeInOutSine(double t) =>
    -(math.cos(math.pi * t.clamp(0.0, 1.0)) - 1) / 2;
