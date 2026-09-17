import 'package:flutter/rendering.dart';

/// Only layers whose drawing can be reproduced without engine-owned effects.
/// Unknown/custom layers and filters keep the engine's snapshot path.
bool canReplayLayer(Layer layer) {
  if (layer.runtimeType == PictureLayer ||
      layer.runtimeType == OffsetLayer ||
      layer.runtimeType == ContainerLayer ||
      layer.runtimeType == TransformLayer ||
      layer is AnnotatedRegionLayer) {
    return true;
  }
  return switch (layer) {
    ClipRectLayer() when layer.runtimeType == ClipRectLayer =>
      layer.clipBehavior != Clip.antiAliasWithSaveLayer,
    ClipRRectLayer() when layer.runtimeType == ClipRRectLayer =>
      layer.clipBehavior != Clip.antiAliasWithSaveLayer,
    ClipPathLayer() when layer.runtimeType == ClipPathLayer =>
      layer.clipBehavior != Clip.antiAliasWithSaveLayer,
    _ => false,
  };
}

/// Replays already-recorded drawing commands; no widget paint, scene capture,
/// GPU readback or new texture is needed. Caller has checked the entire tree.
void replayLayerChildren(ContainerLayer root, Canvas canvas) {
  for (
    Layer? child = root.firstChild;
    child != null;
    child = child.nextSibling
  ) {
    _replay(child, canvas);
  }
}

void _replay(Layer layer, Canvas canvas) {
  if (layer is PictureLayer) {
    final picture = layer.picture;
    if (picture != null) canvas.drawPicture(picture);
    return;
  }
  canvas.save();
  switch (layer) {
    case TransformLayer(:final offset, :final transform):
      canvas.translate(offset.dx, offset.dy);
      if (transform != null) canvas.transform(transform.storage);
    case OffsetLayer(:final offset):
      canvas.translate(offset.dx, offset.dy);
    case ClipRectLayer(:final clipRect, :final clipBehavior):
      if (clipBehavior != Clip.none && clipRect != null) {
        canvas.clipRect(clipRect, doAntiAlias: clipBehavior != Clip.hardEdge);
      }
    case ClipRRectLayer(:final clipRRect, :final clipBehavior):
      if (clipBehavior != Clip.none && clipRRect != null) {
        canvas.clipRRect(clipRRect, doAntiAlias: clipBehavior != Clip.hardEdge);
      }
    case ClipPathLayer(:final clipPath, :final clipBehavior):
      if (clipBehavior != Clip.none && clipPath != null) {
        canvas.clipPath(clipPath, doAntiAlias: clipBehavior != Clip.hardEdge);
      }
  }
  replayLayerChildren(layer as ContainerLayer, canvas);
  canvas.restore();
}
