import '../backdrop.dart';

/// Whatever the compositor has already painted beneath the element.
///
/// The other backdrops hand the element *pixels* — a live capture of a subtree,
/// a recorded picture, a canvas callback — which the element then samples,
/// refracts and blurs itself. This one hands it nothing: it says "filter what is
/// behind me", and the whole chain becomes a [BackdropFilterLayer], Flutter's
/// own `BackdropFilter`, which the compositor applies to the scene beneath.
///
/// That is the right instrument for a surface **over** the content it filters,
/// which is most modal chrome: a sheet, a dialog, a selection toolbar. Compared
/// with capturing the screen and refracting the capture, it removes three
/// things, not just cost:
///
///  * **The capture.** A full-screen `toImageSync` is a texture the size of the
///    screen — on a 1440x3168 phone, 18 MB — allocated and rasterised every
///    time the surface opens.
///  * **The staleness.** A capture is frozen at the moment it was taken, so
///    anything moving behind the surface stops moving inside it.
///  * **The dim bookkeeping.** A capture has to have the modal barrier's dim
///    painted into it by hand, or the surface reads as a lit window floating
///    over a dimmed page. A compositor filter sits above the barrier already.
///
/// What it gives up is the refraction: there is no texture to bend, so the lens
/// and the shaded rim have nothing to work with. An element on this backdrop is
/// therefore pinned to [GlassQuality.plain] — a plain Gaussian blur behind the
/// tint, with a flat rim — whatever the device could otherwise afford. On a
/// surface that carries a heavy tint (a sheet full of text needs one) the
/// refraction was never visible through it anyway.
///
/// Use a [LayerBackdrop] instead when the refraction *is* the point and the
/// element is not simply on top of what it refracts — a tab bar magnifying the
/// page under it, a button over a photo.
class NativeBackdrop extends Backdrop {
  const NativeBackdrop();

  @override
  bool get isCoordinatesDependent => false;

  @override
  bool get isPaintedBehindConsumer => true;

  @override
  bool get isCompositorOnly => true;

  /// Nothing to draw: the compositor supplies the pixels.
  @override
  void drawBackdrop(BackdropDrawContext context) {}

  @override
  bool operator ==(Object other) => other is NativeBackdrop;

  @override
  int get hashCode => (NativeBackdrop).hashCode;
}

/// The shared [NativeBackdrop] instance.
const Backdrop nativeBackdrop = NativeBackdrop();
