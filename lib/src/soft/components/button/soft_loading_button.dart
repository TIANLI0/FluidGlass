import 'package:flutter/widgets.dart';

import '../../foundation/soft_theme.dart';
import 'soft_button.dart';

/// The loading button defaults.
abstract final class SoftLoadingButtonDefaults {
  /// The radius of each loading dot.
  static const double dotRadius = 1;

  /// The gap between two neighbouring dots.
  static const double dotSpacing = 2;

  /// One wave cycle.
  static const Duration cycle = Duration(milliseconds: 1332);

  /// The delay between two neighbouring dots joining the wave.
  static const Duration stagger = Duration(milliseconds: 333);

  static const double startAlpha = 0.2;
  static const double midAlpha = 0.5;
  static const double endAlpha = 1;

  /// The alpha of dot [index] [elapsed] after the loading state began: each
  /// dot, delayed by [stagger], runs 20 % → 50 % (133 ms) → 100 % (200 ms),
  /// holds, → 50 % (534 ms) → 20 % (666 ms) and rests until the cycle ends.
  static double dotAlpha(int index, Duration elapsed) {
    final int phase = elapsed.inMicroseconds - index * stagger.inMicroseconds;
    if (phase < 0) return startAlpha;
    final double ms = (phase % cycle.inMicroseconds) / 1000;
    double lerp(double a, double b, double from, double to) =>
        a + (b - a) * ((ms - from) / (to - from));
    if (ms < 133) return lerp(startAlpha, midAlpha, 0, 133);
    if (ms < 200) return lerp(midAlpha, endAlpha, 133, 200);
    if (ms < 467) return endAlpha;
    if (ms < 534) return lerp(endAlpha, midAlpha, 467, 534);
    if (ms < 666) return lerp(midAlpha, startAlpha, 534, 666);
    return startAlpha;
  }
}

/// A text button that switches into a loading state.
///
/// While [loading], the label is hidden (still laid out, so the button keeps
/// its size) and three tiny dots pulse in a staggered wave in the content
/// colour — or, with [loadingText], that label is followed by three pulsing
/// full stops. Taps still press the button but do not call [onPressed].
class SoftLoadingButton extends StatelessWidget {
  const SoftLoadingButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.loading = false,
    this.loadingText,
    this.enabled = true,
    this.variant = SoftButtonVariant.normal,
    this.colors,
    this.cornerRadius = SoftButtonDefaults.cornerRadius,
    this.minWidth = SoftButtonDefaults.minWidth,
    this.minHeight = SoftButtonDefaults.minHeight,
    this.padding = SoftButtonDefaults.padding,
  });

  final String text;
  final VoidCallback? onPressed;
  final bool loading;

  /// Shown with the pulsing stops while loading; null for the dots alone.
  final String? loadingText;
  final bool enabled;
  final SoftButtonVariant variant;
  final SoftButtonColors? colors;
  final double cornerRadius;
  final double minWidth;
  final double minHeight;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final TextStyle style = SoftTheme.textStylesOf(context).button;
    final VoidCallback? onPressed = this.onPressed;
    return Semantics(
      liveRegion: loading,
      child: SoftButton(
        onPressed: onPressed == null
            ? null
            : () {
                if (!loading) onPressed();
              },
        enabled: enabled,
        variant: variant,
        colors: colors,
        cornerRadius: cornerRadius,
        minWidth: minWidth,
        minHeight: minHeight,
        padding: padding,
        child: Stack(
          alignment: Alignment.center,
          children: <Widget>[
            Opacity(
              opacity: loading ? 0 : 1,
              child: Text(text, style: style),
            ),
            if (loading) _SoftLoadingIndicator(text: loadingText, style: style),
          ],
        ),
      ),
    );
  }
}

class _SoftLoadingIndicator extends StatefulWidget {
  const _SoftLoadingIndicator({required this.text, required this.style});

  final String? text;
  final TextStyle style;

  @override
  State<_SoftLoadingIndicator> createState() => _SoftLoadingIndicatorState();
}

class _SoftLoadingIndicatorState extends State<_SoftLoadingIndicator>
    with SingleTickerProviderStateMixin {
  /// Seconds since the loading state began; runs until disposed.
  late final AnimationController _clock = AnimationController.unbounded(
    vsync: this,
  )..animateWith(_ClockSimulation());

  late final List<Animation<double>> _alphas = List<Animation<double>>.generate(
    3,
    (int i) => _clock.drive(_DotAlphaTween(i)),
  );

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String? text = widget.text;
    if (text == null) {
      final Color color =
          DefaultTextStyle.of(context).style.color ?? const Color(0xFF000000);
      const double r = SoftLoadingButtonDefaults.dotRadius;
      const double gap = SoftLoadingButtonDefaults.dotSpacing;
      return RepaintBoundary(
        child: CustomPaint(
          size: const Size(r * 6 + gap * 2, r * 2),
          painter: _DotsPainter(
            clock: _clock,
            color: color,
            rtl: Directionality.of(context) == TextDirection.rtl,
          ),
        ),
      );
    }
    return RepaintBoundary(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: <Widget>[
          Flexible(child: Text(text, style: widget.style)),
          for (final Animation<double> alpha in _alphas)
            ExcludeSemantics(
              child: FadeTransition(
                opacity: alpha,
                child: Text('.', style: widget.style),
              ),
            ),
        ],
      ),
    );
  }
}

/// x(t) = t forever: a clock for an unbounded controller.
class _ClockSimulation extends Simulation {
  @override
  double x(double time) => time;

  @override
  double dx(double time) => 1;

  @override
  bool isDone(double time) => false;
}

class _DotAlphaTween extends Animatable<double> {
  const _DotAlphaTween(this.index);

  final int index;

  @override
  double transform(double t) => SoftLoadingButtonDefaults.dotAlpha(
    index,
    Duration(microseconds: (t * Duration.microsecondsPerSecond).round()),
  );
}

class _DotsPainter extends CustomPainter {
  _DotsPainter({required this.clock, required this.color, required this.rtl})
    : super(repaint: clock);

  final Animation<double> clock;
  final Color color;

  /// The wave runs in reading direction.
  final bool rtl;

  @override
  void paint(Canvas canvas, Size size) {
    final Duration elapsed = Duration(
      microseconds: (clock.value * Duration.microsecondsPerSecond).round(),
    );
    const double r = SoftLoadingButtonDefaults.dotRadius;
    const double step = r * 2 + SoftLoadingButtonDefaults.dotSpacing;
    final double cy = size.height / 2;
    final Paint paint = Paint();
    for (int i = 0; i < 3; i++) {
      final int wave = rtl ? 2 - i : i;
      final double alpha = SoftLoadingButtonDefaults.dotAlpha(wave, elapsed);
      paint.color = color.withValues(alpha: color.a * alpha);
      canvas.drawCircle(Offset(r + step * i, cy), r, paint);
    }
  }

  @override
  bool shouldRepaint(_DotsPainter old) =>
      old.clock != clock || old.color != color || old.rtl != rtl;
}
