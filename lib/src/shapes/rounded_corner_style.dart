/// The interpolation used between a rounded rectangle's straight edges and its
/// corners.
enum RoundedCornerStyle {
  /// Plain circular corners, as produced by [RRect].
  circular,

  /// G2-continuous ("squircle") corners, matching Apple's corner curvature.
  continuous,
}
