import 'dart:math' as math;

/// Solves for the Bezier control points of a G2-continuous ("squircle") corner.
///
/// [getCornerBezierPoints] returns 20 numbers — ten (x, y) pairs — normalised
/// to a corner radius of 1, describing the corner as three cubic segments plus
/// the straight-edge extension points.
class ContinuousCurvatureRoundedRectangleCornerBuilder {
  ContinuousCurvatureRoundedRectangleCornerBuilder({
    this.extendedFraction = 2.0 / 3.0,
    this.arcFraction = 0.5,
  }) : _theta = (1.0 - arcFraction) * _fracPi4 {
    _cos = math.cos(_theta);
    _sin = math.sin(_theta);
    _cot = 1.0 / math.tan(_theta);
    _cos2 = _cos * _cos;
    _sin2 = _sin * _sin;
    final double cos3 = _cos2 * _cos;
    _sin3 = _sin2 * _sin;
    final double sin3 = _sin3;

    _k0 = 27.0 * (_sqrt2 - 6.0 * _cos + 6.0 * _sqrt2 * _cos2 - 4.0 * cos3) * _cot +
        2.0 *
            _sin *
            (-9.0 +
                2.0 * (_sqrt2 - 2.0 * _sin) * sin3 +
                2.0 * _sqrt2 * _cos * (9.0 + _sin2) -
                2.0 * _cos2 * (9.0 + 2.0 * _sin2));
    _k1 = -81.0 *
            (-2.0 + _sqrt2 + 4.0 * (-1.0 + _sqrt2) * _cos + 2.0 * (-2.0 + _sqrt2) * _cos2) *
            _cot -
        4.0 *
            _sin *
            (-9.0 + 9.0 * _sqrt2 + _sqrt2 * sin3 + (-2.0 + _sqrt2) * _cos * (9.0 + _sin2));
    _k2 = 9.0 *
        (9.0 * (-4.0 + 3.0 * _sqrt2 + (-6.0 + 4.0 * _sqrt2) * _cos) * _cot +
            (-6.0 + 4.0 * _sqrt2) * _sin);
    _k3 = 27.0 * (10.0 - 7.0 * _sqrt2) * _cot;

    _cache = <List<List<double>>>[
      <List<double>>[
        _buildEvenCornerBezierPoints(0.0),
        _buildUnevenCornerBezierPoints(0.0, 1.0),
      ],
      <List<double>>[
        _buildUnevenCornerBezierPoints(1.0, 0.0),
        _buildEvenCornerBezierPoints(1.0),
      ],
    ];
  }

  static final ContinuousCurvatureRoundedRectangleCornerBuilder instance =
      ContinuousCurvatureRoundedRectangleCornerBuilder();

  final double extendedFraction;
  final double arcFraction;

  final double _theta;
  late final double _cos;
  late final double _sin;
  late final double _cot;
  late final double _cos2;
  late final double _sin2;
  late final double _sin3;
  late final double _k0;
  late final double _k1;
  late final double _k2;
  late final double _k3;

  late final List<List<List<double>>> _cache;

  /// [tH] and [tV] are the horizontal/vertical room available for the corner,
  /// each clamped to 0..1 by the caller.
  List<double> getCornerBezierPoints([double tH = 1.0, double tV = 1.0]) {
    final int i;
    if (tH == 0.0) {
      i = 0;
    } else if (tH == 1.0) {
      i = 1;
    } else {
      return _buildCornerBezierPoints(tH, tV);
    }
    final int j;
    if (tV == 0.0) {
      j = 0;
    } else if (tV == 1.0) {
      j = 1;
    } else {
      return _buildCornerBezierPoints(tH, tV);
    }
    return _cache[i][j];
  }

  List<double> _buildCornerBezierPoints(double tH, double tV) {
    return tH == tV
        ? _buildEvenCornerBezierPoints(tH)
        : _buildUnevenCornerBezierPoints(tH, tV);
  }

  List<double> _buildEvenCornerBezierPoints([double t = 1.0]) {
    final double k = extendedFraction * t;

    final double kappa =
        _solveCubicSingle(_k3, _k2, _k1 + 8.0 * (-k) * _sin3 * _sin, _k0);

    final double x3 = _frac1Sqrt2 + (-_frac1Sqrt2 + _sin) / kappa;
    final double y3 = 1.0 - _frac1Sqrt2 + (_frac1Sqrt2 - _cos) / kappa;
    final double x2 = x3 - y3 * _cot;
    final double x1 = x2 - 1.5 * kappa * y3 * y3 / _sin3;
    final double x0 = -k;

    final double x6 = 1.0 - y3;
    final double y6 = 1.0 - x3;
    final double y7 = 1.0 - x2;
    final double y8 = 1.0 - x1;
    final double y9 = 1.0 - x0;

    final double a = 1.5 * kappa;
    final double g = _cos2 - _sin2;
    final double x36 = x6 - x3;
    final double y36 = y6 - y3;
    final double c = -(_cos * y36 - _sin * x36);
    final double lambda = (-g + math.sqrt(g * g - 4.0 * a * c)) / (2.0 * a);
    final double x4 = x3 + lambda * _cos;
    final double y4 = y3 + lambda * _sin;
    final double x5 = x6 - lambda * _sin;
    final double y5 = y6 - lambda * _cos;

    return <double>[
      x0, 0.0, x1, 0.0, x2, 0.0, x3, y3, x4, y4,
      x5, y5, x6, y6, 1.0, y7, 1.0, y8, 1.0, y9,
    ];
  }

  List<double> _buildUnevenCornerBezierPoints([double tH = 1.0, double tV = 1.0]) {
    final double kH = extendedFraction * tH;
    final double kV = extendedFraction * tV;

    final double kappa3 =
        _solveCubicSingle(_k3, _k2, _k1 + 8.0 * (-kH) * _sin3 * _sin, _k0);
    final double kappa6 =
        _solveCubicSingle(_k3, _k2, _k1 + 8.0 * (-kV) * _sin3 * _sin, _k0);

    final double x3 = _frac1Sqrt2 + (-_frac1Sqrt2 + _sin) / kappa3;
    final double y3 = 1.0 - _frac1Sqrt2 + (_frac1Sqrt2 - _cos) / kappa3;
    final double x2 = x3 - y3 * _cot;
    final double x1 = x2 - 1.5 * kappa3 * y3 * y3 / _sin3;
    final double x0 = -kH;

    final double x3p = _frac1Sqrt2 + (-_frac1Sqrt2 + _sin) / kappa6;
    final double y3p = 1.0 - _frac1Sqrt2 + (_frac1Sqrt2 - _cos) / kappa6;
    final double x2p = x3p - y3p * _cot;
    final double x1p = x2p - 1.5 * kappa6 * y3p * y3p / _sin3;
    final double x0p = -kV;
    final double x6 = 1.0 - y3p;
    final double y6 = 1.0 - x3p;
    final double y7 = 1.0 - x2p;
    final double y8 = 1.0 - x1p;
    final double y9 = 1.0 - x0p;

    final double a = 1.5 * kappa3;
    final double b = 1.5 * kappa6;
    final double g = _cos2 - _sin2;
    final double x36 = x6 - x3;
    final double y36 = y6 - y3;
    final double c = -(_cos * y36 - _sin * x36);
    final double d = _sin * y36 - _cos * x36;
    final double p = 2.0 * (d / b);
    final double q = g * g * g / (a * b * b);
    final double r = (a * d * d + c * g * g) / (a * b * b);
    final double lambda6 = _solveDepressedQuarticSingle(p, q, r);
    final double lambda3 = (-d - b * lambda6 * lambda6) / g;
    final double x4 = x3 + lambda3 * _cos;
    final double y4 = y3 + lambda3 * _sin;
    final double x5 = x6 - lambda6 * _sin;
    final double y5 = y6 - lambda6 * _cos;

    return <double>[
      x0, 0.0, x1, 0.0, x2, 0.0, x3, y3, x4, y4,
      x5, y5, x6, y6, 1.0, y7, 1.0, y8, 1.0, y9,
    ];
  }
}

double _cbrt(double x) {
  if (x == 0.0) return 0.0;
  if (x.isNaN) return double.nan;
  return x < 0.0
      ? -math.pow(-x, 1.0 / 3.0).toDouble()
      : math.pow(x, 1.0 / 3.0).toDouble();
}

double _solveCubicSingle(double a, double b, double c, double d) {
  final double f = ((3.0 * c / a) - (b * b) / (a * a)) / 3.0;
  final double g =
      ((2.0 * b * b * b) / (a * a * a) - (9.0 * b * c) / (a * a) + (27.0 * d) / a) / 27.0;
  final double h = g * g / 4.0 + f * f * f / 27.0;
  final double sqrtH = math.sqrt(h);
  return _cbrt(-g / 2.0 + sqrtH) + _cbrt(-g / 2.0 - sqrtH) - b / (3.0 * a);
}

double _solveDepressedQuarticSingle(double p, double q, double r) {
  final double b = -p / 2.0;
  final double c = -r;
  final double d = r * p / 2.0 - q * q / 8.0;
  final double f = ((3.0 * c) - (b * b)) / 3.0;
  final double g = ((2.0 * b * b * b) - (9.0 * b * c) + (27.0 * d)) / 27.0;
  final double rr = math.sqrt(-f * f * f / 27.0);
  final double phi = math.acos(-g / (2.0 * rr));
  final double y = 2.0 * math.sqrt(-f / 3.0) * math.cos(phi / 3.0);
  final double z = y - b / 3.0;
  final double u = math.sqrt(2.0 * z - p);
  return (u - math.sqrt(u * u - 4.0 * (z + q / (2.0 * u)))) / 2.0;
}

const double _sqrt2 = 1.4142135623730951;
const double _fracPi4 = 0.7853981633974483;
const double _frac1Sqrt2 = 0.7071067811865476;
