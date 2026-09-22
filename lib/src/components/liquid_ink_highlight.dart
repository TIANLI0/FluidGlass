import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'interactive_highlight.dart';

/// Install in ThemeData.splashFactory to give every Material ink control the
/// same soft press glow as the glass controls, without wrapping every button.
///
/// The glow behaves like the one on a liquid control, not like a Material
/// ripple: it comes on with the finger, **stays as long as the finger does**,
/// and **follows it** across the control. Material only tells an ink feature
/// where the pointer went down and when the tap confirmed or cancelled — and
/// it cancels the moment the finger drifts past the touch slop, which is why a
/// stock ripple dies under a finger that so much as wobbles. So this feature
/// watches the pointer itself, through the gesture binding's global route,
/// and lets go only when the finger lifts, or when the control it is on
/// starts moving under the finger (the list is scrolling, and this was never
/// a press).
class LiquidInkHighlight extends InteractiveInkFeature {
  LiquidInkHighlight({
    required super.controller,
    required super.referenceBox,
    required super.color,
    required Offset position,
    required TextDirection textDirection,
    BorderRadius borderRadius = BorderRadius.zero,
    ShapeBorder? customBorder,
    RectCallback? rectCallback,
    super.onRemoved,
  }) : _textDirection = textDirection,
       _borderRadius = borderRadius,
       _customBorder = customBorder,
       _rectCallback = rectCallback {
    _highlight = InteractiveHighlight(vsync: controller.vsync)
      ..addListener(_onHighlightChanged);
    _origin = referenceBox.localToGlobal(Offset.zero);
    _pointer = _PointerTracker.instance.claim(referenceBox, position);
    if (_pointer != null) _PointerTracker.instance.addListener(_onPointer);
    controller.addInkFeature(this);
    _highlight.handleDown(position);
  }

  static const InteractiveInkFeatureFactory splashFactory = _LiquidInkFactory();

  final TextDirection _textDirection;
  final BorderRadius _borderRadius;
  final ShapeBorder? _customBorder;
  final RectCallback? _rectCallback;

  late final InteractiveHighlight _highlight;

  /// The pointer this glow follows, or null when nothing was down when it was
  /// made (a keyboard or assistive activation).
  int? _pointer;

  /// Where the control was when the finger went down; a control that moves
  /// under a held finger is a list being scrolled.
  late Offset _origin;

  bool _released = false;

  /// Material's word that the tap completed. The finger is up by then.
  @override
  void confirm() => _release();

  /// Material's word that the tap recognizer gave up — past the touch slop,
  /// or a scroll won the arena. The finger may well still be down, and while
  /// it is, the light stays: that is the whole point. A real scroll is caught
  /// separately, by the control moving under the finger.
  @override
  void cancel() {
    if (_pointer != null && _PointerTracker.instance.isDown(_pointer!)) return;
    _release();
  }

  void _onPointer(PointerEvent event) {
    if (event.pointer != _pointer) return;
    if (event is PointerUpEvent || event is PointerCancelEvent) {
      _release();
      return;
    }
    if (event is! PointerMoveEvent) return;
    if (!referenceBox.attached) {
      _release();
      return;
    }
    if ((referenceBox.localToGlobal(Offset.zero) - _origin).distance > 1) {
      // The control moved under the finger: the list is scrolling.
      _release();
      return;
    }
    _highlight.handleMove(referenceBox.globalToLocal(event.position));
  }

  void _release() {
    if (_released) return;
    _released = true;
    if (_pointer != null) {
      _PointerTracker.instance.removeListener(_onPointer);
      _pointer = null;
    }
    _highlight.handleUp();
  }

  void _onHighlightChanged() {
    controller.markNeedsPaint();
    if (_released && _highlight.pressProgress <= 0.001) dispose();
  }

  @override
  void dispose() {
    if (_pointer != null) {
      _PointerTracker.instance.removeListener(_onPointer);
      _pointer = null;
    }
    _highlight
      ..removeListener(_onHighlightChanged)
      ..dispose();
    super.dispose();
  }

  @override
  void paintFeature(Canvas canvas, Matrix4 transform) {
    final double opacity = _highlight.pressProgress;
    if (opacity <= 0) return;
    final Rect rect = _rectCallback?.call() ?? Offset.zero & referenceBox.size;
    final Offset position = _highlight.glowPosition(rect.size);
    canvas.save();
    canvas.transform(transform.storage);
    if (_customBorder != null) {
      canvas.clipPath(
        _customBorder.getOuterPath(rect, textDirection: _textDirection),
      );
    } else {
      canvas.clipRRect(_borderRadius.toRRect(rect));
    }
    // A flat wash over the whole control, then the glow under the finger.
    canvas.drawRect(
      rect,
      Paint()..color = color.withValues(alpha: color.a * opacity * 0.35),
    );
    canvas.drawCircle(
      position,
      rect.longestSide,
      Paint()
        ..shader =
            RadialGradient(
              colors: <Color>[
                color.withValues(alpha: color.a * opacity),
                color.withValues(alpha: 0),
              ],
            ).createShader(
              Rect.fromCircle(
                center: position,
                radius: rect.shortestSide * 1.5,
              ),
            ),
    );
    canvas.restore();
  }
}

/// Every pointer currently down, and where it is — read off the gesture
/// binding's global route, so an ink feature can find the finger that made
/// it and follow it after Material has stopped reporting.
///
/// The global route is registered once, on first use, and never removed: it
/// is one map update per pointer event, and an app that installed the splash
/// factory presses things for as long as it runs.
class _PointerTracker {
  _PointerTracker._();

  static final _PointerTracker instance = _PointerTracker._();

  final Map<int, Offset> _down = <int, Offset>{};
  final List<void Function(PointerEvent event)> _listeners =
      <void Function(PointerEvent event)>[];
  bool _routed = false;

  void _ensureRoute() {
    if (_routed) return;
    _routed = true;
    GestureBinding.instance.pointerRouter.addGlobalRoute(_handle);
  }

  void _handle(PointerEvent event) {
    if (event is PointerDownEvent) {
      _down[event.pointer] = event.position;
    } else if (event is PointerMoveEvent) {
      if (!_down.containsKey(event.pointer)) return;
      _down[event.pointer] = event.position;
    } else if (event is PointerUpEvent || event is PointerCancelEvent) {
      if (_down.remove(event.pointer) == null) return;
    } else {
      return;
    }
    // A listener may remove itself while being told about a lift.
    for (final void Function(PointerEvent event) listener
        in List<void Function(PointerEvent event)>.of(_listeners)) {
      listener(event);
    }
  }

  bool isDown(int pointer) => _down.containsKey(pointer);

  void addListener(void Function(PointerEvent event) listener) =>
      _listeners.add(listener);

  void removeListener(void Function(PointerEvent event) listener) =>
      _listeners.remove(listener);

  /// The pointer that most plausibly made a splash at [local] on [box]: the
  /// one currently down whose position is nearest to it, in the box's own
  /// coordinates. Null when no pointer is down.
  int? claim(RenderBox box, Offset local) {
    _ensureRoute();
    if (_down.isEmpty || !box.attached || !box.hasSize) return null;
    int? best;
    double bestDistance = double.infinity;
    for (final MapEntry<int, Offset> entry in _down.entries) {
      final double d = (box.globalToLocal(entry.value) - local).distance;
      if (d < bestDistance) {
        bestDistance = d;
        best = entry.key;
      }
    }
    return best;
  }
}

class _LiquidInkFactory extends InteractiveInkFeatureFactory {
  const _LiquidInkFactory();
  @override
  InteractiveInkFeature create({
    required MaterialInkController controller,
    required RenderBox referenceBox,
    required Offset position,
    required Color color,
    required TextDirection textDirection,
    bool containedInkWell = false,
    RectCallback? rectCallback,
    BorderRadius? borderRadius,
    ShapeBorder? customBorder,
    double? radius,
    VoidCallback? onRemoved,
  }) => LiquidInkHighlight(
    controller: controller,
    referenceBox: referenceBox,
    position: position,
    color: color,
    textDirection: textDirection,
    rectCallback: rectCallback,
    borderRadius: borderRadius ?? BorderRadius.zero,
    customBorder: customBorder,
    onRemoved: onRemoved,
  );
}
