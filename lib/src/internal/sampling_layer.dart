import 'dart:ui' as ui;

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
class SamplingLayer extends Layer {
  Rect _bounds = Rect.zero;
  int Function()? _signature;
  void Function(Canvas)? _draw;
  int? _lastSignature;
  ui.Picture? _picture;
  bool _dirty = true;

  void configure({
    required Rect bounds,
    required int Function() signature,
    required void Function(Canvas) draw,
  }) {
    _bounds = bounds;
    _signature = signature;
    _draw = draw;
    _dirty = true;
  }

  void invalidate() => _dirty = true;

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
      _lastSignature = signature;
      _dirty = false;
    }
    builder.addPicture(Offset.zero, _picture!);
  }

  @override
  void dispose() {
    _picture?.dispose();
    _picture = null;
    _draw = null;
    _signature = null;
    super.dispose();
  }
}
