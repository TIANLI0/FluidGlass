import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import '../../foundation/soft_glass.dart';
import '../../foundation/soft_motion.dart';
import '../../foundation/soft_pressable.dart';
import '../../foundation/soft_theme.dart';
import '../../foundation/soft_touch_motion.dart';

/// The toolbar icon button defaults.
abstract final class SoftTopAppBarIconButtonDefaults {
  /// The diameter: a true circle.
  static const double size = 40;

  /// The scale the whole control springs to while pressed.
  static const double pressedScale = 0.89;

  /// The press spring: (0.3, 0).
  static final SpringDescription pressSpring = softSpring(
    damping: 1,
    response: 0.3,
  );

  /// The radial fill's alpha.
  static const double fillAlpha = 0.78;

  /// Where the fill reaches its edge colour, as a fraction of the radius.
  static const double fillEdgeStop = 0.89;

  static const Color fillCenterLight = Color(0xFFF9F9F9);
  static const Color fillEdgeLight = Color(0xFFFBFBFB);
  static const Color fillCenterDark = Color(0xFF1E1E1E);
  static const Color fillEdgeDark = Color(0xFF242424);

  /// How far the fill and the icon brighten towards white while pressed.
  static const double pressedFillBrighten = 0.06;
  static const double pressedContentBrighten = 0.1;

  /// The rim: white at this alpha, dark and light.
  static const double strokeAlpha = 0.6;
  static const double lightStrokeAlpha = 0.2;
  static const double strokeWidth = 1.9;

  /// The light theme's halo: a soft dark shadow around the rim.
  static const Color lightHaloColor = Color(0x08000000);
  static const double lightHaloRadius = 12;
  static const double lightHaloOffsetY = 1;

  /// The dark theme's halo: a faint light glow around the rim.
  static const Color darkHaloColor = Color(0x33FFFFFF);
  static const double darkHaloExtent = 4.9;

  /// The icon size inside the button.
  static const double iconSize = 24;
}

/// The toolbar's round icon button — the back and overflow keys.
///
/// A 40 circle with a radial fill a shade darker in the middle, a lit rim
/// and a halo outside the edge (a soft shadow in the light theme, a faint
/// glow in the dark one). While pressed the control springs to 0.89 and the
/// rim and halo go out while the fill and the icon brighten; it also follows
/// and stretches with the finger. [icon] gets an [IconTheme] in the
/// theme's `onBackground`, so [SoftBackIcon] and [SoftMoreIcon] (and any
/// [Icon]) follow it.
class SoftTopAppBarIconButton extends StatefulWidget {
  const SoftTopAppBarIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.semanticLabel,
    this.size = SoftTopAppBarIconButtonDefaults.size,
    this.enabled = true,
  });

  final Widget icon;
  final VoidCallback? onPressed;

  /// The accessible name, such as "Back".
  final String? semanticLabel;
  final double size;
  final bool enabled;

  @override
  State<SoftTopAppBarIconButton> createState() =>
      _SoftTopAppBarIconButtonState();
}

class _SoftTopAppBarIconButtonState extends State<SoftTopAppBarIconButton>
    with SingleTickerProviderStateMixin {
  late final SoftSpring _press = SoftSpring(vsync: this);

  bool get _active => widget.enabled && widget.onPressed != null;

  @override
  void didUpdateWidget(SoftTopAppBarIconButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_active) _press.snapTo(0);
  }

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  void _onPressed(bool pressed) {
    if (!_active) return;
    if (softReduceMotion(context)) {
      _press.snapTo(pressed ? 1 : 0);
      return;
    }
    _press.animateTo(
      pressed ? 1 : 0,
      SoftTopAppBarIconButtonDefaults.pressSpring,
    );
  }

  @override
  Widget build(BuildContext context) {
    final SoftThemeData theme = SoftTheme.of(context);
    final bool dark = theme.isDark;
    final Color content = theme.colors.onBackground;
    return Semantics(
      label: widget.semanticLabel,
      child: SoftTouchMotion(
        enabled: _active,
        pressScale: false,
        child: SoftPressable(
          feedback: SoftPressFeedback.none,
          enabled: _active,
          onTap: widget.onPressed,
          onPressedChanged: _onPressed,
          child: AnimatedBuilder(
            animation: _press,
            builder: (BuildContext context, Widget? child) {
              final double p = _press.value.clamp(0.0, 1.0);
              return Transform.scale(
                scale:
                    1 - (1 - SoftTopAppBarIconButtonDefaults.pressedScale) * p,
                child: IconTheme(
                  data: IconThemeData(
                    color: Color.lerp(
                      content,
                      const Color(0xFFFFFFFF),
                      SoftTopAppBarIconButtonDefaults.pressedContentBrighten *
                          p,
                    ),
                    size: SoftTopAppBarIconButtonDefaults.iconSize,
                  ),
                  child: child!,
                ),
              );
            },
            child: SizedBox.square(
              dimension: widget.size,
              child: CustomPaint(
                painter: _ButtonPainter(press: _press, dark: dark),
                child: Center(child: widget.icon),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ButtonPainter extends CustomPainter {
  _ButtonPainter({required this.press, required this.dark})
    : super(repaint: press);

  final SoftSpring press;
  final bool dark;

  static const SoftGlassRim _lightRim = SoftGlassRim(
    color: Color(0x33FFFFFF),
    width: SoftTopAppBarIconButtonDefaults.strokeWidth,
    innerBlurRadius: 2.6,
    primaryLight: SoftRimLight(0.5, 0.5, -0.5, 0.6),
    secondaryLight: SoftRimLight(0.5, 0.95, -0.5, 0.35),
  );
  static const SoftGlassRim _darkRim = SoftGlassRim(
    color: Color(0x99FFFFFF),
    width: SoftTopAppBarIconButtonDefaults.strokeWidth,
    innerBlurRadius: 2.3,
    primaryLight: SoftRimLight(0.5, 0.5, -0.5, 0.6),
    secondaryLight: SoftRimLight(0.5, 0.95, -0.36, 0.25),
  );

  @override
  void paint(Canvas canvas, Size size) {
    final double p = press.value.clamp(0.0, 1.0);
    final Offset centre = size.center(Offset.zero);
    final double radius = size.shortestSide / 2;
    final double halo = 1 - p;
    if (halo > 0) _paintHalo(canvas, centre, radius, halo);

    final double brighten =
        SoftTopAppBarIconButtonDefaults.pressedFillBrighten * p;
    const Color white = Color(0xFFFFFFFF);
    final Color inner = Color.lerp(
      dark
          ? SoftTopAppBarIconButtonDefaults.fillCenterDark
          : SoftTopAppBarIconButtonDefaults.fillCenterLight,
      white,
      brighten,
    )!.withValues(alpha: SoftTopAppBarIconButtonDefaults.fillAlpha);
    final Color edge = Color.lerp(
      dark
          ? SoftTopAppBarIconButtonDefaults.fillEdgeDark
          : SoftTopAppBarIconButtonDefaults.fillEdgeLight,
      white,
      brighten,
    )!.withValues(alpha: SoftTopAppBarIconButtonDefaults.fillAlpha);
    canvas.drawCircle(
      centre,
      radius,
      Paint()
        ..shader = ui.Gradient.radial(
          centre,
          radius,
          <Color>[inner, edge, edge],
          const <double>[0, SoftTopAppBarIconButtonDefaults.fillEdgeStop, 1],
        ),
    );
    if (halo > 0) {
      final SoftGlassRim rim = dark ? _darkRim : _lightRim;
      canvas
        ..save()
        ..translate(centre.dx - radius, centre.dy - radius);
      paintSoftGlassRim(
        canvas,
        Size.square(radius * 2),
        BorderRadius.circular(radius),
        SoftGlassRim(
          color: rim.color,
          width: rim.width,
          innerBlurRadius: rim.innerBlurRadius,
          primaryLight: rim.primaryLight,
          secondaryLight: rim.secondaryLight,
          alpha: halo,
        ),
        smooth: false,
      );
      canvas.restore();
    }
  }

  void _paintHalo(Canvas canvas, Offset centre, double radius, double t) {
    if (dark) {
      final double outer =
          radius + SoftTopAppBarIconButtonDefaults.darkHaloExtent;
      const Color c = SoftTopAppBarIconButtonDefaults.darkHaloColor;
      canvas.drawCircle(
        centre,
        outer,
        Paint()
          ..shader = ui.Gradient.radial(
            centre,
            outer,
            <Color>[
              c.withValues(alpha: 0),
              c.withValues(alpha: c.a * t),
              c.withValues(alpha: 0),
            ],
            <double>[(radius - 1) / outer, radius / outer, 1],
          ),
      );
      return;
    }
    final double outer =
        radius + SoftTopAppBarIconButtonDefaults.lightHaloRadius;
    final Offset c =
        centre +
        const Offset(0, SoftTopAppBarIconButtonDefaults.lightHaloOffsetY);
    const Color colour = SoftTopAppBarIconButtonDefaults.lightHaloColor;
    final Color solid = colour.withValues(alpha: colour.a * t);
    canvas.drawCircle(
      c,
      outer,
      Paint()
        ..shader = ui.Gradient.radial(
          c,
          outer,
          <Color>[solid, solid, solid.withValues(alpha: 0)],
          <double>[0, radius / outer, 1],
        ),
    );
  }

  @override
  bool shouldRepaint(_ButtonPainter old) =>
      !identical(old.press, press) || old.dark != dark;
}

/// The colour an icon glyph paints in: [explicit], else the nearest
/// [IconTheme]'s, else the theme's `onSurface`.
Color _glyphColor(BuildContext context, Color? explicit) {
  if (explicit != null) return explicit;
  final IconTheme? theme = context
      .dependOnInheritedWidgetOfExactType<IconTheme>();
  return theme?.data.color ?? SoftTheme.of(context).colors.onSurface;
}

double _glyphSize(BuildContext context, double? explicit) {
  if (explicit != null) return explicit;
  final IconTheme? theme = context
      .dependOnInheritedWidgetOfExactType<IconTheme>();
  return theme?.data.size ?? SoftTopAppBarIconButtonDefaults.iconSize;
}

/// The back arrow of the reference's icon set (regular weight).
class SoftBackIcon extends StatelessWidget {
  const SoftBackIcon({super.key, this.size, this.color});

  /// 24 by default, or the [IconTheme]'s size.
  final double? size;

  /// The [IconTheme]'s colour by default, else the theme's `onSurface`.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final bool rtl = Directionality.of(context) == TextDirection.rtl;
    Widget glyph = CustomPaint(
      size: Size.square(_glyphSize(context, size)),
      painter: _BackPainter(_glyphColor(context, color)),
    );
    if (rtl) {
      glyph = Transform.flip(flipX: true, child: glyph);
    }
    return ExcludeSemantics(child: glyph);
  }
}

class _BackPainter extends CustomPainter {
  const _BackPainter(this.color);

  final Color color;

  /// The glyph in its 1330.8 viewport, y already flipped up.
  static final Path _path = _build();

  static Path _build() {
    const double v = 1330.8;
    double y(double value) => v - value;
    return Path()
      ..moveTo(255.9, y(622.4))
      ..lineTo(1187.9, y(622.4))
      ..quadraticBezierTo(1203.9, y(622.4), 1211.9, y(630.4))
      ..quadraticBezierTo(1219.9, y(638.4), 1219.9, y(653.4))
      ..lineTo(1219.9, y(680.4))
      ..quadraticBezierTo(1219.9, y(693.4), 1211.4, y(700.9))
      ..quadraticBezierTo(1202.9, y(708.4), 1187.9, y(708.4))
      ..lineTo(255.9, y(708.4))
      ..lineTo(539.9, y(992.4))
      ..quadraticBezierTo(549.9, y(1002.4), 549.9, y(1012.4))
      ..quadraticBezierTo(549.9, y(1022.4), 537.9, y(1034.4))
      ..lineTo(520.9, y(1051.4))
      ..quadraticBezierTo(508.9, y(1063.4), 498.9, y(1063.4))
      ..quadraticBezierTo(488.9, y(1063.4), 476.9, y(1051.4))
      ..lineTo(129.9, y(703.4))
      ..quadraticBezierTo(111.9, y(685.4), 111.4, y(665.9))
      ..quadraticBezierTo(110.9, y(646.4), 130.9, y(626.4))
      ..lineTo(476.9, y(280.4))
      ..quadraticBezierTo(488.9, y(268.4), 498.4, y(267.9))
      ..quadraticBezierTo(507.9, y(267.4), 520.9, y(280.4))
      ..lineTo(539.9, y(299.4))
      ..quadraticBezierTo(550.9, y(310.4), 550.9, y(318.9))
      ..quadraticBezierTo(550.9, y(327.4), 538.9, y(339.4))
      ..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final double s = size.shortestSide / 1330.8;
    canvas
      ..save()
      ..scale(s)
      ..drawPath(_path, Paint()..color = color)
      ..restore();
  }

  @override
  bool shouldRepaint(_BackPainter old) => old.color != color;
}

/// The overflow glyph of the reference's icon set: three dots stacked
/// vertically.
class SoftMoreIcon extends StatelessWidget {
  const SoftMoreIcon({super.key, this.size, this.color});

  final double? size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: CustomPaint(
        size: Size.square(_glyphSize(context, size)),
        painter: _MorePainter(_glyphColor(context, color)),
      ),
    );
  }
}

class _MorePainter extends CustomPainter {
  const _MorePainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    // Three 71-radius dots on x = 521.4 of a 1042.8 viewport.
    const double v = 1042.8;
    final double s = size.shortestSide / v;
    final Paint paint = Paint()..color = color;
    for (final double y in const <double>[157.9, 521.9, 885.9]) {
      canvas.drawCircle(Offset(521.4 * s, y * s), 71 * s, paint);
    }
  }

  @override
  bool shouldRepaint(_MorePainter old) => old.color != color;
}
