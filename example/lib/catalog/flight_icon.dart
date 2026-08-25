import 'package:flutter/widgets.dart';

/// The Material Symbols "flight" glyph, drawn from its vector path.
///
/// Drawn from the glyph's vector path, including its reflective quadratic
/// segments (SVG's `T`), which Flutter's [Path] has no direct equivalent for.
class FlightIcon extends StatelessWidget {
  const FlightIcon({super.key, this.size = 24, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _FlightIconPainter(color)),
    );
  }
}

class _FlightIconPainter extends CustomPainter {
  const _FlightIconPainter(this.color);

  final Color color;

  static const double _viewport = 960;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / _viewport, size.height / _viewport);
    canvas.drawPath(_path, Paint()..color = color);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _FlightIconPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// Tracks the previous quadratic control point so reflective segments can
/// mirror it, matching Compose's `PathBuilder`.
class _VectorPath {
  final Path path = Path();
  Offset _current = Offset.zero;
  Offset? _lastControl;

  void moveTo(double x, double y) {
    path.moveTo(x, y);
    _current = Offset(x, y);
    _lastControl = null;
  }

  void lineTo(double x, double y) {
    path.lineTo(x, y);
    _current = Offset(x, y);
    _lastControl = null;
  }

  void lineToRelative(double dx, double dy) {
    lineTo(_current.dx + dx, _current.dy + dy);
  }

  void verticalLineToRelative(double dy) {
    lineTo(_current.dx, _current.dy + dy);
  }

  void quadToRelative(double dx1, double dy1, double dx2, double dy2) {
    final Offset control = Offset(_current.dx + dx1, _current.dy + dy1);
    final Offset end = Offset(_current.dx + dx2, _current.dy + dy2);
    path.quadraticBezierTo(control.dx, control.dy, end.dx, end.dy);
    _current = end;
    _lastControl = control;
  }

  void reflectiveQuadTo(double x, double y) {
    final Offset control = _lastControl == null
        ? _current
        : Offset(2 * _current.dx - _lastControl!.dx, 2 * _current.dy - _lastControl!.dy);
    path.quadraticBezierTo(control.dx, control.dy, x, y);
    _current = Offset(x, y);
    _lastControl = control;
  }

  void reflectiveQuadToRelative(double dx, double dy) {
    reflectiveQuadTo(_current.dx + dx, _current.dy + dy);
  }

  void close() => path.close();
}

final Path _path = _buildFlightPath();

Path _buildFlightPath() {
  final _VectorPath p = _VectorPath()
    ..moveTo(400, 552)
    ..lineTo(147, 653)
    ..quadToRelative(-24, 10, -45.5, -4.5)
    ..reflectiveQuadTo(80, 608)
    ..verticalLineToRelative(-22)
    ..quadToRelative(0, -12, 5.5, -23)
    ..reflectiveQuadToRelative(15.5, -18)
    ..lineToRelative(299, -209)
    ..verticalLineToRelative(-176)
    ..quadToRelative(0, -33, 23.5, -56.5)
    ..reflectiveQuadTo(480, 80)
    ..quadToRelative(33, 0, 56.5, 23.5)
    ..reflectiveQuadTo(560, 160)
    ..verticalLineToRelative(176)
    ..lineToRelative(299, 209)
    ..quadToRelative(10, 7, 15.5, 18)
    ..reflectiveQuadToRelative(5.5, 23)
    ..verticalLineToRelative(22)
    ..quadToRelative(0, 26, -21.5, 40.5)
    ..reflectiveQuadTo(813, 653)
    ..lineTo(560, 552)
    ..verticalLineToRelative(144)
    ..lineToRelative(103, 72)
    ..quadToRelative(8, 6, 12.5, 14.5)
    ..reflectiveQuadTo(680, 801)
    ..verticalLineToRelative(24)
    ..quadToRelative(0, 20, -16.5, 32.5)
    ..reflectiveQuadTo(627, 864)
    ..lineToRelative(-147, -44)
    ..lineToRelative(-147, 44)
    ..quadToRelative(-20, 6, -36.5, -6.5)
    ..reflectiveQuadTo(280, 825)
    ..verticalLineToRelative(-24)
    ..quadToRelative(0, -10, 4.5, -18.5)
    ..reflectiveQuadTo(297, 768)
    ..lineToRelative(103, -72)
    ..verticalLineToRelative(-144)
    ..close();
  return p.path;
}
