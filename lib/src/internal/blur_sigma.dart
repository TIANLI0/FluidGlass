/// The Android framework expresses blurs as a *radius*, while Flutter's
/// `ImageFilter.blur` and `MaskFilter.blur` take a *sigma*.
///
/// Android's `RenderEffect.createBlurEffect` and `BlurMaskFilter` both funnel
/// through Skia's `SkBlurMask::ConvertRadiusToSigma`, which is the conversion
/// used here.
const double kBlurSigmaScale = 0.57735;

/// Converts a blur radius to the equivalent Gaussian sigma.
///
/// The conversion applies to a radius already resolved to *device* pixels, so
/// the `+ 0.5` term is half a device pixel, not half a logical one. [radius]
/// here is in logical pixels, so it is taken to device pixels for the
/// conversion and the result brought back, which keeps a given radius looking
/// the same at any [devicePixelRatio].
double blurRadiusToSigma(double radius, {double devicePixelRatio = 1.0}) {
  if (radius <= 0.0) return 0.0;
  if (devicePixelRatio <= 0.0) return kBlurSigmaScale * radius + 0.5;
  return (kBlurSigmaScale * radius * devicePixelRatio + 0.5) / devicePixelRatio;
}
