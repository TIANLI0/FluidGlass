import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import '../../fluid_glass.dart';
import '../internal/animated_translation.dart';
import '../internal/control_focus.dart';

/// Fills the played part of the track, matching the capsule the old
/// width-animated Container produced: a capsule of the current fill width,
/// rounded at both ends.
///
/// Repaints on [width], never on the animation itself. The fill sits inside
/// the track's [BackdropLayer], and every repaint in there throws the capture
/// away, so a painter listening to the whole animation — five springs, four of
/// which never move the fill — made the thumb re-capture the track on every
/// frame of a press it was held still for.
class _TrackFillPainter extends CustomPainter {
  _TrackFillPainter({
    required this.width,
    required this.color,
    required this.isLtr,
  }) : super(repaint: width);

  /// The fill's width, in whole logical pixels.
  final ValueNotifier<double> width;
  final Color color;
  final bool isLtr;

  @override
  void paint(Canvas canvas, Size size) {
    final double width = this.width.value.clamp(0.0, size.width);
    if (width <= 0) return;
    final Rect rect = isLtr
        ? Rect.fromLTWH(0, 0, width, size.height)
        : Rect.fromLTWH(size.width - width, 0, width, size.height);
    final GlassOutline outline = const Capsule().createOutline(
      rect.size,
      TextDirection.ltr,
    );
    canvas.save();
    canvas.translate(rect.left, rect.top);
    outline.draw(canvas, Paint()..color = color);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _TrackFillPainter oldDelegate) =>
      oldDelegate.width != width ||
      oldDelegate.color != color ||
      oldDelegate.isLtr != isLtr;
}

/// A slider whose thumb is a bead of liquid glass, refracting the track it
/// slides along.
class LiquidSlider extends StatefulWidget {
  const LiquidSlider({
    super.key,
    required this.value,
    required this.onValueChanged,
    this.valueRange = (start: 0, end: 1),
    this.visibilityThreshold = 0.001,
    required this.backdrop,
    this.divisions,
    this.onChangeEnd,
    this.onChangeStart,
    this.semanticLabel,
    this.semanticFormatterCallback,
    this.focusNode,
    this.autofocus = false,
    this.touchTargetHeight = 48,
  }) : assert(value > double.negativeInfinity && value < double.infinity),
       assert(visibilityThreshold > 0 && visibilityThreshold < double.infinity),
       assert(touchTargetHeight >= 24 && touchTargetHeight < double.infinity),
       assert(
         divisions == null || divisions > 0,
         'divisions must be positive, or null for a continuous track.',
       );

  final double value;

  /// Null disables the slider. A zero-length range is also non-interactive.
  final ValueChanged<double>? onValueChanged;
  final ({double start, double end}) valueRange;
  final double visibilityThreshold;
  final Backdrop backdrop;

  /// Snaps the reported value to this many equal steps across [valueRange].
  ///
  /// Null keeps the track continuous. Give a count when the value the caller
  /// stores is discrete and the range is short: a device volume of 0–16 on a
  /// finger-width track resolves to about three pixels a step, and a
  /// continuous slider then makes an exact setting a matter of luck. The
  /// *thumb* still slides continuously — only the reported value snaps, so the
  /// bead keeps tracking the finger rather than jumping between stops.
  final int? divisions;

  /// Called once when the interaction ends — the finger lifts after a drag, or
  /// a tap on the track lands.
  ///
  /// [onValueChanged] fires continuously while dragging, which is the wrong
  /// moment to write anything expensive: a caller that debounces its writes
  /// has no way to know the user has stopped, and so must either wait out the
  /// debounce window after the finger is already gone, or write on every
  /// frame of the drag.
  final ValueChanged<double>? onChangeEnd;

  /// Called once before a pointer, keyboard or accessibility adjustment starts.
  final ValueChanged<double>? onChangeStart;

  final String? semanticLabel;

  /// Describes a value in its own units, for example `(v) => '${v.round()} dB'`.
  /// Defaults to a percentage of [valueRange].
  final String Function(double value)? semanticFormatterCallback;
  final FocusNode? focusNode;
  final bool autofocus;

  /// Input height; the visible thumb stays 24 pixels high. Use 24 for a dense
  /// desktop layout, or leave the default 48-pixel touch target.
  final double touchTargetHeight;

  @override
  State<LiquidSlider> createState() => _LiquidSliderState();
}

class _LiquidSliderState extends State<LiquidSlider>
    with TickerProviderStateMixin {
  static const double _thumbWidth = 40;
  static const double _thumbHeight = 24;

  /// The track's length when the slider is given no width to fill — inside a
  /// `Row` without an `Expanded`, say.
  static const double _unboundedTrackWidth = 200;

  final LayerBackdrop _trackBackdrop = LayerBackdrop();

  late final DampedDragAnimation _animation;
  late Backdrop _thumbBackdrop;

  /// The fill's width in whole logical pixels, changed only when it changes.
  final ValueNotifier<double> _fillWidth = ValueNotifier<double>(0);

  bool _didDrag = false;
  double _trackWidth = 0;

  /// Where the finger has taken the thumb during a drag, before snapping.
  /// Null between drags.
  ///
  /// The drag has to accumulate in here rather than in the value the caller
  /// hands back. With [LiquidSlider.divisions] that value is snapped, and a
  /// finger moves a few pixels per event — far less than half a stop on a
  /// short range (0–16 on a phone-width track is ~20px a stop) — so each move
  /// computed from the caller's value rounds straight back to where it began
  /// and the thumb never leaves its stop.
  double? _dragValue;
  bool _interactionActive = false;
  double? _lastReportedValue;

  /// Whether the arena has given this drag to the slider (see
  /// [DragInspector.onClaim]). Until then the thumb follows the finger but
  /// nothing is reported: inside a list the gesture may still turn out to be
  /// a scroll, and the sideways wobble at the start of one would otherwise
  /// already have moved the caller's value — a volume, say — by a few percent.
  bool _claimed = false;

  bool get _enabled => widget.onValueChanged != null && _span != 0;

  @override
  void initState() {
    super.initState();
    _animation = DampedDragAnimation(
      vsync: this,
      initialValue: widget.value,
      valueRange: widget.valueRange,
      visibilityThreshold: widget.visibilityThreshold,
      initialScale: 1,
      pressedScale: 1.5,
      onDragStarted: (_) => _startInteraction(),
      onDragStopped: () {
        final double? raw = _dragValue;
        _dragValue = null;
        if (_enabled && _interactionActive) {
          // Lifted before the arena decided — a short drag in a list, under
          // the slop either way. Nothing else took it, so it was the slider's.
          if (!_claimed) _claim(report: false);
          final double settled = _snap(raw ?? _animation.targetValue);
          // Let go between two stops: the thumb settles onto the one reported.
          if (_reduceMotion) {
            _animation.snapToValue(settled);
          } else {
            _animation.updateValue(settled);
          }
          if (_didDrag) _reportValue(settled);
          widget.onChangeEnd?.call(settled);
        }
        _interactionActive = false;
        _claimed = false;
        _didDrag = false;
        _lastReportedValue = null;
      },
      onDrag: _onDrag,
    );
    _animation.addListener(_syncFillWidth);
    _thumbBackdrop = _combineThumbBackdrop();
  }

  Backdrop _combineThumbBackdrop() => CombinedBackdrop.of(
    widget.backdrop,
    WrappedBackdrop(_trackBackdrop, _drawScaledTrack),
  );

  void _syncFillWidth() {
    // Rounded, as the painter always drew it: a sub-pixel change repaints
    // nothing anyone can see, and costs a capture.
    _fillWidth.value = (_trackWidth * _animation.progress)
        .roundToDouble()
        .clamp(0.0, _trackWidth);
  }

  /// Whether the platform asked for reduced motion, as of the last build.
  ///
  /// With it, a value the control moves to on its own — set by the caller,
  /// settled after a drag, chosen by a tap or a screen reader — jumps there
  /// instead of springing. A finger dragging the control still moves it: that
  /// is the control following the hand, not decoration.
  bool _reduceMotion = false;

  /// Moves to [value] as the reader's motion setting allows.
  void _settleTo(double value) {
    if (_reduceMotion) {
      _animation.snapToValue(value);
    } else {
      _animation.animateToValue(value);
    }
  }

  @override
  void didUpdateWidget(LiquidSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.backdrop != oldWidget.backdrop) {
      _thumbBackdrop = _combineThumbBackdrop();
    }
    // A range that changes later — a media duration that arrives after the
    // first frame — is clamped and normalised against from now on.
    _animation.valueRange = widget.valueRange;
    if (!_enabled || widget.valueRange != oldWidget.valueRange) {
      _cancelDrag();
    }
    // Mid-drag the finger owns the thumb. The caller echoes back the snapped
    // value, and following it would drag the thumb onto the stop and off the
    // finger every frame.
    if (_dragValue == null && _animation.targetValue != widget.value) {
      if (_reduceMotion) {
        _animation.snapToValue(widget.value);
      } else {
        _animation.updateValue(widget.value);
      }
    }
  }

  @override
  void dispose() {
    _animation.removeListener(_syncFillWidth);
    _animation.dispose();
    _trackBackdrop.dispose();
    _fillWidth.dispose();
    super.dispose();
  }

  double get _span => widget.valueRange.end - widget.valueRange.start;

  /// Clamps into the range whichever way round it is given.
  double _clampToRange(double value) => value.clamp(
    math.min(widget.valueRange.start, widget.valueRange.end),
    math.max(widget.valueRange.start, widget.valueRange.end),
  );

  /// Rounds to the nearest step when [LiquidSlider.divisions] is set.
  ///
  /// Applied to what is *reported*, never to what the thumb is drawn at: the
  /// bead follows the finger and the value lands on a stop, which is how a
  /// stepped slider stays smooth under the thumb.
  double _snap(double raw) {
    final int? divisions = widget.divisions;
    if (divisions == null || _span == 0) return raw;
    final double step = _span / divisions;
    final double stepped =
        widget.valueRange.start +
        ((raw - widget.valueRange.start) / step).roundToDouble() * step;
    return _clampToRange(stepped);
  }

  void _onDrag(Size size, Offset dragAmount) {
    if (!_enabled || !_interactionActive) return;
    if (!_didDrag) {
      _didDrag = dragAmount.dx != 0;
    }
    if (_trackWidth == 0) return;
    final bool isLtr = Directionality.of(context) == TextDirection.ltr;
    final double delta = _span * (dragAmount.dx / _trackWidth);
    final double base = _dragValue ?? _animation.targetValue;
    final double raw = _clampToRange(isLtr ? base + delta : base - delta);
    _dragValue = raw;
    // The thumb follows the finger; only what is reported lands on a stop.
    _animation.updateValue(raw);
    if (_claimed) _reportValue(_snap(raw));
  }

  void _startInteraction() {
    if (!_enabled || _interactionActive) return;
    _interactionActive = true;
    _claimed = false;
    _didDrag = false;
    _lastReportedValue = widget.value;
  }

  /// The drag is the slider's: start the interaction for the caller, and
  /// catch it up with where the finger has already taken the thumb.
  void _claim({bool report = true}) {
    if (!_enabled || !_interactionActive || _claimed) return;
    _claimed = true;
    widget.onChangeStart?.call(widget.value);
    final double? raw = _dragValue;
    if (report && raw != null) _reportValue(_snap(raw));
  }

  void _reportValue(double value) {
    if (!_enabled || _lastReportedValue == value) return;
    _lastReportedValue = value;
    widget.onValueChanged?.call(value);
  }

  void _cancelDrag() {
    _interactionActive = false;
    _claimed = false;
    _didDrag = false;
    _dragValue = null;
    _lastReportedValue = null;
    _animation.cancelDrag();
    _animation.snapToValue(widget.value);
  }

  void _commit(double target) {
    if (!_enabled || target == widget.value) return;
    widget.onChangeStart?.call(widget.value);
    _settleTo(target);
    widget.onValueChanged?.call(target);
    widget.onChangeEnd?.call(target);
  }

  void _onTrackTap(Offset position) {
    if (!_enabled || _trackWidth == 0) return;
    final bool isLtr = Directionality.of(context) == TextDirection.ltr;
    final double delta = _span * (position.dx / _trackWidth);
    final double target = _snap(
      _clampToRange(
        isLtr ? widget.valueRange.start + delta : widget.valueRange.end - delta,
      ),
    );
    _commit(target);
  }

  /// One screen-reader step: a stop when [LiquidSlider.divisions] is set, a
  /// tenth of the range otherwise — what Flutter's own slider moves by.
  double _nudged(int direction) {
    final int? divisions = widget.divisions;
    final double step = divisions != null ? _span / divisions : _span * 0.1;
    return _snap(_clampToRange(widget.value + step * direction));
  }

  void _nudge(int direction) {
    _commit(_nudged(direction));
  }

  String _describe(double value) {
    if (widget.semanticFormatterCallback != null) {
      return widget.semanticFormatterCallback!(value);
    }
    final double progress = _span == 0
        ? 0
        : (value - widget.valueRange.start) / _span;
    return '${(progress.clamp(0.0, 1.0) * 100).round()}%';
  }

  /// The track backdrop, squashed towards the thumb's centre while pressed.
  void _drawScaledTrack(
    BackdropDrawContext context,
    void Function() drawBackdrop,
  ) {
    final double progress = _animation.pressProgress;
    final double scaleX = lerpDouble(2 / 3, 1, progress)!;
    final double scaleY = lerpDouble(0, 1, progress)!;
    final Canvas canvas = context.canvas;
    final Offset center = Offset(
      context.size.width / 2,
      context.size.height / 2,
    );
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(scaleX, scaleY);
    canvas.translate(-center.dx, -center.dy);
    drawBackdrop();
    canvas.restore();
  }

  void _thumbLayerBlock(GlassLayer layer) {
    layer.scaleX = _animation.scaleX;
    layer.scaleY = _animation.scaleY;
    final double velocity = _animation.velocity / 10.0;
    layer.scaleX /= 1.0 - (velocity * 0.75).clamp(-0.2, 0.2);
    layer.scaleY *= 1.0 - (velocity * 0.25).clamp(-0.2, 0.2);
  }

  Widget _buildThumb() {
    return DrawBackdrop(
      backdrop: _thumbBackdrop,
      shape: () => const Capsule(),
      effects: (BackdropEffectScope scope) {
        final double progress = _animation.pressProgress;
        final double blurRadius = 8 * (1 - progress);
        scope
          ..blur(blurRadius)
          ..lens(10 * progress, 14 * progress, chromaticAberration: true);
        // Same as the toggle's knob: the thumb refracts a scaled copy of its
        // track, which does not fill the layer, so the clamped blur has to be
        // given room to read — otherwise it clamps against the layer's straight
        // edges and squares off the thumb's sampling.
        if (scope.padding < blurRadius) {
          scope.padding = blurRadius;
        }
      },
      highlight: () {
        final double progress = _animation.pressProgress;
        return Highlight.ambient.copyWith(
          width: Highlight.ambient.width / 1.5,
          blurRadius: Highlight.ambient.blurRadius / 1.5,
          alpha: progress,
        );
      },
      shadow: () => GlassShadow(
        radius: 4,
        color: const Color(0xFF000000).withValues(alpha: 0.05),
      ),
      innerShadow: () {
        final double progress = _animation.pressProgress;
        return GlassInnerShadow(radius: 4 * progress, alpha: progress);
      },
      layerBlock: _thumbLayerBlock,
      onDrawSurface: (Canvas canvas, Size size) {
        final double progress = _animation.pressProgress;
        canvas.drawRect(
          Offset.zero & size,
          Paint()
            ..color = const Color(0xFFFFFFFF).withValues(alpha: 1 - progress),
        );
      },
      // Src-over only, so the isolating save-layer is pure
      // cost.
      isolateSurface: false,
      repaint: _animation,
      child: const SizedBox(width: _thumbWidth, height: _thumbHeight),
    );
  }

  @override
  Widget build(BuildContext context) {
    _reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final LiquidGlassColors colors = LiquidGlassTheme.of(context);
    final Color accentColor = colors.accent;
    final Color trackColor = colors.track;
    final bool isLtr = Directionality.of(context) == TextDirection.ltr;

    // A slider, as a screen reader should hear it: a value, and a step either
    // way. It had no semantics at all. The track's own tap handler is kept out
    // of it — a semantic tap has no position, and would land at the start.
    return Semantics(
      container: true,
      slider: true,
      enabled: _enabled,
      label: widget.semanticLabel,
      value: _describe(widget.value),
      increasedValue: _describe(_nudged(1)),
      decreasedValue: _describe(_nudged(-1)),
      onIncrease: _enabled ? () => _nudge(1) : null,
      onDecrease: _enabled ? () => _nudge(-1) : null,
      textDirection: Directionality.of(context),
      child: ControlFocus(
        enabled: _enabled,
        focusNode: widget.focusNode,
        autofocus: widget.autofocus,
        onStep: _nudge,
        onFirst: () => _commit(widget.valueRange.start),
        onLast: () => _commit(widget.valueRange.end),
        child: ExcludeSemantics(
          child: _buildSlider(isLtr, accentColor, trackColor),
        ),
      ),
    );
  }

  Widget _buildSlider(bool isLtr, Color accentColor, Color trackColor) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        _trackWidth = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : _unboundedTrackWidth;
        _syncFillWidth();
        return SizedBox(
          width: _trackWidth,
          height: widget.touchTargetHeight,
          child: Stack(
            alignment: isLtr ? Alignment.centerLeft : Alignment.centerRight,
            // Compose's Box does not clip: the thumb grows past the track
            // while pressed and carries a shadow.
            clipBehavior: Clip.none,
            children: <Widget>[
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapUp: (TapUpDetails details) =>
                      _onTrackTap(details.localPosition),
                ),
              ),
              IgnorePointer(
                child: BackdropLayer(
                  backdrop: _trackBackdrop,
                  child: Stack(
                    alignment: isLtr
                        ? Alignment.centerLeft
                        : Alignment.centerRight,
                    clipBehavior: Clip.none,
                    children: <Widget>[
                      ClipPath(
                        clipper: const GlassShapeClipper(Capsule()),
                        child: Container(
                          width: _trackWidth,
                          height: 6,
                          color: trackColor,
                        ),
                      ),
                      // Drawn over the track, but taps must reach the track
                      // beneath it, so the fill takes no pointer input. Painted
                      // rather than laid out: a Container whose width changes
                      // every frame re-runs layout and rebuilds its element,
                      // when only pixels changed.
                      IgnorePointer(
                        child: CustomPaint(
                          size: Size(_trackWidth, 6),
                          painter: _TrackFillPainter(
                            width: _fillWidth,
                            color: accentColor,
                            isLtr: isLtr,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              AnimatedTranslation(
                listenable: _animation,
                // Built once per build, not per tick: only the translation
                // follows the animation, and the glass repaints on its own
                // `repaint` listenable.
                child: _animation.wrapGestures(
                  onCancel: _cancelDrag,
                  claimAxis: Axis.horizontal,
                  onClaim: _claim,
                  child: _buildThumb(),
                ),
                offset: () {
                  // The thumb overhangs each end of the track by a quarter of
                  // itself. On a track too short for that, both limits meet
                  // rather than crossing, which `clamp` would throw on.
                  const double minX = -_thumbWidth / 4;
                  final double maxX = math.max(
                    minX,
                    _trackWidth - _thumbWidth * 3 / 4,
                  );
                  final double translationX =
                      (-_thumbWidth / 2 + _trackWidth * _animation.progress)
                          .clamp(minX, maxX) *
                      (isLtr ? 1 : -1);
                  return Offset(translationX, 0);
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
