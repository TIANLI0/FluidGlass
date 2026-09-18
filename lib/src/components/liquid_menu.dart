import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../fluid_glass.dart';

/// One row of a [LiquidMenu].
@immutable
class LiquidMenuItem {
  const LiquidMenuItem({
    required this.label,
    this.icon,
    this.isDestructive = false,
    this.isSelected = false,
    this.onSelected,
  });

  final String label;

  /// Drawn at the trailing edge, the way a system menu marks its rows.
  final IconData? icon;

  /// Tints the row red, for a row that removes something.
  final bool isDestructive;

  /// Draws a check at the leading edge.
  final bool isSelected;

  final VoidCallback? onSelected;
}

/// Where the panel sits relative to its anchor.
enum LiquidMenuSide { below, above }

/// A pop-up menu that blooms out of its anchor as a [LiquidPanel].
///
/// The motion is one spring, read directly: a short scale from 86% about the
/// anchor corner, with the spring's own slight overshoot supplying the settle
/// — no easing curve is layered on top, which is what made earlier attempts
/// feel rubbery. The panel's refraction, rim and shadow ramp with the same
/// spring through [LiquidPanel.reveal], and the opacity resolves within the
/// first 85% of the travel so the glass never reads as a ghost.
///
/// Pressing a row washes that row alone; there is no panel-wide flash.
///
/// The panel lives in the [Overlay], not in the anchor's own box: Flutter
/// bounds-checks every ancestor while hit-testing, so a panel merely drawn
/// outside its parent would render but never receive a tap.
class LiquidMenu extends StatefulWidget {
  const LiquidMenu({
    super.key,
    required this.backdrop,
    required this.items,
    required this.anchorBuilder,
    this.side = LiquidMenuSide.below,
    this.alignment = Alignment.topLeft,
    this.panelWidth = 240,
    this.gap = 8,
    this.margin = const EdgeInsets.all(12),
    this.rootOverlay = false,
  });

  /// What the panel's glass refracts.
  final Backdrop backdrop;

  final List<LiquidMenuItem> items;

  /// Builds the trigger. [isOpen] lets the anchor reflect the menu's state,
  /// and [toggle] opens or closes it.
  final Widget Function(BuildContext context, bool isOpen, VoidCallback toggle)
  anchorBuilder;

  /// Which side of the anchor the panel *prefers*.
  ///
  /// It flips to the other one when the preferred side cannot fit the panel
  /// inside [margin] — the vertical counterpart of the horizontal edge
  /// avoidance that was always there. A menu low on the screen asked to open
  /// `below` opens `above` instead, rather than hanging off the bottom.
  final LiquidMenuSide side;

  /// Which edge of the anchor the panel lines up with. Only the horizontal
  /// component is read; [side] decides the vertical one.
  final Alignment alignment;

  final double panelWidth;

  /// The space between the anchor and the panel, in logical pixels.
  final double gap;

  /// How close to the overlay's edges the panel may come.
  ///
  /// Both the horizontal nudge and the vertical flip keep the panel inside
  /// this. Widen an edge to keep clear of something the menu must not slide
  /// under — a safe area, or a bar drawn over the overlay it lives in.
  final EdgeInsets margin;

  /// Whether the panel goes in the root [Overlay] rather than the nearest one.
  ///
  /// The nearest overlay is often a nested navigator's, and anything drawn as
  /// that navigator's sibling — an app's own bottom bar, for instance — paints
  /// over it. A menu that has to cover such a bar belongs in the root overlay.
  /// The trade-off is the usual one for root-overlay children: the panel
  /// outlives a route pop of the anchor's route unless the anchor is disposed,
  /// which it is here — [dispose] hides the portal.
  final bool rootOverlay;

  @override
  State<LiquidMenu> createState() => _LiquidMenuState();
}

class _LiquidMenuState extends State<LiquidMenu> with TickerProviderStateMixin {
  static const double _rowHeight = 44.0;
  static const double _panelPadding = 6.0;

  /// Every live menu, so a menu being dismissed can hand the gesture to the
  /// sibling whose anchor was actually pressed.
  ///
  /// The dismiss barrier is opaque on purpose — a tap that closes a menu must
  /// not also press whatever it landed on — but that made switching between
  /// two menus cost two taps: the first was spent dismissing, and the second
  /// anchor never saw it. A menu bar behaves as one tracking surface, so the
  /// barrier resolves the press itself rather than forwarding the event.
  static final Set<_LiquidMenuState> _live = <_LiquidMenuState>{};

  final OverlayPortalController _portal = OverlayPortalController();
  final LayerLink _link = LayerLink();

  late final SpringValue _open = SpringValue(
    vsync: this,
    value: 0,
    visibilityThreshold: 0.001,
  );

  /// A small opening overshoot gives the panel weight; closing is critically
  /// damped so a dismissed menu never rebounds into the interaction area.
  late final SpringDescription _openSpec = springOf(0.76, 420.0);
  late final SpringDescription _closeSpec = springOf(1.0, 620.0);

  late final SpringValue _dragX = SpringValue(
    vsync: this,
    value: 0,
    visibilityThreshold: 0.01,
  );
  late final SpringValue _dragY = SpringValue(
    vsync: this,
    value: 0,
    visibilityThreshold: 0.01,
  );
  late final SpringValue _held = SpringValue(
    vsync: this,
    value: 0,
    visibilityThreshold: 0.001,
  );
  late final SpringValue _selection = SpringValue(
    vsync: this,
    value: 0,
    visibilityThreshold: 0.001,
  );
  late final SpringValue _selectionOpacity = SpringValue(
    vsync: this,
    value: 0,
    visibilityThreshold: 0.001,
  );
  late final Listenable _motion = Listenable.merge([
    _open,
    _dragX,
    _dragY,
    _held,
  ]);
  Offset? _dragOrigin;

  void _animate(
    SpringValue value,
    double target, {
    double damping = 0.72,
    double stiffness = 380,
  }) {
    if (MediaQuery.disableAnimationsOf(context)) {
      value.snapTo(target);
    } else {
      value.animateTo(target, springOf(damping, stiffness));
    }
  }

  void _releaseDrag() {
    _dragOrigin = null;
    _animate(_dragX, 0);
    _animate(_dragY, 0);
    _animate(_held, 0);
    _animate(_selectionOpacity, 0, damping: 1);
  }

  bool _isOpen = false;
  bool _anchorTracking = false;
  int? _trackingPointer;
  int? _hovered;
  final Map<int, GlobalKey> _rowKeys = <int, GlobalKey>{};

  /// Where the finger is, for the hovered row glow to follow. A notifier
  /// rather than state: the glow moves with the pointer, and rebuilding the
  /// panel on every move event to say so would be absurd.
  ///
  /// Never cleared on release. A row reads it only while it is the hovered
  /// one, and clearing it would hand that row a null — the centre — for the
  /// one frame before it deactivates, which is the snap this replaced.
  final ValueNotifier<Offset?> _pointer = ValueNotifier<Offset?>(null);

  void _track(Offset global) {
    _pointer.value = global;
    int? next;
    for (int i = 0; i < widget.items.length; i++) {
      final RenderBox? box =
          _rowKeys[i]?.currentContext?.findRenderObject() as RenderBox?;
      if (box != null &&
          box.hasSize &&
          (Offset.zero & box.size).contains(box.globalToLocal(global))) {
        next = i;
        break;
      }
    }
    if (!_isOpen || _open.value < 0.5) return;
    _dragOrigin ??= global;
    final Offset delta = global - _dragOrigin!;
    _animate(_dragX, (delta.dx * 0.055).clamp(-7.0, 7.0));
    _animate(_dragY, (delta.dy * 0.04).clamp(-6.0, 6.0));
    _animate(_held, next == null ? 0 : 1);
    if (next != _hovered) {
      if (next != null) {
        if (_selectionOpacity.value < 0.01) {
          _selection.snapTo(next.toDouble());
        } else {
          _animate(_selection, next.toDouble(), damping: 0.78, stiffness: 500);
        }
      }
      _animate(_selectionOpacity, next == null ? 0 : 1, damping: 1);
      setState(() => _hovered = next);
    }
  }

  void _finishTracking({bool cancel = false}) {
    final int? index = _hovered;
    _trackingPointer = null;
    _releaseDrag();
    setState(() => _hovered = null);
    if (!cancel && index != null && _isOpen) {
      final LiquidMenuItem item = widget.items[index];
      _close();
      item.onSelected?.call();
    }
  }

  /// Where the anchor sat when the menu opened, for screen-edge avoidance.
  Rect _anchorRect = Rect.zero;

  @override
  void initState() {
    super.initState();
    _live.add(this);
  }

  @override
  void dispose() {
    _live.remove(this);
    _open.dispose();
    _dragX.dispose();
    _dragY.dispose();
    _held.dispose();
    _selection.dispose();
    _selectionOpacity.dispose();
    _pointer.dispose();
    super.dispose();
  }

  /// This menu's anchor, in global coordinates, right now.
  Rect? get _anchorRectNow {
    final RenderBox? box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.attached || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  /// The other menu whose anchor sits under [globalPosition], if any.
  _LiquidMenuState? _siblingAnchoredAt(Offset globalPosition) {
    for (final _LiquidMenuState menu in _live) {
      if (menu == this || !menu.mounted || menu._isOpen) continue;
      final Rect? rect = menu._anchorRectNow;
      if (rect != null && rect.contains(globalPosition)) return menu;
    }
    return null;
  }

  void _show() {
    if (_isOpen) return;
    final RenderBox? box = context.findRenderObject() as RenderBox?;
    if (box != null && box.hasSize) {
      _anchorRect = box.localToGlobal(Offset.zero) & box.size;
    }
    setState(() => _isOpen = true);
    // Never re-show a portal that is still mounted: show() assigns a fresh
    // z-order slot even when already showing, which REMOUNTS the overlay
    // child — reopening while the closing spring was still running made the
    // panel flash and replay its bloom. With the portal left alone, the same
    // spring simply retargets and the motion stays continuous.
    if (!_portal.isShowing) {
      _portal.show();
    }
    if (MediaQuery.disableAnimationsOf(context)) {
      _open.snapTo(1);
    } else {
      _open.animateTo(1.0, _openSpec);
    }
  }

  void _close() {
    if (!_isOpen) return;
    _releaseDrag();
    setState(() {
      _isOpen = false;
      _hovered = null;
    });
    if (MediaQuery.disableAnimationsOf(context)) {
      _open.snapTo(0);
      _portal.hide();
      return;
    }
    _open.animateTo(0.0, _closeSpec);
    // The panel stays mounted until the spring has run out, so it animates
    // away instead of vanishing.
    _open.whenSettled(() {
      if (mounted && !_isOpen) _portal.hide();
    });
  }

  void _toggle() {
    if (_anchorTracking) return;
    _isOpen ? _close() : _show();
  }

  void _endAnchorTracking() {
    _finishTracking();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _anchorTracking = false;
    });
  }

  double get _panelHeight =>
      widget.items.length * _rowHeight + _panelPadding * 2;

  @override
  Widget build(BuildContext context) {
    final bool leading = widget.alignment.x <= 0;

    Widget buildOverlayChild(BuildContext context) {
      // Edge avoidance: on a narrow screen an anchor-aligned panel can hang
      // past the edge, shearing its rim off.
      final Size screen = MediaQuery.sizeOf(context);
      final EdgeInsets margin = widget.margin;
      double dx = 0;
      if (leading) {
        final double overflow =
            _anchorRect.left +
            widget.panelWidth -
            (screen.width - margin.right);
        if (overflow > 0) dx = -overflow;
      } else {
        final double underflow =
            margin.left - (_anchorRect.right - widget.panelWidth);
        if (underflow > 0) dx = underflow;
      }

      // The vertical counterpart: the preferred side wins when it fits, and
      // the panel flips rather than hanging off an edge. Neither fitting means
      // a panel taller than the overlay, which flipping cannot rescue — keep
      // the preference so the result is at least predictable.
      final double span = _panelHeight + widget.gap;
      final bool fitsBelow =
          _anchorRect.bottom + span <= screen.height - margin.bottom;
      final bool fitsAbove = _anchorRect.top - span >= margin.top;
      final bool prefersBelow = widget.side == LiquidMenuSide.below;
      final bool below = prefersBelow
          ? (fitsBelow || !fitsAbove)
          : (!fitsAbove && fitsBelow);

      return Stack(
        children: <Widget>[
          // Touching anywhere else dismisses, on the pointer DOWN — and the
          // barrier stops intercepting the moment the menu starts closing.
          // A barrier that lingered for the whole closing spring ate the
          // taps that followed, so quickly toggling the anchor made the
          // menu pop open and shut out of step with the finger.
          //
          // The press is absorbed rather than passed through, so dismissing
          // never doubles as pressing something. The one thing it resolves
          // itself is a press on a sibling menu's anchor, which opens that
          // menu — otherwise switching between two menus cost two taps.
          Positioned.fill(
            child: IgnorePointer(
              ignoring: !_isOpen,
              child: Listener(
                behavior: HitTestBehavior.opaque,
                onPointerDown: (PointerDownEvent event) {
                  final _LiquidMenuState? sibling = _siblingAnchoredAt(
                    event.position,
                  );
                  _close();
                  sibling?._show();
                },
              ),
            ),
          ),
          CompositedTransformFollower(
            link: _link,
            showWhenUnlinked: false,
            targetAnchor: below
                ? (leading ? Alignment.bottomLeft : Alignment.bottomRight)
                : (leading ? Alignment.topLeft : Alignment.topRight),
            followerAnchor: below
                ? (leading ? Alignment.topLeft : Alignment.topRight)
                : (leading ? Alignment.bottomLeft : Alignment.bottomRight),
            offset: Offset(dx, below ? widget.gap : -widget.gap),
            child: Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: (event) {
                if (_trackingPointer != null || !_isOpen || _open.value < 0.5) {
                  return;
                }
                _trackingPointer = event.pointer;
                _track(event.position);
              },
              onPointerMove: (event) {
                if (_trackingPointer == event.pointer) _track(event.position);
              },
              onPointerUp: (event) {
                if (_trackingPointer != event.pointer) return;
                _track(event.position);
                _finishTracking();
              },
              onPointerCancel: (event) {
                if (_trackingPointer == event.pointer) {
                  _finishTracking(cancel: true);
                }
              },
              child: _MenuPanel(
                motion: _motion,
                pointer: _pointer,
                dragX: _dragX,
                dragY: _dragY,
                held: _held,
                selection: _selection,
                selectionOpacity: _selectionOpacity,
                hovered: _hovered,
                rowKeys: _rowKeys,
                open: _open,
                isOpen: _isOpen,
                backdrop: widget.backdrop,
                items: widget.items,
                width: widget.panelWidth,
                height: _panelHeight,
                rowHeight: _rowHeight,
                padding: _panelPadding,
                growFromTop: below,
                growFromLeft: leading,
                onSelected: (LiquidMenuItem item) {
                  _close();
                  item.onSelected?.call();
                },
              ),
            ),
          ),
        ],
      );
    }

    final Widget anchor = CompositedTransformTarget(
      link: _link,
      child: GestureDetector(
        onLongPressStart: (_) {
          _anchorTracking = true;
          _show();
        },
        onLongPressMoveUpdate: (event) => _track(event.globalPosition),
        onLongPressEnd: (_) => _endAnchorTracking(),
        onLongPressCancel: () {
          if (_hovered != null) _finishTracking(cancel: true);
        },
        child: widget.anchorBuilder(context, _isOpen, _toggle),
      ),
    );

    return OverlayPortal(
      controller: _portal,
      overlayLocation: widget.rootOverlay
          ? OverlayChildLocation.rootOverlay
          : OverlayChildLocation.nearestOverlay,
      overlayChildBuilder: buildOverlayChild,
      child: anchor,
    );
  }
}

class _MenuPanel extends StatelessWidget {
  const _MenuPanel({
    required this.motion,
    required this.pointer,
    required this.dragX,
    required this.dragY,
    required this.held,
    required this.selection,
    required this.selectionOpacity,
    required this.hovered,
    required this.rowKeys,
    required this.open,
    required this.isOpen,
    required this.backdrop,
    required this.items,
    required this.width,
    required this.height,
    required this.rowHeight,
    required this.padding,
    required this.growFromTop,
    required this.growFromLeft,
    required this.onSelected,
  });

  final Listenable motion;
  final ValueListenable<Offset?> pointer;
  final SpringValue dragX, dragY, held, selection, selectionOpacity;
  final int? hovered;
  final Map<int, GlobalKey> rowKeys;
  final SpringValue open;

  /// Whether the menu is on its way in rather than on its way out.
  final bool isOpen;

  final Backdrop backdrop;
  final List<LiquidMenuItem> items;
  final double width;
  final double height;
  final double rowHeight;
  final double padding;
  final bool growFromTop;
  final bool growFromLeft;
  final ValueChanged<LiquidMenuItem> onSelected;

  /// The bloom out of the anchor corner: one uniform scale straight off the
  /// spring. The spring is allowed past 1.0, so the settle-back is its own
  /// physics, not a second curve fighting it.
  void _layerBlock(GlassLayer layer) {
    final double p = open.value;
    layer.transformOrigin = Offset(
      growFromLeft ? 0.08 : 0.92,
      growFromTop ? 0.02 : 0.98,
    );
    final double scale = 0.86 + 0.14 * p;
    final double press = held.value;
    layer.scaleX = scale * (1 + 0.012 * press);
    layer.scaleY = scale * (1 + 0.008 * press);
    layer.translationX = dragX.value;
    layer.translationY = dragY.value + (growFromTop ? -8 : 8) * (1 - p);
    // One continuous mapping in both directions, including interrupted closes.
    layer.alpha = (p / 0.85).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final LiquidGlassColors colors = LiquidGlassTheme.of(context);
    final Color contentColor = colors.content;
    final Color destructiveColor = colors.destructive;
    final Color separatorColor = contentColor.withValues(alpha: 0.08);

    return ListenableBuilder(
      listenable: open,
      builder: (BuildContext context, Widget? child) {
        return IgnorePointer(
          // Rows land where they are drawn at every point of the bloom —
          // `RenderGlassTransform` inverts its own matrix when hit-testing —
          // so this gate is not about geometry. It is about intent: a panel
          // that is still fading in is not yet something you can have aimed
          // at, and one that has been dismissed is no longer something you
          // can aim at. Without the [isOpen] half, a tap meant for whatever
          // the menu had been covering selected a row instead, because the
          // panel stays mounted and live for the whole closing spring while
          // the dismiss barrier steps aside immediately.
          ignoring: !isOpen || open.value < 0.5,
          child: child,
        );
      },
      child: LiquidPanel(
        backdrop: backdrop,
        shape: RoundedRectangle(_radiusFor(width)),
        reveal: () => open.value.clamp(0.0, 1.0),
        repaint: motion,
        layerBlock: _layerBlock,
        child: SizedBox(
          width: width,
          height: height,
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: padding),
            child: Stack(
              children: [
                Positioned.fill(
                  child: IgnorePointer(
                    child: ListenableBuilder(
                      listenable: Listenable.merge([
                        selection,
                        selectionOpacity,
                      ]),
                      builder: (context, child) => Stack(
                        children: [
                          Positioned(
                            left: 6,
                            right: 6,
                            top:
                                selection.value.clamp(
                                      0.0,
                                      (items.length - 1)
                                          .clamp(0, items.length)
                                          .toDouble(),
                                    ) *
                                    rowHeight +
                                2,
                            height: rowHeight - 4,
                            child: Opacity(
                              opacity: selectionOpacity.value.clamp(0.0, 1.0),
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: contentColor.withValues(alpha: 0.09),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: const Color(
                                      0xFFFFFFFF,
                                    ).withValues(alpha: 0.18),
                                    width: 0.5,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    for (int i = 0; i < items.length; i++) ...<Widget>[
                      if (i > 0)
                        Divider(
                          height: 0,
                          thickness: 0.5,
                          indent: 16,
                          endIndent: 16,
                          color: separatorColor,
                        ),
                      _MenuRow(
                        key: rowKeys.putIfAbsent(i, () => GlobalKey()),
                        active: hovered == i,
                        pointer: pointer,
                        reserveCheck: items.any((item) => item.isSelected),
                        item: items[i],
                        height: rowHeight,
                        contentColor: items[i].isDestructive
                            ? destructiveColor
                            : contentColor,
                        washColor: contentColor.withValues(alpha: 0.08),
                        onSelected: onSelected,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Big enough to read as a squircle at this size, not so big it turns into
  /// a capsule.
  static double _radiusFor(double width) => width / 4 < 22.0 ? width / 4 : 22.0;
}

class _MenuRow extends StatefulWidget {
  const _MenuRow({
    super.key,
    required this.active,
    required this.pointer,
    required this.reserveCheck,
    required this.item,
    required this.height,
    required this.contentColor,
    required this.washColor,
    required this.onSelected,
  });

  final bool active;
  final ValueListenable<Offset?> pointer;
  final bool reserveCheck;
  final LiquidMenuItem item;
  final double height;
  final Color contentColor;
  final Color washColor;
  final ValueChanged<LiquidMenuItem> onSelected;

  @override
  State<_MenuRow> createState() => _MenuRowState();
}

class _MenuRowState extends State<_MenuRow> {
  @override
  Widget build(BuildContext context) {
    // Slop-free, like Compose's `clickable`: a finger that wanders while
    // choosing must not have its selection swallowed.
    //
    // The pressed wash is an inset rounded rectangle, not a full-bleed bar:
    // full-bleed collided with the panel's rounded corners on the first and
    // last rows, shearing the wash into a hard-edged strip.
    return Semantics(
      button: true,
      selected: widget.item.isSelected,
      onTap: () => widget.onSelected(widget.item),
      child: SizedBox(
        height: widget.height,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          child: LiquidInteraction(
            active: widget.active,
            activePosition: widget.pointer,
            selected: widget.item.isSelected,
            trackPointer: false,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 110),
              curve: Curves.easeOut,
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                children: <Widget>[
                  if (widget.reserveCheck)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: SizedBox(
                        width: 18,
                        child: widget.item.isSelected
                            ? Icon(
                                Icons.check,
                                size: 18,
                                color: widget.contentColor,
                              )
                            : null,
                      ),
                    ),
                  Expanded(
                    child: Text(
                      widget.item.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: widget.contentColor,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  if (widget.item.icon != null)
                    Icon(
                      widget.item.icon,
                      size: 19,
                      color: widget.contentColor,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
