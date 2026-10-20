import 'package:flutter/widgets.dart';

import '../../foundation/soft_motion.dart';
import '../../foundation/soft_pressable.dart';
import '../../foundation/soft_squircle.dart';
import '../../foundation/soft_theme.dart';

/// The card defaults.
abstract final class SoftCardDefaults {
  /// 17 smooth corners.
  static const double cornerRadius = 17;

  /// The page inset a card sits at.
  static const double horizontalInset = 16;
}

/// A row's position inside its card group: the rounded outer edges of a
/// group each get 2 extra padding.
enum SoftCardListPosition {
  /// Not in a group.
  none,

  /// The first of several rows.
  head,

  /// A row with siblings on both sides.
  middle,

  /// The last of several rows.
  tail,

  /// The only row.
  full;

  /// The padding each rounded outer edge adds.
  static const double headOrTailPadding = 2;

  double get extraTop => this == head || this == full ? headOrTailPadding : 0;

  double get extraBottom =>
      this == tail || this == full ? headOrTailPadding : 0;

  /// The position of row [index] of [count].
  static SoftCardListPosition of(int index, int count) {
    if (count <= 0 || index < 0 || index >= count) return none;
    if (count == 1) return full;
    if (index == 0) return head;
    if (index == count - 1) return tail;
    return middle;
  }
}

/// A card: a smooth-cornered surface (17 corners, the theme's
/// `surfaceContainer`) holding [child].
///
/// With [onTap] or [onLongPress] it is pressable: the fill animates towards
/// `surfaceContainerHigh` on a critically damped spring, and a quick tap
/// still drives it to 70 % before it fades — or, with
/// [SoftPressFeedback.sink], the card sinks instead.
class SoftCard extends StatefulWidget {
  const SoftCard({
    super.key,
    required this.child,
    this.cornerRadius = SoftCardDefaults.cornerRadius,
    this.padding = EdgeInsets.zero,
    this.color,
    this.pressedColor,
    this.onTap,
    this.onLongPress,
    this.feedback = SoftPressFeedback.tint,
    this.holdDown = false,
  });

  final Widget child;
  final double cornerRadius;
  final EdgeInsetsGeometry padding;

  /// The fill; the theme's `surfaceContainer` by default.
  final Color? color;

  /// The pressed fill; the theme's `surfaceContainerHigh` by default.
  final Color? pressedColor;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final SoftPressFeedback feedback;

  /// Keeps the card pressed after the finger lifts.
  final bool holdDown;

  @override
  State<SoftCard> createState() => _SoftCardState();
}

class _SoftCardState extends State<SoftCard>
    with SingleTickerProviderStateMixin {
  late final SoftSpring _tint = SoftSpring(vsync: this);
  bool _pressed = false;

  bool get _clickable => widget.onTap != null || widget.onLongPress != null;

  @override
  void didUpdateWidget(SoftCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.holdDown != widget.holdDown) _sync();
  }

  @override
  void dispose() {
    _tint.dispose();
    super.dispose();
  }

  Future<void> _sync() async {
    if (widget.feedback != SoftPressFeedback.tint) {
      _tint.snapTo(0);
      return;
    }
    if (_pressed || widget.holdDown) {
      await _tint.animateTo(1, SoftMotion.stateLayer);
      return;
    }
    if (_tint.value <= 0) return;
    if (_tint.value < 0.7) {
      // Keep pressing in until the tint is clearly visible.
      await _tint
          .animateTo(1, SoftMotion.stateLayer)
          .orCancel
          .catchError((_) {});
      if (!mounted || _pressed || widget.holdDown) return;
    }
    _tint.animateTo(0, SoftMotion.stateLayer);
  }

  void _setPressed(bool value) {
    if (_pressed == value) return;
    _pressed = value;
    _sync();
  }

  @override
  Widget build(BuildContext context) {
    final SoftThemeData theme = SoftTheme.of(context);
    final Color color = widget.color ?? theme.colors.surfaceContainer;
    final Color pressed =
        widget.pressedColor ?? theme.colors.surfaceContainerHigh;
    final BorderRadius radius = BorderRadius.circular(widget.cornerRadius);
    Widget content = Padding(padding: widget.padding, child: widget.child);
    content = AnimatedBuilder(
      animation: _tint,
      builder: (BuildContext context, Widget? child) {
        final double t = _tint.value.clamp(0.0, 1.0);
        return DecoratedBox(
          decoration: ShapeDecoration(
            color: Color.lerp(color, pressed, t),
            shape: SoftSquircleBorder(
              radius: radius,
              smooth: theme.smoothCorners,
            ),
          ),
          child: child,
        );
      },
      child: ClipPath(
        clipper: ShapeBorderClipper(
          shape: SoftSquircleBorder(
            radius: radius,
            smooth: theme.smoothCorners,
          ),
        ),
        child: content,
      ),
    );
    if (!_clickable) return content;
    return SoftPressable(
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      feedback: widget.feedback == SoftPressFeedback.sink
          ? SoftPressFeedback.sink
          : SoftPressFeedback.none,
      borderRadius: radius,
      onPressedChanged: _setPressed,
      child: content,
    );
  }
}
