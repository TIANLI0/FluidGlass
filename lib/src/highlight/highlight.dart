import 'package:flutter/foundation.dart';

import 'highlight_style.dart';

/// The bright rim drawn just inside a glass element's edge.
@immutable
class Highlight {
  const Highlight._({
    required this.width,
    required this.blurRadius,
    required this.alpha,
    required this.style,
  });

  /// [blurRadius] defaults to half of [width].
  factory Highlight({
    double width = 0.5,
    double? blurRadius,
    double alpha = 1.0,
    HighlightStyle style = HighlightStyle.standard,
  }) {
    return Highlight._(
      width: width,
      blurRadius: blurRadius ?? width / 2.0,
      alpha: alpha,
      style: style,
    );
  }

  /// The thickness of the rim, in logical pixels.
  final double width;

  /// How far the rim is feathered, in logical pixels.
  final double blurRadius;

  /// An overall opacity applied to the rim.
  final double alpha;

  final HighlightStyle style;

  /// A rim lit from the top-left.
  static const Highlight standard = Highlight._(
    width: 0.5,
    blurRadius: 0.25,
    alpha: 1.0,
    style: HighlightStyle.standard,
  );

  /// A rim that is white on the lit side and black on the other.
  static const Highlight ambient = Highlight._(
    width: 0.5,
    blurRadius: 0.25,
    alpha: 1.0,
    style: HighlightStyle.ambient,
  );

  /// A rim of uniform colour.
  static const Highlight plain = Highlight._(
    width: 0.5,
    blurRadius: 0.25,
    alpha: 1.0,
    style: HighlightStyle.plain,
  );

  Highlight copyWith({
    double? width,
    double? blurRadius,
    double? alpha,
    HighlightStyle? style,
  }) {
    return Highlight._(
      width: width ?? this.width,
      blurRadius: blurRadius ?? this.blurRadius,
      alpha: alpha ?? this.alpha,
      style: style ?? this.style,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Highlight &&
      other.width == width &&
      other.blurRadius == blurRadius &&
      other.alpha == alpha &&
      other.style == style;

  @override
  int get hashCode => Object.hash(width, blurRadius, alpha, style);

  @override
  String toString() =>
      'Highlight(width: $width, blurRadius: $blurRadius, alpha: $alpha, style: $style)';
}
