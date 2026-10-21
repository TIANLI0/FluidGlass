import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../../foundation/soft_colors.dart';
import '../../foundation/soft_motion.dart';
import '../../foundation/soft_theme.dart';
import 'soft_selection_frame.dart';

/// The colours of a [SoftRadioButton].
@immutable
class SoftRadioButtonColors {
  const SoftRadioButtonColors({
    required this.selected,
    required this.disabledSelected,
    required this.unselected,
    required this.disabledUnselected,
    this.centre = const Color(0xFFFFFFFF),
    required this.disabledCentre,
  });

  /// The reference roles: a `primary` disc with a white centre (white in both
  /// themes), an `onSurfaceVariantActions` ring; `disabledPrimary`,
  /// `disabledSecondaryVariant` and `disabledOnPrimaryButton` when disabled.
  factory SoftRadioButtonColors.of(SoftColors c) => SoftRadioButtonColors(
    selected: c.primary,
    disabledSelected: c.disabledPrimary,
    unselected: c.onSurfaceVariantActions,
    disabledUnselected: c.disabledSecondaryVariant,
    disabledCentre: c.disabledOnPrimaryButton,
  );

  /// The selected disc.
  final Color selected;
  final Color disabledSelected;

  /// The unselected ring.
  final Color unselected;
  final Color disabledUnselected;

  /// The dot in the middle of the selected disc.
  final Color centre;
  final Color disabledCentre;

  Color disc(bool enabled) => enabled ? selected : disabledSelected;

  Color ring(bool enabled) => enabled ? unselected : disabledUnselected;

  Color dot(bool enabled) => enabled ? centre : disabledCentre;

  @override
  bool operator ==(Object other) =>
      other is SoftRadioButtonColors &&
      other.selected == selected &&
      other.disabledSelected == disabledSelected &&
      other.unselected == unselected &&
      other.disabledUnselected == disabledUnselected &&
      other.centre == centre &&
      other.disabledCentre == disabledCentre;

  @override
  int get hashCode => Object.hash(
    selected,
    disabledSelected,
    unselected,
    disabledUnselected,
    centre,
    disabledCentre,
  );
}

/// The radio button geometry and timing.
abstract final class SoftRadioButtonDefaults {
  /// The square the radio button lays out in.
  static const double size = 24;

  /// Selecting: 300 ms on this easing.
  static const Cubic selectEase = Cubic(0.3, 0, 0.1, 1);

  /// Deselecting: 200–267 ms on this easing.
  static const Cubic deselectEase = Cubic(0.33, 0, 0.67, 1);

  /// The pulse every toggle plays on the ring and the disc.
  static const double pulseScale = 1.08;
}

/// A radio button.
///
/// Unselected is a 1.3 ring of radius 9.2; selected is a disc of radius 10
/// with a white dot of radius 6 in the middle. Selecting cross-fades the ring
/// into the disc and grows the dot from the centre over 300 ms; deselecting
/// runs it back over 200–267 ms. Both pulse the ring and disc 1 → 1.08 → 1,
/// and a press sinks the whole button to 0.85.
///
/// [onTap] is called on a tap; the caller updates [selected]. Without it the
/// button is not tappable (a list row usually handles the tap instead).
class SoftRadioButton extends StatefulWidget {
  const SoftRadioButton({
    super.key,
    required this.selected,
    required this.onTap,
    this.enabled = true,
    this.colors,
  });

  final bool selected;
  final VoidCallback? onTap;
  final bool enabled;

  /// Defaults to [SoftRadioButtonColors.of] the theme's colours.
  final SoftRadioButtonColors? colors;

  @override
  State<SoftRadioButton> createState() => _SoftRadioButtonState();
}

class _SoftRadioButtonState extends State<SoftRadioButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
    value: 1,
  );
  late final _RadioTimeline _timeline = _RadioTimeline(_clock, widget.selected);

  @override
  void didUpdateWidget(SoftRadioButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selected != widget.selected) {
      _timeline.retarget(widget.selected);
      if (softReduceMotion(context)) {
        _clock.value = 1;
      } else {
        _clock.forward(from: 0);
      }
    }
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  void _handleTap() {
    final VoidCallback? onTap = widget.onTap;
    if (onTap == null) return;
    onTap();
    playSoftSelectionHaptic(
      widget.selected
          ? SoftSelectionHaptic.toggleOff
          : SoftSelectionHaptic.toggleOn,
    );
  }

  @override
  Widget build(BuildContext context) {
    final SoftRadioButtonColors colors =
        widget.colors ?? SoftRadioButtonColors.of(SoftTheme.colorsOf(context));
    final bool enabled = widget.enabled;
    final bool tappable = enabled && widget.onTap != null;
    return SoftMinTouchTarget(
      child: Semantics(
        container: true,
        enabled: enabled,
        checked: widget.selected,
        inMutuallyExclusiveGroup: true,
        onTap: tappable ? _handleTap : null,
        child: SoftSelectionFrame(
          enabled: enabled,
          onTap: tappable ? _handleTap : null,
          builder: (BuildContext context, ValueListenable<double> sink) =>
              CustomPaint(
                painter: _RadioPainter(
                  timeline: _timeline,
                  sink: sink,
                  ring: colors.ring(enabled),
                  disc: colors.disc(enabled),
                  dot: colors.dot(enabled),
                ),
              ),
        ),
      ),
    );
  }
}

/// The value of each layer over one transition.
class _RadioTimeline {
  _RadioTimeline(this.clock, bool selected)
    : _selected = selected,
      _ring0 = selected ? 0 : 1,
      _disc0 = selected ? 1 : 0,
      _dotScale0 = selected ? 1 : 0,
      _dotAlpha0 = selected ? 1 : 0;

  final AnimationController clock;
  bool _selected;
  double _ring0;
  double _disc0;
  double _dotScale0;
  double _dotAlpha0;
  bool _pulses = false;

  double get _ms => clock.value * 300;

  Cubic get _ease => _selected
      ? SoftRadioButtonDefaults.selectEase
      : SoftRadioButtonDefaults.deselectEase;

  void retarget(bool selected) {
    _ring0 = ring;
    _disc0 = disc;
    _dotScale0 = dotScale;
    _dotAlpha0 = dotAlpha;
    _selected = selected;
    _pulses = true;
  }

  double _tween(double from, double to, double duration) {
    final double ms = _ms;
    if (ms >= duration) return to;
    return ui.lerpDouble(from, to, _ease.transform(ms / duration))!;
  }

  double get ring => _tween(_ring0, _selected ? 0 : 1, _selected ? 300 : 267);

  double get disc => _tween(_disc0, _selected ? 1 : 0, _selected ? 300 : 200);

  double get dotScale =>
      _tween(_dotScale0, _selected ? 1 : 0, _selected ? 300 : 267);

  double get dotAlpha =>
      _tween(_dotAlpha0, _selected ? 1 : 0, _selected ? 300 : 200);

  double get pulse {
    if (!_pulses) return 1;
    final double ms = _ms;
    const double peak = SoftRadioButtonDefaults.pulseScale;
    final Cubic e = _ease;
    if (ms >= 300) return 1;
    return ms < 150
        ? ui.lerpDouble(1, peak, e.transform(ms / 150))!
        : ui.lerpDouble(peak, 1, e.transform((ms - 150) / 150))!;
  }
}

class _RadioPainter extends CustomPainter {
  _RadioPainter({
    required this.timeline,
    required this.sink,
    required this.ring,
    required this.disc,
    required this.dot,
  }) : super(repaint: Listenable.merge(<Listenable>[timeline.clock, sink]));

  final _RadioTimeline timeline;
  final ValueListenable<double> sink;
  final Color ring;
  final Color disc;
  final Color dot;

  @override
  void paint(Canvas canvas, Size size) {
    final double u = size.shortestSide / 24;
    final Offset centre = size.center(Offset.zero);
    canvas
      ..save()
      ..translate(centre.dx, centre.dy)
      ..scale(sink.value);
    final double pulse = timeline.pulse;

    final double ringAlpha = timeline.ring.clamp(0.0, 1.0);
    if (ringAlpha > 0) {
      // The pulse scales the stroke too.
      canvas.drawCircle(
        Offset.zero,
        9.2 * u * pulse,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.3 * u * pulse
          ..color = ring.withValues(alpha: ring.a * ringAlpha),
      );
    }
    final double discAlpha = timeline.disc.clamp(0.0, 1.0);
    if (discAlpha > 0) {
      canvas.drawCircle(
        Offset.zero,
        10 * u * pulse,
        Paint()..color = disc.withValues(alpha: disc.a * discAlpha),
      );
    }
    final double dotScale = timeline.dotScale;
    final double dotAlpha = timeline.dotAlpha.clamp(0.0, 1.0);
    if (dotScale > 0 && dotAlpha > 0) {
      canvas.drawCircle(
        Offset.zero,
        6 * u * dotScale,
        Paint()..color = dot.withValues(alpha: dot.a * dotAlpha),
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_RadioPainter old) =>
      old.timeline != timeline ||
      old.sink != sink ||
      old.ring != ring ||
      old.disc != disc ||
      old.dot != dot;
}
