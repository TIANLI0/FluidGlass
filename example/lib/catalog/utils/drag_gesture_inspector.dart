import 'package:flutter/gestures.dart';
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
///
/// Staying out of the arena has one known gap: arena resolution never reaches a
/// plain [Listener], so when an ancestor — a [Scrollable], say — claims the
/// pointer, events keep arriving as if nothing happened, and the press does not
/// release until the finger lifts. Compose notices the equivalent through
/// `PointerInputChange.isConsumed`.
///
/// Registering a non-competing arena member to learn about takeovers was tried
/// and reverted: when nobody claims a pointer the arena resolves by default,
/// accepting its *first* member and rejecting the rest, which a non-competing
/// member cannot tell apart from a real takeover. Since two inspectors
/// deliberately observe the same pointer here — one for the press glow, one for
/// the drag — the second was spuriously cancelled on every gesture. No catalog
/// screen currently puts one of these inside a scrollable.
class DragInspector extends StatefulWidget {
  const DragInspector({
    super.key,
    this.onDragStart,
    this.onDrag,
    this.onDragEnd,
    this.onDragCancel,
    this.onTap,
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

  /// The pointer lifted without the gesture being taken over.
  ///
  /// Fires however far the pointer travelled. Compose's `clickable` bottoms out
  /// in `waitForUpOrCancellation`, which only fails when another node consumes
  /// the event — there is no distance test — whereas Flutter's
  /// [TapGestureRecognizer] self-rejects past [kTouchSlop]. On a component whose
  /// whole point is that it slides under your finger, that difference is the
  /// gap between a button that always fires and one that silently does not.
  final VoidCallback? onTap;

  final HitTestBehavior behavior;
  final Widget child;

  @override
  State<DragInspector> createState() => _DragInspectorState();
}

class _DragInspectorState extends State<DragInspector> {
  /// The pointer whose movement is being reported.
  int? _pointer;

  /// Every pointer currently down on this node, in the order they arrived, so
  /// the drag can be handed to a surviving finger when the tracked one lifts —
  /// as Compose's `inspectDragGestures` does.
  final List<int> _down = <int>[];

  /// Where each pointer last was, so a handover can measure its delta from the
  /// new finger's own position rather than jumping by the gap between fingers.
  final Map<int, Offset> _lastPosition = <int, Offset>{};

  Size get _size {
    final RenderBox? box = context.findRenderObject() as RenderBox?;
    return box != null && box.hasSize ? box.size : Size.zero;
  }

  void _forget(int pointer) {
    _down.remove(pointer);
    _lastPosition.remove(pointer);
  }

  /// Ends the drag, unless another finger is still down to take it over.
  void _endOrHandOver(int pointer, {required bool cancelled}) {
    _down.remove(pointer);
    _lastPosition.remove(pointer);

    if (_down.isNotEmpty) {
      // Hand the drag to the next finger without reporting an end: Compose
      // continues the same gesture.
      _pointer = _down.first;
      return;
    }
    _pointer = null;
    if (cancelled) {
      widget.onDragCancel?.call();
    } else {
      widget.onDragEnd?.call();
      widget.onTap?.call();
    }
  }

  @override
  void dispose() {
    _down.clear();
    _lastPosition.clear();
    _pointer = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: widget.behavior,
      onPointerDown: (PointerDownEvent event) {
        _down.add(event.pointer);
        _lastPosition[event.pointer] = event.localPosition;
        // A second finger joins the set but does not restart the drag.
        if (_pointer != null) return;
        _pointer = event.pointer;
        final Size size = _size;
        widget.onDragStart?.call(event.localPosition, size);
        widget.onDrag?.call(event.localPosition, Offset.zero, size);
      },
      onPointerMove: (PointerMoveEvent event) {
        _lastPosition[event.pointer] = event.localPosition;
        if (_pointer != event.pointer) return;
        widget.onDrag?.call(event.localPosition, event.localDelta, _size);
      },
      onPointerUp: (PointerUpEvent event) {
        if (!_down.contains(event.pointer)) return;
        if (_pointer != event.pointer) {
          _forget(event.pointer);
          return;
        }
        _endOrHandOver(event.pointer, cancelled: false);
      },
      onPointerCancel: (PointerCancelEvent event) {
        if (!_down.contains(event.pointer)) return;
        if (_pointer != event.pointer) {
          _forget(event.pointer);
          return;
        }
        _endOrHandOver(event.pointer, cancelled: true);
      },
      child: widget.child,
    );
  }
}
