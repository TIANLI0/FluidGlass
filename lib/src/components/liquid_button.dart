import 'package:flutter/material.dart';

import '../../fluid_glass.dart';
import '../internal/control_focus.dart';
import '../internal/drag_deformation.dart';

/// A capsule of liquid glass that squashes and slides under the finger.
class LiquidButton extends StatefulWidget {
  const LiquidButton({
    super.key,
    required this.onPressed,
    required this.backdrop,
    this.isInteractive = true,
    this.tint,
    this.surfaceColor,
    this.height = 48,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
    this.spacing = 8,
    this.child,
    this.children = const <Widget>[],
    this.tooltip,
    this.focusNode,
    this.autofocus = false,
  }) : assert(
         child == null || children.length == 0,
         'Supply child or children, not both.',
       ),
       assert(height > 0 && height < double.infinity),
       assert(spacing >= 0 && spacing < double.infinity);

  /// Null disables the button: no gestures, no press deformation, no highlight.
  ///
  /// The *appearance* of a disabled button is the caller's — dim the
  /// [children], as a disabled icon or label would be dimmed anywhere else. A
  /// disabled button is also inert rather than absorbing: a tap over it reaches
  /// whatever is behind, which is what a disabled control does elsewhere in
  /// Flutter.
  final VoidCallback? onPressed;

  final Backdrop backdrop;
  final bool isInteractive;
  final Color? tint;
  final Color? surfaceColor;

  /// The button's minimum height. Content can grow for large text, within the
  /// parent's constraints. Its width comes from [child]/[children] and [padding].
  ///
  /// A square button — [height] with children that measure the same across —
  /// is a circle, since the shape is a capsule.
  final double height;

  /// Inset around [children]. Pass [EdgeInsets.zero] for an icon-only button
  /// that should stay as wide as it is tall.
  final EdgeInsetsGeometry padding;

  /// The gap between [children].
  final double spacing;

  final List<Widget> children;

  /// Content for a single label or icon, constrained to the available width.
  /// Long labels can wrap. Use [children] for an explicitly laid-out spaced row.
  final Widget? child;

  /// A hover hint and accessible description, useful for icon buttons.
  final String? tooltip;
  final FocusNode? focusNode;
  final bool autofocus;

  @override
  State<LiquidButton> createState() => _LiquidButtonState();
}

class _LiquidButtonState extends State<LiquidButton>
    with TickerProviderStateMixin {
  late final InteractiveHighlight _interactiveHighlight = InteractiveHighlight(
    vsync: this,
  );

  @override
  void dispose() {
    _interactiveHighlight.dispose();
    super.dispose();
  }

  void _layerBlock(GlassLayer layer) => applyDragDeformation(
    layer,
    offset: _interactiveHighlight.offset,
    pressProgress: _interactiveHighlight.pressProgress,
  );

  void _drawSurface(Canvas canvas, Size size) {
    final Rect rect = Offset.zero & size;
    final Color? tint = widget.tint;
    if (tint != null) {
      canvas.drawRect(
        rect,
        Paint()
          ..color = tint
          ..blendMode = BlendMode.hue,
      );
      canvas.drawRect(rect, Paint()..color = tint.withValues(alpha: 0.75));
    }
    final Color? surfaceColor = widget.surfaceColor;
    if (surfaceColor != null) {
      canvas.drawRect(rect, Paint()..color = surfaceColor);
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget content = ConstrainedBox(
      constraints: BoxConstraints(minHeight: widget.height),
      child: Padding(
        padding: widget.padding,
        child: widget.child != null
            ? Center(widthFactor: 1, heightFactor: 1, child: widget.child)
            : Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                spacing: widget.spacing,
                children: widget.children,
              ),
      ),
    );

    final VoidCallback? onPressed = widget.onPressed;
    final bool isEnabled = onPressed != null;

    if (widget.isInteractive) {
      // The tap is reported by the same slop-free inspector that drives the
      // press highlight, so pushing the glass around under a finger and then
      // releasing still counts as a press, as it does in Compose. A
      // GestureDetector would enter the arena and self-reject past kTouchSlop.
      //
      // Wrapped whether or not the button is enabled, so enabling it keeps
      // the tree it had. Leaving a disabled button unwrapped rebuilt its
      // children from scratch on every change, and a button disabled while
      // pressed never heard the finger lift and stayed swollen and lit.
      //
      // Disabled, it ignores pointers, so it is inert rather than absorbing: a
      // tap reaches whatever is behind it. A finger already down keeps the
      // route it was given, so it is still heard lifting.
      content = IgnorePointer(
        ignoring: !isEnabled,
        child: _interactiveHighlight.wrapOverlay(
          child: _interactiveHighlight.wrapGestures(
            child: content,
            onTap: onPressed,
            enabled: isEnabled,
          ),
        ),
      );
    } else if (!isEnabled) {
      // Nothing wrapped: no InkWell that would swallow the tap without acting
      // on it.
    } else {
      content = Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onPressed,
          canRequestFocus: false,
          child: content,
        ),
      );
    }

    // A button, as a screen reader should hear it, disabled or not. The slop-free
    // inspector reports taps to nothing but the pointer, so the action is given
    // here; an InkWell brings its own.
    content = Semantics(
      button: true,
      enabled: isEnabled,
      tooltip: widget.tooltip,
      onTap: widget.isInteractive && isEnabled ? onPressed : null,
      child: content,
    );
    content = ControlFocus(
      enabled: isEnabled,
      focusNode: widget.focusNode,
      autofocus: widget.autofocus,
      onActivate: onPressed,
      child: content,
    );
    if (widget.tooltip != null) {
      content = IgnorePointer(
        ignoring: !isEnabled,
        child: Tooltip(
          message: widget.tooltip!,
          excludeFromSemantics: true,
          child: content,
        ),
      );
    }

    // Filtering an empty backdrop produces nothing but still costs the filter
    // save-layers; the Back button on every catalog screen sits on one.
    final bool refractsNothing = identical(widget.backdrop, emptyBackdrop);

    return DrawBackdrop(
      backdrop: widget.backdrop,
      shape: () => const Capsule(),
      effects: refractsNothing
          ? (BackdropEffectScope scope) {}
          : (BackdropEffectScope scope) => scope
              ..vibrancy()
              ..blur(2)
              ..lens(12, 24),
      // Kept while disabled: a disabled button does not press, so the block is
      // the identity, and dropping it would put a transform in and out of the
      // tree above the content.
      layerBlock: widget.isInteractive ? _layerBlock : null,
      onDrawSurface: widget.tint != null || widget.surfaceColor != null
          ? _drawSurface
          : null,
      isolateSurface: widget.tint != null,
      repaint: _interactiveHighlight,
      child: content,
    );
  }
}
