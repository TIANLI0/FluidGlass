import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../../gestures/drag_gesture_inspector.dart';
import '../../foundation/soft_motion.dart';

/// The haptic kinds the selection controls play.
enum SoftSelectionHaptic {
  /// Turning a control on.
  toggleOn,

  /// Turning a control off.
  toggleOff,

  /// Moving a tri-state control out of its mixed state.
  segmentTick,

  /// A slider reaching either end.
  threshold,

  /// A slider passing a step or a key point.
  tick,
}

/// Plays [kind] through the platform's haptic channel.
///
/// The platform channel has no toggle or threshold constants, so each kind
/// maps to the nearest one it does have.
void playSoftSelectionHaptic(SoftSelectionHaptic kind) {
  switch (kind) {
    case SoftSelectionHaptic.toggleOn:
    case SoftSelectionHaptic.toggleOff:
      HapticFeedback.lightImpact();
    case SoftSelectionHaptic.segmentTick:
    case SoftSelectionHaptic.tick:
      HapticFeedback.selectionClick();
    case SoftSelectionHaptic.threshold:
      HapticFeedback.mediumImpact();
  }
}

/// Extends hit testing of a small control to a [minSize] square around it,
/// the way the reference extends the touch area of anything smaller than a
/// touch target. Layout is untouched.
///
/// The extension only reaches as far as the ancestors' own bounds.
class SoftMinTouchTarget extends SingleChildRenderObjectWidget {
  const SoftMinTouchTarget({super.key, this.minSize = 48, super.child});

  final double minSize;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderMinTouchTarget(minSize);

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) {
    (renderObject as _RenderMinTouchTarget).minSize = minSize;
  }
}

class _RenderMinTouchTarget extends RenderProxyBox {
  _RenderMinTouchTarget(this.minSize);

  double minSize;

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (size.isEmpty) return false;
    final double padX = math.max(0, (minSize - size.width) / 2);
    final double padY = math.max(0, (minSize - size.height) / 2);
    final Rect area = Rect.fromLTRB(
      -padX,
      -padY,
      size.width + padX,
      size.height + padY,
    );
    if (!area.contains(position)) return false;
    // The children only accept positions on themselves; hand them the nearest
    // point inside. Events are delivered by transform, not by this position,
    // so their local positions stay exact.
    final Offset inside = Offset(
      position.dx.clamp(0.0, math.max(0.0, size.width - 0.001)),
      position.dy.clamp(0.0, math.max(0.0, size.height - 0.001)),
    );
    if (hitTestChildren(result, position: inside)) {
      result.add(BoxHitTestEntry(this, position));
      return true;
    }
    return false;
  }
}

/// The 24 square every checkbox and radio button draws in, with the
/// reference's press feedback: the whole square sinks to 0.85 the moment the
/// finger lands (no tap delay) on a (0.99, 986.96) spring, and springs back
/// when it lifts or the gesture turns into a scroll.
///
/// Wrap the control, semantics included, in a [SoftMinTouchTarget].
///
/// [builder] receives the sink scale to paint with, so nothing rebuilds while
/// it moves.
class SoftSelectionFrame extends StatefulWidget {
  const SoftSelectionFrame({
    super.key,
    required this.enabled,
    required this.onTap,
    required this.builder,
    this.size = 24,
  });

  /// Sinks when pressed. Taps only reach [onTap] while enabled.
  final bool enabled;
  final VoidCallback? onTap;
  final Widget Function(BuildContext context, ValueListenable<double> sink)
  builder;
  final double size;

  /// The scale a pressed control sinks to.
  static const double sinkScale = 0.85;

  /// The sink spring: damping 0.99, stiffness 986.96.
  static final SpringDescription sinkSpring = softSpringStiffness(
    damping: 0.99,
    stiffness: 986.96,
  );

  @override
  State<SoftSelectionFrame> createState() => _SoftSelectionFrameState();
}

class _SoftSelectionFrameState extends State<SoftSelectionFrame>
    with SingleTickerProviderStateMixin {
  late final SoftSpring _sink = SoftSpring(vsync: this, value: 1);
  bool _pressed = false;
  bool _reduceMotion = false;

  void _press(bool pressed) {
    if (_pressed == pressed) return;
    _pressed = pressed;
    final double target = pressed ? SoftSelectionFrame.sinkScale : 1;
    if (_reduceMotion) {
      _sink.snapTo(target);
    } else {
      _sink.animateTo(target, SoftSelectionFrame.sinkSpring);
    }
  }

  @override
  void didUpdateWidget(SoftSelectionFrame oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled) _press(false);
  }

  @override
  void dispose() {
    _sink.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _reduceMotion = softReduceMotion(context);
    final bool enabled = widget.enabled;
    return DragInspector(
      onDragStart: enabled ? (Offset _, Size _) => _press(true) : null,
      onDragEnd: enabled ? () => _press(false) : null,
      onDragCancel: enabled ? () => _press(false) : null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        excludeFromSemantics: true,
        onTap: enabled ? widget.onTap : null,
        child: SizedBox.square(
          dimension: widget.size,
          child: widget.builder(context, _sink),
        ),
      ),
    );
  }
}
