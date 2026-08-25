import 'package:flutter/widgets.dart';

/// Reports the pointer down, every movement and the pointer up of a drag, with
/// no touch slop.
///
/// The drag starts on the very first pointer-down and never consumes the
/// events, so a tap handler on the same node keeps working and several
/// listeners can observe the same gesture side by side.
///
/// A raw [Listener] delivers every event without entering Flutter's gesture
/// arena. A gesture recogniser would enter the arena and, being the innermost
/// competitor, win it, swallowing the taps a handler above it should receive.
class DragInspector extends StatefulWidget {
  const DragInspector({
    super.key,
    this.onDragStart,
    this.onDrag,
    this.onDragEnd,
    this.onDragCancel,
    this.behavior = HitTestBehavior.opaque,
    required this.child,
  });

  /// The pointer went down at [position], within a box of [size].
  final void Function(Offset position, Size size)? onDragStart;

  /// The pointer moved by [delta], to [position], within a box of [size].
  ///
  /// Also called once with a zero delta right after [onDragStart].
  final void Function(Offset position, Offset delta, Size size)? onDrag;

  final VoidCallback? onDragEnd;
  final VoidCallback? onDragCancel;

  final HitTestBehavior behavior;
  final Widget child;

  @override
  State<DragInspector> createState() => _DragInspectorState();
}

class _DragInspectorState extends State<DragInspector> {
  int? _pointer;

  Size get _size {
    final RenderBox? box = context.findRenderObject() as RenderBox?;
    return box != null && box.hasSize ? box.size : Size.zero;
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: widget.behavior,
      onPointerDown: (PointerDownEvent event) {
        // One sequence at a time.
        if (_pointer != null) return;
        _pointer = event.pointer;
        final Size size = _size;
        widget.onDragStart?.call(event.localPosition, size);
        widget.onDrag?.call(event.localPosition, Offset.zero, size);
      },
      onPointerMove: (PointerMoveEvent event) {
        if (_pointer != event.pointer) return;
        widget.onDrag?.call(event.localPosition, event.localDelta, _size);
      },
      onPointerUp: (PointerUpEvent event) {
        if (_pointer != event.pointer) return;
        _pointer = null;
        widget.onDragEnd?.call();
      },
      onPointerCancel: (PointerCancelEvent event) {
        if (_pointer != event.pointer) return;
        _pointer = null;
        widget.onDragCancel?.call();
      },
      child: widget.child,
    );
  }
}
