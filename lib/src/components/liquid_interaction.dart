import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../theme/liquid_glass_theme.dart';
import 'interactive_highlight.dart';

/// Shared finger-following feedback for custom controls, menu rows and tiles.
///
/// Observes pointers without claiming their gestures; unless [onTap] is given,
/// activation stays with the child. [active] supports drag selection
/// controlled by a parent.
///
/// The glow stays as long as the finger does — it does not fade when the
/// finger wanders past a slop distance the way a Material ink does — and it
/// follows the finger, clamped to the control's bounds, until the pointer
/// lifts.
///
/// Inside a [LiquidInteractionGroup] this control gives up its own pointer:
/// the group tracks one finger across every member and hands each member its
/// share of the press, so a press can travel from one control to the next and
/// fire the one it lifts on.
class LiquidInteraction extends StatefulWidget {
  const LiquidInteraction({
    super.key,
    required this.child,
    this.onTap,
    this.active = false,
    this.activePosition,
    this.selected = false,
    this.enabled = true,
    this.trackPointer = true,
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
  });
  final Widget child;
  final bool active, selected, enabled, trackPointer;

  /// What this control does when the finger lifts on it.
  ///
  /// Slop-free, like every liquid control: it fires on release however far the
  /// finger has travelled, as long as it lifts inside this control's bounds.
  /// Outside a [LiquidInteractionGroup], the pointer this widget observes is
  /// the one that lifts. Inside one, the group decides — the finger may have
  /// gone down on a neighbour.
  ///
  /// Leave null for a child that already handles its own tap; do not set both,
  /// or a plain tap fires twice.
  final VoidCallback? onTap;

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

  /// The group this control belongs to, if any.
  _LiquidInteractionGroupState? _group;

  /// Whether the group's finger is on this control.
  bool _heldByGroup = false;

  @override
  void initState() {
    super.initState();
    widget.activePosition?.addListener(_handleActivePosition);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final _LiquidInteractionGroupState? next = _LiquidInteractionGroupScope.of(
      context,
    );
    if (identical(next, _group)) return;
    _group?._unregister(this);
    _group = next;
    next?._register(this);
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

  // ── Driven by a LiquidInteractionGroup ──

  RenderBox? get _box {
    final RenderObject? object = context.findRenderObject();
    if (object is! RenderBox || !object.hasSize || !object.attached) {
      return null;
    }
    return object;
  }

  /// Whether [global] is inside this control, for the group's hit test.
  bool _contains(Offset global) {
    final RenderBox? box = _box;
    if (box == null) return false;
    return (Offset.zero & box.size).contains(box.globalToLocal(global));
  }

  void _groupDown(Offset global) {
    final RenderBox? box = _box;
    if (box == null) return;
    _heldByGroup = true;
    _highlight.handleDown(box.globalToLocal(global));
  }

  void _groupMove(Offset global) {
    final RenderBox? box = _box;
    if (box == null || !_heldByGroup) return;
    _highlight.handleMove(box.globalToLocal(global));
  }

  void _groupUp() {
    if (!_heldByGroup) return;
    _heldByGroup = false;
    _highlight.handleUp();
  }

  @override
  void dispose() {
    _group?._unregister(this);
    widget.activePosition?.removeListener(_handleActivePosition);
    _highlight.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // In a group the group's listener drives this control; its own pointer
    // handling would fight it for the same finger.
    final bool own = widget.trackPointer && _group == null;
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (e) {
        if (!widget.enabled || !own || _pointer != null) return;
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
          final RenderBox? box = _box;
          if (widget.onTap != null &&
              box != null &&
              (Offset.zero & box.size).contains(e.localPosition)) {
            widget.onTap!();
          }
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

/// One finger, many controls.
///
/// Every [LiquidInteraction] below this widget becomes a member. The group
/// tracks one pointer: the member under the finger lights up and follows it,
/// sliding onto a neighbour moves the light — and the press — to that
/// neighbour, and lifting fires the [LiquidInteraction.onTap] of whichever
/// member the finger is on by then. Lifting on nothing fires nothing.
///
/// This is the rule a body of fused glass already follows for its light: if
/// the glow can cross from one control to the next under a held finger, so
/// must the thing the finger is about to do. A row of actions, a grid of
/// stickers, the two slots of an input capsule — the finger goes down
/// somewhere near, slides to the one it means, and lifts.
///
/// **Members give their taps to the group.** A member's own tap handler
/// (`GestureDetector`, `InkWell`) would fire alongside the group's commit on a
/// plain tap; inside a group, put the action in [LiquidInteraction.onTap] and
/// nothing else.
///
/// **A scroll cancels the press.** The group observes pointers without
/// claiming them, so a drag across a scrolling grid of members is also the
/// grid's scroll gesture. The member under the down position names its
/// enclosing [Scrollable]; if that scrollable's offset moves while the finger
/// is down, the finger was scrolling, and lifting fires nothing.
class LiquidInteractionGroup extends StatefulWidget {
  const LiquidInteractionGroup({
    super.key,
    required this.child,
    this.enabled = true,
  });

  final Widget child;

  /// False lets every member track its own finger again, as if the group were
  /// not there.
  final bool enabled;

  @override
  State<LiquidInteractionGroup> createState() => _LiquidInteractionGroupState();
}

class _LiquidInteractionGroupState extends State<LiquidInteractionGroup> {
  final Set<_LiquidInteractionState> _members = <_LiquidInteractionState>{};

  int? _pointer;
  _LiquidInteractionState? _active;

  ScrollPosition? _scroll;
  double? _scrollPixels;

  void _register(_LiquidInteractionState member) => _members.add(member);

  void _unregister(_LiquidInteractionState member) {
    _members.remove(member);
    if (identical(member, _active)) _active = null;
  }

  _LiquidInteractionState? _memberAt(Offset global) {
    for (final _LiquidInteractionState member in _members) {
      if (member.widget.enabled && member._contains(global)) return member;
    }
    return null;
  }

  void _activate(_LiquidInteractionState? next, Offset global) {
    final _LiquidInteractionState? current = _active;
    if (identical(next, current)) {
      current?._groupMove(global);
      return;
    }
    current?._groupUp();
    _active = next;
    next?._groupDown(global);
  }

  void _watchScroll(_LiquidInteractionState member) {
    final ScrollPosition? position = Scrollable.maybeOf(
      member.context,
    )?.position;
    if (position == null || !position.hasPixels) return;
    _scroll = position;
    _scrollPixels = position.pixels;
    position.addListener(_onScrolled);
  }

  void _unwatchScroll() {
    _scroll?.removeListener(_onScrolled);
    _scroll = null;
    _scrollPixels = null;
  }

  /// The list under the finger moved: this was a scroll, not a press.
  void _onScrolled() {
    final ScrollPosition? position = _scroll;
    if (position == null || !position.hasPixels) return;
    if (position.pixels != _scrollPixels) _cancel();
  }

  void _cancel() {
    _pointer = null;
    _unwatchScroll();
    _active?._groupUp();
    _active = null;
  }

  @override
  void dispose() {
    _unwatchScroll();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _LiquidInteractionGroupScope(
      state: widget.enabled ? this : null,
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (PointerDownEvent e) {
          if (!widget.enabled || _pointer != null) return;
          final _LiquidInteractionState? member = _memberAt(e.position);
          if (member == null) return;
          _pointer = e.pointer;
          _activate(member, e.position);
          _watchScroll(member);
        },
        onPointerMove: (PointerMoveEvent e) {
          if (e.pointer != _pointer) return;
          // Over nothing the finger keeps the member it came from, so the
          // light has somewhere to be; lifting there still fires nothing.
          _activate(_memberAt(e.position) ?? _active, e.position);
        },
        onPointerUp: (PointerUpEvent e) {
          if (e.pointer != _pointer) return;
          final _LiquidInteractionState? over = _memberAt(e.position);
          _cancel();
          if (over != null && over.mounted) over.widget.onTap?.call();
        },
        onPointerCancel: (PointerCancelEvent e) {
          if (e.pointer == _pointer) _cancel();
        },
        child: widget.child,
      ),
    );
  }
}

class _LiquidInteractionGroupScope extends InheritedWidget {
  const _LiquidInteractionGroupScope({
    required this.state,
    required super.child,
  });

  final _LiquidInteractionGroupState? state;

  static _LiquidInteractionGroupState? of(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<_LiquidInteractionGroupScope>()
      ?.state;

  @override
  bool updateShouldNotify(_LiquidInteractionGroupScope oldWidget) =>
      !identical(oldWidget.state, state);
}
