import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'interactive_highlight.dart';

/// Install in ThemeData.splashFactory to give every Material ink control the
/// same soft press glow as the glass controls, without wrapping every button.
///
/// The glow behaves like the one on a liquid control, not like a Material
/// ripple: it comes on with the finger, **stays as long as the finger does**,
/// and **follows it** across the control.
///
/// Material cannot tell it any of that. An ink feature is told where the
/// pointer went down and, later, that the tap confirmed or cancelled — and the
/// cancel arrives the moment the finger drifts past the touch slop, which is
/// why a stock ripple dies under a finger that so much as wobbles. So this
/// feature watches the pointer itself, through the gesture binding's global
/// route, and lets go only when the finger lifts or when the control travels
/// out from under it (the list is scrolling, and this was never a press).
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
    // Whether the tracker was already watching when this glow was made. The
    // first gesture of an app's life is the one that starts it watching, so
    // that gesture's down event is already gone — and its glow has to adopt a
    // finger from the first move rather than conclude there is none.
    final bool wasWatching = _PointerTracker.instance.isWatching;
    _PointerTracker.instance.addListener(_onPointer);
    _pointer = _PointerTracker.instance.claim(referenceBox, position);
    _awaitingAdoption = !wasWatching && _pointer == null;
    controller.addInkFeature(this);
    _highlight.handleDown(position);
  }

  static const InteractiveInkFeatureFactory splashFactory = _LiquidInkFactory();

  /// How far the control may drift under a held finger before the press is
  /// read as a scroll rather than a press.
  ///
  /// Not zero, and not one pixel either. A page still finishing its entrance,
  /// a list settling out of a fling, a keyboard sliding in — each moves a
  /// control a little without anybody scrolling anything, and a hair trigger
  /// here puts the light out for what the reader experiences as no reason at
  /// all. A scroll travels much further than this within a frame or two.
  static const double _scrollSlop = 12;

  final TextDirection _textDirection;
  final BorderRadius _borderRadius;
  final ShapeBorder? _customBorder;
  final RectCallback? _rectCallback;

  late final InteractiveHighlight _highlight;

  /// The pointer this glow follows, or null when there is none to follow yet.
  int? _pointer;

  /// Waiting to adopt a finger that was already down before the tracker was
  /// watching. Until one arrives, Material's cancel is not to be believed.
  bool _awaitingAdoption = false;

  /// Where the control was when the finger went down.
  late Offset _origin;

  bool _released = false;
  bool _disposed = false;
  bool _disposeScheduled = false;

  /// Material's word that the tap completed. The finger is up by then.
  @override
  void confirm() => _release();

  /// Material's word that the tap recognizer gave up — past the touch slop, or
  /// a scroll won the arena. The finger may well still be down, and while it
  /// is, the light stays: that is the whole point.
  @override
  void cancel() {
    if (_pointer != null && _PointerTracker.instance.isDown(_pointer!)) return;
    if (_awaitingAdoption) return;
    _release();
  }

  void _onPointer(PointerEvent event) {
    if (_pointer == null) {
      if (event is PointerMoveEvent && _isOver(event.position)) {
        _pointer = event.pointer;
        _awaitingAdoption = false;
      } else if (event is PointerUpEvent || event is PointerCancelEvent) {
        // No finger of ours to follow and one has just left the screen; with
        // nothing else able to end this glow, end it here.
        _release();
        return;
      } else {
        return;
      }
    }
    if (event.pointer != _pointer) return;
    if (event is PointerUpEvent || event is PointerCancelEvent) {
      _release();
      return;
    }
    if (event is! PointerMoveEvent) return;
    if (!referenceBox.attached || !referenceBox.hasSize) {
      _release();
      return;
    }
    if ((referenceBox.localToGlobal(Offset.zero) - _origin).distance >
        _scrollSlop) {
      _release();
      return;
    }
    _highlight.handleMove(referenceBox.globalToLocal(event.position));
  }

  /// Whether [global] is inside the control this glow belongs to.
  bool _isOver(Offset global) {
    if (!referenceBox.attached || !referenceBox.hasSize) return false;
    return (Offset.zero & referenceBox.size).contains(
      referenceBox.globalToLocal(global),
    );
  }

  void _release() {
    if (_released) return;
    _released = true;
    _pointer = null;
    _awaitingAdoption = false;
    _PointerTracker.instance.removeListener(_onPointer);
    _highlight.handleUp();
  }

  void _onHighlightChanged() {
    controller.markNeedsPaint();
    if (!_released || _disposeScheduled) return;
    if (_highlight.pressProgress > 0.001) return;
    // **Not synchronously.** This runs inside the spring's own
    // `notifyListeners`, and disposing the spring from there mutates the
    // listener list being walked — which `ChangeNotifier` asserts on.
    _disposeScheduled = true;
    scheduleMicrotask(() {
      if (!_disposed) dispose();
    });
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _pointer = null;
    _PointerTracker.instance.removeListener(_onPointer);
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
    // At least as far as the gradient reaches, one and a half short sides
    // out. A circle of the long side alone stopped short of that on anything
    // squarer than 3:2 — a hard arc across a square button pressed near a
    // corner, where the glow was still a third on.
    canvas.drawCircle(
      position,
      math.max(rect.longestSide, rect.shortestSide * 1.5),
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
/// binding's global route, so an ink feature can find the finger that made it
/// and follow it after Material has stopped reporting.
///
/// The route is registered on first use and never removed: it is one map
/// update per pointer event, and an app that installed the splash factory
/// presses things for as long as it runs.
class _PointerTracker {
  _PointerTracker._();

  static final _PointerTracker instance = _PointerTracker._();

  final Map<int, Offset> _down = <int, Offset>{};
  final List<void Function(PointerEvent event)> _listeners =
      <void Function(PointerEvent event)>[];
  bool _watching = false;

  /// Whether the global route is already in place, and so whether [_down] can
  /// be trusted to know about a finger that is on the screen right now.
  bool get isWatching => _watching;

  void _ensureRoute() {
    if (_watching) return;
    _watching = true;
    GestureBinding.instance.pointerRouter.addGlobalRoute(_handle);
  }

  void _handle(PointerEvent event) {
    if (event is PointerDownEvent) {
      _down[event.pointer] = event.position;
    } else if (event is PointerMoveEvent) {
      if (!_down.containsKey(event.pointer)) return;
      _down[event.pointer] = event.position;
    } else if (event is PointerUpEvent || event is PointerCancelEvent) {
      _down.remove(event.pointer);
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

  void addListener(void Function(PointerEvent event) listener) {
    _ensureRoute();
    _listeners.add(listener);
  }

  void removeListener(void Function(PointerEvent event) listener) =>
      _listeners.remove(listener);

  /// The pointer that most plausibly made a splash at [local] on [box]: the
  /// one currently down whose position is nearest to it, in the box's own
  /// coordinates. Null when no pointer is down.
  int? claim(RenderBox box, Offset local) {
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
