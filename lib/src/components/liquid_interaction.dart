import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../theme/liquid_glass_theme.dart';
import 'interactive_highlight.dart';

/// Shared finger-following feedback for custom controls, menu rows and tiles.
/// Observes pointers without claiming their gestures; activation stays with
/// the child. [active] supports drag selection controlled by a parent.
class LiquidInteraction extends StatefulWidget {
  const LiquidInteraction({
    super.key,
    required this.child,
    this.active = false,
    this.activePosition,
    this.selected = false,
    this.enabled = true,
    this.trackPointer = true,
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
  });
  final Widget child;
  final bool active, selected, enabled, trackPointer;

  /// Where the finger is during [active], in global coordinates, for a parent
  /// that owns the gesture — a menu tracking one drag across its rows.
  ///
  /// Without it an activated child has no pointer of its own to follow
  /// ([trackPointer] is that parent's to claim, not both), and the glow can
  /// only sit still in the middle of the child. It is a listenable rather than
  /// a value so the glow can follow the finger without rebuilding anything.
  final ValueListenable<Offset?>? activePosition;
  final BorderRadius borderRadius;
  @override
  State<LiquidInteraction> createState() => _LiquidInteractionState();
}

class _LiquidInteractionState extends State<LiquidInteraction>
    with TickerProviderStateMixin {
  late final InteractiveHighlight _highlight = InteractiveHighlight(
    vsync: this,
  );
  int? _pointer;

  @override
  void initState() {
    super.initState();
    widget.activePosition?.addListener(_handleActivePosition);
  }

  @override
  void didUpdateWidget(LiquidInteraction oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.activePosition != oldWidget.activePosition) {
      oldWidget.activePosition?.removeListener(_handleActivePosition);
      widget.activePosition?.addListener(_handleActivePosition);
    }
    if (!widget.enabled || !widget.active && oldWidget.active) {
      _highlight.handleUp();
    }
    if (widget.enabled && widget.active && !oldWidget.active) {
      _highlight.handleDown(_activeLocalPosition());
    }
  }

  /// The parent's pointer in this widget's own coordinates, or its centre when
  /// the parent tracks no pointer — a keyboard or an assistive activation.
  Offset _activeLocalPosition() {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return Offset.zero;
    final Offset? global = widget.activePosition?.value;
    return global == null
        ? box.size.center(Offset.zero)
        : box.globalToLocal(global);
  }

  void _handleActivePosition() {
    if (!widget.enabled || !widget.active) return;
    _highlight.handleMove(_activeLocalPosition());
  }

  @override
  void dispose() {
    widget.activePosition?.removeListener(_handleActivePosition);
    _highlight.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (e) {
        if (!widget.enabled || !widget.trackPointer || _pointer != null) return;
        _pointer = e.pointer;
        _highlight.handleDown(e.localPosition);
      },
      onPointerMove: (e) {
        if (_pointer == e.pointer) _highlight.handleMove(e.localPosition);
      },
      onPointerUp: (e) {
        if (_pointer == e.pointer) {
          _pointer = null;
          _highlight.handleUp();
        }
      },
      onPointerCancel: (e) {
        if (_pointer == e.pointer) {
          _pointer = null;
          _highlight.handleUp();
        }
      },
      child: ClipRRect(
        borderRadius: widget.borderRadius,
        child: ColoredBox(
          color: widget.selected && widget.enabled
              ? LiquidGlassTheme.of(context).accent.withValues(alpha: 0.10)
              : Colors.transparent,
          child: _highlight.wrapOverlay(child: widget.child),
        ),
      ),
    );
  }
}
