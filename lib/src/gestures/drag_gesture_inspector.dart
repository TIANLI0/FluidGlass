import 'dart:math' as math;

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
/// Staying out of the arena means arena resolution never reaches a plain
/// [Listener]: when an ancestor [Scrollable] claims the pointer, events keep
/// arriving as if nothing happened. Compose notices the equivalent through
/// `PointerInputChange.isConsumed`. Here the takeover is noticed where it
/// shows — every [Scrollable] above this one is watched while the finger is
/// down, and if any of them moves the gesture was a scroll: it ends through
/// [onDragCancel], and [onTap] does not fire.
///
/// Registering a non-competing arena member to learn about takeovers was tried
/// and reverted: when nobody claims a pointer the arena resolves by default,
/// accepting its *first* member and rejecting the rest, which a non-competing
/// member cannot tell apart from a real takeover. Since two inspectors
/// deliberately observe the same pointer here — one for the press glow, one for
/// the drag — the second was spuriously cancelled on every gesture.
///
/// Watching only tells a control it lost. A control that is *dragged along an
/// axis* — a slider's thumb, a switch's knob — must also be able to win, or a
/// list it sits in scrolls out from under the finger as soon as a sideways drag
/// drifts past the scroll's slop, and the drag is cancelled halfway. That is
/// [claimAxis]: a real competitor for drags along that axis, the way Flutter's
/// own `Slider` holds a horizontal drag recogniser. Whichever axis passes the
/// touch slop first takes the pointer. The events here still arrive with no
/// slop, so the control still answers the moment it is touched.
class DragInspector extends StatefulWidget {
  const DragInspector({
    super.key,
    this.onDragStart,
    this.onDrag,
    this.onDragEnd,
    this.onDragCancel,
    this.onTap,
    this.claimAxis,
    this.onClaim,
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

  /// The pointer lifted on the element without the gesture being taken over.
  ///
  /// The rule is Compose's `clickable`, which bottoms out in
  /// `waitForUpOrCancellation`: a press is cancelled once the pointer leaves
  /// the element's bounds — extended to a 48-pixel touch target for anything
  /// smaller — or once something else consumes it, and a cancelled press does
  /// not fire even if the finger comes back. There is no *distance* test,
  /// though, unlike Flutter's [TapGestureRecognizer], which self-rejects past
  /// [kTouchSlop]: a finger that wanders inside a control that squashes and
  /// leans under it still fires it.
  ///
  /// So sliding off a button to think better of it aborts it, a finger that
  /// scrolled a list lifting on a row selects nothing, and pressing Cancel then
  /// sliding to OK fires neither.
  final VoidCallback? onTap;

  /// Competes in the gesture arena for drags along this axis.
  ///
  /// Null, the default, stays out of the arena entirely. Set, a drag that
  /// passes the touch slop along this axis first takes the pointer away from
  /// every competitor — an enclosing list cannot scroll for the rest of it —
  /// and one that passes it across this axis first loses the pointer to that
  /// competitor, ending the gesture through [onDragCancel].
  ///
  /// Only for something that moves under a drag. A press-only control given
  /// an axis would win the arena on a tap and starve the tap handlers above.
  final Axis? claimAxis;

  /// The arena handed this gesture over: it is a drag along [claimAxis] now,
  /// and nothing else will get it.
  ///
  /// With no competitor that happens right after the pointer goes down; inside
  /// a list running the other way, only once the drag has passed the touch
  /// slop along this axis. A control reporting values should hold them until
  /// this — before it, the gesture may still turn out to be a scroll, and a
  /// value reported from its first sideways wobble would already be the
  /// caller's.
  final VoidCallback? onClaim;

  final HitTestBehavior behavior;
  final Widget child;

  @override
  State<DragInspector> createState() => _DragInspectorState();
}

/// Learning the arena's verdict for a drag recogniser, which otherwise keeps it
/// to itself.
mixin _ArenaVerdict on OneSequenceGestureRecognizer {
  void Function(int pointer)? onAccepted;
  void Function(int pointer)? onRejected;

  @override
  void acceptGesture(int pointer) {
    super.acceptGesture(pointer);
    onAccepted?.call(pointer);
  }

  @override
  void rejectGesture(int pointer) {
    super.rejectGesture(pointer);
    onRejected?.call(pointer);
  }
}

class _HorizontalClaim extends HorizontalDragGestureRecognizer
    with _ArenaVerdict {
  _HorizontalClaim({super.debugOwner});
}

class _VerticalClaim extends VerticalDragGestureRecognizer with _ArenaVerdict {
  _VerticalClaim({super.debugOwner});
}

class _DragInspectorState extends State<DragInspector> {
  /// The pointer whose movement is being reported.
  int? _pointer;

  /// Every pointer currently down on this node, in the order they arrived, so
  /// the drag can be handed to a surviving finger when the tracked one lifts —
  /// as Compose's `inspectDragGestures` does.
  final List<int> _down = <int>[];

  /// Whether this gesture can no longer be a tap: the pointer left the
  /// element, and Compose does not let a press come back from that.
  bool _tapCancelled = false;

  /// Every scrollable above this one and where it stood when the finger went
  /// down, while a gesture is in progress.
  final List<(ScrollPosition, double)> _scrolls = <(ScrollPosition, double)>[];

  /// Compose's `extendedTouchPadding`: a control smaller than a touch target
  /// counts as that large for whether the pointer is still on it.
  static const double _minimumTouchTarget = 48;

  /// The arena competitor for [DragInspector.claimAxis], or null without one.
  _ArenaVerdict? _claim;

  /// The pointer entered in the arena — the first finger of the gesture. The
  /// verdict is about this one only.
  int? _claimPointer;

  @override
  void initState() {
    super.initState();
    _syncClaim();
  }

  @override
  void didUpdateWidget(DragInspector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.claimAxis != widget.claimAxis) _syncClaim();
  }

  void _syncClaim() {
    _claim?.dispose();
    _claim = null;
    _claimPointer = null;
    final _ArenaVerdict? claim = switch (widget.claimAxis) {
      null => null,
      Axis.horizontal => _HorizontalClaim(debugOwner: this),
      Axis.vertical => _VerticalClaim(debugOwner: this),
    };
    if (claim == null) return;
    // The recogniser only has to be in the arena; every event it would report
    // already arrives here, slop-free, through the listener. A drag recogniser
    // with no callback at all declines every pointer, hence the empty one.
    (claim as DragGestureRecognizer).onStart = (DragStartDetails _) {};
    claim
      ..onAccepted = _onClaimAccepted
      ..onRejected = _onClaimRejected;
    _claim = claim;
  }

  void _onClaimAccepted(int pointer) {
    if (pointer != _claimPointer || _pointer == null) return;
    // Nothing can take the pointer from here, so a scroll above that moves now
    // is someone else's doing (a keyboard opening, a programmatic jump) and
    // not a reason to drop the drag.
    _unwatchScrolls();
    widget.onClaim?.call();
  }

  void _onClaimRejected(int pointer) {
    // A recogniser also rejects itself when its pointer lifts before it drew
    // enough distance to compete, which is not a takeover: the listener has
    // already ended the gesture by then, so the pointer is no longer down.
    if (pointer != _claimPointer || !_down.contains(pointer)) return;
    _takenOver();
  }

  bool _isOnElement(Offset position) {
    final Size size = _size;
    final double padX = math.max(0.0, (_minimumTouchTarget - size.width) / 2);
    final double padY = math.max(0.0, (_minimumTouchTarget - size.height) / 2);
    return Rect.fromLTRB(
      -padX,
      -padY,
      size.width + padX,
      size.height + padY,
    ).contains(position);
  }

  void _watchScrolls() {
    _unwatchScrolls();
    // Found without depending on them: this runs in an event handler, and the
    // widget has no business rebuilding when a scrollable does.
    ScrollableState? scrollable = context
        .findAncestorStateOfType<ScrollableState>();
    while (scrollable != null) {
      final ScrollPosition position = scrollable.position;
      if (position.hasPixels) {
        _scrolls.add((position, position.pixels));
        position.addListener(_onScrolled);
      }
      scrollable = scrollable.context
          .findAncestorStateOfType<ScrollableState>();
    }
  }

  void _unwatchScrolls() {
    for (final (ScrollPosition position, double _) in _scrolls) {
      position.removeListener(_onScrolled);
    }
    _scrolls.clear();
  }

  /// A scrollable above moved while the finger was down: the gesture was a
  /// scroll, and nothing here gets it.
  void _onScrolled() {
    for (final (ScrollPosition position, double pixels) in _scrolls) {
      if (position.hasPixels && position.pixels != pixels) {
        _takenOver();
        return;
      }
    }
  }

  void _takenOver() {
    _unwatchScrolls();
    if (_pointer == null) return;
    _down.clear();
    _pointer = null;
    _tapCancelled = true;
    widget.onDragCancel?.call();
  }

  Size get _size {
    final RenderBox? box = context.findRenderObject() as RenderBox?;
    return box != null && box.hasSize ? box.size : Size.zero;
  }

  void _forget(int pointer) {
    _down.remove(pointer);
  }

  /// Ends the drag, unless another finger is still down to take it over.
  void _endOrHandOver(int pointer, {required bool cancelled}) {
    _down.remove(pointer);

    if (_down.isNotEmpty) {
      // Hand the drag to the next finger without reporting an end: Compose
      // continues the same gesture.
      _pointer = _down.first;
      return;
    }
    _pointer = null;
    _unwatchScrolls();
    if (cancelled) {
      widget.onDragCancel?.call();
    } else {
      widget.onDragEnd?.call();
      if (!_tapCancelled) widget.onTap?.call();
    }
  }

  @override
  void dispose() {
    _claim?.dispose();
    _unwatchScrolls();
    _down.clear();
    _pointer = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // The device's touch slop, as every `GestureDetector` and `Scrollable`
    // reads it. Left at the default, this competitor waited for Flutter's 18
    // while a list on an Android phone (about 8) waited for less — and won a
    // drag that went two parts sideways to one part across.
    _claim?.gestureSettings = MediaQuery.maybeGestureSettingsOf(context);
    return Listener(
      behavior: widget.behavior,
      onPointerDown: (PointerDownEvent event) {
        _down.add(event.pointer);
        // A second finger joins the set but does not restart the drag.
        if (_pointer != null) return;
        _pointer = event.pointer;
        _tapCancelled = false;
        if (widget.onTap != null || widget.onDragCancel != null) {
          _watchScrolls();
        }
        // Entered while the pointer-down is still being dispatched: the
        // arena closes once every node on the hit path has seen it.
        final _ArenaVerdict? claim = _claim;
        if (claim != null) {
          _claimPointer = event.pointer;
          claim.addPointer(event);
        }
        final Size size = _size;
        widget.onDragStart?.call(event.localPosition, size);
        widget.onDrag?.call(event.localPosition, Offset.zero, size);
      },
      onPointerMove: (PointerMoveEvent event) {
        if (_pointer != event.pointer) return;
        // Only the tap is lost: a drag goes on following the finger wherever
        // it goes, as a slider's thumb must.
        if (!_tapCancelled && !_isOnElement(event.localPosition)) {
          _tapCancelled = true;
        }
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
