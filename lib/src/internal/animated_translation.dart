import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Moves a stable subtree on animation ticks without rebuilding or laying it out.
class AnimatedTranslation extends SingleChildRenderObjectWidget {
  const AnimatedTranslation({
    super.key,
    required this.listenable,
    required this.offset,
    required super.child,
  });

  final Listenable listenable;
  final Offset Function() offset;

  @override
  RenderAnimatedTranslation createRenderObject(BuildContext context) =>
      RenderAnimatedTranslation(listenable, offset);

  @override
  void updateRenderObject(
    BuildContext context,
    RenderAnimatedTranslation renderObject,
  ) => renderObject.update(listenable, offset);
}

class RenderAnimatedTranslation extends RenderTransform {
  RenderAnimatedTranslation(this._listenable, this._offset)
    : super(transform: Matrix4.identity());

  Listenable _listenable;
  Offset Function() _offset;

  void update(Listenable listenable, Offset Function() offset) {
    if (_listenable != listenable) {
      if (attached) _listenable.removeListener(_syncTransform);
      _listenable = listenable;
      if (attached) _listenable.addListener(_syncTransform);
    }
    _offset = offset;
    _syncTransform();
  }

  void _syncTransform() {
    final Offset offset = _offset();
    transform = Matrix4.translationValues(offset.dx, offset.dy, 0);
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _listenable.addListener(_syncTransform);
    _syncTransform();
  }

  @override
  void detach() {
    _listenable.removeListener(_syncTransform);
    super.detach();
  }
}
