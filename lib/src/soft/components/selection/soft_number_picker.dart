import 'dart:math' as math;
// Derived from coui17 basic/NumberPicker.kt, Apache-2.0.
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../foundation/soft_motion.dart';
import '../../foundation/soft_theme.dart';

abstract final class SoftNumberPickerDefaults {
  static const double itemHeight = 45;
  static const int visibleItemCount = 3;
}

/// A snapping number wheel. The selected item is 20px and neighbouring
/// items blend to the normal colour at 80% scale, as in the reference.
class SoftNumberPicker extends StatefulWidget {
  const SoftNumberPicker({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.max = 10,
    this.enabled = true,
    this.wrapAround = false,
    this.visibleItemCount = 3,
    this.itemHeight = 45,
    this.label,
    this.semanticLabel,
    this.textStyle,
    this.selectedColor,
    this.unselectedColor,
    this.haptics = true,
  }) : assert(min <= max),
       assert(itemHeight > 0),
       assert(visibleItemCount >= 3 && visibleItemCount % 2 == 1);

  final int value, min, max, visibleItemCount;
  final ValueChanged<int>? onChanged;
  final bool enabled, wrapAround, haptics;
  final double itemHeight;
  final String Function(int)? label;
  final String? semanticLabel;
  final TextStyle? textStyle;
  final Color? selectedColor, unselectedColor;

  @override
  State<SoftNumberPicker> createState() => _SoftNumberPickerState();
}

class _SoftNumberPickerState extends State<SoftNumberPicker>
    with SingleTickerProviderStateMixin {
  late final AnimationController _position = AnimationController.unbounded(
    vsync: this,
    value: (widget.value.clamp(widget.min, widget.max) - widget.min).toDouble(),
  )..addListener(_tick);
  bool _userScrolling = false;
  int _generation = 0;
  int _lastHaptic = 0;
  bool get _active => widget.enabled && widget.onChanged != null;
  int get _count => widget.max - widget.min + 1;
  int get _index => widget.value.clamp(widget.min, widget.max) - widget.min;
  String _label(int value) => widget.label?.call(value) ?? '$value';
  int _rounded(double value) => (value + 0.5).floor(); // Kotlin fastRoundToInt.
  int _item(int value) =>
      widget.wrapAround ? value % _count : value.clamp(0, _count - 1);
  double _bound(double value) =>
      widget.wrapAround ? value : value.clamp(0, _count - 1).toDouble();

  void _tick() {
    final int next = _item(_rounded(_position.value));
    if (next != _lastHaptic && _userScrolling && widget.haptics) {
      HapticFeedback.selectionClick();
    }
    _lastHaptic = next;
  }

  @override
  void didUpdateWidget(SoftNumberPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value ||
        widget.min != oldWidget.min ||
        widget.max != oldWidget.max ||
        widget.wrapAround != oldWidget.wrapAround ||
        !_active) {
      _generation++;
      _userScrolling = false;
      _position.stop();
      _position.value = _index.toDouble();
    }
  }

  void _start() {
    _generation++;
    _position.stop();
    _lastHaptic = _item(_rounded(_position.value));
    _userScrolling = true;
  }

  Future<void> _finish(double velocity) async {
    final int generation = ++_generation;
    try {
      if (!softReduceMotion(context)) {
        if (velocity.abs() > 0.1) {
          await _position
              .animateWith(
                _PickerDecay(
                  _position.value,
                  velocity,
                  minimum: widget.wrapAround ? double.negativeInfinity : 0,
                  maximum: widget.wrapAround
                      ? double.infinity
                      : (_count - 1).toDouble(),
                ),
              )
              .orCancel;
        }
        if (!mounted || generation != _generation) return;
        await _position
            .animateWith(
              SpringSimulation(
                SpringDescription(mass: 1, stiffness: 400, damping: 40),
                _position.value,
                _bound(_rounded(_position.value).toDouble()),
                0,
                tolerance: const Tolerance(distance: 0.01, velocity: 0.625),
              ),
            )
            .orCancel;
      }
      if (!mounted || generation != _generation) return;
      final int next = widget.min + _item(_rounded(_position.value));
      _userScrolling = false;
      if (next != widget.value) widget.onChanged?.call(next);
      // Same controlled-state contract as the reference: the caller commits.
      if (mounted && generation == _generation) {
        _position.value = _index.toDouble();
      }
    } on TickerCanceled {
      // A new drag, external value or disposal superseded this fling.
    }
  }

  void _step(int step) {
    if (!_active) return;
    _start();
    _position.value = _bound(_position.value + step);
    _finish(0);
  }

  @override
  void dispose() {
    _generation++;
    _position.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final SoftThemeData theme = SoftTheme.of(context);
    final Color focus = widget.enabled
        ? (widget.selectedColor ?? theme.colors.onSurface)
        : theme.colors.disabledOnSecondary;
    final Color normal = widget.enabled
        ? (widget.unselectedColor ?? theme.colors.onSurfaceVariantActions)
        : theme.colors.disabledOnSecondary;
    final int value = widget.value.clamp(widget.min, widget.max);
    return Semantics(
      label: widget.semanticLabel,
      value: _label(value),
      enabled: _active,
      increasedValue: _active && (widget.wrapAround || value < widget.max)
          ? _label(value == widget.max ? widget.min : value + 1)
          : null,
      decreasedValue: _active && (widget.wrapAround || value > widget.min)
          ? _label(value == widget.min ? widget.max : value - 1)
          : null,
      onIncrease: _active && (widget.wrapAround || value < widget.max)
          ? () => _step(1)
          : null,
      onDecrease: _active && (widget.wrapAround || value > widget.min)
          ? () => _step(-1)
          : null,
      child: ExcludeSemantics(
        child: FocusableActionDetector(
          enabled: _active,
          shortcuts: const <ShortcutActivator, Intent>{
            SingleActivator(LogicalKeyboardKey.arrowUp): _WheelIntent(-1),
            SingleActivator(LogicalKeyboardKey.arrowDown): _WheelIntent(1),
          },
          actions: <Type, Action<Intent>>{
            _WheelIntent: CallbackAction<_WheelIntent>(
              onInvoke: (intent) {
                _step(intent.step);
                return null;
              },
            ),
          },
          child: RepaintBoundary(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onVerticalDragStart: _active ? (_) => _start() : null,
              onVerticalDragUpdate: _active
                  ? (details) {
                      _position.value = _bound(
                        _position.value - details.delta.dy / widget.itemHeight,
                      );
                    }
                  : null,
              onVerticalDragEnd: _active
                  ? (details) => _finish(
                      -(details.primaryVelocity ?? 0) / widget.itemHeight,
                    )
                  : null,
              onVerticalDragCancel: _active ? () => _finish(0) : null,
              child: SizedBox(
                height: widget.itemHeight * widget.visibleItemCount,
                width: double.infinity,
                child: ClipRect(
                  child: AnimatedBuilder(
                    animation: _position,
                    builder: (context, _) {
                      final int rounded = _rounded(_position.value);
                      final int half = widget.visibleItemCount ~/ 2;
                      return Stack(
                        alignment: Alignment.center,
                        clipBehavior: Clip.none,
                        children: <Widget>[
                          for (int i = -half - 1; i <= half + 1; i++)
                            if (widget.wrapAround ||
                                (rounded + i >= 0 && rounded + i < _count))
                              Transform.translate(
                                offset: Offset(
                                  0,
                                  (rounded + i - _position.value) *
                                      widget.itemHeight,
                                ),
                                child: Transform.scale(
                                  scale:
                                      1 -
                                      0.2 *
                                          ((rounded + i - _position.value)
                                                      .abs() *
                                                  2)
                                              .clamp(0, 1),
                                  child: Text(
                                    _label(widget.min + _item(rounded + i)),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                    style:
                                        (widget.textStyle ??
                                                theme.textStyles.title3)
                                            .copyWith(
                                              fontWeight:
                                                  widget
                                                      .textStyle
                                                      ?.fontWeight ??
                                                  FontWeight.w500,
                                              color: Color.lerp(
                                                focus,
                                                normal,
                                                ((rounded + i - _position.value)
                                                            .abs() *
                                                        2)
                                                    .clamp(0, 1),
                                              ),
                                            ),
                                  ),
                                ),
                              ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Compose exponentialDecay(frictionMultiplier = 2): friction = -4.2 * 2,
/// velocity threshold 0.1. The integer snap is a separate critical spring.
class _PickerDecay extends Simulation {
  _PickerDecay(
    this.start,
    this.velocity, {
    required this.minimum,
    required this.maximum,
  }) {
    duration = velocity.abs() <= 0.1
        ? 0
        : math.log(0.1 / velocity.abs()) / friction;
    final double end = start - velocity / friction;
    final double bound = end.clamp(minimum, maximum);
    if (bound != end) {
      final double ratio = 1 + friction * (bound - start) / velocity;
      if (ratio > 0) duration = math.min(duration, math.log(ratio) / friction);
    }
  }
  static const double friction = -8.4;
  final double start, velocity, minimum, maximum;
  late double duration;
  @override
  double x(double time) =>
      (start +
              velocity /
                  friction *
                  (math.exp(friction * math.min(time, duration)) - 1))
          .clamp(minimum, maximum);
  @override
  double dx(double time) =>
      velocity * math.exp(friction * math.min(time, duration));
  @override
  bool isDone(double time) => time >= duration;
}

class _WheelIntent extends Intent {
  const _WheelIntent(this.step);
  final int step;
}
