import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/rendering.dart';

import '../backdrop.dart';
import '../backdrops/combined_backdrop.dart';
import '../backdrops/layer_backdrop.dart';
import '../backdrops/wrapped_backdrop.dart';

bool hasLiveSamplingSource(Backdrop backdrop) => switch (backdrop) {
  LayerBackdrop() => true,
  WrappedBackdrop() => hasLiveSamplingSource(backdrop.backdrop),
  CombinedBackdrop() => backdrop.backdrops.any(hasLiveSamplingSource),
  _ => false,
};

int prepareSamplingSource(Backdrop backdrop) {
  switch (backdrop) {
    case LayerBackdrop():
      final LayerBackdropSource? source = backdrop.source;
      if (source is RenderBackdropLayer) {
        source.prepareSampling();
        return Object.hash(
          source,
          source.samplingRevision,
          source.attached ? source.getTransformTo(null) : null,
        );
      }
      if (source is PictureBackdropSource) {
        return Object.hash(
          source,
          source.samplingRevision,
          source.globalTransform,
        );
      }
      return backdrop.hashCode;
    case WrappedBackdrop():
      return prepareSamplingSource(backdrop.backdrop);
    case CombinedBackdrop():
      return Object.hashAll(backdrop.backdrops.map(prepareSamplingSource));
    default:
      return backdrop.hashCode;
  }
}

/// Records glass pixels after this frame's background layers have painted.
/// Unchanged scenes reuse the picture; this layer does not schedule frames.
///
/// **A reused picture is not free.** It replays every blur, lens and blend of
/// the glass on the GPU, frame after frame — and the frames that reuse it are
/// exactly the ones where nothing under the glass changed: something elsewhere
/// on the page is animating (an animated sticker in a chat, a spinner), and
/// the whole scene is composited again around it. So once the same content
/// has been drawn for two frames in a row, the picture is rasterised once,
/// pixel-aligned at device resolution, and later frames draw only that image.
/// Content that changes every frame — a scroll, a press — never reaches the
/// second frame and never pays for the rasterisation.
///
/// Content that changes *every other* frame would: two animations on a page
/// take turns, and the one under the glass changes on every second frame, so
/// each frame in between would rasterise an image the next frame throws
/// away — a whole extra offscreen pass, per frame. So the number of unchanged
/// frames it takes is adaptive: an image thrown away after only a few frames
/// doubles it, and an image that lasted resets it.
class SamplingLayer extends Layer {
  Rect _bounds = Rect.zero;
  int Function()? _signature;
  void Function(Canvas)? _draw;
  Matrix4 Function()? _layerToDevice;
  int? _lastSignature;
  ui.Picture? _picture;
  bool _dirty = true;

  /// The rasterised [_picture], and the picture that draws it.
  ui.Image? _image;
  ui.Picture? _imagePicture;

  /// Whether the current [_picture] could not be rasterised (a rotated or
  /// skewed transform, or a texture too large), so later frames do not retry.
  bool _rasterFailed = false;

  /// Frames drawn with the current [_picture] unchanged, the frame that
  /// recorded it excluded.
  int _unchangedFrames = 0;

  /// Frames drawn from the current [_image].
  int _imageFrames = 0;

  /// How many unchanged frames it takes to rasterise ([minStableFrames] to
  /// [maxStableFrames]).
  int _stableFrames = minStableFrames;

  /// The fewest unchanged frames that rasterise: the first frame that repeats.
  static const int minStableFrames = 1;

  /// The most an image that keeps being thrown away can push it to.
  static const int maxStableFrames = 32;

  /// An image used for fewer frames than this was not worth rasterising.
  static const int wastedImageFrames = 4;

  /// The largest side, in device pixels, worth caching as a texture.
  static const int maxRasterSide = 4096;

  /// [layerToDevice] maps this layer's coordinates to device pixels; null
  /// keeps replaying the picture. [contentKey] names what [draw] draws apart
  /// from the sampled source: the same key at the same bounds keeps the
  /// recording; null re-records on every configure.
  void configure({
    required Rect bounds,
    required int Function() signature,
    required void Function(Canvas) draw,
    Matrix4 Function()? layerToDevice,
    Object? contentKey,
  }) {
    // A repaint the owner did not ask for — an ancestor repainting around it —
    // hands over the same content: keep what was drawn.
    if (contentKey == null || contentKey != _contentKey || bounds != _bounds) {
      _dirty = true;
    }
    _contentKey = contentKey;
    _bounds = bounds;
    _signature = signature;
    _draw = draw;
    _layerToDevice = layerToDevice;
  }

  Object? _contentKey;

  void invalidate() => _dirty = true;

  /// How many times the content was rasterised.
  @visibleForTesting
  int debugRasterizations = 0;

  /// Whether the last frame was drawn from the rasterised image.
  @visibleForTesting
  bool get debugDrewFromImage => _drewFromImage;
  bool _drewFromImage = false;

  @override
  bool get alwaysNeedsAddToScene => true;

  @override
  void addToScene(ui.SceneBuilder builder) {
    final int signature = _signature!();
    if (_dirty || signature != _lastSignature) {
      final ui.PictureRecorder recorder = ui.PictureRecorder();
      _draw!(Canvas(recorder, _bounds));
      final ui.Picture next = recorder.endRecording();
      _picture?.dispose();
      _picture = next;
      if (_image != null) {
        _stableFrames = _imageFrames < wastedImageFrames
            ? math.min(_stableFrames * 2, maxStableFrames)
            : minStableFrames;
      }
      _releaseImage();
      _rasterFailed = false;
      _unchangedFrames = 0;
      _lastSignature = signature;
      _dirty = false;
      _drewFromImage = false;
      builder.addPicture(Offset.zero, next);
      return;
    }
    _unchangedFrames += 1;
    final ui.Picture? cached =
        _imagePicture ??
        (_unchangedFrames >= _stableFrames ? _rasterize() : null);
    _drewFromImage = cached != null;
    if (cached != null) _imageFrames += 1;
    builder.addPicture(Offset.zero, cached ?? _picture!);
  }

  /// Draws [_picture] once into a device-resolution image and returns a
  /// picture that draws that image back in place; null when it cannot be
  /// done exactly.
  ui.Picture? _rasterize() {
    if (_rasterFailed) return null;
    final Matrix4? toDevice = _layerToDevice?.call();
    final ui.Picture? picture = _picture;
    if (toDevice == null || picture == null || _bounds.isEmpty) return null;
    // Only a scale and a translation map pixels onto pixels; anything else
    // would be resampled, and keeps replaying the picture.
    final Float64List m = toDevice.storage;
    final bool axisAligned =
        m[1] == 0 &&
        m[2] == 0 &&
        m[3] == 0 &&
        m[4] == 0 &&
        m[6] == 0 &&
        m[7] == 0 &&
        m[8] == 0 &&
        m[9] == 0 &&
        m[11] == 0 &&
        m[15] == 1 &&
        m[0] > 0 &&
        m[5] > 0;
    if (!axisAligned) {
      _rasterFailed = true;
      return null;
    }
    final Rect device = MatrixUtils.transformRect(toDevice, _bounds);
    final Rect snapped = Rect.fromLTRB(
      device.left.floorToDouble(),
      device.top.floorToDouble(),
      device.right.ceilToDouble(),
      device.bottom.ceilToDouble(),
    );
    final int width = snapped.width.toInt();
    final int height = snapped.height.toInt();
    if (width <= 0 ||
        height <= 0 ||
        width > maxRasterSide ||
        height > maxRasterSide) {
      _rasterFailed = true;
      return null;
    }
    final Matrix4? toLayer = Matrix4.tryInvert(toDevice);
    if (toLayer == null) {
      _rasterFailed = true;
      return null;
    }

    final ui.PictureRecorder raster = ui.PictureRecorder();
    final Canvas rasterCanvas = Canvas(raster);
    rasterCanvas.translate(-snapped.left, -snapped.top);
    rasterCanvas.transform(m);
    rasterCanvas.drawPicture(picture);
    final ui.Picture rasterPicture = raster.endRecording();
    final ui.Image image = rasterPicture.toImageSync(width, height);
    rasterPicture.dispose();

    // Drawn back under the inverse transform, each image pixel lands on the
    // device pixel it was rendered for.
    final ui.PictureRecorder back = ui.PictureRecorder();
    final Canvas backCanvas = Canvas(back);
    backCanvas.transform(toLayer.storage);
    backCanvas.drawImage(image, snapped.topLeft, Paint());
    _image = image;
    _imageFrames = 0;
    debugRasterizations += 1;
    return _imagePicture = back.endRecording();
  }

  void _releaseImage() {
    _imagePicture?.dispose();
    _imagePicture = null;
    _image?.dispose();
    _image = null;
  }

  @override
  void dispose() {
    _picture?.dispose();
    _picture = null;
    _releaseImage();
    _draw = null;
    _signature = null;
    _layerToDevice = null;
    super.dispose();
  }
}
